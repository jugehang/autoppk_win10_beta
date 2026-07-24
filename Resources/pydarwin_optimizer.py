#!/usr/bin/env python3
"""
pyDarwin GA optimizer for NONMEM models.

Reads a run*.mod file, parses $THETA blocks (lower, initial, upper),
runs a genetic algorithm that calls PsN execute as the fitness function,
and writes the best candidate as a new run*.mod file.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from pydarwin import ChromosomeSpecifications, GA
    HAS_PYDARWIN = True
except ImportError:
    HAS_PYDARWIN = False


# ---------- .mod parsing ----------

THETA_BLOCK_RE = re.compile(
    r"\$THETA\s*\n(.*?)(?=\n\$|\Z)",
    re.DOTALL | re.IGNORECASE,
)

THETA_LINE_RE = re.compile(
    r"\(\s*([-\d.eE+]+)\s*,\s*([-\d.eE+]+)\s*,\s*([-\d.eE+]+)\s*\)",
)


def parse_thetas(mod_text: str):
    """Return list of (lower, initial, upper, comment) tuples from $THETA block."""
    match = THETA_BLOCK_RE.search(mod_text)
    if not match:
        return []
    block = match.group(1)
    thetas = []
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        m = THETA_LINE_RE.search(line)
        if m:
            lower = float(m.group(1))
            initial = float(m.group(2))
            upper = float(m.group(3))
            comment = line.split(";", 1)[1].strip() if ";" in line else ""
            thetas.append((lower, initial, upper, comment))
    return thetas


def replace_theta_initials(mod_text: str, new_values: list) -> str:
    """Replace the initial value in each (lower, initial, upper) THETA line."""
    match = THETA_BLOCK_RE.search(mod_text)
    if not match:
        return mod_text
    block = match.group(1)
    lines = block.splitlines()
    value_idx = 0
    new_lines = []
    for line in lines:
        m = THETA_LINE_RE.search(line)
        if m and value_idx < len(new_values):
            lower = m.group(1)
            upper = m.group(3)
            new_val = new_values[value_idx]
            # Preserve the comment suffix
            comment = ""
            if ";" in line:
                comment = "  ;" + line.split(";", 1)[1]
            new_line = f"({lower}, {new_val:.6g}, {upper}){comment}"
            new_lines.append(new_line)
            value_idx += 1
        else:
            new_lines.append(line)
    new_block = "\n".join(new_lines)
    return mod_text[: match.start(1)] + new_block + mod_text[match.end(1):]


# ---------- NONMEM / PsN fitness ----------

def extract_ofv(lst_path: Path):
    """Extract the objective function value from a .lst file. Returns None on failure."""
    if not lst_path.exists():
        return None
    try:
        text = lst_path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return None
    upper = text.upper()
    # Check for minimization failure
    if "MINIMIZATION TERMINATED" in upper or "MINIMIZATION NOT TESTED" in upper:
        return None
    patterns = [
        r"MINIMUM VALUE OF OBJECTIVE FUNCTION\s*[:=]?\s*([-+]?\d+(?:\.\d+)?)",
        r"OBJECTIVE FUNCTION VALUE\s*[:=]?\s*([-+]?\d+(?:\.\d+)?)",
        r"OBJV:\s*([-+]?\d+(?:\.\d+)?)",
    ]
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            try:
                return float(m.group(1))
            except ValueError:
                continue
    return None


def run_psn_for_fitness(mod_text_with_values, run_id, project_dir, psn_cmd, work_dir):
    """Write a temp .mod, run PsN execute, return OFV or None."""
    temp_mod = work_dir / f"run{run_id}.mod"
    temp_mod.write_text(mod_text_with_values, encoding="utf-8")

    # Copy data file into work dir if needed
    for candidate in project_dir.glob("*.csv"):
        shutil.copy2(candidate, work_dir / candidate.name)

    cmd = f"{psn_cmd} {temp_mod.name} -model_dir_name"
    try:
        proc = subprocess.run(
            ["zsh", "-lc", cmd],
            cwd=str(work_dir),
            capture_output=True,
            text=True,
            timeout=600,
        )
    except subprocess.TimeoutExpired:
        return None
    except Exception:
        return None

    # PsN creates run_dir_name/ with .lst inside
    lst_candidates = list(work_dir.rglob(f"run{run_id}.lst"))
    lst_candidates += list(work_dir.glob(f"*.lst"))
    for lst in lst_candidates:
        ofv = extract_ofv(lst)
        if ofv is not None:
            return ofv
    return None


# ---------- Main ----------

def main():
    parser = argparse.ArgumentParser(description="pyDarwin GA optimizer for NONMEM models")
    parser.add_argument("--mod", required=True, help="Path to run*.mod file")
    parser.add_argument("--project-dir", required=True, help="Project directory")
    parser.add_argument("--run-id", required=True, help="Run ID (e.g. 001)")
    parser.add_argument("--population", type=int, default=6, help="GA population size")
    parser.add_argument("--iterations", type=int, default=2, help="GA iterations")
    parser.add_argument("--psn-cmd", default="execute", help="PsN execute command")
    parser.add_argument("--output-run", default="", help="Output run ID for best model (default: auto-increment)")
    args = parser.parse_args()

    if not HAS_PYDARWIN:
        print("ERROR: pydarwin package not installed. Run: pip3 install pydarwin", file=sys.stderr)
        return 1

    mod_path = Path(args.mod)
    project_dir = Path(args.project_dir)

    if not mod_path.exists():
        print(f"ERROR: Model file not found: {mod_path}", file=sys.stderr)
        return 1

    print(f"pyDarwin GA Optimizer")
    print(f"  Model: {mod_path.name}")
    print(f"  Project: {project_dir}")
    print(f"  Population: {args.population}, Iterations: {args.iterations}")
    print()

    mod_text = mod_path.read_text(encoding="utf-8")
    thetas = parse_thetas(mod_text)

    if not thetas:
        print("ERROR: No $THETA parameters found in model.", file=sys.stderr)
        return 1

    print(f"Parsed {len(thetas)} THETA parameters:")
    for i, (lo, init, hi, comment) in enumerate(thetas, 1):
        label = f" ({comment})" if comment else ""
        print(f"  THETA({i}): range [{lo}, {hi}], initial {init}{label}")
    print()

    # Build chromosome specs
    specs = ChromosomeSpecifications()
    for i, (lo, init, hi, _) in enumerate(thetas, 1):
        specs.add(f"THETA{i}", lo, hi)

    # Fitness function
    eval_count = [0]

    def fitness(chromosome):
        eval_count[0] += 1
        values = [chromosome[f"THETA{i+1}"] for i in range(len(thetas))]
        print(f"  [eval {eval_count[0]}] THETA={', '.join(f'{v:.4g}' for v in values)}", flush=True)

        work_dir = Path(tempfile.mkdtemp(prefix=f"pydarwin_eval{eval_count[0]}_"))
        try:
            mod_variant = replace_theta_initials(mod_text, values)
            ofv = run_psn_for_fitness(
                mod_variant, args.run_id, project_dir, args.psn_cmd, work_dir
            )
        finally:
            shutil.rmtree(work_dir, ignore_errors=True)

        if ofv is None:
            print(f"    -> NONMEM failed or no OFV, penalty: -1e15", flush=True)
            return -1e15

        print(f"    -> OFV={ofv:.4f}, fitness={-ofv:.4f}", flush=True)
        return -ofv  # GA maximizes, we minimize OFV

    # Run GA
    print(f"Starting GA optimization ({args.population} x {args.iterations} = {args.population * args.iterations} evals max)...")
    print()
    try:
        best = GA.solve(
            specs,
            fitness,
            population_size=args.population,
            elite_ratio=0.3,
            iterations=args.iterations,
        )
    except Exception as e:
        print(f"ERROR: GA optimization failed: {e}", file=sys.stderr)
        return 1

    if best is None:
        print("ERROR: GA returned no solution.", file=sys.stderr)
        return 1

    best_values = [best[f"THETA{i+1}"] for i in range(len(thetas))]
    print()
    print("=" * 60)
    print("GA Optimization Complete")
    print(f"  Evaluations performed: {eval_count[0]}")
    print(f"  Best THETA values:")
    for i, (val, (lo, init, hi, comment)) in enumerate(zip(best_values, thetas), 1):
        label = f" ({comment})" if comment else ""
        print(f"    THETA({i}): {val:.6g}  (was {init}, range [{lo}, {hi}]){label}")
    print("=" * 60)

    # Write best model as new run
    if args.output_run:
        out_run = args.output_run
    else:
        # Auto-increment: find next available run number
        existing = []
        for f in project_dir.glob("run*.mod"):
            m = re.match(r"run(\d+)\.mod", f.name, re.IGNORECASE)
            if m:
                existing.append(int(m.group(1)))
        next_num = (max(existing) + 1) if existing else 1
        out_run = f"{next_num:03d}"

    out_path = project_dir / f"run{out_run}.mod"
    best_mod = replace_theta_initials(mod_text, best_values)
    # Update $PROBLEM and table file references
    best_mod = best_mod.replace(
        f"run{args.run_id}", f"run{out_run}"
    )
    out_path.write_text(best_mod, encoding="utf-8")
    print(f"\nBest model written to: {out_path}")
    print(f"Run this model with: execute run{out_run}.mod -model_dir_name")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
