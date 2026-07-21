import Foundation

// MARK: - Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhCN = "zh-CN"
    case en = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhCN: return "中文"
        case .en: return "English"
        }
    }

    static func current() -> AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: "AutoPMX.language"),
           let lang = AppLanguage(rawValue: saved) {
            return lang
        }
        // Auto-detect from system
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh") { return .zhCN }
        return .en
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "AutoPMX.language")
    }
}

// MARK: - Localized Strings

enum L10n {
    static func t(_ key: String) -> String {
        let lang = AppLanguage.current()
        return Self.strings[key]?[lang] ?? key
    }

    // Categories & Asset names
    static let models = t("models")
    static let data = t("data")
    static let outputs = t("outputs")
    static let figures = t("figures")
    static let reports = t("reports")
    static let scripts = t("scripts")

    // Toolbar
    static let toolbarNewProject = t("toolbar.newProject")
    static let toolbarOpen = t("toolbar.open")
    static let toolbarDemo = t("toolbar.demo")
    static let toolbarRoot = t("toolbar.root")
    static let toolbarFromRun = t("toolbar.fromRun")
    static let toolbarRefresh = t("toolbar.refresh")
    static let toolbarRunModel = t("toolbar.runModel")
    static let toolbarRunning = t("toolbar.running")

    // Sidebar
    static let sidebarProjectExplorer = t("sidebar.projectExplorer")
    static let sidebarDesc = t("sidebar.desc")

    // Detail
    static let detailOpen = t("detail.open")
    static let detailReveal = t("detail.reveal")
    static let detailActions = t("detail.actions")
    static let detailWorkspace = t("detail.workspace")
    static let detailFileType = t("detail.fileType")
    static let detailSize = t("detail.size")
    static let detailPath = t("detail.path")

    // Inspector
    static let inspectorRunConfig = t("inspector.runConfig")
    static let inspectorPrevious = t("inspector.previous")
    static let inspectorCurrent = t("inspector.current")
    static let inspectorDataFile = t("inspector.dataFile")
    static let inspectorRulesJSON = t("inspector.rulesJSON")
    static let inspectorPsnCommand = t("inspector.psnCommand")
    static let inspectorSuggest = t("inspector.suggest")
    static let inspectorAI = t("inspector.ai")
    static let inspectorRun = t("inspector.run")
    static let inspectorChecks = t("inspector.checks")
    static let inspectorModelFiles = t("inspector.modelFiles")
    static let inspectorDataPath = t("inspector.dataPath")
    static let inspectorPsn = t("inspector.psn")
    static let inspectorParameterEstimates = t("inspector.parameterEstimates")
    static let inspectorLLM = t("inspector.llmProvider")
    static let inspectorTestConnection = t("inspector.testConnection")
    static let inspectorNoEstimates = t("inspector.noEstimates")
    static let inspectorParam = t("inspector.param")
    static let inspectorEstimate = t("inspector.estimate")
    static let inspectorSE = t("inspector.se")
    static let inspectorRSE = t("inspector.rse")

    // AI Assistant
    static let aiTitle = t("ai.title")
    static let aiSubtitle = t("ai.subtitle")
    static let aiRunning = t("ai.running")
    static let aiTestLLM = t("ai.testLLM")
    static let aiGenPsN = t("ai.genPsn")
    static let aiDuDuAuto = t("ai.duDuAuto")
    static let aiPlots = t("ai.plots")
    static let aiVPC = t("ai.vpc")
    static let aiLSTAudit = t("ai.lstAudit")
    static let aiAllDiagnose = t("ai.allDiagnose")
    static let aiAskPlaceholder = t("ai.askPlaceholder")
    static let aiStop = t("ai.stop")
    static let aiThinking = t("ai.thinking")
    static let aiThinkingDuDu = t("ai.thinkingDuDu")
    static let aiSystemLabel = t("ai.systemLabel")
    static let aiDuDuLabel = t("ai.duDuLabel")

