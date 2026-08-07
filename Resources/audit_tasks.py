import base64
import json
import re
import shutil
from pathlib import Path
from typing import Dict, List, Optional

from workbench_core import WorkbenchSettings, dated_compare_dir, stream_subprocess


def _inside(path: Path, base: Path) -> bool:
    try:
        path.resolve().relative_to(base.resolve())
        return True
    except ValueError:
        return False


def _rule_sources(rules_file: str) -> List[str]:
    sources = re.split(r"[,;\n]+", rules_file or "")
    cleaned = [source.strip() for source in sources if source.strip()]
    return cleaned or ["poppk_rules.json", "NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md"]


def _load_rules(root: Path, rules_file: str) -> str:
    software_root = Path(__file__).resolve().parent
    sections = []
    missing = []

    for source in _rule_sources(rules_file):
        candidates = [Path(source)] if Path(source).is_absolute() else [root / source, software_root / source]
        path = next((candidate for candidate in candidates if candidate.exists() and candidate.is_file()), None)
        if path is None:
            missing.append(source)
            continue
        if not (_inside(path, root) or _inside(path, software_root)):
            missing.append(f"{source} (outside AutoPMX workspace)")
            continue
        text = path.read_text(encoding="utf-8", errors="ignore").strip()
        if text:
            sections.append(f"### AutoPMX Rule Source: {path.name}\nPath: {path}\n\n{text[:80000]}")

    if missing:
        sections.append("### Missing/skipped Rule Sources\n" + "\n".join(f"- {item}" for item in missing))

    if not sections:
        return "内置准则：RSE < 30%, Shrinkage < 30%, mAb Vc 3-5L；$INPUT 保留 C，$DATA 使用 IGNORE=C；优先使用 AutoPMX NONMEM 模板。"
    return "\n\n---\n\n".join(sections)


def _openai_client(base_url: str, api_key: str = "lm-studio", timeout_sec: int = 180):
    from openai import OpenAI
    from httpx import Timeout

    return OpenAI(
        base_url=base_url,
        api_key=api_key or "lm-studio",
        timeout=Timeout(timeout_sec, connect=15.0),
    )


def _read_lst_source_truth(root: Path, run_id: str, role_label: str) -> Dict[str, str]:
    path = root / f"run{run_id}.lst"
    try:
        content = path.read_text(encoding="utf-8", errors="ignore")
        ofv = re.search(r"(?:OBJV:|MINIMUM VALUE OF OBJECTIVE FUNCTION).*?([\d\.\-]+)", content, re.I)
        aic = re.search(r"AIC.*?([\d\.\-]+)", content, re.I)
        estimates = re.search(r"FINAL PARAMETER ESTIMATE[\s\S]*?(?=\s*1\s*TOTAL)", content)
        se_matrix = re.search(r"STANDARD ERROR OF ESTIMATE[\s\S]*?(?=\s*1\s*TOTAL)", content)
        shrinkage = re.search(r"(ETABAR:[\s\S]*?EPSSHRINKVR.*)", content)
        pk_logic = re.search(r"(\$PK[\s\S]*?)(?=\$ERROR|\$EST)", content)
        return {
            "ofv": ofv.group(1) if ofv else "N/A",
            "aic": aic.group(1) if aic else "N/A",
            "summary": (
                f"### [{role_label} (Run {run_id}) 原始真相提取] ###\n"
                f"Objective Function Value: {ofv.group(1) if ofv else 'N/A'}\n"
                f"AIC: {aic.group(1) if aic else 'N/A'}\n"
                f"Control Stream ($PK): \n{pk_logic.group(0) if pk_logic else 'N/A'}\n"
                f"Estimate Matrix: \n{estimates.group(0) if estimates else 'N/A'}\n"
                f"Standard Error Matrix: \n{se_matrix.group(0) if se_matrix else 'N/A'}\n"
                f"Shrinkage Table: \n{shrinkage.group(0) if shrinkage else 'N/A'}"
            ),
        }
    except Exception as exc:
        return {"ofv": "N/A", "aic": "N/A", "summary": f"读取 {path.name} 失败: {exc}"}


