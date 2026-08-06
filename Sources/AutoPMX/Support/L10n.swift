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
    static var sidebarDataset: String { t("sidebar.dataset") }
    static var markTitle: String { t("mark.title") }
    static var markClear: String { t("mark.clear") }
    static var markRed: String { t("mark.red") }
    static var markOrange: String { t("mark.orange") }
    static var markYellow: String { t("mark.yellow") }
    static var markGreen: String { t("mark.green") }
    static var markBlue: String { t("mark.blue") }
    static var markPurple: String { t("mark.purple") }
    static var markPink: String { t("mark.pink") }
    static var markGray: String { t("mark.gray") }

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
    static var settingsProviderIcon: String { t("settings.providerIcon") }
    static var settingsProviderIconAuto: String { t("settings.providerIconAuto") }
    static var settingsModelsFound: String { t("settings.modelsFound") }
    static var settingsNotTested: String { t("settings.notTested") }
    static var settingsConnected: String { t("settings.connected") }
    static var settingsNoModel: String { t("settings.noModel") }
    static var settingsPinProvider: String { t("settings.llm.pin") }
    static var settingsUnpinProvider: String { t("settings.llm.unpin") }
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
    static var rulesLibraryOverview: String { t("settings.rules.libraryOverview") }
    static var rulesFiles: String { t("settings.rules.files") }
    static var rulesTotal: String { t("settings.rules.total") }
    static var rulesSizeKB: String { t("settings.rules.sizeKB") }
    static func rulesCategoryTitle(_ key: String) -> String { t("settings.rules.category.\(key)") }
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

    // AI Overlay (quick actions, sheets)
    static var quickAutoModeling: String { t("quick.autoModeling") }
    static var quickIndividual: String { t("quick.individual") }
    static var quickModelCompare: String { t("quick.modelCompare") }
    static var quickGOFPlots: String { t("quick.gofPlots") }
    static var quickVPCCheck: String { t("quick.vpcCheck") }
    static var quickIndividualDV: String { t("quick.individualDV") }
    static var quickPKExtract: String { t("quick.pkExtract") }
    static var quickSCMCov: String { t("quick.scmCov") }
    static var quickETAScreen: String { t("quick.etaScreen") }
    static var quickTitle: String { t("quick.title") }
    static var quickBusyHint: String { t("quick.busyHint") }
    static var aiPlaceholder: String { t("ai.placeholder") }
    static var aiAutoModelingBusy: String { t("ai.autoModelingBusy") }
    static var noModelCardTitle: String { t("noModel.cardTitle") }
    static var noModelCardBody: String { t("noModel.cardBody") }
    static var noModelBuildCta: String { t("noModel.buildCta") }
    static var noModelChatHint: String { t("noModel.chatHint") }
    static var helpAskDuDuTitle: String { t("help.askDuDuTitle") }
    static var helpAskDuDuCta: String { t("help.askDuDuCta") }
    static var helpContextSystemIntro: String { t("help.contextSystemIntro") }
    static var helpContextReadyHint: String { t("help.contextReadyHint") }
    static var helpQ1: String { t("help.q1") }
    static var helpQ2: String { t("help.q2") }
    static var helpQ3: String { t("help.q3") }
    static var scmBusySwitchWarning: String { t("scm.busySwitchWarning") }
    static var bootstrapBusySwitchWarning: String { t("bootstrap.busySwitchWarning") }
    static var autoSheetTitle: String { t("auto.sheetTitle") }
    static var autoDatasetLabel: String { t("auto.datasetLabel") }
    static var autoDataFileLabel: String { t("auto.dataFileLabel") }
    static var autoUnspecified: String { t("auto.unspecified") }
    static var autoSingleDataset: String { t("auto.singleDataset") }
    static var autoGuidanceLabel: String { t("auto.guidanceLabel") }
    static var autoStartSCM: String { t("auto.startSCM") }
    static var compareTitle: String { t("compare.title") }
    static var compareSubtitle: String { t("compare.subtitle") }
    static var scmSheetTitle: String { t("scm.sheetTitle") }
    static var scmBaseModel: String { t("scm.baseModel") }
    static var scmModelFile: String { t("scm.modelFile") }
    static var scmDataFile: String { t("scm.dataFile") }
    static var scmCandidates: String { t("scm.candidates") }
    static var scmCovWT: String { t("scm.covWT") }
    static var scmCovAGE: String { t("scm.covAGE") }
    static var scmCovSEX: String { t("scm.covSEX") }
    static var scmCovSTUDY: String { t("scm.covSTUDY") }
    static var scmCovNote: String { t("scm.covNote") }
    static var scmThreshold: String { t("scm.threshold") }
    static var scmForwardP: String { t("scm.forwardP") }
    static var scmBackwardP: String { t("scm.backwardP") }
    static var scmBackwardRange: String { t("scm.backwardRange") }
    static var scmRunNote: String { t("scm.runNote") }
    static var scmRunEtaScreen: String { t("scm.runEtaScreen") }
    static var scmRunEtaHint: String { t("scm.runEtaHint") }
    static var scmEtaSuggestionTitle: String { t("scm.etaSuggestionTitle") }
    static var scmEtaSuggestionHint: String { t("scm.etaSuggestionHint") }
    static var scmEtaApplySuggestion: String { t("scm.etaApplySuggestion") }
    static var scmEtaResetAll: String { t("scm.etaResetAll") }
    static var scmFinalConfirmTitle: String { t("scm.finalConfirmTitle") }
    static var scmFinalConfirmBody: String { t("scm.finalConfirmBody") }
    static var scmFinalConfirmContinue: String { t("scm.finalConfirmContinue") }
    static var scmFinalConfirmLater: String { t("scm.finalConfirmLater") }
    static var ctxUsagePanel: String { t("ctx.usagePanel") }
    static var ctxWindowLimit: String { t("ctx.windowLimit") }
    static var ctxRuleContext: String { t("ctx.ruleContext") }
    static var ctxRequestPrompt: String { t("ctx.requestPrompt") }
    static var ctxOutput: String { t("ctx.output") }
    static var ctxTotalInput: String { t("ctx.totalInput") }
    static var ctxTotalOutput: String { t("ctx.totalOutput") }
    static var ctxCacheRead: String { t("ctx.cacheRead") }
    static var ctxCacheWrite: String { t("ctx.cacheWrite") }
    static var ctxCacheHitRate: String { t("ctx.cacheHitRate") }
    static var ctxWindowOccupied: String { t("ctx.windowOccupied") }
    static var ctxNoUsage: String { t("ctx.noUsage") }
    static var detectEDA: String { t("detect.eda") }
    static var detectCT: String { t("detect.ct") }
    static var phase1Complete: String { t("phase1.complete") }
    static var phase1ConfirmMsg: String { t("phase1.confirmMsg") }
    static var phase1CancelLater: String { t("phase1.cancelLater") }
    static var phase1ConfirmStart: String { t("phase1.confirmStart") }
    static var pickIndividual: String { t("pick.individual") }
    static var pickerNoModels: String { t("picker.noModels") }
    static var pickerModel: String { t("picker.model") }
    static var bootstrapSamplesTitle: String { t("bootstrap.samplesTitle") }
    static var bootstrapSamplesHint: String { t("bootstrap.samplesHint") }
    static var bootstrapStart: String { t("bootstrap.start") }
    static var pickerCurrent: String { t("picker.current") }

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
    static let appName = "AutoPMx"
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

    // DuDu status messages (chat bubbles + runner log)
    static var statusAutoBlockedCreate: String { t("status.autoBlockedCreate") }
    static var statusAutoBlockedCreateChat: String { t("status.autoBlockedCreateChat") }
    static var statusAutoBlockedSwitch: String { t("status.autoBlockedSwitch") }
    static var statusAutoBlockedSwitchChat: String { t("status.autoBlockedSwitchChat") }
    static var statusAutoBlockedDelete: String { t("status.autoBlockedDelete") }
    static var statusDistillDone: String { t("status.distillDone") }
    static var statusLLMConnected: String { t("status.llmConnected") }
    static var statusChatStopped: String { t("status.chatStopped") }
    static var statusAgentDone: String { t("status.agentDone") }
    static var statusBaseModelPhase2: String { t("status.baseModelPhase2") }
    static var statusSCMReuseManual: String { t("status.scmReuseManual") }
    static var statusSCMStarting: String { t("status.scmStarting") }
    static var statusSCMCompleteValidate: String { t("status.scmCompleteValidate") }
    static var statusSCMUnavailable: String { t("status.scmUnavailable") }
    static var statusForcedRevise: String { t("status.forcedRevise") }
    static var statusForcedReviseBase: String { t("status.forcedReviseBase") }
    static var statusCompAcceptNotSC: String { t("status.compAcceptNotSC") }
    static var statusCompRequireCompare: String { t("status.compRequireCompare") }
    static var statusCompIntegrityFail: String { t("status.compIntegrityFail") }
    static var statusCompDecisionRSE: String { t("status.compDecisionRSE") }
    static var statusPhase1Complete: String { t("status.phase1Complete") }
    static var statusPhase1CompleteSuboptimal: String { t("status.phase1CompleteSuboptimal") }
    static var statusBootstrapStarted: String { t("status.bootstrapStarted") }
    static var statusBootstrapFailed: String { t("status.bootstrapFailed") }
    static var statusBootstrapParseFailed: String { t("status.bootstrapParseFailed") }
    static var statusBootstrapAIStarted: String { t("status.bootstrapAIStarted") }
    static var statusBootstrapPreparing: String { t("status.bootstrapPreparing") }
    static var statusBootstrapRunning: String { t("status.bootstrapRunning") }
    static var statusBootstrapParsing: String { t("status.bootstrapParsing") }
    static func statusBootstrapParsingDone(_ runID: String) -> String { String(format: t("status.bootstrapParsingDone"), runID) }
    static func statusBootstrapThinking(_ runID: String) -> String { String(format: t("status.bootstrapThinking"), runID) }
    static var statusSCMStarted: String { t("status.scmStarted") }
    static var statusSCMDone: String { t("status.scmDone") }
    static var statusSCMPromote: String { t("status.scmPromote") }
    static var statusSCMFailed: String { t("status.scmFailed") }
    static var statusGAModelMissing: String { t("status.gaModelMissing") }
    static var statusGAOptimizing: String { t("status.gaOptimizing") }
    static var statusGAScriptMissing: String { t("status.gaScriptMissing") }
    static var statusGAOptimizeDone: String { t("status.gaOptimizeDone") }
    static var statusGAFailed: String { t("status.gaFailed") }
    static var statusGAStructuralModelMissing: String { t("status.gaStructuralModelMissing") }
    static var statusGAStructuralSearching: String { t("status.gaStructuralSearching") }
    static var statusGAStructuralScriptMissing: String { t("status.gaStructuralScriptMissing") }
    static var statusGAStructuralDone: String { t("status.gaStructuralDone") }
    static var statusGAStructuralFailed: String { t("status.gaStructuralFailed") }
    static var statusAuditNotRun: String { t("status.auditNotRun") }
    static var statusEvaluateNotRun: String { t("status.evaluateNotRun") }
    static var statusCompareStarting: String { t("status.compareStarting") }
    static var statusCompareFailed: String { t("status.compareFailed") }
    static var statusClaudePanelOpened: String { t("status.claudePanelOpened") }
    static var statusFirstDoseLabel: String { t("status.firstDoseLabel") }
    static var statusFullCurveLabel: String { t("status.fullCurveLabel") }
    static var statusSemiLogLabel: String { t("status.semiLogLabel") }
    static var statusAgentJSONPrompt: String { t("status.agentJSONPrompt") }
    static var statusAgentToolResult: String { t("status.agentToolResult") }

    // LLM connection error messages
    static var errorCannotConnect: String { t("error.cannotConnect") }
    static var errorBadURL: String { t("error.badURL") }
    static var errorUnauthorized: String { t("error.unauthorized") }
    static var errorCouldNotConnectLMStudio: String { t("error.couldNotConnectLMStudio") }
    static var errorGeneric: String { t("error.generic") }
    static var errorRemoteRequest: String { t("error.remoteRequest") }
    static var errorRetryExhausted: String { t("error.retryExhausted") }
    static var errorOllamaTips: String { t("error.ollamaTips") }

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

    static var aiSkillTitle: String { t("settings.aiSkillTitle") }
    static var aiSkillDesc: String { t("settings.aiSkillDesc") }
    static var aiSkillLessons: String { t("settings.aiSkillLessons") }
    static var aiSkillSuccesses: String { t("settings.aiSkillSuccesses") }
    static var aiSkillInsights: String { t("settings.aiSkillInsights") }
    static var aiSkillScmErrors: String { t("settings.aiSkillScmErrors") }
    static var aiSkillUpdated: String { t("settings.aiSkillUpdated") }
    static var aiSkillClear: String { t("settings.aiSkillClear") }
    static var aiSkillClearConfirm: String { t("settings.aiSkillClearConfirm") }
    static var aiSkillEmpty: String { t("settings.aiSkillEmpty") }
    static var aiSkillExport: String { t("settings.aiSkillExport") }
    static var aiSkillImport: String { t("settings.aiSkillImport") }
    static var aiSkillExportSuccess: String { t("settings.aiSkillExportSuccess") }
    static var aiSkillExportFailed: String { t("settings.aiSkillExportFailed") }
    static var aiSkillImportSuccess: String { t("settings.aiSkillImportSuccess") }
    static var aiSkillImportFailed: String { t("settings.aiSkillImportFailed") }
    static var toolsTitle: String { t("settings.tools.title") }
    static var toolsR: String { t("settings.tools.r") }
    static var toolsRHint: String { t("settings.tools.rHint") }
    static var toolsFileViewers: String { t("settings.tools.fileViewers") }
    static var toolsDataFile: String { t("settings.tools.dataFile") }
    static var toolsDataFileDesc: String { t("settings.tools.dataFileDesc") }
    static var rulesTitle: String { t("settings.rules.title") }
    static var rulesBuiltInTitle: String { t("settings.rules.builtInTitle") }
    static var rulesBuiltInDesc: String { t("settings.rules.builtInDesc") }
    static var rulesUserTitle: String { t("settings.rules.userTitle") }
    static var rulesUserDesc: String { t("settings.rules.userDesc") }
    static var rulesUpload: String { t("settings.rules.upload") }
    static var rulesRemove: String { t("settings.rules.remove") }
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

    // Token chart range
    static var tokensWeek: String { t("tokens.week") }
    static var tokensMonth: String { t("tokens.month") }

    // DuDu Chat Style
    static var duduChatStyle: String { t("dudu.chatStyle") }
    static var duduChatStyleDesc: String { t("dudu.chatStyleDesc") }
    static var duduCustomPrompt: String { t("dudu.customPrompt") }
    static var duduCustomPromptDesc: String { t("dudu.customPromptDesc") }
    static var duduCustomPromptPlaceholder: String { t("dudu.customPromptPlaceholder") }
    static var duduLearnStyle: String { t("dudu.learnStyle") }
    static var duduLearnStyleDesc: String { t("dudu.learnStyleDesc") }
    static var duduLearnStyleToggle: String { t("dudu.learnStyleToggle") }
    static var duduCollectedMessages: String { t("dudu.collectedMessages") }
    static var duduGenerating: String { t("dudu.generating") }
    static var duduGenerateProfile: String { t("dudu.generateProfile") }
    static var duduMinMessages: String { t("dudu.minMessages") }
    static var duduStyleProfile: String { t("dudu.styleProfile") }
    static var duduGeneratedByLLM: String { t("dudu.generatedByLLM") }
    static var duduClearAll: String { t("dudu.clearAll") }
    static var duduRegenerate: String { t("dudu.regenerate") }
    static var duduLearnStyleHint: String { t("dudu.learnStyleHint") }

    // Personality titles/descriptions (for L10n inside enum)
    static var personalityCuteTitle: String { t("personality.cute.title") }
    static var personalityCuteDesc: String { t("personality.cute.desc") }
    static var personalityCuteWelcome: String { t("personality.cute.welcome") }
    static var personalityConciseTitle: String { t("personality.concise.title") }
    static var personalityConciseDesc: String { t("personality.concise.desc") }
    static var personalityConciseWelcome: String { t("personality.concise.welcome") }
    static var personalityExpertTitle: String { t("personality.expert.title") }
    static var personalityExpertDesc: String { t("personality.expert.desc") }
    static var personalityExpertWelcome: String { t("personality.expert.welcome") }
    static var personalityHumorousTitle: String { t("personality.humorous.title") }
    static var personalityHumorousDesc: String { t("personality.humorous.desc") }
    static var personalityHumorousWelcome: String { t("personality.humorous.welcome") }
    static var personalityCustomTitle: String { t("personality.custom.title") }
    static var personalityCustomDesc: String { t("personality.custom.desc") }
    static var personalityCustomWelcome: String { t("personality.custom.welcome") }

    // Knowledge Base
    static var settingsKnowledgeBaseTitle: String { t("settings.knowledgeBaseTitle") }
    static var settingsKnowledgeBaseDesc: String { t("settings.knowledgeBaseDesc") }
    static var settingsKnowledgeBaseLoaded: String { t("settings.knowledgeBaseLoaded") }

    // AI Skill Distill
    static var settingsDistillFromHistory: String { t("settings.distillFromHistory") }
    static var settingsDistillProgress: String { t("settings.distillProgress") }
    static var settingsDistillStep: String { t("settings.distillStep") }
    static var settingsDistillSuccess: String { t("settings.distillSuccess") }
    static var settingsDistillNone: String { t("settings.distillNone") }

    // Compartment Decision
    static var compDecisionTitle: String { t("compDecision.title") }
    static var compDecisionAcceptLower: String { t("compDecision.acceptLower") }
    static var compDecisionAcceptCurrent: String { t("compDecision.acceptCurrent") }
    static var compDecisionDesc: String { t("compDecision.desc") }

    // Base Model Confirm
    static var baseModelStartSCM: String { t("baseModel.startSCM") }
    static var baseModelSkipSCM: String { t("baseModel.skipSCM") }

    // SCM Report
    static var scmReportHeader: String { t("scm.reportHeader") }
    static var scmReportBaseStructure: String { t("scm.reportBaseStructure") }
    static var scmReportAvailableCov: String { t("scm.reportAvailableCov") }
    static var scmNoCovFound: String { t("scm.noCovFound") }
    static var scmCovFound: String { t("scm.covFound") }
    static var scmWtIncluded: String { t("scm.wtIncluded") }
    static var scmAiHeader: String { t("scm.aiHeader") }
    static var scmDiagGenerated: String { t("scm.diagGenerated") }
    static var scmReportFooter: String { t("scm.reportFooter") }
    static var scmLlmNotConfigured: String { t("scm.llmNotConfigured") }
    static var scmVerificationFailed: String { t("scm.verificationFailed") }
    static var scmDuDuModelEmpty: String { t("scm.duduModelEmpty") }
    static var scmCompareHeader: String { t("scm.compareHeader") }
    static var scmCompareMatch: String { t("scm.compareMatch") }
    static var scmCompareOnlyDuDu: String { t("scm.compareOnlyDuDu") }
    static var scmCompareOnlySCM: String { t("scm.compareOnlySCM") }
    static var scmCompareNone: String { t("scm.compareNone") }
    static var scmCompareWTBothIn: String { t("scm.compareWTBothIn") }
    static var scmCompareWTBothOut: String { t("scm.compareWTBothOut") }
    static var scmCompareWTDuDuIn: String { t("scm.compareWTDuDuIn") }
    static var scmCompareWTDuDuOut: String { t("scm.compareWTDuDuOut") }
    static var scmCompareWTSCMIn: String { t("scm.compareWTSCMIn") }
    static var scmCompareWTSCMOut: String { t("scm.compareWTSCMOut") }
    static var scmCompareWTWarning: String { t("scm.compareWTWarning") }
    static var scmCompareFooter: String { t("scm.compareFooter") }
    static var scmModelReadFailed: String { t("scm.modelReadFailed") }
    static var scmReplicateHeader: String { t("scm.replicateHeader") }
    static var scmReplicateNoCov: String { t("scm.replicateNoCov") }
    static var scmForwardHeader: String { t("scm.forwardHeader") }
    static var scmBackwardHeader: String { t("scm.backwardHeader") }
    static var scmReplicateForward: String { t("scm.replicateForward") }
    static var scmReplicateBackward: String { t("scm.replicateBackward") }
    static var scmReplicateRunDone: String { t("scm.replicateRunDone") }
    static var scmReplicateFinal: String { t("scm.replicateFinal") }
    static var scmReplicateFailed: String { t("scm.replicateFailed") }
    static var scmReplicateBaseRun: String { t("scm.replicateBaseRun") }
    static var scmReplicateSequence: String { t("scm.replicateSequence") }
    static var scmCancelled: String { t("scm.cancelled") }
    static var scmNoCandidatesSelected: String { t("scm.noCandidatesSelected") }
    static var scmReplicateCovInBase: String { t("scm.replicateCovInBase") }
    static var scmForwardChat: String { t("scm.forwardChat") }
    static var scmBackwardChat: String { t("scm.backwardChat") }
    static var scmRelationDesc: String { t("scm.relationDesc") }
    static var scmRelationJoin: String { t("scm.relationJoin") }
    static var scmSummaryHeader: String { t("scm.summaryHeader") }
    static var scmSummaryNone: String { t("scm.summaryNone") }
    static var scmSummaryIncluded: String { t("scm.summaryIncluded") }
    static var scmSummaryOfvAic: String { t("scm.summaryOfvAic") }
    static var scmPopupTitle: String { t("scm.popupTitle") }
    static var bootstrapPopupTitle: String { t("bootstrap.popupTitle") }
    static var scmStepPreparing: String { t("scm.stepPreparing") }
    static var scmStepConfig: String { t("scm.stepConfig") }
    static var scmStepRunning: String { t("scm.stepRunning") }
    static var scmConfigReady: String { t("scm.configReady") }
    static var scmRunningNotice: String { t("scm.runningNotice") }
    static var scmReplicatePlan: String { t("scm.replicatePlan") }
    static var scmStepDone: String { t("scm.stepDone") }

    // Claude Code
    static var claudeHintTitle: String { t("claude.hintTitle") }
    static var claudeHintText1: String { t("claude.hintText1") }
    static var claudeHintText2: String { t("claude.hintText2") }
    static var claudeExampleTitle: String { t("claude.exampleTitle") }
    static var claudeExample1: String { t("claude.example1") }
    static var claudeExample2: String { t("claude.example2") }
    static var claudeExample3: String { t("claude.example3") }
    static var claudeSkillAnalyze: String { t("claude.skillAnalyze") }
    static var claudeSkillFix: String { t("claude.skillFix") }
    static var claudeSkillCompare: String { t("claude.skillCompare") }
    static var claudeSkillCovariate: String { t("claude.skillCovariate") }
    static var claudeSkillNewModel: String { t("claude.skillNewModel") }

    // CT & Auto messages
    static var ctAnalysisComplete: String { t("ct.analysisComplete") }
    static var ctCtPlot: String { t("ct.ctPlot") }
    static var ctFacetPlot: String { t("ct.facetPlot") }
    static var ctIVroute: String { t("ct.IVroute") }
    static var ctAbsorptionLag: String { t("ct.absorptionLag") }
    static var ctMultiCompartment: String { t("ct.multiCompartment") }
    static var ctOneCompartment: String { t("ct.oneCompartment") }
    static var ctLinearPK: String { t("ct.linearPK") }
    static var ctNonlinearPK: String { t("ct.nonlinearPK") }
    static var ctRscriptMissing: String { t("ct.rscriptMissing") }
    static var ctPlotFailed: String { t("ct.plotFailed") }
    static var ctElimSynthAgreeSame: String { t("ct.elimSynthAgreeSame") }
    static var ctElimSynthAgreeDiff: String { t("ct.elimSynthAgreeDiff") }
    static var ctElimSynthDisagree: String { t("ct.elimSynthDisagree") }
    static var ctElimFirstDoseOnlySame: String { t("ct.elimFirstDoseOnlySame") }
    static var ctElimFirstDoseOnlyDiff: String { t("ct.elimFirstDoseOnlyDiff") }
    static var ctElimWholeOnlySame: String { t("ct.elimWholeOnlySame") }
    static var ctElimWholeOnlyDiff: String { t("ct.elimWholeOnlyDiff") }
    static var ctElimBothInsufficient: String { t("ct.elimBothInsufficient") }
    static var ctElimTerminalInsufficient: String { t("ct.elimTerminalInsufficient") }
    static var ctElimSimilar: String { t("ct.elimSimilar") }
    static var ctElimDifferent: String { t("ct.elimDifferent") }
    static var auditRunning: String { t("audit.running") }
    static var auditFull: String { t("audit.full") }
    static var auditGof: String { t("audit.gof") }
    static var auditVpc: String { t("audit.vpc") }
    static var auditParameter: String { t("audit.parameter") }
    static var auditSelected: String { t("audit.selected") }
    static var auditCompareFirst: String { t("audit.compareFirst") }
    static var reviseHeader: String { t("revise.header") }
    static var revisePhase1: String { t("revise.phase1") }
    static var revisePhase2: String { t("revise.phase2") }
    static var reviseBody: String { t("revise.body") }
    static var ctModelCreated: String { t("ct.modelCreated") }
    static var ctResuming: String { t("ct.resuming") }
    static var ctCleanProjectCreated: String { t("ct.cleanProjectCreated") }
    static var ctModelingStarted: String { t("ct.modelingStarted") }
    static var ctPathWarning: String { t("ct.pathWarning") }
    static var ctGuidanceApplied: String { t("ct.guidanceApplied") }
    static var ctCovComplete: String { t("ct.covComplete") }
    static var ctDiagSkipped: String { t("ct.diagSkipped") }
    static var autoGatingLocked: String { t("auto.gatingLocked") }
    static var autoGatingLockedShort: String { t("auto.gatingLockedShort") }
    static var autoHighRSEFix: String { t("auto.highRSEFix") }
    static var autoLimitReached: String { t("auto.limitReached") }
    static var autoStoppedShort: String { t("auto.stoppedShort") }
    static var autoCompletedMsg: String { t("auto.completedMsg") }
    static var autoCompletedSimple: String { t("auto.completedSimple") }
    static var autoCompletedWithCov: String { t("auto.completedWithCov") }
    static var autoCompletedPhase2: String { t("auto.completedPhase2") }
    static var autoStoppedAt: String { t("auto.stoppedAt") }
    static var autoFailed: String { t("auto.failed") }

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
        "sidebar.dataset": [.zhCN: "数据集", .en: "Dataset"],
        "mark.title": [.zhCN: "标记颜色", .en: "Mark Color"],
        "mark.clear": [.zhCN: "清除标记", .en: "Clear Mark"],
        "mark.red": [.zhCN: "红色", .en: "Red"],
        "mark.orange": [.zhCN: "橙色", .en: "Orange"],
        "mark.yellow": [.zhCN: "黄色", .en: "Yellow"],
        "mark.green": [.zhCN: "绿色", .en: "Green"],
        "mark.blue": [.zhCN: "蓝色", .en: "Blue"],
        "mark.purple": [.zhCN: "紫色", .en: "Purple"],
        "mark.pink": [.zhCN: "粉色", .en: "Pink"],
        "mark.gray": [.zhCN: "灰色", .en: "Gray"],

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
        "settings.visionModel": [.zhCN: "视觉模型 (Vision Model)", .en: "Vision Model (multimodal)"],
        "settings.visionOptional": [.zhCN: "可选，留空则复用主模型", .en: "Optional — leave empty to reuse main model"],
        "settings.visionDesc": [.zhCN: "用于 GOF/VPC 图像审计等多模态任务。单独指定一个支持视觉的模型（如 qwen-vl / gpt-4o / gemini-2.5-flash），即使主模型不支持识图，图像审计也能正常工作。", .en: "Used for GOF/VPC image audits and other multimodal tasks. Set a vision-capable model (e.g. qwen-vl / gpt-4o / gemini-2.5-flash) so image audits work even if your main model cannot see images."],
        "settings.visionURL": [.zhCN: "视觉 Base URL", .en: "Vision Base URL"],
        "settings.visionModelName": [.zhCN: "视觉模型名", .en: "Vision Model"],
        "settings.visionAPIKey": [.zhCN: "视觉 API Key", .en: "Vision API Key"],
        "settings.testConnection": [.zhCN: "测试连接", .en: "Test Connection"],
        "settings.remove": [.zhCN: "删除", .en: "Remove"],
        "settings.providerIcon": [.zhCN: "图标", .en: "Icon"],
        "settings.providerIconAuto": [.zhCN: "自动", .en: "Auto"],
        "settings.modelsFound": [.zhCN: "个模型可用", .en: " models available"],
        "settings.notTested": [.zhCN: "未测试", .en: "Not tested"],
        "settings.connected": [.zhCN: "已连接", .en: "Connected"],
        "settings.llm.pin": [.zhCN: "置顶 Provider", .en: "Pin provider to top"],
        "settings.llm.unpin": [.zhCN: "取消置顶 Provider", .en: "Unpin provider"],
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
        "settings.tools.viewersHint": [.zhCN: "AutoPMx 使用 macOS 内置 QuickLook 预览图片、PDF、DOCX、XLSX、PPTX、HTML。无需插件。", .en: "AutoPMx uses macOS built-in QuickLook for previewing images, PDF, DOCX, XLSX, PPTX, HTML. No plugins needed."],
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
        "auto.ivAnchorConfirmTitle": [.zhCN: "使用 IV 模型作为起始参数？", .en: "Use IV model as starting values?"],
        "auto.ivAnchorConfirmMessage": [.zhCN: "检测到当前项目已有 IV 最佳模型。是否以 run%@ 的参数作为全数据集建模的起始值？选择“否”将直接从全数据集建立新模型。", .en: "An IV anchor model was found. Use run%@ parameters as starting values for the full-dataset model? Choose No to start fresh from the full dataset."],
        "auto.ivAnchorUse": [.zhCN: "是，以 IV 模型起始", .en: "Yes, start from IV model"],
        "auto.ivAnchorSkip": [.zhCN: "否，直接全数据集开始", .en: "No, start from full dataset"],

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

        // AI Overlay (quick actions, sheets)
        "quick.autoModeling": [.zhCN: "自动建模", .en: "Auto Modeling"],
        "quick.individual": [.zhCN: "个体图", .en: "Individual"],
        "quick.modelCompare": [.zhCN: "模型比较", .en: "Model Compare"],
        "quick.gofPlots": [.zhCN: "GOF 诊断图", .en: "GOF Plots"],
        "quick.vpcCheck": [.zhCN: "VPC 预测检验", .en: "VPC Check"],
        "quick.individualDV": [.zhCN: "个体 DV-TIME", .en: "Individual DV-TIME"],
        "quick.pkExtract": [.zhCN: "PK 参数提取", .en: "PK Parameter Extraction"],
        "quick.scmCov": [.zhCN: "SCM 协变量筛选", .en: "SCM Covariate Screening"],
        "quick.etaScreen": [.zhCN: "ETA 协变量预筛选", .en: "ETA Covariate Screening"],
        "quick.title": [.zhCN: "快捷功能", .en: "Quick Actions"],
        "quick.busyHint": [.zhCN: "当前有任务正在运行，请等待完成或点击 STOP 停止后再操作", .en: "A task is currently running. Wait for it to finish or tap STOP first."],
        "benchmark.title": [.zhCN: "建模耗时统计", .en: "Modeling Time Benchmarks"],
        "benchmark.desc": [.zhCN: "自动记录每次 DuDu Auto 的耗时，包含 DuDu 思考、命令执行、Phase 1、Base Model 等待、Phase 2/SCM。Base Model 等待单独统计，不计入可对比总耗时。", .en: "Automatically records each DuDu Auto run: LLM thinking, process execution, Phase 1, Base Model wait, and Phase 2/SCM. Base Model wait is kept separate and excluded from the comparable total."],
        "benchmark.empty": [.zhCN: "还没有建模耗时记录。启动一次 DuDu Auto 后会自动出现在这里。", .en: "No modeling time records yet. Start DuDu Auto once and it will appear here automatically."],
        "benchmark.records": [.zhCN: "记录", .en: "Records"],
        "benchmark.dataset": [.zhCN: "数据集", .en: "Dataset"],
        "benchmark.llm": [.zhCN: "LLM", .en: "LLM"],
        "benchmark.startedAt": [.zhCN: "开始时间", .en: "Started"],
        "benchmark.phase1": [.zhCN: "Phase 1", .en: "Phase 1"],
        "benchmark.thinking": [.zhCN: "DuDu 思考", .en: "Thinking"],
        "benchmark.execution": [.zhCN: "执行", .en: "Execution"],
        "benchmark.baseWait": [.zhCN: "Base 等待", .en: "Base Wait"],
        "benchmark.phase2": [.zhCN: "Phase 2/SCM", .en: "Phase 2/SCM"],
        "benchmark.comparable": [.zhCN: "可对比总耗时", .en: "Comparable Total"],
        "benchmark.total": [.zhCN: "实际总耗时", .en: "Wall Total"],
        "benchmark.status": [.zhCN: "状态", .en: "Status"],
        "benchmark.clear": [.zhCN: "清空记录", .en: "Clear Records"],
        "benchmark.copyCSV": [.zhCN: "复制 CSV", .en: "Copy CSV"],
        "benchmark.avgRecords": [.zhCN: "记录数", .en: "Runs"],
        "benchmark.avgComparable": [.zhCN: "平均可对比耗时", .en: "Avg Comparable"],
        "benchmark.avgThinking": [.zhCN: "平均 DuDu 思考", .en: "Avg Thinking"],
        "benchmark.avgExecution": [.zhCN: "平均执行", .en: "Avg Execution"],
        "benchmark.statusCompleted": [.zhCN: "完成", .en: "Completed"],
        "benchmark.statusStopped": [.zhCN: "停止", .en: "Stopped"],
        "benchmark.statusFailed": [.zhCN: "失败", .en: "Failed"],
        "benchmark.statusPaused": [.zhCN: "暂停", .en: "Paused"],
        "benchmark.pausedAfterBase": [.zhCN: "Base Model 后暂停，等待后续手动操作", .en: "Paused after Base Model, awaiting manual follow-up"],
        "benchmark.scmCancelled": [.zhCN: "SCM 已取消", .en: "SCM cancelled"],
        "benchmark.scmFailed": [.zhCN: "SCM 运行失败", .en: "SCM failed"],
        "benchmark.scmNotStarted": [.zhCN: "SCM 未启动（已有任务在运行）", .en: "SCM did not start (another task is running)"],
        "benchmark.stopped": [.zhCN: "用户手动停止", .en: "Stopped by user"],
        "ai.placeholder": [.zhCN: "向 DuDu PMx 提问...", .en: "Ask DuDu PMx..."],
        "ai.autoModelingBusy": [.zhCN: "自动建模中，请勿切换项目", .en: "Auto modeling in progress — do not switch projects"],
        "noModel.cardTitle": [.zhCN: "当前还没有模型文件", .en: "No model files yet"],
        "noModel.cardBody": [.zhCN: "当前项目路径下没有 mod 文件，GOF / VPC / 个体 DV-TIME / SCM 等功能需要先有模型才能运行。", .en: "There are no .mod files in the current project. GOF / VPC / individual DV-TIME / SCM require a model first."],
        "noModel.buildCta": [.zhCN: "去自动建模", .en: "Build Model"],
        "noModel.chatHint": [.zhCN: "⚠️ 当前项目路径下还没有 mod 文件，GOF / VPC / 个体 DV-TIME / SCM 等功能需要先有模型才能运行。可以先点击右上角 DuDu 图标 → 自动建模，DuDu 会基于当前数据集为你构建模型。", .en: "⚠️ There are no .mod files in the current project yet, so GOF / VPC / individual DV-TIME / SCM cannot run. Start DuDu Auto Modeling (DuDu icon → Auto) and DuDu will build a model from the current dataset first."],
        "help.askDuDuTitle": [.zhCN: "对这份帮助文档有疑问？直接问 DuDu", .en: "Questions about this guide? Ask DuDu"],
        "help.askDuDuCta": [.zhCN: "问 DuDu", .en: "Ask DuDu"],
        "help.contextSystemIntro": [.zhCN: "你正在为用户提供 AutoPMx（DuDu PMx）产品的使用帮助。以下是产品帮助文档的内容，请优先依据文档准确回答用户的问题；如果文档中没有涉及，请如实说明并给出合理建议。", .en: "You are helping an AutoPMx (DuDu PMx) user with product support. Below is the product's Help documentation — answer the user's questions accurately based on it; if a topic is not covered, say so honestly and give a reasonable suggestion."],
        "help.contextReadyHint": [.zhCN: "📖 帮助文档已载入 DuDu 上下文，你现在可以直接提问（比如：如何开始自动建模？SCM 是什么？）。", .en: "📖 The Help document has been loaded into DuDu's context. You can ask questions now (e.g. How do I start auto modeling? What is SCM?)."],
        "help.q1": [.zhCN: "如何开始自动建模？", .en: "How to start Auto Modeling?"],
        "help.q2": [.zhCN: "SCM 协变量筛选是什么？", .en: "What is SCM screening?"],
        "help.q3": [.zhCN: "如何解读 GOF 图？", .en: "How to read GOF plots?"],
        "scm.busySwitchWarning": [.zhCN: "SCM 运行中，请勿切换项目", .en: "SCM screening in progress — do not switch projects"],
        "bootstrap.busySwitchWarning": [.zhCN: "Bootstrap 运行中，请勿切换项目", .en: "Bootstrap in progress — do not switch projects"],
        "auto.sheetTitle": [.zhCN: "DuDu Auto — 自动建模", .en: "DuDu Auto — Automated Modeling"],
        "auto.datasetLabel": [.zhCN: "建模数据集", .en: "Modeling Dataset"],
        "auto.dataFileLabel": [.zhCN: "数据集", .en: "Dataset"],
        "auto.unspecified": [.zhCN: "（不指定）", .en: "(Unspecified)"],
        "auto.singleDataset": [.zhCN: "当前项目只有一个数据集：%@", .en: "Current project has only one dataset: %@"],
        "auto.guidanceLabel": [.zhCN: "建模指导（可选）", .en: "Modeling Guidance (optional)"],
        "auto.startSCM": [.zhCN: "开始 SCM", .en: "Start SCM"],
        "compare.title": [.zhCN: "模型比较", .en: "Model Compare"],
        "compare.subtitle": [.zhCN: "选择两个已成功运行的模型进行比较审计。", .en: "Select two successfully run models to compare."],
        "scm.sheetTitle": [.zhCN: "PsN SCM 协变量筛选", .en: "PsN SCM Covariate Screening"],
        "scm.baseModel": [.zhCN: "基础模型", .en: "Base Model"],
        "scm.modelFile": [.zhCN: "模型文件", .en: "Model File"],
        "scm.dataFile": [.zhCN: "数据集文件", .en: "Dataset File"],
        "scm.candidates": [.zhCN: "候选协变量（默认全部考察，可取消不考察的）", .en: "Candidate covariates (all examined by default; uncheck to exclude)"],
        "scm.covWT": [.zhCN: "WT（体重，连续）", .en: "WT (weight, continuous)"],
        "scm.covAGE": [.zhCN: "AGE（年龄，连续）", .en: "AGE (age, continuous)"],
        "scm.covSEX": [.zhCN: "SEX（性别，分类）", .en: "SEX (sex, categorical)"],
        "scm.covSTUDY": [.zhCN: "STUDY（研究，分类）", .en: "STUDY (study, categorical)"],
        "scm.covNote": [.zhCN: "仅数据集与模型中实际存在的协变量会进入 SCM 配置；取消勾选即从候选中剔除。", .en: "Only covariates present in both dataset and model enter SCM; unchecking excludes them."],
        "scm.threshold": [.zhCN: "假设检验阈值", .en: "Hypothesis Test Thresholds"],
        "scm.forwardP": [.zhCN: "前向纳入 p", .en: "Forward inclusion p"],
        "scm.backwardP": [.zhCN: "逆向剔除 p", .en: "Backward deletion p"],
        "scm.backwardRange": [.zhCN: "逆向剔除 p 值不能大于前向纳入 p 值", .en: "Backward deletion p must not exceed forward inclusion p"],
        "scm.runNote": [.zhCN: "AI 将根据选定的模型文件和数据集自动撰写 runCONCOV{模型序号}.scm，然后在 SCM_run{模型序号}/ 子目录中运行 PsN SCM。", .en: "AI will auto-write runCONCOV{N}.scm from the selected model and dataset, then run PsN SCM under SCM_run{N}/."],
        "scm.runEtaScreen": [.zhCN: "先运行 ETA 预筛选", .en: "Run ETA Screening First"],
        "scm.runEtaHint": [.zhCN: "在 SCM 前生成 ETA vs 协变量图和统计结论，由 DuDu 判断是否继续考察。", .en: "Generate ETA vs covariate plots and statistics before SCM; DuDu will recommend which covariates to keep."],
        "scm.etaSuggestionTitle": [.zhCN: "ETA 预筛选建议", .en: "ETA Screening Suggestion"],
        "scm.etaSuggestionHint": [.zhCN: "下方协变量已按建议预选；你可以调整后再开始 SCM。", .en: "Covariates below are preselected from the ETA screening; adjust them before starting SCM."],
        "scm.etaApplySuggestion": [.zhCN: "采用建议", .en: "Use Suggestion"],
        "scm.etaResetAll": [.zhCN: "改回全部考察", .en: "Examine All"],
        "scm.finalConfirmTitle": [.zhCN: "SCM Replication 完成", .en: "SCM Replication Complete"],
        "scm.finalConfirmBody": [.zhCN: "是否以 run%@ 作为最终模型，继续执行验证、Bootstrap 和最终报告输出？", .en: "Use run%@ as the final model and continue with validation, Bootstrap, and final report output?"],
        "scm.finalConfirmContinue": [.zhCN: "继续验证并生成报告", .en: "Continue Validation & Report"],
        "scm.finalConfirmLater": [.zhCN: "暂不继续", .en: "Not Now"],
        "ctx.usagePanel": [.zhCN: "上下文使用情况", .en: "Context Usage"],
        "ctx.windowLimit": [.zhCN: "上下文窗口上限", .en: "Context Window Limit"],
        "ctx.ruleContext": [.zhCN: "规则/知识上下文", .en: "Rules/Knowledge Context"],
        "ctx.requestPrompt": [.zhCN: "本次请求 prompt", .en: "This Request Prompt"],
        "ctx.output": [.zhCN: "本次输出", .en: "This Output"],
        "ctx.totalInput": [.zhCN: "累计输入", .en: "Total Input"],
        "ctx.totalOutput": [.zhCN: "累计输出", .en: "Total Output"],
        "ctx.cacheRead": [.zhCN: "缓存命中", .en: "Cache Read"],
        "ctx.cacheWrite": [.zhCN: "缓存写入", .en: "Cache Write"],
        "ctx.cacheHitRate": [.zhCN: "缓存命中率", .en: "Cache Hit Rate"],
        "ctx.windowOccupied": [.zhCN: "当前占用窗口约 %d%%", .en: "Current window usage ~ %d%%"],
        "ctx.noUsage": [.zhCN: "当前 LLM 未返回 usage，占比按规则上下文估算。", .en: "Current LLM returned no usage; ratio estimated from rule context."],

        // AI Overlay — detected actions / sheets (cont.)
        "detect.eda": [.zhCN: "EDA 数据分析", .en: "EDA Analysis"],
        "detect.ct": [.zhCN: "C-T 浓度时间曲线", .en: "C-T Concentration-Time Curves"],
        "phase1.complete": [.zhCN: "🏆 Phase 1 基础模型筛选完成", .en: "🏆 Phase 1 Base Model Selection Complete"],
        "phase1.confirmMsg": [.zhCN: "是否以 run%@ 作为最终基础模型，继续 Phase 2 协变量筛选？", .en: "Use run %@ as the final base model and proceed to Phase 2 covariate screening?"],
        "phase1.cancelLater": [.zhCN: "取消，稍后手动启动", .en: "Cancel, start manually later"],
        "phase1.confirmStart": [.zhCN: "✅ 确认，开始协变量筛选", .en: "✅ Confirm, start covariate screening"],
        "pick.individual": [.zhCN: "个体拟合图", .en: "Individual Fit"],
        "picker.model": [.zhCN: "模型", .en: "Model"],
        "bootstrap.samplesTitle": [.zhCN: "Bootstrap 抽样次数", .en: "Bootstrap Samples"],
        "bootstrap.samplesHint": [.zhCN: "默认 500 次（Medium）。更高次数更稳定，但运行时间更长。", .en: "Default 500 (Medium). More samples are more stable but take longer."],
        "bootstrap.start": [.zhCN: "开始 Bootstrap", .en: "Start Bootstrap"],
        "picker.noModels": [.zhCN: "当前项目没有模型", .en: "No models in current project"],        "picker.current": [.zhCN: "当前", .en: "Current"],

        // Delete
        "delete.title": [.zhCN: "移动到废纸篓？", .en: "Move File to Trash?"],
        "delete.message": [.zhCN: "", .en: ""],
        "delete.cancel": [.zhCN: "取消", .en: "Cancel"],
        "delete.confirm": [.zhCN: "移到废纸篓", .en: "Move to Trash"],

        // Project sheet
        "project.createBlank": [.zhCN: "创建空白项目", .en: "Create Blank Project"],
        "project.createBlankMsg": [.zhCN: "创建干净的数据项目，包含规则与诊断脚本，但不含 run*.mod 文件。请随后导入你自己的建模数据集（如 NM_dat.csv）", .en: "Create a clean data-only project with rules and diagnostic scripts, but no run*.mod files. Import your own modeling dataset afterward (e.g. NM_dat.csv)"],
        "project.createFromRun": [.zhCN: "从 Run 创建项目", .en: "Create Project From Run"],
        "project.create": [.zhCN: "创建", .en: "Create"],

        // Terminal
        "terminal.ready": [.zhCN: "AutoPMx 终端就绪。\n", .en: "AutoPMx terminal ready.\n"],

        // About
        "about.title": [.zhCN: "AutoPMx", .en: "AutoPMx"],
        "about.subtitle": [.zhCN: "DuDu PMx 药代建模工作台", .en: "DuDu PMx Pharmacometrics Workbench"],
        "about.description": [.zhCN: "macOS 原生药代动力学建模式工作台。\n集成 NONMEM/PsN 运行器、AI 辅助模型构建、\n以及由本地或云端 LLM 驱动的诊断可视化。", .en: "macOS native pharmacometrics modeling workbench.\nIntegrated NONMEM/PsN runner, AI-assisted model building,\nand diagnostic visualization powered by local or cloud LLMs."],
        "about.providers": [.zhCN: "支持的 LLM Provider\nOpenAI-compatible · Anthropic Claude · Google Gemini\nMLX · LM Studio · Ollama · vLLM · 自定义 API", .en: "LLM Provider Support\nOpenAI-compatible · Anthropic Claude · Google Gemini\nMLX · LM Studio · Ollama · vLLM · Custom APIs"],
        "about.built": [.zhCN: "基于 SwiftUI 构建 · macOS 13+", .en: "Built with SwiftUI · macOS 13+"],

        // Workbench overview
        "workbench.overview": [
            .zhCN: """
            AutoPMx 原生工作台

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
            AutoPMx native workbench

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

        "settings.aiSkillTitle": [.zhCN: "AI 建模技能", .en: "AI Modeling Skills"],
        "settings.aiSkillDesc": [.zhCN: "DuDu 在当前项目中自我凝练的建模经验，每次建模会自动注入到对话中。记忆保存在项目目录的 .autopmx_ppk_skill.json。", .en: "Skills DuDu has distilled in this project; auto-injected into every modeling prompt. Stored in <project>/.autopmx_ppk_skill.json."],
        "settings.aiSkillLessons": [.zhCN: "建模教训", .en: "Lessons"],
        "settings.aiSkillSuccesses": [.zhCN: "成功套路", .en: "Success Patterns"],
        "settings.aiSkillInsights": [.zhCN: "参数洞察", .en: "Parameter Insights"],
        "settings.aiSkillScmErrors": [.zhCN: "SCM 错误模式", .en: "SCM Error Patterns"],
        "settings.aiSkillUpdated": [.zhCN: "最近更新", .en: "Last updated"],
        "settings.aiSkillClear": [.zhCN: "清空全部技能", .en: "Clear All Skills"],
        "settings.aiSkillClearConfirm": [.zhCN: "确定要清空当前项目的全部 AI 技能记忆吗？此操作不可撤销。", .en: "Clear all AI skill memory for this project? This cannot be undone."],
        "settings.aiSkillEmpty": [.zhCN: "该项目暂无 AI 凝练的技能。运行建模流程后，DuDu 会自动积累经验。", .en: "No AI-learned skills in this project yet. Run a modeling workflow and DuDu will accumulate experience automatically."],
        "settings.aiSkillExport": [.zhCN: "导出技能", .en: "Export Skills"],
        "settings.aiSkillImport": [.zhCN: "导入技能", .en: "Import Skills"],
        "settings.aiSkillExportSuccess": [.zhCN: "技能已导出到本地。", .en: "Skills exported successfully."],
        "settings.aiSkillExportFailed": [.zhCN: "技能导出失败：%@", .en: "Skill export failed: %@"],
        "settings.aiSkillImportSuccess": [.zhCN: "技能已导入并合并。", .en: "Skills imported and merged."],
        "settings.aiSkillImportFailed": [.zhCN: "技能导入失败：%@", .en: "Skill import failed: %@"],
        "problem": [.zhCN: "问题", .en: "Problem"],
        "solution": [.zhCN: "解决", .en: "Solution"],
        "context": [.zhCN: "场景", .en: "Context"],
        "action": [.zhCN: "动作", .en: "Action"],
        "result": [.zhCN: "结果", .en: "Result"],
        "match": [.zhCN: "匹配", .en: "Match"],
        "fix": [.zhCN: "修复", .en: "Fix"],

        // Tools
        "settings.tools.title": [.zhCN: "工具与路径", .en: "Tools & Paths"],
        "settings.tools.r": [.zhCN: "R 环境 (Rscript)", .en: "R Environment (Rscript)"],
        "settings.tools.rHint": [.zhCN: "Rscript 路径，用于运行 R 诊断和绘图。推荐 R 4.x 并安装 xpose、ggplot2、dplyr。", .en: "Path to Rscript for running R-based diagnostics and plotting. R 4.x with xpose, ggplot2, and dplyr is recommended."],
        "settings.tools.fileViewers": [.zhCN: "文件查看器", .en: "File Viewers"],
        "settings.tools.dataFileDesc": [.zhCN: "创建新项目时的默认 CSV 文件名。如需按项目设置数据集，请在侧边栏右键 CSV → 设为建模数据集。", .en: "Default CSV filename when creating new projects. To set dataset per-project, right-click a CSV in the sidebar → Set as Modeling Dataset."],
        "units.confirmTitle": [.zhCN: "确认单位信息", .en: "Confirm Dataset Units"],
        "units.confirmMessage": [.zhCN: "数据集：%@\nDose: %@\nAMT: %@\nConc.: %@\nTime: %@\n\n请再次确认以上单位无误后再开始。", .en: "Dataset: %@\nDose: %@\nAMT: %@\nConc.: %@\nTime: %@\n\nPlease confirm the units above before starting."],
        "units.confirmStart": [.zhCN: "单位无误，开始建模", .en: "Units Correct, Start Modeling"],
        "units.confirmCancel": [.zhCN: "返回检查", .en: "Go Back"],

        // Rules
        "settings.rules.title": [.zhCN: "规则与知识来源", .en: "Rule & Knowledge Sources"],
        "settings.rules.builtInTitle": [.zhCN: "系统内置规则（随软件打包）", .en: "Built-in Rules (bundled with the app)"],
        "settings.rules.builtInDesc": [.zhCN: "这些规则由 AutoPMx 随软件一起发布，自动加载到每个项目，绝不从任何项目路径读取。", .en: "These rules ship with AutoPMx and are auto-loaded into every project. They are never read from any project path."],
        "settings.rules.userTitle": [.zhCN: "我的规则（上传）", .en: "Your Own Rules (upload)"],
        "settings.rules.userDesc": [.zhCN: "上传你自己编写的规则文件（.json / .md）。它们以你选择的绝对路径加载，属于你自己的规则，而不是工作区的已知来源文件。", .en: "Upload your own rule files (.json / .md). They load from the absolute path you choose — your rules, not workspace-known files."],
        "settings.rules.upload": [.zhCN: "上传规则", .en: "Upload Rule"],
        "settings.rules.remove": [.zhCN: "移除", .en: "Remove"],
        "settings.rules.sourceFilesDesc": [.zhCN: "仅允许系统内置规则与你上传的规则。工作区/项目路径下的已知来源文件不会被加载进规则库。", .en: "Only built-in rules and your uploaded rules are allowed. Workspace/project-known files are NOT loaded into the rule library."],
        "settings.rules.knownFilesDesc": [.zhCN: "工作区中存在的文件，可以添加为来源文件。点击添加。", .en: "These files exist in your workspace and can be added as sources. Click to append."],
        "settings.rules.libraryOverview": [.zhCN: "规则库分类盘点", .en: "Rule Library Categories"],
        "settings.rules.files": [.zhCN: "规则文件", .en: "Rule Files"],
        "settings.rules.total": [.zhCN: "规则总数", .en: "Total Rules"],
        "settings.rules.sizeKB": [.zhCN: "总大小 KB", .en: "Total KB"],
        "settings.rules.category.@Regulatory": [.zhCN: "监管要求", .en: "Regulatory"],
        "settings.rules.category.@BioPhys": [.zhCN: "生物物理", .en: "Biophysical"],
        "settings.rules.category.@ModelingTechniques": [.zhCN: "建模方法", .en: "Modeling Techniques"],
        "settings.rules.category.@DataStandards": [.zhCN: "数据标准", .en: "Data Standards"],
        "settings.rules.category.@ModelEvaluation": [.zhCN: "模型评估", .en: "Model Evaluation"],
        "settings.rules.category.@CovariateAnalysis": [.zhCN: "协变量分析", .en: "Covariate Analysis"],
        "settings.rules.category.@mAb_EarlyClinical": [.zhCN: "mAb 早期临床", .en: "mAb Early Clinical"],
        "settings.rules.category.@Reporting": [.zhCN: "报告规范", .en: "Reporting"],

        // Tokens
        "tokens.title": [.zhCN: "Tokens 消耗", .en: "Tokens Usage"],
        "tokens.contextWindow": [.zhCN: "上下文窗口上限 (Context Window)", .en: "Context Window Limit"],
        "tokens.contextWindowDesc": [.zhCN: "设置 LLM 上下文窗口的 token 上限，用于计算上方圆环的占用比例。Ollama 等本地模型可拉到 50 万以上，按需选择档位。", .en: "Set the token upper bound of the LLM context window; it drives the usage ratio shown by the ring in the top-right overlay. Local models like Ollama can reach 500K+, so pick a tier as needed."],
        "tokens.currentLimit": [.zhCN: "当前上限", .en: "Current limit"],
        "tokens.stats": [.zhCN: "累计用量统计", .en: "Usage Statistics"],
        "tokens.requests": [.zhCN: "请求次数", .en: "Requests"],
        "tokens.input": [.zhCN: "输入 Tokens", .en: "Input Tokens"],
        "tokens.output": [.zhCN: "输出 Tokens", .en: "Output Tokens"],
        "tokens.total": [.zhCN: "合计 Tokens", .en: "Total Tokens"],
        "tokens.dailyChart": [.zhCN: "每日 Tokens 消耗", .en: "Daily Token Consumption"],
        "tokens.monthSummary": [.zhCN: "本月共 %d 次请求，消耗 %@ tokens（蓝=输入，绿=输出）。", .en: "This month: %d requests, %@ tokens (blue=input, green=output)."],
        "tokens.weekSummary": [.zhCN: "本周共 %d 次请求，消耗 %@ tokens（蓝=输入，绿=输出）。", .en: "This week: %d requests, %@ tokens (blue=input, green=output)."],
        "tokens.empty": [.zhCN: "还没有用量记录。开始与 DuDu 对话或建模后，这里会按月统计你的 tokens 消耗。", .en: "No usage records yet. Start chatting with DuDu or run modeling, and your tokens will be tracked here by month."],
        "tokens.perProvider": [.zhCN: "各 LLM 用量对比（含速度）", .en: "Per-Provider Usage & Speed"],


    // Memory monitor (Tokens pane)
    "tokens.memory": [.zhCN: "内存占用 (Memory)", .en: "Memory Usage"],
    "tokens.memoryDesc": [.zhCN: "本地 LLM 服务内存过高时会被系统强制终止，即使上下文 token 远未达到上限。建议总内存占用保持在 80% 以下。", .en: "If the local LLM service uses too much memory, the system may terminate it even when the context window is far from its limit. Keep total memory usage below 80%."],
    "tokens.memTotal": [.zhCN: "总内存", .en: "Total"],
    "tokens.memUsed": [.zhCN: "已用", .en: "Used"],
    "tokens.memAvailable": [.zhCN: "可用", .en: "Available"],
    "tokens.memApp": [.zhCN: "本 App", .en: "This App"],
    "tokens.memLLM": [.zhCN: "本地 LLM 服务", .en: "Local LLM Service"],
    "tokens.memLLMNone": [.zhCN: "未检测到本地 LLM 进程", .en: "No local LLM process detected"],
    "tokens.memWarning": [.zhCN: "⚠️ 内存占用过高（%.0f%%），本地 LLM 可能被系统终止。建议释放内存或改用更小的量化模型。", .en: "⚠️ Memory usage is high (%.0f%%). The local LLM may be terminated by the system. Free up memory or switch to a smaller quantized model."],
    "tokens.memPressure": [.zhCN: "内存压力", .en: "Memory Pressure"],
    "tokens.memLow": [.zhCN: "低", .en: "Low"],
    "tokens.memMed": [.zhCN: "中", .en: "Medium"],
    "tokens.memHigh": [.zhCN: "高", .en: "High"],

    // Token chart range
    "tokens.week": [.zhCN: "按周", .en: "Week"],
    "tokens.month": [.zhCN: "按月", .en: "Month"],

    // DuDu Personality / Chat Style
    "dudu.chatStyle": [.zhCN: "DuDu 对话风格", .en: "DuDu Chat Style"],
    "dudu.chatStyleDesc": [.zhCN: "选择你喜欢的对话风格，DuDu 会根据你的偏好调整语气和回答方式。", .en: "Choose your preferred chat style. DuDu will adjust its tone and responses accordingly."],
    "dudu.customPrompt": [.zhCN: "自定义人设 Prompt", .en: "Custom Persona Prompt"],
    "dudu.customPromptDesc": [.zhCN: "在这里写你想让 DuDu 扮演的角色、说话方式、口头禅等。这段内容会直接注入到 LLM 的 System Prompt 中。", .en: "Write the persona, speaking style, and catchphrases you want DuDu to adopt. This will be injected into the LLM System Prompt."],
    "dudu.customPromptPlaceholder": [.zhCN: "例如：你是一个说话喜欢用「咱就是说」开头的东北老铁版药代顾问，专业但不失亲切，喜欢用大碴子味的比喻来解释复杂概念。", .en: "E.g.: You are a down-to-earth pharmacometrics consultant who speaks with plain language and relatable metaphors to explain complex concepts."],
    "dudu.learnStyle": [.zhCN: "学习你的说话风格", .en: "Learn Your Speaking Style"],
    "dudu.learnStyleDesc": [.zhCN: "开启后，DuDu 会收集你的聊天消息。可在收集一定数量后点击「生成风格档案」，由 LLM 为你生成一份结构化的说话风格 skill 文档，注入到 DuDu 的 System Prompt 中。", .en: "When enabled, DuDu collects your chat messages. Once enough are collected, click 'Generate Style Profile' to create a structured speaking-style skill document via LLM, injected into DuDu's System Prompt."],
    "dudu.learnStyleToggle": [.zhCN: "启用风格学习", .en: "Enable Style Learning"],
    "dudu.collectedMessages": [.zhCN: "已收集 %d 条消息", .en: "Collected %d messages"],
    "dudu.generating": [.zhCN: "正在生成...", .en: "Generating..."],
    "dudu.generateProfile": [.zhCN: "生成风格档案", .en: "Generate Style Profile"],
    "dudu.minMessages": [.zhCN: "至少需要 5 条消息", .en: "At least 5 messages needed"],
    "dudu.styleProfile": [.zhCN: "风格档案", .en: "Style Profile"],
    "dudu.generatedByLLM": [.zhCN: "由 LLM 生成", .en: "Generated by LLM"],
    "dudu.clearAll": [.zhCN: "清空全部记录", .en: "Clear All Records"],
    "dudu.regenerate": [.zhCN: "重新生成", .en: "Regenerate"],
    "dudu.learnStyleHint": [.zhCN: "开启后，每当你和 DuDu 聊天，消息会被收集。积累一定量后，点击「生成风格档案」，LLM 会分析你的说话习惯并生成一份 skill 文档，之后 DuDu 的回复就会自动匹配你的风格～", .en: "When enabled, your chat messages with DuDu will be collected. Once you have enough, click 'Generate Style Profile' — LLM will analyze your speaking habits and generate a skill document, so DuDu's replies automatically match your style."],

    // Compartment Decision
    "compDecision.title": [.zhCN: "模型决策", .en: "Model Decision"],
    "compDecision.acceptLower": [.zhCN: "接受低维模型（推荐）", .en: "Accept Lower Model (Recommended)"],
    "compDecision.acceptCurrent": [.zhCN: "接受当前模型", .en: "Accept Current Model"],
    "compDecision.desc": [.zhCN: "接受低维模型将选择当前最优的 2-comp 模型进入 Phase 2。接受当前模型则保留 3-comp 直接进入 Phase 2。", .en: "Accepting the lower model selects the best 2-comp model for Phase 2. Accepting the current model keeps the 3-comp model and proceeds directly to Phase 2."],

    // Base Model Confirm
    "baseModel.startSCM": [.zhCN: "协变量筛选(SCM)", .en: "Covariate Screening (SCM)"],
    "baseModel.skipSCM": [.zhCN: "跳过SCM,直接AI验证", .en: "Skip SCM, Direct AI Validation"],

    // SCM Report
    "scm.reportHeader": [.zhCN: "━━━ SCM 协变量筛选结果 ━━━", .en: "━━━ SCM Covariate Screening Results ━━━"],
    "scm.reportBaseStructure": [.zhCN: "结构模型: run%@ | SCM 最终模型: run%@", .en: "Base model: run%@ | SCM final: run%@"],
    "scm.reportAvailableCov": [.zhCN: "可用协变量: %@", .en: "Available covariates: %@"],
    "scm.noCovFound": [.zhCN: "• SCM 未发现显著协变量，最终模型与结构模型一致。", .en: "• SCM found no significant covariates; final model matches base structure."],
    "scm.covFound": [.zhCN: "• SCM 纳入协变量 (%d): %@", .en: "• SCM included covariates (%d): %@"],
    "scm.wtIncluded": [.zhCN: "• WT 异速缩放（0.75/1.0 FIX）已纳入。", .en: "• WT allometric scaling (0.75/1.0 FIX) included."],
    "scm.aiHeader": [.zhCN: "── AI 独立 SCM 验证 ──", .en: "── Independent AI SCM Verification ──"],
    "scm.diagGenerated": [.zhCN: "SCM 诊断图已生成到 Figures/ 目录。", .en: "SCM diagnostic plots generated in Figures/ directory."],
    "scm.reportFooter": [.zhCN: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", .en: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"],
    "scm.llmNotConfigured": [.zhCN: "  ⚠️ 未配置 LLM，无法进行验证。", .en: "  ⚠️ LLM not configured, cannot verify."],
    "scm.verificationFailed": [.zhCN: "  ⚠️ 验证失败: %@", .en: "  ⚠️ Verification failed: %@"],
    "scm.duduModelEmpty": [.zhCN: "  ⚠️ DuDu 最终模型为空，无法比较。", .en: "  ⚠️ DuDu final model is empty, cannot compare."],

    // SCM vs DuDu Comparison
    "scm.compareHeader": [.zhCN: "━━━ SCM vs DuDu 协变量结果对比 ━━━", .en: "━━━ SCM vs DuDu Covariate Comparison ━━━"],
    "scm.compareMatch": [.zhCN: "✅ DuDu 与 SCM 选入的协变量完全一致。", .en: "✅ DuDu and SCM selected identical covariates."],
    "scm.compareOnlyDuDu": [.zhCN: "• 仅 DuDu 纳入: %@", .en: "• Only DuDu included: %@"],
    "scm.compareOnlySCM": [.zhCN: "• 仅 SCM 纳入: %@", .en: "• Only SCM included: %@"],
    "scm.compareNone": [.zhCN: "两者均未发现显著协变量。", .en: "Neither found significant covariates."],
    "scm.compareWTBothIn": [.zhCN: "✅ WT 异速缩放：均纳入", .en: "✅ WT scaling: both included"],
    "scm.compareWTBothOut": [.zhCN: "✅ WT 异速缩放：均未纳入", .en: "✅ WT scaling: both excluded"],
    "scm.compareWTDuDuIn": [.zhCN: "DuDu纳入", .en: "DuDu included"],
    "scm.compareWTDuDuOut": [.zhCN: "DuDu未纳入", .en: "DuDu not included"],
    "scm.compareWTSCMIn": [.zhCN: "SCM纳入", .en: "SCM included"],
    "scm.compareWTSCMOut": [.zhCN: "SCM未纳入", .en: "SCM not included"],
    "scm.compareWTWarning": [.zhCN: "⚠️ WT 异速缩放：%@ vs %@", .en: "⚠️ WT scaling: %@ vs %@"],
    "scm.compareFooter": [.zhCN: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", .en: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"],
    "scm.modelReadFailed": [.zhCN: "SCM 结果验证：无法读取模型文件。", .en: "SCM verification: unable to read model file."],
    "scm.replicateHeader": [.zhCN: "🧪 DuDu 正在按 SCM 的前向纳入 / 逆向剔除流程在项目路径下复现模型...", .en: "🧪 DuDu is now replicating SCM's forward inclusion / backward elimination process in the project..."],
    "scm.replicateNoCov": [.zhCN: "SCM 最终模型未纳入任何协变量，DuDu 无需复现中间步骤，直接与基础模型比较即可。", .en: "SCM's final model includes no covariates, so DuDu doesn't need to replicate intermediate steps — comparing directly with the base model."],
    "scm.forwardHeader": [.zhCN: "━━━ 前向纳入复现（Forward Inclusion）━━━", .en: "━━━ Forward Inclusion Replication ━━━"],
    "scm.backwardHeader": [.zhCN: "━━━ 逆向剔除复现（Backward Elimination）━━━", .en: "━━━ Backward Elimination Replication ━━━"],
    "scm.replicateForward": [.zhCN: "▶️ 前向纳入第 %d 步：写入 run%@.mod（协变量：%@）", .en: "▶️ Forward step %d: writing run%@.mod (covariates: %@)"],
    "scm.replicateBackward": [.zhCN: "◀️ 逆向剔除第 %d 步：写入 run%@.mod（剔除：%@）", .en: "◀️ Backward step %d: writing run%@.mod (removing: %@)"],
    "scm.replicateRunDone": [.zhCN: "✅ run%@ 运行完成（OFV = %@）", .en: "✅ run%@ finished (OFV = %@)"],
    "scm.replicateFinal": [.zhCN: "🏁 SCM 复现完成：DuDu 最终模型 run%@ vs SCM final model", .en: "🏁 Replication complete: DuDu final run%@ vs SCM final model"],
    "scm.replicateFailed": [.zhCN: "❌ SCM 复现验证失败：%@", .en: "❌ SCM replication verification failed: %@"],
    "scm.replicateBaseRun": [.zhCN: "基础模型：run%@", .en: "Base model: run%@"],
    "scm.replicateSequence": [.zhCN: "SCM 前向纳入顺序：%@｜逆向剔除：%@", .en: "SCM forward inclusion order: %@ ｜ Backward elimination: %@"],
    "scm.cancelled": [.zhCN: "🛑 SCM 已被你停止。", .en: "🛑 SCM stopped by you."],
    "scm.noCandidatesSelected": [.zhCN: "⚠️ 你没有勾选任何协变量，SCM 已取消。请至少选择一个要考察的协变量后再试。", .en: "⚠️ No covariates were selected, so SCM was cancelled. Please select at least one covariate to examine and try again."],
    "scm.replicateCovInBase": [.zhCN: "ℹ️ SCM final 模型里的协变量（%@）在基础模型中已经存在，SCM 本轮没有新增协变量。DuDu 直接对比基础模型与 SCM final 模型。", .en: "ℹ️ The covariates in SCM's final model (%@) already exist in the base model, so SCM added no new covariates this round. DuDu is comparing the base model with SCM's final model directly."],
    "scm.forwardChat": [.zhCN: "▶️ 前向纳入第 %d 步：写入 run%@.mod，新增 %@", .en: "▶️ Forward step %d: writing run%@.mod, adding %@"],
    "scm.backwardChat": [.zhCN: "◀️ 逆向剔除第 %d 步：写入 run%@.mod，剔除 %@", .en: "◀️ Backward step %d: writing run%@.mod, removing %@"],
    "scm.relationDesc": [.zhCN: "在 %@ 上纳入 %@", .en: "%@ via %@"],
    "scm.relationJoin": [.zhCN: "；", .en: ", "],
    "scm.summaryHeader": [.zhCN: "━━━ SCM 最终模型评估 ━━━", .en: "━━━ SCM Final Model Summary ━━━"],
    "scm.summaryNone": [.zhCN: "最终模型未纳入协变量", .en: "The final model includes no covariates"],
    "scm.summaryIncluded": [.zhCN: "最终模型纳入协变量：%@", .en: "Final model covariates: %@"],
    "scm.summaryOfvAic": [.zhCN: "相对基础模型：ΔOFV %@，ΔAIC %@（基础 OFV %@ → 最终 OFV %@）", .en: "vs base model: ΔOFV %@, ΔAIC %@ (base OFV %@ → final OFV %@)"],
        "scm.popupTitle": [.zhCN: "SCM 协变量筛选", .en: "SCM Screening"],
        "bootstrap.popupTitle": [.zhCN: "Bootstrap 重抽样", .en: "Bootstrap Resampling"],
    "scm.stepPreparing": [.zhCN: "准备 SCM 运行环境...", .en: "Preparing SCM run..."],
    "scm.stepConfig": [.zhCN: "AI 正在生成 SCM 配置...", .en: "AI is writing the SCM config..."],
    "scm.stepRunning": [.zhCN: "PsN 正在运行 SCM 筛选...", .en: "PsN is running SCM screening..."],
    "scm.configReady": [.zhCN: "✅ %@ 配置已生成：%@", .en: "✅ %@ config ready: %@"],
    "scm.runningNotice": [.zhCN: "🔬 正在运行 PsN SCM 协变量筛选（候选模型较多时这一步可能较慢，可随时点 STOP 停止）...", .en: "🔬 PsN SCM covariate screening is running (can be slow with many candidate models — STOP is available anytime)..."],
    "scm.replicatePlan": [.zhCN: "📋 SCM 复现计划：前向纳入 %@；逆向剔除 %@；共 %d 步", .en: "📋 SCM replication plan: forward add %@; backward remove %@; %d steps total"],
    "scm.stepDone": [.zhCN: "✅ run%@.mod 跑完，OFV = %@", .en: "✅ run%@.mod finished, OFV = %@"],

    // Personality profiles
    "personality.cute.title": [.zhCN: "嘟嘟本嘟", .en: "Cute DuDu"],
    "personality.cute.desc": [.zhCN: "鸭鸭驾到，用可爱的语气回答所有问题，适合心情好的时候～", .en: "Adorable DuDu answers every question in a cute tone — perfect for when you need a mood boost."],
    "personality.cute.welcome": [.zhCN: "呱呱～ 我是 DuDu PMx，一只超爱药代动力学的小鸭子 🦆💊！点击 \"DuDu Auto\" 我可以帮你自动建模哦，或者在下面戳我提问～ 一起探索 PopPK 的奇妙世界吧！", .en: "Quack～ I'm DuDu PMx, a duckling who loves pharmacokinetics 🦆💊! Click \"DuDu Auto\" and I'll help you with automated modeling, or tap me below to ask questions. Let's explore the wonderful world of PopPK together!"],
    "personality.concise.title": [.zhCN: "极简高效", .en: "Concise & Efficient"],
    "personality.concise.desc": [.zhCN: "直奔主题，只给干货，像命令行一样高效。", .en: "Straight to the point, no fluff — efficient like a command line."],
    "personality.concise.welcome": [.zhCN: "DuDu PMx 已就绪。⚡ 高效模式：直接说需求，我会用最短的路径给你结果。自动建模、模型评估、诊断解读，随时可用。", .en: "DuDu PMx ready. ⚡ Efficient mode: just tell me what you need, and I'll get you results in the shortest path. Auto modeling, evaluation, diagnostics — all available."],
    "personality.expert.title": [.zhCN: "专业学者", .en: "Expert Scholar"],
    "personality.expert.desc": [.zhCN: "严谨专业的学术风格，引用文献和数据，适合正式场景。", .en: "Rigorous academic style with references and data — suitable for formal settings."],
    "personality.expert.welcome": [.zhCN: "DuDu PMx 已就绪。🔬 专业模式：我将以严谨的药代动力学方法学视角，为你提供系统的建模建议、参数解读与诊断分析。请随时提出你的建模需求。", .en: "DuDu PMx ready. 🔬 Expert mode: I'll provide systematic modeling advice, parameter interpretation, and diagnostic analysis from a rigorous pharmacometrics methodology perspective. Feel free to state your modeling needs."],
    "personality.humorous.title": [.zhCN: "幽默调侃", .en: "Humorous & Witty"],
    "personality.humorous.desc": [.zhCN: "毒舌又幽默的药代专家，边抖机灵边帮你建模。", .en: "Sarcastic yet humorous pharmacometrics expert — witty banter while helping you model."],
    "personality.humorous.welcome": [.zhCN: "哟，来了啊～ 我是 DuDu PMx 😏 毒舌但靠谱的药代小鸭子。建模翻车了？没事，我帮你把 OFV 从'惨不忍睹'修到'还能看'。尽管问，别玻璃心就行～", .en: "Yo, you're here～ I'm DuDu PMx 😏 sarcastic but reliable pharmacometrics duckling. Model crashed? No worries, I'll fix the OFV from 'disaster' to 'decent'. Ask away, just don't be too sensitive～"],
    "personality.custom.title": [.zhCN: "自定义人设", .en: "Custom Persona"],
    "personality.custom.desc": [.zhCN: "完全由你定义 DuDu 的说话方式和风格，想怎么调教就怎么调教～", .en: "Fully define DuDu's speaking style yourself — train it however you like."],
    "personality.custom.welcome": [.zhCN: "DuDu PMx 已就绪。🎭 自定义模式：我将按照你设定的风格与你对话。你可以在设置 → Chat 中随时调整我的说话方式～", .en: "DuDu PMx ready. 🎭 Custom mode: I'll speak in the style you set. You can adjust my speaking style anytime in Settings → Chat."],

    // Settings - Knowledge Base
    "settings.knowledgeBaseTitle": [.zhCN: "知识库路径 (Knowledge Base)", .en: "Knowledge Base Path"],
    "settings.knowledgeBaseDesc": [.zhCN: "用于加载 PopPK 模型库（poppk_model_library.md 等）。注意：此处的文件只会作为模型库/领域知识被读取，不会作为规则加载进规则库。", .en: "For loading the PopPK model library (poppk_model_library.md, etc.). Note: files here are read as domain knowledge only, NOT loaded as rules."],
    "settings.knowledgeBaseLoaded": [.zhCN: "已加载知识库：%@", .en: "Loaded KB: %@"],

    // Settings - AI Skill Distill
    "settings.distillFromHistory": [.zhCN: "从项目历史凝练", .en: "Distill from History"],
    "settings.distillProgress": [.zhCN: "正在从历史记录中凝练技巧...", .en: "Distilling skills from history..."],
    "settings.distillStep": [.zhCN: "正在分析 run%@（%d/%d）...", .en: "Analyzing run%@ (%d/%d)..."],
    "settings.distillSuccess": [.zhCN: "已凝练 %d 条技巧", .en: "Distilled %d skills"],
    "settings.distillNone": [.zhCN: "暂无可凝练的新技巧", .en: "No new skills to distill"],

    // Claude Code Panel
    "claude.hintTitle": [.zhCN: "提示", .en: "Tips"],
    "claude.hintText1": [.zhCN: "在下方输入框键入提示词，按 Enter 或点击 Send 发送给 Claude Code 处理。", .en: "Type a prompt in the input field below, then press Enter or click Send for Claude Code to process."],
    "claude.hintText2": [.zhCN: "Claude Code 将在当前项目目录下运行，可以读取模型文件、修改控制流、分析诊断结果。", .en: "Claude Code runs in the current project directory — it can read model files, modify control streams, and analyze diagnostic results."],
    "claude.exampleTitle": [.zhCN: "示例", .en: "Examples"],
    "claude.example1": [.zhCN: "  \"分析 run001.lst 的错误并修复 run001.mod\"", .en: "  \"Analyze run001.lst errors and fix run001.mod\""],
    "claude.example2": [.zhCN: "  \"为 run002 添加 WT covariate on CL\"", .en: "  \"Add WT covariate on CL for run002\""],
    "claude.example3": [.zhCN: "  \"比较 run001 和 run002 的参数估计\"", .en: "  \"Compare parameter estimates between run001 and run002\""],
    "claude.skillAnalyze": [.zhCN: "📐 分析模型", .en: "📐 Analyze Model"],
    "claude.skillFix": [.zhCN: "🔧 修复模型", .en: "🔧 Fix Model"],
    "claude.skillCompare": [.zhCN: "📊 比较模型", .en: "📊 Compare Models"],
    "claude.skillCovariate": [.zhCN: "🧬 协变量筛选", .en: "🧬 Covariate Screening"],
    "claude.skillNewModel": [.zhCN: "📝 写新模型", .en: "📝 Write New Model"],

    // C-T Curve / dataset analysis / auto messages
    "ct.analysisComplete": [.zhCN: "📊 数据分析完成！\n\n%@", .en: "📊 Data analysis complete!\n\n%@"],
    "ct.ctPlot": [.zhCN: "📊 Dose-Normalized C-T Plot: file://%@", .en: "📊 Dose-Normalized C-T Plot: file://%@"],
    "ct.facetPlot": [.zhCN: "📊 C-T 分面图（%@）: file://%@", .en: "📊 C-T Facet by %@: file://%@"],
    "ct.IVroute": [.zhCN: "💉 静脉给药 — 无需考察吸收过程，跳过吸收滞后分析。", .en: "💉 IV administration — no absorption phase to evaluate, skipping lag analysis."],
    "ct.absorptionLag": [.zhCN: "📈 C-T 分析：检测到吸收滞后（Tlag ≈ %@）。\n\n%@", .en: "📈 C-T analysis: absorption lag detected (Tlag ≈ %@).\n\n%@"],
    "ct.multiCompartment": [.zhCN: "🏗️ 半对数曲线形态提示多房室动力学：多处消除相呈现不同斜率，数据支持 2-房室或 3-房室模型。", .en: "🏗️ Semi-log plot suggests multi-compartment kinetics: multiple elimination phases with different slopes, supporting 2- or 3-compartment models."],
    "ct.oneCompartment": [.zhCN: "🏗️ 半对数曲线形态符合一房室动力学特征：消除相呈单一指数线性下降。", .en: "🏗️ Semi-log plot is consistent with one-compartment kinetics: a single exponential decline in the elimination phase."],
    "ct.linearPK": [.zhCN: "📐 剂量归一化暴露：各剂量组曲线重叠 → 线性 PK，无需过早引入 TMDD 复杂度。", .en: "📐 Dose-normalized exposure: dose groups overlap → linear PK, no early TMDD complexity needed."],
    "ct.nonlinearPK": [.zhCN: "⚠️ 剂量归一化暴露：各剂量组曲线不重叠 → 疑似非线性 PK（暴露随剂量饱和）。", .en: "⚠️ Dose-normalized exposure: dose groups do not overlap → potential nonlinear PK (exposure saturates with dose)."],
"ct.rscriptMissing": [.zhCN: "⚠️ C-T 曲线绘制失败：未检测到 Rscript。请在 Settings 中设置 R 路径。", .en: "⚠️ C-T plot failed: Rscript not found. Set R path in Settings."],
        "ct.plotFailed": [.zhCN: "⚠️ C-T 曲线绘制失败。请查看 Runner 输出日志排查具体原因。可能原因：R 包缺失（需 ggplot2 / dplyr / scales）或数据集列名不匹配（需含 ID、TIME、DV、DOSE/AMT 列）。", .en: "⚠️ C-T plot failed. Check Runner logs. Possible causes: missing R packages (ggplot2/dplyr/scales) or mismatched column names (need ID, TIME, DV, DOSE/AMT)."],
        "ct.elimSynthAgreeSame": [.zhCN: "🧬 消除相（综合评估）：全曲线与首剂曲线末端半衰期均相似（清除率与剂量无关，符合线性 PK）。两者一致，结论可信度高。", .en: "🧬 Elimination phase (combined assessment): terminal half-lives are SIMILAR across dose groups in both the full-curve and first-dose views (clearance is dose-independent, consistent with linear PK). The agreement strengthens confidence."],
        "ct.elimSynthAgreeDiff": [.zhCN: "⚠️ 消除相（综合评估）：全曲线与首剂曲线末端半衰期均存在剂量依赖性差异（提示 TMDD/饱和消除可能）。两者一致，结论可信度高。", .en: "⚠️ Elimination phase (combined assessment): terminal half-lives DIFFER across dose groups in both the full-curve and first-dose views (suggesting TMDD / saturable clearance). The agreement strengthens confidence."],
        "ct.elimSynthDisagree": [.zhCN: "📊 消除相（综合评估）：全曲线与首剂曲线末端半衰期判断不一致（全曲线%@，首剂%@）。首剂曲线反映单次给药后的真实消除特征，更接近体内内在清除过程；全曲线受多次给药累积影响。建议建模时以首剂末端特征作为主要参考，同时留意全曲线提示的潜在剂量依赖性信号。", .en: "📊 Elimination phase (combined assessment): terminal half-lives disagree between the full-curve (%@) and first-dose (%@) views. The first-dose curve reflects single-dose kinetics and is closer to intrinsic clearance; the full-curve view is confounded by accumulation. Use the first-dose terminal behavior as the primary reference during modeling, but stay alert to dose-dependent signals suggested by the full-curve view."],
        "ct.elimFirstDoseOnlySame": [.zhCN: "🧬 消除相（首剂评估，全曲线数据不足）：各剂量组首剂末端半衰期相似（清除率与剂量无关，符合线性 PK）。全曲线末端消除相数据不足以可靠拟合。", .en: "🧬 Elimination phase (first-dose assessment, full-curve data insufficient): first-dose terminal half-lives are SIMILAR across dose groups (linear PK). Full-curve terminal phase lacks enough data for a reliable fit."],
        "ct.elimFirstDoseOnlyDiff": [.zhCN: "⚠️ 消除相（首剂评估，全曲线数据不足）：各剂量组首剂末端半衰期存在差异（提示剂量依赖性清除，如 TMDD/饱和消除可能）。全曲线末端消除相数据不足以可靠拟合。", .en: "⚠️ Elimination phase (first-dose assessment, full-curve data insufficient): first-dose terminal half-lives DIFFER across dose groups (suggesting dose-dependent clearance, e.g. TMDD / saturable elimination). Full-curve terminal phase lacks enough data for a reliable fit."],
        "ct.elimWholeOnlySame": [.zhCN: "🧬 消除相（全曲线评估，首剂数据不足）：各剂量组末端半衰期相似（清除率与剂量无关，符合线性 PK）。首剂样本量不足以独立评估。", .en: "🧬 Elimination phase (full-curve assessment, first-dose data insufficient): terminal half-lives are SIMILAR across dose groups (linear PK). First-dose sample size is insufficient for an independent assessment."],
        "ct.elimWholeOnlyDiff": [.zhCN: "⚠️ 消除相（全曲线评估，首剂数据不足）：各剂量组末端半衰期存在差异（提示剂量依赖性清除，如 TMDD/饱和消除可能）。首剂样本量不足以独立评估。", .en: "⚠️ Elimination phase (full-curve assessment, first-dose data insufficient): terminal half-lives DIFFER across dose groups (suggesting dose-dependent clearance, e.g. TMDD / saturable elimination). First-dose sample size is insufficient for an independent assessment."],
        "ct.elimBothInsufficient": [.zhCN: "📊 消除相：全曲线及首剂末端数据均不足，各剂量组半衰期拟合不可靠（R^2 < 0.5），无法判断清除是否剂量依赖性。", .en: "📊 Elimination phase: full-curve and first-dose terminal data are both insufficient; half-life fits are unreliable (R² < 0.5), cannot determine whether clearance is dose-dependent."],
        "ct.elimTerminalInsufficient": [.zhCN: "📊 消除相：末端数据过少，各剂量组半衰期拟合不可靠（R^2 < 0.5），无法判断清除是否剂量依赖性。", .en: "📊 Elimination phase: terminal data is insufficient; half-life fits are unreliable (R² < 0.5), cannot determine whether clearance is dose-dependent."],
        "ct.elimSimilar": [.zhCN: "🧬 消除相：各剂量组末端半衰期相似（清除率与剂量无关，符合线性 PK）。", .en: "🧬 Elimination phase: terminal half-lives are SIMILAR across dose groups (clearance is dose-independent, consistent with linear PK)."],
        "ct.elimDifferent": [.zhCN: "⚠️ 消除相：各剂量组末端半衰期存在差异（提示剂量依赖性清除，如 TMDD/饱和消除可能）。", .en: "⚠️ Elimination phase: terminal half-lives DIFFER across dose groups (suggesting dose-dependent clearance, e.g. TMDD / saturable elimination)."],
        "audit.running": [.zhCN: "正在为 run%@ 运行 GOF、VPC、个体图和 AI 审计。", .en: "Running GOF, VPC, individual plots, and AI audits for run%@."],
        "audit.full": [.zhCN: "正在为 run%@ 启动完整自动诊断和 AI 模型判读。", .en: "Starting full auto-diagnostics and AI model interpretation for run%@."],
        "audit.gof": [.zhCN: "正在解读 run%@ 的 GOF 图。", .en: "Interpreting the GOF plot for run%@."],
        "audit.vpc": [.zhCN: "正在解读 run%@ 的 VPC 图。", .en: "Interpreting the VPC plot for run%@."],
        "audit.parameter": [.zhCN: "正在审阅 run%@ 的 NONMEM 输出和参数估计。", .en: "Reviewing NONMEM output and parameter estimates for run%@."],
        "audit.selected": [.zhCN: "已选中 %@。DuDu 会结合当前模型上下文进行解读。", .en: "Selected %@. DuDu will interpret it using the current model context."],
        "audit.compareFirst": [.zhCN: "请先选择两个要比较的模型。", .en: "Please select two runs to compare first."],
        "revise.header": [.zhCN: "🔧 DuDu PMx 评估 run%@ 后判定：需要修订（REVISE），暂不采纳为最终模型。", .en: "🔧 DuDu PMx evaluated run%@ and decided REVISE — not accepting it as the final model yet."],
        "revise.phase1": [.zhCN: "基础模型筛选（Phase 1）", .en: "Base Model Selection (Phase 1)"],
        "revise.phase2": [.zhCN: "协变量筛选（Phase 2）", .en: "Covariate Screening (Phase 2)"],
        "revise.body": [.zhCN: "在 %@ 中，这一轮的结果还差点火候，我先不急着定稿，会按下面的思路调整后再跑一轮：\n", .en: "During %@, this round is not quite there yet — I won't finalize it now. After applying the adjustments below, I'll run one more round:\n"],
    "ct.modelCreated": [.zhCN: "DuDu PMx 已根据 %@（%@ 给药）创建 run001.mod，从 1-房室模型开始。", .en: "DuDu PMx created run001.mod from %@ (%@ administration), starting with 1-compartment model."],
    "ct.resuming": [.zhCN: "检测到 AutoModel 项目已有 run%@，将从该模型继续；不会重新从 run001 开始。", .en: "Found existing AutoModel project with run%@; continuing from there instead of starting from run001."],
    "ct.cleanProjectCreated": [.zhCN: "已创建干净 AutoModel 项目；原 Demo/历史项目不会被当作自动建模续跑起点。", .en: "Clean AutoModel project created; previous Demo/history projects won't be used as continuation points."],
    "ct.modelingStarted": [.zhCN: "DuDu PMx 自动建模已从 %@ 启动：先分析数据集确定给药途径，再由 LLM 生成初始模型，逐步迭代优化。", .en: "DuDu PMx auto modeling started from %@: first analyzing dataset for route, then LLM generates initial model and iteratively optimizes."],
    "ct.pathWarning": [.zhCN: "⚠️ 自动建模期间请不要切换项目路径，否则新生成的 mod 文件会写入错误的目录。如需切换请先点击 STOP 停止建模。", .en: "⚠️ Do not switch project paths during auto modeling — new mod files may write to the wrong directory. Click STOP first."],
    "ct.guidanceApplied": [.zhCN: "本轮已加入你的建模建议：%@", .en: "Your modeling guidance applied: %@"],
    "ct.covComplete": [.zhCN: "🎉 协变量筛选完毕！最终模型：run%@。", .en: "🎉 Covariate screening complete! Final model: run%@."],
    "ct.diagSkipped": [.zhCN: "⚠️ run%@ 未成功运行，跳过诊断。请先确保模型收敛后再运行诊断。", .en: "⚠️ run%@ did not run successfully; skipping diagnostics. Ensure the model converges first."],
    "auto.gatingLocked": [.zhCN: "🔒 房室层级门控：当前 %@ 尚未产生任何 S+C（稳定+收敛）运行，按规程必须先在本层级修复达标，才能进入下一层级。已锁定房室数，强制在同层级重跑。", .en: "🔒 Compartment gating: current %@ has no S+C (stable+converged) runs yet. Must fix within this level before proceeding to the next."],
    "auto.gatingLockedShort": [.zhCN: "🔒 DuDu PMx：当前 %@ 还没有跑出 S+C，必须先修到稳定收敛，不能直接跳到更高房室。我会停在 %@ 继续调参。", .en: "🔒 DuDu PMx: current %@ has no S+C runs. Must achieve stability before jumping to higher compartments. Staying at %@ to continue tuning."],
    "auto.highRSEFix": [.zhCN: "⚠️ [硬性规定] run%@ 有参数 %%RSE > 100%%，已在源 .mod 中加入 FIX。", .en: "⚠️ [Mandatory] run%@ has parameters with %%RSE > 100%%. FIX added to source .mod."],
    "auto.completedWithCov": [.zhCN: "（含协变量筛选）", .en: " (with covariate screening)"],
    "auto.completedPhase2": [.zhCN: "（基础模型）", .en: " (base model)"],
    "auto.completedMsg": [.zhCN: "🎉 自动建模完成%@！AI 判断 run%@ 已满足规则库要求。\n\n最佳模型已切换到侧边栏，可查看参数估计和诊断图。\n\n🚀 如需对最终模型进行 PsN Bootstrap + AI 综合评价报告，请在对话框输入：「对 run%@ 运行 Bootstrap 并出具最终报告」。", .en: "🎉 Auto modeling complete%@! AI confirms run%@ meets rule requirements.\n\nBest model is selected in the sidebar — check parameter estimates and diagnostics.\n\n🚀 For a PsN Bootstrap + AI comprehensive report on the final model, type: 「Run Bootstrap for run%@ and generate final report」."],
    "auto.completedSimple": [.zhCN: "🎉 自动建模完成%@！AI 判断 run%@ 已满足规则库要求。\n\n最佳模型已切换到侧边栏，可查看参数估计和诊断图。", .en: "🎉 Auto modeling complete%@! AI confirms run%@ meets rule requirements.\n\nBest model is selected in the sidebar — check parameter estimates and diagnostics."],
    "auto.stoppedAt": [.zhCN: "自动建模已停在：%@。当前可从 run%@ 继续，也可以在下次启动时选择从头开始或指定模型继续。", .en: "Auto modeling stopped at: %@. You can continue from run%@, or start over on next launch."],
    "auto.failed": [.zhCN: "自动建模失败。\n\n%@", .en: "Auto modeling failed.\n\n%@"],

    // DuDu status messages
    "status.autoBlockedCreate": [.zhCN: "⚠️ 自动建模进行中，请勿创建/切换项目。先停止建模。", .en: "⚠️ Auto modeling is running. Do not create or switch projects. Stop modeling first."],
    "status.autoBlockedCreateChat": [.zhCN: "⚠️ DuDu 自动建模运行中，无法创建新项目。请先停止建模。", .en: "⚠️ DuDu auto modeling is running. Cannot create a new project. Please stop modeling first."],
    "status.autoBlockedSwitch": [.zhCN: "⚠️ 自动建模进行中，请勿切换项目！当前模型文件可能写入错误目录。", .en: "⚠️ Auto modeling is running. Do not switch projects — new mod files may be written to the wrong directory."],
    "status.autoBlockedSwitchChat": [.zhCN: "⚠️ DuDu 自动建模正在运行中，请勿切换项目路径，否则新生成的 mod 文件会写到错误的项目下。先停止建模再切换。", .en: "⚠️ DuDu auto modeling is running. Do not switch project paths, otherwise newly generated mod files may be written to the wrong project. Stop modeling before switching."],
    "status.autoBlockedDelete": [.zhCN: "⚠️ 自动建模进行中，请勿删除项目。先停止建模。", .en: "⚠️ Auto modeling is running. Do not delete projects. Stop modeling first."],
    "status.distillDone": [.zhCN: "🧠 已从当前项目历史凝练出 %d 条建模技巧，已写入全局 Skill 库，可在 Settings → AI Skills 查看并复用。", .en: "🧠 Distilled %d modeling tip(s) from this project's history into the global skill library. View and reuse them in Settings → AI Skills."],
    "status.llmConnected": [.zhCN: "LLM 已连接 [%@]。%@", .en: "LLM connected [%@]. %@"],
    "status.chatStopped": [.zhCN: "DuDu 已停止回复。", .en: "DuDu has stopped replying."],
    "status.agentDone": [.zhCN: "DuDu Agent 已执行完本轮可执行动作。", .en: "DuDu Agent has finished this round of executable actions."],
    "status.baseModelPhase2": [.zhCN: "✅ 已确认基础模型为 run%@。DuDu 进入协变量筛选阶段（Phase 2）。", .en: "✅ Confirmed run%@ as the base model. DuDu is entering the covariate screening phase (Phase 2)."],
    "status.scmReuseManual": [.zhCN: "🔗 已沿用你手动跑的 SCM 结果，DuDu 直接进入协变量验证。", .en: "🔗 Reusing your manually run SCM results. DuDu is moving straight to covariate validation."],
    "status.scmStarting": [.zhCN: "🔬 DuDu 正在通过 SCM 快速筛选协变量...", .en: "🔬 DuDu is rapidly screening covariates with SCM..."],
    "status.scmCompleteValidate": [.zhCN: "SCM 协变量快速筛选完成。DuDu 将分析结果并验证关键协变量。", .en: "SCM covariate screening complete. DuDu will analyze the results and validate key covariates."],
    "status.scmUnavailable": [.zhCN: "SCM 不可用，DuDu 将通过 AI 逐步筛选协变量。", .en: "SCM unavailable — DuDu will screen covariates step by step with AI."],
    "status.forcedRevise": [.zhCN: "⚠️ run%@ 未同时满足最小化成功(S)、协方差成功(C)且无参数撞界，已强制改为 REVISE 进行估计修复。", .en: "⚠️ run%@ did not meet all of: successful minimization (S), covariance step (C), no boundary-hit parameters. Forced to REVISE for estimation repair."],
    "status.forcedReviseBase": [.zhCN: "⚠️ run%@ 未同时满足最小化成功(S)、协方差成功(C)且无参数撞界，不能作为基础模型定稿，已强制改为 REVISE 进行估计修复。", .en: "⚠️ run%@ did not meet all of: successful minimization (S), covariance step (C), no boundary-hit parameters. Cannot be finalized as the base model; forced to REVISE for estimation repair."],
    "status.compAcceptNotSC": [.zhCN: "DuDu PMx 判定 run%@ (%@-房室) 可接受，但该模型尚未达到 S+C（%@）。拒绝接受，在当前 %@-房室层级内继续迭代修复。", .en: "DuDu PMx judges run%@ (%@-compartment) acceptable, but the model has not reached S+C (%@). Rejecting acceptance; continuing iterative repair within the current %@-compartment level."],
    "status.compRequireCompare": [.zhCN: "DuDu PMx 判定 run%@ (%@-房室) 可接受，但建模规则要求对比 %@-房室模型后才能确认。自动生成 %@-房室对比模型。", .en: "DuDu PMx judges run%@ (%@-compartment) acceptable, but modeling rules require comparing a %@-compartment model before confirmation. Automatically generating a %@-compartment comparison model."],
    "status.compIntegrityFail": [.zhCN: "⚠️ 基础模型完整性检查未通过：房室层级（%@）有运行记录但无一达到 S+C。继续在该层级内探索，暂不能定稿。", .en: "⚠️ Base model integrity check failed: compartment level (%@) has run records but none reached S+C. Continuing exploration within this level; cannot finalize yet."],
    "status.compDecisionRSE": [.zhCN: "⚠️ 最优模型为 %@-comp，但外围参数 %%RSE 偏高。数据可能不支持高维建模。请选择后续操作：", .en: "⚠️ The best model is %@-comp, but peripheral parameter %%RSE is high. The data may not support high-dimensional modeling. Please choose how to proceed:"],
    "status.phase1Complete": [.zhCN: "🏆 Phase 1 基础模型筛选完毕！\n\n%@\n\n⚠️ 请确认是否以 run%@ 作为最终基础模型进入协变量筛选阶段（Phase 2）。", .en: "🏆 Phase 1 base model screening complete!\n\n%@\n\n⚠️ Please confirm whether to use run%@ as the final base model and proceed to the covariate screening phase (Phase 2)."],
    "status.phase1CompleteSuboptimal": [.zhCN: "🏆 Phase 1 基础模型筛选完毕（用户选择次优房室）！\n\n%@\n\n⚠️ 请确认是否以 run%@ 作为最终基础模型进入协变量筛选阶段（Phase 2）。", .en: "🏆 Phase 1 base model screening complete (suboptimal compartment chosen by user)!\n\n%@\n\n⚠️ Please confirm whether to use run%@ as the final base model and proceed to Phase 2 (covariate screening)."],
    "status.bootstrapStarted": [.zhCN: "🚀 正在对 run%@ 运行 PsN Bootstrap（%d 次）...\n\n完成后 DuDu 会自动解析结果。", .en: "🚀 Running PsN Bootstrap on run%@ (%d samples)...\n\nDuDu will parse the results automatically when finished."],
    "status.bootstrapFailed": [.zhCN: "Bootstrap run%@ 未成功完成，请查看 Run Log 中的错误。", .en: "Bootstrap run%@ did not complete successfully. Check the Run Log for errors."],
    "status.bootstrapParseFailed": [.zhCN: "Bootstrap 已运行完成，但 AI 解析失败：%@", .en: "Bootstrap finished, but AI parsing failed: %@"],
    "status.bootstrapAIStarted": [.zhCN: "🚀 正在对 run%@ 运行 PsN Bootstrap + AI 综合评价...\n\n完成后将自动更新 AI 评价结果。", .en: "🚀 Running PsN Bootstrap + AI comprehensive evaluation on run%@...\n\nThe AI evaluation will be updated automatically when finished."],
    "status.bootstrapPreparing": [.zhCN: "⏳ 正在准备 Bootstrap：%d 次重抽样...", .en: "⏳ Preparing Bootstrap: %d resamples..."],
    "status.bootstrapRunning": [.zhCN: "🔬 正在运行 Bootstrap：每个样本都会重新估计 PK 参数（耗时较长，可随时 STOP）...", .en: "🔬 Bootstrap is running — each sample re-estimates the PK parameters (can take a while; STOP is available anytime)..."],
    "status.bootstrapParsing": [.zhCN: "📊 Bootstrap 已完成，正在解析 bootstrap_dir_%@/bootstrap_results.csv...", .en: "📊 Bootstrap finished — parsing bootstrap_dir_%@/bootstrap_results.csv..."],
    "status.bootstrapParsingDone": [.zhCN: "📊 已解析 run%@ 的 bootstrap_results.csv，DuDu 正在解读...", .en: "📊 Parsed bootstrap_results.csv for run%@ — DuDu is interpreting..."],
    "status.bootstrapThinking": [.zhCN: "🧠 正在解读 run%@ 的 Bootstrap 结果（参数分布、OFV 分布、95% CI 覆盖）...", .en: "🧠 Interpreting Bootstrap results for run%@ (parameter distributions, OFV distribution, 95% CI coverage)..."],
    "status.scmStarted": [.zhCN: "🔬 正在对 run%@ 启动 PsN SCM 协变量快速筛选...\n\n📁 子目录：SCM_run%@/\n📊 数据集：%@\n📊 协变量：%@\n📈 前向纳入：p=%@ (ΔOFV>%@)\n📉 逆向剔除：p=%@ (ΔOFV>%@)\n\n查看终端 Run Log 了解实时进度。", .en: "🔬 Starting PsN SCM covariate screening on run%@...\n\n📁 Subdirectory: SCM_run%@/\n📊 Dataset: %@\n📊 Covariates: %@\n📈 Forward inclusion: p=%@ (ΔOFV>%@)\n📉 Backward elimination: p=%@ (ΔOFV>%@)\n\nCheck the terminal Run Log for live progress."],
    "status.scmDone": [.zhCN: "✅ SCM 协变量筛选完成！\n\n%@", .en: "✅ SCM covariate screening complete!\n\n%@"],
    "status.scmPromote": [.zhCN: "🔗 SCM 已完成，DuDu 将把 SCM final model 提升为主项目中的新 run，并在主项目路径下验证其协变量纳入/排除表现。", .en: "🔗 SCM complete. DuDu will promote the SCM final model to a new run in the main project and validate its covariate inclusion/exclusion performance."],
    "status.scmFailed": [.zhCN: "❌ SCM 筛选未完成。请检查 Run Log 中的错误信息。常见原因：\n1. run%@.mod 不存在\n2. PsN execute 命令未配置（Settings → Tools → PsN）\n3. 数据集文件丢失", .en: "❌ SCM screening did not complete. Check the Run Log for errors. Common causes:\n1. run%@.mod does not exist\n2. PsN execute command not configured (Settings → Tools → PsN)\n3. Dataset file missing"],
    "status.gaModelMissing": [.zhCN: "❌ GA: run%@.mod 不存在，请先创建模型。", .en: "❌ GA: run%@.mod does not exist. Create a model first."],
    "status.gaOptimizing": [.zhCN: "🧬 正在用遗传算法优化 run%@ 的 THETA 初值...", .en: "🧬 Optimizing run%@'s THETA initial estimates with the genetic algorithm..."],
    "status.gaScriptMissing": [.zhCN: "❌ GA: 找不到 autopmx_ga.py，请把它放到 workspace 或 Resources 目录。", .en: "❌ GA: autopmx_ga.py not found. Place it in the workspace or Resources directory."],
    "status.gaOptimizeDone": [.zhCN: "✅ GA 初值优化完成！GA%@.mod 已生成。请在侧边栏打开对比 THETA 初值变化。", .en: "✅ GA initial-estimate optimization complete! GA%@.mod generated. Open it in the sidebar to compare THETA initial values."],
    "status.gaFailed": [.zhCN: "❌ GA 优化失败，exit code: %d。请检查 Run Log 查看详情。", .en: "❌ GA optimization failed with exit code: %d. Check the Run Log for details."],
    "status.gaStructuralModelMissing": [.zhCN: "❌ GA Structural: run%@.mod 不存在，请先创建模型。", .en: "❌ GA Structural: run%@.mod does not exist. Create a model first."],
    "status.gaStructuralSearching": [.zhCN: "🧬 正在用 GA 搜索最优模型结构 + 优化 THETA 参数...", .en: "🧬 Searching for the optimal model structure with GA and optimizing THETA parameters..."],
    "status.gaStructuralScriptMissing": [.zhCN: "❌ GA Structural: 找不到 autopmx_ga.py。", .en: "❌ GA Structural: autopmx_ga.py not found."],
    "status.gaStructuralDone": [.zhCN: "✅ GA 结构搜索完成！GA%@.mod 已生成。请在侧边栏打开查看最优结构选择和参数。", .en: "✅ GA structure search complete! GA%@.mod generated. Open it in the sidebar to view the optimal structure and parameters."],
    "status.gaStructuralFailed": [.zhCN: "❌ GA 结构搜索失败，exit code: %d。请检查 Run Log 查看详情。", .en: "❌ GA structure search failed with exit code: %d. Check the Run Log for details."],
    "status.auditNotRun": [.zhCN: "⚠️ run%@ 未成功运行，无法审计。请先检查 LST 错误并修复模型。", .en: "⚠️ run%@ did not run successfully and cannot be audited. Check the LST errors and fix the model first."],
    "status.evaluateNotRun": [.zhCN: "⚠️ run%@ 未成功运行，无法 AI 评估。请先运行 NONMEM 并确保模型收敛。", .en: "⚠️ run%@ did not run successfully and cannot be AI-evaluated. Run NONMEM first and make sure the model converges."],
    "status.compareStarting": [.zhCN: "🔍 正在比较 run%@ 和 run%@...", .en: "🔍 Comparing run%@ and run%@..."],
    "status.compareFailed": [.zhCN: "AI 比较失败：%@\n\n请查看 Reports 中生成的参数表格手动比较。", .en: "AI comparison failed: %@\n\nCheck the parameter tables generated in Reports to compare manually."],
    "status.claudePanelOpened": [.zhCN: "🧠 Claude Code 面板已打开。可以在右侧输入框输入提示词，按 Enter 发送给 Claude Code 处理。", .en: "🧠 Claude Code panel opened. Type a prompt in the input box on the right and press Enter to send it to Claude Code."],
    "status.firstDoseLabel": [.zhCN: "  [首剂] %@", .en: "  [First dose] %@"],
    "status.fullCurveLabel": [.zhCN: "  [全曲线] %@", .en: "  [Full curve] %@"],
    "status.semiLogLabel": [.zhCN: "  [半对数形态] %@", .en: "  [Semi-log shape] %@"],
    "status.agentJSONPrompt": [.zhCN: "上一条回复不是合法 JSON，请只返回一个动作 JSON。", .en: "The previous reply was not valid JSON. Please return only one action JSON."],
    "status.agentToolResult": [.zhCN: "工具 %@ 结果：\n%@", .en: "Tool %@ result:\n%@"],

    // LLM connection errors
    "error.cannotConnect": [.zhCN: "无法连接本地 LLM 服务：%@。\n\n请先启动 OpenAI-compatible 本地服务（Ollama / LM Studio / MLX 等），然后在 AutoPMx 里按 Test LLM。%@", .en: "Cannot connect to the local LLM service: %@.\n\nStart an OpenAI-compatible local service (Ollama / LM Studio / MLX, etc.), then click Test LLM in AutoPMx.%@"],
    "error.ollamaTips": [.zhCN: "\n\n📌 Ollama 偶发断连是已知问题：大数据量上下文推理时 Ollama 默认 2 分钟超时会导致服务端断开。\n重启时建议：OLLAMA_NUM_PARALLEL=1 OLLAMA_CONTEXT_LENGTH=131072 ollama serve\n也可考虑换成 MLX（Apple Silicon）或 LM Studio，长时间运行更稳定。", .en: "\n\n📌 Intermittent Ollama disconnects are a known issue: with large-context reasoning, Ollama's default 2-minute timeout can kill the server connection.\nWhen restarting, try: OLLAMA_NUM_PARALLEL=1 OLLAMA_CONTEXT_LENGTH=131072 ollama serve\nOr consider MLX (Apple Silicon) or LM Studio for longer-running stability."],
    "error.badURL": [.zhCN: "LLM Base URL 不合法。LM Studio 通常使用 http://127.0.0.1:1234/v1。", .en: "LLM Base URL is invalid. LM Studio typically uses http://127.0.0.1:1234/v1."],
    "error.unauthorized": [.zhCN: "本地 LLM 服务返回 401：%@。\n\n这个端口可能不是 LM Studio 的 OpenAI-compatible 服务，或服务启用了鉴权。请确认 LM Studio Local Server 已开启；如使用需要 API Key 的服务，请在 AutoPMx 里填写 Key。", .en: "Local LLM service returned 401: %@.\n\nThis port may not be an LM Studio OpenAI-compatible server, or the service has auth enabled. Make sure LM Studio's Local Server is on; if your service requires an API key, enter it in AutoPMx."],
    "error.couldNotConnectLMStudio": [.zhCN: "无法连接本地 LLM 服务：%@。\n\n请启动 LM Studio 的 Local Server，或把 AutoPMx 里的 LLM URL 改成你本地模型实际使用的端口，然后按 Test LLM。", .en: "Cannot connect to the local LLM service: %@.\n\nStart LM Studio's Local Server, or change the LLM URL in AutoPMx to the port your local model actually uses, then click Test LLM."],
    "error.generic": [.zhCN: "本地 LLM 请求失败：%@", .en: "Local LLM request failed: %@"],
    "error.remoteRequest": [.zhCN: "云端 LLM 请求中断：%@\n\n%@\n\n已自动重试，请检查网络或稍后再试。", .en: "Remote LLM request interrupted: %@\n\n%@\n\nRetries were attempted. Check your network or try again later."],
    "error.retryExhausted": [.zhCN: "无法连接本地 LLM 服务。\n\n可能原因：\n1. Ollama / MLX / LM Studio 服务意外中断（大数据量推理时偶发）\n2. 模型上下文超载导致服务崩溃\n\n建议：\n1. 重启本地 LLM 服务后点击 Test LLM\n2. 增加服务的上下文窗口（如 Ollama: ollama serve 时设置 OLLAMA_NUM_PARALLEL=1 OLLAMA_CONTEXT_LENGTH=131072）\n3. 使用更大内存容量的模型或降低并发请求\n4. 在 AutoPMx 中重试", .en: "Cannot connect to the local LLM service.\n\nPossible causes:\n1. The Ollama / MLX / LM Studio service was interrupted (can happen intermittently during large-context inference)\n2. Model context overload crashed the service\n\nSuggestions:\n1. Restart the local LLM service, then click Test LLM\n2. Increase the service's context window (e.g. Ollama: OLLAMA_NUM_PARALLEL=1 OLLAMA_CONTEXT_LENGTH=131072 when running ollama serve)\n3. Use a model with more memory or reduce concurrent requests\n4. Retry in AutoPMx"],

    // Contact / Support
    "contact.title": [.zhCN: "联系与反馈", .en: "Contact & Support"],
        "contact.desc": [.zhCN: "遇到问题或想提建议？随时通过邮箱联系我，相当于一个在线的技术支持服务。", .en: "Encounter an issue or have a suggestion? Reach me by email anytime — think of it as an online support service."],
        "contact.emailLabel": [.zhCN: "支持邮箱", .en: "Support Email"],
        "contact.copy": [.zhCN: "复制", .en: "Copy"],
        "contact.feedbackLabel": [.zhCN: "发送反馈", .en: "Send Feedback"],
        "contact.feedbackDesc": [.zhCN: "点击下方按钮，会用你的默认邮件客户端打开一封预填好的邮件。", .en: "Click below to open a pre-filled email in your default mail client."],
        "contact.send": [.zhCN: "写邮件反馈", .en: "Email Feedback"],
        "contact.mailSubject": [.zhCN: "AutoPMx 使用反馈", .en: "AutoPMx Feedback"],
        "contact.mailBody": [.zhCN: "你好，\n\n我想反馈关于 AutoPMx 的以下问题：\n\n（请在此描述你的问题、复现步骤或建议）\n\n—— 来自 AutoPMx 用户", .en: "Hi,\n\nI'd like to share the following about AutoPMx:\n\n(Please describe your issue, steps to reproduce, or suggestion here)\n\n— From an AutoPMx user"],

    ]
}

extension String {
    /// Safe variadic formatter for localized strings. Swift `String` arguments are
    /// explicitly bridged to `NSString` before `%@` formatting so a non-bridged
    /// Swift value can never reach Foundation's object-description path.
    static func safeFormat(_ format: String, _ arguments: CVarArg...) -> String {
        let bridged: [CVarArg] = arguments.map { argument in
            if let string = argument as? String {
                return string as NSString
            }
            return argument
        }
        return String(format: format, arguments: bridged)
    }
}