    // Settings
    static let settingsLLM = t("settings.llm")
    static let settingsTools = t("settings.tools")
    static let settingsRules = t("settings.rules")
    static let settingsAbout = t("settings.about")
    static let settingsLLMProviders = t("settings.llmProviders")
    static let settingsAddProvider = t("settings.addProvider")
    static let settingsName = t("settings.name")
    static let settingsApiFormat = t("settings.apiFormat")
    static let settingsBaseURL = t("settings.baseURL")
    static let settingsModel = t("settings.model")
    static let settingsApiKey = t("settings.apiKey")
    static let settingsTestConnection = t("settings.testConnection")
    static let settingsRemove = t("settings.remove")
    static let settingsModelsFound = t("settings.modelsFound")
    static let settingsNotTested = t("settings.notTested")
    static let settingsConnected = t("settings.connected")
    static let settingsNoModel = t("settings.noModel")
    static let settingsUnnamed = t("settings.unnamed")
    static let settingsSourceFiles = t("settings.sourceFiles")
    static let settingsSourceFilesHint = t("settings.sourceFilesHint")
    static let settingsReloadRules = t("settings.reloadRules")
    static let settingsLoadAllDefaults = t("settings.loadAllDefaults")
    static let settingsLoadStatus = t("settings.loadStatus")
    static let settingsLoaded = t("settings.loaded")
    static let settingsMissing = t("settings.missing")
    static let settingsNoRules = t("settings.noRules")
    static let settingsKnownFiles = t("settings.knownFiles")
    static let settingsKnownFilesHint = t("settings.knownFilesHint")
    static let settingsNoRuleFiles = t("settings.noRuleFiles")
    static let settingsAdd = t("settings.add")
    static let settingsToolsNONMEM = t("settings.tools.nonmem")
    static let settingsToolsNONMEMHint = t("settings.tools.nonmemHint")
    static let settingsToolsPsN = t("settings.tools.psn")
    static let settingsToolsPsNHint = t("settings.tools.psnHint")
    static let settingsToolsPython = t("settings.tools.python")
    static let settingsToolsPythonHint = t("settings.tools.pythonHint")
    static let settingsToolsViewers = t("settings.tools.viewers")
    static let settingsToolsViewersHint = t("settings.tools.viewersHint")
    static let settingsToolsDataFile = t("settings.tools.dataFile")
    static let settingsToolsDataFileHint = t("settings.tools.dataFileHint")
    static let settingsToolsDataFileHintText = t("settings.tools.dataFileHintText")
    static let settingsAutoDetect = t("settings.autoDetect")
    static let settingsBrowse = t("settings.browse")
    static let settingsFound = t("settings.found")
    static let settingsNotFound = t("settings.notFound")

    // Automation
    static let autoStartFresh = t("auto.startFresh")
    static let autoStartFreshDetail = t("auto.startFreshDetail")
    static let autoStartContinue = t("auto.startContinue")
    static let autoStartContinueDetail = t("auto.startContinueDetail")
    static let autoStartFromModel = t("auto.startFromModel")
    static let autoStartFromModelDetail = t("auto.startFromModelDetail")
    static let autoTitle = t("auto.title")
    static let autoSubtitle = t("auto.subtitle")
    static let autoMode = t("auto.mode")
    static let autoParentModel = t("auto.parentModel")
    static let autoGuidance = t("auto.guidance")
    static let autoGuidanceHint = t("auto.guidanceHint")
    static let autoCancel = t("auto.cancel")
    static let autoStart = t("auto.start")

    // Context menu
    static let ctxRunNONMEM = t("ctx.runNonmem")
    static let ctxRunGOF = t("ctx.runGof")
    static let ctxRunVPC = t("ctx.runVpc")
    static let ctxRunIndividual = t("ctx.runIndividual")
    static let ctxRunAllDiagnostics = t("ctx.runAllDiagnostics")
    static let ctxExtractPK = t("ctx.extractPk")
    static let ctxBootstrap = t("ctx.bootstrap")
    static let ctxSCM = t("ctx.scm")
    static let ctxAIEvaluate = t("ctx.aiEvaluate")
    static let ctxOpen = t("ctx.open")
    static let ctxPin = t("ctx.pin")
    static let ctxUnpin = t("ctx.unpin")
    static let ctxReveal = t("ctx.reveal")
    static let ctxDelete = t("ctx.delete")

    // Delete confirmation
    static let deleteTitle = t("delete.title")
    static let deleteMessage = t("delete.message")
    static let deleteCancel = t("delete.cancel")
    static let deleteConfirm = t("delete.confirm")

    // Project sheet
    static let projectCreateBlank = t("project.createBlank")
    static let projectCreateBlankMsg = t("project.createBlankMsg")
    static let projectCreateFromRun = t("project.createFromRun")
    static let projectCreate = t("project.create")

