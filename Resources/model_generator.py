#!/usr/bin/env python3
"""Deterministic NONMEM model transformer (template-based).

Takes a source .mod and a *structured* modification decision (from LLM or
heuristic) and produces a valid target .mod.  The LLM decides *what* to
change; this module does the *how* — never invents syntax, never makes
typos, always produces referentially consistent control streams.
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# AutoPMX template library
from poppk_model_templates import (
    TEMPLATES,
    render_model,
    recommended_template_id,
    normalize_input_columns,
    COMMON_ESTIMATION,
    _tables,
)


def _is_numeric_token(token: str) -> bool:
    if token == ".":
        return True
    try:
        float(token)
        return True
    except ValueError:
        return False


def strip_inline_dataset_rows(text: str) -> str:
    """Remove CSV rows accidentally pasted after $INPUT/$DATA.

    Two-pass defence:
    1. Between $INPUT and $DATA: pattern-match data-like rows.
    2. After $DATA: WHITELIST — only control records ($...), comments (;...),
       and blank lines survive.  Everything else is silently stripped.
       No heuristic can handle all LLM output formats — a whitelist guarantees it.
    """
    lines = text.split("\n")
    output: List[str] = []
    after_input = False
    after_data = False
    dropped = 0

    for line in lines:
        stripped = line.strip()
        upper = stripped.upper()

        if upper.startswith("$INPUT"):
            after_input = True
            after_data = False
            output.append(line)
            continue
        if upper.startswith("$DATA"):
            after_input = False
            after_data = True
            output.append(line)
            continue

        # --- After $DATA: WHITELIST only ---
        if after_data:
            if not stripped or stripped.startswith(";"):
                output.append(line)
                continue
            if stripped.startswith("$"):
                after_data = False  # next control record ends data section
                output.append(line)
                continue
            # Everything else after $DATA is presumed embedded CSV data
            dropped += 1
            continue

        # --- Between $INPUT and $DATA: pattern matching ---
        if after_input:
            if not stripped or stripped.startswith(";"):
                output.append(line)
                continue
            if stripped.startswith("$"):
                after_input = False
                after_data = upper.startswith("$DATA")
                output.append(line)
                continue

            tokens = stripped.split()
            if len(tokens) >= 2:
                first = tokens[0]
                numeric_count = sum(1 for token in tokens if _is_numeric_token(token))
                if first == "." or _is_numeric_token(first) or numeric_count >= max(2, len(tokens) // 2):
                    dropped += 1
                    continue

        output.append(line)

    if dropped:
        import sys
        print(f"[model_generator] strip_inline_dataset_rows: removed {dropped} embedded CSV rows", file=sys.stderr)

    compact: List[str] = []
    last_blank = False
    for line in output:
        if line.strip():
            if last_blank and compact and compact[-1] != "":
                compact.append("")
            compact.append(line)
            last_blank = False
        else:
            if not last_blank and compact:
                compact.append("")
            last_blank = True
    while compact and compact[-1] == "":
        compact.pop()
    return "\n".join(compact)


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class Modification:
    """A single deterministic change."""
    action: str  # see ACTION_REGISTRY keys
    params: Dict[str, Any] = field(default_factory=dict)


# ---------------------------------------------------------------------------
# .mod parsing helpers
# ---------------------------------------------------------------------------

SectionMap = Dict[str, str]  # label → section text (including the $label)


def parse_sections(text: str) -> SectionMap:
    """Split a .mod into `$`‑delimited sections.

    Consecutive ``$TABLE`` records are merged into a single ``$TABLE``
    section so the dict doesn't drop any of them.
    """
    sections: SectionMap = {}
    pattern = re.compile(r"^\s*(\$\w+)", re.MULTILINE)
    last_label = None
    last_start = None
    for m in pattern.finditer(text):
        label = m.group(1).upper()
        if last_label and last_start is not None:
            this_text = text[last_start:m.start()]
            # Merge consecutive $TABLE records
            if last_label == "$TABLE" and label == "$TABLE" and "$TABLE" in sections:
                sections["$TABLE"] += "\n" + this_text
            else:
                sections[last_label] = this_text
        last_label = label
        last_start = m.start()
    if last_label and last_start is not None:
        this_text = text[last_start:]
        if last_label == "$TABLE" and "$TABLE" in sections:
            sections["$TABLE"] += "\n" + this_text
        else:
            sections[last_label] = this_text
    return sections


def rebuild_mod(sections: SectionMap,
                insert_before: Optional[List[Tuple[str, str]]] = None,
                insert_after: Optional[List[Tuple[str, str]]] = None) -> str:
    """Reassemble sections in canonical order.

    Parameters
    ----------
    sections : SectionMap
        Existing sections.
    insert_before : list of (label, text)
        Insert these blocks before the named section.
    insert_after : list of (label, text)
        Append these blocks after the named section.  If the named section
        doesn't exist, append at end.

    Returns
    -------
    str
    """
    ORDER = ["$PROBLEM", "$INPUT", "$DATA", "$SUBROUTINES", "$MODEL",
             "$PK", "$DES", "$ERROR", "$THETA", "$OMEGA", "$SIGMA",
             "$ESTIMATION", "$EST", "$COVARIANCE", "$COV", "$TABLE"]

    present = [l for l in ORDER if l in sections]
    # Add any extra sections not in ORDER
    present.extend(l for l in sorted(sections) if l not in ORDER and l not in present)

    # Build with insert_before
    before_map: Dict[str, List[str]] = {}
    if insert_before:
        for label, text in insert_before:
            before_map.setdefault(label, []).append(text)

    after_map: Dict[str, List[str]] = {}
    if insert_after:
        for label, text in insert_after:
            after_map.setdefault(label, []).append(text)

    parts = []
    for label in present:
        for t in before_map.get(label, []):
            parts.append(t)
        parts.append(sections[label])
        for t in after_map.get(label, []):
            parts.append(t)

    return "\n\n".join(parts) + "\n"


def find_eta_count(text: str) -> int:
    """Return the highest ETA(n) index referenced in $PK and $ERROR."""
    max_eta = 0
    for m in re.finditer(r"\bETA\s*\(\s*(\d+)\s*\)", text, re.IGNORECASE):
        max_eta = max(max_eta, int(m.group(1)))
    return max_eta


def find_theta_count(text: str) -> int:
    """Return the number of THETA records in the $THETA section."""
    m = re.search(r"\$THETA\s*\n?(.*?)(?=\n\s*\$)", text, re.DOTALL | re.IGNORECASE)
    if not m:
        return 0
    count = 0
    for line in m.group(1).splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        if stripped.upper().startswith(("$THETA",)):
            continue
        count += 1
    return count


def extract_run_id(text: str) -> Optional[str]:
    """Extract run ID from $TABLE FILE= references."""
    m = re.search(r"FILE\s*=\s*SDTAB(\d+)", text, re.IGNORECASE)
    return m.group(1) if m else None


def ensure_eta_table(sections: SectionMap, run_id: str) -> SectionMap:
    """Make sure every generated/fixed model exports EBE values to run{id}.ETA."""
    table_sec = sections.get("$TABLE", "")
    if not table_sec:
        return sections
    eta_count = find_eta_count(rebuild_mod(sections))
    if eta_count <= 0:
        return sections

    eta_terms = " ".join(f"ETA{i}" for i in range(1, eta_count + 1))
    eta_table = f"$TABLE ID {eta_terms} FIRSTONLY NOAPPEND NOPRINT FILE=run{run_id}.ETA"
    kept = []
    for line in table_sec.splitlines():
        if re.search(r"\$TABLE.*ETA\d+.*FIRSTONLY", line, re.IGNORECASE):
            continue
        kept.append(line)
    kept.append(eta_table)
    sections["$TABLE"] = "\n".join(kept)
    return sections


# ---------------------------------------------------------------------------
# Action implementations
# ---------------------------------------------------------------------------

def action_bump_run(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Bump all run‑ID references from old_run to new_run."""
    old_run = str(params["old_run"])
    new_run = str(params["new_run"])
    for label in sections:
        # Replace run{old}.ext → run{new}.ext
        sections[label] = re.sub(
            rf"run{old_run}\b",
            f"run{new_run}",
            sections[label],
            flags=re.IGNORECASE,
        )
        # Replace FILE=SDTAB{old} → SDTAB{new}, etc.
        sections[label] = re.sub(
            rf"(FILE\s*=\s*)((?:SDTAB|PATAB|CATAB|COTAB|000)|run){old_run}",
            lambda m: f"{m.group(1)}{m.group(2)}{new_run}",
            sections[label],
            flags=re.IGNORECASE,
        )
    return sections


