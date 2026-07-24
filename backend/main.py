#!/usr/bin/env python3
"""
AutoPMX Web Backend — FastAPI Server
Bridges the React frontend with Python/R analysis tools.
"""

import os
import sys
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse, FileResponse
from pydantic import BaseModel

# Add resources to path
RESOURCES_DIR = Path(__file__).resolve().parent.parent / "resources"
sys.path.insert(0, str(RESOURCES_DIR))

app = FastAPI(title="AutoPMX Web API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================
# Settings
# ============================================

SETTINGS_FILE = Path.home() / ".autopmx_web_settings.json"

def load_settings():
    if SETTINGS_FILE.exists():
        try:
            return json.loads(SETTINGS_FILE.read_text())
        except Exception:
            pass
    return {
        "llmProvider": "openai",
        "openaiKey": "",
        "openaiModel": "gpt-4o",
        "openaiEndpoint": "https://api.openai.com/v1",
        "deepseekKey": "",
        "deepseekModel": "deepseek-chat",
        "deepseekEndpoint": "https://api.deepseek.com/v1",
        "rscriptPath": "Rscript",
        "pythonPath": "python3",
    }

def save_settings(settings):
    SETTINGS_FILE.write_text(json.dumps(settings, indent=2))

# ============================================
# Asset categories
# ============================================

ASSET_CATEGORIES = {
    "models": {"title": "Models", "extensiosn": [".mod", ".ctl"]},
    "datasets": {"title": "Datasets", "extensiosn": [".csv", ".txt", ".dat"]},
    "outputs": {"title": "Outputs", "extensiosn": [".lst", ".ext", ".cov", ".cor", ".coi", ".phi", ".shk", ".xml"]},
    "diagnostics": {"title": "Diagnostics", "extensiosn": [".pdf", ".png", ".jpg", ".html"]},
    "scripts": {"title": "Scripts", "extensiosn": [".R", ".py", ".sh"]},
    "reports": {"title": "Reports", "extensiosn": [".md"]},
    "other": {"title": "Other", "extensiosn": []},
}

EXT_TO_CATEGORY = {}
for cat_id, cat_info in ASSET_CATEGORIES.items():
    for ext in cat_info["extensiosn"]:
        EXT_TO_CATEGORY[ext] = cat_id


def get_category(filename):
    ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    return EXT_TO_CATEGORY.get(ext, "other")


def scan_directory(root_dir: Path):
    """Recursively scan directory for project files."""
    files = []
    ignore_dirs = {'.git', '__pycache__', '.venv', 'venv', 'node_modules', '.DS_Store', 'NM_run'}

    for entry in sorted(root_dir.rglob("*")):
        if entry.is_dir():
            continue
        if any(part in ignore_dirs for part in entry.parts):
            continue

        rel_path = str(entry.relative_to(root_dir))
        files.append({
            "name": entry.name,
            "path": rel_path,
            "category": get_category(entry.name),
            "size": entry.stat().st_size,
        })

    return files


def parse_parameters_from_ext(ext_path: Path):
    """Parse parameter estimates from .ext file."""
    params = []
    try:
        with open(ext_path, 'r') as f:
            lines = f.readlines()

        # Find TABLE header
        in_table = False
        header_idx = -1
        for i, line in enumerate(lines):
            if line.strip().startswith("TABLE NO."):
                in_table = True
            if in_table and "THETA" in line.upper():
                header_idx = i
                break

        if header_idx < 0:
            return params

        headers = lines[header_idx].strip().split()
        final_est_idx = -1
        for i, line in enumerate(lines[header_idx + 1:], header_idx + 1):
            if not line.strip():
                break
            values = line.strip().split()
            if len(values) >= len(headers):
                final_est_idx = i

        if final_est_idx < 0:
            return params

        final_row = lines[final_est_idx].strip().split()
        se_row = None
        if final_est_idx + 1 < len(lines):
            se_row = lines[final_est_idx + 1].strip().split()

        for i, hdr in enumerate(headers):
            if i >= len(final_row):
                break
            val = final_row[i]
            se = se_row[i] if se_row and i < len(se_row) else "N/A"
            try:
                v = float(val)
                s = float(se)
                rse = round(abs(s / v * 100), 1) if v != 0 else 0
                params.append({
                    "parameter": hdr,
                    "estimate": str(v),
                    "se": str(s),
                    "rse": f"{rse}%",
                })
            except (ValueError, ZeroDivisionError):
                pass
    except Exception as e:
        print(f"Parameter parse error: {e}")

    return params


# ============================================
# API Routes
# ============================================

@app.get("/api/project/scan")
async def project_scan(dir: str = Query(...)):
    """Scan project directory and return categorized file list."""
    root = Path(dir)
    if not root.exists():
        raise HTTPException(404, f"Directory not found: {dir}")
    files = scan_directory(root)
    return {"files": files, "projectDir": str(root), "projectName": root.name}


@app.get("/api/project/file")
async def project_file(dir: str = Query(...), path: str = Query(...)):
    """Get file content."""
    full_path = Path(dir) / path
    if not full_path.exists():
        raise HTTPException(404, f"File not found: {path}")
    try:
        content = full_path.read_text(encoding='utf-8', errors='replace')
        return {"content": content, "path": path, "size": full_path.stat().st_size}
    except Exception as e:
        raise HTTPException(500, str(e))


@app.get("/api/project/file-content")
async def project_file_raw(dir: str = Query(...), path: str = Query(...)):
    """Serve file content as raw (for images)."""
    full_path = Path(dir) / path
    if not full_path.exists():
        raise HTTPException(404)
    ext = full_path.suffix.lower()
    media_types = {
        ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
        ".gif": "image/gif", ".webp": "image/webp", ".svg": "image/svg+xml",
        ".pdf": "application/pdf",
    }
    media_type = media_types.get(ext, "application/octet-stream")
    return FileResponse(full_path, media_type=media_type)


@app.get("/api/project/parameters")
async def project_parameters(dir: str = Query(...), mod: str = Query(...)):
    """Parse parameter estimates from associated .ext file."""
    mod_path = Path(dir) / mod
    base = mod_path.stem
    ext_path = mod_path.with_suffix(".ext")

    if not ext_path.exists():
        return {"parameters": [], "message": "No .ext file found"}

    params = parse_parameters_from_ext(ext_path)
    return {"parameters": params, "modFile": mod}


# ============================================
# Run Actions
# ============================================

class RunRequest(BaseModel):
    projectDir: str
    command: Optional[str] = None
    runId: Optional[str] = None
    modFile: Optional[str] = None
    provider: Optional[str] = None
    apiKey: Optional[str] = None


@app.post("/api/run")
async def run_command(req: RunRequest):
    """Execute a command in the project directory."""
    try:
        result = subprocess.run(
            req.command, shell=True, cwd=req.projectDir,
            capture_output=True, text=True, timeout=600,
        )
        output = result.stdout
        if result.stderr:
            output += "\n[stderr]\n" + result.stderr
        return {"output": output, "returncode": result.returncode}
    except subprocess.TimeoutExpired:
        raise HTTPException(408, "Command timed out (10 min)")
    except Exception as e:
        raise HTTPException(500, str(e))


def _run_analysis(project_dir: str, run_id: str, mod_file: str, analysis_type: str) -> dict:
    """Run an analysis using the CLI."""
    cli_path = RESOURCES_DIR / "autopmx_cli.py"

    type_map = {
        "gof": "gof-plot",
        "vpc": "vpc-plot",
        "individual": "individual-plot",
        "diagnostics": "diagnostics",
    }

    cmd = type_map.get(analysis_type)
    if not cmd:
        raise ValueError(f"Unknown analysis type: {analysis_type}")

    settings = load_settings()
    python = settings.get("pythonPath", "python3")

    try:
        result = subprocess.run(
            [python, str(cli_path), cmd, "--project-dir", project_dir, "--run-id", run_id],
            capture_output=True, text=True, timeout=300,
            cwd=project_dir,
        )
        return {"output": result.stdout or "Done.", "returncode": result.returncode}
    except Exception as e:
        return {"output": f"Error: {e}", "returncode": -1}


@app.post("/api/run/gof")
async def run_gof(req: RunRequest):
    return _run_analysis(req.projectDir, req.runId, req.modFile, "gof")


@app.post("/api/run/vpc")
async def run_vpc(req: RunRequest):
    return _run_analysis(req.projectDir, req.runId, req.modFile, "vpc")


@app.post("/api/run/individual")
async def run_individual(req: RunRequest):
    return _run_analysis(req.projectDir, req.runId, req.modFile, "individual")


@app.post("/api/run/diagnostics")
async def run_diagnostics(req: RunRequest):
    return _run_analysis(req.projectDir, req.runId, req.modFile, "diagnostics")


@app.post("/api/run/audit")
async def run_audit(req: RunRequest):
    """Run AI audit on a model."""
    project_dir = Path(req.projectDir)
    mod_path = project_dir / req.modFile

    if not mod_path.exists():
        raise HTTPException(404, f"Model file not found: {req.modFile}")

    try:
        mod_content = mod_path.read_text()
    except Exception:
        mod_content = "(could not read)"

    lst_path = mod_path.with_suffix(".lst")
    lst_content = ""
    if lst_path.exists():
        try:
            lst_content = lst_path.read_text()[:10000]
        except Exception:
            pass

    settings = load_settings()
    provider = req.provider or settings.get("llmProvider", "openai")
    api_key = req.apiKey or settings.get("openaiKey") or settings.get("deepseekKey", "")

    if not api_key:
        raise HTTPException(400, "No API key configured. Set it in Settings > API Keys.")

    # Build prompt
    system_prompt = """You are a Pharmacometrics expert specializing in NONMEM PopPK model auditing.
Review the provided NONMEM control file and output. Provide a structured audit report covering:

1. Model structure adequacy
2. Parameter estimate reasonableness
3. Goodness-of-fit diagnostics interpretation
4. Potential issues and recommendations
5. Overall model quality assessment

Be concise and professional. Use bullet points."""

    user_prompt = f"""## Model File: {req.modFile}

```nonmem
{mod_content[:5000]}
```

## Output (excerpt):
```
{lst_content[:3000]}
```

Please audit this model and provide your assessment."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]

    import requests

    if provider == "deepseek":
        endpoint = settings.get("deepseekEndpoint", "https://api.deepseek.com/v1") + "/chat/completions"
        model = settings.get("deepseekModel", "deepseek-chat")
    else:
        endpoint = settings.get("openaiEndpoint", "https://api.openai.com/v1") + "/chat/completions"
        model = settings.get("openaiModel", "gpt-4o")

    try:
        resp = requests.post(
            endpoint,
            json={"model": model, "messages": messages, "temperature": 0.3},
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=120,
        )
        resp.raise_for_status()
        data = resp.json()
        report = data["choices"][0]["message"]["content"]
        return {"report": report, "runId": req.runId}
    except requests.exceptions.RequestException as e:
        raise HTTPException(502, f"LLM API error: {e}")


# ============================================
# AI Chat
# ============================================

class ChatRequest(BaseModel):
    messages: list
    provider: str = "openai"
    apiKey: str = ""
    model: str = "gpt-4o"
    endpoint: str = "https://api.openai.com/v1"


@app.post("/api/chat")
async def chat(req: ChatRequest):
    """Send a message to the LLM."""
    import requests

    endpoint = req.endpoint.rstrip("/") + "/chat/completions"
    if not req.apiKey:
        settings = load_settings()
        req.apiKey = settings.get("openaiKey", "") if req.provider == "openai" else settings.get("deepseekKey", "")

    if not req.apiKey:
        raise HTTPException(400, "No API key provided")

    try:
        resp = requests.post(
            endpoint,
            json={"model": req.model, "messages": req.messages, "temperature": 0.7},
            headers={"Authorization": f"Bearer {req.apiKey}"},
            timeout=60,
        )
        resp.raise_for_status()
        data = resp.json()
        return {"content": data["choices"][0]["message"]["content"]}
    except requests.exceptions.RequestException as e:
        raise HTTPException(502, f"LLM API error: {e}")


# ============================================
# Settings
# ============================================

@app.get("/api/settings")
async def get_settings():
    return load_settings()


@app.put("/api/settings")
async def put_settings(settings: dict):
    save_settings(settings)
    return {"status": "ok"}


# ============================================
# Main
# ============================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8899)