    // Terminal
    static let terminalReady = t("terminal.ready")

    // About
    static let aboutTitle = t("about.title")
    static let aboutSubtitle = t("about.subtitle")
    static let aboutDescription = t("about.description")
    static let aboutProviders = t("about.providers")
    static let aboutBuilt = t("about.built")

    // Workbench
    static let workbenchOverview = t("workbench.overview")

    // App display name
    static let appName = "AutoPMX"
    static let appSubtitle = "DuDu PMx Workbench"

    // Thinking steps
    static let thinkCheckingLLM = t("think.checkingLLM")
    static let thinkPreparingProject = t("think.preparingProject")
    static let thinkAnalyzingDataset = t("think.analyzingDataset")
    static let thinkAIWritingModel = t("think.aiWritingModel")
    static let thinkRunningNONMEM = t("think.runningNonmem")
    static let thinkRunningDiagnostics = t("think.runningDiagnostics")
    static let thinkAIEvaluating = t("think.aiEvaluating")

    // Automation messages
    static let msgAutomationStarted = t("msg.automation.started")
    static let msgAutomationUserGuidance = t("msg.automation.userGuidance")
    static let msgAutomationProjectCreated = t("msg.automation.projectCreated")
    static let msgAutomationDatasetAnalysis = t("msg.automation.datasetAnalysis")
    static let msgAutomationModelCreated = t("msg.automation.modelCreated")
    static let msgAutomationResuming = t("msg.automation.resuming")
    static let msgAutomationComplete = t("msg.automation.complete")
    static let msgAutomationBest = t("msg.automation.best")
    static let msgAutomationStopped = t("msg.automation.stopped")
    static let msgAutomationFailed = t("msg.automation.failed")
    static let msgAutomationStopRequested = t("msg.automation.stopRequested")

    // Others
    static let othersNoParams = t("others.noParams")
    static let othersNA = t("others.na")
    static let othersNotConnected = t("others.notConnected")
    static let othersNotTested = t("others.notTested")
    static let othersNeverTested = t("others.neverTested")
    static let othersModelsAvailable = t("others.modelsAvailable")
    static let othersModelNotSelected = t("others.modelNotSelected")

    // MARK: - Translation Table

