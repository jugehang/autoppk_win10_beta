import Foundation
import SwiftUI

// MARK: - Language Store

final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()

    @Published var language: AppLanguage = AppLanguage.current()

    private init() {}

    func setLanguage(_ newValue: AppLanguage) {
        language = newValue
        newValue.save()
    }
}

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
        let lang = LanguageStore.shared.language
        return Self.strings[key]?[lang] ?? key
    }

    // Categories & Asset names
    static var models: String { t("models") }
    static var data: String { t("data") }
    static var outputs: String { t("outputs") }
    static var figures: String { t("figures") }
    static var reports: String { t("reports") }
    static var scripts: String { t("scripts") }

    // Toolbar
    static var toolbarNewProject: String { t("toolbar.newProject") }
    static var toolbarOpen: String { t("toolbar.open") }
    static var toolbarDemo: String { t("toolbar.demo") }
    static var toolbarRoot: String { t("toolbar.root") }
    static var toolbarFromRun: String { t("toolbar.fromRun") }
    static var toolbarRefresh: String { t("toolbar.refresh") }
    static var toolbarRunModel: String { t("toolbar.runModel") }
    static var toolbarRunning: String { t("toolbar.running") }

    // General UI
    static var general: String { t("general.title") }
    static var language: String { t("general.language") }
    static var selectLanguage: String { t("general.selectLanguage") }
    static var cancel: String { t("general.cancel") }
    static var start: String { t("general.start") }
    static var save: String { t("general.save") }

    // Sidebar
    static var sidebarProjectExplorer: String { t("sidebar.projectExplorer") }
    static var sidebarDesc: String { t("sidebar.desc") }

    // Detail
    static var detailOpen: String { t("detail.open") }
    static var detailReveal: String { t("detail.reveal") }
    static var detailActions: String { t("detail.actions") }
    static var detailWorkspace: String { t("detail.workspace") }
    static var detailFileType: String { t("detail.fileType") }
    static var detailSize: String { t("detail.size") }
    static var detailPath: String { t("detail.path") }

    // Inspector
    static var inspectorRunConfig: String { t("inspector.runConfig") }
    static var inspectorPrevious: String { t("inspector.previous") }
    static var inspectorCurrent: String { t("inspector.current") }
    static var inspectorDataFile: String { t("inspector.dataFile") }
    static var inspectorRulesJSON: String { t("inspector.rulesJSON") }
    static var inspectorPsnCommand: String { t("inspector.psnCommand") }
    static var inspectorSuggest: String { t("inspector.suggest") }
    static var inspectorAI: String { t("inspector.ai") }
    static var inspectorRun: String { t("inspector.run") }
    static var inspectorChecks: String { t("inspector.checks") }
    static var inspectorModelFiles: String { t("inspector.modelFiles") }
    static var inspectorDataPath: String { t("inspector.dataPath") }
    static var inspectorPsn: String { t("inspector.psn") }
    static var inspectorParameterEstimates: String { t("inspector.parameterEstimates") }
    static var inspectorLLM: String { t("inspector.llmProvider") }
    static var inspectorTestConnection: String { t("inspector.testConnection") }
    static var inspectorNoEstimates: String { t("inspector.noEstimates") }
    static var inspectorParam: String { t("inspector.param") }
    static var inspectorEstimate: String { t("inspector.estimate") }
    static var inspectorSE: String { t("inspector.se") }
    static var inspectorRSE: String { t("inspector.rse") }

    // AI Assistant
    static var aiTitle: String { t("ai.title") }
    static var aiSubtitle: String { t("ai.subtitle") }
    static var aiRunning: String { t("ai.running") }
    static var aiTestLLM: String { t("ai.testLLM") }
    static var aiGenPsN: String { t("ai.genPsn") }
    static var aiDuDuAuto: String { t("ai.duDuAuto") }
    static var aiPlots: String { t("ai.plots") }
    static var aiVPC: String { t("ai.vpc") }
    static var aiLSTAudit: String { t("ai.lstAudit") }
    static var aiAllDiagnose: String { t("ai.allDiagnose") }
    static var aiAskPlaceholder: String { t("ai.askPlaceholder") }
    static var aiStop: String { t("ai.stop") }
    static var aiThinking: String { t("ai.thinking") }
    static var aiThinkingDuDu: String { t("ai.thinkingDuDu") }
    static var aiSystemLabel: String { t("ai.systemLabel") }
    static var aiDuDuLabel: String { t("ai.duDuLabel") }

    // AI message bubble UI
    static var aiReasoning: String { t("ai.reasoning") }
    static var aiSteps: String { t("ai.steps") }
    static var aiThinkingDots: String { t("ai.thinkingDots") }
    static var aiCopy: String { t("ai.copy") }
    static var aiCopyHint: String { t("ai.copyHint") }
    static var aiFillInput: String { t("ai.fillInput") }
    static var aiClickToRun: String { t("ai.clickToRun") }

    // Action chips
    static var actionAutoModel: String { t("action.autoModel") }
    static var actionCompare: String { t("action.compare") }
    static var actionEvaluate: String { t("action.evaluate") }
    static var actionPKParams: String { t("action.pkParams") }
    static var actionGAOpt: String { t("action.gaOpt") }
    static var actionGOF: String { t("action.gof") }
    static var actionVPC: String { t("action.vpc") }

    // AI Compare sheet
    static var aiCompareRunA: String { t("ai.compare.runA") }
    static var aiCompareRunB: String { t("ai.compare.runB") }
    static var aiCompareStart: String { t("ai.compare.start") }
    static var aiCompareNeedsTwo: String { t("ai.compare.needsTwo") }

    // Settings
    static var settingsLLM: String { t("settings.llm") }
    static var settingsTools: String { t("settings.tools") }
    static var settingsRules: String { t("settings.rules") }
    static var settingsAbout: String { t("settings.about") }
    static var settingsLLMProviders: String { t("settings.llmProviders") }
    static var settingsAddProvider: String { t("settings.addProvider") }
    static var settingsName: String { t("settings.name") }
    static var settingsApiFormat: String { t("settings.apiFormat") }
    static var settingsBaseURL: String { t("settings.baseURL") }
    static var settingsModel: String { t("settings.model") }
    static var settingsApiKey: String { t("settings.apiKey") }
    static var settingsTestConnection: String { t("settings.testConnection") }
    static var settingsRemove: String { t("settings.remove") }
    static var settingsModelsFound: String { t("settings.modelsFound") }
    static var settingsNotTested: String { t("settings.notTested") }
    static var settingsConnected: String { t("settings.connected") }
    static var settingsNoModel: String { t("settings.noModel") }
    static var settingsUnnamed: String { t("settings.unnamed") }
    static var settingsSourceFiles: String { t("settings.sourceFiles") }
    static var settingsSourceFilesHint: String { t("settings.sourceFilesHint") }
    static var settingsReloadRules: String { t("settings.reloadRules") }
    static var settingsLoadAllDefaults: String { t("settings.loadAllDefaults") }
    static var settingsLoadStatus: String { t("settings.loadStatus") }
    static var settingsLoaded: String { t("settings.loaded") }
    static var settingsMissing: String { t("settings.missing") }
    static var settingsNoRules: String { t("settings.noRules") }
    static var settingsKnownFiles: String { t("settings.knownFiles") }
    static var settingsKnownFilesHint: String { t("settings.knownFilesHint") }
    static var settingsNoRuleFiles: String { t("settings.noRuleFiles") }
    static var settingsAdd: String { t("settings.add") }
    static var settingsToolsNONMEM: String { t("settings.tools.nonmem") }
    static var settingsToolsNONMEMHint: String { t("settings.tools.nonmemHint") }
    static var settingsToolsPsN: String { t("settings.tools.psn") }
    static var settingsToolsPsNHint: String { t("settings.tools.psnHint") }
    static var settingsToolsPython: String { t("settings.tools.python") }
    static var settingsToolsPythonHint: String { t("settings.tools.pythonHint") }
    static var settingsToolsViewers: String { t("settings.tools.viewers") }
    static var settingsToolsViewersHint: String { t("settings.tools.viewersHint") }
    static var settingsToolsDataFile: String { t("settings.tools.dataFile") }
    static var settingsToolsDataFileHint: String { t("settings.tools.dataFileHint") }
    static var settingsToolsDataFileHintText: String { t("settings.tools.dataFileHintText") }
    static var settingsAutoDetect: String { t("settings.autoDetect") }
    static var settingsBrowse: String { t("settings.browse") }
    static var settingsFound: String { t("settings.found") }
    static var settingsNotFound: String { t("settings.notFound") }

    // Automation
    static var autoStartFresh: String { t("auto.startFresh") }
    static var autoStartFreshDetail: String { t("auto.startFreshDetail") }
    static var autoStartContinue: String { t("auto.startContinue") }
    static var autoStartContinueDetail: String { t("auto.startContinueDetail") }
    static var autoStartFromModel: String { t("auto.startFromModel") }
    static var autoStartFromModelDetail: String { t("auto.startFromModelDetail") }
    static var autoTitle: String { t("auto.title") }
    static var autoSubtitle: String { t("auto.subtitle") }
    static var autoMode: String { t("auto.mode") }
    static var autoParentModel: String { t("auto.parentModel") }
    static var autoGuidance: String { t("auto.guidance") }
    static var autoGuidanceHint: String { t("auto.guidanceHint") }
    static var autoCancel: String { t("auto.cancel") }
    static var autoStart: String { t("auto.start") }

    // Context menu
    static var ctxRunNONMEM: String { t("ctx.runNonmem") }
    static var ctxRunGOF: String { t("ctx.runGof") }
    static var ctxRunVPC: String { t("ctx.runVpc") }
    static var ctxRunIndividual: String { t("ctx.runIndividual") }
    static var ctxRunAllDiagnostics: String { t("ctx.runAllDiagnostics") }
    static var ctxExtractPK: String { t("ctx.extractPk") }
    static var ctxBootstrap: String { t("ctx.bootstrap") }
    static var ctxSCM: String { t("ctx.scm") }
    static var ctxAIEvaluate: String { t("ctx.aiEvaluate") }
    static var ctxOpen: String { t("ctx.open") }
    static var ctxPin: String { t("ctx.pin") }
    static var ctxUnpin: String { t("ctx.unpin") }
    static var ctxReveal: String { t("ctx.reveal") }
    static var ctxDelete: String { t("ctx.delete") }

    // Delete confirmation
    static var deleteTitle: String { t("delete.title") }
    static var deleteMessage: String { t("delete.message") }
    static var deleteCancel: String { t("delete.cancel") }
    static var deleteConfirm: String { t("delete.confirm") }

    // Project sheet
    static var projectCreateBlank: String { t("project.createBlank") }
    static var projectCreateBlankMsg: String { t("project.createBlankMsg") }
    static var projectCreateFromRun: String { t("project.createFromRun") }
    static var projectCreate: String { t("project.create") }

    // Terminal
    static var terminalReady: String { t("terminal.ready") }

    // About
    static var aboutTitle: String { t("about.title") }
    static var aboutSubtitle: String { t("about.subtitle") }
    static var aboutDescription: String { t("about.description") }
    static var aboutProviders: String { t("about.providers") }
    static var aboutBuilt: String { t("about.built") }

    // Workbench
    static var workbenchOverview: String { t("workbench.overview") }

    // App display name
    static let appName = "AutoPMX"
    static let appSubtitle = "DuDu PMx Workbench"

    // Thinking steps
    static var thinkCheckingLLM: String { t("think.checkingLLM") }
    static var thinkPreparingProject: String { t("think.preparingProject") }
    static var thinkAnalyzingDataset: String { t("think.analyzingDataset") }
    static var thinkAIWritingModel: String { t("think.aiWritingModel") }
    static var thinkRunningNONMEM: String { t("think.runningNonmem") }
    static var thinkRunningDiagnostics: String { t("think.runningDiagnostics") }
    static var thinkAIEvaluating: String { t("think.aiEvaluating") }

    // Automation messages
    static var msgAutomationStarted: String { t("msg.automation.started") }
    static var msgAutomationUserGuidance: String { t("msg.automation.userGuidance") }
    static var msgAutomationProjectCreated: String { t("msg.automation.projectCreated") }
    static var msgAutomationDatasetAnalysis: String { t("msg.automation.datasetAnalysis") }
    static var msgAutomationModelCreated: String { t("msg.automation.modelCreated") }
    static var msgAutomationResuming: String { t("msg.automation.resuming") }
    static var msgAutomationComplete: String { t("msg.automation.complete") }
    static var msgAutomationBest: String { t("msg.automation.best") }
    static var msgAutomationStopped: String { t("msg.automation.stopped") }
    static var msgAutomationFailed: String { t("msg.automation.failed") }
    static var msgAutomationStopRequested: String { t("msg.automation.stopRequested") }

    // Others
    static var othersNoParams: String { t("others.noParams") }
    static var othersNA: String { t("others.na") }
    static var othersNotConnected: String { t("others.notConnected") }
    static var othersNotTested: String { t("others.notTested") }
    static var othersNeverTested: String { t("others.neverTested") }
    static var othersModelsAvailable: String { t("others.modelsAvailable") }
    static var othersModelNotSelected: String { t("others.modelNotSelected") }


    // Appearance
    static var appearance: String { t("settings.appearance") }
    static var followSystem: String { t("settings.followSystem") }
    static var lightTheme: String { t("settings.light") }
    static var darkTheme: String { t("settings.dark") }

    // Particle effects
    static var particleEffects: String { t("settings.particleEffects") }
    static var particleEffectsEnable: String { t("settings.particleEffectsEnable") }
    static var particleEffectsDesc: String { t("settings.particleEffectsDesc") }
    static var particleCount: String { t("settings.particleCount") }
    static var particleLite: String { t("settings.particleLite") }
    static var particleStandard: String { t("settings.particleStandard") }
    static var particlePerformance: String { t("settings.particlePerformance") }
    static var toolsTitle: String { t("settings.tools.title") }
    static var toolsR: String { t("settings.tools.r") }
    static var toolsRHint: String { t("settings.tools.rHint") }
    static var toolsFileViewers: String { t("settings.tools.fileViewers") }
    static var toolsDataFile: String { t("settings.tools.dataFile") }
    static var toolsDataFileDesc: String { t("settings.tools.dataFileDesc") }
    static var rulesTitle: String { t("settings.rules.title") }
    static var rulesSourceFilesDesc: String { t("settings.rules.sourceFilesDesc") }
    static var rulesKnownFilesDesc: String { t("settings.rules.knownFilesDesc") }

    // Provider form labels
    static var providerName: String { t("settings.name") }
    static var providerApiFormat: String { t("settings.apiFormat") }
    static var providerBaseURL: String { t("settings.baseURL") }
    static var providerModel: String { t("settings.model") }
    static var providerApiKey: String { t("settings.apiKey") }
    static var providerTestConnection: String { t("settings.testConnection") }
    static var providerRemove: String { t("settings.remove") }
    static var providerConnected: String { t("settings.connected") }
    static var providerNotTested: String { t("settings.notTested") }
    static var providerNoModel: String { t("settings.noModel") }
    static var buttonBrowse: String { t("settings.browse") }

    // MARK: - Translation Table

    private static let strings: [String: [AppLanguage: String]] = [
        // General UI
        "general.title": [.zhCN: "通用", .en: "General"],
        "general.language": [.zhCN: "语言", .en: "Language"],
        "general.selectLanguage": [.zhCN: "选择语言", .en: "Select Language"],
        "general.cancel": [.zhCN: "取消", .en: "Cancel"],
        "general.start": [.zhCN: "开始", .en: "Start"],
        "general.save": [.zhCN: "保存", .en: "Save"],

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

        // AI message bubble UI
        "ai.reasoning": [.zhCN: "推理过程", .en: "Reasoning"],
        "ai.steps": [.zhCN: "步", .en: "steps"],
        "ai.thinkingDots": [.zhCN: "思考中...", .en: "Thinking..."],
        "ai.copy": [.zhCN: "复制", .en: "Copy"],
        "ai.copyHint": [.zhCN: "复制消息", .en: "Copy message"],
        "ai.fillInput": [.zhCN: "填入输入框", .en: "Insert into input"],
        "ai.clickToRun": [.zhCN: "点击执行", .en: "Click to run"],

        // Action chips
        "action.autoModel": [.zhCN: "DuDu Auto", .en: "DuDu Auto"],
        "action.compare": [.zhCN: "Compare", .en: "Compare"],
        "action.evaluate": [.zhCN: "模型评估", .en: "Evaluate"],
        "action.pkParams": [.zhCN: "PK 参数", .en: "PK Params"],
        "action.gaOpt": [.zhCN: "GA 优化", .en: "GA Optimize"],
        "action.gof": [.zhCN: "GOF", .en: "GOF"],
        "action.vpc": [.zhCN: "VPC", .en: "VPC"],

        // AI Compare sheet
        "ai.compare.runA": [.zhCN: "Run A", .en: "Run A"],
        "ai.compare.runB": [.zhCN: "Run B", .en: "Run B"],
        "ai.compare.start": [.zhCN: "开始比较", .en: "Start Comparison"],
        "ai.compare.needsTwo": [.zhCN: "至少需要两个已生成的模型才能进行比较。", .en: "At least two successfully run models are needed for comparison."],

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
        // Appearance
        "settings.appearance": [.zhCN: "外观", .en: "Appearance"],
        "settings.followSystem": [.zhCN: "跟随系统", .en: "System"],
        "settings.light": [.zhCN: "浅色", .en: "Light"],
        "settings.dark": [.zhCN: "深色", .en: "Dark"],

        // Particle effects
        "settings.particleEffects": [.zhCN: "粒子特效", .en: "Particle Effects"],
        "settings.particleEffectsEnable": [.zhCN: "启用粒子特效", .en: "Enable Particle Effects"],
        "settings.particleEffectsDesc": [.zhCN: "鼠标悬停按钮时显示细微风粒子动画，DuDu PMx 浮动按钮周围也有极光粒子环绕", .en: "Show subtle wind-like particle animations on button hover, with aurora particles orbiting the DuDu PMx floating button"],
        "settings.particleCount": [.zhCN: "粒子数量", .en: "Particle Count"],
        "settings.particleLite": [.zhCN: "轻量", .en: "Lite"],
        "settings.particleStandard": [.zhCN: "标准", .en: "Standard"],
        "settings.particlePerformance": [.zhCN: "性能", .en: "Performance"],

        // Tools
        "settings.tools.title": [.zhCN: "工具与路径", .en: "Tools & Paths"],
        "settings.tools.r": [.zhCN: "R 环境 (Rscript)", .en: "R Environment (Rscript)"],
        "settings.tools.rHint": [.zhCN: "Rscript 路径，用于运行 R 诊断和绘图。推荐 R 4.x 并安装 xpose、ggplot2、dplyr。", .en: "Path to Rscript for running R-based diagnostics and plotting. R 4.x with xpose, ggplot2, and dplyr is recommended."],
        "settings.tools.fileViewers": [.zhCN: "文件查看器", .en: "File Viewers"],
        "settings.tools.dataFileDesc": [.zhCN: "创建新项目时的默认 CSV 文件名。如需按项目设置数据集，请在侧边栏右键 CSV → 设为建模数据集。", .en: "Default CSV filename when creating new projects. To set dataset per-project, right-click a CSV in the sidebar → Set as Modeling Dataset."],

        // Rules
        "settings.rules.title": [.zhCN: "规则与知识来源", .en: "Rule & Knowledge Sources"],
        "settings.rules.sourceFilesDesc": [.zhCN: "逗号分隔的规则、知识、审核文件列表。AutoPMX 会搜索项目目录、工作区根目录和 AutoPMX_Projects 文件夹。", .en: "Comma-separated list of rule, knowledge, and audit files. AutoPMX searches the project directory, workspace root, and AutoPMX_Projects folder."],
        "settings.rules.knownFilesDesc": [.zhCN: "工作区中存在的文件，可以添加为来源文件。点击添加。", .en: "These files exist in your workspace and can be added as sources. Click to append."],

    ]
}