def _run_r_parameter_script(settings: WorkbenchSettings, run_id: str, output_dir: Path, log) -> str:
    root = settings.project_path
    script = "pk parameters script.R"
    if not (root / script).exists():
        log(f"Missing R parameter script: {script}")
        return ""
    code = stream_subprocess([settings.rscript, script, run_id], root, log)
    if code != 0:
        return ""
    csv_name = root / f"data_run{run_id}.csv"
    if not csv_name.exists():
        log(f"R script finished but {csv_name.name} was not generated.")
        return ""
    destination = output_dir / f"raw_data_run{run_id}.csv"
    csv_name.replace(destination)
    return destination.read_text(encoding="utf-8", errors="ignore")[:5000]


def run_parameter_audit(settings: WorkbenchSettings, log) -> int:
    root = settings.project_path
    output = dated_compare_dir(root, settings.prev_run, settings.curr_run)
    rules = _load_rules(root, settings.rules_file)
    log(f"Parameter/LST audit output: {output}")

    prev_csv = _run_r_parameter_script(settings, settings.prev_run, output, log)
    curr_csv = _run_r_parameter_script(settings, settings.curr_run, output, log)
    prev_data = _read_lst_source_truth(root, settings.prev_run, "前序模型")
    curr_data = _read_lst_source_truth(root, settings.curr_run, "当前模型")

    prompt = f"""
你是一名顶级的群体药动学/药效学 (PopPK/PD) 审计专家。
请根据提供的【Rule Library】作为判定标准，对【前序模型】和【当前模型】的演进进行审计，并输出 Markdown。

--- 判定准则库 (Rule Library) ---
{rules}

--- 任务要求 ---
1. 模型发现：对比 $PK 逻辑，自主识别当前模型做了哪些改动。
2. 数据对账：核对当前模型 Estimates/SE Matrix 与 R 脚本产出的 CSV 是否一致。
3. 规则化评价：计算 ΔOFV/ΔAIC；评价 RSE、Shrinkage 和单抗生理意义。
4. 最终判定：是否建议定稿。

--- R 脚本输出 CSV 预览 ---
前序:
{prev_csv or "R 脚本未输出有效数据"}

当前:
{curr_csv or "R 脚本未输出有效数据"}

--- 审计底稿：原始 LST 文本 ---
{prev_data['summary']}
{curr_data['summary']}
"""

    try:
        log("Sending parameter/LST audit request to LLM...")
        response = _openai_client(settings.llm_base_url, settings.llm_api_key).chat.completions.create(
            model=settings.llm_model_id,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
        )
        report_md = response.choices[0].message.content
    except Exception as exc:
        log(f"LLM parameter audit failed: {exc}")
        return 1

    report_name = f"Audit_Report_Run{settings.curr_run}_{output.name[-8:]}.md"
    report_path = output / report_name
    report_path.write_text(
        "# PopPK 模型演进审计报告\n\n"
        f"- **前序**: Run {settings.prev_run} | **当前**: Run {settings.curr_run}\n"
        f"- **生成路径**: `{output}`\n\n---\n\n"
        f"{report_md}",
        encoding="utf-8",
    )

    for run_id in (settings.prev_run, settings.curr_run):
        word_file = root / f"Table5_Run{run_id}_Final_Parameters.docx"
        if word_file.exists():
            word_file.replace(output / word_file.name)
    _write_summary_excel(output, prev_data, curr_data, curr_csv, log)
    log(f"Parameter/LST audit report saved: {report_path}")
    return 0


def _write_summary_excel(output: Path, prev_data: Dict[str, str], curr_data: Dict[str, str], curr_csv: str, log) -> None:
    try:
        import pandas as pd

        prev_ofv = prev_data.get("ofv", "N/A")
        curr_ofv = curr_data.get("ofv", "N/A")
        try:
            delta = round(float(curr_ofv) - float(prev_ofv), 3)
        except Exception:
            delta = "N/A"
        with pd.ExcelWriter(output / "Statistical_Summary.xlsx", engine="openpyxl") as writer:
            pd.DataFrame(
                {"Model": ["Previous", "Current", "Difference"], "OFV": [prev_ofv, curr_ofv, delta]}
            ).to_excel(writer, sheet_name="OFV_Comparison", index=False)
            rows = [line.split(",") for line in curr_csv.splitlines()[:200]] if curr_csv else []
            pd.DataFrame(rows).to_excel(writer, sheet_name="Current_Model_Data", index=False, header=False)
    except Exception as exc:
        log(f"Could not write Statistical_Summary.xlsx: {exc}")


