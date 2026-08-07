import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import threading
import csv
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Set, Tuple


LogFn = Callable[[str], None]

# Optional imports — these may fail if the validator/generator haven't
# been installed yet, so we wrap them in a try/except.
try:
    from mod_validator import validate_mod, ValidationResult, ValidationIssue
    HAS_VALIDATOR = True
except ImportError:
    HAS_VALIDATOR = False
    validate_mod = None  # type: ignore
    ValidationResult = None  # type: ignore

try:
    from model_generator import apply_modifications, Modification
    HAS_GENERATOR = True
except ImportError:
    HAS_GENERATOR = False
    apply_modifications = None  # type: ignore


@dataclass
class CommandResolution:
    command: List[str]
    executable: str
    available: bool
    display: str


@dataclass
class DataPathStatus:
    mod_path: Path
    current_path: Optional[str]
    expected_path: Path
    current_exists: bool
    expected_exists: bool
    matches_expected: bool


@dataclass
class WorkbenchSettings:
    project_dir: Path
    prev_run: str = "38"
    curr_run: str = "41"
    llm_base_url: str = "http://localhost:1234/v1"
    llm_model_id: str = "google/gemma-4-26b-a4b"
    llm_api_key: str = "lm-studio"
    vision_base_url: str = "http://localhost:1234/v1"
    vision_model_id: str = "google/gemma-4-26b-a4b"
    vision_api_key: str = "lm-studio"
    rules_file: str = "poppk_rules.json,NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md"
    psn_dir: str = ""
    bootstrap_samples: int = 0
    rscript: str = "Rscript"
    nonmem_template: str = ""
    psn_execute_template: str = "execute {model} -model_dir_name"
    data_file: str = "NM_dat_new.csv"

    @property
    def project_path(self) -> Path:
        return Path(self.project_dir).resolve()


def ensure_inside_project(path: Path, project_dir: Path) -> Path:
    resolved = Path(path).resolve()
    root = Path(project_dir).resolve()
    if resolved != root and root not in resolved.parents:
        raise ValueError(f"Path is outside project folder: {resolved}")
    return resolved


def discover_runs(project_dir: Path) -> List[str]:
    root = Path(project_dir)
    run_ids = set()
    for path in root.glob("run*.*"):
        match = re.fullmatch(r"run(\d+)\.(mod|lst|ext|cov)", path.name, re.IGNORECASE)
        if match:
            run_ids.add(match.group(1))
    return sorted(run_ids, key=lambda value: int(value))


def check_model_files(project_dir: Path, run_id: str) -> Dict[str, bool]:
    root = Path(project_dir)
    run = str(run_id)
    return {ext: (root / f"run{run}.{ext}").exists() for ext in ("mod", "lst", "ext", "cov")}