    private static let strings: [String: [AppLanguage: String]] = [
        // Categories
        "models": [.zhCN: "模型", .en: "Models"],
        "data": [.zhCN: "数据", .en: "Data"],
        "outputs": [.zhCN: "NONMEM 输出", .en: "NONMEM Outputs"],
        "figures": [.zhCN: "图表", .en: "Figures"],
        "reports": [.zhCN: "报告", .en: "Reports"],
        "scripts": [.zhCN: "脚本", .en: "Scripts"],

        // Toolbar
        "toolbar.newProject": [.zhCN: "新建项目", .en: "New Project"],
        "toolbar.open": [.zhCN: "打开", .en: "Open"],
        "toolbar.demo": [.zhCN: "Demo", .en: "Demo"],
        "toolbar.root": [.zhCN: "根目录", .en: "Root"],
        "toolbar.fromRun": [.zhCN: "从 Run 创建", .en: "From Run"],
        "toolbar.refresh": [.zhCN: "刷新", .en: "Refresh"],
        "toolbar.runModel": [.zhCN: "运行模型", .en: "Run Model"],
        "toolbar.running": [.zhCN: "运行中", .en: "Running"],

        // Sidebar
        "sidebar.projectExplorer": [.zhCN: "项目浏览器", .en: "Project Explorer"],
        "sidebar.desc": [.zhCN: "模型、诊断、报告", .en: "Models, diagnostics, reports"],

        // Detail
        "detail.open": [.zhCN: "打开", .en: "Open"],
        "detail.reveal": [.zhCN: "在 Finder 中显示", .en: "Reveal in Finder"],
        "detail.actions": [.zhCN: "操作", .en: "Actions"],
        "detail.workspace": [.zhCN: "工作区", .en: "Workspace"],
        "detail.fileType": [.zhCN: "类型", .en: "Type"],
        "detail.size": [.zhCN: "大小", .en: "Size"],
        "detail.path": [.zhCN: "路径", .en: "Path"],

        // Inspector
        "inspector.runConfig": [.zhCN: "运行配置", .en: "Run Configuration"],
        "inspector.previous": [.zhCN: "上一个", .en: "Previous"],
        "inspector.current": [.zhCN: "当前", .en: "Current"],
        "inspector.dataFile": [.zhCN: "数据文件", .en: "Data"],
        "inspector.rulesJSON": [.zhCN: "规则 JSON", .en: "Rules JSON"],
        "inspector.psnCommand": [.zhCN: "PsN 命令", .en: "PsN Command"],
        "inspector.suggest": [.zhCN: "推荐", .en: "Suggest"],
        "inspector.ai": [.zhCN: "AI", .en: "AI"],
        "inspector.run": [.zhCN: "运行", .en: "Run"],
        "inspector.checks": [.zhCN: "检查", .en: "Checks"],
        "inspector.modelFiles": [.zhCN: "模型文件", .en: "Model Files"],
        "inspector.dataPath": [.zhCN: "数据路径", .en: "Data Path"],
        "inspector.psn": [.zhCN: "PsN", .en: "PsN"],
        "inspector.parameterEstimates": [.zhCN: "参数估计", .en: "Parameter Estimates"],
        "inspector.llmProvider": [.zhCN: "LLM Provider", .en: "LLM Provider"],
        "inspector.testConnection": [.zhCN: "测试连接", .en: "Test Connection"],
        "inspector.noEstimates": [.zhCN: "运行 NONMEM 后显示参数估计", .en: "Run NONMEM to populate parameter estimates"],
        "inspector.param": [.zhCN: "参数", .en: "Param"],
        "inspector.estimate": [.zhCN: "估计值", .en: "Estimate"],
        "inspector.se": [.zhCN: "SE", .en: "SE"],
        "inspector.rse": [.zhCN: "RSE", .en: "RSE"],

        // AI Assistant
        "ai.title": [.zhCN: "DuDu PMx", .en: "DuDu PMx"],
        "ai.subtitle": [.zhCN: "AI 药代建模助手", .en: "AI pharmacometrics assistant"],
        "ai.running": [.zhCN: "自动建模中", .en: "Automated modeling"],
        "ai.testLLM": [.zhCN: "测试 LLM", .en: "Test LLM"],
        "ai.genPsn": [.zhCN: "生成 PsN", .en: "Gen PsN"],
        "ai.duDuAuto": [.zhCN: "DuDu 自动", .en: "DuDu Auto"],
        "ai.plots": [.zhCN: "诊断图", .en: "Plots"],
        "ai.vpc": [.zhCN: "VPC", .en: "VPC"],
        "ai.lstAudit": [.zhCN: "LST 审核", .en: "LST Audit"],
        "ai.allDiagnose": [.zhCN: "全部诊断", .en: "All Diagnose"],
        "ai.askPlaceholder": [.zhCN: "提问模型、诊断、PsN...", .en: "Ask about model, diagnostics, PsN..."],
        "ai.stop": [.zhCN: "停止", .en: "Stop"],
        "ai.thinking": [.zhCN: "思考中", .en: "Thinking"],
        "ai.thinkingDuDu": [.zhCN: "DuDu 正在思考...", .en: "DuDu is thinking..."],
        "ai.systemLabel": [.zhCN: "系统", .en: "System"],
        "ai.duDuLabel": [.zhCN: "DuDu PMx", .en: "DuDu PMx"],

        // Settings
        "settings.llm": [.zhCN: "LLM", .en: "LLM"],
        "settings.tools": [.zhCN: "工具", .en: "Tools"],
        "settings.rules": [.zhCN: "规则", .en: "Rules"],
        "settings.about": [.zhCN: "关于", .en: "About"],
        "settings.llmProviders": [.zhCN: "LLM Providers", .en: "LLM Providers"],
        "settings.addProvider": [.zhCN: "添加 Provider", .en: "Add Provider"],
        "settings.name": [.zhCN: "名称", .en: "Name"],
        "settings.apiFormat": [.zhCN: "API 格式", .en: "API Format"],
        "settings.baseURL": [.zhCN: "Base URL", .en: "Base URL"],
        "settings.model": [.zhCN: "模型", .en: "Model"],
        "settings.apiKey": [.zhCN: "API Key (可选)", .en: "API Key (optional)"],
        "settings.testConnection": [.zhCN: "测试连接", .en: "Test Connection"],
        "settings.remove": [.zhCN: "删除", .en: "Remove"],
        "settings.modelsFound": [.zhCN: "个模型可用", .en: " models available"],
        "settings.notTested": [.zhCN: "未测试", .en: "Not tested"],
        "settings.connected": [.zhCN: "已连接", .en: "Connected"],
        "settings.noModel": [.zhCN: "未配置模型", .en: "No model configured"],
        "settings.unnamed": [.zhCN: "未命名", .en: "Unnamed"],
        "settings.sourceFiles": [.zhCN: "来源文件", .en: "Source Files"],
        "settings.sourceFilesHint": [.zhCN: "逗号分隔的规则、知识、审核文件列表", .en: "Comma-separated list of rule, knowledge, and audit files"],
        "settings.reloadRules": [.zhCN: "重新加载规则", .en: "Reload Rules"],
        "settings.loadAllDefaults": [.zhCN: "加载全部默认", .en: "Load All Defaults"],
        "settings.loadStatus": [.zhCN: "加载状态", .en: "Load Status"],
        "settings.loaded": [.zhCN: "已加载", .en: "Loaded"],
        "settings.missing": [.zhCN: "缺失 / 跳过", .en: "Missing / Skipped"],
        "settings.noRules": [.zhCN: "未加载任何规则。请添加来源文件后点击重新加载。", .en: "No rules loaded. Add source files above and reload."],
        "settings.knownFiles": [.zhCN: "工作区已知来源文件", .en: "Known Source Files in Workspace"],
        "settings.knownFilesHint": [.zhCN: "这些文件存在于工作区中，可以加入来源列表", .en: "These files exist in workspace and can be added"],
        "settings.noRuleFiles": [.zhCN: "未在工作区找到规则文件", .en: "No rule files found in workspace"],
        "settings.add": [.zhCN: "添加", .en: "Add"],
        "settings.tools.nonmem": [.zhCN: "NONMEM (nmfe)", .en: "NONMEM (nmfe)"],
        "settings.tools.nonmemHint": [.zhCN: "NONMEM 可执行文件路径（如 nmfe76）。首次启动时自动从常见路径检测。", .en: "Path to NONMEM executable (e.g. nmfe76). Auto-detected on first launch."],
        "settings.tools.psn": [.zhCN: "PsN (execute)", .en: "PsN (execute)"],
        "settings.tools.psnHint": [.zhCN: "Perl-speaks-NONMEM execute 命令路径", .en: "Path to PsN execute command"],
        "settings.tools.python": [.zhCN: "Python 环境", .en: "Python Environment"],
        "settings.tools.pythonHint": [.zhCN: "从工作区 .venv 或系统 Python 检测", .en: "Detected from workspace .venv or system Python"],
        "settings.tools.viewers": [.zhCN: "文件查看器", .en: "File Viewers"],
        "settings.tools.viewersHint": [.zhCN: "AutoPMX 使用 macOS 内置 QuickLook 预览图片、PDF、DOCX、XLSX、PPTX、HTML。无需插件。", .en: "AutoPMX uses macOS built-in QuickLook for previewing images, PDF, DOCX, XLSX, PPTX, HTML. No plugins needed."],
        "settings.tools.dataFile": [.zhCN: "默认数据集文件名", .en: "Default Dataset Filename"],
        "settings.tools.dataFileHint": [.zhCN: "默认数据集", .en: "Default Dataset"],
        "settings.tools.dataFileHintText": [.zhCN: "创建新项目时使用的 CSV 文件名，每个项目独立使用自己的数据文件副本", .en: "CSV filename used when creating new projects. Each project uses its own copy."],
        "settings.autoDetect": [.zhCN: "自动检测", .en: "Auto Detect"],
        "settings.browse": [.zhCN: "浏览", .en: "Browse"],
        "settings.found": [.zhCN: "已找到", .en: "Found"],
        "settings.notFound": [.zhCN: "未检测到，请手动设置", .en: "Not detected. Please set manually"],

        // Automation
        "auto.startFresh": [.zhCN: "从头开始", .en: "Start Over"],
        "auto.startFreshDetail": [.zhCN: "创建干净的 AutoModel 项目并从数据集生成 run001.mod", .en: "Create a clean AutoModel project and write run001.mod from the dataset"],
        "auto.startContinue": [.zhCN: "从最新继续", .en: "Continue Latest"],
        "auto.startContinueDetail": [.zhCN: "从当前 AutoModel 项目的最新 run 继续", .en: "Resume from the latest run in the current AutoModel project"],
        "auto.startFromModel": [.zhCN: "从指定模型继续", .en: "Continue From Model"],
        "auto.startFromModelDetail": [.zhCN: "从选择的 run 作为父模型，创建下一个编号", .en: "Use a chosen run as the parent and create the next unused run number"],
        "auto.title": [.zhCN: "启动 DuDu 自动建模", .en: "Start DuDu Auto Modeling"],
        "auto.subtitle": [.zhCN: "", .en: ""],
        "auto.mode": [.zhCN: "模式", .en: "Mode"],
        "auto.parentModel": [.zhCN: "父模型", .en: "Parent Model"],
        "auto.guidance": [.zhCN: "你的建模指导", .en: "Your Modeling Guidance"],
        "auto.guidanceHint": [.zhCN: "可选：告诉 DuDu 测试特定结构、避免某个协变量、优先考虑稳定性、或基于生物学假设继续", .en: "Optional: tell DuDu to test a specific structure, avoid a covariate, prioritize stability, or continue from a biological hypothesis"],
        "auto.cancel": [.zhCN: "取消", .en: "Cancel"],
        "auto.start": [.zhCN: "开始", .en: "Start"],

        // Context menu
        "ctx.runNonmem": [.zhCN: "通过 PsN 运行 NONMEM", .en: "Run NONMEM via PsN"],
        "ctx.runGof": [.zhCN: "运行 GOF", .en: "Run GOF"],
        "ctx.runVpc": [.zhCN: "运行 VPC", .en: "Run VPC"],
        "ctx.runIndividual": [.zhCN: "运行个体 DV-Time 图", .en: "Run Individual DV-Time"],
        "ctx.runAllDiagnostics": [.zhCN: "运行全部诊断", .en: "Run All Diagnostics"],
        "ctx.extractPk": [.zhCN: "提取 PK 参数", .en: "Extract PK Parameters"],
        "ctx.bootstrap": [.zhCN: "Bootstrap", .en: "Bootstrap"],
        "ctx.scm": [.zhCN: "SCM", .en: "SCM"],
        "ctx.aiEvaluate": [.zhCN: "AI 评估此模型", .en: "AI Evaluate This Model"],
        "ctx.open": [.zhCN: "打开", .en: "Open"],
        "ctx.pin": [.zhCN: "置顶", .en: "Pin to Top"],
        "ctx.unpin": [.zhCN: "取消置顶", .en: "Unpin"],
        "ctx.reveal": [.zhCN: "在 Finder 中显示", .en: "Reveal in Finder"],
        "ctx.delete": [.zhCN: "移到废纸篓", .en: "Move to Trash"],

        // Delete
        "delete.title": [.zhCN: "移动到废纸篓？", .en: "Move File to Trash?"],
        "delete.message": [.zhCN: "", .en: ""],
        "delete.cancel": [.zhCN: "取消", .en: "Cancel"],
        "delete.confirm": [.zhCN: "移到废纸篓", .en: "Move to Trash"],

        // Project sheet
        "project.createBlank": [.zhCN: "创建空白项目", .en: "Create Blank Project"],
        "project.createBlankMsg": [.zhCN: "创建干净的数据项目，包含 NM_dat_new.csv、规则和诊断脚本，但不含 run*.mod 文件", .en: "Create a clean data-only project with NM_dat_new.csv, rules, and diagnostic scripts"],
        "project.createFromRun": [.zhCN: "从 Run 创建项目", .en: "Create Project From Run"],
        "project.create": [.zhCN: "创建", .en: "Create"],

        // Terminal
        "terminal.ready": [.zhCN: "AutoPMX 终端就绪。\n", .en: "AutoPMX terminal ready.\n"],

        // About
        "about.title": [.zhCN: "AutoPMX", .en: "AutoPMX"],
        "about.subtitle": [.zhCN: "DuDu PMx 药代建模工作台", .en: "DuDu PMx Pharmacometrics Workbench"],
        "about.description": [.zhCN: "macOS 原生药代动力学建模式工作台。\n集成 NONMEM/PsN 运行器、AI 辅助模型构建、\n以及由本地或云端 LLM 驱动的诊断可视化。", .en: "macOS native pharmacometrics modeling workbench.\nIntegrated NONMEM/PsN runner, AI-assisted model building,\nand diagnostic visualization powered by local or cloud LLMs."],
        "about.providers": [.zhCN: "支持的 LLM Provider\nOpenAI-compatible · Anthropic Claude · Google Gemini\nMLX · LM Studio · Ollama · vLLM · 自定义 API", .en: "LLM Provider Support\nOpenAI-compatible · Anthropic Claude · Google Gemini\nMLX · LM Studio · Ollama · vLLM · Custom APIs"],
        "about.built": [.zhCN: "基于 SwiftUI 构建 · macOS 13+", .en: "Built with SwiftUI · macOS 13+"],

        // Workbench overview
        "workbench.overview": [
            .zhCN: """
            AutoPMX 原生工作台

            项目：
            {projectPath}

            工作流：
            1. 从已有的 run 创建项目或打开根项目。
            2. 从侧边栏选择一个 run*.mod 模型。
            3. 在检查器中查看 PsN execute 命令。
            4. 运行 NONMEM、VPC、R 诊断、LLM 审核。
            5. 在此窗口查看输出、图表、报告。
            """,
            .en: """
            AutoPMX native workbench

            Project:
            {projectPath}

            Workflow:
            1. Create a project from an existing run or open the root project.
            2. Select a run*.mod model from the sidebar.
            3. Review the PsN execute command in the inspector.
            4. Run NONMEM, VPC, R diagnostics, and LLM audits.
            5. Inspect outputs, figures, and reports in this window.
            """
        ],

        // Thinking steps
        "think.checkingLLM": [.zhCN: "检查 LLM 连接", .en: "Checking LLM connection"],
        "think.preparingProject": [.zhCN: "准备自动化项目", .en: "Preparing automation project"],
        "think.analyzingDataset": [.zhCN: "分析数据集", .en: "Analyzing dataset"],
        "think.aiWritingModel": [.zhCN: "AI 正在生成模型", .en: "AI drafting model"],
        "think.runningNonmem": [.zhCN: "运行 NONMEM", .en: "Running NONMEM"],
        "think.runningDiagnostics": [.zhCN: "运行诊断", .en: "Running diagnostics"],
        "think.aiEvaluating": [.zhCN: "AI 正在评估模型", .en: "AI evaluating model"],

        // Automation messages
        "msg.automation.started": [.zhCN: "DuDu PMx 自动建模已启动，数据源：", .en: "DuDu PMx automated modeling started from "],
        "msg.automation.userGuidance": [.zhCN: "本轮已加入你的建模建议：", .en: "Your modeling guidance applied: "],
        "msg.automation.projectCreated": [.zhCN: "已创建干净 AutoModel 项目", .en: "Created clean AutoModel project"],
        "msg.automation.datasetAnalysis": [.zhCN: "数据分析完成", .en: "Dataset analysis complete"],
        "msg.automation.modelCreated": [.zhCN: "DuDu PMx 已根据数据创建初始模型", .en: "DuDu PMx created initial model"],
        "msg.automation.resuming": [.zhCN: "检测到已有 AutoModel 项目，将从最新模型继续", .en: "Found existing AutoModel project, resuming from latest run"],
        "msg.automation.complete": [.zhCN: "自动建模完成：AI 判断该模型已满足规则库要求", .en: "Automated modeling complete: model meets acceptance criteria"],
        "msg.automation.best": [.zhCN: "本轮已到上限，已选择最佳候选模型。再次点击 DuDu Auto 继续。", .en: "Round complete. Best candidate selected. Click DuDu Auto again to continue."],
        "msg.automation.stopped": [.zhCN: "自动建模已停止在", .en: "Automation stopped at"],
        "msg.automation.failed": [.zhCN: "自动建模失败", .en: "Automated modeling failed"],
        "msg.automation.stopRequested": [.zhCN: "已收到停止请求：当前外部任务会被终止，自动建模会停在最近的安全检查点。", .en: "Stop requested. Automation will stop at the nearest safe checkpoint."],

        // Others
        "others.noParams": [.zhCN: "无参数", .en: "No parameters"],
        "others.na": [.zhCN: "N/A", .en: "N/A"],
        "others.notConnected": [.zhCN: "未连接", .en: "Not connected"],
        "others.notTested": [.zhCN: "未测试", .en: "Not tested"],
        "others.neverTested": [.zhCN: "LLM 未测试", .en: "LLM not tested"],
        "others.modelsAvailable": [.zhCN: "个模型可用", .en: " models available"],
        "others.modelNotSelected": [.zhCN: "未选择模型", .en: "No model"],
    ]
}
