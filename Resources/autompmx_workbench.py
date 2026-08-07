import queue
import re
import threading
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, simpledialog

from workbench_core import (
    TaskRunner,
    WorkbenchSettings,
    build_psn_execute_command,
    check_model_files,
    create_project_folder,
    create_project_from_run,
    data_path_status,
    discover_nonmem_template,
    discover_project_assets,
    discover_runs,
    rewrite_mod_data_path,
    resolve_command,
)


APP_BG = "#1f2329"
SIDEBAR_BG = "#252a33"
PANEL_BG = "#2b303b"
EDITOR_BG = "#111820"
TERMINAL_BG = "#071018"
TEXT = "#e6edf3"
MUTED = "#9aa7b4"
ACCENT = "#2f81f7"
ACCENT_HOVER = "#1f6feb"
WARN = "#ffcc66"
BAD = "#ff7b72"
GOOD = "#7ee787"
BORDER = "#3b4450"


class AutoPMXWorkbench(tk.Frame):
    def __init__(self, master: tk.Tk, project_dir: Path):
        super().__init__(master, bg=APP_BG)
        self.master = master
        self.workspace_dir = Path(project_dir).resolve()
        self.project_dir = self.workspace_dir
        self.log_queue: "queue.Queue[str]" = queue.Queue()
        self.running = False
        self.task_buttons = []
        self.asset_rows = []
        self.preview_image = None

        self.prev_run = tk.StringVar(value="38")
        self.curr_run = tk.StringVar(value="41")
        self.data_file = tk.StringVar(value="dataset.csv")
        self.rules_file = tk.StringVar(value="poppk_rules.json,NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md")
        self.llm_base_url = tk.StringVar(value="http://localhost:1234/v1")
        self.llm_model_id = tk.StringVar(value="google/gemma-4-26b-a4b")
        self.vision_base_url = tk.StringVar(value="http://localhost:1234/v1")
        self.vision_model_id = tk.StringVar(value="google/gemma-4-26b-a4b")
        self.nonmem_template = tk.StringVar(value=discover_nonmem_template())
        self.project_label = tk.StringVar(value=str(self.project_dir))
        self.model_status = tk.StringVar(value="")
        self.data_status = tk.StringVar(value="")
        self.nonmem_status = tk.StringVar(value="")
        self.preview_title = tk.StringVar(value="Welcome")
        self.status_text = tk.StringVar(value="Ready")

        self.pack(fill="both", expand=True)
        self._build_ui()
        self.refresh_workspace()
        self.after(120, self._drain_log_queue)

    def _build_ui(self) -> None:
        toolbar = tk.Frame(self, bg=APP_BG, height=44)
        toolbar.pack(fill="x")
        toolbar.pack_propagate(False)
        tk.Label(
            toolbar,
            text="AutoPMX",
            bg=APP_BG,
            fg=TEXT,
            font=("Helvetica", 18, "bold"),
        ).pack(side="left", padx=(12, 14))
        self._toolbar_button(toolbar, "New Project", self.create_project).pack(side="left", padx=4)
        self._toolbar_button(toolbar, "Project from Run", self.create_project_from_current_run).pack(side="left", padx=4)
        self._toolbar_button(toolbar, "Open Root Project", self.open_root_project).pack(side="left", padx=4)
        self._toolbar_button(toolbar, "Refresh", self.refresh_workspace).pack(side="left", padx=4)
        tk.Label(toolbar, textvariable=self.project_label, bg=APP_BG, fg=MUTED, anchor="w").pack(
            side="left", fill="x", expand=True, padx=12
        )

        vertical = tk.PanedWindow(self, orient=tk.VERTICAL, bg=BORDER, sashwidth=6, showhandle=False)
        vertical.pack(fill="both", expand=True)
        main = tk.PanedWindow(vertical, orient=tk.HORIZONTAL, bg=BORDER, sashwidth=6, showhandle=False)
        terminal = self._terminal_panel(vertical)
        vertical.add(main, minsize=520)
        vertical.add(terminal, minsize=170)

        sidebar = self._sidebar_panel(main)
        editor = self._editor_panel(main)
        inspector = self._inspector_panel(main)
        main.add(sidebar, minsize=250, width=300)
        main.add(editor, minsize=460, width=650)
        main.add(inspector, minsize=330, width=390)

        tk.Label(self, textvariable=self.status_text, bg=APP_BG, fg=MUTED, anchor="w").pack(fill="x", padx=10, pady=4)

    def _sidebar_panel(self, parent) -> tk.Frame:
        panel = tk.Frame(parent, bg=SIDEBAR_BG, padx=10, pady=10)
        tk.Label(panel, text="PROJECT EXPLORER", bg=SIDEBAR_BG, fg=MUTED, font=("Helvetica", 11, "bold")).pack(
            anchor="w"
        )
        tk.Label(panel, text="Models, outputs, reports", bg=SIDEBAR_BG, fg=TEXT, font=("Helvetica", 14, "bold")).pack(
            anchor="w", pady=(2, 8)
        )
        self.asset_list = tk.Listbox(
            panel,
            bg="#1b2028",
            fg=TEXT,
            selectbackground=ACCENT,
            selectforeground="white",
            activestyle="none",
            relief="flat",
            borderwidth=0,
            highlightthickness=1,
            highlightbackground=BORDER,
            font=("Menlo", 12),
        )
        self.asset_list.pack(fill="both", expand=True)
        self.asset_list.bind("<<ListboxSelect>>", self.on_asset_select)
        self._small_button(panel, "Preview Selected", self.open_selected_asset).pack(fill="x", pady=(8, 0))
        return panel

    def _editor_panel(self, parent) -> tk.Frame:
        panel = tk.Frame(parent, bg=EDITOR_BG, padx=10, pady=10)
        header = tk.Frame(panel, bg=EDITOR_BG)
        header.pack(fill="x")
        tk.Label(header, textvariable=self.preview_title, bg=EDITOR_BG, fg=TEXT, font=("Helvetica", 15, "bold")).pack(
            side="left"
        )
        self.preview_meta = tk.StringVar(value="Select a model, result, figure, or report.")
        tk.Label(header, textvariable=self.preview_meta, bg=EDITOR_BG, fg=MUTED).pack(side="right")

        self.preview_container = tk.Frame(panel, bg=EDITOR_BG)
        self.preview_container.pack(fill="both", expand=True, pady=(8, 0))
        self.preview_text = tk.Text(
            self.preview_container,
            bg="#0d1117",
            fg=TEXT,
            insertbackground=TEXT,
            selectbackground=ACCENT,
            relief="flat",
            borderwidth=0,
            wrap="none",
            font=("Menlo", 12),
        )
        self.preview_text.grid(row=0, column=0, sticky="nsew")
        yscroll = tk.Scrollbar(self.preview_container, command=self.preview_text.yview)
        xscroll = tk.Scrollbar(self.preview_container, orient="horizontal", command=self.preview_text.xview)
        yscroll.grid(row=0, column=1, sticky="ns")
        xscroll.grid(row=1, column=0, sticky="ew")
        self.preview_text.configure(yscrollcommand=yscroll.set, xscrollcommand=xscroll.set)
        self.preview_container.rowconfigure(0, weight=1)
        self.preview_container.columnconfigure(0, weight=1)
        self.preview_text.insert(
            "1.0",
            "Welcome to AutoPMX.\n\n"
            "1. Create or open a project.\n"
            "2. Select a run*.mod model from the explorer.\n"
            "3. Review the PsN execute command on the right.\n"
            "4. Run NONMEM, diagnostics, and LLM audits.\n\n"
            "The interface keeps files inside this workspace.",
        )
        return panel

    def _inspector_panel(self, parent) -> tk.Frame:
        panel = tk.Frame(parent, bg=PANEL_BG, padx=12, pady=10)
        tk.Label(panel, text="RUN CONFIGURATION", bg=PANEL_BG, fg=MUTED, font=("Helvetica", 11, "bold")).pack(anchor="w")
        tk.Label(panel, text="Model execution", bg=PANEL_BG, fg=TEXT, font=("Helvetica", 15, "bold")).pack(
            anchor="w", pady=(2, 10)
        )

        form = tk.Frame(panel, bg=PANEL_BG)
        form.pack(fill="x")
        self._form_entry(form, "Previous run", self.prev_run, 0)
        self._form_entry(form, "Current run", self.curr_run, 1)
        self._form_entry(form, "Data file", self.data_file, 2)
        self._form_entry(form, "Rules file", self.rules_file, 3)

        self._section_label(panel, "PsN execute command").pack(anchor="w", pady=(14, 4))
        self.command_text = tk.Text(
            panel,
            height=3,
            bg="#1b2028",
            fg=TEXT,
            insertbackground=TEXT,
            relief="flat",
            font=("Menlo", 11),
            wrap="word",
        )
        self.command_text.pack(fill="x")
        command_buttons = tk.Frame(panel, bg=PANEL_BG)
        command_buttons.pack(fill="x", pady=(6, 0))
        self._small_button(command_buttons, "Rule Suggest", self.suggest_psn_command).pack(side="left", fill="x", expand=True)
        self._small_button(command_buttons, "AI Draft", self.ai_draft_psn_command).pack(
            side="left", fill="x", expand=True, padx=(6, 0)
        )

        self._section_label(panel, "Local LLM").pack(anchor="w", pady=(14, 4))
        llm = tk.Frame(panel, bg=PANEL_BG)
        llm.pack(fill="x")
        self._form_entry(llm, "Base URL", self.llm_base_url, 0)
        self._form_entry(llm, "Model", self.llm_model_id, 1)
        self._form_entry(llm, "Vision URL", self.vision_base_url, 2)
        self._form_entry(llm, "Vision model", self.vision_model_id, 3)

        self._section_label(panel, "Checks").pack(anchor="w", pady=(14, 4))
        for variable, color in ((self.model_status, MUTED), (self.data_status, WARN), (self.nonmem_status, GOOD)):
            tk.Label(panel, textvariable=variable, bg=PANEL_BG, fg=color, anchor="w", justify="left", wraplength=340).pack(
                fill="x", pady=2
            )

        self._section_label(panel, "Actions").pack(anchor="w", pady=(14, 4))
        actions = (
            ("Run NONMEM via PsN", "nonmem"),
            ("Run PsN VPC", "psn_vpc"),
            ("Run R diagnostics", "r_diagnostics"),
            ("Run LST/parameter audit", "parameter_audit"),
            ("Run GOF vision audit", "gof_audit"),
            ("Run VPC vision audit", "vpc_audit"),
        )
        for label, task_name in actions:
            button = self._action_button(panel, label, lambda name=task_name: self.start_task(name))
            button.pack(fill="x", pady=3)
            self.task_buttons.append(button)
        self._small_button(panel, "Rewrite current $DATA path", self.rewrite_current_data_path).pack(fill="x", pady=(8, 0))
        return panel

    def _terminal_panel(self, parent) -> tk.Frame:
        panel = tk.Frame(parent, bg=TERMINAL_BG, padx=8, pady=8)
        header = tk.Frame(panel, bg=TERMINAL_BG)
        header.pack(fill="x")
        tk.Label(header, text="TERMINAL", bg=TERMINAL_BG, fg=MUTED, font=("Helvetica", 11, "bold")).pack(side="left")
        self._terminal_button(header, "Clear", self.clear_log).pack(side="right")
        self.log_text = tk.Text(
            panel,
            bg=TERMINAL_BG,
            fg="#d8f3dc",
            insertbackground="#d8f3dc",
            relief="flat",
            height=9,
            font=("Menlo", 11),
            wrap="word",
        )
        self.log_text.pack(fill="both", expand=True, pady=(5, 0))
        self.log("AutoPMX terminal ready.")
        return panel

    def settings(self) -> WorkbenchSettings:
        return WorkbenchSettings(
            project_dir=self.project_dir,
            prev_run=self.prev_run.get().strip(),
            curr_run=self.curr_run.get().strip(),
            llm_base_url=self.llm_base_url.get().strip(),
            llm_model_id=self.llm_model_id.get().strip(),
            vision_base_url=self.vision_base_url.get().strip(),
            vision_model_id=self.vision_model_id.get().strip(),
            rules_file=self.rules_file.get().strip(),
            nonmem_template=self.nonmem_template.get().strip(),
            psn_execute_template=self.command_text.get("1.0", "end").strip(),
            data_file=self.data_file.get().strip(),
        )

    def create_project(self) -> None:
        name = simpledialog.askstring("Create AutoPMX project", "Project name:", parent=self.master)
        if not name:
            return
        try:
            self.project_dir = create_project_folder(self.workspace_dir, name)
            self.project_label.set(str(self.project_dir))
            self.refresh_workspace()
            self.log(f"Created project: {self.project_dir}")
        except Exception as exc:
            messagebox.showerror("Create project failed", str(exc))

    def create_project_from_current_run(self) -> None:
        name = simpledialog.askstring(
            "Create project from current run",
            f"Project name for Run {self.curr_run.get()}:",
            parent=self.master,
        )
        if not name:
            return
        try:
            self.project_dir = create_project_from_run(
                self.workspace_dir,
                self.project_dir,
                name,
                self.curr_run.get(),
                self.data_file.get(),
            )
            self.project_label.set(str(self.project_dir))
            self.refresh_workspace()
            self.log(f"Created project from Run {self.curr_run.get()}: {self.project_dir}")
        except Exception as exc:
            messagebox.showerror("Create project from run failed", str(exc))

    def open_root_project(self) -> None:
        self.project_dir = self.workspace_dir
        self.project_label.set(str(self.project_dir))
        self.refresh_workspace()
        self.log("Opened root project.")

    def refresh_workspace(self) -> None:
        runs = discover_runs(self.project_dir)
        if runs:
            if self.prev_run.get() not in runs:
                self.prev_run.set(runs[-2] if len(runs) > 1 else runs[-1])
            if self.curr_run.get() not in runs:
                self.curr_run.set(runs[-1])
        self.suggest_psn_command()
        self.refresh_assets()
        self.refresh_checks()

    def refresh_assets(self) -> None:
        self.asset_rows.clear()
        self.asset_list.delete(0, tk.END)
        assets = discover_project_assets(self.project_dir)
        labels = {
            "models": "MODELS",
            "data": "DATA",
            "outputs": "NONMEM OUTPUTS",
            "figures": "FIGURES",
            "reports": "REPORTS",
            "scripts": "SCRIPTS",
        }
        for category, title in labels.items():
            self.asset_list.insert(tk.END, f"▸ {title}")
            self.asset_rows.append((None, category))
            for path in assets[category]:
                rel = path.relative_to(self.project_dir) if self.project_dir in path.resolve().parents or path.resolve() == self.project_dir else path.name
                self.asset_list.insert(tk.END, f"   {rel}")
                self.asset_rows.append((path, category))

    def refresh_checks(self) -> None:
        prev = check_model_files(self.project_dir, self.prev_run.get())
        curr = check_model_files(self.project_dir, self.curr_run.get())
        self.model_status.set(
            f"Run {self.prev_run.get()}: {self._compact_status(prev)}\n"
            f"Run {self.curr_run.get()}: {self._compact_status(curr)}"
        )
        status = data_path_status(self.project_dir, self.curr_run.get(), self.data_file.get())
        if status.mod_path.exists() and status.matches_expected:
            self.data_status.set(f"$DATA OK: {status.current_path}")
        elif status.mod_path.exists():
            self.data_status.set(f"$DATA mismatch:\n{status.current_path or 'not found'}\n→ {status.expected_path}")
        else:
            self.data_status.set(f"Current model not found: {status.mod_path.name}")
        resolution = resolve_command(
            self.command_text.get("1.0", "end").strip(),
            {"model": f"run{self.curr_run.get()}.mod", "run": self.curr_run.get(), "project_dir": str(self.project_dir)},
        )
        color_text = "available" if resolution.available else "not configured"
        self.nonmem_status.set(f"PsN execute: {color_text} ({resolution.executable or 'empty'})")
        self.status_text.set(f"Project: {self.project_dir.name} | Current run: {self.curr_run.get()}")

    def suggest_psn_command(self) -> None:
        run = self.curr_run.get().strip() or "1"
        command = build_psn_execute_command(run)
        text = " ".join(command)
        self.command_text.delete("1.0", "end")
        self.command_text.insert("1.0", text)
        self.log(f"Suggested PsN execute command: {text}")
        self.refresh_checks()

    def ai_draft_psn_command(self) -> None:
        if self.running:
            self.log("A task is already running.")
            return
        self.log("Requesting AI PsN command draft...")
        thread = threading.Thread(target=self._ai_draft_psn_command_thread, daemon=True)
        thread.start()

    def _ai_draft_psn_command_thread(self) -> None:
        try:
            from openai import OpenAI

            run = self.curr_run.get().strip() or "1"
            mod_path = self.project_dir / f"run{run}.mod"
            config_path = self.project_dir / "project_config.json"
            mod_text = mod_path.read_text(encoding="utf-8", errors="ignore")[:16000] if mod_path.exists() else ""
            config_text = config_path.read_text(encoding="utf-8", errors="ignore")[:6000] if config_path.exists() else ""
            fallback = " ".join(build_psn_execute_command(run))
            prompt = f"""
You are helping draft a safe PsN command for running a NONMEM control stream.
Return exactly one shell command and no Markdown.

Requirements:
- Use PsN execute, not direct nmfe.
- Run model file: run{run}.mod
- Keep output inside the current project directory.
- Prefer a readable output directory like nonmem_run_{run}.
- Do not delete, move, or overwrite unrelated files.

Fallback command:
{fallback}

project_config.json:
{config_text}

NONMEM control stream preview:
{mod_text}
"""
            response = OpenAI(base_url=self.llm_base_url.get().strip(), api_key="lm-studio").chat.completions.create(
                model=self.llm_model_id.get().strip(),
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
            )
            draft = response.choices[0].message.content.strip().replace("```", "")
            first_line = next((line.strip() for line in draft.splitlines() if line.strip()), fallback)
            if not first_line.startswith("execute "):
                first_line = fallback
                self.log("AI draft did not start with PsN execute; using safe fallback.")
            self.after(0, lambda: self._set_command_draft(first_line, "AI drafted PsN command. Review it before running."))
        except Exception as exc:
            fallback = " ".join(build_psn_execute_command(self.curr_run.get().strip() or "1"))
            self.after(0, lambda: self._set_command_draft(fallback, f"AI draft failed; using fallback. {exc}"))

    def _set_command_draft(self, command: str, log_message: str) -> None:
        self.command_text.delete("1.0", "end")
        self.command_text.insert("1.0", command)
        self.log(log_message)
        self.refresh_checks()

    def on_asset_select(self, _event=None) -> None:
        self.open_selected_asset()

    def open_selected_asset(self) -> None:
        selection = self.asset_list.curselection()
        if not selection:
            return
        path, category = self.asset_rows[selection[0]]
        if path is None:
            return
        if category == "models":
            match = re.match(r"run(\d+)\.mod$", path.name, re.IGNORECASE)
            if match:
                self.curr_run.set(match.group(1))
                self.suggest_psn_command()
        self.preview_file(path)

    def preview_file(self, path: Path) -> None:
        self.preview_title.set(path.name)
        self.preview_meta.set(str(path.relative_to(self.project_dir)) if self.project_dir in path.resolve().parents else str(path))
        suffix = path.suffix.lower()
        self.preview_text.configure(state="normal")
        self.preview_text.delete("1.0", "end")
        if suffix in (".mod", ".lst", ".ext", ".cov", ".md", ".py", ".r", ".json", ".csv", ".txt", ""):
            text = path.read_text(encoding="utf-8", errors="ignore")
            if len(text) > 120000:
                text = text[:120000] + "\n\n[Preview truncated]"
            self.preview_text.insert("1.0", text)
        elif suffix in (".jpg", ".jpeg", ".png", ".pdf", ".docx", ".xlsx"):
            size_kb = path.stat().st_size / 1024
            self.preview_text.insert(
                "1.0",
                f"{path.name}\n\n"
                f"Type: {suffix.upper()[1:]} artifact\n"
                f"Size: {size_kb:,.1f} KB\n"
                f"Path: {path}\n\n"
                "Preview note: image/PDF/Office rendering is listed here; the file remains available in the project explorer.",
            )
        else:
            self.preview_text.insert("1.0", f"No preview available for {path.name}\n\n{path}")
        self.preview_text.mark_set("insert", "1.0")
        self.refresh_checks()

    def rewrite_current_data_path(self) -> None:
        settings = self.settings()
        mod_path = settings.project_path / f"run{settings.curr_run}.mod"
        data_path = settings.project_path / settings.data_file
        if not mod_path.exists():
            messagebox.showerror("Missing model", f"Cannot find {mod_path.name}")
            return
        if not data_path.exists():
            messagebox.showerror("Missing data", f"Cannot find {data_path.name}")
            return
        approved = messagebox.askyesno(
            "Rewrite $DATA path",
            f"Rewrite {mod_path.name} to use:\n{data_path}\n\nA one-time .bak timestamp backup will be kept.",
        )
        if not approved:
            return
        try:
            backup = rewrite_mod_data_path(mod_path, data_path, settings.project_path)
            self.log(f"Rewrote {mod_path.name} $DATA path.")
            self.log(f"Backup created: {backup.name}" if backup else "Existing backup found; no additional backup created.")
            self.refresh_workspace()
        except Exception as exc:
            messagebox.showerror("Rewrite failed", str(exc))

    def start_task(self, task_name: str) -> None:
        if self.running:
            self.log("A task is already running.")
            return
        runner = TaskRunner(self.settings(), self.log)
        task_map = {
            "nonmem": runner.run_nonmem,
            "psn_vpc": runner.run_psn_vpc,
            "r_diagnostics": runner.run_r_diagnostics,
            "parameter_audit": runner.run_parameter_audit,
            "gof_audit": runner.run_gof_audit,
            "vpc_audit": runner.run_vpc_audit,
        }
        self.running = True
        self._set_task_buttons(False)
        self.status_text.set(f"Running {task_name}...")
        self.log(f"=== Starting {task_name} ===")
        thread = threading.Thread(target=self._run_task_thread, args=(task_name, task_map[task_name]), daemon=True)
        thread.start()

    def _run_task_thread(self, task_name: str, target) -> None:
        try:
            code = target()
        except Exception as exc:
            self.log(f"{task_name} failed: {exc}")
            code = 1
        self.after(0, lambda: self._task_done(task_name, code))

    def _task_done(self, task_name: str, code: int) -> None:
        self.log(f"=== Finished {task_name} with exit code {code} ===")
        self.running = False
        self._set_task_buttons(True)
        self.refresh_workspace()

    def _set_task_buttons(self, enabled: bool) -> None:
        state = "normal" if enabled else "disabled"
        for button in self.task_buttons:
            button.configure(state=state)

    def log(self, message: str) -> None:
        self.log_queue.put(str(message))

    def _drain_log_queue(self) -> None:
        try:
            while True:
                line = self.log_queue.get_nowait()
                self.log_text.insert("end", line + "\n")
                self.log_text.see("end")
        except queue.Empty:
            pass
        self.after(120, self._drain_log_queue)

    def clear_log(self) -> None:
        self.log_text.delete("1.0", "end")

    @staticmethod
    def _compact_status(status: dict) -> str:
        return " ".join(f"{ext}:{'✓' if ok else '×'}" for ext, ok in status.items())

    def _form_entry(self, parent: tk.Frame, label: str, variable: tk.StringVar, row: int) -> None:
        tk.Label(parent, text=label, bg=parent["bg"], fg=MUTED, anchor="w").grid(row=row, column=0, sticky="w", pady=3)
        tk.Entry(
            parent,
            textvariable=variable,
            bg="#1b2028",
            fg=TEXT,
            insertbackground=TEXT,
            relief="flat",
        ).grid(row=row, column=1, sticky="ew", padx=(8, 0), pady=3)
        parent.columnconfigure(1, weight=1)

    def _section_label(self, parent: tk.Widget, text: str) -> tk.Label:
        return tk.Label(parent, text=text, bg=PANEL_BG, fg=TEXT, font=("Helvetica", 12, "bold"))

    def _toolbar_button(self, parent, text, command) -> tk.Button:
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg="#303846",
            fg=TEXT,
            activebackground="#3b4556",
            activeforeground=TEXT,
            relief="flat",
            padx=10,
            pady=5,
        )

    def _small_button(self, parent, text, command) -> tk.Button:
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg="#3b4450",
            fg=TEXT,
            activebackground="#4a5565",
            activeforeground=TEXT,
            relief="flat",
            padx=8,
            pady=5,
        )

    def _terminal_button(self, parent, text, command) -> tk.Button:
        return tk.Button(parent, text=text, command=command, bg="#1b2028", fg=TEXT, relief="flat", padx=8, pady=2)

    def _action_button(self, parent, text, command) -> tk.Button:
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg=ACCENT,
            fg="white",
            activebackground=ACCENT_HOVER,
            activeforeground="white",
            relief="flat",
            padx=10,
            pady=7,
            font=("Helvetica", 11, "bold"),
        )


def main() -> None:
    project_dir = Path(__file__).resolve().parent
    root = tk.Tk()
    root.title("AutoPMX Desktop Workbench V2")
    root.configure(bg=APP_BG)
    root.geometry("1440x900")
    root.minsize(1180, 760)
    AutoPMXWorkbench(root, project_dir)
    root.update()
    root.deiconify()
    root.mainloop()


if __name__ == "__main__":
    main()