def _safe_project_name(name: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", name.strip())
    return safe.strip("._") or "AutoPMX_Project"


def create_project_folder(workspace_dir: Path, name: str) -> Path:
    workspace = Path(workspace_dir).resolve()
    project_root = workspace / "AutoPMX_Projects" / _safe_project_name(name)
    ensure_inside_project(project_root, workspace)
    project_root.mkdir(parents=True, exist_ok=True)
    config = project_root / "project_config.json"
    if not config.exists():
        config.write_text(
            json.dumps(
                {
                    "project_name": name.strip() or project_root.name,
                    "units": {"time": "Time (h)", "conc": "Concentration"},
                    "grouping": {"factor": "STUDY", "labels": {}},
                    "psn_settings": {"vpc_samples": 500, "bootstrap_samples": 200, "stratify_var": "STUDY"},
                },
                indent=2,
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
    metadata = project_root / ".autopmx_project.json"
    metadata.write_text(
        json.dumps(
            {
                "name": name.strip() or project_root.name,
                "created_at": datetime.now().isoformat(timespec="seconds"),
                "kind": "AutoPMX local project",
            },
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )
    return project_root


def create_project_from_run(
    workspace_dir: Path,
    source_dir: Path,
    name: str,
    run_id: str,
    data_file: str = "NM_dat_new.csv",
) -> Path:
    project_root = create_project_folder(workspace_dir, name)
    source = Path(source_dir).resolve()
    workspace = Path(workspace_dir).resolve()
    ensure_inside_project(source, workspace)
    run = str(run_id)
    for filename in (f"run{run}.mod", f"run{run}.lst", f"run{run}.ext", f"run{run}.cov", data_file, "project_config.json"):
        src = source / filename
        if src.exists() and src.is_file():
            shutil.copy2(src, project_root / filename)
    return project_root


def discover_project_assets(project_dir: Path) -> Dict[str, List[Path]]:
    root = Path(project_dir)
    categories = {"models": [], "data": [], "outputs": [], "figures": [], "reports": [], "scripts": []}
    for path in root.glob("*"):
        if not path.is_file():
            continue
        name = path.name
        suffix = path.suffix.lower()
        if re.fullmatch(r"run\d+\.mod", name, re.IGNORECASE):
            categories["models"].append(path)
        elif suffix in (".csv", ".xlsx") or name.upper().startswith(("SDTAB", "PATAB", "CATAB", "COTAB")):
            categories["data"].append(path)
        elif re.fullmatch(r"run\d+\.(lst|ext|cov)", name, re.IGNORECASE):
            categories["outputs"].append(path)
        elif suffix in (".jpg", ".jpeg", ".png", ".pdf"):
            categories["figures"].append(path)
        elif suffix in (".md", ".docx"):
            categories["reports"].append(path)
        elif suffix in (".py", ".r"):
            categories["scripts"].append(path)
    for compare_dir in root.glob("Compare*"):
        if compare_dir.is_dir():
            for path in compare_dir.iterdir():
                suffix = path.suffix.lower()
                if suffix in (".md", ".docx", ".xlsx"):
                    categories["reports"].append(path)
                elif suffix in (".jpg", ".jpeg", ".png", ".pdf"):
                    categories["figures"].append(path)
                elif suffix == ".csv":
                    categories["data"].append(path)
    return {key: sorted(value, key=lambda item: str(item)) for key, value in categories.items()}


def extract_data_path(mod_path: Path) -> Optional[str]:
    text = Path(mod_path).read_text(encoding="utf-8", errors="ignore")
    match = re.search(r"(?im)^\s*\$DATA\s+(\S+)", text)
    return match.group(1) if match else None


def data_path_status(project_dir: Path, run_id: str, data_file: str = "NM_dat_new.csv") -> DataPathStatus:
    root = Path(project_dir).resolve()
    mod_path = root / f"run{run_id}.mod"
    expected = root / data_file
    current = extract_data_path(mod_path) if mod_path.exists() else None
    current_path = Path(current).expanduser() if current else None
    current_exists = current_path.exists() if current_path else False
    matches = bool(current_path and current_path.resolve() == expected.resolve())
    return DataPathStatus(
        mod_path=mod_path,
        current_path=current,
        expected_path=expected,
        current_exists=current_exists,
        expected_exists=expected.exists(),
        matches_expected=matches,
    )


def _existing_mod_backups(mod_path: Path) -> List[Path]:
    return sorted(mod_path.parent.glob(f"{mod_path.name}.bak-*"))


def rewrite_mod_data_path(mod_path: Path, new_data_path: Path, project_dir: Path) -> Optional[Path]:
    mod = ensure_inside_project(Path(mod_path), project_dir)
    new_data = ensure_inside_project(Path(new_data_path), project_dir)
    text = mod.read_text(encoding="utf-8", errors="ignore")
    if not re.search(r"(?im)^\s*\$DATA\s+\S+", text):
        raise ValueError(f"No $DATA record found in {mod.name}")

    backup_path = None
    if not _existing_mod_backups(mod):
        backup_path = mod.with_name(f"{mod.name}.bak-{datetime.now().strftime('%Y%m%d-%H%M%S')}")
        backup_path.write_text(text, encoding="utf-8")

    replacement = lambda match: f"{match.group(1)}{new_data}{match.group(3)}"
    updated = re.sub(r"(?im)^(\s*\$DATA\s+)(\S+)(.*)$", replacement, text, count=1)
    mod.write_text(updated, encoding="utf-8")
    return backup_path


def resolve_command(template: str, variables: Dict[str, str]) -> CommandResolution:
    formatted = template.format(**variables).strip()
    command = shlex.split(formatted)
    executable = command[0] if command else ""
    available = bool(executable and shutil.which(executable))
    return CommandResolution(command=command, executable=executable, available=available, display=formatted)


def discover_nonmem_template(extra_roots: Optional[Iterable[Path]] = None) -> str:
    command_names = ("nmfe76", "nmfe75", "nmfe74", "nmfe73", "nmfe72", "nmfe71", "nmfe70", "nonmem")
    for name in command_names:
        found = shutil.which(name)
        if found:
            return f"{found} {{model}}"

    roots = [Path("/opt"), Path("/usr/local"), Path.home()]
    if extra_roots:
        roots = list(extra_roots) + roots
    candidates = []
    for root in roots:
        candidates.extend(
            [
                root / "nm760" / "run" / "nmfe76",
                root / "nm750" / "run" / "nmfe75",
                root / "nm74" / "run" / "nmfe74",
                root / "nonmem" / "run" / "nmfe76",
                root / "nonmem" / "run" / "nmfe75",
                root / "nonmem" / "run" / "nonmem",
            ]
        )
    for candidate in candidates:
        if candidate.exists() and os.access(candidate, os.X_OK):
            return f"{candidate} {{model}}"
    return "nmfe76 {model}"


def stream_subprocess(
    command: Iterable[str],
    cwd: Path,
    log: LogFn,
    env: Optional[Dict[str, str]] = None,
) -> int:
    command_list = list(command)
    log(f"$ {' '.join(shlex.quote(part) for part in command_list)}")
    process = subprocess.Popen(
        command_list,
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
        bufsize=1,
    )
    assert process.stdout is not None
    for line in process.stdout:
        log(line.rstrip())
    return_code = process.wait()
    log(f"[exit {return_code}]")
    return return_code


def load_project_config(project_dir: Path) -> Dict:
    config_path = Path(project_dir) / "project_config.json"
    if not config_path.exists():
        return {}
    return json.loads(config_path.read_text(encoding="utf-8"))


def _psn_command(name: str, psn_dir: str) -> str:
    if psn_dir:
        configured = Path(psn_dir) / name
        if configured.exists():
            return str(configured)
    return shutil.which(name) or f"/usr/local/bin/{name}"


def _model_input_columns(project_dir: Path, run_id: str) -> Set[str]:
    """Return the upper-case $INPUT columns declared in run{run_id}.mod."""
    mod_path = Path(project_dir) / f"run{run_id}.mod"
    if not mod_path.exists():
        return set()
    text = mod_path.read_text(encoding="utf-8", errors="ignore")
    match = re.search(r"(?im)^\s*\$INPUT\s+(.+)$", text)
    if not match:
        return set()
    tokens = match.group(1).split()
    return {
        token.split("=", 1)[0].upper()
        for token in tokens
        if token.upper() not in ("INPUT", "C")
    }


def _vpc_stratify_var(project_dir: Path, run_id: str, cfg: Dict) -> Optional[str]:
    """Choose a VPC stratification column that actually exists in the model $INPUT."""
    input_cols = _model_input_columns(project_dir, run_id)
    if not input_cols:
        return None

    psn_cfg = cfg.get("psn_settings", {})
    grouping = cfg.get("grouping", {})
    configured = [
        psn_cfg.get("vpc_stratify"),
        psn_cfg.get("stratify_var"),
        grouping.get("factor"),
        "STUDY",
    ]

    def resolve(candidate) -> Optional[str]:
        if not candidate:
            return None
        parts = [part.strip().upper() for part in str(candidate).split(",") if part.strip()]
        if parts and all(part in input_cols for part in parts):
            return ",".join(parts)
        return None

    for candidate in configured:
        resolved = resolve(candidate)
        if resolved:
            return resolved

    priority = (
        "DOSE", "STUDY", "STUDYID", "STUDYNO", "ARM",
        "ROUTE", "TRT", "RACE", "REGION", "SEX", "ADA", "TYPE", "CMT", "EVID",
    )
    primary = next((candidate for candidate in priority if candidate in input_cols), None)
    if not primary:
        return None

    parts = [primary]
    if primary != "ROUTE" and "ROUTE" in input_cols:
        parts.append("ROUTE")
    elif primary == "ROUTE" and "DOSE" in input_cols:
        parts.append("DOSE")
    return ",".join(parts)


def _vpc_no_of_strata(project_dir: Path, run_id: str, cfg: Dict, stratify_var: Optional[str]) -> Optional[int]:
    """Cap very large nominal strata (e.g. many dose levels) into readable VPC panels."""
    if not stratify_var:
        return None
    primary = stratify_var.split(",")[0].strip().upper()
    max_strata = int(cfg.get("psn_settings", {}).get("vpc_max_strata", 6))
    data_file = cfg.get("data_file", "")
    data_path = Path(project_dir) / data_file if data_file else None
    if not data_path or not data_path.exists():
        return None
    try:
        with data_path.open(newline="", encoding="utf-8", errors="ignore") as handle:
            reader = csv.DictReader(handle)
            headers = [str(name).strip().strip('"').upper() for name in (reader.fieldnames or [])]
            if primary not in headers:
                return None
            actual = next(name for name in (reader.fieldnames or [])
                          if str(name).strip().strip('"').upper() == primary)
            values = {row.get(actual) for row in reader if row.get(actual) not in (None, "")}
        if len(values) > max_strata:
            return max_strata
    except Exception:
        return None
    return None


def psn_vpc_command(project_dir: Path, run_id: str, psn_dir: str = "") -> List[str]:
    cfg = load_project_config(project_dir)
    psn_cfg = cfg.get("psn_settings", {})
    samples = psn_cfg.get("vpc_samples", 500)
    stratify_var = _vpc_stratify_var(project_dir, run_id, cfg)
    no_of_strata = _vpc_no_of_strata(project_dir, run_id, cfg, stratify_var)
    command = _psn_command("vpc", psn_dir)
    cmd = [
        command,
        f"run{run_id}.mod",
        f"-samples={samples}",
        f"-dir=vpc_dir_{run_id}",
        "-idv=TIME",
        "-bin_by_count=1",
        "-no_of_bins=12",
    ]
    if stratify_var:
        cmd.insert(4, f"-stratify_on={stratify_var}")
    if no_of_strata:
        cmd.append(f"-no_of_strata={no_of_strata}")
    return cmd


def psn_bootstrap_command(project_dir: Path, run_id: str, psn_dir: str = "", samples: int = 0) -> List[str]:
    cfg = load_project_config(project_dir)
    psn_cfg = cfg.get("psn_settings", {})
    samples = samples or psn_cfg.get("bootstrap_samples", 200)
    command = _psn_command("bootstrap", psn_dir)
    return [
        command,
        f"run{run_id}.mod",
        f"-samples={samples}",
        f"-dir=bootstrap_dir_{run_id}",
    ]


def psn_scm_command(project_dir: Path, run_id: str, log: LogFn, psn_dir: str = "") -> List[str]:
    root = Path(project_dir)
    command = _psn_command("scm", psn_dir)
    config_path = root / f"scm_run_{run_id}.conf"
    if not config_path.exists():
        config_path.write_text(default_scm_config(run_id, root), encoding="utf-8")
        log(f"Created editable SCM config: {config_path.name}")
    return [
        command,
        config_path.name,
        f"-dir=scm_dir_{run_id}",
    ]


def default_scm_config(run_id: str, project_dir: Optional[Path] = None) -> str:
    root = Path(project_dir) if project_dir else Path.cwd()
    mod_path = root / f"run{run_id}.mod"
    model_columns: Set[str] = set()
    if mod_path.exists():
        mod_text = mod_path.read_text(encoding="utf-8", errors="ignore")
        match = re.search(r"(?im)^\s*\$INPUT\s+(.+)$", mod_text)
        if match:
            model_columns = {
                token.split("=", 1)[0].upper()
                for token in match.group(1).split()
                if token.upper() not in ("INPUT", "C")
            }
    cfg = load_project_config(root)
    data_file = cfg.get("data_file", "")
    data_columns: Set[str] = set()
    if data_file:
        data_path = root / data_file
        if data_path.exists():
            with data_path.open(newline="", encoding="utf-8", errors="ignore") as handle:
                header = handle.readline()
                data_columns = {
                    col.strip().strip('"').upper()
                    for col in header.split(",")
                    if col.strip()
                }

    continuous_names = {"WT", "AGE", "BSA", "HB", "ALB", "CLCR", "EGFR", "BMI", "DOSE"}
    categorical_names = {"SEX", "STUDY", "STUD", "ROUTE", "ADA", "RACE", "TRT", "ARM",
                         "REGION", "TYPE", "GROUP", "COHORT", "TREATMENT"}
    available = sorted((model_columns & (continuous_names | categorical_names)) & data_columns)
    cont_covs = [name for name in available if name in continuous_names]
    cat_covs = [name for name in available if name in categorical_names]

    params: List[str] = []
    if mod_path.exists():
        mod_text = mod_path.read_text(encoding="utf-8", errors="ignore")
        params = sorted(set(re.findall(r"(?im)\bTV([A-Za-z0-9_]+)\s*=\s*THETA", mod_text)))
    if not params:
        params = ["CL", "V1", "V2", "Q"]

    lines = [
        f"model=run{run_id}.mod",
        "search_direction=forward",
        "p_forward=0.05",
        "p_backward=0.01",
        "linearize=0",
        f"continuous_covariates={','.join(cont_covs)}",
        f"categorical_covariates={','.join(cat_covs)}",
        "",
        "[test_relations]",
    ]
    for param in params:
        lines.append(f"{param}={','.join(available)}")
    lines.extend([
        "",
        "[valid_states]",
        f"continuous = 1,{max(len(cont_covs) + 3, 3)}",
        f"categorical = 1,{max(len(cat_covs) + 1, 1)}",
    ])
    return "\n".join(lines) + "\n"


def build_psn_execute_command(run_id: str, directory: Optional[str] = None) -> List[str]:
    run = str(run_id)
    if directory:
        return ["execute", f"run{run}.mod", f"-directory={directory}"]
    return ["execute", f"run{run}.mod", "-model_dir_name"]


def mac_nonmem_env() -> Dict[str, str]:
    sdk_path = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    env = os.environ.copy()
    if Path(sdk_path).exists():
        env["SDKROOT"] = sdk_path
        env["LIBRARY_PATH"] = f"{sdk_path}/usr/lib"
        env["CPATH"] = f"{sdk_path}/usr/include"
    return env


def archive_existing_paths(project_dir: Path, paths: Iterable[Path], label: str) -> Optional[Path]:
    root = Path(project_dir).resolve()
    # Resolve to real paths and deduplicate (critical for case-insensitive APFS)
    seen: set[str] = set()
    existing: List[Path] = []
    for p in paths:
        abs_path = ensure_inside_project(p, root)
        if not abs_path.exists():
            continue
        real = str(abs_path.resolve())
        if real in seen:
            continue
        seen.add(real)
        existing.append(abs_path)
    if not existing:
        return None
    archive = root / f"WorkbenchArchive-{label}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    archive.mkdir(parents=True, exist_ok=True)
    for path in existing:
        destination = archive / path.name
        if destination.exists():
            destination = archive / f"{path.stem}-{datetime.now().strftime('%H%M%S')}{path.suffix}"
        shutil.move(str(path), str(destination))
    return archive


def dated_compare_dir(project_dir: Path, prev_run: str, curr_run: str) -> Path:
    date_str = datetime.now().strftime("%Y%m%d")
    output = Path(project_dir) / f"Compare{prev_run}-{curr_run}-{date_str}"
    output.mkdir(parents=True, exist_ok=True)
    return output


class TaskRunner:
    def __init__(self, settings: WorkbenchSettings, log: LogFn):
        self.settings = settings
        self.log = log

    @property
    def root(self) -> Path:
        return self.settings.project_path

    @property
    def software_root(self) -> Path:
        return Path(__file__).resolve().parent

    def script_path(self, script: str) -> Path:
        software_script = self.software_root / script
        if software_script.exists():
            return software_script
        return self.root / script

    def run_nonmem(self) -> int:
        model = f"run{self.settings.curr_run}.mod"
        mod_path = self.root / model

        # --- PREFLIGHT VALIDATION -------------------------------------------------
        preflight_code = self._preflight_mod_check(mod_path)
        if preflight_code != 0:
            return preflight_code

        # --- RUN ------------------------------------------------------------------
        template = self.settings.psn_execute_template or self.settings.nonmem_template
        resolution = resolve_command(
            template,
            {"model": model, "run": self.settings.curr_run, "project_dir": str(self.root)},
        )
        if not resolution.command:
            self.log("NONMEM command template is empty.")
            return 2
        if not resolution.available:
            self.log(f"NONMEM command is not configured or not in PATH: {resolution.executable}")
            return 127
        return stream_subprocess(resolution.command, self.root, self.log, env=mac_nonmem_env())

    def _preflight_mod_check(self, mod_path: Path) -> int:
        """Validate a .mod file before feeding it to NONMEM.
        Returns 0 if OK, >0 if validation found blocking errors.
        """
        if not mod_path.exists():
            self.log(f"[PREFLIGHT] Model not found: {mod_path.name}")
            return 1
        if not HAS_VALIDATOR or validate_mod is None:
            self.log("[PREFLIGHT] mod_validator not available — skipping preflight check")
            return 0

        csv_path = self.root / self.settings.data_file
        result = validate_mod(mod_path, project_dir=self.root,
                              csv_path=csv_path if csv_path.exists() else None,
                              run_id=self.settings.curr_run)

        if result.passed:
            if result.issues:
                # Only warnings
                for iss in result.issues:
                    self.log(f"[PREFLIGHT] WARN L{iss.line_number} {iss.section}: {iss.message}")
            self.log(f"[PREFLIGHT] ✓ {mod_path.name} passed ({len(result.issues)} warnings)")
            return 0

        # Blocking errors found — log them all and return early
        self.log(f"[PREFLIGHT] ✗ {mod_path.name} has {result.critical_count} blocking error(s):")
        for iss in result.issues:
            tag = "ERROR" if iss.severity == "error" else "WARN"
            self.log(f"  [{tag}] L{iss.line_number} {iss.section}: {iss.message}")
            if iss.fix_hint:
                self.log(f"         → {iss.fix_hint}")

        # Attempt auto‑fix for auto_fixable errors
        auto_fixable = [iss for iss in result.issues
                        if iss.severity == "error" and iss.auto_fixable]
        if auto_fixable and HAS_GENERATOR:
            self.log(f"[PREFLIGHT] Attempting auto‑fix for {len(auto_fixable)} error(s)...")
            try:
                self._auto_fix_mod(mod_path)
                # Re‑validate
                result2 = validate_mod(mod_path, project_dir=self.root,
                                       csv_path=csv_path if csv_path.exists() else None,
                                       run_id=self.settings.curr_run)
                if result2.passed:
                    self.log("[PREFLIGHT] ✓ Auto‑fix succeeded")
                    return 0
                else:
                    remaining = result2.critical_count
                    self.log(f"[PREFLIGHT] Auto‑fix reduced errors to {remaining}, "
                             f"but {remaining} error(s) remain.  Manual fix needed.")
                    return 2 + remaining
            except Exception as exc:
                self.log(f"[PREFLIGHT] Auto‑fix failed: {exc}")
                return 3
        elif auto_fixable:
            self.log("[PREFLIGHT] Auto‑fix available but model_generator not imported — skipping")
            return 2 + result.critical_count

        return 2 + result.critical_count

    def _auto_fix_mod(self, mod_path: Path) -> None:
        """Apply deterministic fixes to common .mod issues."""
        from model_generator import apply_modifications, Modification, strip_inline_dataset_rows
        from mod_validator import validate_mod

        text = mod_path.read_text(encoding="utf-8")
        csv_path = self.root / self.settings.data_file
        modifications: List[Modification] = []

        # 0. Strip embedded data rows BEFORE any other fix.
        #    LLMs sometimes paste CSV rows after $INPUT/$DATA — this must be cleaned first
        #    or subsequent fixes (fix_input, fix_data) will operate on corrupted text.
        cleaned = strip_inline_dataset_rows(text)
        if cleaned != text:
            mod_path.write_text(cleaned, encoding="utf-8")
            self.log(f"[PREFLIGHT] Stripped inline data rows from {mod_path.name}")
            text = cleaned

        # Determine current run ID from filename
        m = re.match(r"run(\d+)", mod_path.stem, re.IGNORECASE)
        run_id = m.group(1) if m else self.settings.curr_run

        # 1. Fix $INPUT column order (if CSV available)
        if csv_path.exists():
            header = csv_path.read_text(encoding="utf-8", errors="ignore").splitlines()[0]
            columns = [c.strip().strip("\"").upper() for c in header.split(",") if c.strip()]
            modifications.append(Modification(
                action="fix_input",
                params={"columns": columns},
            ))

        # 2. Fix $DATA path
        modifications.append(Modification(
            action="fix_data",
            params={"data_file": self.settings.data_file},
        ))

        # 3. Fix $TABLE file IDs
        modifications.append(Modification(
            action="fix_table_ids",
            params={"run_id": run_id},
        ))

        # 3b. Rebuild table content from actual $INPUT/$PK/ETA references.
        modifications.append(Modification(
            action="fix_table_content",
            params={"run_id": run_id},
        ))

        # 4. Fix THETA boundary format
        modifications.append(Modification(
            action="fix_theta_boundaries",
            params={},
        ))

        # 5. Avoid identical positive IIV initials (covariance stability).
        modifications.append(Modification(
            action="diversify_iiv",
            params={},
        ))

        # Apply all modifications
        result = apply_modifications(text, modifications)
        mod_path.write_text(result, encoding="utf-8")
        self.log(f"[PREFLIGHT] Auto‑fix applied to {mod_path.name}")

    def run_psn_vpc(self) -> int:
        self._ensure_project_config()
        archive = archive_existing_paths(self.root, [self.root / f"vpc_dir_{self.settings.curr_run}"], "psn")
        if archive:
            self.log(f"Archived previous VPC directory to: {archive.name}")
        command = psn_vpc_command(self.root, self.settings.curr_run, self.settings.psn_dir)
        if not shutil.which(command[0]) and not Path(command[0]).exists():
            self.log(f"PsN vpc command not found: {command[0]}")
            return 127
        return stream_subprocess(command, self.root, self.log, env=mac_nonmem_env())

    def run_r_diagnostics(self) -> int:
        final_code = 0
        for target in (self.run_gof_plot, self.run_individual_plot, self.run_vpc_plot):
            code = target()
            final_code = code if code else final_code
        return final_code

    def run_gof_plot(self) -> int:
        return self._run_r_diagnostic_script(
            script="gof_plot_script.R",
            label="GOF plot",
            outputs=[f"GOF_mod{self.settings.curr_run}.jpg", f"GOF_mod{self.settings.curr_run}.JPG"],
        )

    def run_individual_plot(self) -> int:
        return self._run_r_diagnostic_script(
            script="individual_plot_script.R",
            label="Individual DV-Time plot",
            outputs=[f"Individual_Plots_Run{self.settings.curr_run}.pdf"],
        )

    def run_vpc_plot(self) -> int:
        return self._run_r_diagnostic_script(
            script="vpc_plot_script.R",
            label="VPC plot",
            outputs=[
                f"VPC_mod{self.settings.curr_run}.jpg",
                f"VPC_mod{self.settings.curr_run}.JPG",
                f"VPC_Stratified_mod{self.settings.curr_run}.jpg",
                f"VPC_Stratified_mod{self.settings.curr_run}.JPG",
            ],
        )

    def _ensure_project_config(self) -> None:
        """Auto-create or repair project_config.json grouping for the current dataset."""
        config_path = self.root / "project_config.json"

        data_file = self.settings.data_file
        data_path = self.root / data_file
        columns: List[str] = []
        if data_path.exists():
            try:
                import pandas as pd
                df = pd.read_csv(data_path, nrows=1)
                cols = [c.upper() for c in df.columns]
                columns = cols
            except Exception:
                pass

        candidates = ("STUDY", "STUDYID", "STUDYNO", "DOSE", "ARM", "TRT",
                      "ROUTE", "SEX", "RACE", "REGION")
        group_factor = next((c for c in candidates if c in columns), "STUDY")

        if config_path.exists():
            try:
                with open(config_path, "r", encoding="utf-8") as f:
                    config = json.load(f)
                current_factor = config.get("grouping", {}).get("factor", "STUDY")
                if current_factor in columns:
                    config.setdefault("grouping", {})["factor"] = current_factor
                    config.setdefault("psn_settings", {})["stratify_var"] = current_factor
                    if "ROUTE" in columns and current_factor != "ROUTE":
                        config["psn_settings"]["vpc_stratify"] = f"{current_factor},ROUTE"
                    elif current_factor == "ROUTE" and "DOSE" in columns:
                        config["psn_settings"]["vpc_stratify"] = "ROUTE,DOSE"
                    else:
                        config["psn_settings"]["vpc_stratify"] = current_factor
                    with open(config_path, "w", encoding="utf-8") as f:
                        json.dump(config, f, indent=2, ensure_ascii=False)
                    return
                if not group_factor or group_factor == "STUDY" and "STUDY" not in columns and "DOSE" not in columns:
                    return
                config.setdefault("grouping", {})["factor"] = group_factor
                config["grouping"]["labels"] = {}
                config.setdefault("psn_settings", {})["stratify_var"] = group_factor
                if "ROUTE" in columns and group_factor != "ROUTE":
                    config["psn_settings"]["vpc_stratify"] = f"{group_factor},ROUTE"
                elif group_factor == "ROUTE" and "DOSE" in columns:
                    config["psn_settings"]["vpc_stratify"] = "ROUTE,DOSE"
                else:
                    config["psn_settings"]["vpc_stratify"] = group_factor
                with open(config_path, "w", encoding="utf-8") as f:
                    json.dump(config, f, indent=2, ensure_ascii=False)
                self.log(f"Repaired project_config.json grouping factor: {group_factor}")
            except Exception:
                return
            return

        # Create the config when missing.
        if data_path.exists():
            try:
                import pandas as pd
                df = pd.read_csv(data_path, nrows=1)
                cols = [c.upper() for c in df.columns]
                for candidate in ("STUDY", "STUDYID", "STUDYNO", "DOSE", "ARM", "TRT",
                                  "ROUTE", "SEX", "RACE", "REGION"):
                    if candidate in cols:
                        group_factor = candidate
                        break
            except Exception:
                pass
        vpc_stratify = group_factor
        if "ROUTE" in columns and group_factor != "ROUTE":
            vpc_stratify = f"{group_factor},ROUTE"
        elif group_factor == "ROUTE" and "DOSE" in columns:
            vpc_stratify = "ROUTE,DOSE"
        default_config = {
            "project_name": self.root.name,
            "units": {"time": "Time (h)", "conc": "Concentration"},
            "grouping": {"factor": group_factor, "labels": {}},
            "psn_settings": {
                "vpc_samples": 500,
                "bootstrap_samples": 200,
                "stratify_var": group_factor,
                "vpc_stratify": vpc_stratify,
            },
        }
        config_path.write_text(
            json.dumps(default_config, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        self.log(f"Auto-generated project_config.json (grouping factor: {group_factor})")

    def _find_sdtab_file(self, run_id: str) -> str:
        """Detect actual sdtab filename from mod file $TABLE record or project directory.

        Priority:
        1. Parse FILE= from the mod file's $TABLE line (e.g. sdtab1_Dofetilide_Oct_1)
        2. Scan project directory for any sdtab* file
        3. Fallback to conventional name sdtab{run_id}
        """
        # 1. Try parsing $TABLE FILE= from mod file
        mod_path = self.root / f"run{run_id}.mod"
        if mod_path.exists():
            try:
                text = mod_path.read_text(encoding="utf-8", errors="ignore")
                import re
                match = re.search(r"(?im)^\s*\$TABLE\b.*?\bFILE\s*=\s*(\S+)", text)
                if match:
                    filename = match.group(1).rstrip(",;")
                    candidate = self.root / filename
                    if candidate.exists():
                        self.log(f"Detected sdtab from $TABLE: {filename}")
                        return filename
            except Exception:
                pass

        # 2. Scan project directory for any sdtab* file
        candidates = sorted(
            p for p in self.root.glob("sdtab*") if p.is_file()
        )
        if candidates:
            self.log(f"Detected sdtab from directory scan: {candidates[0].name}")
            return candidates[0].name

        # 3. Fallback to conventional name
        return f"sdtab{run_id}"

    def _run_r_diagnostic_script(self, script: str, label: str, outputs: List[str]) -> int:
        run = self.settings.curr_run
        self._ensure_project_config()
        archive = archive_existing_paths(self.root, [self.root / output for output in outputs], label.lower().replace(" ", "-"))
        if archive:
            self.log(f"Archived previous {label} outputs to: {archive.name}")
        script_path = self.script_path(script)
        if not script_path.exists():
            self.log(f"Skip {label}: missing {script}")
            return 2
        # Pass detected sdtab filename for scripts that need it (gof, individual plots)
        rscript_args = [self.settings.rscript, str(script_path), run]
        if script in ("gof_plot_script.R", "individual_plot_script.R"):
            sdtab_name = self._find_sdtab_file(run)
            rscript_args.append(sdtab_name)
        return stream_subprocess(rscript_args, self.root, self.log)

    def run_pk_parameters(self) -> int:
        run = self.settings.curr_run
        archive = archive_existing_paths(
            self.root,
            [
                self.root / f"data_run{run}.csv",
                self.root / f"Run{run}_Final_Parameters.docx",
                self.root / f"Table5_Run{run}_Final_Parameters.docx",
            ],
            "pk-parameters",
        )
        if archive:
            self.log(f"Archived previous PK parameter outputs to: {archive.name}")
        script_path = self.script_path("pk parameters script.R")
        if not script_path.exists():
            self.log("Skip PK parameter extraction: missing pk parameters script.R")
            return 2
        return stream_subprocess([self.settings.rscript, str(script_path), run], self.root, self.log)

    def run_bootstrap(self) -> int:
        archive = archive_existing_paths(self.root, [self.root / f"bootstrap_dir_{self.settings.curr_run}"], "bootstrap")
        if archive:
            self.log(f"Archived previous bootstrap directory to: {archive.name}")
        command = psn_bootstrap_command(self.root, self.settings.curr_run, self.settings.psn_dir, self.settings.bootstrap_samples)
        if not shutil.which(command[0]) and not Path(command[0]).exists():
            self.log(f"PsN bootstrap command not found: {command[0]}")
            return 127
        return stream_subprocess(command, self.root, self.log, env=mac_nonmem_env())

    def run_scm(self) -> int:
        archive = archive_existing_paths(self.root, [self.root / f"scm_dir_{self.settings.curr_run}"], "scm")
        if archive:
            self.log(f"Archived previous SCM directory to: {archive.name}")
        command = psn_scm_command(self.root, self.settings.curr_run, self.log, self.settings.psn_dir)
        if not shutil.which(command[0]) and not Path(command[0]).exists():
            self.log(f"PsN scm command not found: {command[0]}")
            return 127
        return stream_subprocess(command, self.root, self.log, env=mac_nonmem_env())

    def run_parameter_audit(self) -> int:
        from audit_tasks import run_parameter_audit

        return run_parameter_audit(self.settings, self.log)

    def run_gof_audit(self) -> int:
        from audit_tasks import run_gof_audit

        return run_gof_audit(self.settings, self.log)

    def run_vpc_audit(self) -> int:
        from audit_tasks import run_vpc_audit

        return run_vpc_audit(self.settings, self.log)

    def run_eda(self, csv_file: str = "") -> int:
        """Run EDA (Exploratory Data Analysis) on a dataset."""
        data_file = csv_file if csv_file else self.settings.data_file
        # csv_file may be an absolute path; handle both cases
        if Path(data_file).is_absolute():
            data_path = Path(data_file)
        else:
            data_path = self.root / data_file
        if not data_path.exists():
            self.log(f"EDA: dataset not found: {data_path}")
            return 2
        out_prefix = f"EDA_{data_path.stem}"
        script_path = self.script_path("eda_analysis.R")
        if not script_path.exists():
            self.log(f"Skip EDA: missing eda_analysis.R")
            return 2
        return stream_subprocess(
            [self.settings.rscript, str(script_path), str(data_path), out_prefix],
            self.root, self.log
        )

    def run_ct_curves(self, csv_file: str = "") -> int:
        """Run concentration-time curve plots on a dataset."""
        data_file = csv_file if csv_file else self.settings.data_file
        if Path(data_file).is_absolute():
            data_path = Path(data_file)
        else:
            data_path = self.root / data_file
        if not data_path.exists():
            self.log(f"C-T curves: dataset not found: {data_path}")
            return 2
        out_prefix = f"CT_{data_path.stem}"
        script_path = self.script_path("ct_curves_plot.R")
        if not script_path.exists():
            self.log(f"Skip C-T curves: missing ct_curves_plot.R")
            return 2
        return stream_subprocess(
            [self.settings.rscript, str(script_path), str(data_path), out_prefix],
            self.root, self.log
        )


class BackgroundJob:
    def __init__(self, name: str, target: Callable[[], int], on_done: Callable[[str, int], None]):
        self.name = name
        self.target = target
        self.on_done = on_done
        self.thread = threading.Thread(target=self._run, daemon=True)

    def start(self) -> None:
        self.thread.start()

    def _run(self) -> None:
        try:
            code = self.target()
        except Exception as exc:
            code = 1
            # The GUI owns user-facing exception logging via the target logger.
            print(f"{self.name} failed: {exc}")
        self.on_done(self.name, code)
