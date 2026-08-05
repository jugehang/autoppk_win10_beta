#!/usr/bin/env python3
"""autopmx_ga.py — Hybrid GA optimizer for NONMEM PopPK models.

Supports two modes:

1. Parameter-only (default, backward-compatible):
   Optimizes THETA initial estimates within dynamic bounds.
   python3 autopmx_ga.py --mod run001.mod --project-dir /path/to/project --nmfe /opt/nm760/run/nmfe76

2. Structural search (--structural):
   Searches over model structure (ADVAN/compartments, error model, IIV, covariates)
   AND optimizes THETA values simultaneously.
   python3 autopmx_ga.py --mod run001.mod --project-dir /path/to/project --nmfe /opt/nm760/run/nmfe76 --structural

The script:
1. Reads THETA midpoints from the .mod control stream  (now (0, mid) format)
2. For structural mode: builds a mixed chromosome (categorical + continuous genes)
3. Runs NONMEM (nmfe) for each candidate
4. Parses OFV from the .lst output + extracts RSE/boundary/covariance diagnostics
5. Uses fitness = -OFV - complexity_penalty - diagnostic_penalties
6. Writes optimized .mod file and population CSV
"""

import argparse
import csv
import json
import math
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime

try:
    from model_generator import strip_inline_dataset_rows