def action_fix_input(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Replace $INPUT with the canonical column list."""
    columns = params.get("columns", [])
    if columns:
        token_list = normalize_input_columns(columns)
        sections["$INPUT"] = "$INPUT " + " ".join(token_list)
    else:
        sections["$INPUT"] = "$INPUT " + " ".join(
            ["C", "ID", "CYCLE", "DAY", "TIME", "NTIME", "DV", "AMT", "RATE",
             "DUR", "CMT", "DOSE", "MDV", "EVID", "BQL", "TYPE", "STUDY", "SEX", "WT", "AGE"]
        )
    return sections


def action_fix_data(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Replace $DATA path."""
    data_file = params.get("data_file", "NM_dat_new.csv")
    sections["$DATA"] = f"$DATA {data_file} IGNORE=C"
    return sections


def action_fix_table_ids(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Fix all $TABLE FILE= to match target_run_id."""
    target = str(params["run_id"])
    for label in list(sections.keys()):
        if label.startswith("$TABLE") or label == "$TABLE":
            sec = sections[label]
            sec = re.sub(
                r"(FILE\s*=\s*)((?:SDTAB|PATAB|CATAB|COTAB|000)|run)\d+",
                lambda m: f"{m.group(1)}{m.group(2)}{target}",
                sec,
                flags=re.IGNORECASE,
            )
            sections[label] = sec
    return sections


def action_fix_theta_boundaries(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Ensure THETA records have (lower, init, upper) form when missing."""
    theta_sec = sections.get("$THETA", "")
    lines = theta_sec.splitlines()
    fixed = ["$THETA"]
    for line in lines[1:]:
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            fixed.append(line)
            continue
        # If no parentheses, it's a bare number — wrap with sensible bounds
        if not stripped.startswith("("):
            # Check if FIX is present
            is_fixed = "FIX" in stripped.upper()
            val = stripped.replace("FIX", "").replace("fix", "").strip()
            try:
                num = float(val.split(";")[0].strip())
                if is_fixed:
                    fixed.append(f"  (0, {num}) ; {line.split(';')[-1].strip() if ';' in line else ''}")
                else:
                    # Use 0 as lower bound, num * 3 as upper bound
                    ubound = max(num * 3, 10)
                    fixed.append(f"  (0, {num}, {ubound:.4g}) ; {line.split(';')[-1].strip() if ';' in line else ''}")
            except ValueError:
                fixed.append(line)
        else:
            fixed.append(line)
    sections["$THETA"] = "\n".join(fixed)
    return sections


def action_add_covariate(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Add a centered power covariate relationship.

    Example params::

        {"param": "V1", "covariate": "WT", "median": 62.14,
         "theta_init": 0.75, "theta_lower": 0, "theta_upper": 3}

    Injects:
    - THETA(n) : V1WT power exponent (if weight)
    - TV{param}{cov} = (({covariate}/{median})**THETA(n))
    - TV{param} *= TV{param}{cov}
    - ``;;; {param}{cov}-DEFINITION START/END`` markers
    """
    param = params["param"]
    cov = params["covariate"]
    cov_var = f"{param}{cov}"
    median = float(params.get("median", 62.14))
    theta_init = float(params.get("theta_init", 0.75))
    theta_lower = float(params.get("theta_lower", 0))
    theta_upper = float(params.get("theta_upper", 3))

    def fmt_theta(v):
        """Format theta value without unnecessary .0."""
        f = float(v)
        return str(int(f)) if f == int(f) else f"{f:g}"

    coef_line = f"({fmt_theta(theta_lower)}, {fmt_theta(theta_init)}, {fmt_theta(theta_upper)}) ; {cov_var}"

    pk_sec = sections.get("$PK", "")
    theta_sec = sections.get("$THETA", "")

    # Count existing THETAs
    n_theta = 0
    for line in theta_sec.splitlines():
        s = line.strip()
        if s and not s.startswith(";") and not s.upper().startswith("$THETA") and not s.upper().startswith("$"):
            n_theta += 1

    new_theta_idx = n_theta + 1
    cov_var = f"{param}{cov}"

    # Build covariate definition block with markers
    if cov.upper() == "WT":
        cov_def = f""";;; {cov_var}-DEFINITION START
   {cov_var} = (({cov}/{median})**THETA({new_theta_idx}))
;;; {cov_var}-DEFINITION END

;;; {param}-RELATION START
{param}COV={cov_var}
;;; {param}-RELATION END"""
    else:
        cov_def = f""";;; {cov_var}-DEFINITION START
   {cov_var} = ({cov}/{median})
;;; {cov_var}-DEFINITION END

;;; {param}-RELATION START
{param}COV={cov_var}
;;; {param}-RELATION END"""

    # Inject covariate reference into TV{param}
    # Look for TV{param} = THETA(...) pattern
    tv_pattern = re.compile(rf"(TV{param}\s*=\s*THETA\s*\(\s*\d+\s*\))", re.IGNORECASE)
    tv_match = tv_pattern.search(pk_sec)
    if tv_match:
        # Add the covariate multiplication AFTER the TV definition
        new_tv = f"\n\nTV{param} = {cov_var}*TV{param}"
        pk_sec = pk_sec[:tv_match.end()] + new_tv + pk_sec[tv_match.end():]

    # Also add the cov_def block after TV definitions, before scaling
    # Find the scaling line (S1=V1/1000 or S2=V2/1000) and insert before it
    scaling_match = re.search(r"^\s*S[12]\s*=", pk_sec, re.MULTILINE)
    if scaling_match and cov_def:
        pk_sec = pk_sec[:scaling_match.start()] + cov_def + "\n\n" + pk_sec[scaling_match.start():]

    sections["$PK"] = pk_sec

    # Append THETA
    theta_sec = theta_sec.rstrip() + "\n" + coef_line
    sections["$THETA"] = theta_sec

    return sections


def action_swap_template(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Swap structural model template.

    Replaces everything from $SUBROUTINES through $SIGMA with the selected
    template's body.  Preserves $INPUT and $DATA.
    """
    template_id = params["template_id"]
    run_id = str(params.get("run_id", extract_run_id(rebuild_mod(sections)) or "001"))
    spec = TEMPLATES.get(template_id)
    if not spec:
        raise ValueError(f"Unknown template: {template_id}.  Available: {sorted(TEMPLATES)}")

    input_sec = sections.get("$INPUT", "$INPUT C ID CYCLE DAY TIME NTIME DV AMT RATE DUR CMT DOSE MDV EVID BQL TYPE STUDY SEX WT AGE")
    data_sec = sections.get("$DATA", "$DATA NM_dat_new.csv IGNORE=C")

    # Remove old structural sections
    for label in list(sections.keys()):
        if label in ("$SUBROUTINES", "$MODEL", "$PK", "$DES", "$ERROR", "$THETA", "$OMEGA", "$SIGMA"):
            del sections[label]

    # Build new body from template
    new_body = spec.body  # template body includes $SUBROUTINES through $SIGMA

    # Extract the new sections from the template body
    new_sections = parse_sections(new_body)
    for label, text in new_sections.items():
        sections[label] = text

    # Rebuild $TABLE with correct run ID
    max_eta = find_eta_count(new_body)
    eta_terms = " ".join(f"ETA{i}" for i in range(1, max_eta + 1))
    # Remove old $TABLE sections
    sections = {k: v for k, v in sections.items() if not k.startswith("$TABLE")}
    sections["$TABLE"] = _tables(run_id, eta_terms)  # type: ignore

    return sections


def action_add_iiv(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Add IIV (diagonal OMEGA) to a parameter.

    Params: {"param": "Q", "init": 0.04}
    """
    param = params["param"]
    init_var = float(params.get("init", 0.09))

    pk_sec = sections.get("$PK", "")
    omega_sec = sections.get("$OMEGA", "")

    # Check if ETA already exists for this parameter
    all_text = rebuild_mod(sections)
    existing_etas = set()
    for m in re.finditer(r"\bETA\s*\(\s*(\d+)\s*\)", all_text, re.IGNORECASE):
        existing_etas.add(int(m.group(1)))

    next_eta = max(existing_etas) + 1 if existing_etas else 1

    # Add ETA to the parameter assignment in $PK
    tv_pattern = re.compile(rf"(TV{param}\s*=\s*THETA\s*\(\s*\d+\s*\))", re.IGNORECASE)
    tv_match = tv_pattern.search(pk_sec)
    if tv_match:
        new_assignment = f"{tv_match.group(1)}\n{param.upper()} = TV{param.upper()} * EXP(ETA({next_eta}))"

        # Remove existing non-TV {param} assignment if on next line
        rest = pk_sec[tv_match.end():]
        rest = re.sub(
            rf"^\s*{param.upper()}\s*=.*",
            "",
            rest,
            count=1,
            flags=re.MULTILINE
        )
        pk_sec = pk_sec[:tv_match.end()] + "\n" + new_assignment.split("\n")[1] + rest
        # Actually simpler: just check if there's already an EXP(ETA) line
        if rf"{param.upper()} = TV{param.upper()} * EXP(ETA({next_eta}))" not in pk_sec.upper():
            # Check if there's an existing non-covariate assignment
            existing_assign = re.search(
                rf"^{param.upper()}\s*=\s*TV{param.upper()}",
                pk_sec,
                re.MULTILINE,
            )
            if existing_assign:
                # Already has EXP(ETA) with some index — nothing to do
                if "EXP(ETA" in existing_assign.group():
                    return sections
                # Replace bare TV* line with EXP(ETA)
                old_line = existing_assign.group()
                indent = re.match(r"^\s*", old_line).group()
                new_line = f"{indent}{param.upper()} = TV{param.upper()} * EXP(ETA({next_eta}))"
                pk_sec = pk_sec[:existing_assign.start()] + new_line + pk_sec[existing_assign.end():]

    sections["$PK"] = pk_sec

    # Add OMEGA diagonal
    omega_sec = omega_sec.rstrip() + f"\n{init_var} ; IIV {param}"

    # Convert to BLOCK if needed (for correlated IIV — skip for now, just diagonal)
    sections["$OMEGA"] = omega_sec

    return sections


def action_diversify_iiv(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Perturb identical positive OMEGA initials to help covariance stability."""
    omega_sec = sections.get("$OMEGA", "")
    lines = omega_sec.splitlines()
    positive_rows: List[tuple] = []
    in_block = False

    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.upper().startswith("$OMEGA"):
            continue
        if stripped.upper().startswith("BLOCK"):
            in_block = True
            continue
        if in_block:
            continue
        value_part = stripped.split(";", 1)[0].strip()
        if not value_part:
            continue
        value_token = value_part.split()[0]
        try:
            value = float(value_token)
        except ValueError:
            continue
        if value > 0:
            positive_rows.append((index, value))

    if len(positive_rows) < 2:
        return sections
    if len({round(value, 8) for _, value in positive_rows}) > 1:
        return sections

    base = positive_rows[0][1]
    factors = (1.0, 1.2, 0.8, 1.4, 0.6, 1.6, 0.9, 1.1)
    for offset, (line_index, _) in enumerate(positive_rows):
        new_value = base * factors[offset % len(factors)]
        new_token = f"{new_value:.6g}"
        parts = lines[line_index].split(None, 1)
        if parts:
            lines[line_index] = new_token + ((" " + parts[1]) if len(parts) > 1 else "")

    sections["$OMEGA"] = "\n".join(lines)
    return sections


def action_fix_table_content(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Rebuild $TABLE records from actual $INPUT, $PK and ETA references."""
    run_id = str(params.get("run_id", extract_run_id(rebuild_mod(sections)) or "001"))
    input_sec = sections.get("$INPUT", "")
    input_tokens_raw = re.findall(r"\b[A-Z][A-Z0-9_]*\b", input_sec)
    input_tokens = [
        token.upper()
        for token in input_tokens_raw
        if token.upper() not in ("INPUT", "C")
    ]

    pk_sec = sections.get("$PK", "")
    pk_params: List[str] = []
    for match in re.finditer(r"\bTV([A-Z][A-Z0-9_]*)\s*=\s*THETA", pk_sec, re.IGNORECASE):
        param = match.group(1).upper()
        if param not in pk_params:
            pk_params.append(param)
    for match in re.finditer(
        r"\b([A-Z][A-Z0-9_]*)\s*=\s*(?:TV[A-Z][A-Z0-9_]*|THETA\s*\()",
        pk_sec,
        re.IGNORECASE,
    ):
        param = match.group(1).upper()
        if param not in pk_params and not param.startswith("TV"):
            pk_params.append(param)

    eta_count = find_eta_count(rebuild_mod(sections))
    eta_terms = " ".join(f"ETA{index}" for index in range(1, eta_count + 1))

    sdtab_tokens: List[str] = []
    for token in ["TIME", "DV", "MDV", "PRED", "IPRED", "CWRES", "CIWRES"] + input_tokens:
        if token not in sdtab_tokens:
            sdtab_tokens.append(token)
    if "ID" in sdtab_tokens:
        sdtab_tokens.remove("ID")
    if "STUDY" not in sdtab_tokens and "STUDY" in input_tokens:
        sdtab_tokens.append("STUDY")

    cat_cols = [
        token for token in input_tokens
        if token in ("SEX", "STUDY", "ADA", "ROUTE", "BQL", "TYPE", "CMT", "EVID", "MDV")
    ]
    cont_cols = [
        token for token in input_tokens
        if token in ("WT", "AGE", "DOSE", "AMT", "RATE", "DUR")
    ]
    cat_cols = [token for token in cat_cols if token != "ID"]
    cont_cols = [token for token in cont_cols if token != "ID"]

    params_text = " ".join(pk_params) if pk_params else "CL V"
    table_block = f"""$TABLE ID {" ".join(sdtab_tokens)} ONEHEADER NOPRINT NOAPPEND FILE=sdtab{run_id} FORMAT=s1PE14.7
$TABLE ID {params_text}{(" " + eta_terms) if eta_terms else ""} NOPRINT NOAPPEND ONEHEADER FILE=patab{run_id}
$TABLE ID {eta_terms} FIRSTONLY NOAPPEND NOPRINT FILE=run{run_id}.ETA
$TABLE ID {" ".join(cat_cols)} FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab{run_id}
$TABLE ID {" ".join(cont_cols)} FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab{run_id}"""
    sections["$TABLE"] = table_block
    return sections


def action_fix_residual_error(sections: SectionMap, params: Dict[str, Any]) -> SectionMap:
    """Fix $ERROR block to combined proportional + additive form."""
    error_sec = sections.get("$ERROR", "")
    prop_sd = float(params.get("prop_sd", 0.2))
    add_sd = float(params.get("add_sd", 0.01))

    new_error = f"""$ERROR
IPRED = F
W = SQRT((THETA({find_theta_count(rebuild_mod(sections)) - 1})*IPRED)**2 + THETA({find_theta_count(rebuild_mod(sections))})**2)
IF (W.LE.1E-12) W = 1E-12
Y = IPRED + W*EPS(1)
IRES = DV-IPRED
IWRES = IRES/W"""
    sections["$ERROR"] = new_error

    # Add THETA for prop/add if needed
    theta_sec = sections.get("$THETA", "")
    current_count = find_theta_count(rebuild_mod(sections))

    # Check if the last two THETAs are prop/add
    lines = [l for l in theta_sec.splitlines() if l.strip() and not l.strip().startswith("$THETA") and not l.strip().startswith(";")]
    has_prop = any("Prop.RE" in l for l in lines[-3:])
    has_add = any("Add.RE" in l for l in lines[-3:])

    if not has_prop:
        theta_sec += f"\n(0, {prop_sd}, 2) ; Prop.RE (sd)"
    if not has_add:
        theta_sec += f"\n(0, {add_sd}, 10) ; Add.RE (sd)"

    sections["$THETA"] = theta_sec
    return sections


# ---------------------------------------------------------------------------
# Action registry
# ---------------------------------------------------------------------------

ACTION_REGISTRY = {
    "bump_run": action_bump_run,
    "fix_input": action_fix_input,
    "fix_data": action_fix_data,
    "fix_table_ids": action_fix_table_ids,
    "fix_table_content": action_fix_table_content,
    "fix_theta_boundaries": action_fix_theta_boundaries,
    "diversify_iiv": action_diversify_iiv,
    "add_covariate": action_add_covariate,
    "swap_template": action_swap_template,
    "add_iiv": action_add_iiv,
    "fix_residual_error": action_fix_residual_error,
}


# ---------------------------------------------------------------------------
# Main transformer
# ---------------------------------------------------------------------------

def apply_modifications(
    source_text: str,
    modifications: List[Modification],
) -> str:
    """Apply a sequence of modifications to a .mod file.

    Parameters
    ----------
    source_text : str
        Full text of the source .mod file.
    modifications : list of Modification
        Ordered list of modifications to apply.

    Returns
    -------
    str — modified .mod text.
    """
    sections = parse_sections(strip_inline_dataset_rows(source_text))

    for mod in modifications:
        fn = ACTION_REGISTRY.get(mod.action)
        if not fn:
            print(f"[model_generator] Unknown action: {mod.action}", file=sys.stderr)
            continue
        sections = fn(sections, mod.params)

    run_id = extract_run_id(rebuild_mod(sections))
    if run_id:
        sections = ensure_eta_table(sections, run_id)

    # Normalize section order
    return strip_inline_dataset_rows(rebuild_mod(sections))


def apply_structured(
    source_text: str,
    decision: Dict[str, Any],
) -> str:
    """Convenience: convert a structured LLM decision dict into modifications
    and apply them.

    Expected decision format::

        {
            "actions": [
                {"action": "bump_run", "params": {"old_run": "41", "new_run": "42"}},
                {"action": "add_covariate", "params": {"param": "CL", ...}}
            ]
        }
    """
    modifications = [Modification(action=a["action"], params=a.get("params", {}))
                     for a in decision.get("actions", [decision])]
    return apply_modifications(source_text, modifications)


def generate_from_template(
    template_id: str,
    run_id: str,
    data_file: str = "NM_dat_new.csv",
    input_columns: Optional[List[str]] = None,
    problem: Optional[str] = None,
) -> str:
    """Generate a clean starting model from an AutoPMX template."""
    if input_columns is None:
        input_columns = ["C", "ID", "CYCLE", "DAY", "TIME", "NTIME", "DV",
                         "AMT", "RATE", "DUR", "CMT", "DOSE", "MDV", "EVID",
                         "BQL", "TYPE", "STUDY", "SEX", "WT", "AGE"]
    return render_model(template_id, run_id, data_file, input_columns, problem)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description="NONMEM model generator / transformer")
    sub = parser.add_subparsers(dest="command")

    # generate-from-template
    gen = sub.add_parser("generate")
    gen.add_argument("--template", default="iv_infusion_2c_advan3_trans4")
    gen.add_argument("--run", default="001")
    gen.add_argument("--data", default="NM_dat_new.csv")
    gen.add_argument("--output", type=Path, required=True)

    # transform
    tform = sub.add_parser("transform")
    tform.add_argument("--source", type=Path, required=True)
    tform.add_argument("--modifications", type=str,
                       help="JSON string: list of {action, params}")
    tform.add_argument("--output", type=Path, required=True)

    args = parser.parse_args()

    if args.command == "generate":
        text = generate_from_template(args.template, args.run, args.data)
        args.output.write_text(text, encoding="utf-8")
        print(f"Generated {args.output}")
        return 0

    if args.command == "transform":
        source = args.source.read_text(encoding="utf-8")
        mods_data = json.loads(args.modifications)
        mods = [Modification(**m) for m in mods_data]
        result = apply_modifications(source, mods)
        args.output.write_text(result, encoding="utf-8")
        print(f"Wrote {args.output}")
        return 0

    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