def _encode_image(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("utf-8")


def _find_image(root: Path, prefix: str, run_id: str) -> Optional[Path]:
    for suffix in ("jpg", "JPG", "jpeg", "JPEG", "png", "PNG"):
        candidate = root / f"{prefix}{run_id}.{suffix}"
        if candidate.exists():
            return candidate
    return None


def _run_visual_audit(settings: WorkbenchSettings, log, kind: str) -> int:
    root = settings.project_path
    output = dated_compare_dir(root, settings.prev_run, settings.curr_run)
    prefixes = ["GOF_mod"] if kind == "gof" else ["VPC_Stratified_mod", "VPC_mod"]
    current = next((_find_image(root, prefix, settings.curr_run) for prefix in prefixes if _find_image(root, prefix, settings.curr_run)), None)
    previous = next((_find_image(root, prefix, settings.prev_run) for prefix in prefixes if _find_image(root, prefix, settings.prev_run)), None)
    if not current:
        log(f"Missing current {kind.upper()} image for run {settings.curr_run}.")
        return 2

    rules = _load_rules(root, settings.rules_file)
    title = "GOF 图像诊断专家审计报告" if kind == "gof" else "VPC 预测性能专家审计报告"
    task_name = "GOF diagnostic plot" if kind == "gof" else "VPC plot"
    prompt_text = f"""
你是一名资深的群体药理学视觉诊断专家。请对提供的 {task_name} 进行系统性审计。

### 判定准则库 (Rule Library)
{rules}

### 任务
1. 识别图中关键子图/分位数/预测区间等元素。
2. 如提供前序模型图，请比较 Run {settings.prev_run} 到 Run {settings.curr_run} 的演进。
3. 引用 Rule ID 给出定稿建议。

请直接输出 Markdown 格式报告。
"""
    content = [
        {"type": "text", "text": prompt_text},
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{_encode_image(current)}"}},
    ]
    if previous:
        content.append({"type": "text", "text": f"参考附件：前序模型 Run {settings.prev_run}"})
        content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{_encode_image(previous)}"}})

    try:
        log(f"Sending {kind.upper()} visual audit → model={settings.vision_model_id} @ {settings.vision_base_url}")
        response = _openai_client(settings.vision_base_url, settings.vision_api_key).chat.completions.create(
            model=settings.vision_model_id,
            messages=[{"role": "user", "content": content}],
            max_tokens=3000,
        )
        report_md = response.choices[0].message.content
    except Exception as exc:
        log(f"{kind.upper()} visual audit failed: {exc}")
        return 1

    date_part = output.name[-8:]
    report_name = (
        f"GOF_Expert_Audit_Run{settings.curr_run}_{date_part}.md"
        if kind == "gof"
        else f"VPC_Evolution_Audit_Run{settings.curr_run}_{date_part}.md"
    )
    report_path = output / report_name
    report_path.write_text(
        f"# PopPK {title}\n\n"
        f"- **前序**: Run {settings.prev_run} | **当前**: Run {settings.curr_run}\n"
        f"- **存储路径**: `{output}`\n\n---\n\n"
        f"{report_md}",
        encoding="utf-8",
    )
    for image in (previous, current):
        if image:
            shutil.copy2(image, output / image.name)
    log(f"{kind.upper()} audit report saved: {report_path}")
    return 0


def run_gof_audit(settings: WorkbenchSettings, log) -> int:
    return _run_visual_audit(settings, log, "gof")


def run_vpc_audit(settings: WorkbenchSettings, log) -> int:
    return _run_visual_audit(settings, log, "vpc")
