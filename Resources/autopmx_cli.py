import argparse
import json
import sys
from pathlib import Path

from workbench_core import WorkbenchSettings, TaskRunner


def _run_validate(args) -> int:
    """Validate a .mod file without running NONMEM."""
    try:
        from mod_validator import validate_mod
    except ImportError:
        print("mod_validator not available", file=sys.stderr)
        return 127

    mod_path = Path(args.mod)
    project_dir = Path(args.project_dir) if args.project_dir else mod_path.parent
    csv_path = Path(args.csv) if args.csv else None

    result = validate_mod(mod_path, project_dir=project_dir, csv_path=csv_path, run_id=args.run_id)
    print(result.summary())
    return 0 if result.passed else 1


def _run_generate(args) -> int:
    """Generate a NONMEM .mod file from a template + structured decisions."""
    try:
        from model_generator import generate_from_template, apply_modifications, Modification
    except ImportError:
        print("model_generator not available", file=sys.stderr)
        return 127

    if args.template:
        text = generate_from_template(
            template_id=args.template,
            run_id=args.run,
            data_file=args.data or "NM_dat_new.csv",
        )
        Path(args.output).write_text(text, encoding="utf-8")
        print(f"Generated {args.output}")
        return 0

    if args.source:
        source = Path(args.source).read_text(encoding="utf-8")
        mods_data = json.loads(args.modifications)
        mods = [Modification(**m) for m in mods_data]
        result = apply_modifications(source, mods)
        Path(args.output).write_text(result, encoding="utf-8")
        print(f"Generated {args.output} from source")
        return 0

    print("No source or template specified", file=sys.stderr)
    return 1


def _run_autofix(args) -> int:
    """Auto-fix common .mod errors in place."""
    mod_path = Path(args.mod)
    if not mod_path.exists():
        print(f"Not found: {mod_path}", file=sys.stderr)
        return 1

    from workbench_core import TaskRunner, WorkbenchSettings

    settings = WorkbenchSettings(
        project_dir=mod_path.parent,
        curr_run=args.run_id or mod_path.stem.replace("run", ""),
        data_file=args.data or "NM_dat_new.csv",
    )
    runner = TaskRunner(settings, lambda msg: print(msg, file=sys.stderr))
    return runner._preflight_mod_check(mod_path)


def main() -> int:
    parser = argparse.ArgumentParser(description="AutoPMX task bridge for native macOS app")
    parser.add_argument(
        "task",
        choices=[
            "parameter-audit",
            "gof-audit",
            "vpc-audit",
            "r-diagnostics",
            "gof-plot",
            "individual-plot",
            "vpc-plot",
            "pk-parameters",
            "psn-vpc",
            "bootstrap",
            "scm",
            "eda",
            "ct-curves",
            # New deterministic task types:
            "validate-model",
            "generate-model",
            "autofix-model",
        ],
    )
    parser.add_argument(
        "--prev", default="38"
    )
    parser.add_argument("--curr", default="41")
    parser.add_argument("--llm-url", default="http://localhost:1234/v1")
    parser.add_argument("--model", default="google/gemma-4-26b-a4b")
    parser.add_argument("--api-key", default="lm-studio")
    parser.add_argument("--vision-url", default="", help="Independent multimodal model URL for GOF/VPC visual audits (defaults to --llm-url)")
    parser.add_argument("--vision-model", default="", help="Independent multimodal model name for GOF/VPC visual audits (defaults to --model)")
    parser.add_argument("--vision-api-key", default="", help="API key for the vision model (defaults to --api-key)")
    parser.add_argument("--rules", default="poppk_rules.json,NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md")
    parser.add_argument("--psn-dir", default="", help="Directory containing PsN commands (vpc, bootstrap, scm, execute)")
    parser.add_argument("--bootstrap-samples", type=int, default=0, help="Override bootstrap sample count")
    # validate / generate / autofix args
    parser.add_argument("--mod", help="Path to .mod file (for validate-model / autofix-model)")
    parser.add_argument("--project-dir", help="Project directory (for validate-model)")
    parser.add_argument("--csv", help="CSV dataset path (for validate-model)")
    parser.add_argument("--run-id", help="Expected run ID")
    parser.add_argument("--template", help="Template ID (for generate-model)")
    parser.add_argument("--run", help="Run number (for generate-model)")
    parser.add_argument("--data", help="Data file name")
    parser.add_argument("--source", help="Source .mod path (for generate-model transform)")
    parser.add_argument("--modifications", help="JSON modifications (for generate-model transform)")
    parser.add_argument("--output", help="Output path (for generate-model)")
    parser.add_argument("--rscript", default="Rscript", help="Path to Rscript executable")
    args = parser.parse_args()

    # Use explicit --project-dir when provided; fall back to cwd for backward compat
    proj_dir = Path(args.project_dir) if args.project_dir else Path.cwd()
    settings = WorkbenchSettings(
        project_dir=proj_dir,
        prev_run=args.prev,
        curr_run=args.curr,
        llm_base_url=args.llm_url,
        llm_model_id=args.model,
        llm_api_key=args.api_key,
        vision_base_url=args.vision_url or args.llm_url,
        vision_model_id=args.vision_model or args.model,
        vision_api_key=args.vision_api_key or args.api_key,
        rules_file=args.rules,
        psn_dir=args.psn_dir,
        bootstrap_samples=args.bootstrap_samples,
        rscript=args.rscript or "Rscript",
    )
    # Only tasks that actually run visual audits need a vision model. For other tasks
    # (validate-model / autofix-model / generate-model / plots ...) the vision model is
    # irrelevant, so printing it here only confuses users ("why is a vision model involved?").
    VISION_AUDIT_TASKS = {"gof-audit", "vpc-audit", "parameter-audit"}
    if args.task in VISION_AUDIT_TASKS:
        if args.vision_url or args.vision_model:
            print(f"AutoPMX CLI: vision model = {settings.vision_model_id} @ {settings.vision_base_url} (independent)")
        else:
            print(f"AutoPMX CLI: vision model = {settings.vision_model_id} (reusing main model)")
    runner = TaskRunner(settings, print)

    if args.task == "parameter-audit":
        return runner.run_parameter_audit()
    if args.task == "gof-audit":
        return runner.run_gof_audit()
    if args.task == "vpc-audit":
        return runner.run_vpc_audit()
    if args.task == "r-diagnostics":
        return runner.run_r_diagnostics()
    if args.task == "gof-plot":
        return runner.run_gof_plot()
    if args.task == "individual-plot":
        return runner.run_individual_plot()
    if args.task == "vpc-plot":
        return runner.run_vpc_plot()
    if args.task == "pk-parameters":
        return runner.run_pk_parameters()
    if args.task == "psn-vpc":
        return runner.run_psn_vpc()
    if args.task == "bootstrap":
        return runner.run_bootstrap()
    if args.task == "scm":
        return runner.run_scm()
    if args.task == "eda":
        return runner.run_eda(csv_file=args.csv)
    if args.task == "ct-curves":
        return runner.run_ct_curves(csv_file=args.csv)

    # New deterministic task types
    if args.task == "validate-model":
        return _run_validate(args)
    if args.task == "generate-model":
        return _run_generate(args)
    if args.task == "autofix-model":
        return _run_autofix(args)

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
