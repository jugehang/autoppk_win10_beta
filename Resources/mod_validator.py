#!/usr/bin/env python3
"""Static NONMEM .mod preflight validator.

Catches common control-stream errors *before* NONMEM runs, so the automation
loop never submits a manifestly broken model.  Each check returns a structured
result: the caller decides whether to reject, warn, or fix automatically.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set


def _is_numeric_token(token: str) -> bool:
    if token == ".":
        return True
    try:
        float(token)
        return True
    except ValueError:
        return False


def _is_likely_data_row(tokens: List[str]) -> bool:
    if len(tokens) < 2:
        return False
    first = tokens[0]
    numeric_count = sum(1 for token in tokens if _is_numeric_token(token))
    return first == "." or _is_numeric_token(first) or numeric_count >= max(2, len(tokens) // 2)


# ---------------------------------------------------------------------------
# Severity levels
# ---------------------------------------------------------------------------

@dataclass
class ValidationIssue:
    severity: str          # "error" | "warning"
    section: str           # e.g. "$INPUT", "$PK", "$THETA"
    line_number: int       # 1‑based
    message: str           # human‑readable description
    fix_hint: str          # short suggestion (may mention auto‑fix)
    auto_fixable: bool     # can ModGenerator fix this deterministically?


@dataclass
class ValidationResult:
    path: Path
    issues: List[ValidationIssue] = field(default_factory=list)
    critical_count: int = 0   # count of "error" severity issues

    @property
    def passed(self) -> bool:
        return self.critical_count == 0

    def summary(self) -> str:
        total = len(self.issues)
        if not total:
            return f"✓ {self.path.name}: passed"
        lines = [f"{'✗' if not self.passed else '⚠'} {self.path.name}: "
                 f"{self.critical_count} error(s), {total - self.critical_count} warning(s)"]
        for iss in self.issues:
            prefix = "ERROR" if iss.severity == "error" else "WARN"
            lines.append(f"  [{prefix}] L{iss.line_number} {iss.section}: {iss.message}")
            lines.append(f"         → {iss.fix_hint}")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

def _line_number(text: str, offset: int) -> int:
    """Convert byte offset to 1‑based line number."""
    return text[:offset].count("\n") + 1


def _section_boundaries(text: str) -> List[tuple]:
    """Return [(label, start_offset, end_offset), …] for each $‑record."""
    boundaries: List[tuple] = []
    pattern = re.compile(r"^\s*(\$\w+)", re.MULTILINE)
    for m in pattern.finditer(text):
        label = m.group(1).upper()
        start = m.start()
        # Find next $‑record boundary
        next_m = pattern.search(text, m.end())
        end = next_m.start() if next_m else len(text)
        boundaries.append((label, start, end))
    return boundaries


def _section_text(text: str, label: str) -> Optional[str]:
    """Return the full text of the first $label record."""
    for lbl, start, end in _section_boundaries(text):
        if lbl == label:
            return text[start:end]
    return None


def _all_section_texts(text: str, label: str) -> List[str]:
    return [text[s:e] for lbl, s, e in _section_boundaries(text) if lbl == label]


def _normalized_parameter_name(raw: str) -> str:
    """Normalize a THETA/OMEGA label to a comparable parameter name."""
    name = raw.strip().upper()
    if name.startswith("IIV "):
        name = name[4:].strip()
    if name.startswith("TV"):
        name = name[2:]
    name = re.sub(r"\s*\(.*\)\s*$", "", name)
    return name.strip()


def _pk_param_names(text: str) -> List[str]:
    """Return upper-case PK parameters defined from THETA or TV typical values."""
    pk_section = _section_text(text, "$PK") or ""
    names: List[str] = []
    for match in re.finditer(
        r"\b([A-Z][A-Z0-9_]*)\s*=\s*(?:TV[A-Z][A-Z0-9_]*|THETA\s*\(|(?:[A-Z0-9_]*\s*\*\s*)?EXP\s*\(\s*ETA)",
        pk_section,
        re.IGNORECASE,
    ):
        name = match.group(1).upper()
        if name not in names and not name.startswith("TV"):
            names.append(name)
    return names


def _input_tokens(text: str) -> List[str]:
    input_section = _section_text(text, "$INPUT")
    if not input_section:
        return []
    tokens = re.split(r"\s+", input_section.strip())
    return [
        token.split("=", 1)[0].upper()
        for token in tokens
        if token.upper() != "$INPUT"
    ]


def check_content_before_problem(lines: list, text: str) -> List[ValidationIssue]:
    """Reject non-comment content that appears before $PROBLEM."""
    issues: List[ValidationIssue] = []
    problem_index = None
    for idx, raw_line in enumerate(lines, start=1):
        stripped = raw_line.strip()
        if stripped.upper().startswith("$PROBLEM") or stripped.upper().startswith("$PROB "):
            problem_index = idx
            break

    if problem_index is None:
        issues.append(ValidationIssue(
            severity="error",
            section="Header",
            line_number=0,
            message="No $PROBLEM record found; model should start with $PROBLEM",
            fix_hint="Prepend $PROBLEM with a brief run/model description",
            auto_fixable=True,
        ))
        return issues

    for idx, raw_line in enumerate(lines[:problem_index - 1], start=1):
        stripped = raw_line.strip()
        if stripped and not stripped.startswith(";"):
            issues.append(ValidationIssue(
                severity="error",
                section="Header",
                line_number=idx,
                message="Unexpected content before $PROBLEM (possible leaked OMEGA/CSV rows)",
                fix_hint="Remove all non-comment content before $PROBLEM",
                auto_fixable=True,
            ))
    return issues


def check_section_order(text: str) -> List[ValidationIssue]:
    """Verify $PROBLEM → $INPUT → $DATA → ... → $TABLE order."""
    issues: List[ValidationIssue] = []
    canonical = [
        "$PROBLEM",
        "$INPUT",
        "$DATA",
        "$SUBROUTINES",
        "$MODEL",
        "$PK",
        "$DES",
        "$ERROR",
        "$THETA",
        "$OMEGA",
        "$SIGMA",
        "$ESTIMATION",
        "$COVARIANCE",
        "$TABLE",
    ]

    def normalize_label(label: str) -> str:
        if label == "$EST":
            return "$ESTIMATION"
        if label == "$COV":
            return "$COVARIANCE"
        return label

    positions: Dict[str, int] = {}
    for lbl, start, _ in _section_boundaries(text):
        label = normalize_label(lbl)
        positions.setdefault(label, _line_number(text, start))

    seen: Set[str] = set()
    for label in canonical:
        if label not in positions:
            continue
        for earlier in canonical:
            if earlier == label:
                break
            if earlier in positions and positions[earlier] > positions[label]:
                if label not in seen:
                    issues.append(ValidationIssue(
                        severity="error",
                        section=label,
                        line_number=positions[label],
                        message=f"{label} appears before {earlier}; section order is wrong",
                        fix_hint="Rebuild the control stream in canonical NONMEM section order",
                        auto_fixable=True,
                    ))
                    seen.add(label)

    return issues


def check_pk_theta_omega_labels(text: str) -> List[ValidationIssue]:
    """Check OMEGA labels against PK ETA parameters and flag TV-prefixed labels."""
    issues: List[ValidationIssue] = []
    omega_sections = _all_section_texts(text, "$OMEGA")
    if not omega_sections:
        return issues

    omega_labels: Dict[str, int] = {}
    for section in omega_sections:
        for line_num, line in enumerate(section.splitlines(), start=1):
            stripped = line.strip()
            if not stripped or stripped.upper().startswith("$OMEGA") or stripped.upper().startswith("BLOCK"):
                continue
            if ";" not in line:
                continue
            label_raw = line.split(";", 1)[1]
            label = _normalized_parameter_name(label_raw)
            if not label:
                continue
            absolute_line = _line_number(text, text.find(section)) + line_num - 1
            raw_upper = label_raw.strip().upper()
            if raw_upper.startswith("IIV TV") or raw_upper.startswith("TV"):
                issues.append(ValidationIssue(
                    severity="error",
                    section="$OMEGA",
                    line_number=absolute_line,
                    message=f"OMEGA label '{label_raw.strip()}' should not start with TV; use IIV {label}",
                    fix_hint="Strip the TV prefix from OMEGA labels",
                    auto_fixable=True,
                ))
            if label in omega_labels:
                issues.append(ValidationIssue(
                    severity="error",
                    section="$OMEGA",
                    line_number=absolute_line,
                    message=f"Duplicate OMEGA label '{label}'",
                    fix_hint="Keep one OMEGA entry per PK parameter",
                    auto_fixable=True,
                ))
            omega_labels[label] = absolute_line

    pk_section = _section_text(text, "$PK") or ""
    eta_to_param: Dict[int, str] = {}
    for match in re.finditer(
        r"\b([A-Z][A-Z0-9_]*)\s*=.*?EXP\s*\(\s*ETA\s*\(\s*(\d+)\s*\)",
        pk_section,
        re.IGNORECASE,
    ):
        param = match.group(1).upper()
        eta = int(match.group(2))
        eta_to_param.setdefault(eta, param)

    for eta in sorted(eta_to_param):
        expected = eta_to_param[eta]
        if expected not in omega_labels:
            # Unlabeled OMEGA blocks are still accepted; only flag when labels
            # exist for other parameters, because the model is then inconsistent.
            if omega_labels:
                issues.append(ValidationIssue(
                    severity="warning",
                    section="$OMEGA",
                    line_number=0,
                    message=f"ETA({eta}) uses '{expected}' but no matching OMEGA label was found",
                    fix_hint=f"Label the OMEGA entry for ETA({eta}) as IIV {expected}",
                    auto_fixable=True,
                ))
    return issues


def check_subroutine_route(text: str) -> List[ValidationIssue]:
    """Check ADVAN family against KA/S1/S2 usage in $PK."""
    issues: List[ValidationIssue] = []
    subroutine_section = _section_text(text, "$SUBROUTINES")
    if not subroutine_section:
        issues.append(ValidationIssue(
            severity="error",
            section="$SUBROUTINES",
            line_number=0,
            message="No $SUBROUTINES record found",
            fix_hint="Add $SUBROUTINES with the correct ADVAN/TRANS for the route",
            auto_fixable=False,
        ))
        return issues

    subroutine_line = _line_number(text, text.find("$SUBROUTINES"))
    advan_match = re.search(r"ADVAN\s*(\d+)", subroutine_section, re.IGNORECASE)
    advan = int(advan_match.group(1)) if advan_match else 0
    pk_section = _section_text(text, "$PK") or ""
    has_ka = bool(re.search(r"\bKA\s*=", pk_section, re.IGNORECASE))
    has_real_ka = bool(
        re.search(r"\bKA\s*=\s*(?:TVKA|[A-Z0-9_]*\s*\*\s*EXP)", pk_section, re.IGNORECASE)
    )
    has_s1 = bool(re.search(r"\bS1\s*=", pk_section, re.IGNORECASE))
    has_s2 = bool(re.search(r"\bS2\s*=", pk_section, re.IGNORECASE))
    is_iv = advan in (1, 3, 11)
    is_extra = advan in (2, 4, 12)

    if is_iv and has_real_ka:
        issues.append(ValidationIssue(
            severity="error",
            section="$SUBROUTINES",
            line_number=subroutine_line,
            message=f"ADVAN{advan} is IV-only but $PK contains a real KA absorption term",
            fix_hint="Switch to an extravascular ADVAN (ADVAN2/4/12) or remove KA",
            auto_fixable=False,
        ))
    if is_extra and not has_ka:
        issues.append(ValidationIssue(
            severity="error",
            section="$SUBROUTINES",
            line_number=subroutine_line,
            message=f"ADVAN{advan} is extravascular but $PK has no KA absorption parameter",
            fix_hint="Add KA or switch to an IV ADVAN (ADVAN1/3/11)",
            auto_fixable=False,
        ))
    if is_extra and has_s1 and not has_s2:
        issues.append(ValidationIssue(
            severity="error",
            section="$PK",
            line_number=_line_number(text, text.find("$PK")),
            message=f"ADVAN{advan} extravascular model uses S1 but no S2 scaling",
            fix_hint="Use S2=... as the last $PK line for extravascular models",
            auto_fixable=False,
        ))
    if is_iv and has_s2 and not has_s1:
        issues.append(ValidationIssue(
            severity="error",
            section="$PK",
            line_number=_line_number(text, text.find("$PK")),
            message=f"ADVAN{advan} IV model uses S2 but no S1 scaling",
            fix_hint="Use S1=... as the last $PK line for IV models",
            auto_fixable=False,
        ))
    return issues


def check_table_content(text: str, run_id: str) -> List[ValidationIssue]:
    """Ensure TABLE records only reference known input/PK/ETA tokens."""
    issues: List[ValidationIssue] = []
    input_cols = set(_input_tokens(text))
    pk_params = set(_pk_param_names(text))
    eta_terms = set()
    for match in re.finditer(r"\bETA\s*\(\s*(\d+)\s*\)", text, re.IGNORECASE):
        eta_terms.add(f"ETA{match.group(1)}")

    core_sdtab = {"ID", "TIME", "DV", "MDV", "PRED", "IPRED", "CWRES", "CIWRES"}
    ignored_keywords = {
        "$TABLE", "ID", "ONEHEADER", "NOPRINT", "NOAPPEND", "FIRSTONLY", "FORMAT",
    }

    for table_start, table_block in _all_table_blocks(text):
        line_number = _line_number(text, table_start)
        upper = table_block.upper()
        is_sdtab = "FILE=SDTAB" in upper or "FILE= SDTAB" in upper
        is_eta_table = ("FILE=RUN" in upper and ".ETA" in upper) or "FILE=000" in upper
        is_patab = "FILE=PATAB" in upper
        allowed: Optional[Set[str]] = None
        if is_sdtab:
            allowed = core_sdtab | input_cols
        elif is_patab:
            allowed = {"ID"} | pk_params | eta_terms
        elif is_eta_table:
            allowed = {"ID"} | eta_terms

        if allowed is None:
            continue
        tokens = re.split(r"\s+", table_block.strip())
        for token in tokens:
            bare = token.strip(",;").upper()
            if not bare or bare in ignored_keywords:
                continue
            if bare.startswith("FILE=") or bare.startswith("FORMAT="):
                continue
            if bare not in allowed:
                issues.append(ValidationIssue(
                    severity="warning",
                    section="$TABLE",
                    line_number=line_number,
                    message=f"Table token '{bare}' is not an input/PK/ETA item",
                    fix_hint="Rebuild $TABLE records from the actual $INPUT, $PK and ETA list",
                    auto_fixable=True,
                ))
                break
    return issues


def _all_table_blocks(text: str) -> List[tuple]:
    blocks: List[tuple] = []
    offset = 0
    while True:
        match = re.search(r"(?im)^\s*\$TABLE", text[offset:])
        if not match:
            break
        start = offset + match.start()
        end = text.find("\n$", start + 1)
        if end < 0:
            end = len(text)
        blocks.append((start, text[start:end]))
        offset = end + 1
    return blocks


def check_iiv_initial_values(text: str) -> List[ValidationIssue]:
    """Warn when all estimated OMEGA initials are identical."""
    issues: List[ValidationIssue] = []
    omega_sections = _all_section_texts(text, "$OMEGA")
    values: List[tuple] = []  # (line_number, value, raw_line)
    for section in omega_sections:
        base_line = _line_number(text, text.find(section))
        in_block = False
        for offset, line in enumerate(section.splitlines(), start=1):
            stripped = line.strip()
            if not stripped or stripped.upper().startswith("$OMEGA"):
                continue
            if stripped.upper().startswith("BLOCK"):
                in_block = True
                continue
            if in_block:
                continue
            value_token = stripped.split(";", 1)[0].strip().split()[0] if stripped.split(";", 1)[0].strip() else ""
            try:
                value = float(value_token)
            except ValueError:
                continue
            if value > 0:
                values.append((base_line + offset - 1, value, stripped))

    if len(values) >= 2:
        positive_values = {round(value, 8) for _, value, _ in values}
        if len(positive_values) == 1:
            first_line = values[0][0]
            issues.append(ValidationIssue(
                severity="error",
                section="$OMEGA",
                line_number=first_line,
                message="All estimated IIV initial values are identical; this can destabilize the covariance step",
                fix_hint="Give each positive OMEGA a slightly different initial value",
                auto_fixable=True,
            ))
    return issues


def check_handoff_residual_fix(text: str) -> List[ValidationIssue]:
    """IV-anchor handoffs must not inherit fixed residual-error THETAs."""
    upper = text.upper()
    is_handoff = ("IV-ANCHOR HANDOFF" in upper
                  or "INHERITED IV STRUCTURAL THETA/OMEGA ARE FIXED" in upper
                  or "INHERITED IV THETA/OMEGA ARE FIXED" in upper)
    if not is_handoff:
        return []

    issues: List[ValidationIssue] = []
    theta_section = _section_text(text, "$THETA")
    if not theta_section:
        return issues

    for line_number, line in enumerate(theta_section.splitlines(), start=1):
        stripped = line.strip()
        if "FIX" not in stripped.upper():
            continue
        if re.search(r"Prop\.?\s*RE|Add\.?\s*RE|Prop\.?\s*err|Add\.?\s*err", stripped, re.IGNORECASE):
            absolute_line = _line_number(text, text.find(theta_section)) + line_number - 1
            issues.append(ValidationIssue(
                severity="error",
                section="$THETA",
                line_number=absolute_line,
                message="Residual error must not be FIXed in an IV-anchor full-dataset handoff",
                fix_hint="Remove FIX from Prop.RE/Add.RE so the mixed full dataset can estimate residual error",
                auto_fixable=False,
            ))
    return issues


# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------

def check_input_comment_column(lines: list, text: str) -> List[ValidationIssue]:
    """C=DROP / C=SKIP / omitted C when $DATA has IGNORE=C."""
    issues: List[ValidationIssue] = []
    data_ignore_c = False
    data_section = _section_text(text, "$DATA")
    if data_section and re.search(r"IGNORE\s*=\s*C", data_section, re.IGNORECASE):
        data_ignore_c = True

    input_section = _section_text(text, "$INPUT")
    if not input_section:
        return issues

    input_line_num = _line_number(text, text.find("$INPUT"))
    tokens = re.split(r"\s+", input_section.strip())
    col_set: Set[str] = set()
    has_c = False
    for tok in tokens:
        if tok.upper() == "$INPUT":
            continue
        base = tok.upper().split("=")[0]
        col_set.add(base)
        if base == "C":
            has_c = True
        if "C=" in tok.upper() and data_ignore_c:
            issues.append(ValidationIssue(
                severity="error",
                section="$INPUT",
                line_number=input_line_num,
                message=f"Illegal token '{tok}' while $DATA IGNORE=C is active",
                fix_hint="Keep C as a plain token.  Remove '=DROP', '=SKIP' etc.",
                auto_fixable=True,
            ))

    if not has_c and data_ignore_c:
        issues.append(ValidationIssue(
            severity="error",
            section="$INPUT",
            line_number=input_line_num,
            message="Missing C column in $INPUT while $DATA uses IGNORE=C",
            fix_hint="Prepend bare C to $INPUT tokens (AutoPMX convention)",
            auto_fixable=True,
        ))

    return issues


def check_inline_dataset_rows(lines: list, text: str) -> List[ValidationIssue]:
    """Reject CSV rows accidentally embedded after $INPUT or $DATA."""
    issues: List[ValidationIssue] = []
    active_section: Optional[str] = None
    flagged_sections: Set[str] = set()

    for line_number, raw_line in enumerate(lines, start=1):
        line = raw_line.strip()
        upper = line.upper()

        if upper.startswith("$"):
            if upper.startswith("$INPUT"):
                active_section = "$INPUT"
            elif upper.startswith("$DATA"):
                active_section = "$DATA"
            else:
                active_section = None
            continue

        if active_section not in ("$INPUT", "$DATA"):
            continue
        if not line or line.startswith(";"):
            continue

        tokens = line.split()
        if active_section not in flagged_sections and _is_likely_data_row(tokens):
            issues.append(ValidationIssue(
                severity="error",
                section=active_section,
                line_number=line_number,
                message="CSV data rows must not be embedded in the control stream",
                fix_hint="Remove the data rows; keep $INPUT/$DATA records only",
                auto_fixable=True,
            ))
            flagged_sections.add(active_section)

    return issues


def check_input_matches_csv(lines: list, text: str, csv_path: Optional[Path]) -> List[ValidationIssue]:
    """Check $INPUT order matches CSV header order (when CSV is reachable)."""
    issues: List[ValidationIssue] = []
    if not csv_path or not csv_path.exists():
        return issues

    csv_header = csv_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    if not csv_header:
        return issues
    expected_cols = [c.strip().strip("\"").upper() for c in csv_header[0].split(",") if c.strip()]

    input_section = _section_text(text, "$INPUT")
    if not input_section:
        return issues
    input_line_num = _line_number(text, text.find("$INPUT"))
    tokens = re.split(r"\s+", input_section.strip())
    input_cols = []
    for tok in tokens:
        if tok.upper() == "$INPUT":
            continue
        base = tok.upper().split("=")[0]
        # C should appear as literal C
        if base == "C" and tok != "C":
            # already flagged by check_input_comment_column
            input_cols.append("C")
        else:
            input_cols.append(base)

    # Only check first min(len) columns — CSV may have extra columns at end
    # that NONMEM doesn't read
    min_len = min(len(input_cols), len(expected_cols))

    mismatches = []
    for i in range(min_len):
        if input_cols[i] != expected_cols[i]:
            mismatches.append(f"col{i+1}: $INPUT has '{input_cols[i]}', CSV has '{expected_cols[i]}'")

    if len(input_cols) != len(expected_cols) and len(input_cols) < len(expected_cols):
        mismatches.append(f"$INPUT has {len(input_cols)} columns, CSV has {len(expected_cols)}")

    if mismatches:
        details = "; ".join(mismatches[:5])
        issues.append(ValidationIssue(
            severity="error",
            section="$INPUT",
            line_number=input_line_num,
            message=f"$INPUT column order mismatch ({details})",
            fix_hint="Run auto-fix with the CSV header as source of truth",
            auto_fixable=True,
        ))

    return issues


def check_theta_omega_count(lines: list, text: str) -> List[ValidationIssue]:
    """$THETA / $OMEGA count matches $PK references."""
    issues: List[ValidationIssue] = []

    # Count THETA definitions
    theta_sections = _all_section_texts(text, "$THETA")
    theta_count = 0
    for sec in theta_sections:
        sec_lines = sec.splitlines()
        for i, line in enumerate(sec_lines):
            stripped = line.strip()
            if i == 0 and stripped.upper().startswith("$THETA"):
                rest = stripped[6:].strip()
                if rest and re.search(r"\d", rest):
                    theta_count += 1
                continue
            if not stripped or stripped.startswith(";") or stripped.upper().startswith("$THETA"):
                continue
            theta_count += 1

    # Count OMEGA blocks
    omega_sections = _all_section_texts(text, "$OMEGA")
    omega_count = 0
    for sec in omega_sections:
        lines = sec.splitlines()
        in_block = False
        block_size = 0
        block_rows_seen = 0
        for line in lines:
            s = line.strip()
            if not s or s.startswith(";") or s.upper().startswith("$OMEGA"):
                continue
            if s.upper().startswith("BLOCK"):
                in_block = True
                block_size = 0
                block_rows_seen = 0
                # Parse BLOCK(n) — e.g. BLOCK(2) defines 2 ETAs
                m = re.search(r"BLOCK\s*\(\s*(\d+)\s*\)", s, re.IGNORECASE)
                if m:
                    block_size = int(m.group(1))
                    omega_count += block_size
                else:
                    # BLOCK without explicit size — count once (1 ETA)
                    omega_count += 1
                continue
            if in_block:
                # Inside BLOCK matrix rows — don't add new ETAs (already counted via BLOCK(n))
                pass
            else:
                omega_count += 1

    # Check which THETA(i) and ETA(i) are referenced in $PK and $ERROR
    pk_section = _section_text(text, "$PK") or _section_text(text, "$PK") or ""
    error_section = _section_text(text, "$ERROR") or ""
    combined_pk_err = pk_section + error_section

    max_theta_ref = 0
    max_eta_ref = 0
    for m in re.finditer(r"\bTHETA\s*\(\s*(\d+)\s*\)", combined_pk_err, re.IGNORECASE):
        idx = int(m.group(1))
        if idx > max_theta_ref:
            max_theta_ref = idx
    for m in re.finditer(r"\bETA\s*\(\s*(\d+)\s*\)", combined_pk_err, re.IGNORECASE):
        idx = int(m.group(1))
        if idx > max_eta_ref:
            max_eta_ref = idx

    theta_line_num = _line_number(text, text.find("$THETA")) if "$THETA" in text else 0

    if max_theta_ref > theta_count:
        issues.append(ValidationIssue(
            severity="error",
            section="$THETA",
            line_number=theta_line_num,
            message=f"$PK/$ERROR references THETA({max_theta_ref}) but only {theta_count} THETA(s) defined",
            fix_hint=f"Add {max_theta_ref - theta_count} more THETA record(s) with plausible initials",
            auto_fixable=False,
        ))

    omega_line_num = _line_number(text, text.find("$OMEGA")) if "$OMEGA" in text else 0
    if max_eta_ref > omega_count:
        issues.append(ValidationIssue(
            severity="error",
            section="$OMEGA",
            line_number=omega_line_num,
            message=f"$PK uses ETA({max_eta_ref}) but only {omega_count} OMEGA(s) defined",
            fix_hint=f"Add {max_eta_ref - omega_count} OMEGA diagonal or BLOCK records",
            auto_fixable=False,
        ))

    # Also check for common typo: NTIME=DUMP
    if re.search(r"NTIME\s*=\s*DUMP", combined_pk_err, re.IGNORECASE):
        issues.append(ValidationIssue(
            severity="error",
            section="$PK",
            line_number=_line_number(text, combined_pk_err.find("NTIME")),
            message="NTIME is a data item (not a $PK variable) — NTIME=DUMP is a data‑renaming directive, "
                    "not a valid $PK assignment",
            fix_hint="Remove NTIME=DUMP from $INPUT if NTIME is unused, or keep as NTIME",
            auto_fixable=True,
        ))

    return issues


def check_data_path(text: str, project_dir: Path) -> List[ValidationIssue]:
    """$DATA path resolves to a real file."""
    issues: List[ValidationIssue] = []
    m = re.search(r"(?im)^\s*\$DATA\s+(\S+)", text)
    if not m:
        issues.append(ValidationIssue(
            severity="error", section="$DATA", line_number=0,
            message="No $DATA record found",
            fix_hint="Add $DATA <filename> IGNORE=C",
            auto_fixable=True,
        ))
        return issues

    raw_path = m.group(1)
    data_line_num = _line_number(text, m.start())
    resolved = Path(raw_path)
    if not resolved.is_absolute():
        resolved = project_dir / raw_path

    if not resolved.exists():
        issues.append(ValidationIssue(
            severity="error", section="$DATA", line_number=data_line_num,
            message=f"$DATA file not found: {raw_path}",
            fix_hint=f"Update path to point to existing file in {project_dir}",
            auto_fixable=True,
        ))

    # Check IGNORE=C
    if "IGNORE=C" not in text[text.find("$DATA"):text.find("$DATA") + 200].upper():
        data_section = _section_text(text, "$DATA")
        if data_section:
            issues.append(ValidationIssue(
                severity="warning", section="$DATA", line_number=data_line_num,
                message="Missing IGNORE=C on $DATA (AutoPMX convention)",
                fix_hint="Add IGNORE=C to $DATA record",
                auto_fixable=True,
            ))

    return issues


def check_sigma_placement(text: str) -> List[ValidationIssue]:
    """$SIGMA must appear before $EST when EPS is used."""
    issues: List[ValidationIssue] = []

    est_pos = text.find("$EST")
    sigma_pos = text.find("$SIGMA")
    # EPS can be defined in $ERROR OR $PK; $SIGMA can go before or after $ERROR
    # but must be before $EST
    has_eps = bool(re.search(r"\bEPS\s*\(\s*1\s*\)", text[:est_pos + 2000] if est_pos > 0 else text, re.IGNORECASE))

    if has_eps and sigma_pos < 0:
        issues.append(ValidationIssue(
            severity="error", section="$SIGMA", line_number=0,
            message="EPS(1) used but $SIGMA is missing",
            fix_hint="Add $SIGMA 1 FIX before $EST",
            auto_fixable=True,
        ))
    elif has_eps and est_pos > 0 and sigma_pos > est_pos:
        issues.append(ValidationIssue(
            severity="error", section="$SIGMA",
            line_number=_line_number(text, sigma_pos),
            message="$SIGMA must appear BEFORE $EST",
            fix_hint="Move $SIGMA block before $ESTIMATION",
            auto_fixable=True,
        ))

    return issues


def check_table_files(text: str, run_id: str) -> List[ValidationIssue]:
    """$TABLE FILE= must use the correct run ID."""
    issues: List[ValidationIssue] = []
    fidx = 0
    while True:
        m = re.search(r"(?im)^\s*\$TABLE", text[fidx:])
        if not m:
            break
        table_start = fidx + m.start()
        table_end = text.find("\n$", table_start + 1)
        if table_end < 0:
            table_end = len(text)
        table_block = text[table_start:table_end]
        table_line_num = _line_number(text, table_start)

        # Check FILE=name
        file_match = re.search(r"FILE\s*=\s*(\S+)", table_block, re.IGNORECASE)
        if file_match:
            fname = file_match.group(1)
            # Common expected patterns: sdtab{run}, patab{run}, 000{run}.ETA,
            # run{run}.ETA, catab{run}, cotab{run}
            expected_extensions = {
                "SDTAB": "", "PATAB": "", "CATAB": "", "COTAB": "",
                "000": ".ETA",
                "RUN": ".ETA",
            }
            upper_fname = fname.upper()
            found_run = None
            for prefix, suffix in expected_extensions.items():
                if upper_fname.startswith(prefix) and upper_fname.endswith(suffix.upper()):
                    inner = upper_fname[len(prefix):]
                    if suffix:
                        inner = inner[:-len(suffix)] if suffix else inner
                    if inner.isdigit():
                        found_run = int(inner)
                    break
            if found_run is not None and found_run != int(run_id):
                issues.append(ValidationIssue(
                    severity="error", section="$TABLE", line_number=table_line_num,
                    message=f"Table file '{fname}' has run ID {found_run}, expected run {run_id}",
                    fix_hint=f"Change FILE={fname} to match run {run_id}",
                    auto_fixable=True,
                ))

        fidx = table_end + 1

    return issues


def check_residual_error_model(text: str) -> List[ValidationIssue]:
    """Warn on common $ERROR problems."""
    issues: List[ValidationIssue] = []
    pk_section = _section_text(text, "$ERROR")
    if not pk_section:
        return issues

    error_line_num = _line_number(text, text.find("$ERROR"))

    # Check IPRED = F
    if "IPRED" not in pk_section:
        issues.append(ValidationIssue(
            severity="warning", section="$ERROR", line_number=error_line_num,
            message="IPRED not defined in $ERROR (recommend: IPRED = F)",
            fix_hint="Add IPRED = F before residual error computation",
            auto_fixable=True,
        ))

    # Check for Y = ... + EPS(1) without SIGMA FIX
    if "Y =" in pk_section and "EPS(1)" in pk_section:
        has_sigma_fix = False
        sigma_sections = _all_section_texts(text, "$SIGMA")
        for sec in sigma_sections:
            if "FIX" in sec.upper():
                has_sigma_fix = True
                break
        if not has_sigma_fix:
            issues.append(ValidationIssue(
                severity="warning", section="$SIGMA", line_number=error_line_num,
                message="$SIGMA should typically be 1 FIX when EPS(1) is the residual error scale",
                fix_hint="Add $SIGMA 1 FIX",
                auto_fixable=True,
            ))

    return issues


def check_common_typos(text: str) -> List[ValidationIssue]:
    """Flag known NONMEM pitfalls."""
    issues: List[ValidationIssue] = []

    # NTIME=DUMP (common in $INPUT if present)
    m = re.search(r"(?im)NTIME\s*=\s*DUMP", text)
    if m:
        line_num = _line_number(text, m.start())
        issues.append(ValidationIssue(
            severity="error", section="$INPUT", line_number=line_num,
            message="NTIME=DUMP typo — DUMP is not a valid NONMEM destination",
            fix_hint="Use NTIME=DROP to discard the column, or keep as NTIME",
            auto_fixable=True,
        ))

    # Check for duplicate $ records (exclude $TABLE — multiple TABLE lines are valid)
    seen_labels = set()
    for lbl, s, _ in _section_boundaries(text):
        line_num = _line_number(text, s)
        if lbl in ("$PROBLEM", "$TABLE", "$THETA", "$OMEGA"):
            continue
        if lbl in seen_labels:
            issues.append(ValidationIssue(
                severity="error", section=lbl, line_number=line_num,
                message=f"Duplicate {lbl} record",
                fix_hint="Remove the duplicate record",
                auto_fixable=False,
            ))
        seen_labels.add(lbl)

    # 0 FIX on THETA that's too aggressive
    theta_section = _section_text(text, "$THETA")
    if theta_section:
        lines = theta_section.splitlines()
        for i, line in enumerate(lines):
            stripped = line.strip()
            if "FIX" in stripped.upper() and re.search(r"\(\s*0\s*\)", stripped):
                line_num = _line_number(text, text.find("$THETA") if "$THETA" in text else 0) + i
                issues.append(ValidationIssue(
                    severity="warning", section="$THETA", line_number=line_num,
                    message="THETA is FIXed at zero — parameter will never move from boundary",
                    fix_hint="Change to (0, initial, upper) or remove FIX",
                    auto_fixable=False,
                ))

    return issues


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def validate_mod(
    mod_path: Path,
    project_dir: Optional[Path] = None,
    csv_path: Optional[Path] = None,
    run_id: Optional[str] = None,
) -> ValidationResult:
    """Run all static checks on a .mod file.

    Parameters
    ----------
    mod_path : Path
        Path to the .mod file to validate.
    project_dir : Path, optional
        Project root (used to resolve relative $DATA paths).  Defaults to
        the parent of mod_path.
    csv_path : Path, optional
        Path to the dataset CSV (for $INPUT column matching).  If omitted
        the check that requires it is skipped.
    run_id : str, optional
        Expected run ID (for $TABLE file names).  If omitted, extracted from
        the filename (``run{run_id}.mod``).

    Returns
    -------
    ValidationResult
    """
    mod_path = Path(mod_path)
    project_dir = Path(project_dir) if project_dir else mod_path.parent
    if not run_id:
        m = re.match(r"run(\d+)", mod_path.stem, re.IGNORECASE)
        run_id = m.group(1) if m else "0"

    text = mod_path.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()

    # Run all checks
    check_fns = [
        check_content_before_problem,
        lambda l, t: check_section_order(t),
        check_input_comment_column,
        check_inline_dataset_rows,
        lambda l, t: check_input_matches_csv(l, t, csv_path),
        check_theta_omega_count,
        lambda l, t: check_pk_theta_omega_labels(t),
        lambda l, t: check_subroutine_route(t),
        lambda l, t: check_data_path(t, project_dir),
        lambda l, t: check_sigma_placement(t),
        lambda l, t: check_table_files(t, run_id),
        lambda l, t: check_table_content(t, run_id),
        lambda l, t: check_residual_error_model(t),
        lambda l, t: check_common_typos(t),
        lambda l, t: check_iiv_initial_values(t),
        lambda l, t: check_handoff_residual_fix(t),
    ]

    all_issues: List[ValidationIssue] = []
    for fn in check_fns:
        all_issues.extend(fn(lines, text))

    result = ValidationResult(path=mod_path, issues=all_issues,
                              critical_count=sum(1 for i in all_issues if i.severity == "error"))
    return result


def validate_mod_safe(
    mod_path: Path,
    project_dir: Optional[Path] = None,
    csv_path: Optional[Path] = None,
    run_id: Optional[str] = None,
) -> ValidationResult:
    """Non‑throwing wrapper around :func:`validate_mod`."""
    from .mod_validator import validate_mod
    try:
        return validate_mod(mod_path, project_dir, csv_path, run_id)
    except Exception as exc:
        return ValidationResult(
            path=Path(mod_path),
            issues=[ValidationIssue(
                severity="error", section="Validator", line_number=0,
                message=f"Validator crashed: {exc}",
                fix_hint="Fix the validator or check file encoding",
                auto_fixable=False,
            )],
            critical_count=1,
        )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description="Preflight check a NONMEM .mod file")
    parser.add_argument("mod_path", type=Path)
    parser.add_argument("--project-dir", type=Path, default=None)
    parser.add_argument("--csv", type=Path, default=None,
                        help="CSV dataset path (for $INPUT column validation)")
    parser.add_argument("--run-id", default=None)
    args = parser.parse_args()

    result = validate_mod(args.mod_path, args.project_dir, args.csv, args.run_id)
    print(result.summary())
    return 0 if result.passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