except Exception:
    def strip_inline_dataset_rows(text):
        return text


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read_file(path):
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def write_file(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


# ---------------------------------------------------------------------------
# THETA parsing — simplified (0, mid) format
# ---------------------------------------------------------------------------

def parse_theta_midpoints(mod_text):
    """Extract THETA(0, middle) or THETA middle values from NONMEM control stream.

    Supports:
        (0, 5)        → lower=0, mid=5  (new format)
        (0, 0.2)      → lower=0, mid=0.2
        0.2           → lower=0, mid=0.2 (bare value)
        (0.1, 5, 50)  → lower=0.1, mid=5 (legacy format — mid=initial)
        (0, 5 FIX)    → lower=0, mid=5, fixed=True
        (0, 5) FIX    → lower=0, mid=5, fixed=True

    Returns list of dicts: [{'idx': 1, 'lower': 0, 'mid': 5.0, 'fixed': False}, ...]
    """
    thetas = []

    # Find $THETA block
    pattern = re.compile(r'\$THETA\s*\n(.*?)(?=\n\s*\$|\Z)', re.DOTALL | re.IGNORECASE)
    match = pattern.search(mod_text)
    if not match:
        return thetas

    block = match.group(1)

    # Match various THETA formats:
    #   (0, 5)        → 2-tuple
    #   (0, 5) FIX    → 2-tuple with FIX
    #   (0, 5 FIX)    → 2-tuple with FIX inside parens
    #   (0.1, 5, 50)  → legacy 3-tuple
    #   5             → bare value
    #   5 FIX         → bare value with FIX
    #   (0 FIX)       → fixed with no second value
    line_re = re.compile(r"""
        \(?\s*
        ([-+]?\d+\.?\d*(?:[Ee][+-]?\d+)?)\s*          # lower or only value
        (?:,\s*([-+]?\d+\.?\d*(?:[Ee][+-]?\d+)?)\s*)?  # middle (optional)
        (?:,\s*([-+]?\d+\.?\d*(?:[Ee][+-]?\d+)?)\s*)?  # upper (optional, legacy)
        \)?\s*
        (FIX\w*)?\s*                                     # optional FIX
        (?:;.*)?$
    """, re.VERBOSE | re.IGNORECASE)

    idx = 0
    for line in block.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(';'):
            continue

        m = line_re.match(stripped)
        if m:
            idx += 1
            a_str, b_str, c_str, fix_str = m.group(1), m.group(2), m.group(3), m.group(4)
            a = float(a_str)

            is_fixed = bool(fix_str and fix_str.upper().startswith("FIX"))

            if b_str is None and c_str is None:
                # Only one number: bare value or (0 FIX)
                # If a is 0 and there's a FIX, this is a fixed 0
                mid_val = a if a != 0 or not is_fixed else 1.0  # fallback
                thetas.append({
                    "idx": idx,
                    "lower": 0.0,
                    "mid": mid_val,
                    "fixed": is_fixed,
                })
            elif b_str is not None and c_str is None:
                # Two numbers: (lower, mid) or (mid, upper)?
                # In NONMEM, (0, 5) means lower=0, upper=5, initial=5.
                # We treat as: lower=0, mid=5 (initial guess)
                thetas.append({
                    "idx": idx,
                    "lower": a,
                    "mid": float(b_str),
                    "fixed": is_fixed,
                })
            else:
                # Three numbers: legacy (lower, initial, upper)
                thetas.append({
                    "idx": idx,
                    "lower": a,
                    "mid": float(b_str),
                    "fixed": is_fixed,
                })

    return thetas


def build_mod_with_thetas(template, thetas_dict):
    """Replace THETA midpoints in $THETA block with GA-chosen values.

    thetas_dict: {theta_index (1-based): new_midpoint_value}

    Output format: (0, value) for each THETA (or (0 FIX) for fixed).
    Also auto-injects S1=V/1000 (or V1, V2 for oral) if the model uses ADVAN1-4
    but is missing the scale parameter in $PK.
    """
    lines = template.splitlines()
    result = []
    in_theta = False
    theta_idx = 0
    theta_line_re = re.compile(r"""
        (\(?\s*[-+]?\d+\.?\d*(?:[Ee][+-]?\d+)?\s*(?:,\s*[-+]?\d+\.?\d*(?:[Ee][+-]?\d+)?\s*){0,2}\)?)\s*(FIX\w*)?\s*(;.*)?$
    """, re.VERBOSE)

    for line in lines:
        stripped = line.strip()

        if stripped.upper().startswith("$THETA") and not stripped.upper().startswith("$THETAP"):
            in_theta = True
            result.append(line)
            continue
        elif in_theta and stripped.startswith("$"):
            in_theta = False

        if in_theta:
            if not stripped or stripped.startswith(";"):
                result.append(line)
                continue

            m = theta_line_re.match(stripped)
            if m:
                theta_idx += 1
                is_fixed = bool(m.group(2) and m.group(2).upper().startswith("FIX"))
                comment = m.group(3) or ""

                if theta_idx in thetas_dict and not is_fixed:
                    new_val = thetas_dict[theta_idx]
                    # Format cleanly
                    if abs(new_val) < 0.001 or abs(new_val) >= 10000:
                        new_str = f"{new_val:.4E}".lower()
                    elif new_val == int(new_val):
                        new_str = f"{int(new_val)}"
                    else:
                        new_str = f"{new_val:.4g}"
                    result.append(f"  (0, {new_str}){comment}")
                elif is_fixed:
                    result.append(f"  (0 FIX){comment}")
                else:
                    result.append(line)
            else:
                result.append(line)
        else:
            result.append(line)

    updated = "\n".join(result)

    # --- Auto-inject scale parameter if needed ---
    # Check if ADVAN is 1-4 (need S1 or S2) and $PK is missing it
    advan_match = re.search(r'\$SUBROUTINE\w*\s+ADVAN(\d+)', updated, re.IGNORECASE)
    if advan_match:
        advan_num = int(advan_match.group(1))
        if advan_num in (1, 2, 3, 4):
            pk_text = updated.upper()
            has_scale = bool(re.search(r'\bS[12]\s*=', pk_text))
            if not has_scale:
                # Find the end of $PK block and inject the scale parameter
                # Look for the line before $ERROR
                pk_end_pattern = re.compile(r'(\n)(\$ERROR)', re.IGNORECASE)
                if advan_num == 2:
                    # Oral: S2 = V/1000 (or V2/1000)
                    scale_line = "\nS2 = V/1000\n"
                else:
                    # IV: try V1 first, then V
                    if re.search(r'\bV1\b', pk_text):
                        scale_line = "\nS1 = V1/1000\n"
                    else:
                        scale_line = "\nS1 = V/1000\n"

                updated = pk_end_pattern.sub(scale_line + r'\2', updated, count=1)
                if scale_line.strip().lower() not in updated.lower():
                    # Fallback: if the regex didn't match, try harder
                    pass

    return updated


# ---------------------------------------------------------------------------
# NONMEM interaction
# ---------------------------------------------------------------------------

def extract_ofv(lst_path):
    """Parse OFV from a NONMEM .lst file."""
    if not os.path.exists(lst_path):
        return None

    text = read_file(lst_path)

    patterns = [
        r'MINIMUM\s+VALUE\s+OF\s+OBJECTIVE\s+FUNCTION\s*[:=]?\s*([-+]?\d+\.?\d*(?:[Ee][+-]?\d+)?)',
        r'OBJV:\s*([-+]?\d+\.?\d*(?:[Ee][+-]?\d+)?)',
        r'OBJECTIVE\s+FUNCTION\s+VALUE\s*[:=]?\s*([-+]?\d+\.?\d*(?:[Ee][+-]?\d+)?)',
    ]

    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return float(match.group(1))

    return None


def extract_minimization_successful(lst_path):
    """Check if minimization was successful."""
    if not os.path.exists(lst_path):
        return False
    text = read_file(lst_path).upper()
    return "MINIMIZATION SUCCESSFUL" in text


def extract_covariance_successful(lst_path):
    """Check if covariance step was successful.

    Composite criteria (same as Swift runCovarianceOK):
    1. No abort/fail/R-matrix-PD signal in lst
    2. No boundary warning
    3. .cov file exists and non-empty
    4. ELAPSED COVARIANCE or COVARIANCE STEP SUCCESSFUL present in lst

    We do NOT require the literal string "COVARIANCE STEP SUCCESSFUL" — under FOCE/I
    (and in some batch outputs) NONMEM omits that exact line even when the step
    completed fine. "ELAPSED COVARIANCE" or "COVARIANCE STEP SUCCESSFUL" are both
    valid signals that the covariance step ran to completion.
    """
    if not os.path.exists(lst_path):
        return False
    text = read_file(lst_path)
    upper = text.upper()

    # Hard failures
    if ("COVARIANCE STEP ABORTED" in upper
            or "COVARIANCE STEP FAILED" in upper
            or "R MATRIX IS NOT POSITIVE DEFINITE" in upper):
        return False

    # Boundary indicates unstable estimates → covariance not trustworthy
    if "PARAMETER IS NEAR ITS BOUNDARY" in upper:
        return False

    # .cov file must exist and be non-empty
    cov_path = os.path.join(os.path.dirname(lst_path),
                            os.path.basename(lst_path).replace(".lst", ".cov"))
    if not os.path.exists(cov_path) or os.path.getsize(cov_path) == 0:
        return False

    # Covariance step must have actually run
    return ("ELAPSED COVARIANCE" in upper
            or "COVARIANCE STEP SUCCESSFUL" in upper)


def extract_rse_warnings(lst_path, max_rse=50.0):
    """Check if any parameter has RSE > max_rse.

    Returns (has_high_rse, max_rse_found, error_model_rse_info).
    error_model_rse_info: dict with keys 'prop_err_rse', 'add_err_rse', 'prop_err_boundary', 'add_err_boundary'
    """
    if not os.path.exists(lst_path):
        return (False, 0.0, {})

    text = read_file(lst_path)

    # Find RSE% values in the .lst output
    max_found = 0.0
    rse_pattern = re.compile(r'(\d{1,3}\.\d{1,2})\s*%?')
    in_rse_section = False

    for line in text.splitlines():
        if 'RSE' in line.upper() and '%' in line:
            in_rse_section = True
            continue
        if in_rse_section:
            matches = rse_pattern.findall(line)
            for m in matches:
                val = float(m)
                if val > max_found:
                    max_found = val

    has_high = max_found > max_rse

    # --- Extract error-model-specific RSE info ---
    error_model_info = _extract_error_model_rse_from_lst(text)

    return (has_high, max_found, error_model_info)


def _extract_error_model_rse_from_lst(lst_text):
    """Parse .lst to find RSE% for Prop.err (proportional) and Add.err (additive) THETAs.

    In NONMEM combined error model:
      W = SQRT(THETA(n)**2*IPRED**2 + THETA(n+1)**2)
      THETA(n)   = Prop.RE (sd)  → proportional error SD
      THETA(n+1) = Add.RE (sd)   → additive error SD

    We look for THETA labels containing 'Prop' or 'Add' (case-insensitive)
    and extract their RSE% from the parameter estimate table.

    Returns dict: {
        'prop_err_rse': float or None,
        'add_err_rse': float or None,
        'prop_err_boundary': bool,
        'add_err_boundary': bool,
        'prop_err_estimate': float or None,
        'add_err_estimate': float or None,
    }
    """
    info = {
        'prop_err_rse': None,
        'add_err_rse': None,
        'prop_err_boundary': False,
        'add_err_boundary': False,
        'prop_err_estimate': None,
        'add_err_estimate': None,
    }

    # Strategy 1: Parse the NONMEM .lst parameter estimate table
    # Format typically:
    # THETA - VECTOR OF FIXED EFFECTS
    # THETA 1  0.1500   2.34E-03  1.56    Prop.RE (sd)
    # THETA 2  0.5000   0.1500     30.0    Add.RE (sd)
    #
    # Or from the final parameter estimate section:
    # THETA 1  1.56E-01  2.34E-03  1.50E+00  1.56E-01  0.0000E+00  1.00E+05

    # Try to find the THETA section with labels
    theta_section_pattern = re.compile(
        r'THETA\s+(\d+)\s+([\d\.E\+\-]+)\s+([\d\.E\+\-]+)\s+([\d\.E\+\-]+)',
        re.IGNORECASE
    )

    # Also look for lines with Prop/Add labels nearby
    lines = lst_text.splitlines()
    for i, line in enumerate(lines):
        line_upper = line.upper()

        # Check if this line or nearby lines mention Prop/Add
        is_prop = 'PROP' in line_upper or 'PROPORTIONAL' in line_upper
        is_add = 'ADD' in line_upper or 'ADDITIVE' in line_upper

        if is_prop or is_add:
            m = theta_section_pattern.search(line)
            if m:
                theta_num = int(m.group(1))
                estimate = float(m.group(2))
                try:
                    rse_val = float(m.group(4))
                except (ValueError, IndexError):
                    rse_val = None

                if is_prop:
                    info['prop_err_rse'] = rse_val
                    info['prop_err_estimate'] = estimate
                    info['prop_err_boundary'] = (estimate <= 1e-6)
                elif is_add:
                    info['add_err_rse'] = rse_val
                    info['add_err_estimate'] = estimate
                    info['add_err_boundary'] = (estimate <= 1e-6)

    # Strategy 2: If labels not found, try to parse from the parameter estimate CSV if available
    # (fallback: look for the last two THETAs in a combined error model)
    # In a combined model with n PK THETAs, THETA(n-1) = Prop.err, THETA(n) = Add.err
    # We'll skip this for now as it's heuristic and could be wrong without labels.

    # Strategy 3: Try reading from _params.csv if it exists
    lst_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in dir() else '.'
    # Actually, let's check for the params CSV near the lst file
    # This is a fallback; primary source is the .lst labels

    return info


def should_simplify_error_model(error_model_info, rse_threshold=100.0):
    """Determine whether and how to simplify the combined error model.

    Args:
        error_model_info: dict from _extract_error_model_rse_from_lst()
        rse_threshold: RSE% above which a component should be fixed to 0 (default 100%)

    Returns:
        dict with:
            'should_simplify': bool
            'action': 'fix_prop_to_zero' | 'fix_add_to_zero' | None
            'reason': str explaining the recommendation
    """
    prop_rse = error_model_info.get('prop_err_rse')
    add_rse = error_model_info.get('add_err_rse')
    prop_boundary = error_model_info.get('prop_err_boundary', False)
    add_boundary = error_model_info.get('add_err_boundary', False)
    prop_est = error_model_info.get('prop_err_estimate')
    add_est = error_model_info.get('add_err_estimate')

    prop_unsupported = (
        (prop_rse is not None and prop_rse > rse_threshold) or
        prop_boundary or
        (prop_est is not None and prop_est <= 1e-6)
    )
    add_unsupported = (
        (add_rse is not None and add_rse > rse_threshold) or
        add_boundary or
        (add_est is not None and add_est <= 1e-6)
    )

    if prop_unsupported and add_unsupported:
        # Both bad — prefer proportional-only (more common in PK)
        return {
            'should_simplify': True,
            'action': 'fix_add_to_zero',
            'reason': (
                f'Both Prop.err (RSE={prop_rse}%) and Add.err (RSE={add_rse}%) '
                f'are poorly estimated. Prefer proportional-only model.'
            ),
        }
    elif add_unsupported:
        return {
            'should_simplify': True,
            'action': 'fix_add_to_zero',
            'reason': (
                f'Add.err RSE={add_rse}% > {rse_threshold}% or at boundary. '
                f'Fix Add.err=0 → proportional-only error model.'
            ),
        }
    elif prop_unsupported:
        return {
            'should_simplify': True,
            'action': 'fix_prop_to_zero',
            'reason': (
                f'Prop.err RSE={prop_rse}% > {rse_threshold}% or at boundary. '
                f'Fix Prop.err=0 → additive-only error model.'
            ),
        }
    else:
        return {
            'should_simplify': False,
            'action': None,
            'reason': 'Both error components are adequately estimated.',
        }


def extract_boundary_warnings(lst_path):
    """Check if any parameter is at its boundary."""
    if not os.path.exists(lst_path):
        return False

    text = read_file(lst_path)
    return "PARAMETER IS NEAR ITS BOUNDARY" in text.upper()


def run_nonmem(mod_path, nmfe_path, project_dir):
    """Run NONMEM on a .mod file, return (exit_code, lst_path)."""
    basename = os.path.splitext(os.path.basename(mod_path))[0]
    lst_path = os.path.join(project_dir, f"{basename}.lst")

    cmd = [nmfe_path, mod_path, lst_path]
    try:
        proc = subprocess.run(
            cmd,
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=300,
        )
        return proc.returncode, lst_path
    except subprocess.TimeoutExpired:
        return -1, lst_path
    except Exception as exc:
        print(f"NONMEM run error: {exc}", file=sys.stderr)
        return -1, lst_path


def cleanup_nonmem_outputs(project_dir, run_tag):
    """Remove NONMEM output files from a GA trial."""
    patterns = [
        f"{run_tag}.lst", f"{run_tag}.ext", f"{run_tag}.cov",
        f"{run_tag}.cor", f"{run_tag}.coi", f"{run_tag}.phi",
        f"{run_tag}.shm", f"{run_tag}.rmt", f"{run_tag}.xml",
        f"INTER", f"FCON", f"FREPORT", f"FSIZES", f"FSTREAM",
        f"FSUBS", f"FSUBS.f90", f"nmbd", f"nmlog",
        f"new.res", f"old.res", f"temp.nlst",
    ]
    for pat in patterns:
        target = os.path.join(project_dir, pat)
        if os.path.exists(target):
            try:
                os.remove(target)
            except OSError:
                pass


# ---------------------------------------------------------------------------
# Non-structural GA parameter extraction (backward-compatible)
# ---------------------------------------------------------------------------

def parse_theta_midpoints_for_continuous(mod_text):
    """Extract continuous genes for parameter-only mode (no structural search)."""
    thetas = parse_theta_midpoints(mod_text)
    result = []
    for t in thetas:
        result.append({
            "name": f"theta_{t['idx']}",
            "idx": t["idx"],
            "mid": t["mid"],
            "fixed": t.get("fixed", False),
        })
    return result


# ============================================================================
#  HYBRID GA ENGINE
# ============================================================================

class MixedChromosomeSpecs:
    """Specification for a mixed chromosome: continuous + categorical genes."""

    def __init__(self):
        self.continuous = {}   # name → (min, max)
        self.categorical = {}  # name → [option1, option2, ...]

    def add_continuous(self, name, lo, hi):
        self.continuous[name] = (lo, hi)

    def add_categorical(self, name, options):
        if not options:
            raise ValueError(f"Categorical gene '{name}' needs at least one option")
        self.categorical[name] = list(options)

    def make_new(self):
        """Create a random chromosome."""
        c = {}
        for name, (lo, hi) in self.continuous.items():
            c[name] = random.uniform(lo, hi)
        for name, options in self.categorical.items():
            c[name] = random.choice(options)
        return c

    def mutate(self, chromosome, mutation_rate=0.15):
        """Mutate in-place."""
        for name in self.continuous:
            if random.random() < mutation_rate:
                lo, hi = self.continuous[name]
                old_val = chromosome[name]
                # Gaussian perturbation
                sigma = (hi - lo) * 0.1
                new_val = old_val + random.gauss(0, sigma)
                new_val = max(lo, min(hi, new_val))
                chromosome[name] = new_val

        for name in self.categorical:
            if random.random() < mutation_rate:
                options = self.categorical[name]
                chromosome[name] = random.choice(options)

    def crossover(self, parent1, parent2):
        """Uniform crossover: for each gene, randomly pick from p1 or p2."""
        child = {}
        for name in self.continuous:
            if random.random() < 0.5:
                # BLX-alpha crossover for continuous
                lo, hi = self.continuous[name]
                v1, v2 = parent1[name], parent2[name]
                alpha = 0.5
                low = min(v1, v2) - alpha * abs(v1 - v2)
                high = max(v1, v2) + alpha * abs(v1 - v2)
                low = max(lo, low)
                high = min(hi, high)
                child[name] = random.uniform(low, high)
            else:
                child[name] = parent1[name] if random.random() < 0.5 else parent2[name]

        for name in self.categorical:
            child[name] = parent1[name] if random.random() < 0.5 else parent2[name]

        return child


def ga_solve(chromosome_specs, fitness_function, population_size=20,
             iterations=10, elite_ratio=0.2, elite_cut=0.1):
    """Hybrid GA solver.

    Args:
        chromosome_specs: MixedChromosomeSpecs
        fitness_function: callable(chromosome) → float (higher = better)
        population_size: individuals per generation
        iterations: number of generations
        elite_ratio: fraction preserved each generation
        elite_cut: fraction of offspring from crossover (rest = fresh random)
    """
    # Initial population
    population = [chromosome_specs.make_new() for _ in range(population_size)]

    all_generations = []

    for gen in range(iterations):
        # Evaluate fitness
        for c in population:
            c["__score__"] = fitness_function(c)

        # Sort by fitness (descending)
        population.sort(key=lambda c: c["__score__"], reverse=True)

        # Record generation stats
        gen_record = {
            "generation": gen + 1,
            "best_score": population[0]["__score__"],
            "median_score": population[len(population) // 2]["__score__"],
            "worst_score": population[-1]["__score__"],
        }
        all_generations.append(gen_record)
        print(f"  Gen {gen+1}/{iterations}: best={gen_record['best_score']:.2f}, "
              f"median={gen_record['median_score']:.2f}")

        # Elite selection
        elite_count = max(1, int(elite_ratio * population_size))
        elite = population[:elite_count]

        # New population
        new_pop = [elite[0]]  # Keep absolute best (super-elite)
        elite_without_1st = elite[1:] if len(elite) > 1 else [elite[0]]

        # Crossover offspring
        offspring_count = int(elite_cut * population_size)
        for _ in range(offspring_count):
            p1 = random.choice(elite)
            p2 = random.choice(elite_without_1st) if elite_without_1st else p1
            child = chromosome_specs.crossover(p1, p2)
            chromosome_specs.mutate(child)
            new_pop.append(child)

        # Fresh random to fill the rest
        while len(new_pop) < population_size:
            new_pop.append(chromosome_specs.make_new())

        population = new_pop

    # Final evaluation
    for c in population:
        if "__score__" not in c:
            c["__score__"] = fitness_function(c)

    population.sort(key=lambda c: c["__score__"], reverse=True)
    return population


# ---------------------------------------------------------------------------
# Structural templates / model assembly
# ---------------------------------------------------------------------------

# ADVAN → (num_compartments, TRANS, route_category)
# route_category: "iv", "oral", "custom"
ADVAN_INFO = {
    "ADVAN1":  (1, "TRANS2",  "iv"),
    "ADVAN2":  (1, "TRANS2",  "oral"),
    "ADVAN3":  (2, "TRANS4",  "iv"),
    "ADVAN4":  (2, "TRANS4",  "oral"),
    "ADVAN11": (3, "TRANS4",  "iv"),
    "ADVAN12": (3, "TRANS4",  "oral"),
    "ADVAN13": (1, "",         "custom"),
}

# Route → available ADVAN options
ROUTE_ADVAN = {
    "iv_bolus":    ["ADVAN1", "ADVAN3", "ADVAN11"],
    "iv_infusion": ["ADVAN1", "ADVAN3", "ADVAN11"],
    "oral":        ["ADVAN2", "ADVAN4", "ADVAN12"],
    "mixed":       ["ADVAN13"],
}

# Compartments → PK parameter names
COMPARTMENT_PARAMS = {
    1: ["CL", "V"],
    2: ["CL", "V1", "Q", "V2"],
    3: ["CL", "V1", "Q2", "V2", "Q3", "V3"],
}


def detect_route_from_mod(mod_text):
    """Detect administration route from NONMEM control stream."""
    text_upper = mod_text.upper()

    # Check $SUBROUTINES
    sub_match = re.search(r'\$SUBROUTINE\w*\s+ADVAN(\d+)', text_upper)
    advan_num = int(sub_match.group(1)) if sub_match else 0

    if advan_num in (2, 4, 12):
        return "oral"
    elif advan_num in (1, 3, 11):
        # Check for infusion markers
        if re.search(r'\bD1\s*=\s*DUR\b', text_upper) or re.search(r'\bRATE\b', text_upper):
            return "iv_infusion"
        return "iv_bolus"

    # Fallback: check $PK block for clues
    pk_match = re.search(r'\$PK\s*\n(.*?)(?=\n\s*\$|\Z)', mod_text, re.DOTALL | re.IGNORECASE)
    if pk_match:
        pk_block = pk_match.group(1).upper()
        if "KA" in pk_block:
            return "oral"
        if "D1" in pk_block and "DUR" in pk_block:
            return "iv_infusion"

    return "iv_bolus"


def get_oral_extra_params():
    """Extra parameters for oral models (in addition to compartment params)."""
    return ["KA"]


def build_error_block(error_model, theta_start_idx, iiv_params=None):
    """Build $ERROR block text.

    error_model: "prop", "comb", or "add"
    theta_start_idx: first THETA number for error model parameters

    Returns (error_block_text, num_thetas_added)
    """
    if error_model == "add":
        # Y = IPRED + EPS(1) * THETA(n)
        block = (
            f"IPRED = F\n"
            f"W = THETA({theta_start_idx})\n"
            f"Y = IPRED + W*EPS(1)\n"
            f"IRES = DV - IPRED\n"
            f"IWRES = IRES / W\n"
        )
        return block, 1
    elif error_model == "comb":
        # Y = IPRED + SQRT(THETA(n+1)**2 * IPRED**2 + THETA(n+2)**2) * EPS(1)
        block = (
            f"IPRED = F\n"
            f"W = SQRT(THETA({theta_start_idx})**2*IPRED**2 + THETA({theta_start_idx+1})**2)\n"
            f"Y = IPRED + W*EPS(1)\n"
            f"IRES = DV - IPRED\n"
            f"IWRES = IRES / W\n"
        )
        return block, 2
    else:
        # default: proportional
        # Y = IPRED * (1 + EPS(1) * THETA(n))
        block = (
            f"IPRED = F\n"
            f"W = THETA({theta_start_idx}) * IPRED\n"
            f"Y = IPRED + W*EPS(1)\n"
            f"IRES = DV - IPRED\n"
            f"IWRES = IRES / W\n"
        )
        return block, 1


def build_pk_block(advan, params, iiv_params=None, cov_genes=None, has_infusion=False, is_oral=False):
    """Build $PK block text for a given ADVAN.

    advan: e.g. "ADVAN3"
    params: list of parameter names e.g. ["CL", "V1", "Q", "V2"]
    iiv_params: dict of param_name → bool (whether to include ETA)
    cov_genes: dict of covariate gene values
    has_infusion: include D1=DUR
    is_oral: include KA and S2 scaling
    """
    lines = []

    if has_infusion and "D1" in "".join(params):
        pass  # D1=DUR handled separately
    if has_infusion:
        lines.append("D1=DUR")

    for i, param in enumerate(params):
        eta = ""
        if iiv_params and iiv_params.get(f"iiv_{param.lower()}", False):
            eta = f" * EXP(ETA({sum(1 for p in params[:i+1] if iiv_params.get('iiv_'+p.lower(), False))}))"

        # Covariate effects
        cov_part = ""
        if cov_genes:
            if cov_genes.get("cov_wt_cl", False) and param in ("CL", "V1", "V"):
                cov_part = " * (WT/70)**THETA_COV"
            if cov_genes.get("cov_wt_v", False) and param in ("V", "V1", "V2", "V3"):
                cov_part = " * (WT/70)**THETA_COV"

        lines.append(f"TV{param} = THETA({i+1})")
        lines.append(f"{param} = TV{param}{eta}{cov_part}")

    # Scaling
    _, _, route_cat = ADVAN_INFO.get(advan, (1, "TRANS2", "iv"))
    if route_cat == "oral":
        lines.append("S2 = V/1000")
    else:
        central_vol = "V1" if "V1" in params else "V"
        lines.append(f"S1 = {central_vol}/1000")

    return "\n".join(lines)


def build_mod_from_structure(template_mod, structural_genes, theta_values):
    """Assemble a complete .mod file from structural genes + THETA values.

    Args:
        template_mod: original .mod file content (used for $INPUT/$DATA etc.)
        structural_genes: dict with keys like 'advan', 'error_model', 'iiv_cl', etc.
        theta_values: dict of {theta_idx: value} for continuous THETA genes

    Returns: complete .mod file as string
    """
    advan = structural_genes.get("advan", "ADVAN3")
    error_model = structural_genes.get("error_model", "comb")
    num_compartments, trans, route_cat = ADVAN_INFO.get(advan, (2, "TRANS4", "iv"))

    is_oral = (route_cat == "oral")
    has_infusion = ("D1=DUR" in template_mod.upper() or "D1" in template_mod.upper())

    # Build parameter list
    params = COMPARTMENT_PARAMS.get(num_compartments, ["CL", "V"])
    if is_oral:
        params = get_oral_extra_params() + params  # KA first

    # Collect IIV genes
    iiv_params = {}
    for key, val in structural_genes.items():
        if key.startswith("iiv_") and isinstance(val, bool) and val:
            iiv_params[key] = True

    # Collect covariate genes
    cov_genes = {}
    for key in ["cov_wt_cl", "cov_wt_v", "cov_age", "cov_sex", "cov_study"]:
        if structural_genes.get(key, False):
            cov_genes[key] = True

    # Count THETAs needed
    num_base_thetas = len(params)
    error_block, num_error_thetas = build_error_block(error_model, num_base_thetas + 1)
    num_cov_thetas = 0
    if cov_genes.get("cov_wt_cl") or cov_genes.get("cov_wt_v"):
        num_cov_thetas = 1

    total_thetas = num_base_thetas + num_error_thetas + num_cov_thetas

    # Build $THETA block
    theta_lines = []
    for i in range(1, total_thetas + 1):
        val = theta_values.get(i, 1.0)
        if abs(val) < 0.001 or abs(val) >= 10000:
            theta_lines.append(f"  (0, {val:.4E})".lower())
        elif val == int(val):
            theta_lines.append(f"  (0, {int(val)})")
        else:
            theta_lines.append(f"  (0, {val:.4g})")

    # Extra FIX for additive part of combined error
    # No extra FIX needed — we use the standard Y form

    theta_block = "\n".join(theta_lines)

    # Build $OMEGA block
    omega_lines = []
    active_iiv_params = [k for k, v in iiv_params.items() if v]
    omega_structure = structural_genes.get("omega_structure", "diagonal")

    if omega_structure == "block" and len(active_iiv_params) >= 2:
        # Full block: n×n matrix
        n = len(active_iiv_params)
        for i_idx in range(n):
            vals = []
            for j_idx in range(n):
                if j_idx == 0:
                    vals.append("0.1")
                elif j_idx <= i_idx:
                    vals.append("0.01")
                else:
                    vals.append("0")
            omega_lines.append("  " + "  ".join(vals))
    else:
        # Diagonal
        for i, _ in enumerate(active_iiv_params):
            omega_lines.append("  0.1")
        # Add FIX for unused ETAs if any from template
        pass

    if not omega_lines:
        omega_lines.append("  0 FIX")
    omega_block = "\n".join(omega_lines)

    # Build $SIGMA block
    if error_model == "comb":
        sigma_block = "  1 FIX"
    elif error_model == "prop":
        sigma_block = "  1 FIX"
    else:  # add
        sigma_block = "  1 FIX"

    # Build $SUBROUTINES
    sub_block = f"$SUBROUTINES {advan} {trans}".strip()

    # Build $PK
    pk_block = build_pk_block(advan, params, iiv_params, cov_genes, has_infusion, is_oral)

    # Parse template for $PROBLEM, $INPUT, $DATA, $ESTIMATION, $COVARIANCE, $TABLE
    # Extract blocks from template
    problem_block = _extract_block(template_mod, "PROBLEM") or ";; GA-optimized model"
    input_block = _extract_block(template_mod, "INPUT") or ""
    data_block = _extract_block(template_mod, "DATA") or ""
    estim_block = _extract_block(template_mod, "EST") or "$EST METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10"
    cov_block = _extract_block(template_mod, "COVAR") or "$COVARIANCE PRINT=E MATRIX=S"

    # Build model description
    desc = f"GA-optimized {'oral' if is_oral else 'IV'} {num_compartments}-comp {error_model} error"
    # Extract numeric run ID from the template text (e.g. "run001" inside $PROBLEM or filename-like content)
    run_id_match = re.search(r'\brun(\d+)\b', template_mod[:500])
    run_id = run_id_match.group(1) if run_id_match else ""
    ga_run = f"GA{run_id}" if run_id else "GA"
    problem_text = f"$PROBLEM {ga_run}: {desc}"

    # Build $TABLE records with GA prefix
    eta_count = len(active_iiv_params)
    eta_terms = " ".join(f"ETA{i}" for i in range(1, eta_count + 1))
    pk_names = " ".join(params)
    table_block = f"""$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=SDTAB{ga_run} FORMAT=s1PE14.7
$TABLE ID {pk_names} {eta_terms} NOPRINT NOAPPEND ONEHEADER FILE=PATAB{ga_run}
$TABLE ID {eta_terms} FIRSTONLY NOAPPEND NOPRINT FILE={ga_run}.ETA
$TABLE ID WT SEX STUDY NOPRINT NOAPPEND ONEHEADER FILE=CATAB{ga_run}
$TABLE ID AGE NOPRINT NOAPPEND ONEHEADER FILE=COTAB{ga_run}"""

    # Assemble
    sections = [
        problem_text,
        f";; Generated by AutoPMX GA — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f";; Structure: {advan} {trans}, {num_compartments}-comp, {error_model} error",
        "",
    ]
    if input_block:
        sections.append(input_block.strip())
    if data_block:
        sections.append(data_block.strip())
    sections.append(sub_block)
    sections.append("")
    sections.append("$PK")
    sections.append(pk_block)
    sections.append("")
    sections.append("$ERROR")
    sections.append(error_block.strip())
    sections.append("")
    sections.append("$THETA")
    sections.append(theta_block)
    sections.append("")
    sections.append("$OMEGA")
    sections.append(omega_block)
    sections.append("")
    sections.append("$SIGMA")
    sections.append(sigma_block)
    sections.append("")
    sections.append(estim_block.strip())
    if cov_block:
        sections.append(cov_block.strip())
    # Always use GA-prefixed table block (never template's original table)
    sections.append(table_block)
    sections.append("")

    return "\n".join(sections)


def _extract_block(mod_text, keyword):
    """Extract a $BLOCK ... $NEXT_BLOCK or end-of-file section."""
    # Handle special cases
    keyword_upper = keyword.upper()
    if keyword_upper == "EST":
        pattern = r'\$EST\w*\s*\n(.*?)(?=\n\s*\$|\Z)'
    elif keyword_upper == "COV":
        pattern = r'\$COV\w*\s*\n(.*?)(?=\n\s*\$|\Z)'
    elif keyword_upper in ("PROBLEM", "PROB"):
        pattern = r'\$(?:PROBLEM|PROB)\s*\n?(.*?)(?=\n\s*\$|\Z)'
    else:
        pattern = rf'\${keyword_upper}\w*\s*\n?(.*?)(?=\n\s*\$|\Z)'

    match = re.search(pattern, mod_text, re.DOTALL | re.IGNORECASE)
    if match:
        content = match.group(1).strip()
        return f"${keyword_upper}\n{content}"
    return None


# ---------------------------------------------------------------------------
# Fitness functions
# ---------------------------------------------------------------------------

def make_fitness(mod_template, thetas_info, nmfe_path, project_dir):
    """Create fitness function for parameter-only GA (backward-compatible).

    Uses simplified (0, mid) THETA format.
    Each continuous gene = theta_{idx} with range [mid×0.1, mid×10].
    """
    specs = MixedChromosomeSpecs()
    for t in thetas_info:
        if t.get("fixed"):
            continue
        lo = max(t["mid"] * 0.1, 1e-6)
        hi = t["mid"] * 10.0
        specs.add_continuous(t["name"], lo, hi)

    ga_run_counter = [0]

    def fitness(chromosome):
        ga_run_counter[0] += 1
        run_tag = f"_ga_trial_{ga_run_counter[0]}"
        mod_path = os.path.join(project_dir, f"{run_tag}.mod")

        # Build .mod with proposed thetas
        thetas_dict = {}
        for t in thetas_info:
            key = f"theta_{t['idx']}"
            if key in chromosome and not t.get("fixed"):
                thetas_dict[t["idx"]] = chromosome[key]

        updated_mod = build_mod_with_thetas(mod_template, thetas_dict)
        write_file(mod_path, updated_mod)

        # Run NONMEM
        exit_code, lst_path = run_nonmem(mod_path, nmfe_path, project_dir)

        # Diagnostics
        ofv = extract_ofv(lst_path)
        success = extract_minimization_successful(lst_path)
        cov_ok = extract_covariance_successful(lst_path)
        boundary = extract_boundary_warnings(lst_path)

        # Clean up
        cleanup_nonmem_outputs(project_dir, run_tag)
        if os.path.exists(mod_path):
            os.remove(mod_path)

        if ofv is None:
            return -1e10

        fitness = -ofv
        if success:
            fitness += 100
        if not cov_ok:
            fitness -= 200
        if boundary:
            fitness -= 50

        return fitness

    return fitness, specs


def make_structural_fitness(mod_template, structural_specs, continuous_specs,
                            nmfe_path, project_dir):
    """Create fitness function for structural GA.

    Evaluates both structure and THETA values by running NONMEM.
    """
    ga_run_counter = [0]

    def fitness(chromosome):
        ga_run_counter[0] += 1
        run_tag = f"_gas_trial_{ga_run_counter[0]}"
        mod_path = os.path.join(project_dir, f"{run_tag}.mod")

        # Extract structural genes and theta values from chromosome
        structural_genes = {}
        theta_values = {}
        for key, val in chromosome.items():
            if key.startswith("theta_") and not key.startswith("theta_cov"):
                idx = int(key.split("_")[1])
                theta_values[idx] = val
            elif key.startswith("__"):
                continue
            else:
                structural_genes[key] = val

        # Build .mod
        updated_mod = build_mod_from_structure(
            mod_path,  # pass path so build_mod can read the original template
            structural_genes,
            theta_values,
        )
        # Actually, build_mod_from_structure needs the original template text:
        updated_mod = build_mod_from_structure(mod_template, structural_genes, theta_values)
        write_file(mod_path, updated_mod)

        # Run NONMEM
        exit_code, lst_path = run_nonmem(mod_path, nmfe_path, project_dir)

        # Diagnostics
        ofv = extract_ofv(lst_path)
        success = extract_minimization_successful(lst_path)
        cov_ok = extract_covariance_successful(lst_path)
        boundary = extract_boundary_warnings(lst_path)
        has_high_rse, max_rse, error_model_info = extract_rse_warnings(lst_path)

        # Clean up
        cleanup_nonmem_outputs(project_dir, run_tag)
        if os.path.exists(mod_path):
            os.remove(mod_path)

        if ofv is None:
            return -1e10

        # Base fitness
        fitness = -ofv

        # Success bonus
        if success:
            fitness += 100

        # Complexity penalty (AIC-like: 3.84 per additional parameter)
        num_compartments, _, _ = ADVAN_INFO.get(
            structural_genes.get("advan", "ADVAN3"), (2, "TRANS4", "iv"))
        base_params = 2  # 1-comp base
        extra_params = (num_compartments - 1) * 2  # each extra comp adds 2 params (Q + V)
        # Error model complexity
        error_model = structural_genes.get("error_model", "comb")
        if error_model == "comb":
            extra_params += 1  # one more THETA for additive component
        # IIV complexity
        for key, val in structural_genes.items():
            if key.startswith("iiv_") and val:
                extra_params += 1
        fitness -= 3.84 * extra_params

        # Diagnostic penalties
        if not cov_ok:
            fitness -= 200
        if boundary:
            fitness -= 50
        if has_high_rse:
            fitness -= 100

        # Error model simplification penalty:
        # If combined error model is used but one component is poorly estimated,
        # penalize it to encourage trying simpler error models in GA search
        if error_model == "comb" and error_model_info:
            simplify = should_simplify_error_model(error_model_info, rse_threshold=100.0)
            if simplify['should_simplify']:
                # Penalty proportional to how bad the RSE is
                prop_rse = error_model_info.get('prop_err_rse', 0) or 0
                add_rse = error_model_info.get('add_err_rse', 0) or 0
                max_err_rse = max(prop_rse, add_rse)
                # Scale penalty: mild at 100%, severe at 200%+
                penalty = min(150, (max_err_rse - 100) * 1.5)
                fitness -= penalty

        return fitness

    return fitness


# ============================================================================
# Main GA optimization
# ============================================================================

def run_ga_parameter_optimization(mod_text, nmfe_path, project_dir,
                                   pop_size=20, iterations=10, elite_ratio=0.2):
    """Run GA to optimize THETA midpoints only (backward-compatible)."""

    thetas = parse_theta_midpoints(mod_text)
    if not thetas:
        print("ERROR: No $THETA block found in control stream.", file=sys.stderr)
        return None

    print(f"Parsed {len(thetas)} THETA parameters:")
    for t in thetas:
        fixed_str = " [FIX]" if t.get("fixed") else ""
        print(f"  THETA{t['idx']}: (0, {t['mid']:.4g}){fixed_str}")

    thetas_info = parse_theta_midpoints_for_continuous(mod_text)

    fitness_fn, specs = make_fitness(mod_text, thetas_info, nmfe_path, project_dir)

    print(f"\nStarting GA: population={pop_size}, iterations={iterations}, elite_ratio={elite_ratio}")
    print(f"Estimated NONMEM runs: {pop_size * iterations}")

    population = ga_solve(
        chromosome_specs=specs,
        fitness_function=fitness_fn,
        population_size=pop_size,
        iterations=iterations,
        elite_ratio=elite_ratio,
    )

    return {
        "best_chromosome": population[0],
        "population": population,
        "thetas": thetas,
        "mode": "parameter",
    }


def run_ga_structural_optimization(mod_text, nmfe_path, project_dir,
                                    pop_size=20, iterations=10, elite_ratio=0.2,
                                    structural_dims=None):
    """Run GA to search model structure + optimize THETA values."""

    if structural_dims is None:
        structural_dims = ["advan", "error", "iiv", "covariate"]

    route = detect_route_from_mod(mod_text)
    print(f"Detected route: {route}")
    print(f"Structural dimensions: {structural_dims}")

    # Build chromosome specs
    specs = MixedChromosomeSpecs()

    # --- ADVAN gene ---
    if "advan" in structural_dims:
        advan_options = ROUTE_ADVAN.get(route, ["ADVAN1", "ADVAN3"])
        specs.add_categorical("advan", advan_options)
        print(f"  ADVAN options: {advan_options}")

    # --- Error model gene ---
    if "error" in structural_dims:
        specs.add_categorical("error_model", ["prop", "comb", "add"])
        print("  Error model options: prop, comb, add")

    # --- IIV genes (per parameter) ---
    iiv_gene_names = []
    if "iiv" in structural_dims:
        # Determine max possible parameters across all compartment options
        all_params = set()
        for advan in ROUTE_ADVAN.get(route, ["ADVAN3"]):
            nc, _, rc = ADVAN_INFO.get(advan, (2, "TRANS4", "iv"))
            params = COMPARTMENT_PARAMS.get(nc, ["CL", "V"])
            if rc == "oral":
                params = ["KA"] + params
            for p in params:
                all_params.add(p.lower())

        for p in sorted(all_params):
            gene_name = f"iiv_{p}"
            specs.add_categorical(gene_name, [True, False])
            iiv_gene_names.append(gene_name)
        print(f"  IIV genes: {iiv_gene_names}")

    # --- OMEGA structure gene ---
    if "iiv" in structural_dims:
        specs.add_categorical("omega_structure", ["diagonal", "block"])

    # --- Covariate genes ---
    cov_gene_names = []
    if "covariate" in structural_dims:
        for cov in ["cov_wt_cl", "cov_wt_v", "cov_age", "cov_sex", "cov_study"]:
            specs.add_categorical(cov, [True, False])
            cov_gene_names.append(cov)
        print(f"  Covariate genes: {cov_gene_names}")

    # --- Continuous THETA genes ---
    # Parse THETA midpoints from original model as starting values for reference
    original_thetas = parse_theta_midpoints(mod_text)
    theta_map = {t["idx"]: t for t in original_thetas}

    # We need continuous genes for ALL possible thetas across all structures
    # Max compartments = 3, max params = 7 (KA+CL+V1+Q2+V2+Q3+V3)
    # Plus error model thetas (2 for comb) + covariate thetas (2 for WT on CL and V)
    max_params = 7  # worst case: KA + CL + V1 + Q2 + V2 + Q3 + V3
    max_error_thetas = 2
    max_cov_thetas = 2

    for i in range(1, max_params + 1):
        # Use original theta value if available, else default
        default_mid = theta_map[i]["mid"] if i in theta_map else 1.0
        lo = max(default_mid * 0.01, 1e-6) if default_mid > 0 else 0.001
        hi = default_mid * 25.0
        specs.add_continuous(f"theta_{i}", lo, hi)

    # Error model thetas
    for i in range(1, 3):
        idx = max_params + i
        default_mid = theta_map[idx]["mid"] if idx in theta_map else (0.1 if i == 1 else 1.0)
        specs.add_continuous(f"theta_{idx}", max(default_mid * 0.01, 1e-6), default_mid * 25.0)

    # Covariate thetas
    for i in range(1, 3):
        idx = max_params + max_error_thetas + i
        specs.add_continuous(f"theta_{idx}", 0.001, 10.0)

    print(f"\nTotal continuous genes: {len(specs.continuous)}")
    print(f"Total categorical genes: {len(specs.categorical)}")

    # Create fitness function
    fitness_fn = make_structural_fitness(mod_text, specs, specs, nmfe_path, project_dir)

    print(f"\nStarting Structural GA: population={pop_size}, iterations={iterations}, elite_ratio={elite_ratio}")
    print(f"Estimated NONMEM runs: {pop_size * iterations}")

    population = ga_solve(
        chromosome_specs=specs,
        fitness_function=fitness_fn,
        population_size=pop_size,
        iterations=iterations,
        elite_ratio=elite_ratio,
    )

    return {
        "best_chromosome": population[0],
        "population": population,
        "thetas": original_thetas,
        "mode": "structural",
        "route": route,
        "structural_dims": structural_dims,
    }


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def write_optimized_mod(result, output_path, mod_text):
    """Write the GA-optimized .mod file."""
    best = result["best_chromosome"]
    mode = result.get("mode", "parameter")

    # Build header
    header = (
        f";; AutoPMX GA-optimized — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
    )

    if mode == "structural":
        advan = best.get("advan", "ADVAN?")
        error_model = best.get("error_model", "?")
        header += (
            f";; Mode: Structural Search\n"
            f";; Route: {result.get('route', '?')}\n"
            f";; Structure: {advan}, {error_model} error\n"
        )

        # List structural choices
        for key, val in sorted(best.items()):
            if key.startswith("theta_") or key.startswith("__"):
                continue
            header += f";;   {key} = {val}\n"

        # Build full mod from structure
        structural_genes = {}
        theta_values = {}
        for key, val in best.items():
            if key.startswith("theta_") and not key.startswith("theta_cov"):
                idx = int(key.split("_")[1])
                theta_values[idx] = val
            elif key.startswith("__"):
                continue
            else:
                structural_genes[key] = val

        updated = build_mod_from_structure(mod_text, structural_genes, theta_values)
    else:
        # Parameter-only mode
        thetas_dict = {}
        for key, val in best.items():
            if key.startswith("theta_") and not key.startswith("__"):
                idx = int(key.split("_")[1])
                thetas_dict[idx] = val

        updated = build_mod_with_thetas(mod_text, thetas_dict)

        # Add parameter change summary
        header += f";; Mode: Parameter Optimization\n"
        original_thetas = result.get("thetas", [])
        for t in original_thetas:
            key = f"theta_{t['idx']}"
            if key in best and not t.get("fixed"):
                new_val = best[key]
                header += f";;   THETA{t['idx']}: {t['mid']:.4g} → {new_val:.4g}\n"

    # Insert header after $PROBLEM line
    lines = updated.splitlines()
    out_lines = []
    inserted = False
    for line in lines:
        out_lines.append(line)
        if not inserted and line.strip().upper().startswith("$PROBLEM"):
            out_lines.append(header.rstrip())
            inserted = True

    write_file(output_path, strip_inline_dataset_rows("\n".join(out_lines) + "\n"))
    return output_path


def write_population_csv(population, output_path):
    """Write all candidates to CSV for comparison."""
    if not population:
        return

    # Collect all gene names
    all_keys = set()
    for c in population:
        for k in c:
            if not k.startswith("__"):
                all_keys.add(k)

    sorted_keys = sorted(all_keys)

    with open(output_path, "w", newline="") as fh:
        writer = csv.writer(fh)
        fieldnames = ["rank"] + sorted_keys + ["fitness"]
        writer.writerow(fieldnames)
        for rank, c in enumerate(population[:50], 1):  # Top 50
            row = [rank]
            for k in sorted_keys:
                val = c.get(k, "")
                if isinstance(val, float):
                    row.append(f"{val:.6g}")
                else:
                    row.append(str(val))
            row.append(f"{c.get('__score__', 0):.2f}")
            writer.writerow(row)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="AutoPMX Hybrid GA Optimizer for NONMEM PopPK models"
    )
    parser.add_argument("--mod", required=True, help="Path to the .mod control stream")
    parser.add_argument("--project-dir", required=True, help="Project directory (working dir for NONMEM)")
    parser.add_argument("--nmfe", required=True, help="Path to NONMEM nmfe executable")
    parser.add_argument("--rscript", default="", help="Path to Rscript (for future diagnostic integration)")
    parser.add_argument("--ga-pop", type=int, default=20, help="GA population size (default: 20)")
    parser.add_argument("--ga-iter", type=int, default=10, help="GA iterations (default: 10)")
    parser.add_argument("--ga-elite", type=float, default=0.2, help="GA elite ratio (default: 0.2)")
    parser.add_argument("--output", default="", help="Output .mod path (default: <mod>_ga_opt.mod)")

    # Structural search options
    parser.add_argument("--structural", action="store_true",
                        help="Enable structural model search (ADVAN, error, IIV, covariates)")
    parser.add_argument("--structural-dims", default="all",
                        help="Comma-separated dimensions to search: advan,error,iiv,covariate (default: all)")
    parser.add_argument("--eval-mode", default="fast", choices=["fast", "full"],
                        help="Evaluation mode (default: fast)")
    parser.add_argument("--audit-top", type=int, default=0,
                        help="Run full diagnostic audit on top N elites per generation (default: 0)")

    parser.add_argument("--dry-run", action="store_true", help="Only show THETAs/genes, don't run GA")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")

    args = parser.parse_args()

    mod_path = os.path.abspath(args.mod)
    project_dir = os.path.abspath(args.project_dir)

    if not os.path.exists(mod_path):
        print(f"ERROR: .mod file not found: {mod_path}", file=sys.stderr)
        sys.exit(1)

    mod_text = read_file(mod_path)

    # Dry-run
    if args.dry_run:
        if args.structural:
            route = detect_route_from_mod(mod_text)
            dims = args.structural_dims.split(",") if args.structural_dims != "all" else ["advan", "error", "iiv", "covariate"]
            print(f"Dry-run — Structural GA")
            print(f"Route: {route}")
            print(f"Dimensions: {dims}")
            print(f"ADVAN options: {ROUTE_ADVAN.get(route, [])}")
            print(f"Max compartments: 3")
            print(f"Candidate count: {args.ga_pop} × {args.ga_iter} = {args.ga_pop * args.ga_iter}")
        else:
            thetas = parse_theta_midpoints(mod_text)
            print(f"Theta parameters in {args.mod}:")
            print(json.dumps(thetas, indent=2))
        return

    if not os.path.exists(args.nmfe):
        print(f"ERROR: nmfe not found: {args.nmfe}", file=sys.stderr)
        sys.exit(1)

    print(f"=== AutoPMX Hybrid GA Optimizer ===")
    print(f"Model: {mod_path}")
    print(f"Project: {project_dir}")
    print(f"NMFE: {args.nmfe}")
    if args.structural:
        print(f"Mode: Structural Search")
    else:
        print(f"Mode: Parameter Only")

    # Run optimization
    if args.structural:
        dims = None
        if args.structural_dims != "all":
            dims = [d.strip() for d in args.structural_dims.split(",")]
        result = run_ga_structural_optimization(
            mod_text=mod_text,
            nmfe_path=args.nmfe,
            project_dir=project_dir,
            pop_size=args.ga_pop,
            iterations=args.ga_iter,
            elite_ratio=args.ga_elite,
            structural_dims=dims,
        )
    else:
        result = run_ga_parameter_optimization(
            mod_text=mod_text,
            nmfe_path=args.nmfe,
            project_dir=project_dir,
            pop_size=args.ga_pop,
            iterations=args.ga_iter,
            elite_ratio=args.ga_elite,
        )

    if result is None:
        print("ERROR: GA optimization failed", file=sys.stderr)
        sys.exit(1)

    # Write output
    # Output naming: run001.mod → GA001.mod
    mod_basename = os.path.basename(mod_path)
    ga_run_id = re.sub(r'^run', 'GA', os.path.splitext(mod_basename)[0])
    output_path = args.output or os.path.join(project_dir, ga_run_id + ".mod")
    write_optimized_mod(result, output_path, mod_text)

    # Write population CSV
    pop_csv = os.path.join(project_dir, ga_run_id + "_population.csv")
    write_population_csv(result.get("population", []), pop_csv)

    best = result["best_chromosome"]
    mode = result.get("mode", "parameter")

    if args.json:
        report = {
            "output_mod": output_path,
            "population_csv": pop_csv,
            "mode": mode,
            "fitness": best.get("__score__", "N/A"),
            "best_chromosome": {k: v for k, v in best.items() if not k.startswith("__")},
            "generation_stats": [],
        }
        print(json.dumps(report, indent=2))
    else:
        print(f"\n=== GA Optimization Complete ===")
        print(f"Optimized model written to: {output_path}")
        print(f"Population detail: {pop_csv}")
        print(f"Best fitness score: {best.get('__score__', 'N/A'):.2f}")

        if mode == "structural":
            print(f"\nBest structure:")
            for key, val in sorted(best.items()):
                if key.startswith("theta_") or key.startswith("__"):
                    continue
                print(f"  {key} = {val}")
        else:
            original_thetas = parse_theta_midpoints(mod_text)
            print(f"\nParameter changes:")
            for t in original_thetas:
                key = f"theta_{t['idx']}"
                if key in best and not t.get("fixed"):
                    old_val = t["mid"]
                    new_val = best[key]
                    delta = ((new_val - old_val) / abs(old_val)) * 100 if abs(old_val) > 1e-9 else 0
                    print(f"  THETA{t['idx']}: (0, {old_val:.4g}) → (0, {new_val:.4g}) ({delta:+.1f}%)")


if __name__ == "__main__":
    main()
