import subprocess
import logging
import os
import shutil
import json
import re
import csv
from pathlib import Path

# =================================================================
# 1. 高级日志配置：学术级详细记录
# =================================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("DuxactMaster")


class DuxactPopMaster:
    """
    Duxact PopPK 自动化诊断工作站 V8.0
    功能：PsN 计算调度 + Mac 环境补丁 + 自动分 Bin 逻辑 + 绘图闭环
    """

    def __init__(self, mod_index):
        self.mod_index = str(mod_index)
        self.model_file = f"run{self.mod_index}.mod"
        self.vpc_dir = f"vpc_dir_{self.mod_index}"
        self.config = self._load_config()

    def _load_config(self):
        """深度加载并验证项目配置"""
        config_path = Path("project_config.json")
        if not config_path.exists():
            logger.error("❌ 配置文件缺失：请检查 project_config.json。")
            return None
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                logger.info(f"📖 项目配置载入成功: {data.get('project_name', 'TEST_mAb_PopPK')}")
                return data
        except Exception as e:
            logger.error(f"❌ JSON 格式错误，请检查逗号或引号: {e}")
            return None

    def _prepare_mac_env(self):
        """[Mac 专用补丁] 注入 SDK 路径，防止 NONMEM 链接报错"""
        sdk_path = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
        env = os.environ.copy()
        env["SDKROOT"] = sdk_path
        env["LIBRARY_PATH"] = f"{sdk_path}/usr/lib"
        env["CPATH"] = f"{sdk_path}/usr/include"
        return env

    def run_psn_vpc(self):
        """
        核心 PsN 计算引擎：基于海报规范构建指令
        """
        if not self.config: return False

        logger.info(f"⏳ [阶段 1] 正在启动 PsN VPC 计算 (Target: Run {self.mod_index})...")

        # 1. 提取参数
        psn_cfg = self.config.get("psn_settings", {})
        samples = psn_cfg.get("vpc_samples", 500)
        stratify_var = self._vpc_stratify_var()
        no_of_strata = self._vpc_no_of_strata(stratify_var)

        # 2. 目录清理
        if os.path.exists(self.vpc_dir):
            logger.info(f"🧹 正在清理旧输出目录: {self.vpc_dir}")
            shutil.rmtree(self.vpc_dir)

        if not Path(self.model_file).exists():
            logger.error(f"❌ 找不到模型文件: {self.model_file}")
            return False

        # 3. 组装 PsN 指令 (严格对齐海报 vpc run.mod -options 格式)
        cmd = [
            "/usr/local/bin/vpc",
            self.model_file,
            f"-samples={samples}",  # 仿真样本量
            f"-dir={self.vpc_dir}",  # 结果输出目录
            "-idv=TIME",  # 强制指定自变量，确保覆盖全量时间轴
            "-bin_by_count=1",  # 采用海报推荐的自动分 Bin 模式
            "-no_of_bins=12"  # 减少 bin 数以包含长尾数据点
        ]
        if stratify_var:
            cmd.insert(4, f"-stratify_on={stratify_var}")
        if no_of_strata:
            cmd.append(f"-no_of_strata={no_of_strata}")

        logger.info(f"🚀 任务下发指令: {' '.join(cmd)}")
        print(f"\n{'=' * 25} PsN 实时进度控制台 {'=' * 25}")

        try:
            # 执行并注入 Mac 环境补丁
            env = self._prepare_mac_env()
            subprocess.run(cmd, env=env, check=True)

            # 4. 物理文件校验
            if (Path(self.vpc_dir) / "vpc_results.csv").exists():
                logger.info(f"✅ [PsN] VPC 仿真数据生成成功！")
                return True
            else:
                logger.error("❌ 任务异常：未发现 vpc_results.csv，请检查模型设置。")
                return False

        except Exception as e:
            logger.error(f"❌ PsN 运行失败: {e}")
            return False

    def _vpc_stratify_var(self):
        """Choose a VPC stratification column that exists in the model $INPUT."""
        input_cols = self._model_input_columns()
        if not input_cols:
            return None
        psn_cfg = self.config.get("psn_settings", {})
        grouping = self.config.get("grouping", {})
        configured = [
            psn_cfg.get("vpc_stratify"),
            psn_cfg.get("stratify_var"),
            grouping.get("factor"),
            "STUDY",
        ]

        def resolve(candidate):
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

    def _vpc_no_of_strata(self, stratify_var):
        """Cap large nominal VPC strata, e.g. many unique dose levels."""
        if not stratify_var:
            return None
        primary = stratify_var.split(",")[0].strip().upper()
        max_strata = int(self.config.get("psn_settings", {}).get("vpc_max_strata", 6))
        data_file = self.config.get("data_file", "")
        data_path = Path(data_file)
        if not data_path.exists():
            data_path = Path.cwd() / data_file if data_file else None
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

    def _model_input_columns(self):
        mod_path = Path(self.model_file)
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

    def run_r_drawing(self):
        """[R 绘图模块] 闭环调用所有诊断图，捕获详细日志"""
        scripts = [
            ("gof_plot_script.R", "GOF 诊断图"),
            ("individual_plot_script.R", "个体拟合图"),
            ("vpc_plot_script.R", "VPC 预测图")
        ]

        print(f"\n{'=' * 30} 启动 R 绘图引擎 {'=' * 30}")

        for script_file, label in scripts:
            if not Path(script_file).exists():
                continue

            logger.info(f"🎨 正在绘制: {label} ...")
            try:
                # 捕获 R 的 stdout 和 stderr 以便诊断
                result = subprocess.run(
                    ["Rscript", script_file, self.mod_index],
                    check=True, capture_output=True, text=True
                )
                if result.stdout: print(result.stdout)
                logger.info(f"✨ {label} 绘制成功！")
            except subprocess.CalledProcessError as e:
                logger.error(f"❌ {label} 绘制失败！")
                if e.stderr: logger.error(f"R 语言报错堆栈:\n{e.stderr}")

    def start_workflow(self, run_vpc=True):
        """一键启动"""
        print(f"\n{'#' * 60}")
        print(f"## Duxact PopPK 自动化工作站 V8.0 | Target: Run {self.mod_index} ##")
        print(f"{'#' * 60}\n")

        if run_vpc:
            if not self.run_psn_vpc():
                logger.error("🚫 VPC 计算失败，自动熔断后续任务。")
                return

        self.run_r_drawing()
        print(f"\n{'#' * 60}\n## 所有自动化任务执行完毕！ ##\n{'#' * 60}\n")


if __name__ == "__main__":
    TARGET_ID = 41
    master = DuxactPopMaster(TARGET_ID)
    master.start_workflow(run_vpc=False)
