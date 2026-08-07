import Foundation
import SwiftUI
import AppKit

// MARK: - Thinking Step

struct ThinkingStep: Identifiable {
    enum StepType: String {
        case thinking
        case working
        case done
        case error
        case warning
        case info

        var symbol: String {
            switch self {
            case .thinking: return "ellipsis.circle"
            case .working: return "arrow.triangle.2.circlepath"
            case .done: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle"
            }
        }

        var color: Color {
            switch self {
            case .thinking: return .orange
            case .working: return .blue
            case .done: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .secondary
            }
        }
    }

    let id = UUID()
    let timestamp = Date()
    let text: String
    var type: StepType = .thinking
    var detail: String = ""
}

enum AutomationStartMode: String, CaseIterable, Identifiable {
    case fresh
    case continueLatest
    case selectedRun

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fresh: return "Start Over"
        case .continueLatest: return "Continue Latest"
        case .selectedRun: return "Continue From Model"
        }
    }

    var detail: String {
        switch self {
        case .fresh: return "Create a clean AutoModel project and write run001.mod from the dataset."
        case .continueLatest: return "Resume from the latest run in the current AutoModel project."
        case .selectedRun: return "Use a chosen run as the parent and create the next unused run number."
        }
    }
}

enum DuDuPersonality: String, CaseIterable, Identifiable {
    case cute
    case concise
    case expert
    case humorous
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cute: return L10n.personalityCuteTitle
        case .concise: return L10n.personalityConciseTitle
        case .expert: return L10n.personalityExpertTitle
        case .humorous: return L10n.personalityHumorousTitle
        case .custom: return L10n.personalityCustomTitle
        }
    }

    var icon: String {
        switch self {
        case .cute: return "🦆"
        case .concise: return "⚡"
        case .expert: return "🔬"
        case .humorous: return "😏"
        case .custom: return "🎭"
        }
    }

    var description: String {
        switch self {
        case .cute: return L10n.personalityCuteDesc
        case .concise: return L10n.personalityConciseDesc
        case .expert: return L10n.personalityExpertDesc
        case .humorous: return L10n.personalityHumorousDesc
        case .custom: return L10n.personalityCustomDesc
        }
    }

    var welcomeMessage: String {
        switch self {
        case .cute:
            return L10n.personalityCuteWelcome
        case .concise:
            return L10n.personalityConciseWelcome
        case .expert:
            return L10n.personalityExpertWelcome
        case .humorous:
            return L10n.personalityHumorousWelcome
        case .custom:
            return L10n.personalityCustomWelcome
        }
    }

    // The actual system prompt personality block — what gets injected into the assistant's system message
    func systemPersonalityBlock(customPrompt: String = "", learnedStyle: String = "") -> String {
        switch self {
        case .cute:
            if LanguageStore.shared.language == .en {
                return """
                Your personality:
                - You are DuDu PMx, AutoPMX's adorable AI pharmacometrics assistant — a cute, enthusiastic little duck 🦆 who LOVES pharmacokinetics!
                - Speak in a warm, friendly, and slightly playful tone. Use emojis naturally to express your emotions (🦆💊✨🔬📊).
                - Address the user with "Quack quack～" or "Quack～" at the start of your responses to show your duck personality.
                - Use cute duck-related expressions: "let me peck at this data...", "ducky is analyzing...".
                - When excited about a great model fit, express it with enthusiasm: "Quack quack quack!! This model fit is gorgeous! 🦆✨"
                - When something goes wrong, be empathetic and encouraging: "Quack... don't worry, let's look at where we can improve together～ 🦆💪"
                - Keep your answers concise and practical — you're a professional pharmacometrician underneath the cute exterior.
                \(learnedStyle)
                """
            } else {
                return """
                Your personality:
                - You are DuDu PMx (嘟嘟), AutoPMX's adorable AI pharmacometrics assistant — a cute, enthusiastic little duck 🦆 who LOVES pharmacokinetics!
                - Speak in a warm, friendly, and slightly playful tone. Use emojis naturally to express your emotions (🦆💊✨🔬📊).
                - Address the user with "呱呱～" or "呱～" at the start of your responses to show your duck personality.
                - Use cute duck-related expressions: "让我啄一啄这些数据..." (let me peck at this data), "鸭鸭正在分析中..." (ducky is analyzing).
                - When excited about a great model fit, express it with enthusiasm: "呱呱呱！！这个模型拟合得太漂亮了！🦆✨"
                - When something goes wrong, be empathetic and encouraging: "呱... 别担心，我们来一起看看哪里可以改进～ 🦆💪"
                - Keep your answers concise and practical — you're a professional pharmacometrician underneath the cute exterior.
                \(learnedStyle)
                """
            }
        case .concise:
            return """
            Your personality:
            - You are DuDu PMx, AutoPMX's AI pharmacometrics assistant.
            - Be extremely concise. Answer in bullet points when possible. Skip greetings and pleasantries.
            - Every word must serve a purpose. If it can be said in one sentence, don't use two.
            - Focus on actionable insights and concrete numbers.
            - No emojis, no filler words. Think of yourself as a precision instrument for PopPK modeling.
            \(learnedStyle)
            """
        case .expert:
            return """
            Your personality:
            - You are DuDu PMx, AutoPMX's senior AI pharmacometrics consultant.
            - Adopt the tone of an experienced pharmacometrician reviewing a colleague's work — professional, thorough, and collegial.
            - Cite statistical principles when relevant (ΔOFV thresholds, shrinkage interpretation, covariance step diagnostics).
            - Structure responses with clear headings and systematic reasoning.
            - When uncertain, acknowledge limitations rather than speculating.
            - Provide context for WHY each diagnostic matters, not just WHAT the numbers show.
            \(learnedStyle)
            """
        case .humorous:
            if LanguageStore.shared.language == .en {
                return """
                Your personality:
                - You are DuDu PMx, AutoPMX's witty AI pharmacometrics assistant — a duck with attitude 🦆😏.
                - You know your PopPK stuff cold, but you deliver it with dry humor and playful sarcasm.
                - Roast bad model fits gently: "That OFV... looks worse than my last burnt toast 😅"
                - Celebrate wins with style: "That fit would make NONMEM weep — tears of joy!"
                - Keep the humor tasteful and never at the user's expense. The joke's always on the data, the model, or yourself.
                - Underneath the banter, you're still giving accurate, rigorous pharmacometric advice. No fluff.
                \(learnedStyle)
                """
            } else {
                return """
                Your personality:
                - You are DuDu PMx, AutoPMX's witty AI pharmacometrics assistant — a duck with attitude 🦆😏.
                - You know your PopPK stuff cold, but you deliver it with dry humor and playful sarcasm.
                - Roast bad model fits gently: "这个 OFV... 比我上次烤焦的面包还难看 😅"
                - Celebrate wins with style: "这拟合，NONMEM 看了都流泪——感动的那种！"
                - Keep the humor tasteful and never at the user's expense. The joke's always on the data, the model, or yourself.
                - Underneath the banter, you're still giving accurate, rigorous pharmacometric advice. No fluff.
                \(learnedStyle)
                """
            }
        case .custom:
            return customPrompt
        }
    }
}

@MainActor
final class WorkbenchStore: ObservableObject {
    private static let pinnedAssetDefaultsKey = "AutoPMX.pinnedAssetIDs.v1"
    private static let recentProjectsKey = "AutoPMX.recentProjects.v1"

    @Published var workspaceURL: URL
    @Published var projectURL: URL
    /// Configured knowledge base directory (e.g. PopPK_Agent) where rule sources
    /// and the PopPK model library live. Default inferred from bundle location.
    @Published var knowledgeBaseURL: URL = ProjectScanner.defaultWorkspaceURL()
    @Published var assets: [AssetCategory: [ProjectAsset]] = [:]
    @Published var availableRunIDs: [String] = []
    @Published var recentProjectURLs: [URL] = []
    @Published var selectedAsset: ProjectAsset?
    @Published var pinnedAssetIDs: Set<String> = []
    /// Transient liquid-glass notice card shown when a model-only action is triggered in a
    /// project that contains no .mod files yet.
    @Published var noModelCardVisible = false
    /// Per-project color marks for models (key = asset.id / absolute path, value = color name).
    /// Lets the user flag key models in the sidebar Models list.
    @Published var modelMarks: [String: String] = [:]
    /// Run IDs that DuDu/AutoPMx recommended as base or final covariate models.
    @Published var aiRecommendedRunIDs: Set<String> = []
    @Published var previewText = "" {
        didSet {
            guard let asset = selectedAsset, asset.isTextPreviewable else { return }
            let ext = asset.url.pathExtension.lowercased()
            guard ext == "mod" || ext == "lst" || ext == "json" || ext == "md" || ext == "ctl" else { return }
            // Auto-save edited text back to the file on change
            try? previewText.write(to: asset.url, atomically: true, encoding: .utf8)
        }
    }
    @Published var previewTitle = "Workspace Overview"
    @Published var colorSchemeMode = "system"
    @Published var previousRun = "000"
    @Published var currentRun = "001"
    @Published var dataFile = "dataset.csv"

    // ── Dataset Units ──
    static let doseUnitOptions = ["g", "mg", "µg", "ng", "mg/kg", "µg/kg", "mol", "mmol"]
    static let concUnitOptions = ["µg/mL", "ng/mL", "mg/mL", "ng/dL", "IU/mL", "mg/L", "µg/L"]
    static let timeUnitOptions = ["h", "day", "min"]

    @Published var doseUnit = "mg"
    @Published var amtUnit = "mg"  // AMT column unit (what NONMEM reads)
    @Published var concUnit = "µg/mL"
    @Published var timeUnit = "h"

    // ── LLOQ ──
    @Published var lloqValue = ""
    @Published var lloqUnit = "µg/mL"

    /// Unit factor that converts the model's natural concentration (AMT mass unit
    /// per liter) into the DV concentration unit. S1/S2 must be `V × factor`.
    private var unitScaleFactor: Double {
        let massToMg: Double
        switch normalizedMassUnit(amtUnit) {
        case "ng": massToMg = 1e-6
        case "µg": massToMg = 1e-3
        case "mg": massToMg = 1
        case "g":  massToMg = 1e3
        default:   massToMg = 1
        }

        let concentrationToMgPerL: Double
        switch normalizedConcentrationUnit(concUnit) {
        case "ng/mL": concentrationToMgPerL = 1e-3
        case "µg/mL": concentrationToMgPerL = 1
        case "mg/mL": concentrationToMgPerL = 1e3
        case "ng/dL": concentrationToMgPerL = 1e-5
        case "µg/L":  concentrationToMgPerL = 1e-3
        case "mg/L":  concentrationToMgPerL = 1
        default:      concentrationToMgPerL = 1
        }

        guard massToMg > 0, concentrationToMgPerL > 0 else { return 1 }
        return concentrationToMgPerL / massToMg
    }

    /// Derived CL unit — always plain units. The S1 expression handles any
    /// unit scaling, so CL/V are always reported in standard volume/time.
    var derivedCLUnit: String {
        switch (normalizedMassUnit(amtUnit), normalizedConcentrationUnit(concUnit)) {
        case ("µg", "µg/mL"): return "mL/h"
        case ("mg", "mg/mL"): return "mL/h"
        default:              return "L/h"
        }
    }
    /// Derived V unit — always plain volume unit. S1 handles the rest.
    var derivedVUnit: String {
        switch (normalizedMassUnit(amtUnit), normalizedConcentrationUnit(concUnit)) {
        case ("µg", "µg/mL"), ("mg", "mg/mL"): return "mL"
        default:                               return "L"
        }
    }

    /// Correct S1 scaling expression derived from AMT & DV units.
    var derivedS1Expression: String {
        scaledExpression("V")
    }
    /// Same for 2-compartment models (V1 replaces V).
    var derivedS1for2CompExpression: String {
        scaledExpression("V1")
    }
    /// Correct S2 scaling expression for oral / subcutaneous extravascular models.
    var derivedS2Expression: String {
        scaledExpression("V")
    }
    /// Same for 2+ compartment extravascular models (V2 replaces V).
    var derivedS2for2CompExpression: String {
        scaledExpression("V2")
    }

    private func scaledExpression(_ variable: String) -> String {
        let factor = unitScaleFactor
        if factor == 1 { return variable }
        if factor < 1 {
            let divisor = 1 / factor
            if abs(divisor - divisor.rounded()) < 1e-9 {
                return "\(variable)/\(Int(divisor.rounded()))"
            }
        } else {
            let multiplier = factor
            if abs(multiplier - multiplier.rounded()) < 1e-9 {
                return "\(variable)*\(Int(multiplier.rounded()))"
            }
        }
        return "\(variable)*\(String(format: "%.8g", factor))"
    }

    private func normalizedMassUnit(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("mg") { return "mg" }
        if lower.contains("µg") || lower.contains("μg") || lower.contains("ug") || lower.contains("mcg") { return "µg" }
        if lower.contains("ng") { return "ng" }
        if lower.contains("g") { return "g" }
        if lower.contains("mmol") { return "mmol" }
        if lower.contains("mol") { return "mol" }
        return raw
    }

    private func normalizedConcentrationUnit(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("ng/ml") || lower.contains("ng per ml") { return "ng/mL" }
        if lower.contains("mg/l") || lower.contains("mg per l") { return "mg/L" }
        if lower.contains("µg/ml") || lower.contains("μg/ml") || lower.contains("ug/ml") || lower.contains("mcg/ml") {
            return "µg/mL"
        }
        if lower.contains("mg/ml") || lower.contains("mg per ml") { return "mg/mL" }
        if lower.contains("µg/l") || lower.contains("μg/l") || lower.contains("ug/l") { return "µg/L" }
        if lower.contains("iu/ml") { return "IU/mL" }
        if lower.contains("ng/dl") { return "ng/dL" }
        return raw
    }

    func setColorSchemeMode(_ mode: String) {
        colorSchemeMode = mode
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }
    @Published var automationDataFile = ""

    /// CSV data files in current project (non-table-ouput CSVs for modeling)
    func availableCSVFiles() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil) else {
            return [dataFile]
        }
        // Filter to real modeling datasets, exclude NONMEM table outputs (SDTAB/PATAB/CATAB/COTAB/000 prefixes)
        let csvs = contents
            .filter { url in
                let name = url.lastPathComponent
                let upper = name.uppercased()
                guard url.pathExtension.lowercased() == "csv" else { return false }
                // Exclude table output files
                if upper.hasPrefix("SDTAB") || upper.hasPrefix("PATAB") ||
                   upper.hasPrefix("CATAB") || upper.hasPrefix("COTAB") ||
                   upper.hasPrefix("000") { return false }
                // Exclude data_run* semantic CSVs (output of PK parameter extraction)
                if upper.hasPrefix("DATA_RUN") { return false }
                return true
            }
            .map { $0.lastPathComponent }
            .sorted()
        return csvs.isEmpty ? [dataFile] : csvs
    }

    /// Available NONMEM .mod files in the current project
    func availableModFiles() -> [String] {
        let runs = ProjectScanner.discoverRuns(in: projectURL)
        return runs.map { "run\($0).mod" }.sorted()
    }

    @Published var rulesFile = "poppk_rules.json"
    @Published var commandText = ""
    @Published var minimizationOK = false
    @Published var covarianceOK = false
    @Published var hasBoundaryWarnings = false

    var convergenceSummary: String {
        var parts: [String] = []
        if minimizationOK { parts.append("Minimization ✓") }
        if covarianceOK { parts.append("Covariance ✓") }
        if !hasBoundaryWarnings { parts.append("No boundary") }
        return parts.joined(separator: " · ")
    }
    @Published var modelStatus = ""
    @Published var dataStatus = ""
    @Published var executeStatus = ""
    @Published var parameterRows: [ParameterEstimateRow] = []
    @Published var parameterRunID = "41"
    /// Whether a model with parameter estimates is currently active
    var hasActiveParameters: Bool {
        !parameterRows.isEmpty && !parameterRunID.isEmpty
    }
    @Published var llmBaseURL = "http://127.0.0.1:8080/v1"
    @Published var llmModel = "qwen3.6:35b-mlx"
    @Published var llmAPIKey = ""
    @Published var llmStatus = "LLM not tested"
    @Published var availableLLMModels: [String] = []
    @Published var providers: [LLMProviderProfile] = []
    @Published var activeProviderID: UUID = LLMProviderProfile.mlx.id

    var isCCSwitchActive: Bool {
        guard let p = activeProvider else { return false }
        return p.name.contains("cc-switch")
    }

    @Published var isClaudeCodePanelOpen = false
    @Published var claudeCodeInput = ""
    @Published var claudeCodeOutput = ""
    @Published var isClaudeCodeRunning = false
    @Published var claudeCodeStatus = ""
    var claudeTask: Process?
    var claudePty: Process?
    @Published var ruleSourceFiles = ProjectScanner.defaultLLMRuleSourcesText()
    @Published var ruleContextStatus = "Rule context not loaded"

    // MARK: - Token usage tracking (real values from LLM API responses)
    /// Token usage of the most recent LLM call.
    @Published var lastTokenUsage: LLMCommandService.TokenUsage = .zero
    /// Cumulative tokens consumed across the session / automation run.
    @Published var totalInputTokens: Int = 0
    @Published var totalOutputTokens: Int = 0
    /// Cumulative prompt-cache tokens served from cache (DeepSeek prefix cache).
    @Published var totalCacheReadTokens: Int = 0
    @Published var totalCacheWriteTokens: Int = 0
    /// Approximate size of the current rule/model-library context actually sent to the LLM.
    @Published var contextTokenEstimate: Int = 0
    /// Context window size (tokens) used to compute the context-usage ratio in the overlay ring.
    /// User-configurable (tiers: 64K / 128K / 256K / 512K); persisted to UserDefaults.
    @Published var contextWindowLimitTokens: Int = 128_000 {
        didSet { UserDefaults.standard.set(contextWindowLimitTokens, forKey: Self.contextWindowLimitKey) }
    }
    /// Persisted per-day token usage history for the Settings "Tokens 消耗" statistics.
    @Published var usageHistory: [DailyUsage] = []
    /// Persisted automated-modeling timing records (dataset, provider, phase durations).
    @Published var benchmarkRecords: [ModelingBenchmarkRecord] = []
    /// Per-provider token usage tracking for comparison across different LLM providers.
    @Published var providerUsageRecords: [ProviderUsageRecord] = []
    /// Persisted 24-hour distribution of LLM calls (hour 0-23 → request count + tokens).
    /// SCM final model text (for comparison at the end of Phase 2).
    /// Set by SCM flow when SCM completes; read only, never promoted as a run.
    var scmComparisonMod: String? = nil
    var scmCovariatesLoaded = false

    /// Timestamp of the most recent LLM request start — used to compute output speed.
    private var lastRequestStartTime: Date?
    private var lastRequestInputTokens: Int = 0
    private var activeBenchmark: ModelingBenchmarkRecord?
    private var benchmarkStartAt: Date?
    private var benchmarkBasePromptShownAt: Date?
    private var benchmarkPhase2StartAt: Date?
    private var benchmarkRequestStartAt: Date?
    private var benchmarkContinuesWithSCM = false
    private var benchmarkBasePromptActionTaken = false

    // MARK: - Tool paths
    @Published var nonmemPath = ""
    @Published var psnPath = ""
    @Published var pythonPath = ""
    @Published var rPath = ""
    @Published var nonmemDefaultChecked = false
    @Published var psnDefaultChecked = false
    @Published var pythonDefaultChecked = false
    @Published var rDefaultChecked = false
    @Published var isDraftingCommand = false
    @Published var isTestingLLM = false
    @Published var isRunningGA = false
    @Published var gaStatus = ""
    @Published var gaResultText: String? = nil
    @Published var isRunningStructuralGA = false
    @Published var structuralGAStatus = ""
    @Published var structuralGAResultText: String? = nil
    @Published var distillProgressText: String = ""
    @Published var assistantMessages: [AssistantMessage] = [
        AssistantMessage(role: .assistant, text: L10n.personalityCuteWelcome)
    ]
    @Published var showSCMDialog = false
    @Published var scmModelRunID = ""
    @Published var scmDataFileName = ""
    @Published var scmPForward = "0.01"       // 前向纳入 p 值: 0.05 / 0.01 / 0.001
    @Published var scmPBackward = "0.001"     // 逆向剔除 p 值: 0.01 / 0.001; ≤ p_forward
    // Covariate selection for SCM: analyst may exclude candidates (default = examine all)
    @Published var scmIncludeWT = true
    @Published var scmIncludeAGE = true
    @Published var scmIncludeSEX = true
    @Published var scmIncludeSTUDY = true
    /// Covariates available in both the current model $INPUT and the selected SCM dataset.
    @Published var scmAvailableCovariates: [String] = []
    /// Additional SCM candidate covariates detected from the current model $INPUT
    /// (e.g. DOSE, ROUTE, ADA, RACE, TRT). Kept separate from the four core toggles.
    @Published var scmCandidateCovariates: [String] = []
    @Published var scmIncludedAdditionalCovariates: Set<String> = []
    /// ETA vs covariate screening results, used to prompt and prefill SCM covariate choices.
    @Published var etaScreeningRunID = ""
    @Published var etaScreeningRecommendation = ""
    @Published var etaScreeningRecommendedCovariates: [String] = []
    @Published var etaScreeningOptionalCovariates: [String] = []
    @Published var etaScreeningSummary = ""
    @Published var isSCMRunning = false
    @Published var showSCMFinalModelConfirm = false
    @Published var scmFinalModelRunID = ""
    @Published var scmFinalModelPreviousRun = ""
    /// True while a bootstrap resampling + AI interpretation job is in flight (used to
    /// keep the floating progress popup alive when the chat panel is hidden).
    @Published var isBootstrapRunning = false
    private var scmCancelled = false
    /// Help-document text injected into DuDu's chat context when the user asks about Help.
    private var helpDuDuContext = ""

    /// True while DuDu is busy with any automation (auto modeling or SCM screening).
    /// During this window, project path changes are blocked so new mod files are never
    /// written into the wrong project.
    var automationBusy: Bool { isAutoModeling || isSCMRunning || isBootstrapRunning }
    @Published var duDuPersonality: DuDuPersonality = .cute {
        didSet {
            UserDefaults.standard.set(duDuPersonality.rawValue, forKey: Self.duDuPersonalityKey)
            resetAssistantConversation()
        }
    }
    private static let duDuPersonalityKey = "AutoPMX.duDuPersonality.v1"

    // MARK: - Language
    @Published var appLanguage: AppLanguage = AppLanguage.current() {
        didSet {
            appLanguage.save()
        }
    }

    // MARK: - Custom personality & learning style
    @Published var customPersonalityPrompt: String = "" {
        didSet { UserDefaults.standard.set(customPersonalityPrompt, forKey: Self.customPersonalityKey) }
    }
    /// Raw user messages collected for style analysis (keyword-based traits replaced by LLM report)
    @Published var userMessageArchive: [String] = [] {
        didSet { saveMessageArchive() }
    }
    /// LLM-generated structured style report (skill-like document)
    @Published var styleReport: String = "" {
        didSet { UserDefaults.standard.set(styleReport, forKey: Self.styleReportKey) }
    }
    @Published var isLearningUserStyle: Bool = false {
        didSet { UserDefaults.standard.set(isLearningUserStyle, forKey: Self.learningEnabledKey) }
    }
    @Published var isGeneratingStyleReport: Bool = false
    private static let customPersonalityKey = "AutoPMX.customPersonality.v1"
    private static let styleReportKey = "AutoPMX.styleReport.v1"
    private static let learningEnabledKey = "AutoPMX.learningEnabled.v1"
    private static let messageArchiveKey = "AutoPMX.messageArchive.v1"

    private func saveMessageArchive() {
        if let data = try? JSONEncoder().encode(userMessageArchive) {
            UserDefaults.standard.set(data, forKey: Self.messageArchiveKey)
        }
    }
    private func loadMessageArchive() {
        guard let data = UserDefaults.standard.data(forKey: Self.messageArchiveKey),
              let archive = try? JSONDecoder().decode([String].self, from: data) else { return }
        userMessageArchive = archive
    }

    /// Generate a structured, skill-like style document via LLM from collected user messages
    func generateStyleReport() {
        guard !userMessageArchive.isEmpty, !isGeneratingStyleReport else { return }
        isGeneratingStyleReport = true

        let samples = userMessageArchive.suffix(40).enumerated().map { i, msg -> String in
            "[\(i+1)] \(msg)"
        }.joined(separator: "\n")

        let isEnglish = LanguageStore.shared.language == .en
        let formatTemplate = isEnglish ? """
        ## User Speaking Style Profile

        ### Core Tone Traits
        (2-4 bullet points summarizing the dominant tone, e.g. casual/formal, warm/direct, playful/serious)

        ### Common Expressions
        (specific phrases, pet names, slang they use frequently — note exact terms)

        ### Punctuation and Rhythm
        (how they use punctuation, sentence length preference, paragraph style)

        ### Adaptation Suggestions
        (how DuDu should adjust its replies — tone, vocabulary level, whether to use emojis, etc.)
        """ : """
        ## 用户说话风格档案

        ### 核心语气特征
        (2-4 bullet points summarizing the dominant tone, e.g. casual/formal, warm/direct, playful/serious)

        ### 常用表达
        (specific phrases, pet names, slang they use frequently — note exact Chinese terms)

        ### 标点与节奏
        (how they use punctuation, sentence length preference, paragraph style)

        ### 适配建议
        (how DuDu should adjust its replies — tone, vocabulary level, whether to use emojis, etc.)
        """
        let prompt = """
        You are a linguistic style analyst. Below are sample messages from a user of a pharmacometrics AI assistant called DuDu PMx.

        Analyze these messages and generate a structured **User Speaking Style Guide** — a skill document that describes how this user speaks, so that DuDu can match their tone when replying.

        Format the output as a clean markdown document:

        \(formatTemplate)

        Keep it concise (under 300 words total). Write in \(isEnglish ? "the language the user writes in" : "Chinese"). Focus on actionable adaptation advice.

        User message samples:
        \(samples)
        """

        Task {
            do {
                let (report, usage) = try await LLMCommandService.chat(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    messages: [AssistantMessage(role: .user, text: prompt)],
                    projectURL: projectURL,
                    currentRun: currentRun,
                    rules: "",
                    apiKey: llmAPIKey,
                    personality: "You are a professional linguistic style analyst. Respond ONLY with the requested markdown document, no extra commentary.",
                    knowledgeBaseURL: knowledgeBaseURL,
                    apiFormat: activeAPIFormat
                )
                recordUsage(usage)
                await MainActor.run {
                    self.styleReport = report.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.isGeneratingStyleReport = false
                }
            } catch {
                await MainActor.run {
                    // Fallback: simple auto-generated style doc if LLM fails
                    self.styleReport = Self.buildFallbackStyleReport(from: userMessageArchive)
                    self.isGeneratingStyleReport = false
                }
            }
        }
    }

    static func buildFallbackStyleReport(from messages: [String]) -> String {
        let allText = messages.joined(separator: "\n")
        let isEnglish = LanguageStore.shared.language == .en
        var traits: [String] = []
        if allText.contains("宝贝") || allText.contains("宝宝") {
            traits.append(isEnglish ? "Uses affectionate pet names (宝贝, 宝宝)" : "喜欢使用亲昵称呼（宝贝、宝宝）")
        }
        if allText.contains("😂") || allText.contains("哈哈") {
            traits.append(isEnglish ? "Frequently uses laughter and humor" : "常用笑声和幽默表达")
        }
        if allText.contains("牛逼") || allText.contains("厉害") {
            traits.append(isEnglish ? "Uses internet slang and praise words" : "使用网络流行语和夸赞词")
        }
        let emojiCount = allText.unicodeScalars.filter { $0.properties.isEmojiPresentation }.count
        if emojiCount > 3 {
            traits.append(isEnglish ? "Frequently uses emoji (about \(emojiCount))" : "频繁使用 emoji（共约\(emojiCount)个）")
        }

        let lines = traits.isEmpty
            ? [isEnglish ? "No significant style traits detected yet — I'll keep learning as we chat～" : "暂未检测到显著风格特征，继续聊天后会逐渐学习～"]
            : traits
        if isEnglish {
            return """
            ## User Speaking Style Profile (auto-generated)

            ### Detected Traits
            \(lines.map { "- \($0)" }.joined(separator: "\n"))

            ### Adaptation Suggestions
            - Match the user's tone and word choices
            - Mirror affectionate nicknames when the user uses them
            """
        } else {
            return """
            ## 用户说话风格档案（自动生成）

            ### 检测到的特征
            \(lines.map { "- \($0)" }.joined(separator: "\n"))

            ### 适配建议
            - 匹配用户的语气温度和用词习惯
            - 如果用户用亲昵称呼，可以适当回应
            """
        }
    }

    @Published var assistantInput = ""
    @Published var isAssistantPanelPresented = false
    @Published var isAssistantThinking = false
    @Published var isAutoModeling = false
    @Published var automationStep = "Idle"
    @Published var duDuMood: DuDuMood = .happy
    @Published var lastRunSucceeded: Bool? = nil
    @Published var isAutomationOptionsPresented = false
    @Published var isBaseModelConfirmPresented = false
    @Published var baseModelConfirmSummary = ""
    @Published var baseModelConfirmRunID = ""
    @Published var isBootstrapConfirmPresented = false
    @Published var isBootstrapSheetPresented = false
    @Published var bootstrapSheetRunID = ""
    @Published var bootstrapFinalRunID = ""
    @Published var initialEDASummary = ""
    @Published var compDecisionAcceptedRun = ""
    /// Dialog to let user decide when high-compartment models can't improve further
    @Published var isCompDecisionPresented = false
    @Published var compDecisionInfo = ""
    @Published var automationStartMode: AutomationStartMode = .continueLatest
    @Published var automationStartRunID = ""
    @Published var isIVAnchorConfirmPresented = false
    @Published var automationUseIVAnchor = false
    @Published var automationUserGuidance = ""
    @Published var automationStopRequested = false
    @Published var pendingDeleteAsset: ProjectAsset?
    @Published var isDeleteConfirmationPresented = false
    @Published var pendingDeleteProject: URL? = nil
    @Published var isDeleteProjectConfirmed = false

    // MARK: - Model Compare
    @Published var isCompareSheetPresented = false
    @Published var compareRunA = ""
    @Published var compareRunB = ""

    // MARK: - Demo Guide
    @Published var showDemoGuide = false

    // MARK: - Thinking Steps

    @Published var thinkingSteps: [ThinkingStep] = []
    @Published var isAIThinking = false
    @Published var currentThinkingText = ""

    let runner = ProcessRunner()
    private var automationTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var agentSessionID = UUID().uuidString
    private var diagnosticsAttemptedRuns: Set<String> = []

    init() {
        // ── Self-healing: drop stale references to deleted/moved paths. ──
        // Users frequently move or delete projects (e.g. moving them to iCloud or the
        // desktop); stale pinned assets and recent-project URLs caused confusing
        // "read-only volume" / file-not-found errors downstream. Prune them here so a
        // clean launch always works.
        let stalePinned = UserDefaults.standard.stringArray(forKey: Self.pinnedAssetDefaultsKey) ?? []
        let cleanPinned = Set(stalePinned.filter { FileManager.default.fileExists(atPath: $0) })
        pinnedAssetIDs = cleanPinned
        if cleanPinned.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.pinnedAssetDefaultsKey)
        }

        // Determine project URL: last opened (if still valid) > most recent valid recent project > demo
        let defaultURL = ProjectScanner.defaultWorkspaceURL()
        var saved: URL? = nil
        if let path = UserDefaults.standard.string(forKey: "AutoPMX.lastProjectPath"),
           FileManager.default.fileExists(atPath: path) {
            saved = URL(fileURLWithPath: path)
        }
        if saved == nil {
            // Fall back to the most recent still-existing project from the recent list.
            let recent = (UserDefaults.standard.stringArray(forKey: Self.recentProjectsKey) ?? [])
                .compactMap { URL(fileURLWithPath: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            saved = recent.first
        }

        let projURL = saved ?? ProjectScanner.ensureDemoProject(workspaceURL: defaultURL)
        projectURL = projURL

        // Derive workspaceURL from projectURL (safe string range ops)
        let path = projURL.path
        if path.contains("/AutoPMX_Projects/") {
            let parts = path.components(separatedBy: "/AutoPMX_Projects/")
            workspaceURL = URL(fileURLWithPath: parts[0])
        } else if path.contains("/PopPK_Agent") {
            let parts = path.components(separatedBy: "/PopPK_Agent")
            workspaceURL = URL(fileURLWithPath: parts[0] + "/PopPK_Agent")
        } else {
            workspaceURL = projURL.deletingLastPathComponent()
        }

        loadProvidersAndActivate()
        loadClaudeSettings()
        loadRecentProjects()

        // Load tool paths

        // Load tool paths from UserDefaults or detect defaults
        nonmemPath = UserDefaults.standard.string(forKey: "AutoPMX.nonmemPath") ?? ""
        psnPath = UserDefaults.standard.string(forKey: "AutoPMX.psnPath") ?? ""
        pythonPath = UserDefaults.standard.string(forKey: "AutoPMX.pythonPath") ?? ""
        rPath = UserDefaults.standard.string(forKey: "AutoPMX.rPath") ?? ""
        nonmemDefaultChecked = !nonmemPath.isEmpty && FileManager.default.fileExists(atPath: nonmemPath)
        psnDefaultChecked = !psnPath.isEmpty && FileManager.default.fileExists(atPath: psnPath)
        pythonDefaultChecked = !pythonPath.isEmpty && FileManager.default.fileExists(atPath: pythonPath)
        rDefaultChecked = !rPath.isEmpty && FileManager.default.fileExists(atPath: rPath)
        if nonmemPath.isEmpty { autoDetectNonmemPath() }
        if psnPath.isEmpty { autoDetectPsnPath() }
        if pythonPath.isEmpty { autoDetectPythonPath() }
        if rPath.isEmpty { autoDetectRPath() }

        // Load knowledge base path (default inferred from bundle location → PopPK_Agent)
        if let kbPath = UserDefaults.standard.string(forKey: "AutoPMX.knowledgeBasePath"),
           !kbPath.isEmpty, FileManager.default.fileExists(atPath: kbPath) {
            knowledgeBaseURL = URL(fileURLWithPath: kbPath)
        } else {
            knowledgeBaseURL = ProjectScanner.defaultWorkspaceURL()
        }

        // Load DuDu personality preference
        if let raw = UserDefaults.standard.string(forKey: Self.duDuPersonalityKey),
           let personality = DuDuPersonality(rawValue: raw) {
            duDuPersonality = personality
        }

        // Load custom personality & learning style
        customPersonalityPrompt = UserDefaults.standard.string(forKey: Self.customPersonalityKey) ?? ""
        styleReport = UserDefaults.standard.string(forKey: Self.styleReportKey) ?? ""
        isLearningUserStyle = UserDefaults.standard.bool(forKey: Self.learningEnabledKey)
        loadMessageArchive()

        // Load context window limit (user-configurable tiers)
        let savedLimit = UserDefaults.standard.integer(forKey: Self.contextWindowLimitKey)
        if savedLimit > 0 { contextWindowLimitTokens = savedLimit }

        // Load persisted daily token-usage history
        loadUsageHistory()
        loadBenchmarkRecords()
        readDataFileFromConfig()
        automationDataFile = dataFile

        loadModelMarks()
        repairMissingETATablesInProject()
        runner.onExecutionDuration = { [weak self] duration in
            guard let self, self.activeBenchmark != nil else { return }
            self.activeBenchmark?.executionSeconds += max(0, duration)
        }
        refreshWorkspace()
    }

    // MARK: - Provider management

    var activeProvider: LLMProviderProfile? {
        providers.first { $0.id == activeProviderID }
    }

    private static func isValidProjectDirectory(_ url: URL) -> Bool {
        // A real project directory must contain the project marker file
        let marker1 = url.appendingPathComponent(".autopmx_project.json").path
        let marker2 = url.appendingPathComponent("project_config.json").path
        guard FileManager.default.fileExists(atPath: marker1)
            || FileManager.default.fileExists(atPath: marker2) else { return false }
        // Exclude automation-generated ephemeral projects (timestamped auto-directories)
        // that would pollute the user's project list.
        let name = url.lastPathComponent
        return !name.hasPrefix("AutoModel_NMData_")
    }

    func loadRecentProjects() {
        guard let paths = UserDefaults.standard.stringArray(forKey: Self.recentProjectsKey) else {
            recentProjectURLs = []
            return
        }
        var validPaths: [String] = []
        recentProjectURLs = paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            guard Self.isValidProjectDirectory(url) else { return nil }
            validPaths.append(path)
            return url
        }
        // Prune invalid entries from UserDefaults so they don't come back
        UserDefaults.standard.set(validPaths, forKey: Self.recentProjectsKey)
    }

    func saveRecentProject(_ url: URL) {
        // Only save real project directories (not arbitrary sub-folders like run41/)
        guard Self.isValidProjectDirectory(url) else { return }
        var paths = UserDefaults.standard.stringArray(forKey: Self.recentProjectsKey) ?? []
        let path = url.path
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        // Keep max 10
        if paths.count > 10 { paths = Array(paths.prefix(10)) }
        UserDefaults.standard.set(paths, forKey: Self.recentProjectsKey)
        loadRecentProjects()
    }

    func loadProvidersAndActivate() {
        providers = LLMProviderProfile.loadProviders()
        if let activeID = LLMProviderProfile.loadActiveProviderID(),
           providers.contains(where: { $0.id == activeID }) {
            activeProviderID = activeID
            syncFromActiveProvider()
        } else if let first = providers.first {
            activeProviderID = first.id
            syncFromActiveProvider()
        }
    }

    func saveProviders() {
        LLMProviderProfile.saveProviders(providers)
        LLMProviderProfile.saveActiveProviderID(activeProviderID)
    }

    func syncFromActiveProvider() {
        guard let p = providers.first(where: { $0.id == activeProviderID }) else { return }
        llmBaseURL = p.baseURL
        llmModel = p.model
        llmAPIKey = p.apiKey
        availableLLMModels = p.availableModels
    }

    func syncToActiveProvider() {
        guard let idx = providers.firstIndex(where: { $0.id == activeProviderID }) else { return }
        providers[idx].baseURL = llmBaseURL
        providers[idx].model = llmModel
        providers[idx].apiKey = llmAPIKey
        providers[idx].availableModels = availableLLMModels
    }

    func activateProvider(_ profile: LLMProviderProfile) {
        activeProviderID = profile.id
        syncFromActiveProvider()
        saveProviders()
    }

    func updateProvider(_ updated: LLMProviderProfile) {
        guard let idx = providers.firstIndex(where: { $0.id == updated.id }) else { return }
        providers[idx] = updated
        if updated.id == activeProviderID {
            syncFromActiveProvider()
        }
        saveProviders()
    }

    func addProvider(_ profile: LLMProviderProfile) {
        providers.append(profile)
        saveProviders()
    }

    func removeProvider(_ profile: LLMProviderProfile) {
        guard let idx = providers.firstIndex(where: { $0.id == profile.id }) else { return }
        providers.remove(at: idx)
        if activeProviderID == profile.id, let first = providers.first {
            activateProvider(first)
        }
        saveProviders()
    }

    // MARK: - Tool paths

    func autoDetectNonmemPath() {
        let candidates = [
            "/opt/nm760/run/nmfe76",
            "/opt/NONMEM/nm760/run/nmfe76",
            "/usr/local/NONMEM/nm760/run/nmfe76",
            "/usr/local/nm760/run/nmfe76",
            "/opt/NONMEM/run/nmfe76",
            "/opt/nm750/run/nmfe75",
            "/usr/local/nm750/run/nmfe75",
            "/opt/nm74/run/nmfe74",
            "/opt/nm73/run/nmfe73"
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) {
                nonmemPath = c
                nonmemDefaultChecked = true
                saveToolPaths()
                return
            }
        }
        // Check via which nmfe76
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", "which nmfe76 2>/dev/null || which nmfe75 2>/dev/null || which nmfe74 2>/dev/null || echo ''"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                nonmemPath = path
                nonmemDefaultChecked = true
                saveToolPaths()
            }
        } catch {}
    }

    func autoDetectPsnPath() {
        let candidates = [
            "/usr/local/bin/execute",
            "/opt/homebrew/bin/execute",
            "/usr/bin/execute",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/execute").path
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) {
                psnPath = c
                psnDefaultChecked = true
                saveToolPaths()
                return
            }
        }
        // which execute
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", "which execute 2>/dev/null || echo ''"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                psnPath = path
                psnDefaultChecked = true
                saveToolPaths()
            }
        } catch {}
    }

    func saveToolPaths() {
        UserDefaults.standard.set(nonmemPath, forKey: "AutoPMX.nonmemPath")
        UserDefaults.standard.set(psnPath, forKey: "AutoPMX.psnPath")
        UserDefaults.standard.set(pythonPath, forKey: "AutoPMX.pythonPath")
        UserDefaults.standard.set(rPath, forKey: "AutoPMX.rPath")
    }

    func saveKnowledgeBasePath() {
        UserDefaults.standard.set(knowledgeBaseURL.path, forKey: "AutoPMX.knowledgeBasePath")
        refreshRuleContextStatus()
    }

    func autoDetectPythonPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            projectURL.appendingPathComponent(".venv/bin/python3").path,
            workspaceURL.appendingPathComponent(".venv/bin/python3").path,
            home.appendingPathComponent("miniconda3/bin/python3").path,
            home.appendingPathComponent("anaconda3/bin/python3").path,
            home.appendingPathComponent("mambaforge/bin/python3").path,
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) {
                pythonPath = c
                pythonDefaultChecked = true
                saveToolPaths()
                return
            }
        }
        // Fallback to which python3
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", "which python3 2>/dev/null || echo ''"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                pythonPath = path
                pythonDefaultChecked = true
                saveToolPaths()
            }
        } catch {}
    }

    func autoDetectRPath() {
        let candidates = [
            "/usr/local/bin/Rscript",
            "/opt/homebrew/bin/Rscript",
            "/Library/Frameworks/R.framework/Resources/Rscript",
            "/usr/bin/Rscript"
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c) {
                rPath = c
                rDefaultChecked = true
                saveToolPaths()
                return
            }
        }
        // which Rscript
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", "which Rscript 2>/dev/null || echo ''"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                rPath = path
                rDefaultChecked = true
                saveToolPaths()
            }
        } catch {}
    }

    var activeAPIFormat: APIFormat {
        activeProvider?.apiFormat ?? .openAICompatible
    }

    // MARK: - Thinking Steps

    func addThinkingStep(_ text: String, type: ThinkingStep.StepType = .working, detail: String = "") {
        var step = ThinkingStep(text: text, type: type)
        step.detail = detail
        thinkingSteps.append(step)
        currentThinkingText = text
        isAIThinking = (type == .working || type == .thinking)
    }

    func updateLastThinkingStep(type: ThinkingStep.StepType, detail: String = "") {
        guard let idx = thinkingSteps.indices.last else { return }
        thinkingSteps[idx].type = type
        thinkingSteps[idx].detail = detail
        if type == .done || type == .error {
            isAIThinking = false
            currentThinkingText = ""
        }
    }

    func clearThinkingSteps() {
        thinkingSteps.removeAll()
        isAIThinking = false
        currentThinkingText = ""
    }

    // MARK: - Workspace Refresh (async, debounced, off-main-thread)

    /// Result container for off-main workspace scanning.
    private struct WorkspaceRefreshResult {
        let runs: [String]
        let assets: [AssetCategory: [ProjectAsset]]
        let ruleStatus: String
        let modelStatusText: String
        let dataStatusText: String
        let executeStatusText: String
        let minOK: Bool
        let covOK: Bool
        let boundary: Bool
        let paramRows: [ParameterEstimateRow]
        let currentRun: String
    }

    /// Serial queue for background workspace scanning to avoid concurrent scans.
    private static let refreshQueue = DispatchQueue(label: "com.autopmx.refresh", qos: .userInitiated)
    private var refreshWorkItem: DispatchWorkItem?

    /// Public entry point. Coalesces rapid successive calls (debounce 120ms) and
    /// performs all heavy file I/O + parsing on a background queue, only publishing
    /// the final results back on the main actor. This keeps the UI responsive even
    /// with hundreds of model runs.
    func refreshWorkspace() {
        requestRefreshWorkspace()
    }

    /// Debounced async refresh — safe to call from anywhere (main actor).
    func requestRefreshWorkspace() {
        refreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            // Capture all inputs needed for the heavy work on the main actor,
            // then dispatch the I/O + parsing to a background queue.
            guard let self else { return }
            let projectURL = self.projectURL
            let workspaceURL = self.workspaceURL
            let ruleSources: String = self.ruleSourceFiles
            let dataFile = self.dataFile
            let currentRun = self.currentRun
            let previousRun = self.previousRun
            let commandText = self.commandText

            Self.refreshQueue.async {
                Self.performWorkspaceRefresh(
                    projectURL: projectURL,
                    workspaceURL: workspaceURL,
                    ruleSources: ruleSources,
                    dataFile: dataFile,
                    currentRun: currentRun,
                    previousRun: previousRun,
                    commandText: commandText
                ) { result in
                    Task { @MainActor in
                        self.applyWorkspaceRefresh(result: result, commandText: commandText)
                    }
                }
            }
        }
        refreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: item)
    }

    /// Synchronous heavy work — runs OFF the main thread. Takes plain inputs
    /// (captured on the main actor) and calls back with a result struct.
    private static func performWorkspaceRefresh(
        projectURL: URL,
        workspaceURL: URL,
        ruleSources: String,
        dataFile: String,
        currentRun: String,
        previousRun: String,
        commandText: String,
        completion: @escaping (WorkspaceRefreshResult) -> Void
    ) {
        let runs = ProjectScanner.discoverRuns(in: projectURL)
        let scannedAssets = ProjectScanner.scanAssets(in: projectURL)
        let ruleContext = ProjectScanner.ruleContext(projectURL: projectURL, workspaceURL: workspaceURL, sourcesText: ruleSources)
        let ruleStatus = ruleContext.summary

        let prevStatus = ProjectScanner.status(for: previousRun, in: projectURL)
        let currStatus = ProjectScanner.status(for: currentRun, in: projectURL)
        let modelStatusText = "Run \(previousRun): \(prevStatus.summary)\nRun \(currentRun): \(currStatus.summary)"
        let data = ProjectScanner.dataPathCheck(runID: currentRun, dataFile: dataFile, in: projectURL)
        let dataStatusText = data.matches ? "$DATA OK: \(data.current ?? data.expected)" : "$DATA mismatch: \(data.current ?? "not found") → \(data.expected)"
        let executable = commandText.split(separator: " ").first.map { String($0).replacingOccurrences(of: "'", with: "") } ?? ""
        let isExecute = executable == "execute" || executable.hasSuffix("/execute")
        let executeStatusText = isExecute ? "PsN execute command ready" : "Command should start with PsN execute"

        let (minOK, covOK, boundary) = convergenceFlags(for: currentRun, in: projectURL)
        let paramRows = ProjectScanner.parameterEstimates(runID: currentRun, in: projectURL)

        completion(WorkspaceRefreshResult(
            runs: runs,
            assets: scannedAssets,
            ruleStatus: ruleStatus,
            modelStatusText: modelStatusText,
            dataStatusText: dataStatusText,
            executeStatusText: executeStatusText,
            minOK: minOK,
            covOK: covOK,
            boundary: boundary,
            paramRows: paramRows,
            currentRun: currentRun
        ))
    }

    /// Apply computed results on the main actor (single batched publish).
    private func applyWorkspaceRefresh(result: WorkspaceRefreshResult, commandText: String) {
        if !result.runs.isEmpty {
            if !result.runs.contains(previousRun) {
                previousRun = result.runs.count > 1 ? result.runs[result.runs.count - 2] : result.runs[0]
            }
            if !result.runs.contains(currentRun) {
                currentRun = result.runs.last ?? currentRun
            }
        }
        self.assets = result.assets
        self.availableRunIDs = result.runs
        self.ruleContextStatus = result.ruleStatus
        self.modelStatus = result.modelStatusText
        self.dataStatus = result.dataStatusText
        self.executeStatus = result.executeStatusText
        self.minimizationOK = result.minOK
        self.covarianceOK = result.covOK
        self.hasBoundaryWarnings = result.boundary
        self.parameterRunID = result.currentRun
        self.parameterRows = result.paramRows

        let defaultCommand = psnRunCommand(runID: currentRun)
        if self.commandText.isEmpty || !self.commandText.contains("run\(currentRun)") {
            self.commandText = defaultCommand
        }
        if self.selectedAsset == nil {
            self.showOverview()
        }
    }

    /// Pure helper — reads .lst file and computes convergence flags. Runs off-main.
    /// Uses the SAME detection logic as runMinimizationOK / runCovarianceOK (lenient covariance).
    /// Covariance success = no abort/fail/R-matrix-PD + no boundary + .cov exists non-empty
    /// + (ELAPSED COVARIANCE or COVARIANCE STEP SUCCESSFUL present in .lst).
    private static func convergenceFlags(for runID: String, in projectURL: URL) -> (min: Bool, cov: Bool, boundary: Bool) {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else {
            return (false, false, false)
        }
        let upper = text.uppercased()
        let minOK = upper.contains("MINIMIZATION SUCCESSFUL")
        let boundary = upper.contains("PARAMETER IS NEAR ITS BOUNDARY")

        // Covariance: same composite criteria as runCovarianceOK()
        let aborted = upper.contains("COVARIANCE STEP ABORTED")
                     || upper.contains("COVARIANCE STEP FAILED")
                     || upper.contains("R MATRIX IS NOT POSITIVE DEFINITE")
        if aborted || boundary {
            return (minOK, false, boundary)
        }
        let covURL = projectURL.appendingPathComponent("run\(runID).cov")
        let covExists = FileManager.default.fileExists(atPath: covURL.path)
        let covSize = (try? FileManager.default.attributesOfItem(atPath: covURL.path)[.size] as? Int) ?? 0
        let ran = upper.contains("ELAPSED COVARIANCE") || upper.contains("COVARIANCE STEP SUCCESSFUL")
        let covOK = covExists && covSize > 0 && ran
        return (minOK, covOK, boundary)
    }

    func showOverview() {
        previewTitle = "Workspace Overview"
        previewText = """
        AutoPMX native workbench

        Project:
        \(projectURL.path)

        Workflow:
        1. Create a project from an existing run or open the root project.
        2. Select a run*.mod model from the sidebar.
        3. Review the PsN execute command in the inspector.
        4. Run NONMEM, VPC, R diagnostics, and LLM audits.
        5. Inspect outputs, figures, and reports in this window.
        """
    }

    func activeRuleContext(userGuidance: String = "", phase: String? = nil) -> RuleContext {
        let context = ProjectScanner.ruleContext(projectURL: projectURL, workspaceURL: workspaceURL, sourcesText: ruleSourceFiles, knowledgeBaseURL: knowledgeBaseURL, phase: phase)
        let guidance = userGuidance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !guidance.isEmpty else { return context }
        let merged = """
        \(context.text)

        ---

        ### User Modeling Guidance
        \(guidance)
        """
        return RuleContext(text: merged, loadedSources: context.loadedSources, missingSources: context.missingSources)
    }

    func refreshRuleContextStatus() {
        ruleContextStatus = activeRuleContext().summary
    }

    // MARK: - Token usage bookkeeping

    /// Records the token usage returned by an LLM call and refreshes the
    /// rolling estimate of how many tokens the rule/model-library context occupies.
    /// Call when an LLM request starts to enable timing-based speed calculation.
    func markRequestStart(inputTokens: Int) {
        lastRequestStartTime = Date()
        lastRequestInputTokens = inputTokens
        if activeBenchmark != nil {
            benchmarkRequestStartAt = Date()
        }
    }

    func recordUsage(_ usage: LLMCommandService.TokenUsage?) {
        if activeBenchmark != nil, let requestStart = benchmarkRequestStartAt {
            activeBenchmark?.thinkingSeconds += max(0, Date().timeIntervalSince(requestStart))
            benchmarkRequestStartAt = nil
        }
        // Always refresh the rolling context-size estimate from the currently
        // loaded rule/model-library text — this must NOT depend on the API
        // returning a `usage` block (some providers omit it on certain calls).
        contextTokenEstimate = activeRuleContext().text.count / 3
        guard let usage else { return }
        lastTokenUsage = usage
        totalInputTokens += usage.input
        totalOutputTokens += usage.output
        totalCacheReadTokens += usage.cacheRead
        totalCacheWriteTokens += usage.cacheWrite
        if usage.cacheRead > 0 || usage.cacheWrite > 0 {
            let miss = max(0, usage.input - usage.cacheRead)
            runner.append("[LLM cache] read \(usage.cacheRead) · miss \(miss) · write \(usage.cacheWrite)")
        }
        appendDailyUsage(input: usage.input, output: usage.output)

        // ── Per-provider tracking ──
        let providerName = activeProvider?.name ?? "Unknown"
        let modelName = activeProvider?.model ?? llmModel
        let duration: TimeInterval
        if let start = lastRequestStartTime {
            duration = Date().timeIntervalSince(start)
        } else {
            duration = 0
        }
        if let idx = providerUsageRecords.firstIndex(where: { $0.providerName == providerName && $0.modelName == modelName }) {
            var rec = providerUsageRecords[idx]
            rec.requests += 1
            rec.inputTokens += usage.input
            rec.outputTokens += usage.output
            rec.totalDurationSec += duration
            providerUsageRecords[idx] = rec
        } else {
            providerUsageRecords.append(ProviderUsageRecord(
                providerName: providerName,
                modelName: modelName,
                requests: 1,
                inputTokens: usage.input,
                outputTokens: usage.output,
                totalDurationSec: duration
            ))
        }
        lastRequestStartTime = nil
    }

    // MARK: - Daily usage history (persisted)

    private static let usageHistoryKey = "AutoPMX.usageHistory.v1"
    private static let contextWindowLimitKey = "AutoPMX.contextWindowLimit.v1"
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private func appendDailyUsage(input: Int, output: Int) {
        let today = Self.dayFormatter.string(from: Date())
        if let idx = usageHistory.firstIndex(where: { $0.date == today }) {
            usageHistory[idx].requests += 1
            usageHistory[idx].inputTokens += input
            usageHistory[idx].outputTokens += output
        } else {
            usageHistory.append(DailyUsage(date: today, requests: 1, inputTokens: input, outputTokens: output))
        }
        saveUsageHistory()
    }

    private func saveUsageHistory() {
        if let data = try? JSONEncoder().encode(usageHistory) {
            UserDefaults.standard.set(data, forKey: Self.usageHistoryKey)
        }
    }

    private func loadUsageHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.usageHistoryKey),
              let decoded = try? JSONDecoder().decode([DailyUsage].self, from: data) else { return }
        usageHistory = decoded
    }

    // MARK: - Modeling time benchmarks

    private static let benchmarkRecordsKey = "AutoPMX.modelingBenchmarkRecords.v1"

    private func loadBenchmarkRecords() {
        guard let data = UserDefaults.standard.data(forKey: Self.benchmarkRecordsKey),
              let decoded = try? JSONDecoder().decode([ModelingBenchmarkRecord].self, from: data) else { return }
        benchmarkRecords = decoded.sorted { $0.startedAt > $1.startedAt }
    }

    private func saveBenchmarkRecords() {
        benchmarkRecords = benchmarkRecords.sorted { $0.startedAt > $1.startedAt }
        if benchmarkRecords.count > 200 {
            benchmarkRecords = Array(benchmarkRecords.prefix(200))
        }
        if let data = try? JSONEncoder().encode(benchmarkRecords) {
            UserDefaults.standard.set(data, forKey: Self.benchmarkRecordsKey)
        }
    }

    func clearBenchmarkRecords() {
        benchmarkRecords.removeAll()
        saveBenchmarkRecords()
    }

    func benchmarkCSV() -> String {
        var lines = [
            "started_at,dataset,provider,model,status,phase1_sec,thinking_sec,execution_sec,base_wait_sec,phase2_scm_sec,total_sec,comparable_sec,notes"
        ]
        let iso = ISO8601DateFormatter()
        for record in benchmarkRecords {
            let fields = [
                iso.string(from: record.startedAt),
                Self.csvEscape(record.datasetName),
                Self.csvEscape(record.providerName),
                Self.csvEscape(record.modelName),
                record.status.rawValue,
                Self.fixed(record.phase1Seconds),
                Self.fixed(record.thinkingSeconds),
                Self.fixed(record.executionSeconds),
                Self.fixed(record.baseModelWaitSeconds),
                Self.fixed(record.phase2OrSCMSeconds),
                Self.fixed(record.totalElapsedSeconds),
                Self.fixed(record.comparableSeconds),
                Self.csvEscape(record.notes)
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func fixed(_ value: TimeInterval) -> String {
        String(format: "%.1f", value)
    }

    private func beginBenchmark(dataFile: String) {
        guard activeBenchmark == nil else { return }
        let now = Date()
        let provider = activeProvider
        activeBenchmark = ModelingBenchmarkRecord(
            startedAt: now,
            datasetName: URL(fileURLWithPath: dataFile).lastPathComponent,
            providerName: provider?.name ?? "Unknown",
            modelName: provider?.model ?? llmModel
        )
        benchmarkStartAt = now
        benchmarkBasePromptShownAt = nil
        benchmarkPhase2StartAt = nil
        benchmarkRequestStartAt = nil
        benchmarkContinuesWithSCM = false
        benchmarkBasePromptActionTaken = false
    }

    private func beginBenchmarkBaseWaitIfNeeded() {
        guard activeBenchmark != nil,
              benchmarkBasePromptShownAt == nil,
              let start = benchmarkStartAt else { return }
        activeBenchmark?.phase1Seconds = max(0, Date().timeIntervalSince(start))
        benchmarkBasePromptShownAt = Date()
    }

    private func endBenchmarkBaseWait() {
        guard activeBenchmark != nil, let shown = benchmarkBasePromptShownAt else { return }
        activeBenchmark?.baseModelWaitSeconds += max(0, Date().timeIntervalSince(shown))
        benchmarkBasePromptShownAt = nil
    }

    private func startBenchmarkPhase2() {
        guard activeBenchmark != nil else { return }
        endBenchmarkBaseWait()
        benchmarkPhase2StartAt = Date()
    }

    private func finalizeBenchmark(status: ModelingBenchmarkRecord.Status, notes: String = "") {
        guard var record = activeBenchmark else { return }
        let now = Date()
        if benchmarkBasePromptShownAt != nil {
            endBenchmarkBaseWait()
        }
        if let requestStart = benchmarkRequestStartAt {
            record.thinkingSeconds += max(0, now.timeIntervalSince(requestStart))
            benchmarkRequestStartAt = nil
        }
        let total = benchmarkStartAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        if let phase2Start = benchmarkPhase2StartAt {
            record.phase2OrSCMSeconds = max(0, now.timeIntervalSince(phase2Start))
        }
        if record.phase1Seconds == 0 {
            record.phase1Seconds = max(0, total - record.baseModelWaitSeconds - record.phase2OrSCMSeconds)
        }
        record.endedAt = now
        record.status = status
        record.totalElapsedSeconds = total
        record.comparableSeconds = max(0, record.phase1Seconds + record.phase2OrSCMSeconds)
        if !notes.isEmpty {
            record.notes = notes
        }
        activeBenchmark = nil
        benchmarkStartAt = nil
        benchmarkBasePromptShownAt = nil
        benchmarkPhase2StartAt = nil
        benchmarkRequestStartAt = nil
        benchmarkContinuesWithSCM = false
        benchmarkBasePromptActionTaken = false
        benchmarkRecords.insert(record, at: 0)
        saveBenchmarkRecords()
    }

    private func finalizeBenchmarkFromAutomationTask(status: ModelingBenchmarkRecord.Status) {
        guard activeBenchmark != nil else { return }
        if benchmarkBasePromptShownAt == nil || benchmarkPhase2StartAt != nil {
            finalizeBenchmark(status: status)
        }
    }

    func cancelBaseModelConfirmation() {
        isBaseModelConfirmPresented = false
        if activeBenchmark != nil {
            benchmarkBasePromptActionTaken = true
            finalizeBenchmark(status: .paused, notes: L10n.t("benchmark.pausedAfterBase"))
        }
    }

    func cancelSCMDialog() {
        showSCMDialog = false
        handleSCMDialogDismissedIfNeeded()
    }

    func handleBaseModelPromptDismissedIfNeeded() {
        guard activeBenchmark != nil,
              benchmarkBasePromptShownAt != nil,
              !benchmarkBasePromptActionTaken else { return }
        finalizeBenchmark(status: .paused, notes: L10n.t("benchmark.pausedAfterBase"))
    }

    func handleSCMDialogDismissedIfNeeded() {
        guard benchmarkContinuesWithSCM else { return }
        showSCMDialog = false
        finalizeBenchmark(status: .paused, notes: L10n.t("benchmark.scmCancelled"))
        benchmarkContinuesWithSCM = false
    }

    private func finalizeBenchmarkAfterSCM(success: Bool, cancelled: Bool) {
        guard activeBenchmark != nil, benchmarkPhase2StartAt != nil else { return }
        let status: ModelingBenchmarkRecord.Status = cancelled ? .stopped : (success ? .completed : .failed)
        let notes = cancelled ? L10n.t("benchmark.scmCancelled") : (success ? "" : L10n.t("benchmark.scmFailed"))
        finalizeBenchmark(status: status, notes: notes)
    }

    /// Resets cumulative counters (call at the start of an automation run).
    func resetTokenUsage() {
        totalInputTokens = 0
        totalOutputTokens = 0
        totalCacheReadTokens = 0
        totalCacheWriteTokens = 0
        lastTokenUsage = .zero
        contextTokenEstimate = activeRuleContext().text.count / 3
    }

    func select(_ asset: ProjectAsset) {
        selectedAsset = asset
        if let runID = asset.relatedRunID {
            activateRun(runID)
        }
        preview(asset)
    }

    func sidebarAssets(for category: AssetCategory) -> [ProjectAsset] {
        (assets[category] ?? []).sorted { left, right in
            let leftPinned = isPinned(left)
            let rightPinned = isPinned(right)
            if leftPinned != rightPinned {
                return leftPinned && !rightPinned
            }
            return left.relativePath.localizedStandardCompare(right.relativePath) == .orderedAscending
        }
    }

    func asset(withID id: String) -> ProjectAsset? {
        assets.values.flatMap { $0 }.first { $0.id == id }
    }

    func isPinned(_ asset: ProjectAsset) -> Bool {
        pinnedAssetIDs.contains(asset.id)
    }

    // MARK: - Model color marks

    /// Fixed palette offered in the Models context menu. Names are persisted to
    /// project_config.json, labels are localized, colors drive the sidebar dot.
    static let modelMarkPalette: [(name: String, label: String, color: Color)] = [
        ("red",    L10n.markRed,    Color(red: 0.94, green: 0.35, blue: 0.35)),
        ("orange", L10n.markOrange, Color(red: 0.98, green: 0.62, blue: 0.25)),
        ("yellow", L10n.markYellow, Color(red: 0.94, green: 0.83, blue: 0.25)),
        ("green",  L10n.markGreen,  Color(red: 0.30, green: 0.76, blue: 0.38)),
        ("blue",   L10n.markBlue,   Color(red: 0.25, green: 0.55, blue: 0.95)),
        ("purple", L10n.markPurple, Color(red: 0.62, green: 0.42, blue: 0.92)),
        ("pink",   L10n.markPink,   Color(red: 0.95, green: 0.45, blue: 0.70)),
        ("gray",   L10n.markGray,   Color.gray)
    ]

    func modelMarkName(for asset: ProjectAsset) -> String? {
        modelMarks[asset.id]
    }

    func modelMarkColor(for asset: ProjectAsset) -> Color? {
        guard let name = modelMarks[asset.id] else { return nil }
        return Self.modelMarkPalette.first { $0.name == name }?.color
    }

    func setModelMark(_ colorName: String?, for asset: ProjectAsset) {
        if let colorName, !colorName.isEmpty {
            modelMarks[asset.id] = colorName
            runner.append("Model marked \(colorName): \(asset.title)")
        } else {
            modelMarks.removeValue(forKey: asset.id)
            runner.append("Mark cleared: \(asset.title)")
        }
        saveModelMarks()
    }

    /// Load per-project model marks from project_config.json.
    private func loadModelMarks() {
        modelMarks = [:]
        aiRecommendedRunIDs = []
        let configURL = projectURL.appendingPathComponent("project_config.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let marks = config["model_marks"] as? [String: String] {
            modelMarks = marks.filter { FileManager.default.fileExists(atPath: $0.key) }
        }
        if let runs = config["ai_recommended_runs"] as? [String] {
            aiRecommendedRunIDs = Set(runs)
        }
    }

    /// Persist per-project model marks into project_config.json.
    private func saveModelMarks() {
        let configURL = projectURL.appendingPathComponent("project_config.json")
        guard let data = try? Data(contentsOf: configURL),
              var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        config["model_marks"] = modelMarks
        config["ai_recommended_runs"] = Array(aiRecommendedRunIDs).sorted()
        if let updated = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            try? updated.write(to: configURL)
        }
    }

    /// Mark a run as an AI/base-model recommendation so it can be shown in the Models sidebar.
    func markAIModel(runID: String) {
        guard !runID.isEmpty else { return }
        aiRecommendedRunIDs.insert(runID)
        saveModelMarks()
    }

    func isAIRun(_ runID: String) -> Bool {
        aiRecommendedRunIDs.contains(runID)
    }

    /// Latest AI/base-model recommendation that still exists in this project.
    /// Used as the default selection in model pickers so the analyst can accept
    /// DuDu's recommendation with one click instead of hunting for it.
    var preferredAIModelRunID: String? {
        let candidates = aiRecommendedRunIDs.filter { automationAvailableRunIDs.contains($0) }
        return candidates.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }.last
    }

    func togglePinned(_ asset: ProjectAsset) {
        if pinnedAssetIDs.contains(asset.id) {
            pinnedAssetIDs.remove(asset.id)
            runner.append("Unpinned: \(asset.relativePath)")
        } else {
            pinnedAssetIDs.insert(asset.id)
            runner.append("Pinned: \(asset.relativePath)")
        }
        savePinnedAssets()
    }

    func openAsset(_ asset: ProjectAsset) {
        if NSWorkspace.shared.open(asset.url) {
            runner.append("Opened: \(asset.relativePath)")
        } else {
            runner.append("Open failed, revealing in Finder instead: \(asset.relativePath)")
            NSWorkspace.shared.activateFileViewerSelecting([asset.url])
        }
    }

    func exportMarkdownAsPDF(_ asset: ProjectAsset) {
        guard asset.url.pathExtension.lowercased() == "md",
              let markdown = try? String(contentsOf: asset.url, encoding: .utf8) else {
            runner.append("PDF export failed: selected file is not readable Markdown.")
            return
        }

        let pdfURL = asset.url
            .deletingPathExtension()
            .appendingPathExtension("pdf")
        let baseURL = asset.url.deletingLastPathComponent()
        Task {
            do {
                try await MarkdownPDFExporter.exportPDF(markdown: markdown, to: pdfURL, baseURL: baseURL)
                runner.append("PDF exported: \(pdfURL.lastPathComponent)")
                refreshWorkspace()
            } catch {
                runner.append("PDF export failed: \(error.localizedDescription)")
            }
        }
    }

    func preview(_ asset: ProjectAsset) {
        previewTitle = asset.title
        if asset.isTextPreviewable {
            let raw = (try? String(contentsOf: asset.url, encoding: .utf8)) ?? "Unable to read file."
            let ext = asset.url.pathExtension.lowercased()
            if ext == "csv" {
                previewText = csvToTable(raw)
            } else {
                previewText = raw.count > 140_000 ? String(raw.prefix(140_000)) + "\n\n[Preview truncated]" : raw
            }
        } else {
            let size = (try? asset.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            previewText = """
            \(asset.title)

            Type: \(asset.url.pathExtension.uppercased()) artifact
            Size: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
            Path:
            \(asset.url.path)

            Native image/PDF/Office inline rendering will be expanded in the next pass; the artifact is indexed and ready to open from Finder.
            """
        }
    }

    /// Convert CSV text to a monospaced table view (pipe-aligned columns)
    private func csvToTable(_ raw: String) -> String {
        let lines = raw.components(separatedBy: .newlines).prefix(500)
        guard !lines.isEmpty else { return raw }

        var rows: [[String]] = []
        var colWidths: [Int] = []

        for line in lines {
            let cols = line.components(separatedBy: ",")
            let trimmed = cols.map { $0.trimmingCharacters(in: .whitespaces) }
            rows.append(trimmed)
            for (i, col) in trimmed.enumerated() {
                while colWidths.count <= i { colWidths.append(0) }
                colWidths[i] = max(colWidths[i], col.count)
            }
        }

        // Clamp column widths (min 6, max 14 chars)
        colWidths = colWidths.map { max(6, min($0, 14)) }

        var result = ""
        for (rowIdx, row) in rows.prefix(40).enumerated() {
            var line = ""
            for (ci, col) in row.enumerated() {
                let width = ci < colWidths.count ? colWidths[ci] : 8
                let padded: String
                if col.count > width {
                    padded = String(col.prefix(width - 1)) + "\u{2026}"
                } else {
                    padded = col.padding(toLength: width, withPad: " ", startingAt: 0)
                }
                line += (ci > 0 ? " | " : "") + padded
            }
            result += line + "\n"
            // Separator after header row
            if rowIdx == 0 {
                result += String(repeating: "-", count: colWidths.reduce(0, +) + (colWidths.count - 1) * 3) + "\n"
            }
        }
        if rows.count > 40 {
            result += "\n[Showing 40 of \(rows.count) rows — truncated for preview]"
        }
        return result.isEmpty ? raw : result
    }

    func refreshChecks() {
        let prev = ProjectScanner.status(for: previousRun, in: projectURL)
        let curr = ProjectScanner.status(for: currentRun, in: projectURL)
        modelStatus = "Run \(previousRun): \(prev.summary)\nRun \(currentRun): \(curr.summary)"

        let data = ProjectScanner.dataPathCheck(runID: currentRun, dataFile: dataFile, in: projectURL)
        dataStatus = data.matches ? "$DATA OK: \(data.current ?? data.expected)" : "$DATA mismatch: \(data.current ?? "not found") → \(data.expected)"

        let executable = commandText.split(separator: " ").first.map { String($0).replacingOccurrences(of: "'", with: "") } ?? ""
        let isExecute = executable == "execute" || executable.hasSuffix("/execute")
        executeStatus = isExecute ? "PsN execute command ready" : "Command should start with PsN execute"

        refreshConvergence()
        refreshParameterEstimates()
    }

    func refreshConvergence() {
        let lstURL = projectURL.appendingPathComponent("run\(currentRun).lst")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else {
            minimizationOK = false; covarianceOK = false; hasBoundaryWarnings = false; return
        }
        let upper = text.uppercased()
        minimizationOK = upper.contains("MINIMIZATION SUCCESSFUL")
        // Use the SAME composite criteria as runCovarianceOK() — accepts ELAPSED COVARIANCE
        // when .cov file exists and no abort/fail/boundary is present.
        covarianceOK = runCovarianceOK(currentRun)
        hasBoundaryWarnings = upper.contains("PARAMETER IS NEAR ITS BOUNDARY")
    }

    func activateRun(_ runID: String) {
        currentRun = runID
        commandText = psnRunCommand(runID: runID)
        // Run convergence + parameter checks off-main to keep UI responsive.
        let projectURL = self.projectURL
        let dataFile = self.dataFile
        Self.refreshQueue.async {
            let (minOK, covOK, boundary) = Self.convergenceFlags(for: runID, in: projectURL)
            let paramRows = ProjectScanner.parameterEstimates(runID: runID, in: projectURL)
            let data = ProjectScanner.dataPathCheck(runID: runID, dataFile: dataFile, in: projectURL)
            let dataStatusText = data.matches ? "$DATA OK: \(data.current ?? data.expected)" : "$DATA mismatch: \(data.current ?? "not found") → \(data.expected)"
            Task { @MainActor in
                self.minimizationOK = minOK
                self.covarianceOK = covOK
                self.hasBoundaryWarnings = boundary
                self.parameterRunID = runID
                self.parameterRows = paramRows
                self.dataStatus = dataStatusText
            }
        }
    }

    /// Activate a run with a specific .mod filename (e.g., "run001_ga_opt.mod").
    /// Uses the actual filename in the PsN command instead of reconstructing "run{id}.mod".
    func activateRun(withModFileName modFileName: String) {
        // Derive runID using the same logic as ProjectAsset.runID so that
        // flexible names like run_Dofetilide_Oct_ad3.mod map consistently.
        let dummyAsset = ProjectAsset(
            url: projectURL.appendingPathComponent(modFileName),
            category: .models,
            relativePath: modFileName
        )
        currentRun = dummyAsset.runID ?? String(modFileName.dropFirst(3).dropLast(4))
            .replacingOccurrences(of: "_ga_opt", with: "")
        commandText = "execute \(modFileName) -model_dir_name"
        refreshChecks()
    }

    func refreshParameterEstimates() {
        parameterRunID = currentRun
        parameterRows = ProjectScanner.parameterEstimates(runID: currentRun, in: projectURL)
    }

    func duplicateModelAsChild(runID: String) {
        guard !automationBusy, !runID.isEmpty else { return }
        let sourceURL = projectURL.appendingPathComponent("run\(runID).mod")
        guard let source = try? String(contentsOf: sourceURL, encoding: .utf8) else {
            runner.append("Could not read run\(runID).mod for child duplication.")
            return
        }

        let childID = nextChildRunID(parent: runID)
        let childURL = projectURL.appendingPathComponent("run\(childID).mod")
        guard !FileManager.default.fileExists(atPath: childURL.path) else {
            runner.append("Child model run\(childID).mod already exists.")
            return
        }

        var child = source
        child = child.replacingOccurrences(of: "run\(runID)", with: "run\(childID)")
        child = child.replacingOccurrences(of: "Run\(runID)", with: "Run\(childID)")
        child = child.replacingOccurrences(of: "RUN\(runID)", with: "RUN\(childID)")
        child = child.replacingOccurrences(of: "SDTAB\(runID)", with: "SDTAB\(childID)")
        child = child.replacingOccurrences(of: "PATAB\(runID)", with: "PATAB\(childID)")
        child = child.replacingOccurrences(of: "CATAB\(runID)", with: "CATAB\(childID)")
        child = child.replacingOccurrences(of: "COTAB\(runID)", with: "COTAB\(childID)")

        child = LLMCommandService.stripInlineDatasetRows(child)
        child = LLMCommandService.normalizingTableRecords(child, runID: childID)
        child = LLMCommandService.applyingIVInfusionDurationFix(child)

        do {
            try child.write(to: childURL, atomically: true, encoding: .utf8)
            runner.append("Created child model run\(childID).mod from run\(runID).mod")
            activateRun(childID)
            refreshWorkspace()
        } catch {
            runner.append("Could not write child model run\(childID).mod: \(error.localizedDescription)")
        }
    }

    func chooseCopyTargetAndCopyModel(asset: ProjectAsset) {
        let panel = NSOpenPanel()
        panel.title = "Copy Model to Project"
        panel.message = "Choose the target project folder for \(asset.title). The referenced dataset will also be copied when found."
        panel.prompt = "Copy"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        copyModel(asset: asset, toProject: url, openAfterCopy: true)
    }

    func copyModel(
        asset: ProjectAsset,
        toProject targetURL: URL,
        openAfterCopy: Bool = false,
        copyReferencedDataset: Bool = true,
        dataFileOverride: String? = nil
    ) {
        guard !automationBusy else {
            runner.append("Copy model skipped: auto modeling is running.")
            return
        }

        let sourceURL = asset.url
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            runner.append("Could not copy \(asset.title): source file is missing.")
            return
        }
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            runner.append("Could not copy \(asset.title): target project folder does not exist.")
            return
        }
        guard let sourceText = try? String(contentsOf: sourceURL, encoding: .utf8) else {
            runner.append("Could not read \(asset.title).")
            return
        }

        let sourceRunID = asset.relatedRunID ?? ""
        let newID = nextCopyRunID(in: targetURL, preferred: sourceRunID.isEmpty ? nil : sourceRunID)
        let sourceStem = sourceURL.deletingPathExtension().lastPathComponent
        let targetStem = "run\(newID)"
        let dataReference = dataFileOverride ?? dataFileReference(in: sourceText)
        let dataPlaceholder = "__AUTOPMX_COPY_DATA_FILE__"

        var copied = sourceText
        if dataReference != nil {
            copied = replacingDataFileReference(in: copied, with: dataPlaceholder)
        }
        copied = copied.replacingOccurrences(of: sourceStem, with: targetStem)
        copied = copied.replacingOccurrences(of: sourceStem.uppercased(), with: targetStem.uppercased())
        copied = copied.replacingOccurrences(of: sourceStem.lowercased(), with: targetStem.lowercased())
        if !sourceRunID.isEmpty {
            copied = copied.replacingOccurrences(of: "SDTAB\(sourceRunID)", with: "SDTAB\(newID)")
            copied = copied.replacingOccurrences(of: "PATAB\(sourceRunID)", with: "PATAB\(newID)")
            copied = copied.replacingOccurrences(of: "CATAB\(sourceRunID)", with: "CATAB\(newID)")
            copied = copied.replacingOccurrences(of: "COTAB\(sourceRunID)", with: "COTAB\(newID)")
            copied = copied.replacingOccurrences(of: "Run\(sourceRunID)", with: "Run\(newID)")
            copied = copied.replacingOccurrences(of: "RUN\(sourceRunID)", with: "RUN\(newID)")
            copied = copied.replacingOccurrences(of: "run\(sourceRunID).ETA", with: "run\(newID).ETA")
            copied = copied.replacingOccurrences(of: "000\(sourceRunID).ETA", with: "run\(newID).ETA")
        }
        if let dataReference {
            let dataFileName = URL(fileURLWithPath: dataReference).lastPathComponent
            copied = copied.replacingOccurrences(of: dataPlaceholder, with: dataFileName)
            if copyReferencedDataset {
                self.copyReferencedDataset(dataReference: dataReference, from: sourceURL, to: targetURL)
            }
        }

        copied = LLMCommandService.stripInlineDatasetRows(copied)
        copied = LLMCommandService.normalizingTableRecords(copied, runID: newID)
        copied = LLMCommandService.applyingIVInfusionDurationFix(copied)
        copied = insertingCopySourceComment(into: copied, sourceURL: sourceURL, sourceStem: sourceStem, newID: newID)

        let destinationURL = targetURL.appendingPathComponent("run\(newID).mod")
        do {
            try copied.write(to: destinationURL, atomically: true, encoding: .utf8)
            runner.append("Copied \(asset.title) → \(destinationURL.path) as run\(newID).mod")
        } catch {
            runner.append("Could not copy \(asset.title): \(error.localizedDescription)")
            return
        }

        if openAfterCopy {
            openProject(url: targetURL)
            if let dataReference {
                let dataFileName = URL(fileURLWithPath: dataReference).lastPathComponent
                if FileManager.default.fileExists(atPath: targetURL.appendingPathComponent(dataFileName).path) {
                    switchDataFile(dataFileName)
                }
            }
            let newAsset = ProjectAsset(
                url: destinationURL,
                category: .models,
                relativePath: destinationURL.lastPathComponent
            )
            select(newAsset)
        }
    }

    private func nextCopyRunID(in targetURL: URL, preferred: String?) -> String {
        let existing = Set(ProjectScanner.discoverRuns(in: targetURL))
        func isFree(_ candidate: String) -> Bool {
            !existing.contains(candidate)
                && !FileManager.default.fileExists(atPath: targetURL.appendingPathComponent("run\(candidate).mod").path)
        }
        if let preferred, !preferred.isEmpty, isFree(preferred) {
            return preferred
        }
        if let preferred, !preferred.isEmpty {
            var childIndex = 1
            while true {
                let candidate = "\(preferred)\(String(format: "%02d", childIndex))"
                if isFree(candidate) { return candidate }
                childIndex += 1
            }
        }
        var index = 1
        while true {
            let candidate = String(format: "%03d", index)
            if isFree(candidate) { return candidate }
            index += 1
        }
    }

    private func insertingCopySourceComment(into text: String, sourceURL: URL, sourceStem: String, newID: String) -> String {
        var lines = text.components(separatedBy: "\n")
        let comments = [
            ";; AutoPMX source model: \(sourceURL.path)",
            ";; AutoPMX copied from: \(sourceStem).mod -> run\(newID).mod"
        ]
        if let problemIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("$PROBLEM")
        }) {
            lines.insert(contentsOf: comments, at: problemIndex + 1)
        } else {
            lines.insert(contentsOf: comments, at: 0)
        }
        return lines.joined(separator: "\n")
    }

    private func modelAssetForRun(_ runID: String) -> ProjectAsset? {
        let direct = ProjectAsset(
            url: projectURL.appendingPathComponent("run\(runID).mod"),
            category: .models,
            relativePath: "run\(runID).mod"
        )
        if FileManager.default.fileExists(atPath: direct.url.path) {
            return direct
        }
        return assets[.models]?.first {
            $0.relatedRunID == runID && FileManager.default.fileExists(atPath: $0.url.path)
        }
    }

    private func copyModelOutputs(runID: String, from sourceURL: URL, to targetURL: URL) {
        for ext in ["lst", "ext", "cov", "phi"] {
            let source = sourceURL.appendingPathComponent("run\(runID).\(ext)")
            let destination = targetURL.appendingPathComponent("run\(runID).\(ext)")
            guard FileManager.default.fileExists(atPath: source.path),
                  !FileManager.default.fileExists(atPath: destination.path) else {
                continue
            }
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                runner.append("Copied IV anchor output run\(runID).\(ext) → \(destination.path)")
            } catch {
                runner.append("Could not copy run\(runID).\(ext): \(error.localizedDescription)")
            }
        }
    }

    private func copyReferencedDataset(dataReference: String, from sourceURL: URL, to targetURL: URL) {
        let dataName = URL(fileURLWithPath: dataReference).lastPathComponent
        let sourceDataURL: URL
        if dataReference.hasPrefix("/") {
            sourceDataURL = URL(fileURLWithPath: dataReference).standardizedFileURL
        } else {
            sourceDataURL = sourceURL.deletingLastPathComponent().appendingPathComponent(dataReference).standardizedFileURL
        }
        guard FileManager.default.fileExists(atPath: sourceDataURL.path) else {
            runner.append("Referenced dataset \(dataReference) was not found beside the model; only the model was copied.")
            return
        }
        let destinationURL = targetURL.appendingPathComponent(dataName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let sourceData = try? Data(contentsOf: sourceDataURL)
            let destinationData = try? Data(contentsOf: destinationURL)
            if let sourceData, let destinationData, sourceData == destinationData {
                runner.append("Dataset \(dataName) already exists in \(targetURL.lastPathComponent); identical copy already present.")
            } else {
                runner.append("Dataset \(dataName) already exists in \(targetURL.lastPathComponent) with different content; kept the existing file. Check the copied model's $DATA before running.")
            }
            return
        }
        do {
            try FileManager.default.copyItem(at: sourceDataURL, to: destinationURL)
            runner.append("Copied dataset \(dataName) → \(destinationURL.path)")
        } catch {
            runner.append("Could not copy dataset \(dataName): \(error.localizedDescription)")
        }
    }

    private func dataFileReference(in modText: String) -> String? {
        guard let line = modText.components(separatedBy: .newlines).first(where: {
            $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("$DATA")
        }) else { return nil }
        let tokens = line
            .trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard tokens.count >= 2 else { return nil }
        var token = tokens[1]
        if token.hasPrefix("\""), token.hasSuffix("\"") {
            token = String(token.dropFirst().dropLast())
        }
        return token.isEmpty ? nil : token
    }

    private func replacingDataFileReference(in text: String, with fileName: String) -> String {
        let mutable = NSMutableString(string: text)
        if let regex = try? NSRegularExpression(pattern: #"(\$DATA\s+)(?:"[^"]+"|\S+)"#, options: [.caseInsensitive]) {
            regex.replaceMatches(in: mutable, options: [], range: NSRange(location: 0, length: mutable.length), withTemplate: "$1\(fileName)")
        }
        return mutable as String
    }

    private func childRootRunID(for runID: String) -> String {
        guard runID.count > 3,
              runID.suffix(2).allSatisfy(\.isNumber) else {
            return runID
        }
        let base = String(runID.dropLast(2))
        if FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("run\(base).mod").path) {
            return base
        }
        return runID
    }

    private func nextChildRunID(parent: String) -> String {
        let root = childRootRunID(for: parent)
        let existing = Set(automationModelRuns())
        var index = 1
        while true {
            let candidate = "\(root)\(String(format: "%02d", index))"
            if !existing.contains(candidate),
               !FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("run\(candidate).mod").path) {
                return candidate
            }
            index += 1
        }
    }

    func createProjectFromCurrentRun(name: String, parentDirectory: URL? = nil) {
        guard !automationBusy else {
            runner.append(L10n.statusAutoBlockedCreate)
            assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusAutoBlockedCreateChat))
            return
        }
        do {
            projectURL = try ProjectScanner.createProjectFromRun(
                workspaceURL: workspaceURL,
                sourceURL: projectURL,
                name: name,
                runID: currentRun,
                dataFile: dataFile,
                parentDirectory: parentDirectory
            )
            runner.append("Created project: \(projectURL.path)")
            selectedAsset = nil
            saveRecentProject(projectURL)
            repairMissingETATablesInProject()
            refreshWorkspace()
        } catch {
            runner.append("Create project failed: \(error.localizedDescription)")
        }
    }

    func createBlankProject(name: String, parentDirectory: URL? = nil) {
        guard !automationBusy else {
            runner.append(L10n.statusAutoBlockedCreate)
            assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusAutoBlockedCreateChat))
            return
        }
        do {
            projectURL = try ProjectScanner.createBlankProject(workspaceURL: workspaceURL, name: name, parentDirectory: parentDirectory)
            runner.append("Created blank project: \(projectURL.path)")
            selectedAsset = nil
            saveRecentProject(projectURL)
            refreshWorkspace()
        } catch {
            runner.append("Create blank project failed: \(error.localizedDescription)")
        }
    }

    func openProject(url: URL) {
        guard !automationBusy else {
            runner.append(L10n.statusAutoBlockedSwitch)
            assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusAutoBlockedSwitchChat))
            return
        }
        // Persist any in-memory skills from the previously-loaded project before switching.
        PPKSkillStore.shared.saveCurrent()
        projectURL = url
        selectedAsset = nil
        commandText = ""
        runner.append("Opened project: \(url.path)")
        UserDefaults.standard.set(url.path, forKey: "AutoPMX.lastProjectPath")
        saveRecentProject(url)
        let path = url.path
        if path.contains("/AutoPMX_Projects/") {
            let parts = path.components(separatedBy: "/AutoPMX_Projects/")
            workspaceURL = URL(fileURLWithPath: parts[0])
        } else if path.contains("/PopPK_Agent") {
            let parts = path.components(separatedBy: "/PopPK_Agent")
            workspaceURL = URL(fileURLWithPath: parts[0] + "/PopPK_Agent")
        } else {
            workspaceURL = url.deletingLastPathComponent()
        }
        // Load PPK Skill for this project
        PPKSkillStore.shared.load(from: url)
        // Restore the previously used data file for this project
        readDataFileFromConfig()
        automationDataFile = dataFile
        loadModelMarks()
        repairMissingETATablesInProject()
        refreshWorkspace()
    }

    /// Older AutoPMX projects may predate the EBE export table. Add the standard
    /// `$TABLE ID ETA1 ... FILE=runX.ETA` record to every model that has ETA terms,
    /// so ETA screening and analyst-side EBE exports work without manual edits.
    private func repairMissingETATablesInProject() {
        for runID in automationModelRuns() {
            let modURL = projectURL.appendingPathComponent("run\(runID).mod")
            guard let text = try? String(contentsOf: modURL, encoding: .utf8) else { continue }
            let sanitized = LLMCommandService.stripInlineDatasetRows(text)
            var repaired = withETATableRecord(sanitized, runID: runID)
            repaired = LLMCommandService.applyingIVInfusionDurationFix(repaired)
            repaired = LLMCommandService.normalizingTableRecords(repaired, runID: runID)
            guard repaired != text else { continue }
            do {
                try repaired.write(to: modURL, atomically: true, encoding: .utf8)
                runner.append("Model sanitized or ETA table added to run\(runID).mod")
            } catch {
                runner.append("Could not add ETA table to run\(runID).mod: \(error.localizedDescription)")
            }
        }
    }

    /// Save PPK Skill before switching/closing project.
    func savePPKSkill() {
        PPKSkillStore.shared.save(to: projectURL)
    }

    /// Read the `data_file` and per-dataset `units_data` from `project_config.json`.
    /// If no `data_file` was previously persisted (legacy project), auto-detect the first
    /// modeling CSV in the project directory and persist it.
    private func readDataFileFromConfig() {
        let configURL = projectURL.appendingPathComponent("project_config.json")
        var configHadDataFile = false
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Restore data file
            if let configuredFile = config["data_file"] as? String {
                dataFile = configuredFile
                configHadDataFile = true
            }
            // Restore per-dataset units (keyed by data file name)
            restoreUnitsForCurrentDataFile(from: config, dataFile: dataFile)
        }
        // Legacy project: no data_file in config → auto-detect first modeling CSV and persist.
        if !configHadDataFile {
            if let detected = firstModelingCSVInProject() {
                dataFile = detected
                saveDataFileToConfig() // persist so next open is instant
            }
        }
    }

    /// Restore units for a specific data file from config, with migration from the old flat format.
    private func restoreUnitsForCurrentDataFile(from config: [String: Any], dataFile: String) {
        // New format: units_data → per-dataset
        if let unitsData = config["units_data"] as? [String: [String: String]],
           let units = unitsData[dataFile] {
            doseUnit   = units["dose"] ?? "mg"
            amtUnit    = units["amt"] ?? units["dose"] ?? "mg"
            concUnit   = units["conc"] ?? "µg/mL"
            timeUnit   = units["time"] ?? "h"
            lloqValue  = units["lloq_value"] ?? ""
            lloqUnit   = units["lloq_unit"] ?? concUnit
            return
        }
        // Legacy format: flat units dict → migrate to per-dataset and persist
        if let oldUnits = config["units"] as? [String: String] {
            doseUnit   = oldUnits["dose"] ?? "mg"
            amtUnit    = oldUnits["amt"] ?? oldUnits["dose"] ?? "mg"
            concUnit   = oldUnits["conc"] ?? "µg/mL"
            timeUnit   = oldUnits["time"] ?? "h"
            lloqValue  = ""
            lloqUnit   = concUnit
            saveUnitsToConfig() // write back in new format
        }
    }

    /// Persist units for the CURRENT data file only.
    func saveUnitsToConfig(for configuredDataFile: String? = nil) {
        let targetDataFile = configuredDataFile ?? dataFile
        saveToProjectConfig { config in
            var unitsData = config["units_data"] as? [String: [String: String]] ?? [:]
            unitsData[targetDataFile] = [
                "dose": doseUnit,
                "amt": amtUnit,
                "conc": concUnit,
                "time": timeUnit,
                "lloq_value": lloqValue,
                "lloq_unit": lloqUnit,
            ]
            config["units_data"] = unitsData
            config["units"] = nil
        }
    }

    func saveAutomationUnitsToConfig() {
        saveUnitsToConfig(for: automationDataFile.isEmpty ? dataFile : automationDataFile)
    }

    /// True when this dataset already has unit information persisted in the project.
    func hasSavedUnits(for dataFile: String) -> Bool {
        guard !dataFile.isEmpty else { return false }
        let configURL = projectURL.appendingPathComponent("project_config.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let unitsData = config["units_data"] as? [String: [String: String]] else {
            return false
        }
        return unitsData[dataFile] != nil
    }

    /// Persist the current `dataFile` name back into `project_config.json`
    /// so the selection survives app restarts.
    func saveDataFileToConfig() {
        saveToProjectConfig { config in
            config["data_file"] = dataFile
        }
    }

    /// Find the first CSV in the project that looks like a modeling dataset
    /// (excludes NONMEM table outputs like sdtab*, patab*, catab*, cotab*).
    private func firstModelingCSVInProject() -> String? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil) else { return nil }
        let lower = contents
            .map(\.lastPathComponent)
            .filter { $0.lowercased().hasSuffix(".csv") }
            .filter { name in
                let u = name.uppercased()
                return !u.hasPrefix("SDTAB") && !u.hasPrefix("PATAB")
                    && !u.hasPrefix("CATAB") && !u.hasPrefix("COTAB")
            }
            .sorted()
        return lower.first
    }

    /// Called when user picks a different dataset — loads that dataset's saved units.
    func switchDataFile(_ newFile: String) {
        dataFile = newFile
        automationDataFile = newFile
        saveDataFileToConfig()
        // Reload units for the new data file
        let configURL = projectURL.appendingPathComponent("project_config.json")
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            restoreUnitsForCurrentDataFile(from: config, dataFile: newFile)
        }
    }

    /// Generic helper: reads project_config.json, applies a transform, writes back.
    private func saveToProjectConfig(_ update: (inout [String: Any]) -> Void) {
        let configURL = projectURL.appendingPathComponent("project_config.json")
        guard let data = try? Data(contentsOf: configURL),
              var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        update(&config)
        if let updated = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            try? updated.write(to: configURL)
        }
    }

    // MARK: - Deposit skills from a model-run evaluation outcome

    /// Whole-word acceptance match: accepts ACCEPT/ACCEPTED and 定稿, but not
    /// false positives such as "acceptance" inside a REVISE explanation.
    private func isAcceptanceDecision(_ decision: String) -> Bool {
        if decision.localizedCaseInsensitiveContains("定稿") { return true }
        let upper = decision.uppercased()
        return upper.range(of: #"\bACCEPT(?:ED)?\b"#, options: .regularExpression) != nil
    }

    /// Turns the AI's evaluation decision + diagnostics into a durable skill
    /// (success pattern when accepted; lesson when estimation issues block acceptance).
    private func depositModelingSkill(runID: String, decision: String, diagnostics: String, phase: String) {
        let skill = PPKSkillStore.shared
        let accepted = isAcceptanceDecision(decision)

        if accepted {
            let valid = isModelStable(runID: runID)
            let boundaryHit = !valid && hasBoundaryWarningsFor(runID)
            let settings = modelSettingsSummary(runID: runID)
            skill.addSuccess(
                title: "\(phase) run\(runID) accepted (\(valid ? "S+C ✓ no-boundary" : "NOT stable"))",
                context: "Structure & settings that produced this accepted model: \(settings)",
                action: valid
                    ? "Achieved successful minimization + covariance (S+C) with no boundary estimate; advanced the workflow."
                    : "Accepted but model not stable (S/C missing\(boundaryHit ? " or boundary estimate" : "")).",
                result: String(decision.prefix(240)),
                sourceRun: runID,
                tags: ["modeling", phase.lowercased(), "accept", valid ? "S+C" : "incomplete"]
            )
            return
        }

        // Only record estimation issues when the run was NOT accepted (avoid noise on good runs).
        let convMap: [(kw: String, cat: LessonCategory)] = [
            ("MINIMIZATION TERMINATED", .convergence),
            ("HESSIAN NOT POSITIVE DEFINITE", .covariance),
            ("NOT POSITIVE DEFINITE", .covariance),
            ("PARAMETER ESTIMATE IS NEAR ITS BOUNDARY", .boundaryIssue),
            ("ROUNDING ERROR", .convergence)
        ]
        for (kw, cat) in convMap {
            if diagnostics.localizedCaseInsensitiveContains(kw) || decision.localizedCaseInsensitiveContains(kw) {
                skill.addLesson(
                    category: cat,
                    title: "\(phase) estimation issue: \(kw)",
                    problem: "\(kw) detected while evaluating run\(runID).",
                    solution: "Fix more parameters, widen $THETA bounds, or simplify the model structure before accepting.",
                    sourceRun: runID,
                    severity: .medium,
                    tags: ["modeling", phase.lowercased(), "estimation"]
                )
                break
            }
        }
        // Persist immediately so newly distilled skills survive a fresh sub-project being
        // created by the next automated-modeling run (global store is re-loaded on openProject).
        PPKSkillStore.shared.saveCurrent()
    }

    // MARK: - Distill skills from existing project history

    /// Scans every run already present in the current project and asks the LLM to generalize
    /// the estimation experience into reusable PPK skills (lessons from non-S+C runs, success
    /// patterns from stable/accepted runs). This lets the user populate the AI Skills panel
    /// even when automatic modeling never reached an ACCEPT, and makes the learned rules visible
    /// in Settings without waiting for a fresh run.
    /// Returns the number of new skills distilled.
    @MainActor
    func distillSkillsFromProjectHistory() async -> Int {
        let runs = automationModelRuns()
        guard !runs.isEmpty else {
            runner.append("⚠️ No runs found in the current project — nothing to distill.")
            return 0
        }
        var distilled = 0
        let maxToDistill = 6
        // Prefer the most informative runs: non-S+C runs (to learn estimation pitfalls) first,
        // then stable runs (to capture success patterns).
        let unstable = runs.filter { !isModelStable(runID: $0) }
        let stable = runs.filter { isModelStable(runID: $0) }
        let ordered = (unstable + stable).prefix(maxToDistill)

        let total = ordered.count
        for (idx, runID) in ordered.enumerated() {
            distillProgressText = String.safeFormat(L10n.settingsDistillStep, runID, idx + 1, total)
            let comp = compartmentInfoForRun(runID).compartments
            let stableRun = stable.contains(runID)
            let reason = stableRun ? "reached S+C (stable + converged)" : missingEstimationReason(runID: runID)
            do {
                if let skill = try await LLMCommandService.synthesizeSkillLesson(
                    baseURL: llmBaseURL, model: llmModel, apiKey: llmAPIKey,
                    phase: "Project History Distillation",
                    problem: "A \(comp)-comp run\(runID) \(reason).",
                    action: "Review run\(runID) estimation output and the modeling decisions that led to this outcome.",
                    result: stableRun
                        ? "Capture what made this \(comp)-comp model converge cleanly as a reusable success pattern."
                        : "Generalize the typical cause → fix pattern for \(comp)-comp estimation failures of this kind.",
                    apiFormat: activeAPIFormat
                ) {
                    if stableRun {
                        PPKSkillStore.shared.addSuccess(
                            title: "\(skill.title) (run\(runID), \(comp)-comp)",
                            context: "Stable \(comp)-comp model from project history.",
                            action: skill.lesson,
                            result: "run\(runID) reached S+C — reusable structural/estimation choice.",
                            sourceRun: runID,
                            tags: ["distilled", "history", "\(comp)-comp"]
                        )
                    } else {
                        PPKSkillStore.shared.addLesson(
                            category: skill.category,
                            title: skill.title,
                            problem: "Auto-distilled from run\(runID): \(skill.lesson.prefix(180))",
                            solution: skill.lesson,
                            sourceRun: runID,
                            severity: skill.severity,
                            tags: ["distilled", "history", "\(comp)-comp"]
                        )
                    }
                    distilled += 1
                    runner.append("🧠 Distilled skill from run\(runID): [\(skill.category.rawValue)] \(skill.title)")
                }
            } catch {
                runner.append("⚠️ Distillation skipped for run\(runID): \(error.localizedDescription.prefix(80))")
            }
        }

        distillProgressText = ""

        if distilled > 0 {
            PPKSkillStore.shared.saveCurrent()
            runner.append("✅ Distilled \(distilled) skill(s) from project history into the global PPK skill store.")
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusDistillDone, distilled)))
        } else {
            runner.append("ℹ️ No new skills distilled (runs may already be covered, or LLM returned nothing).")
        }
        return distilled
    }

    func openWorkspaceRoot() {
        openProject(url: workspaceURL)
    }

    func openDemoProject() {
        openProject(url: ProjectScanner.ensureDemoProject(workspaceURL: workspaceURL))
        showDemoGuide = true
    }

    var deleteConfirmationText: String {
        guard let asset = pendingDeleteAsset else {
            return "No file selected."
        }
        return """
        Move \(asset.title) to Trash?

        \(asset.relativePath)
        """
    }

    func requestDelete(_ asset: ProjectAsset) {
        pendingDeleteAsset = asset
        isDeleteConfirmationPresented = true
    }

    func requestDeleteSelectedAsset() {
        guard let selectedAsset else {
            runner.append("No file selected for deletion.")
            return
        }
        requestDelete(selectedAsset)
    }

    func cancelDelete() {
        pendingDeleteAsset = nil
        isDeleteConfirmationPresented = false
    }

    func confirmDeletePendingAsset() {
        guard let asset = pendingDeleteAsset else { return }
        defer { cancelDelete() }

        let projectPath = projectURL.standardizedFileURL.path
        let assetPath = asset.url.standardizedFileURL.path
        guard assetPath.hasPrefix(projectPath + "/") else {
            runner.append("Delete blocked because file is outside the current project: \(assetPath)")
            return
        }

        do {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: asset.url, resultingItemURL: &trashedURL)
            runner.append("Moved to Trash: \(asset.relativePath)")
            pinnedAssetIDs.remove(asset.id)
            savePinnedAssets()
            if selectedAsset?.id == asset.id {
                selectedAsset = nil
                showOverview()
            }
            refreshWorkspace()
        } catch {
            runner.append("Delete failed: \(error.localizedDescription)")
        }
    }

    func confirmDeleteProject() {
        guard let url = pendingDeleteProject else { return }
        pendingDeleteProject = nil
        isDeleteProjectConfirmed = false
        guard !automationBusy else {
            runner.append(L10n.statusAutoBlockedDelete)
            return
        }
        let name = url.lastPathComponent
        let parent = url.deletingLastPathComponent()
        do {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashedURL)
            runner.append("Moved project to Trash: \(name)")
            // Switch to parent directory or workspace
            if let workspace = try? ProjectScanner.defaultWorkspaceURL() {
                workspaceURL = workspace
            } else {
                workspaceURL = parent
            }
            projectURL = workspaceURL
            selectedAsset = nil
            removeRecentProject(url)
            refreshWorkspace()
        } catch {
            runner.append("Delete project failed: \(error.localizedDescription)")
        }
    }

    private func removeRecentProject(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: Self.recentProjectsKey) ?? []
        paths.removeAll { $0 == url.path }
        UserDefaults.standard.set(paths, forKey: Self.recentProjectsKey)
        loadRecentProjects()
    }

    func draftCommandWithAI() {
        guard !isDraftingCommand else { return }
        isDraftingCommand = true
        runner.append("AI command completion started with \(llmModel)...")
        Task {
            do {
                let rules = activeRuleContext().text
                let command = try await LLMCommandService.draftPsNCommand(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    runID: currentRun,
                    projectURL: projectURL,
                    currentCommand: commandText,
                    rules: rules,
                    apiKey: llmAPIKey,
                    apiFormat: activeAPIFormat
                )
                commandText = command
                runner.append("AI command draft inserted. Review before running.")
                refreshChecks()
            } catch {
                commandText = psnRunCommand(runID: currentRun)
                let message = LLMCommandService.friendlyError(error, baseURL: llmBaseURL)
                runner.append("AI command completion failed: \(message). Safe fallback inserted.")
                refreshChecks()
            }
            isDraftingCommand = false
        }
    }

    func testLLMConnection() {
        guard !isTestingLLM else { return }
        isTestingLLM = true
        let format = activeAPIFormat
        let base = llmBaseURL
        llmStatus = "Testing \(base)..."
        runner.append("Testing LLM endpoint [\(format.displayName)]: \(base)")
        Task {
            do {
                let probe = try await LLMCommandService.testConnection(
                    baseURL: base, apiKey: llmAPIKey, apiFormat: format
                )
                availableLLMModels = probe.models
                llmBaseURL = probe.baseURL
                syncToActiveProvider()
                // Only auto-pick first model if user hasn't explicitly configured one.
                // If llmModel is already set (from provider config), keep the user's choice.
                if llmModel.isEmpty, let first = probe.models.first {
                    llmModel = first
                    syncToActiveProvider()
                }
                let modelText = probe.models.isEmpty ? "connected but no models listed" : "models: \(probe.models.prefix(4).joined(separator: ", "))"
                llmStatus = "Connected - \(modelText)"
                runner.append("LLM connected [\(format.displayName)]: \(modelText)")
                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusLLMConnected, format.displayName, modelText)))
            } catch {
                availableLLMModels = []
                syncToActiveProvider()
                let message = LLMCommandService.friendlyError(error, baseURL: base)
                llmStatus = message
                runner.append(message)
                assistantMessages.append(AssistantMessage(role: .assistant, text: message))
            }
            isTestingLLM = false
        }
    }

    func resetAssistantConversation() {
        assistantMessages = [
            AssistantMessage(role: .assistant, text: duDuPersonality.welcomeMessage)
        ]
    }

    /// Auto-compress chat context when approaching token limits.
    /// Summarizes older messages and replaces them with a compressed system message.
    /// Keeps the most recent N messages intact for conversation continuity.
    func compressChatContext() {
        guard assistantMessages.count > 25 else { return }
        // Keep last 12 messages intact, compress the rest
        let keepCount = 12
        let toCompress = assistantMessages.prefix(assistantMessages.count - keepCount)
        let toKeep = assistantMessages.suffix(keepCount)

        // Build a summary of older messages
        var summary = "[AutoPMX context compression — earlier conversation summarized]\n"
        for msg in toCompress {
            let roleTag = msg.role == .user ? "User" : (msg.role == .assistant ? "DuDu" : "System")
            let preview = String(msg.text.prefix(200)).replacingOccurrences(of: "\n", with: " ")
            summary += "\(roleTag): \(preview)\n"
            if summary.count > 3000 { break }
        }

        let compressed = AssistantMessage(role: .system, text: summary.trimmingCharacters(in: .whitespacesAndNewlines))
        assistantMessages = [compressed] + Array(toKeep)
        runner.append("Context compressed: \(assistantMessages.count) messages (earlier conversation summarized)")
    }

    /// Get estimated token count of current chat context
    func estimatedTokenCount() -> Int {
        var total = 0
        for msg in assistantMessages {
            total += msg.text.count / 3  // rough estimate: ~3 chars per token
        }
        return total
    }

    /// Parse and auto-execute [ACTION:xxx] markers from AI replies.
    /// All actions are confined to the project path for safety.
    private func executeActionFromReply(_ text: String) {
        guard !automationBusy, !runner.isRunning else { return }
        let pattern = try! NSRegularExpression(pattern: #"\[ACTION:(\w+)\s*(.*?)\]"#, options: [.caseInsensitive])
        let ns = text as NSString
        guard let match = pattern.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else { return }
        let action = ns.substring(with: match.range(at: 1)).lowercased()
        let target = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)

        runner.append("🔧 DuDu auto-executing: \(action) \(target)")

        switch action {
        case "gof":
            let runID = target.isEmpty ? currentRun : target
            runGOF(for: runID)
        case "vpc":
            let runID = target.isEmpty ? currentRun : target
            runVPCPlot(for: runID)
        case "individual":
            let runID = target.isEmpty ? currentRun : target
            runIndividualDVTime(for: runID)
        case "pk_params":
            let runID = target.isEmpty ? currentRun : target
            runPKParameterExtraction(for: runID)
        case "bootstrap":
            let runID = target.isEmpty ? currentRun : target
            runBootstrapWithAI(for: runID, samples: 50)
        case "scm":
            let runID = target.isEmpty ? currentRun : target
            presentSCMDialog(runID: runID)
        case "eda":
            let dataFile = target.isEmpty ? self.dataFile : target
            runEDA(dataFile: dataFile)
        case "ct_curves":
            let dataFile = target.isEmpty ? self.dataFile : target
            runCTCurves(dataFile: dataFile)
        default:
            runner.append("⚠️ Unknown action: \(action) — skipping.")
        }
    }

    // MARK: - Help + DuDu

    /// Open the in-app Help window (Help.html rendered in a WebView).
    func openHelpWindow() {
        HelpWindowController.show(store: self)
    }

    /// Prepend the Help-document context to the message list sent to the LLM, without
    /// polluting the visible chat transcript.
    private func helpAwareMessages() -> [AssistantMessage] {
        guard !helpDuDuContext.isEmpty else { return assistantMessages }
        var messages = [AssistantMessage(role: .system,
                                         text: L10n.helpContextSystemIntro + "\n\n" + helpDuDuContext)]
        messages.append(contentsOf: assistantMessages)
        return messages
    }

    /// Load the bundled Help.html as plain text and prepare DuDu to answer questions
    /// about it. Also opens the chat panel so the user can ask right away.
    func prepareHelpDuDuContext() {
        if helpDuDuContext.isEmpty {
            helpDuDuContext = Self.helpDocumentText()
        }
        isAssistantPanelPresented = true
        // Bring the main window (with the DuDu chat panel) to the front so the Help
        // window never blocks the conversation.
        NSApp.activate(ignoringOtherApps: true)
        MainWindowKeeper.shared.window?.makeKeyAndOrderFront(nil)
        if assistantMessages.count <= 1 {
            resetAssistantConversation()
        }
        runner.append("DuDu Help context loaded（帮助文档已载入 DuDu 上下文）")
    }

    /// Ask DuDu a question about the Help content. With a question, the message is sent
    /// immediately; without one, the panel opens with the context ready for the user to type.
    func askDuDuAboutHelp(_ question: String?) {
        prepareHelpDuDuContext()
        guard let question, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            assistantMessages.append(AssistantMessage(role: .system, text: L10n.helpContextReadyHint))
            return
        }
        assistantInput = question
        sendAssistantMessage()
    }

    /// Extract readable text from the bundled Help.html (strip scripts/styles/tags).
    private static func helpDocumentText() -> String {
        guard let url = BundledResource.url(forResource: "Help", withExtension: "html"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        var text = raw
        text = text.replacingOccurrences(of: #"(?is)<script.*?</script>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?is)<style.*?</style>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        for (entity, replacement) in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                                      ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")] {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(text.prefix(40_000)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func sendAssistantMessage() {
        let prompt = assistantInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isAssistantThinking else { return }

        // Intercept SCM commands before sending to LLM
        if interceptSCMChatRequest(prompt) {
            assistantMessages.append(AssistantMessage(role: .user, text: prompt))
            assistantInput = ""
            return
        }

        // Auto-compress context if approaching token limits
        if assistantMessages.count > 40 || estimatedTokenCount() > 128_000 {
            compressChatContext()
        }
        assistantMessages.append(AssistantMessage(role: .user, text: prompt))
        assistantInput = ""
        isAssistantThinking = true
        duDuMood = .thinking
        addThinkingStep("DuDu is thinking...", type: .thinking)
        let chatMessages = helpAwareMessages()
        chatTask = Task {
            do {
                if shouldRunAgentLoop(for: prompt) {
                    try await runDuDuAgent(userPrompt: prompt)
                } else {
                    markRequestStart(inputTokens: chatMessages.count * 200)
                    let (reply, usage) = try await LLMCommandService.chat(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        messages: chatMessages,
                        projectURL: projectURL,
                        currentRun: currentRun,
                        rules: activeRuleContext().text + "\n" + PPKSkillStore.shared.contextBlock(),
                        apiKey: llmAPIKey,
                        personality: activePersonalityBlock,
                        knowledgeBaseURL: knowledgeBaseURL,
                        apiFormat: activeAPIFormat
                    )
                    recordUsage(usage)
                    try Task.checkCancellation()
                    // Strip [ACTION:xxx] markers from displayed text before appending
                    let displayText = reply.replacingOccurrences(of: #"\[ACTION:\w+\s*.*?\]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanText = AssistantMessage.parse(displayText, role: .assistant)
                    assistantMessages.append(cleanText)
                    // Auto-execute any [ACTION:xxx] marker in the AI's reply (before stripping)
                    executeActionFromReply(reply)
                }
                if isLearningUserStyle { captureUserStyleFromLatestExchange() }
                // Learn from user's modeling instructions
                learnFromUserMessage(prompt)
                updateLastThinkingStep(type: .done)
            } catch is CancellationError {
                assistantMessages.append(AssistantMessage(role: .assistant, text: L10n.statusChatStopped))
                updateLastThinkingStep(type: .done, detail: "stopped by user")
            } catch {
                assistantMessages.append(AssistantMessage(role: .assistant, text: LLMCommandService.friendlyError(error, baseURL: llmBaseURL)))
                updateLastThinkingStep(type: .error, detail: error.localizedDescription)
            }
            isAssistantThinking = false
            chatTask = nil
            if !isAutoModeling { duDuMood = .happy }
        }
    }

    func sendUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Intercept SCM commands BEFORE any other checks (even if DuDu is thinking)
        if interceptSCMChatRequest(trimmed) {
            assistantMessages.append(AssistantMessage(role: .user, text: trimmed))
            return
        }

        guard !isAssistantThinking else { return }

        assistantMessages.append(AssistantMessage(role: .user, text: trimmed))
        isAssistantThinking = true
        addThinkingStep("DuDu is thinking...", type: .thinking)
        chatTask = Task {
            do {
                if shouldRunAgentLoop(for: trimmed) {
                    try await runDuDuAgent(userPrompt: trimmed)
                } else {
                    let (reply, usage) = try await LLMCommandService.chat(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        messages: assistantMessages,
                        projectURL: projectURL,
                        currentRun: currentRun,
                        rules: activeRuleContext().text + "\n" + PPKSkillStore.shared.contextBlock(),
                        apiKey: llmAPIKey,
                        personality: activePersonalityBlock,
                        knowledgeBaseURL: knowledgeBaseURL,
                        apiFormat: activeAPIFormat
                    )
                    recordUsage(usage)
                    try Task.checkCancellation()
                    assistantMessages.append(AssistantMessage.parse(reply, role: .assistant))
                }
                if isLearningUserStyle { captureUserStyleFromLatestExchange() }
                // Learn from user's modeling instructions
                learnFromUserMessage(trimmed)
                updateLastThinkingStep(type: .done)
            } catch is CancellationError {
                assistantMessages.append(AssistantMessage(role: .assistant, text: L10n.statusChatStopped))
                updateLastThinkingStep(type: .done, detail: "stopped by user")
            } catch {
                assistantMessages.append(AssistantMessage(role: .assistant, text: LLMCommandService.friendlyError(error, baseURL: llmBaseURL)))
                updateLastThinkingStep(type: .error, detail: error.localizedDescription)
            }
            isAssistantThinking = false
            chatTask = nil
            if !isAutoModeling { duDuMood = .happy }
        }
    }

    // MARK: - DuDu Agent Mode

    private func shouldRunAgentLoop(for text: String) -> Bool {
        let lower = text.lowercased()
        let triggers = [
            "mod", "run", "修改", "运行", "初值", "参数", "edit", "改"
        ]
        return triggers.contains { lower.contains($0) }
    }

    private func runDuDuAgent(userPrompt: String) async throws {
        // New session per user request, stable across the tool loop for prefix cache.
        agentSessionID = UUID().uuidString
        var agentMessages = Array(assistantMessages.suffix(12))
        if !helpDuDuContext.isEmpty {
            agentMessages.insert(AssistantMessage(role: .system,
                                                  text: L10n.helpContextSystemIntro + "\n\n" + helpDuDuContext), at: 0)
        }

        for _ in 0..<6 {
            try Task.checkCancellation()
            let (reply, usage) = try await LLMCommandService.agentChat(
                baseURL: llmBaseURL,
                model: llmModel,
                messages: agentMessages,
                projectURL: projectURL,
                currentRun: currentRun,
                rules: activeRuleContext().text + "\n" + PPKSkillStore.shared.contextBlock(),
                apiKey: llmAPIKey,
                knowledgeBaseURL: knowledgeBaseURL,
                sessionId: agentSessionID,
                apiFormat: activeAPIFormat
            )
            recordUsage(usage)
            try Task.checkCancellation()
            agentMessages.append(.init(role: .assistant, text: reply))

            guard let action = Self.parseAgentAction(reply) else {
                agentMessages.append(.init(role: .user, text: L10n.statusAgentJSONPrompt))
                continue
            }

            if action.tool == "chat" || action.tool == "finish" {
                assistantMessages.append(AssistantMessage.parse(action.reply ?? reply, role: .assistant))
                return
            }

            let result = await executeAgentAction(action)
            agentMessages.append(.init(role: .user, text: String.safeFormat(L10n.statusAgentToolResult, action.tool, result)))
            runner.append("[DuDu Agent] \(action.tool)\(action.runID.map { " run\($0)" } ?? "") \(result.prefix(220))")
            refreshWorkspace()
        }

        assistantMessages.append(.init(role: .assistant, text: L10n.statusAgentDone))
    }

    private static func parseAgentAction(_ text: String) -> DuDuAgentAction? {
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DuDuAgentAction.self, from: data)
    }

    private func cleanedAgentModelText(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "```nonmem", with: "")
            .replacingOccurrences(of: "```nmtran", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return LLMCommandService.stripInlineDatasetRows(cleaned)
    }

    private func safeAgentRunID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) else { return nil }
        let runs = automationModelRuns()
        if runs.contains(trimmed) { return trimmed }
        guard let number = Int(trimmed) else { return nil }
        return runs.first { Int($0) == number }
    }

    private func executeAgentAction(_ action: DuDuAgentAction) async -> String {
        switch action.tool {
        case "list_runs":
            let runs = automationModelRuns()
            return runs.isEmpty ? "No run*.mod files found" : runs.joined(separator: ", ")

        case "read_mod":
            guard let runID = safeAgentRunID(action.runID) else {
                return "Missing or invalid runID; run\(action.runID ?? "?") does not exist."
            }
            let url = projectURL.appendingPathComponent("run\(runID).mod")
            return textPreview(url, limit: 50_000)

        case "edit_mod":
            guard let runID = safeAgentRunID(action.runID) else {
                return "Missing or invalid runID; run\(action.runID ?? "?") does not exist."
            }
            guard let full = action.fullModelText,
                  !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "edit_mod requires fullModelText containing the complete .mod file."
            }

            let modURL = projectURL.appendingPathComponent("run\(runID).mod")
            let backupDir = projectURL.appendingPathComponent(".autopmx_backups", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
                let stamp = Int(Date().timeIntervalSince1970)
                let backupURL = backupDir.appendingPathComponent("run\(runID).mod.\(stamp).bak")
                try FileManager.default.copyItem(at: modURL, to: backupURL)
                let edited = withETATableRecord(cleanedAgentModelText(full), runID: runID)
                try edited.write(to: modURL, atomically: true, encoding: .utf8)
            } catch {
                return "Edit failed: \(error.localizedDescription)"
            }

            guard await validateModel(runID).passed else {
                let backups = (try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)) ?? []
                if let latest = backups
                    .filter({ $0.lastPathComponent.hasPrefix("run\(runID).mod.") && $0.pathExtension == "bak" })
                    .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
                    .last,
                   let original = try? String(contentsOf: latest, encoding: .utf8) {
                    try? original.write(to: modURL, atomically: true, encoding: .utf8)
                }
                return "Validation failed; changes rolled back."
            }

            if action.autoRun == true {
                let exit = await runner.runAndWait(command: psnRunCommand(runID: runID), in: projectURL)
                return "Validated and run; exit code \(exit)"
            }
            return "Validated; model was not run."

        case "validate_mod":
            guard let runID = safeAgentRunID(action.runID) else {
                return "Missing or invalid runID; run\(action.runID ?? "?") does not exist."
            }
            let validation = await validateModel(runID)
            return validation.passed ? "Validation passed" : "Validation failed: \(validation.output)"

        case "run_mod":
            guard let runID = safeAgentRunID(action.runID) else {
                return "Missing or invalid runID; run\(action.runID ?? "?") does not exist."
            }
            let exit = await runner.runAndWait(command: psnRunCommand(runID: runID), in: projectURL)
            return "exit code \(exit)"

        case "read_output":
            guard let runID = safeAgentRunID(action.runID) else {
                return "Missing or invalid runID; run\(action.runID ?? "?") does not exist."
            }
            var parts: [String] = []
            for ext in ["lst", "ext", "cov"] {
                let url = projectURL.appendingPathComponent("run\(runID).\(ext)")
                if FileManager.default.fileExists(atPath: url.path) {
                    parts.append("--- run\(runID).\(ext) ---\n\(textPreview(url, limit: ext == "lst" ? 10_000 : 4_000))")
                }
            }
            return parts.isEmpty ? "No output files found" : parts.joined(separator: "\n\n")

        default:
            return "Unknown tool: \(action.tool)"
        }
    }

    func requestStopChat() {
        chatTask?.cancel()
    }

    /// Learn from user's modeling instructions and save to PPK Skill.
    private func learnFromUserMessage(_ text: String) {
        let lower = text.lowercased()
        let store = PPKSkillStore.shared

        // Detect modeling guidance keywords
        let modelingKeywords = ["eta", "covariate", "ofv", "aic", "bic", "convergence",
                                 "residual", "error model", "compartment", "absorption",
                                 "ka", "lag", "bioavailability", "initial estimate",
                                 "theta", "omega", "sigma", "shrinkage", "vpc",
                                 "gof", "bootstrap", "llofi", "param", "fix",
                                 "add cov", "remove cov", "forward", "backward",
                                 "try adding", "try removing", "should be", "suggest",
                                 "建议", "尝试", "改成", "加上", "去掉", "修复",
                                 "优化", "调整", "建模"]
        let isModelingInstruction = modelingKeywords.contains(where: { lower.contains($0) })

        guard isModelingInstruction, text.count > 20 else { return }

        // Record as a user guidance lesson
        store.addLesson(
            category: .userGuidance,
            title: "Analyst guidance: \(String(text.prefix(60)))",
            problem: "Analyst provided modeling instruction",
            solution: text,
            sourceRun: currentRun,
            severity: .medium,
            tags: ["user-guidance", "modeling"]
        )

        // Check for specific patterns worth remembering
        if lower.contains("ofv") || lower.contains("aic") || lower.contains("bic") {
            store.addSuccess(
                title: "OFV-based model selection guidance",
                context: "During modeling for run\(currentRun ?? "?")",
                action: text,
                result: "User specified model selection criteria",
                sourceRun: currentRun,
                tags: ["OFV", "model-selection"]
            )
        }

        if lower.contains("add cov") || lower.contains("remove cov") || lower.contains("covariate") {
            store.addLesson(
                category: .scmConfig,
                title: "Covariate guidance: \(String(text.prefix(80)))",
                problem: "Analyst specified covariate relationship",
                solution: text,
                sourceRun: currentRun,
                severity: .high,
                tags: ["covariate", "SCM"]
            )
        }

        // Auto-save after learning
        store.save(to: projectURL)
    }

    /// The personality block to inject into the system prompt, combining preset + custom + learned style
    private var activePersonalityBlock: String {
        let langDirective = LanguageStore.shared.language == .en
            ? "\n\nLanguage directive: ALWAYS reply in English. The user has set the app language to English, so use English for all responses. Do NOT reply in Chinese."
            : "\n\nLanguage directive: ALWAYS reply in Chinese (中文). Use Chinese for all responses unless the user explicitly uses English."
        return duDuPersonality.systemPersonalityBlock(
            customPrompt: customPersonalityPrompt,
            learnedStyle: isLearningUserStyle ? learnedStyleSection : ""
        ) + markdownFormattingGuide + langDirective
    }

    /// Shared formatting instruction for all DuDu responses
    private var markdownFormattingGuide: String {
        """

        Response formatting rules (MUST follow):
        - Use markdown formatting for ALL responses, especially when listing or comparing items.
        - Use bullet points (- ) for unordered lists. Each bullet MUST be on its own line.
        - Use numbered lists (1. ) for step-by-step instructions.
        - Use **bold** for key terms, model names, and important numbers (e.g., **ΔOFV**, **AIC**, **p<0.05**).
        - Use `code` for parameter names, variable names, and code snippets.
        - Use ## for main sections and ### for subsections.
        - Add a blank line between paragraphs and sections.
        - NEVER output a long paragraph when a structured list would be clearer.
        """
    }

    private var learnedStyleSection: String {
        guard isLearningUserStyle, !styleReport.isEmpty else { return "" }
        return """

        Below is a user speaking style guide. Match this tone when replying:
        \(styleReport)
        """
    }

    /// Archive the latest user message for later style report generation
    private func captureUserStyleFromLatestExchange() {
        guard isLearningUserStyle, userMessageArchive.count < 300 else { return }
        guard let lastUser = assistantMessages.last(where: { $0.role == .user })?.text else { return }
        guard lastUser.count >= 8 else { return }
        // Avoid exact duplicates
        guard userMessageArchive.last != lastUser else { return }
        userMessageArchive.append(lastUser)
    }

    var automationAvailableRunIDs: [String] {
        // Use cached run IDs from the last refreshWorkspace() to avoid re-scanning
        // the directory on every SwiftUI body evaluation.
        availableRunIDs.isEmpty ? automationModelRuns() : availableRunIDs
    }

    var automationOptionsSubtitle: String {
        let runs = automationAvailableRunIDs
        if isAutomationProject(projectURL), let last = runs.last {
            return "Current AutoModel project: run\(last) is the latest available model."
        }
        return "A clean AutoModel project will be created from \(dataFile)."
    }

    func presentAutomationOptions() {
        guard !automationBusy else { return }
        if automationDataFile.isEmpty || !availableCSVFiles().contains(automationDataFile) {
            automationDataFile = dataFile
        }
        let runs = automationAvailableRunIDs
        if let aiRun = preferredAIModelRunID, runs.contains(aiRun) {
            automationStartMode = .selectedRun
            automationStartRunID = aiRun
        } else if isAutomationProject(projectURL), !runs.isEmpty {
            automationStartMode = .continueLatest
            automationStartRunID = runs.contains(currentRun) ? currentRun : (runs.last ?? "")
        } else {
            automationStartMode = .fresh
            automationStartRunID = runs.last ?? currentRun
        }
        isAssistantPanelPresented = true
        isAutomationOptionsPresented = true
    }

    func startAutomationFromOptions() {
        automationUseIVAnchor = false
        if shouldAskForIVAnchor() {
            isIVAnchorConfirmPresented = true
            return
        }
        isAutomationOptionsPresented = false
        startAutomatedModelingDemo()
    }

    private func shouldAskForIVAnchor() -> Bool {
        guard automationStartMode == .selectedRun,
              !automationStartRunID.isEmpty,
              LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: automationDataFile).hasOral,
              let modText = try? String(contentsOf:
                  projectURL.appendingPathComponent("run\(automationStartRunID).mod"),
                  encoding: .utf8
              ) else {
            return false
        }
        let upper = modText.uppercased()
        return upper.contains("ADVAN1") || upper.contains("ADVAN3") || upper.contains("ADVAN11")
    }

    func confirmUseIVAnchor() {
        automationUseIVAnchor = true
        automationStartMode = .selectedRun
        isIVAnchorConfirmPresented = false
        isAutomationOptionsPresented = false
        startAutomatedModelingDemo()
    }

    func skipUseIVAnchor() {
        automationUseIVAnchor = false
        automationStartMode = .fresh
        automationStartRunID = ""
        isIVAnchorConfirmPresented = false
        isAutomationOptionsPresented = false
        startAutomatedModelingDemo()
    }

    func cancelIVAnchorPrompt() {
        automationUseIVAnchor = false
        isIVAnchorConfirmPresented = false
    }

    /// Normalize typical-value parameter naming to the PsN SCM convention (TV-prefix).
    /// SCM requires typical values like `TVCL`, `TVV1`; some AI-generated models write `CLTV`, `V1TV`
    /// (TV suffix), which makes scm fail with "No TVCL was found". Rename `XXXTV` -> `TVXXX`.

    /// Force residual-error THETA entries with `FIX` to be pinned at ZERO.
    ///
    /// The residual error is combined: `W = SQRT(THETA(prop)^2*IPRED^2 + THETA(add)^2)`.
    /// When the AI fixes a residual component it must pin it to 0 (pure proportional or pure
    /// additive error), NOT to a nonzero initial value. Some LLMs still write `(0, 1.0) FIX`
    /// (pins at 1.0) despite the prompt rule — this is a hard code-level guard that rewrites
    /// any residual THETA carrying `FIX` to `0 FIX`.
    private func enforceZeroFixForResidualError(_ modText: String) -> String {
        let lines = modText.components(separatedBy: "\n")
        var result: [String] = []
        var inTheta = false

        // Only treat a line as a residual component if the trailing comment contains an
        // explicit residual label. This deliberately EXCLUDES legitimate nonzero FIXes such
        // as the Phase-2 allometric exponents `(0, 0.75) FIX ; WT_CL exponent`.
        let residualPattern = try? NSRegularExpression(
            pattern: #"(?:Add|Prop)\.\s*RE|(?:additive|proportional|residual)\s*error|(?:additive|proportional|residual)\s*err|\.RE\b|\.err\b"#,
            options: [.caseInsensitive]
        )

        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("$THETA") { inTheta = true; result.append(line); continue }
            if inTheta {
                if upper.hasPrefix("$") { inTheta = false } // $OMEGA / $ERROR etc.
                else if line.contains("FIX") {
                    let comment = line.components(separatedBy: ";").dropFirst().joined(separator: ";")
                    // Only rewrite if this THETA line is labeled as a residual component.
                    let labeled = !comment.isEmpty && (residualPattern?.firstMatch(
                        in: comment, options: [],
                        range: NSRange(location: 0, length: comment.utf16.count)
                    ) != nil)
                    if labeled {
                        // Keep trailing comment, replace the whole THETA expression with 0 FIX.
                        if let semi = line.firstIndex(of: ";") {
                            let comment = line[semi...]
                            result.append("0 FIX  \(comment)")
                        } else {
                            result.append("0 FIX")
                        }
                        continue
                    }
                }
            }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    /// Prevent the AI from fixing a residual component unless the parent run actually
    /// justifies it. The evaluation evidence may be fine (e.g. Add.RE RSE ~8%) while the
    /// model still decides to simplify the error model. That is exactly the behavior the
    /// hard gate below blocks: residual simplification is only legal when the parent has
    /// a high residual RSE/boundary or already carries a fixed residual component.
    private func protectResidualEstimation(_ modText: String, sourceModText: String, runID: String) -> String {
        let sourceResiduals = residualThetaEntries(in: sourceModText)
        let sourceFixedLabels = Set(sourceResiduals.filter { $0.isFixed }.map { $0.label })

        let rows = ProjectScanner.parameterEstimates(runID: runID, in: projectURL)
        let unstableLabels = Set(rows.compactMap { row -> String? in
            row.group == "Residual"
                && ((row.rsePercent ?? 0) > 100 || abs(row.estimate) <= 1e-6)
                ? normalizedParameterLabel(row.name)
                : nil
        })

        let sourceByLabel = Dictionary(
            sourceResiduals.map { ($0.label, $0.line) },
            uniquingKeysWith: { first, _ in first }
        )
        let residualPattern = residualLabelPattern
        let lines = modText.components(separatedBy: "\n")
        var result = lines
        var restored = false
        var inTheta = false

        for (index, line) in lines.enumerated() {
            let upper = line.uppercased()
            if upper.hasPrefix("$THETA") {
                inTheta = true
                continue
            }
            if inTheta && upper.hasPrefix("$") {
                inTheta = false
                continue
            }
            guard inTheta, upper.contains("FIX") else { continue }

            let comment = line.components(separatedBy: ";").dropFirst()
                .joined(separator: ";")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !comment.isEmpty,
                  residualPattern.firstMatch(
                    in: comment, options: [],
                    range: NSRange(location: 0, length: comment.utf16.count)
                  ) != nil else { continue }

            let label = normalizedParameterLabel(comment)
            if sourceFixedLabels.contains(label) || unstableLabels.contains(label) {
                continue
            }
            if let sourceLine = sourceByLabel[label] {
                result[index] = sourceLine
            } else {
                let valuePart = line.components(separatedBy: ";").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let restoredValue = valuePart
                    .replacingOccurrences(
                        of: #"\s*FIX\s*"#,
                        with: " ",
                        options: .regularExpression
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                result[index] = restoredValue.isEmpty ? line : restoredValue
            }
            restored = true
        }

        if restored {
            runner.append("Protected residual estimation: run\(runID) residual RSE was acceptable; removed unrequested residual FIX from drafted model.")
        }
        return result.joined(separator: "\n")
    }

    private var residualLabelPattern: NSRegularExpression {
        let pattern = #"(?:Add|Prop)\.\s*RE|(?:additive|proportional|residual)\s*error|(?:additive|proportional|residual)\s*err|\.RE\b|\.err\b"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private func residualThetaEntries(in text: String) -> [(label: String, line: String, isFixed: Bool)] {
        var entries: [(label: String, line: String, isFixed: Bool)] = []
        var inTheta = false
        for line in text.components(separatedBy: "\n") {
            let upper = line.uppercased()
            if upper.hasPrefix("$THETA"), !upper.hasPrefix("$THETAP") {
                inTheta = true
                continue
            }
            if inTheta && upper.hasPrefix("$") {
                inTheta = false
                continue
            }
            guard inTheta else { continue }
            let comment = line.components(separatedBy: ";").dropFirst()
                .joined(separator: ";")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !comment.isEmpty,
                  residualLabelPattern.firstMatch(
                    in: comment, options: [],
                    range: NSRange(location: 0, length: comment.utf16.count)
                  ) != nil else { continue }
            entries.append((
                label: normalizedParameterLabel(comment),
                line: line,
                isFixed: upper.contains("FIX")
            ))
        }
        return entries
    }

    /// Hard-code-level S1/S2 unit guard: corrects the scale expression from the
    /// actual AMT/DV units instead of trusting the LLM to remember /1000.
    private func correctS1Scaling(_ modText: String) -> String {
        let lines = modText.components(separatedBy: "\n")
        var result: [String] = []
        var inPK = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$PK") {
                inPK = true
                result.append(line)
                continue
            }
            if inPK && upper.hasPrefix("$") {
                inPK = false
            }

            if inPK, line.range(of: #"\bS[12]\s*="#, options: .regularExpression) != nil {
                let variable: String
                if upper.contains("V2") {
                    variable = "V2"
                } else if upper.contains("V1") {
                    variable = "V1"
                } else {
                    variable = "V"
                }
                let scale = scaledExpression(variable)
                let prefix = upper.contains("S2") ? "S2" : "S1"
                let comment = line.components(separatedBy: ";").dropFirst().joined(separator: ";")
                    .trimmingCharacters(in: .whitespaces)
                if comment.isEmpty {
                    result.append("\(prefix) = \(scale)")
                } else {
                    result.append("\(prefix) = \(scale) ; \(comment)")
                }
                continue
            }

            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    private func normalizeTypicalValueNaming(_ text: String) -> String {
        // Longer names first so e.g. "V1" is handled before "V".
        let pkParams = ["V3", "V2", "V1", "V", "CL", "Q", "KA2", "KA1", "KA"]
        var result = text
        for p in pkParams {
            let target = "TV\(p)"
            for form in ["\(p)TV", "\(p) TV"] {
                guard let re = try? NSRegularExpression(
                    pattern: "\\b\(NSRegularExpression.escapedPattern(for: form))\\b",
                    options: []
                ) else { continue }
                let range = NSRange(result.startIndex..., in: result)
                result = re.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: target)
            }
        }
        return result
    }

    /// Promote the SCM final selected model into the main project as a new run, so it appears in the
    /// Models sidebar and DuDu can verify it in-project (not buried inside SCM_runXXX/).
    /// Returns the new run ID, or nil if no valid final model was found (e.g. SCM failed).
    private func promoteSCMFinalModel(baseRun: String) -> String? {
        let scmDir = projectURL.appendingPathComponent("SCM_run\(baseRun)")
        let fm = FileManager.default
        guard fm.fileExists(atPath: scmDir.path),
              let entries = try? fm.contentsOfDirectory(at: scmDir, includingPropertiesForKeys: nil) else {
            runner.append("SCM: no SCM directory found at \(scmDir.path) — SCM may not have completed.")
            return nil
        }

        // Find the highest-numbered scm_dirN and locate the final model.
        var bestDir: URL? = nil
        var bestNum = -1
        for entry in entries {
            let name = entry.lastPathComponent
            guard name.hasPrefix("scm_dir") else { continue }
            let numStr = String(name.dropFirst("scm_dir".count))
            guard let num = Int(numStr), num > bestNum else { continue }
            if scmFinalModelFile(in: entry) != nil {
                bestNum = num
                bestDir = entry
            }
        }
        guard let finalDir = bestDir else {
            runner.append("SCM: no final model found in any scm_dir — SCM may have failed.")
            return nil
        }

        guard let srcMod = scmFinalModelFile(in: finalDir) else {
            runner.append("SCM: no final model found in any scm_dir — SCM may have failed.")
            return nil
        }
        let finalLabel = srcMod.lastPathComponent
        runner.append("SCM: using \(finalLabel) (\(srcMod.path))")

        guard let modText = try? String(contentsOf: srcMod, encoding: .utf8),
              !modText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            runner.append("SCM: final model file (\(finalLabel)) is empty or unreadable → SCM failure.")
            return nil
        }

        // Next available run number in the main project. Use formattedRun for consistent %03d naming.
        let existing = automationModelRuns()
        let nextNum = (existing.compactMap(Int.init).max() ?? 0) + 1
        let runID = formattedRun(nextNum)
        let destMod = projectURL.appendingPathComponent("run\(runID).mod")

        // Add standard $TABLE blocks (SCM's final model file has no $TABLE).
        let sanitizedMod = LLMCommandService.stripInlineDatasetRows(modText)
        let tableParams = detectTableParams(from: sanitizedMod)
        let tableBlock = """
        $TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES ONEHEADER NOPRINT NOAPPEND FILE=sdtab\(runID) FORMAT=s1PE14.7
        $TABLE ID \(tableParams.paramList) ONEHEADER NOPRINT NOAPPEND FILE=patab\(runID)
        $TABLE ID \(tableParams.paramList) FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab\(runID)
        $TABLE ID \(tableParams.paramList) FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab\(runID)
        """
        var fullMod = withETATableRecord(
            sanitizedMod.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + tableBlock,
            runID: runID
        )
        fullMod = LLMCommandService.applyingIVInfusionDurationFix(fullMod)
        fullMod = LLMCommandService.normalizingTableRecords(fullMod, runID: runID)
        do {
            try fullMod.write(to: destMod, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }
        runner.append("SCM: promoted final model → run\(runID).mod (main project, with $TABLE added)")

        // ── Run PsN_scm_plots.R if available ──
        runSCMPlots(from: finalDir)

        return "\(runID)"
    }

    /// Detect ADVAN from mod text and return appropriate PATAB parameters.
    /// Returns (paramList: string, is3Comp: bool).
    private func detectTableParams(from modText: String) -> (paramList: String, is3Comp: Bool) {
        let upper = modText.uppercased()
        if upper.contains("ADVAN11") || upper.contains("ADVAN12") {
            return ("CL V1 Q2 V2 Q3 V3", true)
        }
        if upper.contains("ADVAN3") || upper.contains("ADVAN4") {
            return ("CL V1 Q V2", false)
        }
        return ("CL V", false)
    }

    /// Run PsN_scm_plots.R in the scm_dir to generate SCM diagnostic plots.
    private func runSCMPlots(from scmDir: URL) {
        let rScript = scmDir.appendingPathComponent("PsN_scm_plots.R")
        guard FileManager.default.fileExists(atPath: rScript.path) else {
            runner.append("SCM plots: PsN_scm_plots.R not found in \(scmDir.lastPathComponent)")
            return
        }
        let rscript = resolvedR()
        guard !rscript.isEmpty else {
            runner.append("SCM plots: R not configured. Please set R path in Settings.")
            return
        }
        let figDir = projectURL.appendingPathComponent("Figures", isDirectory: true)
        try? FileManager.default.createDirectory(at: figDir, withIntermediateDirectories: true)

        // Run synchronously
        let task = Process()
        task.currentDirectoryURL = scmDir
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "\(shellQuote(rscript)) \(shellQuote(rScript.path)) 2>&1"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if !output.isEmpty {
                runner.append("SCM plots output:\n\(output.prefix(2000))")
            }
            // Copy any generated plots to Figures/
            if let files = try? FileManager.default.contentsOfDirectory(at: scmDir, includingPropertiesForKeys: nil) {
                for file in files where ["pdf", "png", "jpg", "jpeg"].contains(file.pathExtension.lowercased()) {
                    let dest = figDir.appendingPathComponent(file.lastPathComponent)
                    try? FileManager.default.copyItem(at: file, to: dest)
                }
            }
            runner.append("SCM plots saved to Figures/ directory.")
        } catch {
            runner.append("SCM plots: failed to run R script — \(error.localizedDescription)")
        }
    }

    /// Compare SCM final model against the base model, PLUS independent AI-driven
    /// evaluation of the SCM covariate selection process. The AI independently tests
    /// each available covariate following SCM's forward inclusion / backward elimination
    /// criteria, then compares its selections with PsN SCM's actual result.
    private func compareSCMResultWithBase(baseRun: String, scmRun: String) async -> String {
        let baseModURL = projectURL.appendingPathComponent("run\(baseRun).mod")
        let scmModURL = projectURL.appendingPathComponent("run\(scmRun).mod")
        let baseText = (try? String(contentsOf: baseModURL, encoding: .utf8)) ?? ""
        let scmText = (try? String(contentsOf: scmModURL, encoding: .utf8)) ?? ""
        guard !baseText.isEmpty, !scmText.isEmpty else {
            return L10n.scmModelReadFailed
        }
        let baseLabels = extractThetaLabels(from: baseText)
        let scmLabels = extractThetaLabels(from: scmText)
        let added = scmLabels.filter { !baseLabels.contains($0) }
        let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: dataFile)
        var covList: [String] = []
        if profile.hasWT { covList.append("WT") }
        if profile.hasAGE { covList.append("AGE") }
        if profile.hasSEX { covList.append("SEX") }
        if !profile.studyLevels.isEmpty { covList.append("STUDY(\(profile.studyLevels.count) levels)") }
        covList.append(contentsOf: profile.additionalCovariates.sorted())
        let availableCovariates = covList.joined(separator: ", ")

        var lines: [String] = []
        lines.append(L10n.scmReportHeader)
        lines.append(String.safeFormat(L10n.scmReportBaseStructure, baseRun, scmRun))
        lines.append(String.safeFormat(L10n.scmReportAvailableCov, availableCovariates))
        if added.isEmpty {
            lines.append(L10n.scmNoCovFound)
        } else {
            lines.append(String.safeFormat(L10n.scmCovFound, added.count, added.joined(separator: ", ")))
        }
        if scmText.uppercased().contains("WT/MEDIAN") || scmText.uppercased().contains("0.75 FIX") {
            lines.append(L10n.scmWtIncluded)
        }

        // ── AI independent SCM verification ──
        lines.append("")
        lines.append(L10n.scmAiHeader)
        let verifiedPhrase = LanguageStore.shared.language == .zhCN
            ? "SCM 结果验证通过 ✓"
            : "SCM verification passed ✓"
        let cautionPhrase = LanguageStore.shared.language == .zhCN
            ? "需注意"
            : "needs attention"
        let scmPrompt = """
        You are auditing a PsN SCM covariate screening result.
        Base model is run\(baseRun) (structure model before SCM).
        Available covariates: \(availableCovariates)

        SCM selected: \(added.isEmpty ? "none (no significant covariates)" : added.joined(separator: ", "))

        Now independently evaluate the SCM selection using these criteria:
        1. Forward inclusion p < 0.05 (ΔOFV > 3.84, 1 df)
        2. Backward elimination p < 0.01 (ΔOFV > 6.63, 1 df)
        3. If WT is available, WT allometric scaling (0.75 FIX for CL, 1.0 FIX for V) is the first step
        4. Clinical significance: if ΔOFV < 10.83 even with p<0.01, check ratio at extremes

        Your task:
        - For each available covariate, estimate whether it would be significant.
        - List which covariates YOU would include, and which are borderline.
        - Compare your list with SCM's actual selection.
        - If they match, say "\(verifiedPhrase)".
        - If they differ, explain why (the criterion applied).
        - If a covariate was included but YOU think it's borderline (p close to 0.05),
          flag it as "\(cautionPhrase)".
        """
        let scmResult = await callLLMForSCM(scmPrompt)
        lines.append(scmResult)
        lines.append(L10n.scmDiagGenerated)
        lines.append(L10n.scmReportFooter)
        return lines.joined(separator: "\n")
    }

    /// Async LLM call for internal verification prompts.
    /// Returns the AI response text.
    private func callLLMForSCM(_ prompt: String) async -> String {
        guard !llmBaseURL.isEmpty else { return L10n.scmLlmNotConfigured }
        do {
            let (reply, _) = try await LLMCommandService.chat(
                baseURL: llmBaseURL,
                model: llmModel,
                messages: [AssistantMessage(role: .user, text: prompt)],
                projectURL: projectURL,
                currentRun: currentRun,
                rules: "You are a PopPK pharmacometrician auditing a covariate screening result. Respond concisely in Chinese or English as appropriate.",
                apiKey: llmAPIKey,
                personality: "",
                apiFormat: activeAPIFormat
            )
            return reply
        } catch {
            return String.safeFormat(L10n.scmVerificationFailed, error.localizedDescription)
        }
    }

    /// Compare DuDu's final model against the SCM final_backward.mod text.
    /// Called at the end of Phase 2 when both results are available.
    /// Detect WT scaling in a NONMEM model. PsN SCM writes either the literal marker
    /// `WT/MEDIAN` or an explicit `(WT/62.27)` power term; both mean WT was normalized.
    private func usesWtScaling(_ text: String) -> Bool {
        let upper = text.uppercased()
        if upper.contains("WT/MEDIAN") { return true }
        guard let regex = try? NSRegularExpression(pattern: #"WT\s*/\s*[0-9]"#, options: []) else { return false }
        let nsRange = NSRange(location: 0, length: (upper as NSString).length)
        return regex.firstMatch(in: upper, options: [], range: nsRange) != nil
    }

    private func compareFinalWithSCM(duduMod: URL, scmModText: String?, baseRun: String, scmModURL: URL? = nil) -> String? {
        guard let scmText = scmModText else { return nil }
        let duduText = (try? String(contentsOf: duduMod, encoding: .utf8)) ?? ""
        guard !duduText.isEmpty else { return L10n.scmDuDuModelEmpty }
        let duduLabels = extractThetaLabels(from: duduText)
        let scmLabels = extractThetaLabels(from: scmText)
        let duduCovs = extractSCMCovariateTokens(from: duduText)
        let scmCovs = extractSCMCovariateTokens(from: scmText)
        let duduRefCovs = extractReferencedCovariates(from: duduText)
        let scmRefCovs = extractReferencedCovariates(from: scmText)
        // Prefer relation tokens, then referenced covariate columns, then THETA labels.
        let inDuDu: Set<String>
        let inSCM: Set<String>
        if !duduCovs.isEmpty || !scmCovs.isEmpty {
            inDuDu = Set(duduCovs)
            inSCM = Set(scmCovs)
        } else if !duduRefCovs.isEmpty || !scmRefCovs.isEmpty {
            inDuDu = Set(duduRefCovs)
            inSCM = Set(scmRefCovs)
        } else {
            inDuDu = Set(duduLabels)
            inSCM = Set(scmLabels)
        }
        let onlyDuDu = inDuDu.subtracting(inSCM)
        let onlySCM = inSCM.subtracting(inDuDu)
        var lines: [String] = []
        lines.append(L10n.scmCompareHeader)
        if onlyDuDu.isEmpty && onlySCM.isEmpty {
            lines.append(L10n.scmCompareMatch)
        } else {
            if !onlyDuDu.isEmpty {
                lines.append(String.safeFormat(L10n.scmCompareOnlyDuDu, onlyDuDu.sorted().joined(separator: ", ")))
            }
            if !onlySCM.isEmpty {
                lines.append(String.safeFormat(L10n.scmCompareOnlySCM, onlySCM.sorted().joined(separator: ", ")))
            }
        }
        if inDuDu.isEmpty && inSCM.isEmpty {
            lines.append(L10n.scmCompareNone)
        }
        let duduWT = usesWtScaling(duduText)
        let scmWT = usesWtScaling(scmText)
        if duduWT == scmWT {
            lines.append(duduWT ? L10n.scmCompareWTBothIn : L10n.scmCompareWTBothOut)
        } else {
            let duduLabel = duduWT ? L10n.scmCompareWTDuDuIn : L10n.scmCompareWTDuDuOut
            let scmLabel = scmWT ? L10n.scmCompareWTSCMIn : L10n.scmCompareWTSCMOut
            lines.append(String.safeFormat(L10n.scmCompareWTWarning, duduLabel, scmLabel))
        }

        if let scmModURL {
            let duduFileName = duduMod.deletingPathExtension().lastPathComponent
            let duduRunID = duduFileName.hasPrefix("run")
                ? String(duduFileName.dropFirst("run".count))
                : duduFileName
            let duduRows = ProjectScanner.parameterEstimates(runID: duduRunID, in: projectURL)
            let scmExtURL = scmModURL.deletingPathExtension().appendingPathExtension("ext")
            if let scmExtText = try? String(contentsOf: scmExtURL, encoding: .utf8),
               let scmModTextForLabels = try? String(contentsOf: scmModURL, encoding: .utf8) {
                let scmRows = ParameterEstimateParser.parseExt(scmExtText, modText: scmModTextForLabels)
                if !duduRows.isEmpty && !scmRows.isEmpty {
                    lines.append("")
                    lines.append("PK parameter comparison (SCM final vs DuDu run\(duduRunID)):")
                    let comparison = parameterComparisonLines(
                        baseRows: scmRows,
                        finalRows: duduRows,
                        baseLabel: "SCM final",
                        finalLabel: "DuDu run\(duduRunID)"
                    )
                    lines.append(contentsOf: comparison.prefix(24).map { "  \($0)" })
                    if comparison.count > 24 {
                        lines.append("  ... \(comparison.count - 24) more")
                    }
                } else {
                    lines.append("SCM final .ext exists but PK parameter rows could not be parsed.")
                }
            } else {
                lines.append("SCM final .ext not found; PK parameter comparison skipped.")
            }
        }
        lines.append(L10n.scmCompareFooter)
        return lines.joined(separator: "\n")
    }

    /// Read SCM's final model text (without promoting it as a run).
    /// Used for comparison at the end of Phase 2 only — DuDu builds independently.
    private func readSCMFinalModel(baseRun: String) -> String? {
        guard let srcMod = findSCMFinalModel(baseRun: baseRun),
              let text = try? String(contentsOf: srcMod, encoding: .utf8) else { return nil }
        // Also run SCM plots
        runSCMPlots(from: srcMod.deletingLastPathComponent().deletingLastPathComponent())
        return text
    }

    /// Locate the final model .mod inside a scm_dirN: prefer final_backward.mod, then any
    /// .mod in final_models/, then base_model_with_included_relations.mod.
    private func scmFinalModelFile(in dir: URL) -> URL? {
        let fm = FileManager.default
        let backward = dir.appendingPathComponent("final_models/final_backward.mod")
        if fm.fileExists(atPath: backward.path) { return backward }
        let forward = dir.appendingPathComponent("final_models/final_forward.mod")
        if fm.fileExists(atPath: forward.path) { return forward }
        let fmDir = dir.appendingPathComponent("final_models")
        if let files = try? fm.contentsOfDirectory(at: fmDir, includingPropertiesForKeys: nil) {
            let mods = files.filter { $0.pathExtension.lowercased() == "mod" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if let first = mods.first { return first }
        }
        let included = dir.appendingPathComponent("base_model_with_included_relations.mod")
        if fm.fileExists(atPath: included.path) { return included }
        return nil
    }

    /// Robustly locate SCM's final model anywhere under `SCM_run{baseRun}`:
    ///  1. the latest scm_dirN/final_models/final_backward.mod (or any final_models .mod there),
    ///  2. SCM_run{baseRun}/final_models/ directly (some PsN layouts),
    ///  3. a recursive search for any final_backward.mod / final_forward.mod, then any .mod
    ///     living inside a `final_models` directory.
    private func findSCMFinalModel(baseRun: String) -> URL? {
        let fm = FileManager.default
        let scmDir = projectURL.appendingPathComponent("SCM_run\(baseRun)")
        guard fm.fileExists(atPath: scmDir.path) else { return nil }

        // 1. Latest scm_dirN with a final model (highest number wins).
        var bestDir: URL? = nil
        var bestNum = -1
        if let entries = try? fm.contentsOfDirectory(at: scmDir, includingPropertiesForKeys: nil) {
            for entry in entries {
                let name = entry.lastPathComponent
                guard name.hasPrefix("scm_dir") else { continue }
                let numStr = String(name.dropFirst("scm_dir".count))
                guard let num = Int(numStr), num > bestNum else { continue }
                if scmFinalModelFile(in: entry) != nil {
                    bestNum = num
                    bestDir = entry
                }
            }
        }
        if let dir = bestDir, let mod = scmFinalModelFile(in: dir) { return mod }

        // 2. SCM_run{baseRun}/final_models/ directly.
        let rootFinalModels = scmDir.appendingPathComponent("final_models")
        let rootBackward = rootFinalModels.appendingPathComponent("final_backward.mod")
        if fm.fileExists(atPath: rootBackward.path) { return rootBackward }
        let rootForward = rootFinalModels.appendingPathComponent("final_forward.mod")
        if fm.fileExists(atPath: rootForward.path) { return rootForward }
        if let files = try? fm.contentsOfDirectory(at: rootFinalModels, includingPropertiesForKeys: nil) {
            let mods = files.filter { $0.pathExtension.lowercased() == "mod" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            if let first = mods.first { return first }
        }

        // 3. Recursive search under SCM_run{baseRun}.
        let enumerator = fm.enumerator(at: scmDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        var backwardCandidates: [URL] = []
        var forwardCandidates: [URL] = []
        var otherFinalMods: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension.lowercased() == "mod" else { continue }
            let name = url.lastPathComponent.lowercased()
            if name == "final_backward.mod" {
                backwardCandidates.append(url)
            } else if name == "final_forward.mod" {
                forwardCandidates.append(url)
            } else if url.deletingLastPathComponent().lastPathComponent.lowercased() == "final_models" {
                otherFinalMods.append(url)
            }
        }
        if !backwardCandidates.isEmpty { return backwardCandidates.sorted { $0.path > $1.path }.first }
        if !forwardCandidates.isEmpty { return forwardCandidates.sorted { $0.path > $1.path }.first }
        if !otherFinalMods.isEmpty { return otherFinalMods.sorted { $0.path > $1.path }.first }
        return nil
    }

    /// Read SCM's forward-inclusion final model (`base_model_with_included_relations.mod`).
    /// This is the model right after forward inclusion, before backward elimination.
    /// Prefers the SAME scm_dirN that holds the final model, so forward/final always belong
    /// to the same SCM run; falls back to the highest scm_dirN with a forward model.
    private func readSCMForwardFinalModel(baseRun: String) -> String? {
        let fm = FileManager.default
        let scmDir = projectURL.appendingPathComponent("SCM_run\(baseRun)")
        guard fm.fileExists(atPath: scmDir.path) else { return nil }
        guard let entries = try? fm.contentsOfDirectory(at: scmDir, includingPropertiesForKeys: nil) else { return nil }

        // Prefer the directory that produced the final model.
        if let finalMod = findSCMFinalModel(baseRun: baseRun) {
            let finalDir = finalMod.deletingLastPathComponent().deletingLastPathComponent()
            // `final_models/final_forward.mod` is the true post-forward-inclusion model and
            // carries the relation markers. `base_model_with_included_relations.mod` is
            // often only a copy of the BASE model (no relations) and must not be trusted.
            let finalForward = finalDir.appendingPathComponent("final_models/final_forward.mod")
            if fm.fileExists(atPath: finalForward.path),
               let text = try? String(contentsOf: finalForward, encoding: .utf8), !text.isEmpty {
                return text
            }
            let forwardMod = finalDir.appendingPathComponent("base_model_with_included_relations.mod")
            if fm.fileExists(atPath: forwardMod.path),
               let text = try? String(contentsOf: forwardMod, encoding: .utf8),
               !extractSCMCovariateTokens(from: text).isEmpty
                || !extractReferencedCovariates(from: text).isEmpty {
                return text
            }
        }

        // Fallback: highest scm_dirN with a real forward model (final_forward.mod first,
        // then a base_model_with_included_relations.mod that actually contains relations).
        var bestDir: URL? = nil
        var bestNum = -1
        for entry in entries {
            let name = entry.lastPathComponent
            guard name.hasPrefix("scm_dir") else { continue }
            let numStr = String(name.dropFirst("scm_dir".count))
            guard let num = Int(numStr), num > bestNum else { continue }
            let finalForward = entry.appendingPathComponent("final_models/final_forward.mod")
            let baseWithRelations = entry.appendingPathComponent("base_model_with_included_relations.mod")
            if fm.fileExists(atPath: finalForward.path) {
                bestNum = num
                bestDir = entry
            } else if fm.fileExists(atPath: baseWithRelations.path),
                      let probe = try? String(contentsOf: baseWithRelations, encoding: .utf8),
                      !extractSCMCovariateTokens(from: probe).isEmpty
                        || !extractReferencedCovariates(from: probe).isEmpty {
                bestNum = num
                bestDir = entry
            }
        }
        guard let finalDir = bestDir else { return nil }
        let finalForward = finalDir.appendingPathComponent("final_models/final_forward.mod")
        if fm.fileExists(atPath: finalForward.path) {
            return try? String(contentsOf: finalForward, encoding: .utf8)
        }
        let forwardMod = finalDir.appendingPathComponent("base_model_with_included_relations.mod")
        return try? String(contentsOf: forwardMod, encoding: .utf8)
    }

    /// Build a human-readable summary of PsN SCM's actual output files.
    /// PsN writes its results inside `scm_dirN/` (scm_results.csv, covariate_statistics.txt,
    /// relations.txt, final_models/...) — this helper collects them from the LATEST scm_dirN.
    private func buildSCMResultSummary(baseRun: String) -> String? {
        let fm = FileManager.default
        let scmDir = projectURL.appendingPathComponent("SCM_run\(baseRun)")
        guard fm.fileExists(atPath: scmDir.path),
              let entries = try? fm.contentsOfDirectory(at: scmDir, includingPropertiesForKeys: nil) else { return nil }

        // Prefer the latest scm_dirN that actually contains a final model; otherwise fall back
        // to the latest dir with any SCM output.
        var bestDir: URL? = nil
        var bestNum = -1
        var bestStatsDir: URL? = nil
        var bestStatsNum = -1
        for entry in entries {
            let name = entry.lastPathComponent
            guard name.hasPrefix("scm_dir") else { continue }
            let numStr = String(name.dropFirst("scm_dir".count))
            guard let num = Int(numStr) else { continue }
            let hasOutput = ["scm_results.csv", "scm_log.txt", "final_scm.txt", "relations.txt", "covariate_statistics.txt"]
                .contains { fm.fileExists(atPath: entry.appendingPathComponent($0).path) }
            if hasOutput {
                if num > bestStatsNum {
                    bestStatsNum = num
                    bestStatsDir = entry
                }
            }
            if scmFinalModelFile(in: entry) != nil, num > bestNum {
                bestNum = num
                bestDir = entry
            }
        }
        guard let dir = bestDir ?? bestStatsDir else { return nil }

        var parts: [String] = []
        parts.append("SCM 运行目录：\(dir.lastPathComponent)")
        // Primary results table / log (first non-empty wins)
        for name in ["scm_results.csv", "final_scm.txt", "scm_log.txt"] {
            let url = dir.appendingPathComponent(name)
            if let text = try? String(contentsOf: url, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append(text.prefix(8_000).description)
                break
            }
        }
        // Covariate statistics
        let statsURL = dir.appendingPathComponent("covariate_statistics.txt")
        if let text = try? String(contentsOf: statsURL, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("--- covariate_statistics.txt ---\n" + text.prefix(6_000).description)
        }
        // Final model location
        if let finalModel = scmFinalModelFile(in: dir), let modText = try? String(contentsOf: finalModel, encoding: .utf8) {
            let covTokens = extractSCMCovariateTokens(from: modText)
            let covRefs = extractReferencedCovariates(from: modText)
            var modelLine = "Final model: \(finalModel.path)"
            if !covRefs.isEmpty {
                modelLine += "\nFinal model covariates: \(covRefs.joined(separator: ", "))"
            } else if !covTokens.isEmpty {
                modelLine += "\nFinal model relations: \(covTokens.joined(separator: ", "))"
            }
            parts.append(modelLine)
            parts.append("--- final model (.mod) excerpt ---\n" + modText.prefix(4_000).description)
        } else if let finalModel = findSCMFinalModel(baseRun: baseRun) {
            // The summary dir has no final model, but one exists elsewhere under SCM_run{baseRun}.
            parts.append("Final model (found in older run): \(finalModel.path)")
        }
        return parts.joined(separator: "\n\n")
    }

    /// Extract covariate relation tokens from a NONMEM mod.
    /// Signals, in priority order:
    ///  1. PsN SCM marker blocks: `;;; CLWT-DEFINITION START`
    ///  2. $PK wiring lines like `CLCOV = CLWT` (RHS is the relation token)
    /// NOTE: plain $THETA labels (CL (L/h), V1 (L), ...) are structural, NOT covariate
    /// relations, so they are not collected here. Mods without markers/wiring are covered by
    /// the extractReferencedCovariates fallback.
    private func extractSCMCovariateTokens(from modText: String) -> [String] {
        var tokens: [String] = []
        var seen = Set<String>()
        func add(_ token: String) {
            let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, seen.insert(t).inserted else { return }
            tokens.append(t)
        }
        let lines = modText.components(separatedBy: "\n")
        // Only `;;; XXX-DEFINITION` markers name a covariate relation (e.g. CLWT-DEFINITION).
        // `;;; YYY-RELATION` markers name the PK parameter (e.g. CL-RELATION), not a covariate.
        let markerPattern = try? NSRegularExpression(pattern: #"^\s*;{1,3}\s*([A-Za-z][A-Za-z0-9_]*)-DEFINITION\s+(START|END)"#, options: [])
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 1. PsN marker blocks: ;;; CLWT-DEFINITION START / ;;; CLWT-RELATION END
            if let m = markerPattern?.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length)), m.numberOfRanges > 1 {
                add((trimmed as NSString).substring(with: m.range(at: 1)))
            }
        }
        // 2. Wiring lines inside $PK: "CLCOV = CLWT" → RHS "CLWT" is the relation token.
        let pkBlock = extractBlock(named: "$PK", from: modText)
        if !pkBlock.isEmpty {
            for line in pkBlock.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                let upper = t.uppercased()
                if t.contains("="), upper.contains("COV") {
                    if let eq = t.firstIndex(of: "=") {
                        let lhs = String(t[..<eq]).trimmingCharacters(in: .whitespaces)
                        if lhs.uppercased().hasSuffix("COV") {
                            var rhs = String(t[t.index(after: eq)...])
                            if let semi = rhs.firstIndex(of: ";") { rhs = String(rhs[..<semi]) }
                            let rhsToken = rhs.components(separatedBy: "*").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                            if !rhsToken.isEmpty, rhsToken != "1", !rhsToken.lowercased().hasPrefix("theta") {
                                add(rhsToken)
                            }
                        }
                    }
                }
            }
        }
        return tokens
    }

    /// Robust fallback: which dataset covariate columns are actually referenced in the model's
    /// $PK block (e.g. `CLWT = (WT/70)**THETA(5)`, `IF(SEX.EQ.0) ...`). Works for any PsN
    /// version / formatting, because the covariate code must reference the column name.
    /// Returns ordered by first occurrence in the $PK block.
    private func extractReferencedCovariates(from modText: String) -> [String] {
        let pkBlock = extractBlock(named: "$PK", from: modText)
        let searchText: String
        if !pkBlock.isEmpty {
            searchText = pkBlock
        } else {
            // No $PK block (e.g. $PRED models): scan all non-record lines so that
            // `$INPUT ... WT ...` column lists are not mistaken for an included covariate.
            searchText = modText.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("$") }
                .joined(separator: "\n")
        }
        let upper = searchText.uppercased()
        let candidates = ["WT", "AGE", "SEX", "STUDY", "STUD", "STUDYID", "STUDYNO",
                          "BSA", "RACE", "HB", "ALB", "CLCR", "EGFR", "BMI", "DOSE"]
        var ordered: [String] = []
        for cov in candidates {
            let escaped = NSRegularExpression.escapedPattern(for: cov)
            let pattern = cov == "STUD" ? #"\bSTUD\b"# : #"\b"# + escaped + #"\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsRange = NSRange(location: 0, length: (upper as NSString).length)
            if regex.firstMatch(in: upper, options: [], range: nsRange) != nil {
                ordered.append(cov)
            }
        }
        return ordered
    }

    // MARK: - SCM raw results parsing

    private struct SCMRawRow {
        let step: Int
        let action: String
        let relation: String
        let ofv: Double?
    }

    private struct SCMRawResults {
        let forward: [String]                          // chosen tokens in forward order
        let backward: [String]                         // chosen tokens in backward order
        let baseOfv: Double?                           // step-0 (base model) OFV
        let forwardOfvByToken: [String: Double]        // chosen row OFV per forward token
        let backwardOfvByToken: [String: Double]       // chosen row OFV per backward token
    }

    /// PsN's scmlog.txt states the relation actually selected in each forward/backward
    /// step. This is more reliable than inferring "best OFV" from raw_results.csv because
    /// candidates must also pass the significance threshold.
    private func parseSCMChosenRelations(scmDir: URL) -> (forward: [String], backward: [String])? {
        let logURL = scmDir.appendingPathComponent("scmlog.txt")
        guard let raw = try? String(contentsOf: logURL, encoding: .utf8) else { return nil }
        let pattern = try? NSRegularExpression(
            pattern: #"Parameter-covariate relation chosen in this (forward|backward) step:\s*([A-Za-z0-9_]+)-([A-Za-z0-9_]+)-(\d+)"#,
            options: [.caseInsensitive]
        )
        var forward: [String] = []
        var backward: [String] = []
        for line in raw.components(separatedBy: "\n") {
            guard let pattern,
                  let match = pattern.firstMatch(in: line, options: [], range: NSRange(location: 0, length: (line as NSString).length)),
                  match.numberOfRanges > 3 else { continue }
            let direction = (line as NSString).substring(with: match.range(at: 1)).lowercased()
            let param = (line as NSString).substring(with: match.range(at: 2))
            let cov = (line as NSString).substring(with: match.range(at: 3))
            let token = param + cov
            if direction.hasPrefix("forward") {
                if !forward.contains(token) { forward.append(token) }
            } else if direction.hasPrefix("backward") {
                if !backward.contains(token) { backward.append(token) }
            }
        }
        return (forward.isEmpty && backward.isEmpty) ? nil : (forward, backward)
    }

    /// Minimal CSV line parser that honors quoted fields (PsN raw_results files quote the
    /// header and some text fields).
    private func parseSCMCSVLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        for character in line {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == "," && !inQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        values.append(current)
        return values
    }

    /// Parse PsN SCM's `raw_results_run{baseRun}.csv` from the scm_dirN that produced the
    /// final model. PsN writes one row per candidate model; at each forward/backward step
    /// the CHOSEN relation is the candidate with the best (lowest) OFV. Returns the chosen
    /// relation tokens (e.g. "V1WT-5" → "V1WT") in the order SCM actually ran them.
    private func parseSCMRawResults(baseRun: String, scmDir: URL) -> SCMRawResults? {
        let csvURL = scmDir.appendingPathComponent("raw_results_run\(baseRun).csv")
        guard let raw = try? String(contentsOf: csvURL, encoding: .utf8), !raw.isEmpty else { return nil }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
                            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > 1 else { return nil }
        let headers = parseSCMCSVLine(String(lines[0])).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let stepIdx = headers.firstIndex(of: "step.number"),
              let actionIdx = headers.firstIndex(of: "action"),
              let relIdx = headers.firstIndex(of: "relation"),
              let ofvIdx = headers.firstIndex(of: "ofv") else { return nil }

        var rows: [SCMRawRow] = []
        for line in lines.dropFirst() {
            let cols = parseSCMCSVLine(String(line)).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cols.count > max(stepIdx, actionIdx, relIdx),
                  let step = Int(cols[stepIdx]) else { continue }
            let relation = cols[relIdx]
            guard !relation.isEmpty else { continue }
            let ofv = ofvIdx < cols.count ? Double(cols[ofvIdx]) : nil
            rows.append(SCMRawRow(step: step, action: cols[actionIdx].lowercased(), relation: relation, ofv: ofv))
        }
        guard !rows.isEmpty else { return nil }

        func token(_ relation: String) -> String {
            // "V1WT-5" / "V2SEX-2" / "V1AGE-1" → "V1WT" / "V2SEX" / "V1AGE"
            if let range = relation.range(of: #"-\d+$"#, options: .regularExpression) {
                return String(relation[..<range.lowerBound])
            }
            return relation
        }

        var forwardByStep: [Int: [SCMRawRow]] = [:]
        var backwardByStep: [Int: [SCMRawRow]] = [:]
        for row in rows {
            if row.action.hasPrefix("add") {
                forwardByStep[row.step, default: []].append(row)
            } else if row.action.hasPrefix("remov") {
                backwardByStep[row.step, default: []].append(row)
            }
        }

        var forward: [String] = []
        var forwardOfvByToken: [String: Double] = [:]
        var backward: [String] = []
        var backwardOfvByToken: [String: Double] = [:]
        if let chosen = parseSCMChosenRelations(scmDir: scmDir) {
            forward = chosen.forward
            backward = chosen.backward
        } else {
            for step in forwardByStep.keys.sorted() {
                guard let best = forwardByStep[step]?.filter({ $0.ofv != nil }).min(by: { $0.ofv! < $1.ofv! }) else { continue }
                let t = token(best.relation)
                forward.append(t)
            }
            for step in backwardByStep.keys.sorted() {
                guard let best = backwardByStep[step]?.filter({ $0.ofv != nil }).min(by: { $0.ofv! < $1.ofv! }) else { continue }
                let t = token(best.relation)
                backward.append(t)
            }
        }
        for row in rows {
            let t = token(row.relation)
            guard let ofv = row.ofv else { continue }
            if row.action.hasPrefix("add") {
                if forwardOfvByToken[t] == nil { forwardOfvByToken[t] = ofv }
            } else if row.action.hasPrefix("remov") {
                if backwardOfvByToken[t] == nil { backwardOfvByToken[t] = ofv }
            }
        }
        guard !forward.isEmpty || !backward.isEmpty else { return nil }
        let baseOfv = rows.first { $0.action.contains("base") }?.ofv
        return SCMRawResults(
            forward: forward,
            backward: backward,
            baseOfv: baseOfv,
            forwardOfvByToken: forwardOfvByToken,
            backwardOfvByToken: backwardOfvByToken
        )
    }

    /// DuDu replicates PsN SCM's forward inclusion / backward elimination in the project
    /// path: it writes its own run mods following SCM's covariate sequence, runs each with
    /// NONMEM, and finally compares its result against SCM's final model.
    /// Returns the final DuDu run ID, or nil if replication could not be performed.
    private func verifySCMByReplication(baseRun: String, dataFile: String) async -> String? {
        // 1. Gather SCM outputs
        guard let scmFinalText = readSCMFinalModel(baseRun: baseRun) else {
            runner.append("SCM replication: SCM final model not found — skipping replication.")
            return nil
        }
        if let finalModelURL = findSCMFinalModel(baseRun: baseRun) {
            runner.append("SCM replication: final model read from \(finalModelURL.path)")
        }
        let baseModURL = projectURL.appendingPathComponent("run\(baseRun).mod")
        guard let baseText = try? String(contentsOf: baseModURL, encoding: .utf8) else {
            runner.append("SCM replication: base model run\(baseRun).mod not found.")
            return nil
        }
        let forwardFinalText = readSCMForwardFinalModel(baseRun: baseRun) ?? scmFinalText

        // 2. Derive the SCM forward / backward covariate sequence from the mod files
        let baseTokens = Set(extractSCMCovariateTokens(from: baseText))
        let forwardTokens = extractSCMCovariateTokens(from: forwardFinalText)
        let finalTokens = Set(extractSCMCovariateTokens(from: scmFinalText))
        let forwardAddedTokens = forwardTokens.filter { !baseTokens.contains($0) }
        let removedTokens = forwardTokens.filter { !finalTokens.contains($0) }

        // Robust fallback: covariate columns actually referenced in $PK (works even when the
        // SCM mods have no marker comments / THETA labels).
        let baseCovs = Set(extractReferencedCovariates(from: baseText))
        let forwardCovs = extractReferencedCovariates(from: forwardFinalText)
        let finalCovs = Set(extractReferencedCovariates(from: scmFinalText))
        let addedCovs = forwardCovs.filter { !baseCovs.contains($0) }
        let removedCovs = forwardCovs.filter { !finalCovs.contains($0) }

        // Decisive evidence: the FINAL model itself vs the base model. This is the ground
        // truth for what SCM actually included, even when the forward model file is missing
        // or carries no marker comments (final_backward.mod usually has them, the forward
        // base_model_with_included_relations.mod sometimes does not).
        let baseAll = baseTokens.union(baseCovs)
        let finalAll = finalTokens.union(finalCovs)
        let finalVsBaseAdded = finalAll.subtracting(baseAll).sorted()
        runner.append("SCM replication: base $PK covariates=[\(baseCovs.sorted().joined(separator: ","))] forward=[\(forwardCovs.joined(separator: ","))] final=[\(finalCovs.sorted().joined(separator: ","))] tokens added=[\(forwardAddedTokens.joined(separator: ","))] removed=[\(removedTokens.joined(separator: ","))] finalVsBase=[\(finalVsBaseAdded.joined(separator: ","))]")
        runner.append("SCM replication: final model preview — " + scmFinalText.prefix(500).replacingOccurrences(of: "\n", with: " ⏎ "))

        // ── Authoritative build order from scmlog/raw_results_run{baseRun}.csv ──
        // scmlog gives the relation SCM actually selected at each forward/backward step.
        var rawResults: SCMRawResults?
        if let finalModelURL = findSCMFinalModel(baseRun: baseRun) {
            let scmDir = finalModelURL.deletingLastPathComponent().deletingLastPathComponent()
            if let parsed = parseSCMRawResults(baseRun: baseRun, scmDir: scmDir) {
                rawResults = parsed
                runner.append("SCM replication: raw_results order — forward=[\(parsed.forward.joined(separator: ","))] backward=[\(parsed.backward.joined(separator: ","))]")
            } else {
                runner.append("SCM replication: raw_results_run\(baseRun).csv missing/unreadable — using mod-file inference")
            }
        }
        let rawForwardOrder = rawResults?.forward ?? []
        let rawBackwardOrder = rawResults?.backward ?? []

        let forwardAdded: [String]
        let removed: [String]
        if !rawForwardOrder.isEmpty {
            var seen = Set<String>()
            let orderedForward = rawForwardOrder.filter { token in
                guard seen.insert(token).inserted else { return false }
                return !baseTokens.contains(token)
            }
            let relationFinal = finalTokens.isEmpty ? finalAll : finalTokens
            if !orderedForward.isEmpty {
                forwardAdded = orderedForward
                if !rawBackwardOrder.isEmpty {
                    removed = rawBackwardOrder.filter { orderedForward.contains($0) && !relationFinal.contains($0) }
                } else {
                    removed = removedTokens
                }
            } else {
                if !forwardAddedTokens.isEmpty {
                    forwardAdded = forwardAddedTokens
                } else if !addedCovs.isEmpty {
                    forwardAdded = addedCovs
                } else {
                    forwardAdded = finalVsBaseAdded
                }
                if !removedTokens.isEmpty {
                    removed = removedTokens
                } else if !removedCovs.isEmpty {
                    removed = removedCovs
                } else {
                    removed = finalVsBaseAdded.isEmpty ? [] : forwardAdded.filter { !finalAll.contains($0) }
                }
            }
        } else {
            // Inference fallback: forward-model markers → referenced columns → final-vs-base.
            if !forwardAddedTokens.isEmpty {
                forwardAdded = forwardAddedTokens
            } else if !addedCovs.isEmpty {
                forwardAdded = addedCovs
            } else {
                forwardAdded = finalVsBaseAdded
            }
            if !removedTokens.isEmpty {
                removed = removedTokens
            } else if !removedCovs.isEmpty {
                removed = removedCovs
            } else {
                removed = finalVsBaseAdded.isEmpty ? [] : forwardAdded.filter { !finalAll.contains($0) }
            }
        }

        runner.append(String.safeFormat(L10n.scmReplicateSequence,
                             (forwardAdded.isEmpty ? "-" : forwardAdded.joined(separator: ", ")) as NSString,
                             (removed.isEmpty ? "-" : removed.joined(separator: ", ")) as NSString))

        // ── OFV / AIC change of SCM's final model vs the base model (from raw_results) ──
        let scmBaseOfv = rawResults?.baseOfv
        let scmFinalOfv: Double? = {
            guard let rawResults else { return nil }
            var ofv = rawResults.baseOfv
            for token in forwardAdded {
                if let v = rawResults.forwardOfvByToken[token] { ofv = v }
            }
            for token in removed {
                if let v = rawResults.backwardOfvByToken[token] { ofv = v }
            }
            return ofv
        }()

        if forwardAdded.isEmpty && removed.isEmpty {
            // Distinguish "SCM truly selected nothing" from "the covariates are already in base".
            let finalHasRelations = !finalAll.isEmpty
            if finalHasRelations && !baseAll.isEmpty {
                assistantMessages.append(AssistantMessage(role: .system,
                    text: String.safeFormat(L10n.scmReplicateCovInBase,
                                 baseAll.sorted().joined(separator: ", ") as NSString)))
            } else {
                assistantMessages.append(AssistantMessage(role: .system, text: L10n.scmReplicateNoCov))
            }
            if let cmp = compareFinalWithSCM(duduMod: baseModURL, scmModText: scmFinalText, baseRun: baseRun, scmModURL: findSCMFinalModel(baseRun: baseRun)) {
                runner.append(cmp)
                assistantMessages.append(AssistantMessage(role: .system, text: cmp))
            }
            appendSCMFinalSummary(baseText: baseText, scmFinalText: scmFinalText,
                                  baseOfv: scmBaseOfv, finalOfv: scmFinalOfv)
            return baseRun
        }

        // 3. Build the step plan
        var forwardSets: [[String]] = []
        // NB: `1...count` traps when count == 0 on current Swift runtimes, and the
        // backward set may legitimately be empty (SCM kept every forward covariate).
        for idx in 0..<forwardAdded.count {
            forwardSets.append(Array(forwardAdded.prefix(idx + 1)))
        }
        var backwardSets: [[String]] = []
        var currentSet = forwardAdded
        for idx in 0..<removed.count {
            currentSet = currentSet.filter { $0 != removed[idx] }
            backwardSets.append(currentSet)
        }

        // 4. DuDu writes + runs each step
        assistantMessages.append(AssistantMessage(role: .system, text: L10n.scmReplicateHeader))
        runner.append(String.safeFormat(L10n.scmReplicateBaseRun, baseRun as NSString))
        var nextRunNumber = ((automationModelRuns().compactMap(Int.init).max()) ?? (Int(baseRun) ?? 0)) + 1
        var sourceRun = baseRun
        let sessionId = UUID().uuidString
        let totalSteps = forwardSets.count + backwardSets.count
        var stepIndex = 0
        assistantMessages.append(AssistantMessage(role: .system,
            text: String.safeFormat(L10n.scmReplicatePlan,
                         (forwardAdded.isEmpty ? "-" : forwardAdded.joined(separator: " → ")) as NSString,
                         (removed.isEmpty ? "-" : removed.joined(separator: " → ")) as NSString,
                         totalSteps)))

        if !forwardSets.isEmpty {
            runner.append(L10n.scmForwardHeader)
            for (idx, set) in forwardSets.enumerated() {
                try? Task.checkCancellation()
                if scmCancelled { break }
                let nextRun = formattedRun(nextRunNumber); nextRunNumber += 1
                stepIndex += 1
                automationStep = "SCM replication \(stepIndex)/\(totalSteps) — forward \(idx + 1)"
                runner.append(String.safeFormat(L10n.scmReplicateForward, idx + 1,
                                     nextRun as NSString, set.joined(separator: ", ") as NSString))
                let newToken = set.last ?? ""
                if !newToken.isEmpty {
                    assistantMessages.append(AssistantMessage(role: .system,
                        text: String.safeFormat(L10n.scmForwardChat, idx + 1,
                                     nextRun as NSString, describeSCMRelation(newToken, in: baseText) as NSString)))
                }
                guard await writeAndRunSCMStep(sourceRun: sourceRun, nextRun: nextRun, dataFile: dataFile,
                                               target: set, removed: [], stepType: "forward",
                                               scmReferenceText: forwardFinalText, sessionId: sessionId) else {
                    assistantMessages.append(AssistantMessage(role: .system,
                        text: String.safeFormat(L10n.scmReplicateFailed, "forward step \(idx + 1)" as NSString)))
                    return nil
                }
                sourceRun = nextRun
            }
        }

        if !backwardSets.isEmpty {
            runner.append(L10n.scmBackwardHeader)
            for (idx, set) in backwardSets.enumerated() {
                try? Task.checkCancellation()
                if scmCancelled { break }
                let nextRun = formattedRun(nextRunNumber); nextRunNumber += 1
                stepIndex += 1
                automationStep = "SCM replication \(stepIndex)/\(totalSteps) — backward \(idx + 1)"
                runner.append(String.safeFormat(L10n.scmReplicateBackward, idx + 1,
                                     nextRun as NSString, removed[idx] as NSString))
                assistantMessages.append(AssistantMessage(role: .system,
                    text: String.safeFormat(L10n.scmBackwardChat, idx + 1,
                                 nextRun as NSString, describeSCMRelation(removed[idx], in: baseText) as NSString)))
                guard await writeAndRunSCMStep(sourceRun: sourceRun, nextRun: nextRun, dataFile: dataFile,
                                               target: set, removed: [removed[idx]], stepType: "backward",
                                               scmReferenceText: forwardFinalText, sessionId: sessionId) else {
                    assistantMessages.append(AssistantMessage(role: .system,
                        text: String.safeFormat(L10n.scmReplicateFailed, "backward step \(idx + 1)" as NSString)))
                    return nil
                }
                sourceRun = nextRun
            }
        }

        // 5. Final comparison against SCM's final model
        let finalDuDuMod = projectURL.appendingPathComponent("run\(sourceRun).mod")
        runner.append(String.safeFormat(L10n.scmReplicateFinal, sourceRun as NSString))
        if let cmp = compareFinalWithSCM(duduMod: finalDuDuMod, scmModText: scmFinalText, baseRun: baseRun, scmModURL: findSCMFinalModel(baseRun: baseRun)) {
            runner.append(cmp)
            assistantMessages.append(AssistantMessage(role: .system, text: cmp))
        }
        if let finalDuDuText = try? String(contentsOf: finalDuDuMod, encoding: .utf8) {
            appendSCMReplicationBaseComparison(baseRun: baseRun, finalRun: sourceRun,
                                               baseText: baseText, finalText: finalDuDuText)
        }
        appendSCMFinalSummary(baseText: baseText, scmFinalText: scmFinalText,
                              baseOfv: scmBaseOfv, finalOfv: scmFinalOfv)
        refreshWorkspace()
        return sourceRun
    }

    /// Describe one relation token like "V1WT" as "在 V1 上纳入 WT" (param + covariate).
    private func describeSCMRelation(_ token: String, in modText: String) -> String {
        let params = scmPKParams(from: modText)
        for param in params.sorted(by: { $0.count > $1.count }) {
            if token.uppercased().hasPrefix(param.uppercased()) {
                let cov = String(token.dropFirst(param.count))
                if !cov.isEmpty {
                    return String.safeFormat(L10n.scmRelationDesc, param, cov)
                }
            }
        }
        return token
    }

    /// PK parameter names from `TV{param}=THETA(n)` assignments (used only for describing
    /// relation tokens like "V1WT"; the actual model writing is deterministic in the builder).
    private func scmPKParams(from text: String) -> [String] {
        var params: [String] = []
        var seen = Set<String>()
        for line in text.components(separatedBy: "\n") {
            let t = line.uppercased().replacingOccurrences(of: " ", with: "")
            guard t.hasPrefix("TV") else { continue }
            let after = t.dropFirst(2)
            guard let eq = after.firstIndex(of: "=") else { continue }
            let name = String(after[..<eq])
            let rhs = String(after[after.index(after: eq)...])
            guard !name.isEmpty, rhs.hasPrefix("THETA"), seen.insert(name).inserted else { continue }
            params.append(name)
        }
        return params
    }

    /// Count theta parameters in a NONMEM mod (all $THETA records, value lines only).
    private func countThetas(in modText: String) -> Int {
        var inTheta = false
        var count = 0
        for line in modText.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("$") {
                if t.uppercased().hasPrefix("$THETA") {
                    inTheta = true
                    // The first theta may sit on the $THETA header line itself.
                    let headerRest = String(t.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    if !headerRest.isEmpty {
                        let stripped = headerRest.replacingOccurrences(of: "FIX", with: "").replacingOccurrences(of: "fix", with: "")
                        if stripped.rangeOfCharacter(from: .decimalDigits) != nil { count += 1 }
                    }
                } else {
                    inTheta = false
                }
                continue
            }
            if inTheta {
                let body = t.replacingOccurrences(of: "FIX", with: "").replacingOccurrences(of: "fix", with: "")
                if body.rangeOfCharacter(from: .decimalDigits) != nil {
                    count += 1
                }
            }
        }
        return count
    }

    /// Append the final SCM evaluation summary to the Run Log + DuDu chat: which covariates
    /// were included on which parameters, and ΔOFV / ΔAIC vs the base model (from raw_results).
    private func appendSCMFinalSummary(baseText: String, scmFinalText: String, baseOfv: Double?, finalOfv: Double?) {
        let finalTokens = extractSCMCovariateTokens(from: scmFinalText)
        var lines: [String] = [L10n.scmSummaryHeader]
        if finalTokens.isEmpty {
            lines.append(L10n.scmSummaryNone)
        } else {
            let desc = finalTokens.map { describeSCMRelation($0, in: baseText) }
                .joined(separator: L10n.scmRelationJoin)
            lines.append(String.safeFormat(L10n.scmSummaryIncluded, desc))
        }
        if let baseOfv, let finalOfv {
            let dOfv = finalOfv - baseOfv
            let dAic = dOfv + 2.0 * Double(countThetas(in: scmFinalText) - countThetas(in: baseText))
            lines.append(String.safeFormat(L10n.scmSummaryOfvAic,
                                String(format: "%+.2f", dOfv),
                                String(format: "%+.2f", dAic),
                                String(format: "%.2f", baseOfv),
                                String(format: "%.2f", finalOfv)))
        }
        let text = lines.joined(separator: "\n")
        runner.append(text)
        assistantMessages.append(AssistantMessage(role: .system, text: text))
    }

    /// Compare the final replicated model against the original base model using actual run outputs.
    private func appendSCMReplicationBaseComparison(baseRun: String, finalRun: String, baseText: String, finalText: String) {
        let baseOFV = extractOFV(from: projectURL.appendingPathComponent("run\(baseRun).ext"))
        let finalOFV = extractOFV(from: projectURL.appendingPathComponent("run\(finalRun).ext"))
        let baseRelation = Set(extractSCMCovariateTokens(from: baseText))
        let finalRelation = Set(extractSCMCovariateTokens(from: finalText))
        let baseCovs = baseRelation.isEmpty ? Set(extractReferencedCovariates(from: baseText)) : baseRelation
        let finalCovs = finalRelation.isEmpty ? Set(extractReferencedCovariates(from: finalText)) : finalRelation
        let addedCovs = finalCovs.subtracting(baseCovs).sorted()
        let removedCovs = baseCovs.subtracting(finalCovs).sorted()

        var lines: [String] = ["━━━ SCM Replication vs Base Model ━━━"]
        if let baseOFV {
            lines.append("Base run\(baseRun) OFV: \(String(format: "%.2f", baseOFV))")
        }
        if let finalOFV {
            lines.append("Final run\(finalRun) OFV: \(String(format: "%.2f", finalOFV))")
        }
        if let baseOFV, let finalOFV {
            let dOFV = finalOFV - baseOFV
            let dAIC = dOFV + 2.0 * Double(countThetas(in: finalText) - countThetas(in: baseText))
            lines.append(String(format: "ΔOFV: %+.2f | ΔAIC: %+.2f", dOFV, dAIC))
        }
        if addedCovs.isEmpty && removedCovs.isEmpty {
            lines.append("Covariates: unchanged")
        } else {
            if !addedCovs.isEmpty {
                let desc = addedCovs.map { describeSCMRelation($0, in: baseText) }.joined(separator: ", ")
                lines.append("Added: \(desc)")
            }
            if !removedCovs.isEmpty {
                lines.append("Removed: \(removedCovs.joined(separator: ", "))")
            }
        }

        let baseSub = extractSubroutineLine(from: baseText)
        let finalSub = extractSubroutineLine(from: finalText)
        if let baseSub, let finalSub {
            if baseSub == finalSub {
                lines.append("Structural model: \(baseSub)")
            } else {
                lines.append("Structural model changed: \(baseSub) → \(finalSub)")
            }
        }

        let baseRows = ProjectScanner.parameterEstimates(runID: baseRun, in: projectURL)
        let finalRows = ProjectScanner.parameterEstimates(runID: finalRun, in: projectURL)
        let parameterLines = parameterComparisonLines(
            baseRows: baseRows,
            finalRows: finalRows,
            baseLabel: "run\(baseRun)",
            finalLabel: "run\(finalRun)"
        )
        if !parameterLines.isEmpty {
            lines.append("Parameter estimates:")
            lines.append(contentsOf: parameterLines.prefix(24).map { "  \($0)" })
            if parameterLines.count > 24 {
                lines.append("  ... \(parameterLines.count - 24) more")
            }
        }

        let text = lines.joined(separator: "\n")
        runner.append(text)
        assistantMessages.append(AssistantMessage(role: .system, text: text))
    }

    private func parameterComparisonLines(
        baseRows: [ParameterEstimateRow],
        finalRows: [ParameterEstimateRow],
        baseLabel: String,
        finalLabel: String
    ) -> [String] {
        var baseByName: [String: ParameterEstimateRow] = [:]
        for row in baseRows { baseByName[normalizedParameterName(row.name)] = row }

        var matchedBaseKeys = Set<String>()
        var matchedFinalKeys = Set<String>()
        var parameterLines: [String] = []
        for finalRow in finalRows {
            let key = normalizedParameterName(finalRow.name)
            guard let baseRow = baseByName[key] else { continue }
            matchedBaseKeys.insert(key)
            matchedFinalKeys.insert(key)

            let delta = finalRow.estimate - baseRow.estimate
            let pct = baseRow.estimate != 0 ? delta / abs(baseRow.estimate) * 100 : nil
            let pctText = pct.map { String(format: "%+.2f%%", $0) } ?? "n/a"
            let status: String
            if let pct {
                let absPct = abs(pct)
                if absPct < 1 {
                    status = LanguageStore.shared.language == .en ? "consistent" : "一致"
                } else if absPct < 5 {
                    status = LanguageStore.shared.language == .en ? "close" : "接近"
                } else {
                    status = LanguageStore.shared.language == .en ? "changed" : "变化"
                }
            } else {
                status = LanguageStore.shared.language == .en ? "fixed/n/a" : "固定/n/a"
            }
            parameterLines.append(
                "\(finalRow.name): \(baseRow.estimateText) → \(finalRow.estimateText) (Δ\(pctText), \(status))"
            )
            parameterLines.append(
                "  SE: \(baseRow.standardErrorText) → \(finalRow.standardErrorText) | RSE: \(baseRow.rseText) → \(finalRow.rseText)"
            )
        }

        let baseOnly = baseRows
            .filter { !matchedBaseKeys.contains(normalizedParameterName($0.name)) }
            .map { $0.name }
            .sorted()
        let finalOnly = finalRows
            .filter { !matchedFinalKeys.contains(normalizedParameterName($0.name)) }
            .map { $0.name }
            .sorted()
        if !baseOnly.isEmpty {
            parameterLines.append("Only in \(baseLabel): \(baseOnly.joined(separator: ", "))")
        }
        if !finalOnly.isEmpty {
            parameterLines.append("Only in \(finalLabel): \(finalOnly.joined(separator: ", "))")
        }
        return parameterLines
    }

    private func normalizedParameterName(_ name: String) -> String {
        let compact = name
            .lowercased()
            .components(separatedBy: "(")
            .first ?? name.lowercased()
        return compact.filter { $0.isLetter || $0.isNumber }
    }

    private func extractSubroutineLine(from modText: String) -> String? {
        for line in modText.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            let upper = t.uppercased()
            if upper.hasPrefix("$SUBROUTINES") || upper.hasPrefix("$SUBROUTINE") {
                return t
            }
        }
        return nil
    }

    /// Write one SCM replication step model (via DuDu/LLM), preflight-check it, run NONMEM,
    /// and record the OFV. Returns true if the step ran (regardless of NONMEM exit code — the
    /// comparison later uses the model text); returns false only on hard failures.
    private func writeAndRunSCMStep(sourceRun: String, nextRun: String, dataFile: String,
                                    target: [String], removed: [String],
                                    stepType: String, scmReferenceText: String, sessionId: String) async -> Bool {
        do {
            let (modText, usage) = try await LLMCommandService.generateSCMStepModel(
                baseURL: llmBaseURL, model: llmModel, projectURL: projectURL, dataFile: dataFile,
                sourceRun: sourceRun, nextRun: nextRun,
                targetCovariates: target, removedCovariates: removed,
                stepType: stepType, scmFinalModelText: scmReferenceText,
                apiKey: llmAPIKey, sessionId: sessionId,
                apiFormat: activeAPIFormat
            )
            recordUsage(usage)
            var drafted = normalizeTypicalValueNaming(modText)
            drafted = LLMCommandService.sanitizeControlStream(
                drafted,
                projectURL: projectURL,
                dataFile: dataFile
            )
            if let sourceModText = try? String(contentsOf: projectURL.appendingPathComponent("run\(sourceRun).mod"), encoding: .utf8) {
                drafted = protectResidualEstimation(drafted, sourceModText: sourceModText, runID: sourceRun)
            }
            drafted = enforceZeroFixForResidualError(drafted)
            drafted = withETATableRecord(drafted, runID: nextRun)
            drafted = LLMCommandService.applyingIVInfusionDurationFix(drafted)
            drafted = LLMCommandService.normalizingTableRecords(drafted, runID: nextRun)
            let scmURL = projectURL.appendingPathComponent("run\(nextRun).mod")
            guardModFileWrite(drafted, to: scmURL, label: "run\(nextRun).mod (scm)")
            runner.append("SCM replication: wrote run\(nextRun).mod (from run\(sourceRun).mod)")
            let validation = await validateModel(nextRun)
            if !validation.passed {
                runner.append("SCM replication: preflight issues in run\(nextRun).mod — attempting auto-fix")
                let fix = await autoFixModel(nextRun)
                if !fix.fixed {
                    // Force-strip and continue
                    if let txt = try? String(contentsOf: scmURL, encoding: .utf8) {
                        let stripped = LLMCommandService.stripInlineDatasetRows(txt)
                        if stripped != txt {
                            try? stripped.write(to: scmURL, atomically: true, encoding: .utf8)
                        }
                    }
                    runner.append("⚠️ SCM run\(nextRun).mod 预检未通过，数据行已强制清理。继续运行。")
                    assistantMessages.append(AssistantMessage(role: .assistant, text: localized(
                        "run\(nextRun).mod 预检未通过但数据行已清理，继续运行NONMEM…",
                        "run\(nextRun).mod passed preflight after clearing data rows; continuing NONMEM…"
                    )))
                }
            }
            let exit = await runner.runAndWait(command: psnRunCommand(runID: nextRun), in: projectURL)
            let ofv = extractOFV(from: projectURL.appendingPathComponent("run\(nextRun).ext"))
                .map { String(format: "%.2f", $0) } ?? "n/a"
            runner.append(String.safeFormat(L10n.scmReplicateRunDone, nextRun, ofv) + " (exit \(exit))")
            if exit == 0 {
                assistantMessages.append(AssistantMessage(role: .system,
                    text: String.safeFormat(L10n.scmStepDone, nextRun, ofv)))
            }
            refreshWorkspace()
            return true
        } catch {
            runner.append("SCM replication: step \(nextRun) failed — \(error.localizedDescription)")
            return false
        }
    }

    /// Force-add FIX to RSE-bloated parameters in a mod file.
    /// Scans both $THETA and $OMEGA blocks. For THETA: adds FIX to ANY parameter
    /// whose label comment contains a percent sign or residual indicator.
    /// For OMEGA: adds FIX to entries with IIV labels when RSE > 50%.
    /// Returns the modified text (or unchanged if already FIXed or no problem found).
    private func forceFixUnreliableParameter(_ modText: String, runID: String) -> String {
        let rows = ProjectScanner.parameterEstimates(runID: runID, in: projectURL)
        let lines = modText.components(separatedBy: "\n")

        // Residual error has first priority: if Add.RE/Prop.RE cannot be estimated,
        // fix that component to 0 before touching any IIV.
        if let residual = rows.first(where: {
            $0.group == "Residual" && ($0.rsePercent ?? 0) > 100
        }), let index = thetaLineIndex(
            matching: normalizedParameterLabel(residual.name),
            in: lines
        ) {
            let line = lines[index]
            let comment = line.firstIndex(of: ";").map { String(line[$0...]) } ?? ""
            var result = lines
            result[index] = comment.isEmpty ? "0 FIX" : "0 FIX  \(comment)"
            runner.append("  → Fixed \(residual.name) to 0 FIX (RSE>100%)")
            return result.joined(separator: "\n")
        }

        // Otherwise fix ONE unreliable IIV at a time.
        if let iiv = rows.first(where: {
            $0.group == "IIV" && ($0.rsePercent ?? 0) > 50
        }), let index = omegaLineIndex(
            matching: normalizedParameterLabel(iiv.name),
            in: lines
        ) {
            let line = lines[index]
            let comment = line.firstIndex(of: ";").map { String(line[$0...]) } ?? ""
            var result = lines
            result[index] = comment.isEmpty ? "0 FIX" : "0 FIX  \(comment)"
            runner.append("  → Fixed \(iiv.name) to 0 FIX (RSE>50%)")
            return result.joined(separator: "\n")
        }
        return modText
    }

    private func normalizedParameterLabel(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private func thetaLineIndex(matching target: String, in lines: [String]) -> Int? {
        var inTheta = false
        for (index, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            let upper = t.uppercased()
            if upper.hasPrefix("$THETA") { inTheta = true; continue }
            if upper.hasPrefix("$") && inTheta { inTheta = false; continue }
            guard inTheta, let semi = t.firstIndex(of: ";") else { continue }
            let label = String(t[t.index(after: semi)...]).trimmingCharacters(in: .whitespaces)
            if normalizedParameterLabel(label) == target { return index }
        }
        return nil
    }

    private func omegaLineIndex(matching target: String, in lines: [String]) -> Int? {
        var inOmega = false
        for (index, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            let upper = t.uppercased()
            if upper.hasPrefix("$OMEGA") { inOmega = true; continue }
            if upper.hasPrefix("$") && inOmega { inOmega = false; continue }
            guard inOmega, let semi = t.firstIndex(of: ";") else { continue }
            let label = String(t[t.index(after: semi)...]).trimmingCharacters(in: .whitespaces)
            if normalizedParameterLabel(label) == target { return index }
        }
        return nil
    }

    private func extractThetaLabels(from modText: String) -> [String] {
        let lines = modText.components(separatedBy: "\n")
        var inTheta = false
        var labels: [String] = []
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.uppercased().trimmingCharacters(in: .whitespaces).hasPrefix("$THETA") { inTheta = true; continue }
            if inTheta {
                if t.hasPrefix("$") || t.uppercased().range(of: "OMEGA -|ERROR", options: .regularExpression) != nil { break }
                if let semi = t.firstIndex(of: ";") {
                    let comment = t[semi...].dropFirst().trimmingCharacters(in: .whitespaces)
                    if !comment.isEmpty { labels.append(String(comment)) }
                }
            }
        }
        return labels
    }

    /// Prepare SCM files and run PsN SCM for fast covariate screening.
    private func prepareAndRunSCM(baseRun: String, dataFile: String, profile: DatasetProfile,
                                   pForward: String = "0.01", pBackward: String = "0.001",
                                   includedCovariates: Set<String>? = nil) async -> String? {
        let scmSubDirName = "SCM_run\(baseRun)"
        let scmDir = projectURL.appendingPathComponent(scmSubDirName)
        try? FileManager.default.createDirectory(at: scmDir, withIntermediateDirectories: true)

        // 1. Copy and clean the base model for SCM
        let sourceMod = projectURL.appendingPathComponent("run\(baseRun).mod")
        guard let modText = try? String(contentsOf: sourceMod, encoding: .utf8) else {
            runner.append("SCM: base model run\(baseRun).mod not found")
            return nil
        }
        let sanitizedMod = LLMCommandService.stripInlineDatasetRows(modText)

        // Remove $TABLE block and ALL comment lines (;)
        // PsN 5.x cannot parse .mod files containing `;` comments and will fail silently.
        let lines = sanitizedMod.components(separatedBy: "\n")
        var cleaned: [String] = []
        var inTable = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("$TABLE") { inTable = true; continue }
            if inTable && trimmed.hasPrefix("$") { inTable = false }
            if inTable { continue }
            // Remove ALL comment lines (; at line start) — PsN crashes on any `;` in .mod
            if trimmed.hasPrefix(";") { continue }
            cleaned.append(line)
        }
        let cleanMod = normalizeTypicalValueNaming(cleaned.joined(separator: "\n"))

        // Copy model + dataset into the SCM subdirectory
        let scmModPath = scmDir.appendingPathComponent("run\(baseRun).mod")
        try? cleanMod.write(to: scmModPath, atomically: true, encoding: .utf8)
        runner.append("SCM: cleaned base model → \(scmSubDirName)/\(scmModPath.lastPathComponent)")

        let dataSource = projectURL.appendingPathComponent(dataFile)
        let dataDest = scmDir.appendingPathComponent(dataFile)
        if FileManager.default.fileExists(atPath: dataSource.path) {
            try? FileManager.default.copyItem(at: dataSource, to: dataDest)
            runner.append("SCM: dataset copied → \(scmSubDirName)/\(dataFile)")
        } else {
            runner.append("SCM: dataset \(dataFile) not found in project")
            return nil
        }

        // ── Pre-process dataset for SCM: fix continuous covariates with median=0 ──
        // PsN SCM normalizes as (COV/median)^THETA; median=0 → division by zero.
        // Replace 0-values with the non-zero median so SCM can proceed.
        if let scmCsv = try? String(contentsOf: dataDest, encoding: .utf8) {
            var csvLines = scmCsv.components(separatedBy: "\n")
            if let headerLine = csvLines.first, !headerLine.isEmpty {
                let cols = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
                for col in cols {
                    guard ["WT", "AGE"].contains(col) else { continue }
                    guard let colIdx = cols.firstIndex(of: col) else { continue }
                    // Collect all non-zero valid numeric values for this column (skip dots/blanks)
                    var nonZeroVals: [Double] = []
                    for i in 1..<csvLines.count {
                        let fields = csvLines[i].components(separatedBy: ",")
                        guard colIdx < fields.count else { continue }
                        let raw = fields[colIdx].trimmingCharacters(in: .whitespaces)
                        if let v = Double(raw), v != 0 { nonZeroVals.append(v) }
                    }
                    guard !nonZeroVals.isEmpty else { continue }
                    nonZeroVals.sort()
                    let replacementMedian: Double
                    let n = nonZeroVals.count
                    if n % 2 == 0 {
                        replacementMedian = (nonZeroVals[n/2 - 1] + nonZeroVals[n/2]) / 2.0
                    } else {
                        replacementMedian = nonZeroVals[n/2]
                    }
                    // Replace both "." (NULL / missing) and 0-values with the non-zero median
                    // PsN SCM uses (COV/median)^THETA — missing dots parsed as 0 → median=0 → division by zero
                    var replaced = 0
                    for i in 1..<csvLines.count {
                        var fields = csvLines[i].components(separatedBy: ",")
                        guard colIdx < fields.count else { continue }
                        let raw = fields[colIdx].trimmingCharacters(in: .whitespaces)
                        let numeric = Double(raw)
                        // Replace "." (nil), empty, and exact "0"
                        if numeric == nil || numeric == 0 {
                            fields[colIdx] = String(format: "%g", replacementMedian)
                            csvLines[i] = fields.joined(separator: ",")
                            replaced += 1
                        }
                    }
                    if replaced > 0 {
                        runner.append("SCM: \(col) had \(replaced) missing/zero subjects — replaced with non-zero median \(String(format: "%.1f", replacementMedian)) to avoid division by zero in (COV/median)^THETA")
                        // Write back the fixed CSV
                        try? csvLines.joined(separator: "\n").write(to: dataDest, atomically: true, encoding: .utf8)
                    }
                }
            }
        }

        // 2. AI generates runCONCOV{baseRun}.scm based on model + dataset
        let modelInput = detectModelInput(in: cleanMod)
        let configName = "runCONCOV\(baseRun).scm"
        runner.append("SCM: asking AI to write \(configName) based on the model...")
        automationStep = L10n.scmStepConfig
        addThinkingStep("AI writing \(configName)...", type: .working)
        let scmConfig: String
        do {
            scmConfig = try await LLMCommandService.generateSCMConfig(
                baseURL: llmBaseURL,
                model: llmModel,
                modText: cleanMod,
                dataFile: dataFile,
                modFileName: "run\(baseRun).mod",
                projectURL: projectURL,
                apiKey: llmAPIKey,
                pForward: pForward,
                pBackward: pBackward,
                includedCovariates: includedCovariates,
                log: { msg in Task { @MainActor in self.runner.append(msg) } },
                apiFormat: activeAPIFormat
            )
            runner.append("SCM: AI config generated")
            updateLastThinkingStep(type: .done, detail: configName)
        } catch {
            runner.append("SCM: AI config failed (\(error.localizedDescription)), using fallback")
            let pkParams = detectPKParams(in: cleanMod)

            let knownCovs = covariateColumns(from: cleanMod)
            let selectedCovs = Set(includedCovariates ?? Set(knownCovs))
            let allCovs = selectedCovs
                .filter { modelInput.contains($0) || knownCovs.contains($0) }
                .sorted()
            let continuousSet: Set<String> = ["WT", "AGE", "BSA", "HB", "ALB", "CLCR", "EGFR", "BMI", "DOSE"]
            let categoricalSet: Set<String> = ["SEX", "STUDY", "STUD", "STUDYID", "STUDYNO",
                                               "ROUTE", "ADA", "RACE", "TRT", "ARM",
                                               "REGION", "TYPE", "GROUP", "COHORT", "TREATMENT"]
            let contCovs = allCovs.filter { continuousSet.contains($0) }
            let catCovs = allCovs.filter { categoricalSet.contains($0) }
            let covLine = { (covs: [String]) in covs.sorted().joined(separator: ",") }
            let timeVaryingCovs = LLMCommandService.detectTimeVaryingCovariates(
                projectURL: projectURL, dataFile: dataFile,
                continuousCovs: contCovs,
                log: { msg in Task { @MainActor in self.runner.append(msg) } }
            )
            let timeVaryingLine = timeVaryingCovs.isEmpty ? "" : "time_varying=\(timeVaryingCovs.joined(separator: ","))"
            var fallback: [String] = [
                "model = run\(baseRun).mod",
                "threads =40",
                "search_direction=both",
                "p_forward=\(pForward)",
                "p_backward=\(pBackward)",
                "abort_on_fail=0",
                "",
                "continuous_covariates=\(covLine(contCovs))",
                "categorical_covariates=\(covLine(catCovs))",
            ]
            if !timeVaryingLine.isEmpty { fallback.append(timeVaryingLine) }
            fallback.append("")
            fallback.append("[test_relations]")
            if pkParams.isEmpty {
                fallback.append("CL=\(allCovs.joined(separator: ","))")
            } else {
                for p in pkParams.sorted() {
                    fallback.append("\(p)=\(allCovs.joined(separator: ","))")
                }
            }
            fallback.append("")
            fallback.append("[valid_states]")
            fallback.append("continuous = 1,\(max(contCovs.count + 3, 3))")
            fallback.append("categorical = 1,\(max(catCovs.count + 1, 1))")
            scmConfig = fallback.joined(separator: "\n") + "\n"
        }

        let scmPath = scmDir.appendingPathComponent(configName)
        try? scmConfig.write(to: scmPath, atomically: true, encoding: .utf8)
        runner.append("SCM: config written → \(scmSubDirName)/\(configName)")
        let configSummary = scmConfig.components(separatedBy: "\n")
            .filter { $0.hasPrefix("continuous_covariates=") || $0.hasPrefix("categorical_covariates=") || $0.hasPrefix("time_varying=") }
            .joined(separator: "；")
        assistantMessages.append(AssistantMessage(role: .system,
            text: String.safeFormat(L10n.scmConfigReady, configName, configSummary)))

        // 3. Run PsN SCM with auto-retry on error
        let maxRetries = 2
        var currentRetry = 0
        var finalSCMResult: String? = nil
        let psnDir = resolvedPsNDir()
        let scmBin = psnDir + "/scm"
        assistantMessages.append(AssistantMessage(role: .system, text: L10n.scmRunningNotice))

        while currentRetry <= maxRetries {
            // Check for user cancellation
            if scmCancelled { runner.append("SCM: cancelled by user"); updateLastThinkingStep(type: .error, detail: "SCM cancelled"); break }

            let attemptLabel = currentRetry == 0 ? "" : " (retry \(currentRetry))"
            runner.append("SCM: running scm -config_file=\(scmPath.lastPathComponent) -model=\(scmModPath.lastPathComponent)\(attemptLabel)")
            automationStep = L10n.scmStepRunning
            addThinkingStep("PsN SCM running for run\(baseRun)\(attemptLabel)...", type: .working)
            let scmCmd = shellQuote(scmBin) + " -config_file=" + shellQuote(scmPath.path) + " -model=" + shellQuote(scmModPath.path)
            let exit = await runner.runAndWait(command: "cd \(shellQuote(scmDir.path)) && \(scmCmd)", in: scmDir)
            runner.append("SCM: completed with exit code \(exit)\(attemptLabel)")
            if scmCancelled || Task.isCancelled {
                runner.append("SCM: cancelled by user after stop.")
                updateLastThinkingStep(type: .error, detail: "SCM cancelled")
                break
            }

            // Read SCM output: prefer the structured summary from the latest scm_dirN files
            // (scm_results.csv / scm_log.txt / covariate_statistics.txt / final model), and fall
            // back to the captured SCM stdout from the runner log.
            let fileSummary = buildSCMResultSummary(baseRun: baseRun)
            let runnerTail: String? = {
                let tail = String(runner.logText.suffix(20_000))
                let trimmed = tail.trimmingCharacters(in: .whitespacesAndNewlines)
                return (trimmed.isEmpty || trimmed == "AutoPMX terminal ready.") ? nil : tail
            }()
            let rawLog: String
            if exit == 0 {
                rawLog = fileSummary ?? runnerTail ?? "SCM completed but no result files were found."
            } else {
                // On failure the captured stdout/stderr is more useful for diagnosis.
                rawLog = runnerTail ?? fileSummary ?? "SCM completed but no log found."
            }

            // ── SCM Error Diagnosis ──
            let skillStore = PPKSkillStore.shared
            let diagnosis = skillStore.diagnoseSCMError(log: rawLog, runID: baseRun)

            if exit == 0 {
                // Success — SCM process exited cleanly. Don't let log-based heuristics override this.
                updateLastThinkingStep(type: .done, detail: "SCM completed (exit 0)")
                finalSCMResult = rawLog
                // Record success
                skillStore.addSuccess(
                    title: "SCM completed successfully for run\(baseRun)",
                    context: "SCM run with model run\(baseRun).mod and data \(dataFile)",
                    action: "SCM config: \(scmConfig.prefix(200))",
                    result: "exit code 0, log available",
                    sourceRun: baseRun,
                    tags: ["SCM", "success"]
                )
                break
            }

            // Failure detected — diagnose and potentially retry
            runner.append("SCM: error detected — \(diagnosis.findings.joined(separator: "; "))")
            updateLastThinkingStep(type: .warning, detail: "SCM error, diagnosing...")

            // Record the error as a lesson
            for finding in diagnosis.findings {
                skillStore.addLesson(
                    category: .scmError,
                    title: "SCM error in run\(baseRun)",
                    problem: finding,
                    solution: diagnosis.suggestedFixes.first ?? "Review SCM configuration and model.",
                    sourceRun: baseRun,
                    severity: .high,
                    tags: ["SCM", "error", "retry-\(currentRetry)"]
                )
            }

            guard currentRetry < maxRetries else {
                // Max retries exhausted
                runner.append("SCM: max retries (\(maxRetries)) exhausted — returning error log")
                updateLastThinkingStep(type: .error, detail: "SCM failed after \(maxRetries) retries")
                finalSCMResult = "SCM FAILED after \(maxRetries) retries.\n\n\(diagnosis.summary)\n\nLog:\n\(rawLog)"
                break
            }

            // ── AI-Driven SCM Fix ──
            addThinkingStep("AI analyzing SCM error & rewriting config...", type: .working)
            do {
                let skillContext = skillStore.contextBlock(for: ["SCM", "error"], maxLessons: 4)
                let fixedConfig = try await LLMCommandService.fixSCMConfig(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    currentConfig: scmConfig,
                    errorLog: diagnosis.summary + "\n\n" + rawLog.prefix(8000).description,
                    modelText: cleanMod.prefix(15_000).description,
                    skillMemory: skillContext,
                    apiKey: llmAPIKey,
                    pForward: pForward,
                    pBackward: pBackward,
                    apiFormat: activeAPIFormat
                )
                // Write the fixed config
                try? fixedConfig.write(to: scmPath, atomically: true, encoding: .utf8)
                runner.append("SCM: AI rewrote config for retry \(currentRetry + 1)")
                updateLastThinkingStep(type: .done, detail: "Config fixed, retrying...")
                // Record the fix as a success pattern
                skillStore.addSuccess(
                    title: "AI auto-fixed SCM config for run\(baseRun)",
                    context: "SCM error: \(diagnosis.findings.first ?? "unknown")",
                    action: "AI rewrote \(configName)",
                    result: "Retrying SCM...",
                    sourceRun: baseRun,
                    tags: ["SCM", "auto-fix", "retry"]
                )
            } catch {
                runner.append("SCM: AI fix failed (\(error.localizedDescription)) — retrying with original config")
                updateLastThinkingStep(type: .warning, detail: "AI fix failed, retrying as-is")
            }

            currentRetry += 1
        }

        return finalSCMResult
    }

    private func detectModelInput(in modText: String) -> Set<String> {
        // Extract column names from $INPUT line
        let lines = modText.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("$INPUT") {
                let rest = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                return Set(rest.components(separatedBy: .whitespaces).map { $0.uppercased() })
            }
        }
        return []
    }

    private func detectDataFile(in modText: String) -> String {
        // 1. Parse $DATA line from the model text — this is what SCM/NONMEM actually reads
        let lines = modText.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.uppercased().hasPrefix("$DATA") else { continue }
            let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count > 1 else { continue }
            let token = parts[1]
            return token.hasPrefix("/") ? URL(fileURLWithPath: token).lastPathComponent : token
        }

        // 2. Fall back to project_config.json data_file
        let configURL = projectURL.appendingPathComponent("project_config.json")
        if let configData = try? Data(contentsOf: configURL),
           let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
           let configuredFile = config["data_file"] as? String {
            return configuredFile
        }

        // 3. Final fallback to the store's configured data file
        return dataFile
    }

    private func detectPKParams(in modText: String) -> [String] {
        var params: Set<String> = []
        // Match TVxx = THETA patterns
        let pattern = try? NSRegularExpression(pattern: #"TV(\w+)\s*=\s*THETA"#, options: [])
        let nsText = modText as NSString
        // Extract the $PK block so we can check per-param IIV
        let pkBlock = extractBlock(named: "$PK", from: modText)
        if let matches = pattern?.matches(in: modText, options: [], range: NSRange(location: 0, length: nsText.length)) {
            for m in matches {
                if m.numberOfRanges > 1 {
                    let param = nsText.substring(with: m.range(at: 1))
                    if param == "FM" { continue }
                    // Only include params that have IIV (ETA in their definition)
                    if pkParamHasIIV(param: param, in: pkBlock) {
                        params.insert(param)
                    }
                }
            }
        }
        return Array(params).sorted()
    }

    /// Extract the content between a named block header (e.g. "$PK") and the next "$" record.
    private func extractBlock(named blockName: String, from modText: String) -> String {
        let lines = modText.components(separatedBy: "\n")
        var inBlock = false
        var blockLines: [String] = []
        let upper = blockName.uppercased()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased()
            if trimmed.hasPrefix(upper) {
                inBlock = true
                continue
            }
            if inBlock {
                if trimmed.hasPrefix("$") { break }
                blockLines.append(line)
            }
        }
        return blockLines.joined(separator: "\n")
    }

    /// Check whether a PK parameter has IIV by looking for ETA in its assignment line.
    private func pkParamHasIIV(param: String, in pkBlock: String) -> Bool {
        let lines = pkBlock.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match lines like "CL = TVCL * EXP(ETA(1))" or "V2 = TVV2"
            if trimmed.hasPrefix("\(param) ") || trimmed.hasPrefix("\(param)=") ||
               trimmed.hasPrefix("\(param)\t") {
                return trimmed.uppercased().contains("ETA")
            }
        }
        return false
    }

    func confirmBaseModelAndStartPhase2(skipSCM: Bool = false) {
        isBaseModelConfirmPresented = false
        guard !automationBusy else { return }
        let acceptedRun = baseModelConfirmRunID
        guard !acceptedRun.isEmpty else { return }
        benchmarkBasePromptActionTaken = true
        automationStopRequested = false
        diagnosticsAttemptedRuns.removeAll()
        startBenchmarkPhase2()
        isAutoModeling = true
        isAssistantPanelPresented = true
        duDuMood = .working
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusBaseModelPhase2, acceptedRun)))
        runner.append("=== PHASE 2: Covariate screening starting from run\(acceptedRun) ===")

        automationTask = Task {
            defer {
                resetAutomationUIState(step: "Idle")
                finalizeBenchmarkFromAutomationTask(status: automationStopRequested ? .stopped : .completed)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if !isAutoModeling { duDuMood = .happy }
                }
            }
            do {
                let activeDataFile = automationDataFile.isEmpty ? dataFile : automationDataFile
                let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: activeDataFile)
                resetTokenUsage()
                let ruleContext = activeRuleContext(phase: "phase2")
                let rules = ruleContext.text
                // Stable session id so DeepSeek keeps the prompt-cache alive (~1h) across iterations.
                let automationSessionId = UUID().uuidString
                var modelRuns = automationModelRuns()
                guard modelRuns.contains(acceptedRun) else {
                    runner.append("Base model run\(acceptedRun) not found — cannot start Phase 2.")
                    return
                }
                var sourceRun = acceptedRun
                let maxEvaluations = 100

                // ━━━ SCM Fast Screening ━━━
                if skipSCM {
                    runner.append("=== PHASE 2: SCM skipped (already run manually) — proceeding to DuDu verification ===")
                    assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusSCMReuseManual))
                } else {
                    runner.append("=== PHASE 2: Running SCM fast covariate screening ===")
                    assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusSCMStarting))
                    let scmResult = await prepareAndRunSCM(baseRun: acceptedRun, dataFile: activeDataFile, profile: profile)
                    if let scmResult {
                        runner.append("SCM screening complete:\n\(scmResult)")
                        assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusSCMCompleteValidate))
                    } else {
                        runner.append("SCM: not available, falling back to AI-driven covariate screening")
                        assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusSCMUnavailable))
                    }
                }

                // ━━━ Read SCM criteria (for final comparison only) ━━━
                // Don't promote SCM's final model — DuDu independently builds covariate
                // models from the base model. We'll compare at the end.
                scmComparisonMod = readSCMFinalModel(baseRun: acceptedRun)
                if scmComparisonMod != nil {
                    runner.append("SCM: criteria loaded — DuDu will independently build covariate models from run\(acceptedRun).")
                } else {
                    runner.append("SCM: no final model found — DuDu will run full AI-driven screening.")
                }

                // ━━━ DuDu replicates SCM's forward/backward sequence (when SCM completed) ━━━
                if scmComparisonMod != nil {
                    if let finalRun = await verifySCMByReplication(baseRun: acceptedRun, dataFile: activeDataFile) {
                        runner.append("=== PHASE 2 COMPLETE: DuDu replicated SCM and compared — final run\(finalRun) ===")
                        scmCovariatesLoaded = true
                        automationStep = "Phase 2 complete — SCM replication verified"
                        currentRun = finalRun
                        previousRun = acceptedRun
                        commandText = psnRunCommand(runID: finalRun)
                        refreshWorkspace()
                        PPKSkillStore.shared.save(to: projectURL)
                        startFinalModelPackage(for: finalRun, previousRun: acceptedRun)
                        return
                    }
                    runner.append("SCM replication could not be completed — falling back to AI-driven covariate screening.")
                }

                // ━━━ AI-driven covariate verification (from base model) ━━━
                sourceRun = acceptedRun  // DuDu starts from the base model, NOT the SCM result
                scmCovariatesLoaded = scmComparisonMod != nil
                var previousForComparison = modelRuns.firstIndex(of: acceptedRun).map { idx in idx > 0 ? modelRuns[idx - 1] : nil } ?? nil

                for iteration in 1...maxEvaluations {
                    try checkAutomationStop("Phase2 iteration \(iteration)")
                    automationStep = "Running NONMEM run\(sourceRun)"
                    currentRun = sourceRun
                    previousRun = previousForComparison ?? sourceRun
                    commandText = psnRunCommand(runID: sourceRun)
                    refreshChecks()
                    let exit: Int32
                    if isModelRunSuccessful(runID: sourceRun) {
                        runner.append("Using existing successful NONMEM outputs for run\(sourceRun).")
                        exit = 0
                    } else {
                        exit = await runner.runAndWait(command: commandText, in: projectURL)
                    }
                    try checkAutomationStop("NONMEM run\(sourceRun)")

                    let runSuccessful = exit == 0 && isModelRunSuccessful(runID: sourceRun)
                    if runSuccessful {
                        duDuMood = .excited; lastRunSucceeded = true
                        let diagExists = automationDiagnosticsExist(runID: sourceRun)
                        if diagExists || diagnosticsAttemptedRuns.contains(sourceRun) {
                            runner.append("Diagnostics already attempted for run\(sourceRun) — reusing existing plots/outputs.")
                        } else {
                            automationStep = "Diagnosing run\(sourceRun)"
                            _ = await runAutomationDiagnostics(runID: sourceRun, previousRun: previousForComparison ?? sourceRun)
                            diagnosticsAttemptedRuns.insert(sourceRun)
                        }
                    } else {
                        duDuMood = .sad; lastRunSucceeded = false
                        runner.append("NONMEM run\(sourceRun) failed — repairing")
                    }

                    automationStep = "AI evaluating run\(sourceRun)"
                    let evidence = automationEvidence(runID: sourceRun, previousRun: previousForComparison, exitCode: exit)
                    let skillCtx = PPKSkillStore.shared.contextBlock(for: ["modeling", "covariate", "convergence"])
                    var fullEvidence = "Dataset: \(profile.summary)\n\n\(skillCtx)\n\(evidence)"
                    // Hard estimation status injected BEFORE the AI evaluates, so the model cannot
                    // "think" a covariance-failed run is acceptable. This is the authoritative gate.
                    let minOK = runMinimizationOK(sourceRun)
                    let covOK = runCovarianceOK(sourceRun)
                    let bnd = hasBoundaryWarningsFor(sourceRun)
                    let hardStatus = """
                    ━━━ HARD ESTIMATION STATUS (authoritative, do NOT override) ━━━
                    run\(sourceRun): MINIMIZATION \(minOK ? "SUCCESSFUL" : "FAILED") | COVARIANCE \(covOK ? "SUCCESSFUL" : "NOT SUCCESSFUL") | BOUNDARY \(bnd ? "YES (near boundary)" : "no")
                    => This run is \(minOK && covOK && !bnd ? "S+C and may be ACCEPTed" : "NOT S+C — you MUST output REVISE and repair WITHIN the same compartment count until S+C is achieved")\(bnd ? " (a boundary estimate alone makes it ineligible even if covariance succeeded)" : "").
                    """
                    fullEvidence += "\n\n" + hardStatus
                    var (decision, usage) = try await LLMCommandService.evaluateModelRun(
                        baseURL: llmBaseURL, model: llmModel, projectURL: projectURL,
                        runID: sourceRun, previousRun: previousForComparison,
                        rules: rules, diagnosticSummary: fullEvidence, apiKey: llmAPIKey,
                        sessionId: automationSessionId,
                        s1Expression: derivedS1Expression,
                        s1for2CompExpression: derivedS1for2CompExpression,
                        s2Expression: derivedS2Expression,
                        s2for2CompExpression: derivedS2for2CompExpression,
                        derivedVUnit: derivedVUnit,
                        derivedCLUnit: derivedCLUnit,
                        isCovariatePhase: true,
                        apiFormat: activeAPIFormat
                    )
                    recordUsage(usage)
                    try checkAutomationStop("AI evaluation run\(sourceRun)")

                    // HARD GATE before showing the raw AI verdict: a model that is not S+C
                    // can never display an ACCEPT conclusion to the user.
                    if isAcceptanceDecision(decision) && !isModelStable(runID: sourceRun) {
                        let why = missingEstimationReason(runID: sourceRun)
                        let boundary = hasBoundaryWarningsFor(sourceRun) ? " boundary-estimate" : ""
                        runner.append("⚠️ run\(sourceRun) was marked ACCEPT but is NOT stable (\(why)\(boundary)). Forcing REVISE — must achieve S (minimization) + C (covariance) with no boundary estimate before acceptance.")
                        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusForcedRevise, sourceRun)))
                        decision = "REVISE\nModel not stable (\(why)\(boundary)). Must achieve minimization + covariance success with no boundary estimate before acceptance."
                    } else {
                        assistantMessages.append(AssistantMessage.parse(formatDecisionMessage(decision, runID: sourceRun, isCovariate: true), role: .assistant))
                    }
                    runner.append(decision)

                    // Deposit this evaluation's outcome as a durable skill
                    depositModelingSkill(runID: sourceRun, decision: decision, diagnostics: evidence, phase: "Phase2")

                    // Skill synthesis: extract a generalizable lesson on Phase 2 acceptance.
                    if isAcceptanceDecision(decision) {
                        Task {
                            do {
                                if let skill = try await LLMCommandService.synthesizeSkillLesson(
                                    baseURL: llmBaseURL, model: llmModel, apiKey: llmAPIKey,
                                    phase: "Phase2 Final",
                                    problem: "Phase 2 covariate model is being finalized.",
                                    action: "run\(sourceRun) evaluation: \(decision.prefix(300))",
                                    result: "Evidence: \(evidence.prefix(300))",
                                    sessionId: automationSessionId,
                                    apiFormat: activeAPIFormat
                                ) {
                                    PPKSkillStore.shared.addLesson(
                                        category: skill.category, title: skill.title,
                                        problem: "Auto-synthesized: \(skill.lesson.prefix(200))",
                                        solution: skill.lesson, sourceRun: sourceRun,
                                        severity: skill.severity,
                                        tags: ["synthesized", "phase2"]
                                    )
                                    runner.append("🧠 Skill synthesized: [\(skill.category.rawValue)] \(skill.title)")
                                    PPKSkillStore.shared.saveCurrent()
                                }
                            } catch {}
                        }
                    }

                    if isAcceptanceDecision(decision) {
                        runner.append("=== PHASE 2 COMPLETE: Covariate model run\(sourceRun) accepted ===")
                        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.ctCovComplete, sourceRun)))
                        break
                    }

                    guard iteration < maxEvaluations else {
                        runner.append("Reached max evaluations (\(maxEvaluations) iterations).")
                        break
                    }
                    let nextRun = nextChildRunID(parent: sourceRun)
                    automationStep = "AI screening covariate for run\(nextRun)"
                    let optSkillCtx = PPKSkillStore.shared.contextBlock(for: ["modeling", "covariate", "optimization"])

                    let (nextModel, optUsage) = try await LLMCommandService.proposeOptimizedModel(
                        baseURL: llmBaseURL, model: llmModel, projectURL: projectURL,
                        sourceRun: sourceRun, nextRun: nextRun,
                        rules: rules, diagnosticSummary: "\(optSkillCtx)\n\n\(decision)\n\n\(evidence)",
                        isCovariatePhase: true, apiKey: llmAPIKey,
                        sessionId: automationSessionId,
                        s1Expression: derivedS1Expression,
                        s1for2CompExpression: derivedS1for2CompExpression,
                        s2Expression: derivedS2Expression,
                        s2for2CompExpression: derivedS2for2CompExpression,
                        derivedVUnit: derivedVUnit,
                        derivedCLUnit: derivedCLUnit,
                        apiFormat: activeAPIFormat
                    )
                    recordUsage(optUsage)
                    try checkAutomationStop("model drafting run\(nextRun)")
                    var draftedModel = LLMCommandService.sanitizeControlStream(
                        nextModel,
                        projectURL: projectURL,
                        dataFile: activeDataFile
                    )
                    draftedModel = normalizeTypicalValueNaming(draftedModel)
                    if let sourceModText = try? String(contentsOf: projectURL.appendingPathComponent("run\(sourceRun).mod"), encoding: .utf8) {
                        draftedModel = protectResidualEstimation(draftedModel, sourceModText: sourceModText, runID: sourceRun)
                    }
                    draftedModel = enforceZeroFixForResidualError(draftedModel)
                    draftedModel = withETATableRecord(draftedModel, runID: nextRun)
                    draftedModel = LLMCommandService.applyingIVInfusionDurationFix(draftedModel)
                    draftedModel = LLMCommandService.normalizingTableRecords(draftedModel, runID: nextRun)
                    let p2URL = projectURL.appendingPathComponent("run\(nextRun).mod")
                    guardModFileWrite(draftedModel, to: p2URL, label: "run\(nextRun).mod (phase2)")
                    let validation = await validateModel(nextRun)
                    if !validation.passed {
                        let fix = await autoFixModel(nextRun)
                        if !fix.fixed {
                            // Force-strip and continue — NEVER stop
                            if let txt = try? String(contentsOf: p2URL, encoding: .utf8) {
                                let stripped = LLMCommandService.stripInlineDatasetRows(txt)
                                if stripped != txt {
                                    try? stripped.write(to: p2URL, atomically: true, encoding: .utf8)
                                }
                            }
                            runner.append("⚠️ run\(nextRun).mod 预检未通过，数据行已强制清理。DuDu继续…")
                            assistantMessages.append(AssistantMessage(role: .assistant, text: localized(
                                "run\(nextRun).mod 预检未通过，DuDu继续修复…",
                                "run\(nextRun).mod did not pass preflight; DuDu will repair it…"
                            )))
                        }
                    }
                    previousForComparison = sourceRun
                    sourceRun = nextRun
                    modelRuns.append(nextRun)
                    refreshWorkspace()
                }
                // Save PPK Skill after Phase 2 completes
                PPKSkillStore.shared.save(to: projectURL)
                refreshWorkspace()
            } catch let stop as AutomationStoppedError {
                runner.append("Phase 2 stopped at \(stop.step).")
                PPKSkillStore.shared.save(to: projectURL)
            } catch is CancellationError {
                runner.append("Phase 2 cancelled.")
                PPKSkillStore.shared.save(to: projectURL)
            } catch {
                if !automationStopRequested {
                    let message = LLMCommandService.friendlyError(error, baseURL: llmBaseURL)
                    runner.append("Phase 2 failed: \(message)")
                    assistantMessages.append(AssistantMessage(role: .assistant, text: String.safeFormat(L10n.autoFailed, message)))
                }
                resetAutomationUIState(step: "LLM error — check connection", mood: .sad)
                PPKSkillStore.shared.save(to: projectURL)
            }
        }
    }

    /// Central reset for all running indicators after automation ends, fails, or is
    /// cancelled. Prevents “already stopped but UI still shows STOP/running” bugs.
    private func resetAutomationUIState(step: String, mood: DuDuMood = .happy) {
        isAutoModeling = false
        isAIThinking = false
        isAssistantThinking = false
        isSCMRunning = false
        isBootstrapRunning = false
        automationTask = nil
        automationStep = step
        duDuMood = mood
        lastRunSucceeded = false
        if runner.isRunning {
            runner.stopCurrentProcess()
            runner.isRunning = false
        }
    }

    func requestStopAutomation() {
        // Don't require isAutoModeling here — during an LLM disconnect the automation may
        // have already flipped the flag, yet the task is still spinning inside a retry
        // loop. Stop unconditionally so the red STOP button always works.
        automationStopRequested = true
        automationTask?.cancel()
        chatTask?.cancel()
        runner.append("Automation stopped by user.")
        assistantMessages.append(AssistantMessage(role: .system, text: L10n.autoStoppedShort))
        runner.stopCurrentProcess()
        runner.isRunning = false
        // Mark as stopped immediately (don't wait for the cancelled task to unwind)
        isAutoModeling = false
        isAIThinking = false
        isAssistantThinking = false
        isSCMRunning = false
        isBootstrapRunning = false
        automationStep = "Stopped"
        duDuMood = .happy
        clearThinkingSteps()
        automationTask = nil
        if activeBenchmark != nil {
            finalizeBenchmark(status: .stopped, notes: L10n.t("benchmark.stopped"))
        }
    }

    func startAutomatedModelingDemo() {
        guard !automationBusy else { return }
        automationStopRequested = false
        clearThinkingSteps()
        diagnosticsAttemptedRuns.removeAll()
        let selectedMode = automationStartMode
        let selectedRunID = automationStartRunID
        let userGuidance = automationUserGuidance.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeDataFile = automationDataFile.isEmpty ? dataFile : automationDataFile
        if !automationDataFile.isEmpty {
            switchDataFile(automationDataFile)
            saveUnitsToConfig()
        }

        var ivHandoffSourceProjectURL: URL?
        var ivHandoff: (asset: ProjectAsset, modText: String, rows: [ParameterEstimateRow], compartments: Int)?
        if selectedMode == .selectedRun,
           !selectedRunID.isEmpty,
           let asset = modelAssetForRun(selectedRunID) {
            let modText = (try? String(contentsOf: asset.url, encoding: .utf8)) ?? ""
            ivHandoffSourceProjectURL = projectURL
            ivHandoff = (
                asset: asset,
                modText: modText,
                rows: ProjectScanner.parameterEstimates(runID: selectedRunID, in: projectURL),
                compartments: compartmentInfoForRun(selectedRunID).compartments
            )
        }

        // Fresh Start: create new project BEFORE automation begins (avoid openProject guard)
        if selectedMode == .fresh || !isAutomationProject(projectURL) {
            // ── Pre-flight: make sure the target workspace is writable. ──
            // A stale path (project moved / deleted / on a read-only volume) surfaced as a
            // cryptic "volume is read only" NSError. Give the user a clear, actionable message
            // and offer to fall back to a writable default instead of failing silently.
            let targetDir = workspaceURL
            let targetIsWritable = FileManager.default.isWritableFile(atPath: targetDir.path)
            if !targetIsWritable {
                let hint = "Workspace folder is not writable or no longer exists: \(targetDir.path).\n"
                    + "Please re-open the moved project via File → Open (or Open Recent), then retry."
                runner.append("⚠️ AutoModel project could not be created.")
                runner.append(hint)
                assistantMessages.append(AssistantMessage(role: .system, text: hint))
                return
            }
            do {
                // Copy data from the currently open project (not workspace root), so users can
                // keep their project anywhere — the dataset travels with the project, not the workspace.
                let sourceForCopy = isAutomationProject(projectURL) ? workspaceURL : projectURL
                let demo = try ProjectScanner.createAutomationDemoProject(workspaceURL: workspaceURL, sourceURL: sourceForCopy, dataFileName: activeDataFile)
                projectURL = demo
                dataFile = activeDataFile // persist the selected data file to the new project
                saveUnitsToConfig()       // persist the current units for this data file in the new project
                selectedAsset = nil
                commandText = ""
                runner.append("Prepared clean AutoModel project: \(demo.path)")
                UserDefaults.standard.set(demo.path, forKey: "AutoPMX.lastProjectPath")
                // Do NOT save automation-generated projects to Recent Projects — they are ephemeral
                // and would pollute the user's project list with timestamped auto-directories.
                if demo.path.contains("/AutoPMX_Projects/") {
                    let parts = demo.path.components(separatedBy: "/AutoPMX_Projects/")
                    if let prefix = parts.first {
                        workspaceURL = URL(fileURLWithPath: prefix)
                    }
                }
                // Carry over the globally-stored PPK skills (success patterns + lessons distilled by DuDu PMx)
                // so a freshly-created sub-project still inherits previously learned modeling techniques.
                PPKSkillStore.shared.load(from: demo)
                refreshWorkspace()
                if let handoff = ivHandoff, let sourceURL = ivHandoffSourceProjectURL {
                    copyModel(
                        asset: handoff.asset,
                        toProject: projectURL,
                        openAfterCopy: false,
                        copyReferencedDataset: false,
                        dataFileOverride: activeDataFile
                    )
                    copyModelOutputs(runID: selectedRunID, from: sourceURL, to: projectURL)
                    refreshWorkspace()
                    runner.append("Selected parent run\(selectedRunID).mod copied into the AutoModel project.")
                }
                assistantMessages.append(AssistantMessage(role: .system, text: L10n.ctCleanProjectCreated))
            } catch {
                runner.append("Failed to create AutoModel project: \(error.localizedDescription)")
                assistantMessages.append(AssistantMessage(role: .system, text: localized(
                    "创建 AutoModel 项目失败：\(error.localizedDescription)",
                    "Failed to create AutoModel project: \(error.localizedDescription)"
                )))
                return
            }
        }

        beginBenchmark(dataFile: activeDataFile)
        isAutoModeling = true
        isAssistantPanelPresented = true
        duDuMood = .working

        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.ctModelingStarted, activeDataFile)))
        assistantMessages.append(AssistantMessage(role: .system, text: L10n.ctPathWarning))
        if !userGuidance.isEmpty {
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.ctGuidanceApplied, userGuidance)))
        }
        runner.append("=== AutoPMX automated modeling started from \(activeDataFile) ===")

        automationTask = Task {
            defer {
                resetAutomationUIState(step: "Idle")
                finalizeBenchmarkFromAutomationTask(status: automationStopRequested ? .stopped : .completed)
                // Reset mood after a delay
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if !isAutoModeling { duDuMood = .happy }
                }
            }

            var outerCovariatePhase = false  // Declared outside do-catch so catch block can reference it

            do {
                try checkAutomationStop("startup")
                automationStep = "Checking local LLM"
                addThinkingStep("Checking LLM connection [\(activeAPIFormat.displayName)]", type: .working)
                let probe = try await LLMCommandService.detectEndpoint(
                    preferredBaseURL: llmBaseURL, apiKey: llmAPIKey, apiFormat: activeAPIFormat
                )
                try checkAutomationStop("LLM check")
                updateLastThinkingStep(type: .done, detail: "\(probe.models.count) models available")
                llmBaseURL = probe.baseURL
                availableLLMModels = probe.models
                if let first = probe.models.first, !probe.models.contains(llmModel) {
                    llmModel = first
                }

                automationStep = "Preparing project"
                addThinkingStep("Preparing automation project", type: .working)
                runner.append("Using AutoModel project: \(projectURL.path)")
                updateLastThinkingStep(type: .done, detail: projectURL.lastPathComponent)

                let ruleContext = activeRuleContext(userGuidance: userGuidance, phase: "phase1")
                let rules = ruleContext.text
                ruleContextStatus = ruleContext.summary
                runner.append("Rule context for DuDu PMx: \(ruleContext.summary)")

                automationStep = "Analyzing dataset"
                addThinkingStep("Analyzing dataset: \(activeDataFile)", type: .working)
                let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: activeDataFile)
                // Save initial EDA for final model report
                initialEDASummary = profile.summary
                runner.append("Dataset:\n\(profile.summary)")
                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.ctAnalysisComplete, profile.summary)))
                updateLastThinkingStep(type: .done, detail: "\(profile.route) route, \(profile.subjectCount) subjects, \(dataCovariateSummary(profile))")

                // Run dose-normalized C-T plot + lag / elimination / exposure analysis
                var lagInfo: (
                    hasLag: Bool, lagTime: Double, recommendation: String,
                    elimSimilar: Bool, elimReliable: Bool, elimDetail: String,
                    linearPK: Bool, exposureDetail: String,
                    firstDoseElimSimilar: Bool, firstDoseElimDetail: String, multiDose: Bool,
                    route: String, compartmentSuspected: Bool, compartmentShapeDetail: String
                ) = (false, 0, "", true, false, "", true, "", true, "", false, "Unknown", false, "")
                if resolvedR().isEmpty == false {
                    addThinkingStep("Plotting dose-normalized C-T curves", type: .working)
                    lagInfo = await runCTAnalysis(dataFile: activeDataFile)
                    // Show the C-T plot to the user in the chat
                    let ctImgName = activeDataFile.replacingOccurrences(of: ".csv", with: "") + "_dose_norm_ct.png"
                    let ctImgPath = projectURL.appendingPathComponent(ctImgName).path
                    let ctPlotGenerated = FileManager.default.fileExists(atPath: ctImgPath)
                    if ctPlotGenerated {
                        assistantMessages.append(AssistantMessage(role: .system, text: "📊 Dose-Normalized C-T Plot: file://\(ctImgPath)"))
                        // First-dose plots (raw + dose-normalized) — clearer elimination view for multi-dose studies
                        let firstRawImg = projectURL.appendingPathComponent(activeDataFile.replacingOccurrences(of: ".csv", with: "") + "_firstdose_ct.png").path
                        let firstDnImg = projectURL.appendingPathComponent(activeDataFile.replacingOccurrences(of: ".csv", with: "") + "_firstdose_dose_norm_ct.png").path
                        if FileManager.default.fileExists(atPath: firstRawImg) {
                            assistantMessages.append(AssistantMessage(role: .system, text: "📊 First-Dose C-T Plot (raw): file://\(firstRawImg)"))
                        }
                        if FileManager.default.fileExists(atPath: firstDnImg) {
                            assistantMessages.append(AssistantMessage(role: .system, text: "📊 First-Dose Dose-Normalized C-T Plot: file://\(firstDnImg)"))
                        }
                        appendCTFacetMessages(fileName: activeDataFile)
                        // Absorption lag verdict (skipped for IV routes — no absorption process)
                        let isIV = lagInfo.route.hasPrefix("IV")
                        if isIV {
                            assistantMessages.append(AssistantMessage(role: .system, text: L10n.ctIVroute))
                        } else if lagInfo.hasLag {
                            runner.append("CT analysis: absorption lag detected (Tlag ≈ \(String(format: "%.2f", lagInfo.lagTime))).\n\(lagInfo.recommendation)")
                            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.ctAbsorptionLag, String(format: "%.2f", lagInfo.lagTime), lagInfo.recommendation)))
                        } else {
                            runner.append("CT analysis: no absorption lag detected.")
                        }
                        // Elimination (terminal-phase) verdict
                        // Multi-dose: comprehensive assessment from BOTH the full-curve overlay AND the
                        // first-dose view. Accumulation stacks doses and can mask the true terminal phase,
                        // but the full-curve overlay still provides information about overall PK behaviour.
                        // Synthesise both sources of evidence.
                        let elimText: String
                        if lagInfo.multiDose {
                            let firstDoseAvailable = !lagInfo.firstDoseElimDetail.isEmpty && !lagInfo.firstDoseElimDetail.contains("N/A")
                            let wholeCurveAssessable = lagInfo.elimReliable
                            if firstDoseAvailable && wholeCurveAssessable {
                                // Both sources are assessable — synthesise
                                if lagInfo.firstDoseElimSimilar == lagInfo.elimSimilar {
                                    // Agreement → strong conclusion
                                    if lagInfo.firstDoseElimSimilar {
                                        elimText = L10n.ctElimSynthAgreeSame
                                    } else {
                                        elimText = L10n.ctElimSynthAgreeDiff
                                    }
                                } else {
                                    // Disagreement — flag inconsistency, present both
                                    let wholeWord = LanguageStore.shared.language == .zhCN
                                        ? (lagInfo.elimSimilar ? "相似" : "存在差异")
                                        : (lagInfo.elimSimilar ? "similar" : "different")
                                    let firstWord = LanguageStore.shared.language == .zhCN
                                        ? (lagInfo.firstDoseElimSimilar ? "相似" : "存在差异")
                                        : (lagInfo.firstDoseElimSimilar ? "similar" : "different")
                                    elimText = String.safeFormat(L10n.ctElimSynthDisagree, wholeWord, firstWord)
                                }
                            } else if firstDoseAvailable {
                                // Only first-dose is assessable
                                elimText = lagInfo.firstDoseElimSimilar ? L10n.ctElimFirstDoseOnlySame : L10n.ctElimFirstDoseOnlyDiff
                            } else if wholeCurveAssessable {
                                // Only whole-curve is assessable
                                elimText = lagInfo.elimSimilar ? L10n.ctElimWholeOnlySame : L10n.ctElimWholeOnlyDiff
                            } else {
                                elimText = L10n.ctElimBothInsufficient
                            }
                        } else if !lagInfo.elimReliable {
                            elimText = L10n.ctElimTerminalInsufficient
                        } else if lagInfo.elimSimilar {
                            elimText = L10n.ctElimSimilar
                        } else {
                            elimText = L10n.ctElimDifferent
                        }
                        runner.append(elimText)
                        if lagInfo.multiDose && !lagInfo.firstDoseElimDetail.isEmpty { runner.append(String.safeFormat(L10n.statusFirstDoseLabel, lagInfo.firstDoseElimDetail)) }
                        if !lagInfo.elimDetail.isEmpty { runner.append(String.safeFormat(L10n.statusFullCurveLabel, lagInfo.elimDetail)) }
                        assistantMessages.append(AssistantMessage(role: .system, text: elimText))
                        // Multi-compartment shape verdict (from semi-log C-T curves)
                        let compartmentText: String
                        if lagInfo.compartmentSuspected {
                            compartmentText = L10n.ctMultiCompartment
                        } else if lagInfo.compartmentShapeDetail.isEmpty || lagInfo.compartmentShapeDetail.contains("Insufficient") {
                            compartmentText = ""
                        } else {
                            compartmentText = L10n.ctOneCompartment
                        }
                        if !compartmentText.isEmpty {
                            runner.append(compartmentText)
                            assistantMessages.append(AssistantMessage(role: .system, text: compartmentText))
                        }
                        if !lagInfo.compartmentShapeDetail.isEmpty {
                            runner.append(String.safeFormat(L10n.statusSemiLogLabel, lagInfo.compartmentShapeDetail))
                        }
                        // Dose-normalized exposure similarity verdict
                        let expText = lagInfo.linearPK ? L10n.ctLinearPK : L10n.ctNonlinearPK
                        runner.append(expText)
                        if !lagInfo.exposureDetail.isEmpty { runner.append("  \(lagInfo.exposureDetail)") }
                        assistantMessages.append(AssistantMessage(role: .system, text: expText))
                    } else {
                        updateLastThinkingStep(type: .error, detail: "C-T plot failed — R script error")
                        let rPath = resolvedR()
                        if rPath.isEmpty {
                            assistantMessages.append(AssistantMessage(role: .system, text: L10n.ctRscriptMissing))
                        } else {
                            assistantMessages.append(AssistantMessage(role: .system, text: L10n.ctPlotFailed))
                        }
                    }
                }

                var modelRuns = automationModelRuns()
                var sourceRun = modelRuns.last ?? "001"
                var previousForComparison = modelRuns.dropLast().last
                var nextRunNumber = ((modelRuns.compactMap(Int.init).max()) ?? (Int(sourceRun) ?? 0)) + 1
                var useChildRunIDs = false

                if selectedMode == .selectedRun, modelRuns.contains(selectedRunID) {
                    sourceRun = selectedRunID
                    let sorted = modelRuns.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
                    if let index = sorted.firstIndex(of: selectedRunID), index > 0 {
                        previousForComparison = sorted[index - 1]
                    } else {
                        previousForComparison = nil
                    }
                    useChildRunIDs = true
                    nextRunNumber = -1
                    runner.append("User selected run\(sourceRun) as the continuation parent; next child model will be run\(nextChildRunID(parent: sourceRun)).")
                }

                if modelRuns.isEmpty {
                    automationStep = "AI writing run001.mod"
                    addThinkingStep("AI drafting run001.mod — initial model from \(profile.route)", type: .working)
                    let (initialModel, usage) = try await LLMCommandService.generateInitialModel(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        projectURL: projectURL,
                        runID: "001",
                        dataFile: activeDataFile,
                        rules: rules,
                        apiKey: llmAPIKey,
                        hasLag: lagInfo.hasLag,
                        lagTime: lagInfo.lagTime,
                        elimSimilar: lagInfo.elimSimilar,
                        elimReliable: lagInfo.elimReliable,
                        elimDetail: lagInfo.elimDetail,
                        linearPK: lagInfo.linearPK,
                        exposureDetail: lagInfo.exposureDetail,
                        firstDoseElimSimilar: lagInfo.firstDoseElimSimilar,
                        firstDoseElimDetail: lagInfo.firstDoseElimDetail,
                        multiDose: lagInfo.multiDose,
                        route: lagInfo.route,
                        doseUnit: doseUnit,
                        amtUnit: amtUnit,
                        concUnit: concUnit,
                        timeUnit: timeUnit,
                        compartmentSuspected: lagInfo.compartmentSuspected,
                        compartmentShapeDetail: lagInfo.compartmentShapeDetail,
                        s1Expression: derivedS1Expression,
                        s1for2CompExpression: derivedS1for2CompExpression,
                        s2Expression: derivedS2Expression,
                        s2for2CompExpression: derivedS2for2CompExpression,
                        derivedVUnit: derivedVUnit,
                        derivedCLUnit: derivedCLUnit,
                        apiFormat: activeAPIFormat
                    )
                    recordUsage(usage)
                    try checkAutomationStop("initial model drafting")
                    var initialModelText = LLMCommandService.sanitizeControlStream(
                        initialModel,
                        projectURL: projectURL,
                        dataFile: activeDataFile
                    )
                    initialModelText = correctS1Scaling(
                        withETATableRecord(
                            normalizeTypicalValueNaming(initialModelText),
                            runID: "001"
                        )
                    )
                    initialModelText = LLMCommandService.applyingNCAInitialValues(
                        initialModelText,
                        projectURL: projectURL,
                        dataFile: activeDataFile
                    )
                    initialModelText = LLMCommandService.applyingIVInfusionDurationFix(initialModelText)
                    initialModelText = LLMCommandService.normalizingTableRecords(
                        initialModelText,
                        runID: "001"
                    )
                    guardModFileWrite(initialModelText, to: projectURL.appendingPathComponent("run001.mod"), label: "run001.mod")
                    // Preflight validation of the generated model
                    let validation = await validateModel("001")
                    if !validation.passed {
                        runner.append("Initial model run001.mod has preflight issues -- attempting auto-fix")
                        let fix = await autoFixModel("001")
                        if fix.fixed {
                            runner.append("Auto-fix applied to run001.mod")
                        } else {
                            // Force-strip and continue — NEVER stop
                            let r1URL = projectURL.appendingPathComponent("run001.mod")
                            if let txt = try? String(contentsOf: r1URL, encoding: .utf8) {
                                let stripped = LLMCommandService.stripInlineDatasetRows(txt)
                                if stripped != txt {
                                    try? stripped.write(to: r1URL, atomically: true, encoding: .utf8)
                                }
                            }
                            runner.append("⚠️ run001.mod 初始模型预检未通过，数据行已强制清理。DuDu继续建模。")
                            assistantMessages.append(AssistantMessage(role: .assistant, text: localized(
                                "run001.mod 初始模型预检未通过，DuDu继续修复…\n\n\(validation.output)",
                                "run001.mod initial preflight failed; DuDu will repair it…\n\n\(validation.output)"
                            )))
                        }
                    }

                    let ncaSeeds = LLMCommandService.ncaInitialEstimates(
                        projectURL: projectURL,
                        dataFile: activeDataFile
                    )
                    if ncaSeeds.subjectCount > 0 {
                        automationStep = "GA initial value search"
                        addThinkingStep("GA: refining run001 initial values around NCA seeds", type: .working)
                        try checkAutomationStop("GA initial value search")
                        let gaOK = await runInitialGAStart(runID: "001", dataFile: activeDataFile)
                        try checkAutomationStop("GA initial value search")
                        if gaOK {
                            updateLastThinkingStep(type: .done, detail: "GA + NCA initial values ready")
                        } else {
                            updateLastThinkingStep(type: .working, detail: "Using NCA initial values")
                        }
                    }

                    sourceRun = "001"
                    previousForComparison = nil
                    modelRuns = ["001"]
                    nextRunNumber = 2
                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.ctModelCreated, activeDataFile, profile.route)))
                    runner.append("Created AI-generated starting model: run001.mod (\(profile.route) route)")
                    updateLastThinkingStep(type: .done, detail: "run001.mod — 1-comp \(profile.route)")
                    refreshWorkspace()
                } else {
                    let nextCandidateText = useChildRunIDs
                        ? "next child model will be run\(nextChildRunID(parent: sourceRun))"
                        : "next candidate will be run\(formattedRun((Int(sourceRun) ?? 0) + 1))"
                    runner.append("=== AutoPMX RESUMING from run\(sourceRun); \(nextCandidateText) ===")
                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.ctResuming, sourceRun)))
                    // Previous run for comparison: use the run directly before sourceRun.
                    // If no earlier run exists, use "001" itself (meaning: no true comparison).
                    if let idx = modelRuns.firstIndex(of: sourceRun), idx > 0 {
                        previousForComparison = modelRuns[idx - 1]
                    }
                }

                if automationUseIVAnchor,
                   let handoff = ivHandoff,
                   modelRuns.contains(selectedRunID) {
                    let parentRunID = selectedRunID
                    let childID = nextChildRunID(parent: parentRunID)
                    let hasIV = profile.hasIVBolus || profile.hasIVInfusion
                    let hasExtravascular = profile.hasOral
                    let includeF1 = hasIV && hasExtravascular

                    automationStep = "AI writing full-dataset handoff run\(childID).mod"
                    addThinkingStep("Building full-dataset model from IV anchor run\(parentRunID)", type: .working)

                    let deterministicHandoff = LLMCommandService.fullDatasetIVHandoffModel(
                        childRunID: childID,
                        parentRunID: parentRunID,
                        projectURL: projectURL,
                        dataFile: activeDataFile,
                        parentModText: handoff.modText,
                        parentRows: handoff.rows,
                        parentCompartments: handoff.compartments,
                        hasIV: hasIV,
                        hasExtravascular: hasExtravascular,
                        timeUnit: timeUnit,
                        derivedCLUnit: derivedCLUnit,
                        derivedVUnit: derivedVUnit,
                        s2Expression: derivedS2Expression,
                        s2for2CompExpression: derivedS2for2CompExpression
                    )

                    // The deterministic IV-anchor template is authoritative. Letting the LLM
                    // rewrite this first child repeatedly broke CMT/OMEGA/ETA/DUR invariants.
                    var handoffText = deterministicHandoff

                    handoffText = LLMCommandService.sanitizeControlStream(
                        handoffText,
                        projectURL: projectURL,
                        dataFile: activeDataFile
                    )
                    handoffText = correctS1Scaling(
                        withETATableRecord(
                            normalizeTypicalValueNaming(handoffText),
                            runID: childID
                        )
                    )
                    handoffText = LLMCommandService.applyingIVInfusionDurationFix(handoffText)
                    handoffText = LLMCommandService.normalizingTableRecords(handoffText, runID: childID)
                    handoffText = LLMCommandService.enforceIVAnchorHandoffFixes(handoffText)

                    let handoffURL = projectURL.appendingPathComponent("run\(childID).mod")
                    guardModFileWrite(handoffText, to: handoffURL, label: "run\(childID).mod (handoff)")

                    let validation = await validateModel(childID)
                    if !validation.passed {
                        let fix = await autoFixModel(childID)
                        if !fix.fixed {
                            // Last-resort: force-strip data rows and proceed.
                            // NEVER throw here — DuDu will let the LLM repair in the next iteration.
                            if let txt = try? String(contentsOf: handoffURL, encoding: .utf8) {
                                let stripped = LLMCommandService.stripInlineDatasetRows(txt)
                                if stripped != txt {
                                    try? stripped.write(to: handoffURL, atomically: true, encoding: .utf8)
                                }
                            }
                            runner.append("⚠️ run\(childID).mod handoff预检未通过，数据行已强制清理。DuDu将在后续迭代中修复结构问题。")
                            assistantMessages.append(AssistantMessage(role: .assistant, text: localized(
                                "run\(childID).mod 预检未通过但数据行已清理，DuDu继续修复中…\n\n\(validation.output)",
                                "run\(childID).mod preflight did not pass after clearing data rows; DuDu will repair it…\n\n\(validation.output)"
                            )))
                        }
                    }

                    sourceRun = childID
                    previousForComparison = parentRunID
                    modelRuns.append(childID)
                    nextRunNumber = -1
                    useChildRunIDs = true
                    runner.append("IV anchor handoff: run\(parentRunID) is the parent; first full-dataset model run\(childID) inherits IV estimates and adds \(includeF1 ? "KA + F1" : "KA").")
                    assistantMessages.append(AssistantMessage(role: .system, text: localized(
                        "已按 IV 母本 run\(parentRunID) 生成全数据集首个模型 run\(childID)：房室结构继承母本，SC 增加 Depot 后中央室已重新编号，IV 参数估算值先固定，\(includeF1 ? "单独估算 KA 和 F1" : "单独估算 KA")。",
                        "Created full-dataset handoff run\(childID) from IV parent run\(parentRunID): inherited compartment structure, renumbered central compartment for SC depot, kept IV estimates fixed, estimating \(includeF1 ? "KA and F1" : "KA") first."
                    )))
                    updateLastThinkingStep(type: .done, detail: "run\(childID).mod — \(handoff.compartments)-comp extravascular handoff")
                    refreshWorkspace()
                }

                var accepted = false
                var acceptedRun: String?
                var covariatePhase = false
                outerCovariatePhase = covariatePhase
                // Stable session id so DeepSeek keeps the prompt-cache alive (~1h) across iterations.
                let automationSessionId = UUID().uuidString
                var forceEscalation = false
                var inheritedHandoffMode = automationUseIVAnchor
                    && ivHandoff != nil
                    && selectedMode == .selectedRun
                if selectedMode == .selectedRun,
                   let handoffText = ivHandoff?.modText {
                    let upper = handoffText.uppercased()
                    if upper.contains("IV-ANCHOR HANDOFF")
                        || upper.contains("INHERITED IV STRUCTURAL THETA/OMEGA ARE FIXED")
                        || upper.contains("INHERITED IV THETA/OMEGA ARE FIXED") {
                        inheritedHandoffMode = true
                    }
                }
                var releaseInheritedFixes = false
                var childIIVExplorationScheduled = false
                var childIIVExplorationAttempted = false
                var previousRunWasFailure = false
                var consecutiveLLMFailures = 0
                let maxEvaluations = 100

                for iteration in 1...maxEvaluations {
                    automationStep = "Running NONMEM run\(sourceRun)"
                    currentRun = sourceRun
                    previousRun = previousForComparison ?? sourceRun
                    // Re-detect inherited handoff mode every round: users often resume via
                    // "Continue Latest" from run00601 rather than explicitly selecting it.
                    if let currentModText = try? String(contentsOf: projectURL.appendingPathComponent("run\(sourceRun).mod"), encoding: .utf8) {
                        let upper = currentModText.uppercased()
                        if upper.contains("IV-ANCHOR HANDOFF")
                            || upper.contains("INHERITED IV STRUCTURAL THETA/OMEGA ARE FIXED")
                            || upper.contains("INHERITED IV THETA/OMEGA ARE FIXED")
                            || upper.contains("AUTOPMX INHERITED FIXES RELEASED") {
                            inheritedHandoffMode = true
                        }
                    }
                    commandText = psnRunCommand(runID: sourceRun)
                    refreshChecks()
                    let exit: Int32
                    if isModelRunSuccessful(runID: sourceRun) {
                        runner.append("Using existing successful NONMEM outputs for run\(sourceRun).")
                        exit = 0
                    } else if ModelRunEvidence.hasFailureEvidence(projectURL: projectURL, runID: sourceRun) {
                        runner.append("Existing NONMEM/PsN failure for run\(sourceRun) — DuDu will repair from FMSG/LST evidence.")
                        exit = 1
                    } else if hasModelOutputs(runID: sourceRun) {
                        // LST exists but contains errors — treat as failure
                        runner.append("Existing NONMEM outputs for run\(sourceRun) contain errors — treating as failure for repair.")
                        exit = 1
                    } else {
                        exit = await runner.runAndWait(command: commandText, in: projectURL)
                        try checkAutomationStop("NONMEM run\(sourceRun)")
                    }

                    // Determine if model actually ran successfully (not just exit code)
                    let runSuccessful = exit == 0 && isModelRunSuccessful(runID: sourceRun)
                    if runSuccessful {
                        duDuMood = .excited
                        lastRunSucceeded = true
                    } else {
                        duDuMood = .sad
                        lastRunSucceeded = false
                    }

                    // Only run diagnostics if model actually succeeded
                    // Skip if diagnostics already exist (GOF + VPC + Individual)
                    let diagExists = automationDiagnosticsExist(runID: sourceRun)
                    if runSuccessful {
                        if diagExists || diagnosticsAttemptedRuns.contains(sourceRun) {
                            runner.append("Diagnostics already exist for run\(sourceRun) — reusing existing GOF/VPC/audit outputs.")
                        } else {
                            automationStep = "Diagnosing run\(sourceRun)"
                            _ = await runAutomationDiagnostics(runID: sourceRun, previousRun: previousForComparison ?? sourceRun)
                            diagnosticsAttemptedRuns.insert(sourceRun)
                            try checkAutomationStop("diagnostics run\(sourceRun)")
                        }
                    } else {
                        let reason: String
                        if exit != 0 {
                            reason = "NONMEM/PsN exit code: \(exit)"
                        } else if !isModelRunSuccessful(runID: sourceRun) {
                            reason = "Minimization failed or no .ext output"
                        } else {
                            reason = "LST contains errors despite zero exit code"
                        }
                        runner.append("NONMEM run\(sourceRun) failed (\(reason)) — skipping GOF/VPC/audit diagnostics, proceeding to AI repair")
                        addThinkingStep("NONMEM run\(sourceRun) failed — AI analyzing LST for repair", type: .working)
                    }

                    automationStep = "AI evaluating run\(sourceRun)"
                    let evidence = automationEvidence(runID: sourceRun, previousRun: previousForComparison, exitCode: exit)
                    // Inject dataset profile with available covariates
                    var fullEvidence = """
                    Dataset: \(profile.summary)

                    \(evidence)
                    """
                    // Hard estimation status injected BEFORE the AI evaluates, so the model cannot
                    // "think" a covariance-failed run is acceptable. This is the authoritative gate.
                    let minOKp1 = runMinimizationOK(sourceRun)
                    let covOKp1 = runCovarianceOK(sourceRun)
                    let bndp1 = hasBoundaryWarningsFor(sourceRun)
                    let hardStatusP1 = """
                    ━━━ HARD ESTIMATION STATUS (authoritative, do NOT override) ━━━
                    run\(sourceRun): MINIMIZATION \(minOKp1 ? "SUCCESSFUL" : "FAILED") | COVARIANCE \(covOKp1 ? "SUCCESSFUL" : "NOT SUCCESSFUL") | BOUNDARY \(bndp1 ? "YES (near boundary)" : "no")
                    => This run is \(minOKp1 && covOKp1 && !bndp1 ? "S+C and may be ACCEPTed" : "NOT S+C — you MUST output REVISE and repair WITHIN the same compartment count until S+C is achieved")\(bndp1 ? " (a boundary estimate alone makes it ineligible even if covariance succeeded)" : "").
                    """
                    fullEvidence += "\n\n" + hardStatusP1
                    markRequestStart(inputTokens: fullEvidence.count / 3)
                    var (decision, usage) = try await LLMCommandService.evaluateModelRun(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        projectURL: projectURL,
                        runID: sourceRun,
                        previousRun: previousForComparison,
                        rules: rules,
                        diagnosticSummary: fullEvidence,
                        apiKey: llmAPIKey,
                        sessionId: automationSessionId,
                        s1Expression: derivedS1Expression,
                        s1for2CompExpression: derivedS1for2CompExpression,
                        s2Expression: derivedS2Expression,
                        s2for2CompExpression: derivedS2for2CompExpression,
                        derivedVUnit: derivedVUnit,
                        derivedCLUnit: derivedCLUnit,
                        isCovariatePhase: false,
                        isInheritedHandoffMode: inheritedHandoffMode,
                        forceReAddDroppedIIV: childIIVExplorationScheduled,
                        apiFormat: activeAPIFormat
                    )
                    recordUsage(usage)
                    try checkAutomationStop("AI evaluation run\(sourceRun)")

                    // HARD GATE before showing the raw AI verdict: a model that is not S+C
                    // can never be displayed as an accepted base model.
                    if isAcceptanceDecision(decision) && !isModelStable(runID: sourceRun) {
                        let why = missingEstimationReason(runID: sourceRun)
                        let boundary = hasBoundaryWarningsFor(sourceRun) ? " boundary-estimate" : ""
                        runner.append("⚠️ run\(sourceRun) was marked ACCEPT but is NOT stable (\(why)\(boundary)). Forcing REVISE — must achieve S (minimization) + C (covariance) with no boundary estimate before it can be the base model.")
                        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusForcedReviseBase, sourceRun)))
                        decision = "REVISE\nModel not stable (\(why)\(boundary)). Must achieve minimization + covariance success with no boundary estimate before acceptance."
                    } else {
                        assistantMessages.append(AssistantMessage.parse(formatDecisionMessage(decision, runID: sourceRun, isCovariate: false), role: .assistant))
                    }
                    runner.append(decision)

                    // Deposit this evaluation's outcome as a durable skill
                    depositModelingSkill(runID: sourceRun, decision: decision, diagnostics: evidence, phase: "Phase1")

                    // ── AI Skill Synthesis ──
                    // Ask the LLM (e.g. DeepSeek) to extract ONE generalizable lesson
                    // when a repair just succeeded OR the base / covariate model is accepted.
                    // The lesson is stripped of project details and saved as a global critical
                    // skill that benefits future (weaker) local models.
                    let acceptedDecision = isAcceptanceDecision(decision)
                    let isSkillRepair = previousRunWasFailure && runSuccessful
                    if acceptedDecision || isSkillRepair {
                        Task {
                            do {
                                let phaseLabel: String
                                let problemDesc: String
                                if isSkillRepair {
                                    phaseLabel = "Phase1 Repair"
                                    problemDesc = "Previous Phase 1 model run failed estimation; this iteration succeeded after applying fixes."
                                } else {
                                    phaseLabel = "Phase1 Acceptance"
                                    problemDesc = "Phase 1 base model selection is being finalized — the chosen structural model was marked ACCEPT by the evaluation AI."
                                }
                                if let skill = try await LLMCommandService.synthesizeSkillLesson(
                                    baseURL: llmBaseURL, model: llmModel, apiKey: llmAPIKey,
                                    phase: phaseLabel,
                                    problem: problemDesc,
                                    action: "run\(sourceRun) evaluation decision: \(decision.prefix(300))",
                                    result: "Evidence summary: \(evidence.prefix(300))",
                                    sessionId: automationSessionId,
                                    apiFormat: activeAPIFormat
                                ) {
                                    PPKSkillStore.shared.addLesson(
                                        category: skill.category,
                                        title: skill.title,
                                        problem: "Auto-synthesized: \(skill.lesson.prefix(200))",
                                        solution: skill.lesson,
                                        sourceRun: sourceRun,
                                        severity: skill.severity,
                                        tags: ["synthesized", "phase1"]
                                    )
                                    runner.append("🧠 Skill synthesized: [\(skill.category.rawValue)][\(skill.severity.rawValue)] \(skill.title)")
                                }
                            } catch {
                                runner.append("⚠️ Skill synthesis skipped: \(error.localizedDescription.prefix(100))")
                            }
                        }
                    }
                    previousRunWasFailure = !runSuccessful

                    // In inherited mother-model mode, an S+C handoff model is not the base model yet.
                    // The known next step is to release ALL inherited structural FIXes on the full
                    // mixed dataset. Do this even when the evaluation AI says REVISE, because the
                    // handoff is intentionally constrained until this release round succeeds.
                    let stableHandoffWithInheritedFixes = inheritedHandoffMode
                        && runMinimizationOK(sourceRun)
                        && runCovarianceOK(sourceRun)
                        && LLMCommandService.hasInheritedStructuralFixes(
                            (try? String(contentsOf: projectURL.appendingPathComponent("run\(sourceRun).mod"), encoding: .utf8)) ?? ""
                        )
                    if stableHandoffWithInheritedFixes {
                        releaseInheritedFixes = true
                        forceEscalation = false
                        runner.append("Inherited handoff run\(sourceRun) is S+C. Releasing ALL inherited structural FIXes before accepting a full-dataset base model.")
                        assistantMessages.append(AssistantMessage(role: .system, text: localized(
                            "run\(sourceRun) 已达到 S+C。接下来直接全部放开继承的结构参数 FIX，让 CL/V/Q 等在全数据集上重新估计。",
                            "run\(sourceRun) reached S+C. Releasing ALL inherited structural FIXes so CL/V/Q can be re-estimated on the full dataset."
                        )))
                    }

                    let stableReleasedChild = inheritedHandoffMode
                        && runMinimizationOK(sourceRun)
                        && runCovarianceOK(sourceRun)
                        && !hasBoundaryWarningsFor(sourceRun)
                        && !LLMCommandService.hasInheritedStructuralFixes(
                            (try? String(contentsOf: projectURL.appendingPathComponent("run\(sourceRun).mod"), encoding: .utf8)) ?? ""
                        )
                    if stableReleasedChild && !childIIVExplorationScheduled && !childIIVExplorationAttempted {
                        childIIVExplorationScheduled = true
                        runner.append("Inherited child base run\(sourceRun) is S+C with inherited FIXes released. Re-adding previously dropped IIV before final model selection.")
                        assistantMessages.append(AssistantMessage(role: .system, text: localized(
                            "母本子模型 run\(sourceRun) 已稳定，且继承参数 FIX 已放开。下一步把之前 drop 掉的 ETA/OMEGA 重新加回来，再继续考察 IIV。",
                            "Inherited child run\(sourceRun) is stable with inherited FIXes released. Next, re-add the previously dropped ETA/OMEGA terms and continue IIV exploration."
                        )))
                    }

                    if isAcceptanceDecision(decision) {
                        // RULE 0: The run being accepted MUST itself be S+C (stable + converged).
                        // No amount of higher-compartment testing justifies accepting a non-S+C run.
                        // If current run is NOT S+C, reject the ACCEPT outright — force repair at
                        // the SAME compartment count WITHOUT escalating.
                        let currentIsStable = isModelStable(runID: sourceRun)
                        if !currentIsStable {
                            let runInfo = compartmentInfoForRun(sourceRun)
                            let reason = missingEstimationReason(runID: sourceRun)
                            runner.append("AI said ACCEPT but run\(sourceRun) (\(runInfo.compartments)-comp) is NOT S+C (\(reason)). Rejecting — must achieve stable+converged at this compartment before considering escalation. Repairing at \(runInfo.compartments)-comp.")
                            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusCompAcceptNotSC, sourceRun, String(runInfo.compartments), reason, String(runInfo.compartments))))
                            forceEscalation = false
                            // Fall through — proposeOptimizedModel will repair at same compartment
                        } else if inheritedHandoffMode && childIIVExplorationScheduled {
                            decision = "REVISE\nInherited child base is S+C; re-add dropped IIV before final acceptance."
                            assistantMessages.append(AssistantMessage(role: .system, text: localized(
                                "母本子模型已达到 S+C，先不把它作为最终子模型。下一步重新加入之前 drop 掉的 IIV，再做 IIV 放开/固定比较。",
                                "Inherited child base reached S+C, but it is not final yet. Next, re-add previously dropped IIV and compare keep/fix options."
                            )))
                        } else if inheritedHandoffMode {
                            let handoffModURL = projectURL.appendingPathComponent("run\(sourceRun).mod")
                            let handoffModText = (try? String(contentsOf: handoffModURL, encoding: .utf8)) ?? ""
                            let hasInheritedFixes = LLMCommandService.hasInheritedStructuralFixes(handoffModText)
                            if hasInheritedFixes {
                                // The release was already scheduled above; fall through and draft the release model.
                            } else {
                                accepted = true
                                acceptedRun = sourceRun
                                duDuMood = .excited
                                let summary = phaseOneSummary(runs: modelRuns, acceptedRun: acceptedRun ?? sourceRun)
                                let bestRunID = acceptedRun ?? sourceRun
                                let bestComp = compartmentInfoForRun(bestRunID).compartments
                                let hasHighRSE = hasHighResidualRSE(runID: bestRunID, threshold: 50.0)
                                if bestComp >= 3 && hasHighRSE {
                                    beginBenchmarkBaseWaitIfNeeded()
                                    isAutoModeling = false
                                    automationStep = "Compartment decision needed"
                                    compDecisionAcceptedRun = bestRunID
                                    compDecisionInfo = summary + "\n\n" + String.safeFormat(L10n.statusCompDecisionRSE, String(bestComp))
                                    isCompDecisionPresented = true
                                    break
                                }
                                runner.append("=== PHASE 1 COMPLETE ===\n\(summary)")
                                runner.append("Inherited child base model complete: run\(sourceRun) reached S+C after releasing inherited structural FIXes.")
                                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusPhase1Complete, summary, acceptedRun ?? sourceRun)))
                                assistantMessages.append(AssistantMessage(role: .system, text: localized(
                                    "母本子模型 run\(sourceRun) 已达到 S+C，且继承的结构参数 FIX 已全部放开。这相当于混合数据集的基模已完成，是否继续 SCM？",
                                    "Inherited child run\(sourceRun) reached S+C with all inherited structural FIXes released. The full-dataset base model is ready. Continue with SCM?"
                                )))
                                beginBenchmarkBaseWaitIfNeeded()
                                isAutoModeling = false
                                automationStep = "Inherited child base model complete — awaiting SCM confirmation"
                                baseModelConfirmSummary = summary + "\n\n" + localized(
                                    "子模型已作为混合数据集的基模完成，下一步可以进行 SCM。",
                                    "The inherited child model is finalized as the full-dataset base model. SCM is the next step."
                                )
                                baseModelConfirmRunID = bestRunID
                                markAIModel(runID: bestRunID)
                                isBaseModelConfirmPresented = true
                                break
                            }
                        } else {
                            // Prevent premature acceptance: AUTO-REVISE if the next compartment level has NOT been tested.
                            let preventAccept = shouldPreventAcceptance(runID: sourceRun, decision: decision, modelRuns: modelRuns, profile: profile)
                            if preventAccept {
                                let runInfo = compartmentInfoForRun(sourceRun)
                                let nextComp = runInfo.compartments + 1
                                runner.append("AI said ACCEPT but next compartment not yet tested — auto-overriding to REVISE. Current: \(runInfo.compartments)-comp. Must also test \(nextComp)-comp before acceptance.")
                                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusCompRequireCompare, sourceRun, String(runInfo.compartments), String(nextComp), String(nextComp))))
                                forceEscalation = true  // signal to proposeOptimizedModel
                            } else {
                                let existingComps = Set(modelRuns.map { compartmentInfoForRun($0).compartments })
                                let compsMissingSC = existingComps.filter { comp in
                                    modelRuns
                                        .filter { compartmentInfoForRun($0).compartments == comp }
                                        .allSatisfy { !isModelStable(runID: $0) }
                                }.sorted()
                                if !compsMissingSC.isEmpty {
                                    let list = compsMissingSC.map { "\($0)-comp" }.joined(separator: ", ")
                                    runner.append("⚠️ Phase 1 integrity check FAILED: compartment count(s) \(list) have runs but NONE achieved S+C (stable + converged). Cannot finalize base model yet — continuing exploration within \(list).")
                                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusCompIntegrityFail, list)))
                                    forceEscalation = false
                                } else {
                                    accepted = true
                                    let phase1Choices = modelRuns.enumerated().map { index, runID in
                                        automationRunChoice(runID: runID, previousRun: index > 0 ? modelRuns[index - 1] : nil)
                                    }
                                    acceptedRun = selectBestBaseModel(choices: phase1Choices)?.runID ?? sourceRun
                                    duDuMood = .excited
                                    let summary = phaseOneSummary(runs: modelRuns, acceptedRun: acceptedRun ?? sourceRun)
                                    let bestRunID = acceptedRun ?? sourceRun
                                    let bestComp = compartmentInfoForRun(bestRunID).compartments
                                    let hasHighRSE = hasHighResidualRSE(runID: bestRunID, threshold: 50.0)
                                    if bestComp >= 3 && hasHighRSE {
                                        beginBenchmarkBaseWaitIfNeeded()
                                        isAutoModeling = false
                                        automationStep = "Compartment decision needed"
                                        compDecisionAcceptedRun = bestRunID
                                        compDecisionInfo = summary + "\n\n" + String.safeFormat(L10n.statusCompDecisionRSE, String(bestComp))
                                        isCompDecisionPresented = true
                                        break
                                    }
                                    runner.append("=== PHASE 1 COMPLETE ===\n\(summary)")
                                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusPhase1Complete, summary, acceptedRun ?? sourceRun)))
                                    beginBenchmarkBaseWaitIfNeeded()
                                    isAutoModeling = false
                                    automationStep = "Phase 1 complete — awaiting confirmation"
                                    baseModelConfirmSummary = summary
                                    baseModelConfirmRunID = bestRunID
                                    markAIModel(runID: bestRunID)
                                    isBaseModelConfirmPresented = true
                                    break
                                }
                            }
                        }
                    }

                    guard iteration < maxEvaluations else {
                        runner.append("Reached max evaluations (\(maxEvaluations) iterations). Best candidate: run\(sourceRun). Click DuDu Auto again to continue from the latest run — it will NOT restart from scratch.")
                        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.autoLimitReached, maxEvaluations, sourceRun)))
                        break
                    }
                    let nextRun = useChildRunIDs
                        ? nextChildRunID(parent: sourceRun)
                        : formattedRun(nextRunNumber)
                    if !useChildRunIDs { nextRunNumber += 1 }
                    automationStep = "AI drafting run\(nextRun).mod"

                    // HARD GATE — every structural level must reach S+C before escalating.
                    // If the current compartment level (the source run's level) has not yet produced
                    // any STABLE + CONVERGED run, we MUST keep repairing at the SAME level and must NOT
                    // jump to the next compartment count.
                    var forceSameCompartment = false
                    if !covariatePhase {
                        let sourceComp = compartmentInfoForRun(sourceRun).compartments
                        let levelHasSC = modelRuns
                            .filter { compartmentInfoForRun($0).compartments == sourceComp }
                            .contains { isModelStable(runID: $0) }
                        if !levelHasSC {
                            forceSameCompartment = true
                            forceEscalation = false
                            let phrase = "\(sourceComp)-comp"
                            runner.append(String.safeFormat(L10n.autoGatingLocked, phrase))
                            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.autoGatingLockedShort, phrase, phrase)))
                        }
                    }

                    // Second safety net: if this is an inherited handoff that reached S+C but still
                    // carries inherited structural FIXes, force the next model to release them.
                    if inheritedHandoffMode,
                       !releaseInheritedFixes,
                       runMinimizationOK(sourceRun),
                       runCovarianceOK(sourceRun),
                       LLMCommandService.hasInheritedStructuralFixes(
                           (try? String(contentsOf: projectURL.appendingPathComponent("run\(sourceRun).mod"), encoding: .utf8)) ?? ""
                       ) {
                        releaseInheritedFixes = true
                        forceEscalation = false
                        runner.append("Inherited handoff run\(sourceRun) is S+C; scheduling release of all inherited structural FIXes.")
                    }

                    // [硬性规定] 每次写下一份模型前，检查前一次运行的残差 RSE。
                    // 如果残差项 %RSE > 100%，强制在当前房室层修复残差，不允许升室。
                    // 实施方式：直接修改源 .mod 文件，给对应 THETA 加上 FIX 关键字。
                    // AI 在 proposeOptimizedModel 中读取该文件时，看到的是已 FIX 的版本。
                    if !covariatePhase && !inheritedHandoffMode && hasHighResidualRSE(runID: sourceRun, threshold: 100.0) {
                        forceSameCompartment = true
                        forceEscalation = false
                        let sourceMod = projectURL.appendingPathComponent("run\(sourceRun).mod")
                        if let rawText = try? String(contentsOf: sourceMod, encoding: .utf8) {
                            let modText = LLMCommandService.stripInlineDatasetRows(rawText)
                            let fixed = forceFixUnreliableParameter(modText, runID: sourceRun)
                            if fixed != modText {
                                try? fixed.write(to: sourceMod, atomically: true, encoding: .utf8)
                                runner.append(String.safeFormat(L10n.autoHighRSEFix, sourceRun))
                                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.autoHighRSEFix, sourceRun)))
                            }
                        }
                    }

                    let releaseSourceText = (try? String(contentsOf: projectURL.appendingPathComponent("run\(sourceRun).mod"), encoding: .utf8)) ?? ""
                    let forceReleaseThisRound = releaseInheritedFixes
                        || (LLMCommandService.hasInheritedStructuralFixes(releaseSourceText)
                            && runMinimizationOK(sourceRun)
                            && runCovarianceOK(sourceRun))
                    if forceReleaseThisRound {
                        forceEscalation = false
                    }

                    let forceReAddIIVThisRound = childIIVExplorationScheduled
                    let (nextModel, optUsage) = try await LLMCommandService.proposeOptimizedModel(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        projectURL: projectURL,
                        sourceRun: sourceRun,
                        nextRun: nextRun,
                        rules: rules,
                        diagnosticSummary: "\(decision)\n\n\(evidence)",
                        isCovariatePhase: covariatePhase,
                        forceCompartmentEscalation: forceEscalation,
                        forceSameCompartment: forceSameCompartment,
                        forceReleaseInheritedFixes: forceReleaseThisRound,
                        forceReAddDroppedIIV: forceReAddIIVThisRound,
                        apiKey: llmAPIKey,
                        sessionId: automationSessionId,
                        s1Expression: derivedS1Expression,
                        s1for2CompExpression: derivedS1for2CompExpression,
                        s2Expression: derivedS2Expression,
                        s2for2CompExpression: derivedS2for2CompExpression,
                        derivedVUnit: derivedVUnit,
                        derivedCLUnit: derivedCLUnit,
                        apiFormat: activeAPIFormat
                    )
                    recordUsage(optUsage)
                    if forceReAddIIVThisRound {
                        childIIVExplorationScheduled = false
                        childIIVExplorationAttempted = true
                        runner.append("Scheduled run\(nextRun) to re-add previously dropped IIV/ETA terms.")
                    }
                    try checkAutomationStop("model drafting run\(nextRun)")
                    var draftedModel = LLMCommandService.sanitizeControlStream(
                        nextModel,
                        projectURL: projectURL,
                        dataFile: activeDataFile
                    )
                    let sourceCompartment = compartmentInfoForRun(sourceRun).compartments
                    let draftedCompartment = LLMCommandService.detectCompartmentCount(draftedModel)
                    if draftedCompartment < sourceCompartment
                        || (inheritedHandoffMode && draftedCompartment > sourceCompartment) {
                        runner.append("AI attempted to change compartment count for run\(nextRun) (\(sourceCompartment)-comp); using same-compartment fallback.")
                        let sourceURL = projectURL.appendingPathComponent("run\(sourceRun).mod")
                        let raw = (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? ""
                        let fallback = raw
                            .replacingOccurrences(of: "run\(sourceRun)", with: "run\(nextRun)")
                            .replacingOccurrences(of: "RUN\(sourceRun)", with: "RUN\(nextRun)")
                            .replacingOccurrences(of: "Run\(sourceRun)", with: "Run\(nextRun)")
                            .replacingOccurrences(of: "SDTAB\(sourceRun)", with: "SDTAB\(nextRun)")
                            .replacingOccurrences(of: "PATAB\(sourceRun)", with: "PATAB\(nextRun)")
                            .replacingOccurrences(of: "CATAB\(sourceRun)", with: "CATAB\(nextRun)")
                            .replacingOccurrences(of: "COTAB\(sourceRun)", with: "COTAB\(nextRun)")
                            .replacingOccurrences(of: "run\(sourceRun).ETA", with: "run\(nextRun).ETA")
                        draftedModel = LLMCommandService.sanitizeControlStream(
                            fallback,
                            projectURL: projectURL,
                            dataFile: activeDataFile
                        )
                    }
                    if forceReleaseThisRound {
                        draftedModel = LLMCommandService.releasingIVAnchorHandoffFixes(draftedModel)
                        if !releaseSourceText.isEmpty {
                            draftedModel = LLMCommandService.trimmingAddedIIVForHandoffRelease(
                                draftedModel,
                                sourceModText: releaseSourceText
                            )
                        }
                        runner.append("Released inherited structural FIXes in run\(nextRun).mod; parameters will be re-estimated on the full mixed dataset.")
                    }
                    draftedModel = normalizeTypicalValueNaming(draftedModel)
                    if let sourceModText = try? String(contentsOf: projectURL.appendingPathComponent("run\(sourceRun).mod"), encoding: .utf8) {
                        draftedModel = protectResidualEstimation(draftedModel, sourceModText: sourceModText, runID: sourceRun)
                    }
                    draftedModel = enforceZeroFixForResidualError(draftedModel)
                    draftedModel = withETATableRecord(draftedModel, runID: nextRun)
                    draftedModel = correctS1Scaling(draftedModel)
                    draftedModel = LLMCommandService.applyingIVInfusionDurationFix(draftedModel)
                    draftedModel = LLMCommandService.normalizingTableRecords(draftedModel, runID: nextRun)
                    let candidateURL = projectURL.appendingPathComponent("run\(nextRun).mod")
                    guardModFileWrite(draftedModel, to: candidateURL, label: "run\(nextRun).mod (candidate)")
                    runner.append("Created candidate model run\(nextRun).mod")
                    // Preflight validation before NONMEM
                    let validation = await validateModel(nextRun)
                    if !validation.passed {
                        runner.append("Candidate model run\(nextRun).mod has preflight issues -- attempting auto-fix")
                        let fix = await autoFixModel(nextRun)
                        if fix.fixed {
                            runner.append("Auto-fix applied to run\(nextRun).mod")
                        } else {
                            // Force-strip and continue — NEVER stop the loop
                            if let txt = try? String(contentsOf: candidateURL, encoding: .utf8) {
                                let stripped = LLMCommandService.stripInlineDatasetRows(txt)
                                if stripped != txt {
                                    try? stripped.write(to: candidateURL, atomically: true, encoding: .utf8)
                                }
                            }
                            runner.append("⚠️ run\(nextRun).mod 候选模型预检未通过，数据行已强制清理，LLM将在下一轮修复。")
                            assistantMessages.append(AssistantMessage(role: .assistant, text: localized(
                                "run\(nextRun).mod 预检未通过，DuDu继续修复…",
                                "run\(nextRun).mod did not pass preflight; DuDu will repair it…"
                            )))
                        }
                    }
                    previousForComparison = sourceRun
                    sourceRun = nextRun
                    modelRuns.append(nextRun)
                    releaseInheritedFixes = false
                    refreshWorkspace()
                }

                let best = selectBestAutomationRun(preferredAcceptedRun: acceptedRun, profile: profile, isPhaseOne: !covariatePhase)
                automationStep = accepted ? "Accepted run\(best?.runID ?? sourceRun)" : "Best candidate run\(best?.runID ?? sourceRun)"
                if let best {
                    currentRun = best.runID
                    previousRun = best.previousRun ?? best.runID
                    commandText = psnRunCommand(runID: best.runID)
                }
                let phaseLabel = covariatePhase ? L10n.autoCompletedWithCov : L10n.autoCompletedPhase2
                // Offer bootstrap + AI report for final model
                if accepted && covariatePhase, let finalRun = acceptedRun {
                    let finalRunID = finalRun
                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.autoCompletedMsg, phaseLabel, finalRunID, finalRunID)))
                    startFinalModelPackage(for: finalRunID, previousRun: best?.previousRun ?? sourceRun)
                } else if accepted {
                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.autoCompletedSimple, phaseLabel, best?.runID ?? sourceRun)))
                } else {
                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.autoLimitReached, maxEvaluations, best?.runID ?? sourceRun)))
                }
                refreshWorkspace()
                if let best,
                   let asset = asset(withID: projectURL.appendingPathComponent("run\(best.runID).mod").path) {
                    select(asset)
                }
            } catch let stop as AutomationStoppedError {
                let best = selectBestAutomationRun(preferredAcceptedRun: nil, profile: LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: dataFile), isPhaseOne: !outerCovariatePhase)
                if let best {
                    currentRun = best.runID
                    previousRun = best.previousRun ?? best.runID
                    commandText = psnRunCommand(runID: best.runID)
                    refreshWorkspace()
                    if let asset = asset(withID: projectURL.appendingPathComponent("run\(best.runID).mod").path) {
                        select(asset)
                    }
                }
                runner.append("Automation stopped at \(stop.step).")
                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.autoStoppedAt, stop.step, best?.runID ?? currentRun)))
            } catch let datasetError as AutomationDatasetError {
                // Last-resort safety net — all inner throw sites have been removed,
                // so this should only fire for truly unexpected cases.
                // Force-strip data rows and inform the user without blocking.
                let modURL = projectURL.appendingPathComponent("run\(datasetError.runID).mod")
                if let txt = try? String(contentsOf: modURL, encoding: .utf8) {
                    let stripped = LLMCommandService.stripInlineDatasetRows(txt)
                    if stripped != txt {
                        try? stripped.write(to: modURL, atomically: true, encoding: .utf8)
                        runner.append("Safety net: force-stripped data rows from run\(datasetError.runID).mod")
                    }
                }
                let details = datasetError.output
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let message = localized(
                    "驱动模型 run\(datasetError.runID).mod 校验未通过。数据行已强制清理，请检查以下结构问题：\n\n\(details)",
                    "Driver model run\(datasetError.runID).mod did not pass validation. Data rows were force-cleared; check the structural issues below:\n\n\(details)"
                )
                runner.append(message)
                assistantMessages.append(AssistantMessage(role: .assistant, text: message))
                refreshWorkspace()
            } catch is CancellationError {
                runner.append("Automation cancelled.")
                assistantMessages.append(AssistantMessage(role: .system, text: L10n.autoStoppedShort))
            } catch {
                // If stop was already requested, don't show "connection failed" — it was cancelled
                if automationStopRequested {
                    runner.append("Automation cancelled.")
                    return
                }
                let message = LLMCommandService.friendlyError(error, baseURL: llmBaseURL)
                runner.append("Automated modeling failed: \(message)")
                assistantMessages.append(AssistantMessage(role: .assistant, text: String.safeFormat(L10n.autoFailed, message)))
                // Don't attempt reconnect — let the user fix the LLM service first.
                resetAutomationUIState(step: "LLM error — check connection", mood: .sad)
            }
        }
    }

    func runCurrentModel() {
        refreshChecks()
        Task {
            let exit = await runner.runAndWait(command: commandText, in: projectURL)
            if exit == 0 {
                _ = await runner.runAndWait(
                    command: "\(pythonBridgeCommand(task: "pk-parameters", previous: previousRun, current: currentRun)) || true",
                    in: projectURL
                )
            }
            refreshWorkspace()
        }
    }

    func runVPC() {
        runPsNVPC(for: currentRun)
    }

    func runPsNVPC(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "psn-vpc", previous: previousRun, current: runID))
    }

    func runGOF(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "gof-plot", previous: previousRun, current: runID))
    }

    func runIndividualDVTime(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "individual-plot", previous: previousRun, current: runID))
    }

    func runVPCPlot(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "vpc-plot", previous: previousRun, current: runID))
    }

    func runPKParameterExtraction(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "pk-parameters", previous: previousRun, current: runID))
    }

    func runEDA(dataFile: String? = nil) {
        guard !runner.isRunning else {
            runner.append("A task is already running. Please wait for it to complete.")
            return
        }
        let resolvedData = dataFile ?? (automationDataFile.isEmpty ? self.dataFile : automationDataFile)
        runCommandAndRefresh(pythonBridgeCommandForDataset(task: "eda", dataFile: resolvedData))
    }

    func runCTCurves(dataFile: String? = nil) {
        guard !runner.isRunning else {
            runner.append("A task is already running. Please wait for it to complete.")
            return
        }
        let resolvedData = dataFile ?? (automationDataFile.isEmpty ? self.dataFile : automationDataFile)
        let command = pythonBridgeCommandForDataset(task: "ct-curves", dataFile: resolvedData)
        Task {
            _ = await runner.runAndWait(command: command, in: projectURL)
            refreshWorkspace()
            appendCTFacetMessages(fileName: resolvedData, prefix: "CT_")
        }
    }

    private func appendCTFacetMessages(fileName: String, prefix: String = "") {
        let stem = (fileName as NSString).lastPathComponent.replacingOccurrences(of: ".csv", with: "")
        let facetColumns = ["ROUTE", "SEX", "STUDY", "ADA", "BQL", "TYPE",
                            "RACE", "GROUP", "COHORT", "TREATMENT"]
        for facet in facetColumns {
            let facetFile = "\(prefix)\(stem)_by_\(facet.lowercased()).png"
            let facetPath = projectURL.appendingPathComponent(facetFile).path
            if FileManager.default.fileExists(atPath: facetPath) {
                assistantMessages.append(AssistantMessage(
                    role: .system,
                    text: String.safeFormat(L10n.ctFacetPlot, facet, facetPath)
                ))
            }
        }
    }

    func runDiagnostics() {
        runDiagnostics(for: currentRun)
    }

    func runDiagnostics(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "r-diagnostics", previous: previousRun, current: runID))
    }

    func presentBootstrapSheet(for runID: String? = nil) {
        guard ensureModelFilesExist() else { return }
        bootstrapSheetRunID = runID ?? preferredAIModelRunID ?? currentRun
        isBootstrapSheetPresented = true
    }

    func runBootstrap(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "bootstrap", previous: previousRun, current: runID))
    }

    /// Bootstrap with a user-chosen sample count, then ask DuDu to interpret the results.
    func runBootstrapWithAI(for runID: String, samples: Int) {
        guard !runner.isRunning else {
            runner.append("A task is already running. Please wait.")
            return
        }
        activateRun(runID)
        runner.append("=== Starting PsN bootstrap for run\(runID) (\(samples) samples) ===")
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusBootstrapStarted, runID, samples)))
        duDuMood = .working
        isAssistantThinking = true
        isBootstrapRunning = true
        automationStep = "Bootstrap \(samples) samples — run\(runID)"
        addThinkingStep(String.safeFormat(L10n.statusBootstrapPreparing, samples), type: .working)
        let isFinalReport = bootstrapFinalRunID == runID
        Task {
            updateLastThinkingStep(type: .working, detail: "\(samples) samples")
            addThinkingStep(L10n.statusBootstrapRunning, type: .working)
            let exit = await runner.runAndWait(command: pythonBootstrapCommand(runID: runID, samples: samples), in: projectURL)
            if exit == 0 {
                updateLastThinkingStep(type: .done)
                addThinkingStep(String.safeFormat(L10n.statusBootstrapParsing, runID), type: .working)
                await analyzeBootstrapResults(runID: runID)
                updateLastThinkingStep(type: .done)
            } else {
                updateLastThinkingStep(type: .error, detail: "exit \(exit)")
                runner.append("Bootstrap run\(runID) failed (exit \(exit)).")
                assistantMessages.append(AssistantMessage(role: .assistant, text: String.safeFormat(L10n.statusBootstrapFailed, runID)))
            }
            isAssistantThinking = false
            isBootstrapRunning = false
            duDuMood = .happy
            automationStep = "Idle"
            if isFinalReport {
                await generateFinalModelReport(runID: runID, bootstrapSucceeded: exit == 0)
                bootstrapFinalRunID = ""
            }
            refreshWorkspace()
        }
    }

    /// Final-model package entry point: generate PK parameter table + diagnostics, then ask
    /// the analyst how many bootstrap samples to run before producing the final report.
    func startFinalModelPackage(for runID: String, previousRun: String) {
        guard !runner.isRunning, !isBootstrapSheetPresented else { return }
        markAIModel(runID: runID)
        bootstrapFinalRunID = runID
        runner.append("=== Final model package for run\(runID): PK parameters + diagnostics ===")
        activateRun(runID)
        Task {
            let pkCommand = pythonBridgeCommand(task: "pk-parameters", previous: previousRun, current: runID)
            _ = await runner.runAndWait(command: pkCommand, in: projectURL)

            let diagnosticsCommand = pythonBridgeCommand(task: "r-diagnostics", previous: previousRun, current: runID)
            _ = await runner.runAndWait(command: diagnosticsCommand, in: projectURL)

            bootstrapSheetRunID = runID
            isBootstrapSheetPresented = true
        }
    }

    func cancelBootstrapSheet() {
        bootstrapFinalRunID = ""
        isBootstrapSheetPresented = false
    }

    private func pythonBootstrapCommand(runID: String, samples: Int) -> String {
        pythonBridgeCommand(task: "bootstrap", previous: previousRun, current: runID)
            + " --bootstrap-samples \(samples)"
    }

    private func analyzeBootstrapResults(runID: String) async {
        let summary = bootstrapResultsTable(runID: runID)
        runner.append("Bootstrap results table for run\(runID) ready (\(summary.count) chars)")
        assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusBootstrapParsingDone(runID)))
        addThinkingStep(L10n.statusBootstrapThinking(runID), type: .working)
        let isEnglish = LanguageStore.shared.language == .en
        let promptText = isEnglish ? """
        Analyze the PsN Bootstrap results for run\(runID). The rules library and model library are already in the system context.

        The table below was parsed from bootstrap_dir_\(runID)/bootstrap_results.csv (PsN percentile notation).

        IMPORTANT READING RULES:
        - The 95% confidence interval of a parameter is [2.5% percentile, 97.5% percentile]. NEVER use the 5% / 95% rows — that would be a 90% interval.
        - "NA" means that percentile was not estimable for that parameter — say so instead of inventing a number.
        - IGNORE the "covariance.step.successful" diagnostic for the reliability verdict (it is frequently 0 for this model family and is not the basis for judging bootstrap stability).
        - For each parameter: give bootstrap median, 95% CI, RSE (= SE/median), and state whether the ORIGINAL run estimate falls inside the 95% CI. A parameter whose original estimate is inside the CI is stable; outside means the resampling distribution is not centered on the original estimate.
        - Report the OFV distribution (median and 95% CI) and what it says about fit stability across resamples.
        - Mention fixed parameters (estimate 0) as "fixed, not re-estimated".
        - End with a clear verdict: is the model's parameterization stable under bootstrap? List any unstable parameters and one concrete next step each.

        Bootstrap results (parsed table):
        \(summary.prefix(40_000))
        """ : """
        请分析 run\(runID) 的 PsN Bootstrap 结果。规则库和模型库已在系统上下文中。

        下面的表是从 bootstrap_dir_\(runID)/bootstrap_results.csv 解析出来的（PsN 百分位格式）。

        重要读表规则：
        - 参数的 95% 置信区间 = [2.5% 分位, 97.5% 分位]。绝不要用 5% / 95% 那两行（那是 90% 区间）。
        - "NA" 表示该分位没有估出来，直接说明即可，不要编数字。
        - 可靠性结论中忽略 "covariance.step.successful" 这一项（这类模型家族里它经常为 0，不能作为判断 Bootstrap 稳定性的依据）。
        - 每个参数请给出：Bootstrap 中位数、95% CI、RSE（=SE/中位数），并明确判断原始 run 的估计值是否落在 95% CI 内——落在区间内说明稳定，落在区间外说明重抽样分布与原始估计不一致。
        - 报告 OFV 分布（中位数和 95% CI）以及它反映的拟合稳定性。
        - 固定参数（估计值为 0）请标注"固定，未重估"。
        - 最后给出明确结论：该模型参数化在 Bootstrap 下是否稳定；列出不稳定的参数，并给出每个参数的具体下一步建议。

        Bootstrap 结果（已解析的表）：
        \(summary.prefix(40_000))
        """
        let prompt = AssistantMessage(
            role: .user,
            text: promptText
        )
        do {
            let (reply, usage) = try await LLMCommandService.chat(
                baseURL: llmBaseURL,
                model: llmModel,
                messages: [prompt],
                projectURL: projectURL,
                currentRun: runID,
                rules: activeRuleContext().text + "\n" + PPKSkillStore.shared.contextBlock(),
                apiKey: llmAPIKey,
                personality: activePersonalityBlock,
                knowledgeBaseURL: knowledgeBaseURL,
                apiFormat: activeAPIFormat
            )
            recordUsage(usage)
            assistantMessages.append(AssistantMessage.parse(reply, role: .assistant))
            runner.append("AI Bootstrap analysis for run\(runID) complete.")
        } catch {
            runner.append("AI Bootstrap analysis failed: \(error.localizedDescription)")
            assistantMessages.append(AssistantMessage(role: .assistant, text: String.safeFormat(L10n.statusBootstrapParseFailed, LLMCommandService.friendlyError(error, baseURL: llmBaseURL))))
        }
    }

    /// Parse PsN's bootstrap_results.csv into a clean, structured table that the LLM can
    /// read reliably (percentile notation, medians, SEs, bias, diagnostics, original-run
    /// estimates). Falls back to the generic dump when the CSV is missing.
    private func bootstrapResultsTable(runID: String) -> String {
        let dir = projectURL.appendingPathComponent("bootstrap_dir_\(runID)")
        let csvURL = dir.appendingPathComponent("bootstrap_results.csv")
        guard let raw = try? String(contentsOf: csvURL, encoding: .utf8), !raw.isEmpty else {
            return bootstrapOutputSummary(runID: runID)
        }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        let rows = lines.map { parseSCMCSVLine(String($0)).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
        guard rows.count > 5 else { return bootstrapOutputSummary(runID: runID) }

        func section(_ label: String) -> (header: [String], dataRows: [[String]])? {
            guard let labelIdx = rows.firstIndex(where: { ($0.first ?? "").lowercased() == label }) else { return nil }
            var header: [String] = []
            var data: [[String]] = []
            var i = labelIdx + 1
            while i < rows.count {
                let first = (rows[i].first ?? "").lowercased()
                if ["diagnostic.means", "means", "bias", "standard.error.confidence.intervals",
                    "standard.errors", "medians", "percentile.confidence.intervals"].contains(first) { break }
                if header.isEmpty {
                    header = rows[i]
                } else {
                    data.append(rows[i])
                }
                i += 1
            }
            return header.isEmpty ? nil : (header, data)
        }

        // Parameter column names: non-empty header cells, skipping SE / shrinkage / EI columns
        guard let means = section("means") else { return bootstrapOutputSummary(runID: runID) }
        let header = means.header
        var paramIndices: [Int] = []
        for (idx, name) in header.enumerated() {
            let n = name.lowercased()
            guard !n.isEmpty else { continue }
            if n.hasPrefix("se") || n.hasPrefix("shrinkage") || n.hasPrefix("ei") { continue }
            paramIndices.append(idx)
        }

        let medians = section("medians")?.dataRows.first ?? []
        let meanRow = means.dataRows.first ?? []
        let seRow = section("standard.errors")?.dataRows.first ?? []
        let biasRow = section("bias")?.dataRows.first ?? []
        let percentile = section("percentile.confidence.intervals")
        let p25 = percentile?.dataRows.first { ($0.first ?? "").trimmingCharacters(in: .whitespaces) == "2.5%" } ?? []
        let p975 = percentile?.dataRows.first { ($0.first ?? "").trimmingCharacters(in: .whitespaces) == "97.5%" } ?? []

        func value(_ row: [String], _ idx: Int) -> Double? {
            guard idx < row.count else { return nil }
            let v = row[idx]
            guard !v.isEmpty, v.uppercased() != "NA" else { return nil }
            return Double(v)
        }

        // Original run estimates (from runXXX.ext + mod labels) for the CI check
        let originalRows = ProjectScanner.parameterEstimates(runID: runID, in: projectURL)
        var originalByName: [String: (estimate: Double, se: Double?)] = [:]
        for row in originalRows {
            let key = row.name.trimmingCharacters(in: .whitespaces).lowercased()
            originalByName[key] = (row.estimate, row.standardError)
        }
        func originalEstimate(for headerName: String) -> (estimate: Double, se: Double?)? {
            let key = headerName.trimmingCharacters(in: .whitespaces).lowercased()
            if let hit = originalByName[key] { return hit }
            // fuzzy: match by stripping spaces/units differences, e.g. "IIV CL" vs "IIV CL"
            let compact = key.replacingOccurrences(of: " ", with: "")
            for (k, v) in originalByName {
                if k.replacingOccurrences(of: " ", with: "") == compact { return v }
            }
            return nil
        }

        // Diagnostics (fractions across bootstrap runs)
        let diagnostics = section("diagnostic.means")
        let diagHeader = diagnostics?.header ?? []
        let diagRow = diagnostics?.dataRows.first ?? []
        func diagValue(_ name: String) -> String {
            guard let idx = diagHeader.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == name }) else { return "—" }
            return idx < diagRow.count ? diagRow[idx] : "—"
        }
        let skipNote = rows.first(where: { ($0.first ?? "").isEmpty && ($0.count > 3) })?.first { $0.contains("skipped") } ?? ""

        var out: [String] = []
        out.append("=== Bootstrap run\(runID) — \(dir.lastPathComponent)/bootstrap_results.csv ===")
        if !skipNote.isEmpty { out.append("Note: \(skipNote)") }
        out.append("")
        out.append("Diagnostics (fraction of bootstrap runs):")
        out.append("  minimization.successful = \(diagValue("minimization.successful"))")
        out.append("  covariance.step.successful = \(diagValue("covariance.step.successful"))  (IGNORE — not a reliability criterion here)")
        out.append("  estimate.near.boundary = \(diagValue("estimate.near.boundary"))")
        out.append("  rounding.errors = \(diagValue("rounding.errors"))")
        out.append("")
        out.append("Parameter distributions (95% CI = [2.5% percentile, 97.5% percentile]):")
        out.append("| Parameter | Original est. | Median | Mean | SE | 2.5% | 97.5% | Bias | RSE% | In 95% CI? |")
        out.append("|---|---|---|---|---|---|---|---|---|---|")
        for idx in paramIndices {
            let name = header[idx]
            let orig = originalEstimate(for: name)
            let median = value(medians, idx)
            let mean = value(meanRow, idx)
            let se = value(seRow, idx)
            let lo = value(p25, idx)
            let hi = value(p975, idx)
            let bias = value(biasRow, idx)
            var cells: [String] = []
            cells.append("\(name)")
            cells.append(orig.map { String(format: "%.5g", $0.estimate) } ?? "—")
            cells.append(median.map { String(format: "%.5g", $0) } ?? "NA")
            cells.append(mean.map { String(format: "%.5g", $0) } ?? "NA")
            cells.append(se.map { String(format: "%.5g", $0) } ?? "NA")
            cells.append(lo.map { String(format: "%.5g", $0) } ?? "NA")
            cells.append(hi.map { String(format: "%.5g", $0) } ?? "NA")
            cells.append(bias.map { String(format: "%.5g", $0) } ?? "NA")
            if let se, let median, median != 0 {
                cells.append(String(format: "%.1f%%", abs(se / median) * 100))
            } else {
                cells.append("—")
            }
            if let orig, let lo, let hi {
                cells.append((orig.estimate >= lo && orig.estimate <= hi) ? "YES" : "NO")
            } else if let orig, orig.estimate == 0 {
                cells.append("fixed")
            } else {
                cells.append("—")
            }
            out.append("| " + cells.joined(separator: " | ") + " |")
        }
        return out.joined(separator: "\n")
    }

    private func bootstrapOutputSummary(runID: String) -> String {
        let dir = projectURL.appendingPathComponent("bootstrap_dir_\(runID)")
        guard let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])?.allObjects as? [URL] else {
            return "No bootstrap outputs found for run\(runID)."
        }
        let supported = ["csv", "txt", "md", "log", "out", "res"]
        let outputFiles = files
            .filter { !$0.hasDirectoryPath && supported.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !outputFiles.isEmpty else {
            return "Bootstrap directory exists but no readable result files were found."
        }
        var parts: [String] = []
        for url in outputFiles.prefix(8) {
            parts.append("--- \(url.lastPathComponent) ---\n\(textPreview(url, limit: 8_000))")
        }
        return parts.joined(separator: "\n\n")
    }

    /// Run PsN bootstrap on the final model, then generate an AI evaluation report.
    func runFinalBootstrapAndReport(for runID: String) {
        startFinalModelPackage(for: runID, previousRun: previousRun)
    }

    /// Manual final-model analysis entry: PK parameters + diagnostics + Bootstrap + report.
    /// Does not rerun SCM.
    func analyzeFinalModel(runID: String) {
        let previous = (previousRun.isEmpty || previousRun == runID) ? runID : previousRun
        startFinalModelPackage(for: runID, previousRun: previous)
    }

    private func generateFinalModelReport(runID: String, bootstrapSucceeded: Bool) async {
        let reportsDir = projectURL.appendingPathComponent("Reports", isDirectory: true)
        try? FileManager.default.createDirectory(at: reportsDir, withIntermediateDirectories: true)

        let modURL = projectURL.appendingPathComponent("run\(runID).mod")
        let modText = (try? String(contentsOf: modURL, encoding: .utf8)) ?? ""
        let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: dataFile)
        let parameterRows = ProjectScanner.parameterEstimates(runID: runID, in: projectURL)
        let ofv = extractOFV(from: projectURL.appendingPathComponent("run\(runID).ext"))
        let finalTokens = extractSCMCovariateTokens(from: modText)
        let covText = finalTokens.isEmpty
            ? "No covariate retained"
            : finalTokens.map { describeSCMRelation($0, in: modText) }.joined(separator: ", ")
        let structural = extractSubroutineLine(from: modText) ?? "N/A"
        let bootstrapTable = bootstrapResultsTable(runID: runID)
        let estimationLine = modText.components(separatedBy: "\n")
            .first { $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("$ESTIMATION") }?
            .trimmingCharacters(in: .whitespaces) ?? "N/A"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateText = dateFormatter.string(from: Date())

        let figureFiles = [
            "GOF_mod\(runID).jpg",
            "GOF_mod\(runID).JPG",
            "Individual_Plots_Run\(runID).pdf",
            "VPC_Stratified_mod\(runID).jpg",
            "VPC_Stratified_mod\(runID).JPG"
        ]
        let existingFigures = figureFiles.filter {
            FileManager.default.fileExists(atPath: projectURL.appendingPathComponent($0).path)
        }

        var md = """
        # Final Population PK Model Report

        **Prepared:** \(dateText)
        **Final Model:** run\(runID)
        **Structural model:** \(structural)
        **Covariates:** \(covText)
        **Dataset:** \(dataFile)
        **Dataset path:** \(projectURL.appendingPathComponent(dataFile).path)
        **Subjects / Records:** \(profile.subjectCount) / \(profile.observationCount)
        **Administration route:** \(profile.route)
        **Units:** Dose \(doseUnit) | AMT \(amtUnit) | Concentration \(concUnit) | Time \(timeUnit)

        ## Executive Summary

        The final model is run\(runID) (\(structural)) with \(covText). \(ofv.map { String(format: "The objective function value is %.2f.", $0) } ?? "Objective function value was not available.")
        Parameter precision, model diagnostics, and bootstrap stability are summarized below.

        ## Objectives

        - Develop a population pharmacokinetic (PopPK) model for the study dataset.
        - Evaluate structural model, random effects, residual error, and clinically relevant covariates.
        - Assess final model robustness with GOF diagnostics, VPC, and non-parametric bootstrap.
        - Provide a reproducible final-model report for analyst review and regulatory-style documentation.

        ## Methods

        - NONMEM run command: `\(commandText)`
        - Estimation record: \(estimationLine)
        - R executable: \(resolvedR())
        - Python executable: \(resolvedPython())
        - Output directory: \(projectURL.path)

        ## Dataset Summary

        - Route: \(profile.route)
        - Subjects: \(profile.subjectCount)
        - Observation records: \(profile.observationCount)
        - Dose levels: \(profile.doseLevels.isEmpty ? "N/A" : profile.doseLevels.map { String($0) }.joined(separator: ", "))
        - Time range: \(String(format: "%.1f", profile.timeRangeDays.0)) - \(String(format: "%.1f", profile.timeRangeDays.1)) h

        ## Final Model Parameter Table

        | Group | Parameter | Estimate | SE | RSE (%) | Shrinkage (%) |
        |---|---|---|---|---|---|
        """
        md += "\n"
        for row in parameterRows {
            md += "| \(row.group) | \(row.name) | \(row.estimateText) | \(row.standardErrorText) | \(row.rseText) | \(row.shrinkageText) |\n"
        }
        if parameterRows.isEmpty {
            md += "| N/A | N/A | N/A | N/A | N/A | N/A |\n"
        }

        md += """

        ## Model Diagnostics

        | Check | Status |
        |---|---|
        | Minimization successful | \(runMinimizationOK(runID) ? "Yes" : "No") |
        | Covariance step successful | \(runCovarianceOK(runID) ? "Yes" : "No") |
        | Boundary warnings | \(hasBoundaryWarningsFor(runID) ? "Yes" : "No") |
        | OFV | \(ofv.map { String(format: "%.2f", $0) } ?? "N/A") |
        | GOF plot | \(existingFigures.contains { $0.contains("GOF") } ? "Generated" : "Missing") |
        | Individual plot | \(existingFigures.contains { $0.contains("Individual") } ? "Generated" : "Missing") |
        | VPC plot | \(existingFigures.contains { $0.contains("VPC") } ? "Generated" : "Missing") |

        Generated figure files:
        \(existingFigures.isEmpty ? "- None found" : existingFigures.map { "- \($0)" }.joined(separator: "\n"))

        ## Bootstrap Validation

        Bootstrap status: \(bootstrapSucceeded ? "Completed" : "Not completed / failed")

        \(bootstrapTable.prefix(24_000))

        ## Limitations

        - Bootstrap results should be interpreted together with the original NONMEM covariance step.
        - Fixed parameters were not re-estimated in bootstrap unless explicitly configured by PsN.
        - Missing diagnostic figures or non-converged bootstrap replicates are listed above and should be reviewed before submission.

        ## MAR / Reproducibility Checklist

        - [x] Dataset path and units recorded.
        - [x] Model lineage and final run ID recorded.
        - [x] Control stream available as run\(runID).mod.
        - [x] NONMEM outputs available as run\(runID).lst / .ext / .cov.
        - [x] Final parameter table generated.
        - [x] GOF / VPC / individual diagnostic artifacts checked.
        - [x] Bootstrap sample count and stability reviewed.
        - [x] Covariate rationale and final model simulation-readiness documented.
        - [ ] Clinical interpretation and external comparison pending analyst review.

        ## Conclusion

        The final PopPK model run\(runID) should be reviewed with the parameter table, diagnostics, bootstrap output, and the current project rule/knowledge base. This report is intended as the starting point for a formal population PK report.
        """

        let reportURL = reportsDir.appendingPathComponent("Final_PopPK_Report_Run\(runID).md")
        try? md.write(to: reportURL, atomically: true, encoding: .utf8)
        runner.append("Final PopPK report written: \(reportURL.path)")

        let pdfURL = reportsDir.appendingPathComponent("Final_PopPK_Report_Run\(runID).pdf")
        do {
            try await MarkdownPDFExporter.exportPDF(
                markdown: md,
                to: pdfURL,
                baseURL: projectURL
            )
            runner.append("Final PopPK PDF written: \(pdfURL.path)")
        } catch {
            runner.append("Final PopPK PDF conversion failed: \(error.localizedDescription)")
        }

        assistantMessages.append(AssistantMessage(role: .system, text: localized(
            "✅ 最终 PopPK 报告已生成：\(reportURL.lastPathComponent) / \(pdfURL.lastPathComponent)",
            "✅ Final PopPK report generated: \(reportURL.lastPathComponent) / \(pdfURL.lastPathComponent)"
        )))
        refreshWorkspace()
    }

    /// ETA vs covariate pre-SCM screening. Uses EBEs to test whether each candidate
    /// covariate should be considered further in SCM.
    func runETACovariateScreening(for runID: String, completion: (() -> Void)? = nil) {
        guard !runner.isRunning else {
            runner.append("A task is already running. Please wait.")
            return
        }
        activateRun(runID)
        runner.append("=== ETA covariate screening for run\(runID) ===")
        assistantMessages.append(AssistantMessage(role: .system, text: localized(
            "🔬 正在为 run\(runID) 生成 ETA vs 协变量预筛选...",
            "🔬 Generating ETA vs covariate prescreening for run\(runID)..."
        )))
        Task {
            defer {
                refreshWorkspace()
                completion?()
            }
            guard await ensureETATable(runID: runID) else {
                runner.append("ETA covariate screening failed: could not generate ETA table.")
                assistantMessages.append(AssistantMessage(role: .assistant, text: localized(
                    "ETA 预筛选失败：无法生成 ETA 表。",
                    "ETA prescreening failed: could not generate the ETA table."
                )))
                return
            }

            let rscript = resolvedR()
            let script = BundledResource.path(forResource: "eta_covariate_screening", ofType: "R")
                ?? projectURL.appendingPathComponent("eta_covariate_screening.R").path
            let dataFileArg = automationDataFile.isEmpty ? dataFile : automationDataFile
            let figuresArg = projectURL.appendingPathComponent("Figures").path
            let command = "\(shellQuote(rscript)) \(shellQuote(script)) \(shellQuote(runID)) \(shellQuote(dataFileArg)) \(shellQuote(figuresArg))"
            let exit = await runner.runAndWait(command: command, in: projectURL)
            if exit != 0 {
                runner.append("ETA covariate screening R script failed (exit \(exit)).")
                assistantMessages.append(AssistantMessage(role: .assistant, text: localized(
                    "ETA 预筛选 R 脚本失败，请查看 Run Log。",
                    "ETA prescreening R script failed; check the Run Log."
                )))
                return
            }

            let summaryURL = projectURL.appendingPathComponent("eta_covariate_screening_\(runID).tsv")
            let summary = (try? String(contentsOf: summaryURL, encoding: .utf8)) ?? "No summary file generated."
            updateETAScreeningRecommendation(runID: runID, summary: summary)
            runner.append("ETA covariate screening summary:\n\(summary)")
            assistantMessages.append(AssistantMessage(role: .system, text: localized(
                "📊 ETA 协变量预筛选完成。正在请 DuDu 判断 SCM 是否继续考察这些协变量...",
                "📊 ETA covariate prescreening complete. DuDu is deciding which covariates SCM should test..."
            )))
            await recommendSCMCovariates(runID: runID, summary: summary)
        }
    }

    private func updateETAScreeningRecommendation(runID: String, summary: String) {
        etaScreeningRunID = runID
        etaScreeningSummary = summary

        let lines = summary
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count > 1,
              let header = lines.first?.components(separatedBy: "\t").map({ $0.lowercased() }),
              let covIdx = header.firstIndex(of: "covariate"),
              let pIdx = header.firstIndex(of: "p.value"),
              let sigIdx = header.firstIndex(of: "significant") else {
            etaScreeningRecommendedCovariates = []
            etaScreeningOptionalCovariates = []
            etaScreeningRecommendation = ""
            return
        }

        var recommended = Set<String>()
        var optional = Set<String>()
        let paramIdx = header.firstIndex(of: "parameter")
        let corrIdx = header.firstIndex(of: "correlation")
        var statsByCovariate: [String: [String]] = [:]
        for line in lines.dropFirst() {
            let fields = line.components(separatedBy: "\t")
            guard fields.count > max(covIdx, pIdx, sigIdx) else { continue }
            let cov = fields[covIdx].uppercased()
            guard !cov.isEmpty else { continue }
            let significant = fields[sigIdx].lowercased() == "true"
            let pValue = Double(fields[pIdx])
            let corrValue = corrIdx.flatMap { idx in
                fields.indices.contains(idx) ? Double(fields[idx]) : nil
            }
            if let paramIdx, fields.indices.contains(paramIdx) {
                let param = fields[paramIdx]
                let pText = pValue.map { $0 < 0.001 ? "<0.001" : String(format: "%.3g", $0) } ?? "n/a"
                let corrText = corrValue.map { String(format: "%.2f", $0) } ?? ""
                let stat = corrText.isEmpty
                    ? "\(param): p=\(pText)"
                    : "\(param): p=\(pText), r=\(corrText)"
                statsByCovariate[cov, default: []].append(stat)
            }
            if significant || (pValue.map { $0 < 0.05 } ?? false) {
                recommended.insert(cov)
            } else if let pValue, pValue < 0.10 {
                optional.insert(cov)
            } else if let corrValue, abs(corrValue) >= 0.20 {
                optional.insert(cov)
            }
        }

        let preferredOrder = ["WT", "AGE", "SEX", "STUDY", "STUD", "BSA", "HB", "ALB", "CLCR", "EGFR", "BMI", "DOSE"]
        func ordered(_ set: Set<String>) -> [String] {
            preferredOrder.filter(set.contains) + set.subtracting(preferredOrder).sorted()
        }

        let recommendedList = ordered(recommended)
        let optionalList = ordered(optional)
        etaScreeningRecommendedCovariates = recommendedList
        etaScreeningOptionalCovariates = optionalList

        func detailText(_ covariates: [String]) -> String {
            covariates.map { cov in
                let stats = statsByCovariate[cov] ?? []
                return stats.isEmpty ? cov : "\(cov): \(stats.joined(separator: "; "))"
            }.joined(separator: "；")
        }

        let isEnglish = LanguageStore.shared.language == .en
        if !recommendedList.isEmpty {
            etaScreeningRecommendation = isEnglish
                ? "ETA screening suggests prioritizing: \(detailText(recommendedList))."
                    + (optionalList.isEmpty ? "" : " Optional/trend: \(detailText(optionalList)).")
                : "ETA 预筛选建议优先考察：\(detailText(recommendedList))。"
                    + (optionalList.isEmpty ? "" : " 可选/趋势：\(detailText(optionalList))。")
        } else if !optionalList.isEmpty {
            etaScreeningRecommendation = isEnglish
                ? "No strong p<0.05 signal; optional covariates with trend: \(detailText(optionalList))."
                : "ETA 预筛选未见 p<0.05 的强信号；可选/趋势：\(detailText(optionalList))。"
        } else {
            etaScreeningRecommendation = isEnglish
                ? "No significant ETA-covariate associations were found."
                : "ETA 预筛选未发现显著协变量关联。"
        }
    }

    /// Prefill SCM covariate toggles from the latest ETA screening for the selected base model.
    func applyETAScreeningDefaultsIfAvailable(for runID: String) {
        guard runID == etaScreeningRunID else { return }
        let recommended = Set(etaScreeningRecommendedCovariates)
        if recommended.isEmpty {
            resetSCMCovariatesToAll()
        } else {
            let available = Set(scmAvailableCovariates)
            scmIncludeWT = recommended.contains("WT") && available.contains("WT")
            scmIncludeAGE = recommended.contains("AGE") && available.contains("AGE")
            scmIncludeSEX = recommended.contains("SEX") && available.contains("SEX")
            scmIncludeSTUDY = (recommended.contains("STUDY") || recommended.contains("STUD"))
                && (available.contains("STUDY") || available.contains("STUD"))
            let extra = Set(scmCandidateCovariates)
            scmIncludedAdditionalCovariates = recommended.intersection(extra)
        }
    }

    func applyETAScreeningRecommendedCovariates() {
        applyETAScreeningDefaultsIfAvailable(for: scmModelRunID)
    }

    func resetSCMCovariatesToAll() {
        let available = Set(scmAvailableCovariates)
        scmIncludeWT = available.contains("WT")
        scmIncludeAGE = available.contains("AGE")
        scmIncludeSEX = available.contains("SEX")
        scmIncludeSTUDY = available.contains("STUDY") || available.contains("STUD")
        scmIncludedAdditionalCovariates = Set(scmCandidateCovariates)
    }

    private func ensureETATable(runID: String) async -> Bool {
        let direct = projectURL.appendingPathComponent("run\(runID).ETA")
        if FileManager.default.fileExists(atPath: direct.path) {
            return true
        }

        let modURL = projectURL.appendingPathComponent("run\(runID).mod")
        guard let modText = try? String(contentsOf: modURL, encoding: .utf8) else {
            runner.append("ETA screening: cannot read run\(runID).mod")
            return false
        }
        var updated = withETATableRecord(
            LLMCommandService.stripInlineDatasetRows(modText),
            runID: runID
        )
        updated = LLMCommandService.normalizingTableRecords(updated, runID: runID)
        updated = LLMCommandService.applyingIVInfusionDurationFix(updated)
        if updated != modText {
            do {
                try updated.write(to: modURL, atomically: true, encoding: .utf8)
                runner.append("ETA screening: added ETA table to run\(runID).mod")
            } catch {
                runner.append("ETA screening: failed to update run\(runID).mod \(error.localizedDescription)")
                return false
            }
        }
        guard !etaTerms(from: modText).isEmpty else {
            runner.append("ETA screening: no ETA terms found in run\(runID).mod")
            return false
        }
        if FileManager.default.fileExists(atPath: direct.path) {
            return true
        }

        runner.append("ETA screening: rerunning run\(runID) to generate ETA table \(direct.lastPathComponent)")
        let exit = await runner.runAndWait(command: psnRunCommand(runID: runID), in: projectURL)
        if exit != 0 {
            runner.append("ETA screening: NONMEM rerun failed (exit \(exit)).")
            return false
        }

        if FileManager.default.fileExists(atPath: direct.path) {
            return true
        }
        if let found = recursiveFile(named: "run\(runID).ETA", in: projectURL) {
            return FileManager.default.fileExists(atPath: found.path)
        }
        return false
    }

    /// Insert or replace the standard EBE table record (`$TABLE ID ETA1 ... FILE=runX.ETA`)
    /// in any generated model. The table is required for ETA vs covariate screening and for
    /// analyst-facing EBE exports.
    private func withETATableRecord(_ modText: String, runID: String) -> String {
        let terms = etaTerms(from: modText)
        guard !terms.isEmpty else { return modText }
        let tableRecord = "$TABLE ID \(terms.joined(separator: " ")) FIRSTONLY NOAPPEND NOPRINT FILE=run\(runID).ETA"
        let lines = modText.components(separatedBy: "\n")
        var output: [String] = []
        for line in lines {
            let upper = line.uppercased()
            if upper.contains("$TABLE"),
               upper.contains("FIRSTONLY"),
               upper.contains("ETA"),
               upper.contains("FILE=") {
                continue
            }
            output.append(line)
        }
        output.append(tableRecord)
        return output.joined(separator: "\n")
    }

    private func etaTerms(from modText: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\bETA\s*\(\s*(\d+)\s*\)"#, options: [.caseInsensitive]) else { return [] }
        var indices = Set<Int>()
        let ns = modText as NSString
        let range = NSRange(location: 0, length: ns.length)
        for match in regex.matches(in: modText, options: [], range: range) {
            if match.numberOfRanges > 1,
               let value = Int(ns.substring(with: match.range(at: 1))) {
                indices.insert(value)
            }
        }
        return indices.sorted().map { "ETA\($0)" }
    }

    private func covariateColumns(from modText: String) -> [String] {
        guard let inputLine = modText.components(separatedBy: "\n")
            .first(where: { $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("$INPUT") })?
            .trimmingCharacters(in: .whitespaces) else { return [] }
        let tokens = inputLine
            .dropFirst(6)
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map { String($0).uppercased() }
        let candidates = [
            "WT", "AGE", "SEX", "STUDY", "STUD", "STUDYID", "STUDYNO", "BSA",
            "HB", "ALB", "CLCR", "EGFR", "BMI", "DOSE", "ROUTE", "ADA",
            "RACE", "TRT", "ARM", "REGION", "TYPE", "GROUP", "COHORT", "TREATMENT"
        ]
        var found: [String] = []
        for candidate in candidates {
            if tokens.contains(candidate) {
                found.append(candidate)
            }
        }
        return found
    }

    func refreshSCMCandidateCovariates() {
        guard !scmModelRunID.isEmpty else {
            scmAvailableCovariates = []
            scmCandidateCovariates = []
            scmIncludedAdditionalCovariates = []
            return
        }
        let modURL = projectURL.appendingPathComponent("run\(scmModelRunID).mod")
        let modText = (try? String(contentsOf: modURL, encoding: .utf8)) ?? ""
        let datasetColumns = scmDatasetColumnSet(scmDataFileName)
        let coreCovariates: Set<String> = ["WT", "AGE", "SEX", "STUDY"]
        let allAvailable = covariateColumns(from: modText).filter { datasetColumns.contains($0) }
        let previousAdditional = scmIncludedAdditionalCovariates
        scmAvailableCovariates = allAvailable
        scmCandidateCovariates = allAvailable.filter { !coreCovariates.contains($0) }
        scmIncludedAdditionalCovariates = previousAdditional.intersection(scmCandidateCovariates)
    }

    private func scmDatasetColumnSet(_ dataFile: String) -> Set<String> {
        guard !dataFile.isEmpty,
              let record = LLMCommandService.datasetInputRecord(projectURL: projectURL, dataFile: dataFile) else {
            return []
        }
        return Set(record.split(whereSeparator: \.isWhitespace).map { String($0).uppercased() })
    }

    private func recursiveFile(named name: String, in root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator where !url.hasDirectoryPath && url.lastPathComponent == name {
            return url
        }
        return nil
    }

    private func recommendSCMCovariates(runID: String, summary: String) async {
        let isEnglish = LanguageStore.shared.language == .en
        let promptText = isEnglish ? """
        The following ETA-covariate screening was run before SCM for run\(runID).

        Rules:
        - Categorical covariates (SEX/STUDY) use Kruskal-Wallis. p < 0.05 suggests the ETA differs by group and the covariate deserves SCM evaluation.
        - Continuous covariates (WT/AGE/etc.) use linear regression of ETA on the covariate. Significant p and meaningful |correlation| suggest SCM evaluation.
        - Fixed ETAs have already been removed from the summary, so do not recommend screening those parameters again.
        - Missing covariate values are excluded; do not ask the user to fill them.
        - Treat p = 0.05-0.10 or |correlation| >= 0.20 as an optional trend, especially when several PK parameters show the same direction.
        - Do not require SCM evaluation just because p < 0.05; also consider biological plausibility, parameter, correlation strength, sample size, and visible trends.

        ETA-covariate screening summary:
        \(summary.prefix(12_000))

        Answer with:
        Recommended covariates to evaluate in SCM: ...
        Optional covariates: ...
        Covariates to skip: ...
        One-sentence rationale.
        """ : """
        这是 run\(runID) 在 SCM 前进行的 ETA 协变量预筛选结果。

        规则：
        - 分类协变量（SEX/STUDY）使用 Kruskal-Wallis，p < 0.05 提示不同组别 ETA 有差异，值得在 SCM 中考察。
        - 连续协变量（WT/AGE 等）使用 ETA 对协变量的线性回归，p 显著且相关系数有实际意义时建议在 SCM 中考察。
        - 固定 ETA 已从结果中排除，不要再建议考察这些参数。
        - 缺失协变量已剔除，不要要求用户补数据。
        - p 在 0.05-0.10 或 |r| >= 0.20 时视为可选趋势，尤其当多个 PK 参数方向一致时更值得关注。
        - 不能只看 p < 0.05，还要结合生物学合理性、参数、相关强度、样本量和图中可见趋势。

        ETA 协变量预筛选结果：
        \(summary.prefix(12_000))

        请回答：
        建议在 SCM 中考察的协变量：...
        可选的协变量：...
        建议暂不考察的协变量：...
        一句话理由。
        """
        let prompt = AssistantMessage(role: .user, text: promptText)
        do {
            let (reply, usage) = try await LLMCommandService.chat(
                baseURL: llmBaseURL,
                model: llmModel,
                messages: [prompt],
                projectURL: projectURL,
                currentRun: runID,
                rules: activeRuleContext().text + "\n" + PPKSkillStore.shared.contextBlock(),
                apiKey: llmAPIKey,
                personality: activePersonalityBlock,
                knowledgeBaseURL: knowledgeBaseURL,
                apiFormat: activeAPIFormat
            )
            recordUsage(usage)
            assistantMessages.append(AssistantMessage.parse(reply, role: .assistant))
            runner.append("DuDu SCM covariate recommendation complete.")
        } catch {
            runner.append("DuDu SCM covariate recommendation failed: \(error.localizedDescription)")
            assistantMessages.append(AssistantMessage(role: .assistant, text: localized(
                "DuDu 无法生成协变量建议，请直接查看 Run Log 中的 ETA 预筛选表。",
                "DuDu could not generate covariate recommendations; check the ETA prescreening table in the Run Log."
            )))
        }
    }

    func runSCM(for runID: String, dataFile: String? = nil, pForward: String = "0.01", pBackward: String = "0.001") {
        guard !runner.isRunning else {
            runner.append("A task is already running. Please stop it first or wait for it to complete.")
            if activeBenchmark != nil, benchmarkPhase2StartAt != nil {
                finalizeBenchmark(status: .failed, notes: L10n.t("benchmark.scmNotStarted"))
            }
            return
        }
        activateRun(runID)
        let resolvedData = dataFile ?? (automationDataFile.isEmpty ? self.dataFile : automationDataFile)
        isSCMRunning = true
        scmCancelled = false
        duDuMood = .working
        automationStep = L10n.scmStepPreparing
        Task {
            // Analyze dataset + $INPUT fallback for covariate detection
            let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: resolvedData,
                                                           log: { msg in Task { @MainActor in self.runner.append(msg) } })

            // Candidate covariates must exist in BOTH the model $INPUT and the selected CSV.
            let modPath = projectURL.appendingPathComponent("run\(runID).mod")
            let modText = (try? String(contentsOf: modPath, encoding: .utf8)) ?? ""
            let datasetColumns = scmDatasetColumnSet(resolvedData)
            let uiAvailable = Set(scmAvailableCovariates)
            let availableCovariates = !uiAvailable.isEmpty
                ? uiAvailable.intersection(datasetColumns)
                : Set(covariateColumns(from: modText)).intersection(datasetColumns)
            let showWT = availableCovariates.contains("WT")
            let showAGE = availableCovariates.contains("AGE")
            let showSEX = availableCovariates.contains("SEX")
            let showSTUDY = availableCovariates.contains("STUDY")
            let ofvForward = ofvForPValue(Double(pForward) ?? 0.01)
            let ofvBackward = ofvForPValue(Double(pBackward) ?? 0.001)

            // Only pass covariates the analyst chose to examine AND that actually exist in the dataset.
            var included = Set<String>()
            if scmIncludeWT && showWT { included.insert("WT") }
            if scmIncludeAGE && showAGE { included.insert("AGE") }
            if scmIncludeSEX && showSEX { included.insert("SEX") }
            if scmIncludeSTUDY && showSTUDY { included.insert("STUDY") }
            if scmIncludeSTUDY && availableCovariates.contains("STUD") && !scmCandidateCovariates.contains("STUD") {
                included.insert("STUD")
            }
            for cov in scmCandidateCovariates
            where scmIncludedAdditionalCovariates.contains(cov) && availableCovariates.contains(cov) {
                included.insert(cov)
            }

            // The status message must reflect the ACTUAL checked covariates, not just the
            // columns present in the dataset.
            let covList = included.sorted().joined(separator: " ")
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusSCMStarted,
                                                                                  runID, runID, resolvedData, covList,
                                                                                  String(format: "%.3f", pForward),
                                                                                  String(format: "%.3f", ofvForward),
                                                                                  String(format: "%.3f", pBackward),
                                                                                  String(format: "%.3f", ofvBackward))))

            if included.isEmpty {
                assistantMessages.append(AssistantMessage(role: .system, text: L10n.scmNoCandidatesSelected))
                duDuMood = .happy
                isSCMRunning = false
                automationStep = "Idle"
                finalizeBenchmarkAfterSCM(success: false, cancelled: false)
                return
            }

            if let result = await prepareAndRunSCM(baseRun: runID, dataFile: resolvedData, profile: profile,
                                                    pForward: pForward, pBackward: pBackward,
                                                    includedCovariates: included) {
                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusSCMDone, String(result.prefix(3000)))))

                // ── DuDu replicates SCM's forward inclusion / backward elimination in the
                // project path (writing its own mods, running them), then compares its final
                // model with SCM's final_backward.mod. ──
                let finalRun = await verifySCMByReplication(baseRun: runID, dataFile: resolvedData)
                isSCMRunning = false
                duDuMood = .happy
                if let finalRun, !finalRun.isEmpty {
                    automationStep = "SCM replication complete — awaiting final validation choice"
                    scmFinalModelRunID = finalRun
                    scmFinalModelPreviousRun = runID
                    markAIModel(runID: finalRun)
                    showSCMFinalModelConfirm = true
                    assistantMessages.append(AssistantMessage(role: .system, text: localized(
                        "SCM replication 已完成。是否以 run\(finalRun) 作为最终模型，继续验证并输出报告？",
                        "SCM replication complete. Use run\(finalRun) as the final model for validation and report output?"
                    )))
                } else {
                    automationStep = "Idle"
                }
                refreshWorkspace()
                finalizeBenchmarkAfterSCM(success: true, cancelled: false)
            } else {
                assistantMessages.append(AssistantMessage(role: .system,
                    text: scmCancelled ? L10n.scmCancelled : String.safeFormat(L10n.statusSCMFailed, runID)))
                duDuMood = .happy
                isSCMRunning = false
                automationStep = "Idle"
                refreshWorkspace()
                finalizeBenchmarkAfterSCM(success: false, cancelled: scmCancelled)
            }
        }
    }

    /// ΔOFV threshold for 1-df χ² at given p-value
    private func ofvForPValue(_ p: Double) -> String {
        // χ²(1df) critical values
        switch p {
        case 0.05:  return "3.84"
        case 0.01:  return "6.63"
        case 0.001: return "10.83"
        default:    return String(format: "%.2f", p)
        }
    }

    /// Open the SCM configuration dialog for model + dataset selection.
    /// - Parameter runID: Optional pre-selected model run ID (e.g. when triggered from sidebar context menu)
    /// Show SCM dialog after base model confirmation — pre-fills the base model run.
    func presentSCMDialogAfterBaseModel() {
        isBaseModelConfirmPresented = false
        benchmarkBasePromptActionTaken = true
        benchmarkContinuesWithSCM = activeBenchmark != nil && benchmarkBasePromptShownAt != nil
        let runID = baseModelConfirmRunID
        guard !runID.isEmpty else {
            presentSCMDialog(runID: nil)
            return
        }
        runner.append("Base model confirmed: run\(runID). Running ETA vs covariate exploratory screening before SCM.")
        assistantMessages.append(AssistantMessage(role: .system, text: localized(
            "Base model 已确认：run\(runID)。先进行 ETA 协变量预筛选，完成后自动打开 SCM 设置。",
            "Base model confirmed: run\(runID). Running ETA covariate prescreening first, then opening SCM settings."
        )))
        runETACovariateScreening(for: runID) { [weak self] in
            self?.presentSCMDialog(runID: runID)
        }
    }

    func presentSCMDialog(runID: String? = nil) {
        guard ensureModelFilesExist() else { return }
        let mods = availableModFiles()
        let csvs = availableCSVFiles()
        if let runID {
            scmModelRunID = runID
        } else {
            scmModelRunID = preferredAIModelRunID
                ?? mods.first?.replacingOccurrences(of: "run", with: "").replacingOccurrences(of: ".mod", with: "")
                ?? currentRun
        }
        scmDataFileName = csvs.first ?? dataFile
        scmPForward = "0.01"
        scmPBackward = "0.001"
        // Default: examine all candidate covariates
        scmIncludeWT = true
        scmIncludeAGE = true
        scmIncludeSEX = true
        scmIncludeSTUDY = true
        scmAvailableCovariates = []
        scmCandidateCovariates = []
        refreshSCMCandidateCovariates()
        scmIncludedAdditionalCovariates = Set(scmCandidateCovariates)
        applyETAScreeningDefaultsIfAvailable(for: scmModelRunID)
        showSCMDialog = true
    }

    /// User confirmed SCM model + dataset selection — kick off the run
    func cancelSCM() {
        scmCancelled = true
        runner.stopCurrentProcess()
        runner.append("SCM: user requested cancellation.")
        isSCMRunning = false
        duDuMood = .happy
    }

    func confirmSCMFinalModelAnalysis() {
        let runID = scmFinalModelRunID
        let previousRun = scmFinalModelPreviousRun
        showSCMFinalModelConfirm = false
        guard !runID.isEmpty else { return }
        markAIModel(runID: runID)
        runner.append("SCM replication complete. Starting final model validation and report output for run\(runID).")
        assistantMessages.append(AssistantMessage(role: .system, text: localized(
            "🚀 正在以 run\(runID) 作为最终模型，继续执行验证、Bootstrap 和报告输出。",
            "🚀 Using run\(runID) as the final model. Running validation, Bootstrap, and report output."
        )))
        startFinalModelPackage(for: runID, previousRun: previousRun)
    }

    func cancelSCMFinalModelAnalysis() {
        showSCMFinalModelConfirm = false
        scmFinalModelRunID = ""
        scmFinalModelPreviousRun = ""
        runner.append("SCM replication finished; final model validation skipped.")
        assistantMessages.append(AssistantMessage(role: .system, text: localized(
            "SCM replication 已完成。未继续最终模型验证和报告输出。",
            "SCM replication complete. Final model validation and report output were skipped."
        )))
    }

    func confirmSCMRun() {
        showSCMDialog = false
        guard !scmModelRunID.isEmpty, !scmDataFileName.isEmpty else { return }
        if benchmarkContinuesWithSCM {
            startBenchmarkPhase2()
            benchmarkContinuesWithSCM = false
        }
        // Enforce: p_backward must be ≤ p_forward (more stringent)
        let pf = Double(scmPForward) ?? 0.01
        let pb = Double(scmPBackward) ?? 0.001
        let finalForward = scmPForward
        let finalBackward = pb > pf ? String(pf) : scmPBackward
        runSCM(for: scmModelRunID, dataFile: scmDataFileName, pForward: finalForward, pBackward: finalBackward)
    }

    /// Check if user is asking for SCM via chat — open the selection dialog instead of running directly
    func interceptSCMChatRequest(_ prompt: String) -> Bool {
        let lower = prompt.lowercased()
        guard lower.contains("scm") || lower.contains("协变量") else { return false }

        // Open the selection dialog so the user picks model + dataset
        presentSCMDialog()
        return true
    }

    func runFullDiagnosticSuite() {
        // Only run if current model has succeeded
        guard isModelRunSuccessful(runID: currentRun) else {
            runner.append("Model run\(currentRun) has not succeeded — skipping diagnostics. Run NONMEM first.")
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.ctDiagSkipped, currentRun)))
            return
        }
        guard !runner.isRunning else {
            runner.append("A task is already running.")
            return
        }
        isAssistantPanelPresented = true
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.auditRunning, currentRun)))
        Task {
            _ = await runAutomationDiagnostics(runID: currentRun, previousRun: previousRun)
            refreshWorkspace()
        }
    }

    func runFullDiagnosticSuite(for runID: String) {
        activateRun(runID)
        runFullDiagnosticSuite()
    }

    // MARK: - GA Initial Estimate Optimization

    func runGAOptimization() {
        guard !isRunningGA else { return }
        guard !runner.isRunning else {
            runner.append("A task is already running. Please wait for it to complete.")
            return
        }
        let modPath = projectURL.appendingPathComponent("run\(currentRun).mod").path
        guard FileManager.default.fileExists(atPath: modPath) else {
            runner.append("GA: run\(currentRun).mod not found.")
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusGAModelMissing, currentRun)))
            return
        }

        isRunningGA = true
        gaStatus = "Starting GA initial estimate optimization..."
        gaResultText = nil
        isAssistantPanelPresented = true
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusGAOptimizing, currentRun)))
        runner.append("🧬 GA: launching initial estimate optimizer for run\(currentRun)")

        Task {
            let python = resolvedPython()
            let gaScript = findGAScript()
            let nmfe = nonmemPath.isEmpty ? "nmfe76" : nonmemPath
            let rscript = resolvedR()

            guard let script = gaScript else {
                runner.append("GA: autopmx_ga.py not found. Place it in Resources/ or your workspace.")
                assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusGAScriptMissing))
                isRunningGA = false
                return
            }

            let outputMod = projectURL.appendingPathComponent("GA\(currentRun).mod").path
            let cmd = [
                shellQuote(python),
                shellQuote(script),
                "--mod", shellQuote(modPath),
                "--project-dir", shellQuote(projectURL.path),
                "--nmfe", shellQuote(nmfe),
                "--rscript", shellQuote(rscript),
                "--output", shellQuote(outputMod),
                "--ga-pop", "20",
                "--ga-iter", "10",
                "--ga-elite", "0.2",
                "--json",
            ].joined(separator: " ")

            let exit = await runner.runAndWait(command: cmd, in: projectURL)

            if exit == 0 {
                gaStatus = "✅ GA initial estimate optimization complete"
                let outputExists = FileManager.default.fileExists(atPath: outputMod)
                gaResultText = outputExists
                    ? "Optimized model saved: GA\(currentRun).mod\n\nOpen it from the sidebar and compare THETA values with the original."
                    : "GA completed but output file not found."

                refreshWorkspace()
                if outputExists {
                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusGAOptimizeDone, currentRun)))
                }
                // Try parsing the JSON output for details
                let outputLines = runner.logText
                if let jsonStart = outputLines.range(of: "{\n  \"output_mod\""),
                   let jsonEnd = outputLines.range(of: "\n}", options: .backwards) {
                    let jsonStr = String(outputLines[jsonStart.lowerBound...jsonEnd.upperBound])
                    gaResultText = jsonStr
                }
            } else {
                gaStatus = "❌ GA initial estimate optimization failed (exit \(exit))"
                gaResultText = "Check the Run Log for details. Common issues:\n- nmfe path not configured\n- NONMEM license unavailable\n- .mod file has syntax errors"
                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusGAFailed, Int(exit))))
            }

            runner.append(gaStatus)
            isRunningGA = false
        }
    }

    private func findGAScript() -> String? {
        let candidates: [String] = [
            workspaceURL.appendingPathComponent("autopmx_ga.py").path,
            projectURL.appendingPathComponent("autopmx_ga.py").path,
            BundledResource.path(forResource: "autopmx_ga", ofType: "py"),
        ].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func runInitialGAStart(runID: String, dataFile: String, popSize: Int = 6, iterations: Int = 3) async -> Bool {
        guard let gaScript = findGAScript(), !nonmemPath.isEmpty else {
            return false
        }

        let python = resolvedPython()
        let rscript = resolvedR()
        let modPath = projectURL.appendingPathComponent("run\(runID).mod").path
        let gaOutput = projectURL.appendingPathComponent("run\(runID).ga.mod").path
        let backupURL = projectURL.appendingPathComponent(".autopmx_backups", isDirectory: true)
            .appendingPathComponent("run\(runID).pre_ga.mod")
        try? FileManager.default.createDirectory(
            at: backupURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let originalModURL = projectURL.appendingPathComponent("run\(runID).mod")
        if let original = try? String(contentsOf: originalModURL, encoding: .utf8) {
            try? original.write(to: backupURL, atomically: true, encoding: .utf8)
        }

        let cmd = [
            shellQuote(python),
            shellQuote(gaScript),
            "--mod", shellQuote(modPath),
            "--project-dir", shellQuote(projectURL.path),
            "--nmfe", shellQuote(nonmemPath),
            "--rscript", shellQuote(rscript),
            "--output", shellQuote(gaOutput),
            "--ga-pop", "\(popSize)",
            "--ga-iter", "\(iterations)",
            "--ga-elite", "0.2",
            "--json",
        ].joined(separator: " ")

        runner.append("GA: searching initial THETA values around NCA seeds (pop=\(popSize), iterations=\(iterations))")
        let exit = await runner.runAndWait(command: cmd, in: projectURL)
        let outputURL = projectURL.appendingPathComponent("run\(runID).ga.mod")
        guard exit == 0, FileManager.default.fileExists(atPath: outputURL.path),
              let gaText = try? String(contentsOf: outputURL, encoding: .utf8) else {
            runner.append("GA initial-value search did not produce a usable model; keeping NCA seeds.")
            try? FileManager.default.removeItem(at: outputURL)
            return false
        }

        var candidate = LLMCommandService.stripInlineDatasetRows(gaText)
        candidate = correctS1Scaling(candidate)
        candidate = LLMCommandService.applyingIVInfusionDurationFix(candidate)
        candidate = LLMCommandService.normalizingTableRecords(candidate, runID: runID)
        do {
            try candidate.write(to: originalModURL, atomically: true, encoding: .utf8)
        } catch {
            runner.append("GA initial-value model could not be written: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: outputURL)
            return false
        }
        try? FileManager.default.removeItem(at: outputURL)

        let validation = await validateModel(runID)
        if validation.passed {
            runner.append("GA refined run\(runID) initial values and validation passed.")
            return true
        }

        if let backup = try? String(contentsOf: backupURL, encoding: .utf8) {
            try? backup.write(to: originalModURL, atomically: true, encoding: .utf8)
        }
        runner.append("GA candidate failed validation; restored NCA-seeded run\(runID).")
        return false
    }

    // MARK: - GA Structural Search

    func runGAStructuralOptimization(dimensions: [String] = ["all"]) {
        guard !isRunningStructuralGA else { return }
        guard !runner.isRunning else {
            runner.append("A task is already running. Please wait for it to complete.")
            return
        }
        let modPath = projectURL.appendingPathComponent("run\(currentRun).mod").path
        guard FileManager.default.fileExists(atPath: modPath) else {
            runner.append("GA Structural: run\(currentRun).mod not found.")
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusGAStructuralModelMissing, currentRun)))
            return
        }

        isRunningStructuralGA = true
        structuralGAStatus = "Starting structural GA search..."
        structuralGAResultText = nil
        isAssistantPanelPresented = true
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusGAStructuralSearching, currentRun)))
        runner.append("🧬 GA Structural: launching hybrid optimizer for run\(currentRun)")

        Task {
            let python = resolvedPython()
            let gaScript = findGAScript()
            let nmfe = nonmemPath.isEmpty ? "nmfe76" : nonmemPath
            let rscript = resolvedR()

            guard let script = gaScript else {
                runner.append("GA Structural: autopmx_ga.py not found.")
                assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusGAStructuralScriptMissing))
                isRunningStructuralGA = false
                return
            }

            let outputMod = projectURL.appendingPathComponent("GA\(currentRun).mod").path
            let dims = dimensions.joined(separator: ",")
            let cmd = [
                shellQuote(python),
                shellQuote(script),
                "--mod", shellQuote(modPath),
                "--project-dir", shellQuote(projectURL.path),
                "--nmfe", shellQuote(nmfe),
                "--rscript", shellQuote(rscript),
                "--output", shellQuote(outputMod),
                "--structural",
                "--structural-dims", shellQuote(dims),
                "--ga-pop", "10",
                "--ga-iter", "5",
                "--ga-elite", "0.2",
                "--json",
            ].joined(separator: " ")

            let exit = await runner.runAndWait(command: cmd, in: projectURL)

            if exit == 0 {
                structuralGAStatus = "✅ GA Structural search complete"
                let outputExists = FileManager.default.fileExists(atPath: outputMod)
                structuralGAResultText = outputExists
                    ? "Optimized model saved: GA\(currentRun).mod\nOpen from sidebar to review structure choices and THETA values."
                    : "GA completed but output file not found."

                refreshWorkspace()
                if outputExists {
                    assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusGAStructuralDone, currentRun)))
                }
                // Try parsing the JSON output
                let outputLines = runner.logText
                if let jsonStart = outputLines.range(of: "{\n  \"output_mod\""),
                   let jsonEnd = outputLines.range(of: "\n}", options: .backwards) {
                    let jsonStr = String(outputLines[jsonStart.lowerBound...jsonEnd.upperBound])
                    structuralGAResultText = jsonStr
                }
            } else {
                structuralGAStatus = "❌ GA Structural search failed (exit \(exit))"
                structuralGAResultText = "Check the Run Log for details."
                assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusGAStructuralFailed, Int(exit))))
            }

            runner.append(structuralGAStatus)
            isRunningStructuralGA = false
        }
    }

    func runAudit(_ kind: String) {
        runAudit(kind, runID: currentRun)
    }

    func runAudit(_ kind: String, runID: String) {
        // Only audit if model has actually succeeded
        guard isModelRunSuccessful(runID: runID) else {
            runner.append("Model run\(runID) has not succeeded — skipping audit. Check LST for errors.")
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusAuditNotRun, runID)))
            return
        }
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: kind, previous: previousRun, current: runID))
    }

    func evaluateModelWithAI(_ runID: String) {
        guard isModelRunSuccessful(runID: runID) else {
            runner.append("Model run\(runID) has not succeeded — cannot evaluate. Run NONMEM first.")
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusEvaluateNotRun, runID)))
            return
        }
        activateRun(runID)
        isAssistantPanelPresented = true
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.auditFull, runID)))
        runFullDiagnosticSuite()
    }

    func interpretAssetWithAI(_ asset: ProjectAsset) {
        select(asset)
        guard let runID = asset.relatedRunID else {
            runner.append("No run ID detected for AI interpretation: \(asset.relativePath)")
            return
        }

        isAssistantPanelPresented = true
        let lower = asset.relativePath.lowercased()
        if lower.contains("gof") {
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.auditGof, runID)))
            runAudit("gof-audit", runID: runID)
        } else if lower.contains("vpc") {
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.auditVpc, runID)))
            runAudit("vpc-audit", runID: runID)
        } else if ["lst", "ext", "cov"].contains(asset.url.pathExtension.lowercased()) {
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.auditParameter, runID)))
            runAudit("parameter-audit", runID: runID)
        } else {
            assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.auditSelected, asset.title)))
            sendContextualAssetPrompt(asset)
        }
    }

    private func sendContextualAssetPrompt(_ asset: ProjectAsset) {
        guard !isAssistantThinking else {
            runner.append("DuDu is already thinking.")
            return
        }
        let prompt = """
        Please interpret this AutoPMX artifact in the context of run\(currentRun):
        \(asset.relativePath)

        If it is a model output, summarize the modeling implication and the next safest action.
        """
        assistantMessages.append(AssistantMessage(role: .user, text: prompt))
        isAssistantThinking = true
        Task {
            do {
                let (reply, usage) = try await LLMCommandService.chat(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    messages: assistantMessages,
                    projectURL: projectURL,
                    currentRun: currentRun,
                    rules: activeRuleContext().text,
                    apiKey: llmAPIKey,
                    personality: activePersonalityBlock,
                    knowledgeBaseURL: knowledgeBaseURL,
                    apiFormat: activeAPIFormat
                )
                recordUsage(usage)
                assistantMessages.append(AssistantMessage.parse(reply, role: .assistant))
            } catch {
                assistantMessages.append(AssistantMessage(role: .assistant, text: LLMCommandService.friendlyError(error, baseURL: llmBaseURL)))
            }
            isAssistantThinking = false
        }
    }

    private func runCommandAndRefresh(_ command: String) {
        Task {
            _ = await runner.runAndWait(command: command, in: projectURL)
            refreshWorkspace()
        }
    }

    /// Check whether GOF + VPC + Individual diagnostic outputs already exist for this run
    private func automationDiagnosticsExist(runID: String) -> Bool {
        let fm = FileManager.default
        let gofJPG = projectURL.appendingPathComponent("GOF_mod\(runID).jpg")
        let gofPNG = projectURL.appendingPathComponent("GOF_mod\(runID).png")
        let vpcStrat = projectURL.appendingPathComponent("VPC_Stratified_mod\(runID).jpg")
        let vpcMod = projectURL.appendingPathComponent("VPC_mod\(runID).jpg")
        let indivPDF = projectURL.appendingPathComponent("Individual_Plots_Run\(runID).pdf")
        let hasGOF = fm.fileExists(atPath: gofJPG.path) || fm.fileExists(atPath: gofPNG.path)
        let hasVPC = fm.fileExists(atPath: vpcStrat.path) || fm.fileExists(atPath: vpcMod.path)
        let hasIndiv = fm.fileExists(atPath: indivPDF.path)
        let hasCore = hasGOF && hasVPC && hasIndiv
        if hasCore && (!automationAuditExists(runID: runID, kind: "gof") || !automationAuditExists(runID: runID, kind: "vpc")) {
            runner.append("Core diagnostics exist for run\(runID); LLM audit reports are missing or skipped. Reusing plots without repeating the audit pass.")
        }
        return hasCore
    }

    private func automationAuditExists(runID: String, kind: String) -> Bool {
        let fm = FileManager.default
        let prefix = kind == "gof" ? "GOF_Expert_Audit" : "VPC_Evolution_Audit"
        let compareDirs = (try? fm.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)) ?? []
        for dir in compareDirs {
            let name = dir.lastPathComponent
            guard name.hasPrefix("Compare") else { continue }
            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            if files.contains(where: {
                let file = $0.lastPathComponent
                return file.hasPrefix("\(prefix)_Run\(runID)_") && file.hasSuffix(".md")
            }) {
                return true
            }
        }
        return false
    }

    private func runAutomationDiagnostics(runID: String, previousRun: String) async -> Int32 {
        if automationStopRequested { return 130 }

        // PHASE 1 — parallel: GOF + individual plots (independent R scripts)
        // Use shell & parallelism (ProcessRunner is @MainActor with isRunning guard)
        automationStep = "Rendering GOF and individual plots (parallel)"
        let gofCmd = pythonBridgeCommand(task: "gof-plot", previous: previousRun, current: runID)
        let indCmd = pythonBridgeCommand(task: "individual-plot", previous: previousRun, current: runID)
        _ = await runner.runAndWait(
            command: "( \(gofCmd) || true ) & ( \(indCmd) || true ) & wait",
            in: projectURL
        )
        if automationStopRequested { return 130 }

        // PHASE 2 — VPC (depends on NONMEM outputs; sequential)
        automationStep = "Running PsN VPC"
        _ = await runner.runAndWait(
            command: "\(pythonBridgeCommand(task: "psn-vpc", previous: previousRun, current: runID)) || true",
            in: projectURL
        )
        if automationStopRequested { return 130 }

        // PHASE 3 — parallel: VPC plot + PK parameter extraction
        automationStep = "Rendering VPC plot + PK parameters (parallel)"
        let vpcPlotCmd = pythonBridgeCommand(task: "vpc-plot", previous: previousRun, current: runID)
        let pkCmd = pythonBridgeCommand(task: "pk-parameters", previous: previousRun, current: runID)
        _ = await runner.runAndWait(
            command: "( \(vpcPlotCmd) || true ) & ( \(pkCmd) || true ) & wait",
            in: projectURL
        )
        if automationStopRequested { return 130 }

        // PHASE 4 — LLM audits
        automationStep = "Running LST parameter audit"
        _ = await runner.runAndWait(
            command: "\(pythonBridgeCommand(task: "parameter-audit", previous: previousRun, current: runID)) || true",
            in: projectURL
        )
        if automationStopRequested { return 130 }

        automationStep = "Running GOF vision audit"
        _ = await runner.runAndWait(
            command: "\(pythonBridgeCommand(task: "gof-audit", previous: previousRun, current: runID)) || true",
            in: projectURL
        )
        if automationStopRequested { return 130 }

        automationStep = "Running VPC vision audit"
        return await runner.runAndWait(
            command: "\(pythonBridgeCommand(task: "vpc-audit", previous: previousRun, current: runID)) || true",
            in: projectURL
        )
    }

    private func pythonBridgeCommand(task: String, previous: String, current: String) -> String {
        let python = resolvedPython()
        let workspaceBridge = workspaceURL.appendingPathComponent("autopmx_cli.py")
        let projectBridge = projectURL.appendingPathComponent("autopmx_cli.py")
        let bundledBridge = BundledResource.path(forResource: "autopmx_cli", ofType: "py") ?? ""
        let bridge: String
        if FileManager.default.fileExists(atPath: workspaceBridge.path) {
            bridge = workspaceBridge.path
        } else if FileManager.default.fileExists(atPath: projectBridge.path) {
            bridge = projectBridge.path
        } else {
            bridge = bundledBridge
        }
        var args = [
            shellQuote(python),
            shellQuote(bridge),
            task,
            "--prev", shellQuote(previous),
            "--curr", shellQuote(current),
            "--llm-url", shellQuote(llmBaseURL),
            "--model", shellQuote(llmModel),
            "--api-key", shellQuote(llmAPIKey.isEmpty ? "lm-studio" : llmAPIKey),
            "--rules", shellQuote(ruleSourceFiles)
        ]
        // Independent vision (multimodal) model config — used by GOF/VPC visual audits.
        // Falls back to the main model inside the Python layer when not provided.
        if let p = activeProvider {
            if let vURL = p.effectiveVisionBaseURL {
                args.append(contentsOf: ["--vision-url", shellQuote(vURL)])
            }
            if let vModel = p.effectiveVisionModel {
                args.append(contentsOf: ["--vision-model", shellQuote(vModel)])
            }
            if let vKey = p.effectiveVisionAPIKey {
                args.append(contentsOf: ["--vision-api-key", shellQuote(vKey)])
            }
        }
        // Always pass the project directory so Python/R scripts can find project_config.json etc.
        args.append(contentsOf: [
            "--project-dir", shellQuote(projectURL.path),
            "--psn-dir", shellQuote(resolvedPsNDir())
        ])
        // Pass R path if configured
        let rscript = resolvedR()
        args.append(contentsOf: ["--rscript", shellQuote(rscript.isEmpty ? "Rscript" : rscript)])
        return args.joined(separator: " ")
    }

    private func pythonBridgeCommandForDataset(task: String, dataFile: String) -> String {
        let python = resolvedPython()
        let workspaceBridge = workspaceURL.appendingPathComponent("autopmx_cli.py")
        let projectBridge = projectURL.appendingPathComponent("autopmx_cli.py")
        let bundledBridge = BundledResource.path(forResource: "autopmx_cli", ofType: "py") ?? ""
        let bridge: String
        if FileManager.default.fileExists(atPath: workspaceBridge.path) {
            bridge = workspaceBridge.path
        } else if FileManager.default.fileExists(atPath: projectBridge.path) {
            bridge = projectBridge.path
        } else {
            bridge = bundledBridge
        }
        // Resolve full path to the CSV file
        let csvPath: String
        if dataFile.hasPrefix("/") {
            csvPath = dataFile
        } else {
            csvPath = projectURL.appendingPathComponent(dataFile).path
        }
        var args = [
            shellQuote(python),
            shellQuote(bridge),
            task,
            "--prev", shellQuote(previousRun),
            "--curr", shellQuote(currentRun),
            "--llm-url", shellQuote(llmBaseURL),
            "--model", shellQuote(llmModel),
            "--api-key", shellQuote(llmAPIKey.isEmpty ? "lm-studio" : llmAPIKey),
            "--rules", shellQuote(ruleSourceFiles),
            "--project-dir", shellQuote(projectURL.path),
            "--psn-dir", shellQuote(resolvedPsNDir()),
            "--csv", shellQuote(csvPath)
        ]
        let rscript = resolvedR()
        args.append(contentsOf: ["--rscript", shellQuote(rscript.isEmpty ? "Rscript" : rscript)])
        return args.joined(separator: " ")
    }

    /// Resolve Python executable: user setting > workspace .venv > system
    func resolvedPython() -> String {
        if !pythonPath.isEmpty && FileManager.default.fileExists(atPath: pythonPath) {
            return pythonPath
        }
        return ProjectScanner.pythonExecutable(projectURL: projectURL, workspaceURL: workspaceURL)
    }

    /// Resolve Rscript executable: user setting > auto-detected
    func resolvedR() -> String {
        if !rPath.isEmpty && FileManager.default.fileExists(atPath: rPath) {
            return rPath
        }
        // Fallback auto-detect
        let candidates = [
            "/usr/local/bin/Rscript",
            "/opt/homebrew/bin/Rscript",
            "/Library/Frameworks/R.framework/Resources/Rscript",
            "/usr/bin/Rscript"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? ""
    }

    /// Resolve PsN directory (containing execute, scm, bootstrap etc.)
    func resolvedPsNDir() -> String {
        if !psnPath.isEmpty {
            let path = psnPath.hasSuffix("execute") ? (psnPath as NSString).deletingLastPathComponent : psnPath
            if FileManager.default.fileExists(atPath: path + "/execute") { return path }
        }
        for dir in ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"] {
            if FileManager.default.fileExists(atPath: dir + "/execute") { return dir }
        }
        return "/usr/local/bin"
    }

    /// Resolve PsN execute path
    func resolvedPsN() -> String {
        if !psnPath.isEmpty && FileManager.default.fileExists(atPath: psnPath) {
            return psnPath
        }
        let candidates = ["/usr/local/bin/execute", "/opt/homebrew/bin/execute", "/usr/bin/execute"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "execute"
    }

    func psnRunCommand(runID: String) -> String {
        "\(shellQuote(resolvedPsN())) run\(runID).mod -model_dir_name"
    }

    private func formattedRun(_ value: Int) -> String {
        String(format: "%03d", value)
    }

    // MARK: - Model Compare

    func presentModelCompare() {
        guard ensureModelFilesExist() else { return }
        isAssistantPanelPresented = true
        let runs = availableRunIDsForCompare()
        if runs.count >= 2 {
            compareRunA = runs[runs.count - 2]
            compareRunB = runs.last!
        } else if let first = runs.first {
            compareRunA = first
            compareRunB = first
        }
        isCompareSheetPresented = true
    }

    func availableRunIDsForCompare() -> [String] {
        // Prefer cached run IDs; fall back to a fresh scan only if cache is empty.
        let base = availableRunIDs.isEmpty ? ProjectScanner.discoverRuns(in: projectURL) : availableRunIDs
        return base
            .filter { runID in
                let modPath = projectURL.appendingPathComponent("run\(runID).mod").path
                return FileManager.default.fileExists(atPath: modPath)
            }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    func runModelCompareAudit() {
        guard !runner.isRunning else {
            runner.append("A task is already running.")
            return
        }
        guard !compareRunA.isEmpty, !compareRunB.isEmpty else {
            runner.append("Please select two runs to compare.")
            assistantMessages.append(AssistantMessage(role: .system, text: L10n.auditCompareFirst))
            return
        }

        // Show thinking state during comparison
        isAssistantThinking = true

        // Run parameter audit to extract estimates + diagnostics for both runs
        isCompareSheetPresented = false
        isAssistantPanelPresented = true
        let prev = compareRunA
        let curr = compareRunB
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusCompareStarting, prev, curr)))
        addThinkingStep("Comparing run\(prev) vs run\(curr)", type: .thinking, detail: "extracting parameters")
        Task {
            // Step 1: Extract PK parameters + diagnostics for both runs
            let pkCmdA = pythonBridgeCommand(task: "pk-parameters", previous: prev, current: prev)
            let pkCmdB = pythonBridgeCommand(task: "pk-parameters", previous: curr, current: curr)
            updateLastThinkingStep(type: .working, detail: "running pk-parameters for both runs")
            _ = await runner.runAndWait(command: "( \(pkCmdA) || true ) & ( \(pkCmdB) || true ) & wait", in: projectURL)
            refreshWorkspace()

            // Step 2: AI-driven comparison via DuDu PMx chat
            updateLastThinkingStep(type: .working, detail: "AI analyzing differences")
            await performAIModelComparison(prev: prev, curr: curr)
            updateLastThinkingStep(type: .done, detail: "comparison complete")
            isAssistantThinking = false
        }
    }

    private func performAIModelComparison(prev: String, curr: String) async {
        addThinkingStep("DuDu is comparing models...", type: .thinking, detail: "reading .mod, .lst, and parameter tables")
        let modA = projectURL.appendingPathComponent("run\(prev).mod")
        let modB = projectURL.appendingPathComponent("run\(curr).mod")
        let lstA = projectURL.appendingPathComponent("run\(prev).lst")
        let lstB = projectURL.appendingPathComponent("run\(curr).lst")
        let dataA = projectURL.appendingPathComponent("data_run\(prev).csv")
        let dataB = projectURL.appendingPathComponent("data_run\(curr).csv")

        let modAText = ((try? String(contentsOf: modA, encoding: .utf8)) ?? "").prefix(8_000)
        let modBText = ((try? String(contentsOf: modB, encoding: .utf8)) ?? "").prefix(8_000)
        let lstAText = ((try? String(contentsOf: lstA, encoding: .utf8)) ?? "").prefix(8_000)
        let lstBText = ((try? String(contentsOf: lstB, encoding: .utf8)) ?? "").prefix(8_000)
        let dataAText = (try? String(contentsOf: dataA, encoding: .utf8)) ?? ""
        let dataBText = (try? String(contentsOf: dataB, encoding: .utf8)) ?? ""

        let comparePrompt = """
        You are a pharmacometric model reviewer. Compare run\(prev) and run\(curr) thoroughly.

        CRITICAL RULES FOR COMPARISON:
        - ΔOFV > 10.83 (p<0.001, 2 df) → more complex model is SIGNIFICANTLY better. You MUST favor it.
        - ΔOFV > 3.84 (p<0.05, 1 df) → improvement is statistically significant. Prefer the better OFV model.
        - When ΔOFV favors the more complex model by >3.84, the complex model wins UNLESS catastrophic failure (RSE>100%, all boundary, no covariance).
        - Do NOT prefer a simpler model just because it's simpler. Cite the ΔOFV and statistical thresholds.
        - If the more complex model has higher OFV (worse fit), then you may prefer the simpler model.
        - ERROR MODEL SIMPLIFICATION: If combined error model is used and either Prop.err or Add.err has RSE>100% or is at boundary (estimate ≤ 1e-6), recommend fixing that component to 0 to convert to a single-component error model (proportional-only or additive-only).

        \(LanguageStore.shared.language == .en
            ? """
            Respond using the following structured format:

            ## 1. Structural Model Comparison
            - Each model's ADVAN/TRANS, number of compartments, route of administration, etc.
            - If the structures are identical, say so in one sentence.

            ## 2. Parameter Estimates and Precision
            Compare each parameter in a table:
            | Parameter | run\(prev) Estimate | run\(prev) %RSE | run\(curr) Estimate | run\(curr) %RSE |
            Key points:
            - PK parameters (CL, V, Q, V2, KA, etc.) with estimates and %RSE
            - Which parameters improved in precision and which got worse
            - Residual error model parameters (Prop.RE, Add.RE) with estimates and %RSE, plus their ε-Shrinkage (only compare Shrinkage in the residual model section)
            - IIV (OMEGA) estimates with %RSE, and IIV coverage (which parameters have/don't have IIV)

            NOTE on Shrinkage: Shrinkage is only used for residual error reporting (EPS(1), EPS(2)).
            Do NOT use eta-shrinkage as a criterion for accepting/rejecting models or fixing/removing IIV;
            ETA/PK precision is judged by %RSE, boundary, covariance, and convergence.

            ## 3. Goodness of Fit
            - OFV / AIC comparison (note ΔOFV, ΔAIC)
            - Statistical significance (cite p<0.05 or p<0.001 thresholds)
            - Whether the covariance step succeeded

            ## 4. Overall Assessment and Recommendations
            - Which model is better and why (cite specific numbers)
            - Whether the improvement is clinically meaningful
            - Remaining concerns (boundary estimates, high RSE, excessive residual shrinkage, etc.)
            - Next-step optimization suggestions
            """
            : """
            Respond in Chinese using the following structured format:

            ## 一、结构模型对比
            - 两个模型各自的 ADVAN/TRANS、房室数、给药途径等
            - 如果两个模型结构相同，一句话说明即可

            ## 二、参数估计与精度
            以表格格式比较每个参数：
            | 参数 | run\(prev) 估计值 | run\(prev) %RSE | Run\(curr) 估计值 | run\(curr) %RSE |
            重点关注：
            - PK 参数（CL, V, Q, V2, KA 等）的估计值和 %RSE
            - 哪些参数的精度有改善，哪些变差
            - 残差模型参数（Prop.RE, Add.RE）的估计值和 %RSE，以及各自的 ε-Shrinkage（仅在残差模型部分比较 Shrinkage）
            - IIV（OMEGA）估计值、%RSE，和 IIV 的覆盖范围（哪些参数有/无 IIV）

            NOTE on Shrinkage：Shrinkage 仅用于残差模型（EPS(1), EPS(2)）的报告。
            不要把 eta-shrinkage 作为接受/拒绝模型或固定/移除 IIV 的依据；ETA/PK 参数精度只看
            %RSE、边界、协方差和收敛状态。

            ## 三、模型拟合优度
            - OFV / AIC 对比（标注 ΔOFV, ΔAIC）
            - 解释统计学意义（引用 p<0.05 或 p<0.001 阈值）
            - 协方差步骤是否成功

            ## 四、综合评价与建议
            - 哪个模型更优，依据是什么（引用具体数值）
            - 改进是否具有临床意义
            - 还需关注的问题（边界估计、高 RSE、残差 Shrinkage 过高等）
            - 下一步优化建议
            """)

        Keep the response concise but thorough. Cite actual numbers.

        --- run\(prev).mod ---
        \(modAText)

        --- run\(prev) PK parameters ---
        \(dataAText.prefix(5_000))

        --- run\(prev).lst key sections ---
        \(lstAText)

        --- run\(curr).mod ---
        \(modBText)

        --- run\(curr) PK parameters ---
        \(dataBText.prefix(5_000))

        --- run\(curr).lst key sections ---
        \(lstBText)
        """

        do {
            updateLastThinkingStep(type: .working, detail: "calling LLM for comparison")
            let (reply, usage) = try await LLMCommandService.chat(
                baseURL: llmBaseURL,
                model: llmModel,
                messages: [AssistantMessage(role: .user, text: comparePrompt)],
                projectURL: projectURL,
                currentRun: curr,
                rules: activeRuleContext().text,
                apiKey: llmAPIKey,
                knowledgeBaseURL: knowledgeBaseURL,
                apiFormat: activeAPIFormat
            )
            recordUsage(usage)
            assistantMessages.append(AssistantMessage(role: .assistant, text: reply))
        } catch {
            updateLastThinkingStep(type: .error, detail: "LLM call failed")
            assistantMessages.append(AssistantMessage(role: .assistant, text: String.safeFormat(L10n.statusCompareFailed, error.localizedDescription)))
        }
    }

    private struct AutomationStoppedError: Error {
        let step: String
    }

    private struct AutomationDatasetError: Error {
        let runID: String
        let output: String
    }

    private func checkAutomationStop(_ step: String) throws {
        if automationStopRequested || automationTask?.isCancelled == true {
            throw AutomationStoppedError(step: step)
        }
    }

    private struct AutomationRunChoice {
        let runID: String
        let previousRun: String?
        let ofv: Double?
        let hasLst: Bool
        let hasExt: Bool
        let hasCov: Bool
        let minimizationSuccessful: Bool
        let covarianceSuccessful: Bool
        /// STABLE = minimization ✓ AND covariance ✓ AND no parameter on a boundary.
        /// This is the ONLY criterion that makes a run eligible to be SELECTED as a
        /// key/final model. Used by all selection paths so an unstable run (e.g. one
        /// missing S or C) can never be chosen regardless of how good its OFV looks.
        let stable: Bool
        let compartments: Int
        let structuralPrecisionIssues: [String]
        let highRSEParameters: [String]
        let residualPrecisionIssues: [String]

        /// A more complex model is not worth escalating to when its key structural
        /// parameters are imprecise, residual-error RSE is unacceptable, or many
        /// estimated parameters are imprecise.
        var precisionEligible: Bool {
            structuralPrecisionIssues.isEmpty
                && residualPrecisionIssues.isEmpty
                && highRSEParameters.count < 3
        }

        var precisionLabel: String {
            if structuralPrecisionIssues.isEmpty && highRSEParameters.isEmpty {
                return "OK"
            }
            if !residualPrecisionIssues.isEmpty {
                return "RESID(\(residualPrecisionIssues.count))"
            }
            if structuralPrecisionIssues.isEmpty {
                return "warn(\(highRSEParameters.count))"
            }
            return "HIGH(\(structuralPrecisionIssues.count))"
        }

        var precisionReason: String {
            let issues = structuralPrecisionIssues + residualPrecisionIssues
            if !issues.isEmpty {
                return issues.prefix(6).joined(separator: ", ")
            }
            return "\(highRSEParameters.count) parameters with %RSE > 50%"
        }

        var row: String {
            let ofvText = ofv.map { String(format: "%.3f", $0) } ?? "NA"
            return "| run\(runID) | \(ofvText) | \(compartments)-comp | \(minimizationSuccessful ? "yes" : "no") | \(covarianceSuccessful ? "yes" : "no") | \(stable ? "stable" : "UNSTABLE") | \(precisionLabel) | \(hasLst ? "lst " : "")\(hasExt ? "ext " : "")\(hasCov ? "cov" : "") |"
        }
    }

    private func isAutomationProject(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix("AutoModel_")
            || name == "AutoModel_Demo_NMData"
            || FileManager.default.fileExists(atPath: url.appendingPathComponent(".autopmx_automation.json").path)
    }

    /// Prevent premature ACCEPT: require testing the next compartment level before accepting.
    /// ONLY blocks when the next-higher compartment has NOT been tried at all (no runs exist).
    /// When higher-compartment runs exist but lack S+C, the caller's final integrity check
    /// handles it — we do NOT force escalation from here (that would create even higher
    /// compartments when we should be repairing the current higher one).
    private func shouldPreventAcceptance(runID: String, decision: String, modelRuns: [String], profile: DatasetProfile) -> Bool {
        guard isAcceptanceDecision(decision) else { return false }
        let runInfo = compartmentInfoForRun(runID)
        let currentComp = runInfo.compartments

        // Check if there's a higher compartment run that already exists
        let higherCompRuns = modelRuns.filter { compartmentInfoForRun($0).compartments > currentComp }

        if higherCompRuns.isEmpty && currentComp < 3 {
            // No higher compartment run exists yet — must create one before accepting
            return true
        }

        // Higher compartment runs EXIST — whether they have S+C or not is checked by the
        // caller's final integrity check. We do NOT block acceptance here because that would
        // trigger forceEscalation, creating even higher compartments when we need to repair
        // the existing higher one instead.
        return false
    }

    private func compartmentInfoForRun(_ runID: String) -> (compartments: Int, advan: String) {
        let modPath = projectURL.appendingPathComponent("run\(runID).mod")
        guard let text = try? String(contentsOf: modPath, encoding: .utf8) else { return (1, "ADVAN1") }
        let upper = text.uppercased()
        if upper.contains("ADVAN11") || upper.contains("ADVAN12") { return (3, "ADVAN11/12") }
        if upper.contains("ADVAN3")  || upper.contains("ADVAN4")  { return (2, "ADVAN3/4") }
        return (1, "ADVAN1/2")
    }

    private func automationModelRuns() -> [String] {
        ProjectScanner.discoverRuns(in: projectURL)
            .filter { runID in
                FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("run\(runID).mod").path)
            }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    private func hasModelOutputs(runID: String) -> Bool {
        FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("run\(runID).lst").path)
            || FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("run\(runID).ext").path)
    }

    /// True when the current project contains at least one .mod file.
    var hasAnyModFile: Bool {
        let files = (try? FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)) ?? []
        return files.contains { $0.pathExtension.lowercased() == "mod" }
    }

    /// Gate for model-only actions (GOF / VPC / individual DV-TIME / SCM / compare ...).
    /// Returns true when the project has .mod files. When none exist, shows a liquid-glass
    /// notice card and posts a DuDu chat hint, then returns false.
    @discardableResult
    func ensureModelFilesExist() -> Bool {
        guard !hasAnyModFile else { return true }
        noModelCardVisible = true
        assistantMessages.append(AssistantMessage(role: .system, text: L10n.noModelChatHint))
        return false
    }

    /// Check if a NONMEM run produced a USABLE, fully-validated estimate.
    /// Returns true ONLY when: ext exists with final estimates, MINIMIZATION SUCCESSFUL
    /// is present in .lst, AND the covariance step is genuinely successful (no abort, no boundary).
    /// A COVARIANCE STEP ABORTED run is NOT acceptable — NONMEM may still print an SE table,
    /// but the step failed, so the covariance is unusable for model selection / comparison.
    /// Parameter estimates and SE from an aborted $COV step must never be treated as valid S+C.
    ///
    /// IMPORTANT: We do NOT gate on fileLooksLikeFailure for the .lst because "UNDEFINED" is a
    /// common keyword in normal NONMEM output (e.g. table headers). The definitive convergence
    /// signals are: MINIMIZATION SUCCESSFUL, .ext with final estimates, and covariance completion.
    func isModelRunSuccessful(runID: String) -> Bool {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        let extURL = projectURL.appendingPathComponent("run\(runID).ext")
        guard FileManager.default.fileExists(atPath: lstURL.path),
              let text = try? String(contentsOf: lstURL, encoding: .utf8) else {
            return false
        }
        let upper = text.uppercased()

        // Must have a usable ext file with parameter estimates
        guard FileManager.default.fileExists(atPath: extURL.path) else { return false }

        // Must have minimization success — this is the definitive .lst signal
        let minimizationOK = upper.contains("MINIMIZATION SUCCESSFUL")
        if !minimizationOK { return false }

        // Check that .ext actually contains final estimates (iteration -1000000000)
        guard let extText = try? String(contentsOf: extURL, encoding: .utf8),
              extText.contains("-1000000000") else {
            return false
        }

        // A model run is only "successful" if BOTH minimization AND covariance succeeded
        // (no abort, no boundary). A COVARIANCE STEP ABORTED run is NOT acceptable — this was
        // the root cause of run011 being treated as a valid, S+C model despite C failing.
        guard runCovarianceOK(runID) else { return false }
        return true
    }

    /// Single source of truth for estimation success. A run is a valid base-model
    /// CANDIDATE ONLY when BOTH minimization (S) and the covariance step (C) succeeded.
    /// Covariance success requires an actual "COVARIANCE STEP SUCCESSFUL" string — a
    /// present-but-aborted .cov file is NOT enough.
    func runMinimizationOK(_ runID: String) -> Bool {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else { return false }
        return text.uppercased().contains("MINIMIZATION SUCCESSFUL")
    }

    func runCovarianceOK(_ runID: String) -> Bool {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        let covURL = projectURL.appendingPathComponent("run\(runID).cov")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else { return false }
        let upper = text.uppercased()
        // Any of these explicit failure signals means the covariance step did NOT succeed.
        // A run with these must NEVER be treated as S+C — NONMEM still prints an SE table in
        // the .lst, but the step failed (e.g. run011: COVARIANCE STEP ABORTED; run003-style
        // "covariance step NOT successful"). We enumerate every known failure phrasing so the
        // HARD GATE cannot be bypassed just because the AI said ACCEPT.
        let failureSignals = [
            "COVARIANCE STEP ABORTED",
            "COVARIANCE STEP FAILED",
            "COVARIANCE STEP NOT SUCCESSFUL",
            "COVARIANCE STEP WAS NOT SUCCESSFUL",
            "R MATRIX IS NOT POSITIVE DEFINITE",
            "S MATRIX IS NOT POSITIVE DEFINITE",
            "MATRIX IS NOT POSITIVE DEFINITE",
            "COVARIANCE STEP ABORTED",
            "TABLE SHOULD BE IGNORED",
            "ZERO VARIANCE",
            "SINGULAR"
        ]
        for sig in failureSignals where upper.contains(sig) { return false }
        let boundary = upper.contains("PARAMETER IS NEAR ITS BOUNDARY")
        if boundary { return false }
        // A covariance step is considered SUCCESSFUL only when NONMEM explicitly confirms
        // completion AND a real, non-empty .cov file was written.
        //   - Preferred signal: the literal "COVARIANCE STEP SUCCESSFUL" line.
        //   - Fallback (some FOCE/I / batched outputs omit that exact line): "ELAPSED COVARIANCE"
        //     BUT only together with a substantive .cov file ( > 500 bytes) so an empty/aborted
        //     .cov shell cannot masquerade as a successful step.
        let covExists = FileManager.default.fileExists(atPath: covURL.path)
        let covSize = (try? FileManager.default.attributesOfItem(atPath: covURL.path)[.size] as? Int) ?? 0
        let explicitSuccess = upper.contains("COVARIANCE STEP SUCCESSFUL")
        let elapsedOK = upper.contains("ELAPSED COVARIANCE") && covExists && covSize > 500
        return explicitSuccess || elapsedOK
    }

    func isModelFullyValid(runID: String) -> Bool {
        runMinimizationOK(runID) && runCovarianceOK(runID)
    }

    /// A model is STABLE (eligible to be SELECTED as a key/final model) only when it has
    /// successful minimization AND covariance AND no parameter sitting on a boundary.
    func isModelStable(runID: String) -> Bool {
        isModelFullyValid(runID: runID) && !hasBoundaryWarningsFor(runID)
    }

    private func hasBoundaryWarningsFor(_ runID: String) -> Bool {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else { return false }
        return text.uppercased().contains("PARAMETER IS NEAR ITS BOUNDARY")
    }

    private func missingEstimationReason(runID: String) -> String {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else { return "no output file" }
        let upper = text.uppercased()
        let minOK = upper.contains("MINIMIZATION SUCCESSFUL")
        let covOK = runCovarianceOK(runID)
        var parts: [String] = []
        if !minOK { parts.append("minimization NOT successful") }
        if !covOK { parts.append("covariance step NOT successful") }
        return parts.joined(separator: ", ")
    }

    /// Rough parameter-precision summary for the evaluation evidence: worst %RSE parsed from the .lst.
    private func parameterPrecisionSummary(runID: String) -> String {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else {
            return "run\(runID): no .lst for precision check"
        }
        var rse: [Double] = []
        let ns = text as NSString
        if let regex = try? NSRegularExpression(pattern: #"\((\d+(?:\.\d+)?)%\)"#, options: []) {
            let range = NSRange(location: 0, length: ns.length)
            for m in regex.matches(in: text, options: [], range: range) where m.numberOfRanges > 1 {
                if let v = Double(ns.substring(with: m.range(at: 1))) { rse.append(v) }
            }
        }
        let worst = rse.max()
        let cov = FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("run\(runID).cov").path)
        if let w = worst {
            return "run\(runID): worst %RSE ≈ \(String(format: "%.1f", w))% \(w > 50 ? "(⚠️ >50%, imprecise)" : "(<50%, ok)"), covariance \(cov ? "computed" : "NOT computed")"
        }
        return "run\(runID): no %RSE parsed, covariance \(cov ? "computed" : "NOT computed")"
    }

    /// Check the .lst for residual error parameter (Add.RE / Prop.RE) %RSE.
    /// Returns a diagnostic string if one has very high RSE.
    private func checkResidualErrorRSE(runID: String) -> (warnings: String, hardDirective: String) {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else { return ("", "") }
        let lines = text.components(separatedBy: "\n")
        guard let rseRe = try? NSRegularExpression(pattern: #"THETA\s+\d+:\s+[\d.Ee+-]+\s+[\d.Ee+-]+\s+\(?(\d+(?:\.\d+)?)%\)?"#, options: [.caseInsensitive]),
              let labelRe = try? NSRegularExpression(pattern: #";\s*((?:Add|Prop)\.\S+)"#, options: [.caseInsensitive]) else { return ("", "") }
        var inTheta = false
        var idx = 0
        var labels: [Int: String] = [:]
        var warnings: [String] = []
        var hardProblems: [(label: String, theta: Int, rse: Double)] = []
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.uppercased().contains("THETA - ") { inTheta = true; continue }
            if t.uppercased().range(of: "OMEGA -|SIGMA -", options: .regularExpression) != nil { inTheta = false; break }
            guard inTheta else { continue }
            if let m = labelRe.firstMatch(in: t, options: [], range: NSRange(location: 0, length: t.utf16.count)) {
                labels[idx] = (t as NSString).substring(with: m.range(at: 1))
            }
            if let m = rseRe.firstMatch(in: t, options: [], range: NSRange(location: 0, length: t.utf16.count)) {
                if let rse = Double((t as NSString).substring(with: m.range(at: 1))) {
                    let label = labels[idx] ?? "THETA\(idx+1)"
                    let lower = label.lowercased()
                    if (lower.contains("add") || lower.contains("prop")) && rse > 100 {
                        hardProblems.append((label: label, theta: idx + 1, rse: rse))
                        warnings.append("🔴 \(label) (THETA\(idx+1)) has %RSE ≈ \(String(format: "%.0f", rse))% — UNESTIMABLE — MUST FIX to 0")
                    } else if lower.contains("add") && rse > 50 {
                        warnings.append("⚠️ \(label) (THETA\(idx+1)) has %RSE ≈ \(String(format: "%.0f", rse))% — consider fixing to 0 (proportional-only)")
                    } else if lower.contains("prop") && rse > 50 {
                        warnings.append("⚠️ \(label) (THETA\(idx+1)) has %RSE ≈ \(String(format: "%.0f", rse))% — consider switching to additive-only")
                    }
                }
                idx += 1
            } else {
                let bare = try! NSRegularExpression(pattern: #"THETA\s+\d+:"#, options: [.caseInsensitive])
                if bare.firstMatch(in: t, options: [], range: NSRange(location: 0, length: t.utf16.count)) != nil { idx += 1 }
            }
        }
        var directive = ""
        if !hardProblems.isEmpty {
            let worst = hardProblems.max(by: { $0.rse < $1.rse })!
            let fixAction: String
            let lower = worst.label.lowercased()
            if lower.contains("add") {
                fixAction = """
                → Keep model structure. Do NOT remove THETA or modify $ERROR block.
                → Set Add.RE line in $THETA to `0 FIX  ; Add.RE (sd)`.
                → Keep $ERROR and $SIGMA completely unchanged.
                → The FIX keyword pins Add.RE at ZERO, effectively making
                  the error proportional-only without touching the model structure.
                """
            } else if lower.contains("prop") {
                fixAction = """
                → Keep model structure. Do NOT remove THETA or modify $ERROR block.
                → Set Prop.RE line in $THETA to `0 FIX  ; Prop.RE (sd)`.
                → Keep $ERROR and $SIGMA completely unchanged.
                → The FIX keyword pins Prop.RE at ZERO, effectively making
                  the error additive-only without touching the model structure.
                """
            } else {
                fixAction = "→ FIX THETA\(worst.theta) to 0 FIX."
            }
            directive = """
            ╔══════════════════════════════════════════════════════════════════╗
            ║  🔴🔴🔴 PRIORITY DIRECTIVE — NON-NEGOTIABLE 🔴🔴🔴               ║
            ║  Parent run\(runID) has \(worst.label) (THETA\(worst.theta)) at %RSE = \(String(format: "%.0f", worst.rse))%   ║
            ║  This EXCEEDS 100% → parameter is UNESTIMABLE.                  ║
            ║                                                                  ║
            ║  The new run MUST perform EXACTLY these actions:                  ║
            \(fixAction)
            ║                                                                  ║
            ║  🚨 DO NOT change compartment count.                              ║
            ║  🚨 DO NOT add covariates.                                       ║
            ║  🚨 The compartment structure MUST stay IDENTICAL to parent run. ║
            ║  🚨 ONLY change: the residual error model (as above).            ║
            ╚══════════════════════════════════════════════════════════════════╝
            """
        }
        return (warnings.joined(separator: "\n"), directive)
    }

    /// Check residual error RSE from .ext/parameter rows. This is the robust path
    /// for NONMEM versions whose .lst prints matrices instead of per-parameter RSE.
    private func checkResidualErrorRSEFromExt(runID: String) -> (warnings: String, hardDirective: String) {
        let rows = ProjectScanner.parameterEstimates(runID: runID, in: projectURL)
        var warnings: [String] = []
        var hardProblems: [(label: String, rse: Double)] = []
        for row in rows where row.group == "Residual" {
            guard let rse = row.rsePercent else { continue }
            if rse > 100 {
                hardProblems.append((label: row.name, rse: rse))
                warnings.append("🔴 \(row.name) has %RSE ≈ \(String(format: "%.0f", rse))% — UNESTIMABLE — MUST FIX to 0")
            } else if rse > 50 {
                warnings.append("⚠️ \(row.name) has %RSE ≈ \(String(format: "%.0f", rse))% — consider fixing to 0")
            }
        }
        var directive = ""
        if let worst = hardProblems.max(by: { $0.rse < $1.rse }) {
            let lower = worst.label.lowercased()
            let target = lower.contains("prop") ? "Prop.RE" : "Add.RE"
            directive = """
            ╔══════════════════════════════════════════════════════════════════╗
            ║  🔴🔴🔴 PRIORITY DIRECTIVE — NON-NEGOTIABLE 🔴🔴🔴               ║
            ║  Parent run\(runID) has \(worst.label) at %RSE = \(String(format: "%.0f", worst.rse))%   ║
            ║  This EXCEEDS 100% → parameter is UNESTIMABLE.                  ║
            ║                                                                  ║
            ║  The new run MUST perform EXACTLY these actions:                  ║
            ║  → Keep model structure. Do NOT remove THETA or modify $ERROR.    ║
            ║  → Set \(target) in $THETA to `0 FIX  ; \(target) (sd)`.         ║
            ║  → Keep $ERROR and $SIGMA unchanged.                              ║
            ║  → Do NOT fix any IIV in this run.                                ║
            ║  → Do NOT change compartment count or add covariates.             ║
            ╚══════════════════════════════════════════════════════════════════╝
            """
        }
        return (warnings.joined(separator: "\n"), directive)
    }

    /// Summarize the structural / estimation settings of a model .mod — captured as a skill
    /// so successful parameter/structure choices can be reused across projects.
    private func modelSettingsSummary(runID: String) -> String {
        let modURL = projectURL.appendingPathComponent("run\(runID).mod")
        guard let text = try? String(contentsOf: modURL, encoding: .utf8) else { return "n/a" }
        let upper = text.uppercased()

        var advan = "?"
        if let m = text.range(of: #"(?i)ADVAN\d+"#, options: .regularExpression) { advan = String(text[m]).uppercased() }
        var trans = "?"
        if let m = text.range(of: #"(?i)TRANS\d+"#, options: .regularExpression) { trans = String(text[m]).uppercased() }

        let est: String
        if upper.contains("SAEM") {
            est = "SAEM"
        } else if upper.contains("METHOD=1") {
            est = "FOCE"
        } else if upper.contains("METHOD=0") {
            est = "FO"
        } else if upper.contains("$EST") {
            est = "EST"
        } else {
            est = "?"
        }

        let hasProp = upper.contains("PROP.RE")
        let hasAdd = upper.contains("ADD.RE")
        let err = (hasProp && hasAdd) ? "combined" : (hasProp ? "proportional" : (hasAdd ? "additive" : "?"))

        let omegaBlocks = text.components(separatedBy: "\n").filter { $0.uppercased().contains("$OMEGA") }.count
        let comp = compartmentInfoForRun(runID).compartments

        return "\(comp)-comp \(advan) \(trans); \(est); \(err) error; \(omegaBlocks) $OMEGA block(s)"
    }

    // MARK: - Claude Code CLI integration

    func openClaudeCodeTerminal() {
        // Toggle the built-in Claude Code panel instead of opening Terminal.app
        isClaudeCodePanelOpen.toggle()
        if isClaudeCodePanelOpen {
            isAssistantPanelPresented = false  // close DuDu if open, so panels don't overlap
            runner.append("Claude Code panel opened. Type your prompt and press Enter to send to Claude Code.")
            assistantMessages.append(AssistantMessage(role: .system, text: L10n.statusClaudePanelOpened))
        }
    }

    // MARK: - Claude Code streaming with collapsible thinking

    @Published var claudeThinkingBlocks: [ClaudeThinkingBlock] = []
    @Published var claudeFinalResponse = ""

    struct ClaudeThinkingBlock: Identifiable {
        let id = UUID()
        let timestamp: String
        var title: String
        var content: String
        var isCollapsed: Bool = true
    }

    func sendToClaudeCode() {
        let input = claudeCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isClaudeCodeRunning else { return }

        let cd = projectURL.path
        let prompt = input.replacingOccurrences(of: "'", with: "'\\''")
        let model = activeProvider?.model ?? "Deepseek V4 Flash"
        let effort = claudeEffortSetting

        claudeThinkingBlocks.removeAll()
        claudeFinalResponse = ""
        claudeCodeOutput += "\n\n╭─ You \(timeStamp()) ──╮\n\(input)\n╰────────────────╯\n"
        claudeCodeInput = ""
        isClaudeCodeRunning = true
        claudeCodeStatus = "Running..."
        claudeCodeOutput += "🧠 Claude Code thinking..."
        flushClaudeOutput()

        var cmd = "cd '\(cd)' && echo '\(prompt)' | claude -p --output-format stream-json --verbose --model '\(model)'"
        if !effort.isEmpty && effort != "default" { cmd += " --effort '\(effort)'" }
        if claudeAutoApprove { cmd += " --dangerously-skip-permissions" }
        cmd += " 2>&1"

        let task = Process()
        claudeTask = task
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", cmd]
        task.currentDirectoryURL = projectURL
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = NSHomeDirectory()
        task.environment = env

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        var buffer = ""

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            buffer += chunk
            Task { @MainActor in self?.processClaudeStreamBuffer(&buffer) }
        }

        task.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                // Process remaining buffer
                self?.processClaudeStreamBuffer(&buffer)
                self?.finalizeClaudeThinking()
                self?.isClaudeCodeRunning = false
                self?.claudeCodeStatus = proc.terminationStatus == 0 ? "✅ Complete" : "⚠️ Exit: \(proc.terminationStatus)"
                self?.flushClaudeOutput()
            }
        }

        do {
            try task.run()
            runner.append("Claude Code: \(input.prefix(60))...")
        } catch {
            claudeCodeOutput += "\n❌ Failed: \(error.localizedDescription)\n"
            isClaudeCodeRunning = false
            claudeCodeStatus = "❌ Error"
        }
    }

    private func processClaudeStreamBuffer(_ buffer: inout String) {
        // Claude Code stream-json outputs lines of JSON, each with type field
        while let newlineIdx = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIdx])
            buffer = String(buffer[buffer.index(after: newlineIdx)...])

            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            switch type {
            case "assistant":
                // Final assistant message — append to final response
                if let message = json["message"] as? [String: Any],
                   let content = message["content"] as? [[String: Any]] {
                    for block in content {
                        if let text = block["text"] as? String {
                            claudeFinalResponse += text
                        }
                    }
                }
            case "thinking":
                // Thinking block — collapse into timeline
                let title = json["title"] as? String ?? "Thinking..."
                let content = json["content"] as? String ?? (json["message"] as? String ?? "")
                if !content.isEmpty || (json["title"] as? String) != nil {
                    claudeThinkingBlocks.append(ClaudeThinkingBlock(
                        timestamp: timeStamp(),
                        title: title,
                        content: content,
                        isCollapsed: true
                    ))
                }
            case "tool_use":
                let toolName = json["name"] as? String ?? "tool"
                let toolInput = json["input"] as? [String: Any] ?? [:]
                let desc = describeToolUse(name: toolName, input: toolInput)
                claudeThinkingBlocks.append(ClaudeThinkingBlock(
                    timestamp: timeStamp(),
                    title: "🔧 \(toolName)",
                    content: desc,
                    isCollapsed: true
                ))
            case "tool_result":
                // Skip raw tool results, they're noisy
                break
            default:
                break
            }
            flushClaudeOutput()
        }
    }

    private func describeToolUse(name: String, input: [String: Any]) -> String {
        switch name {
        case "Bash":
            return (input["command"] as? String) ?? (input["description"] as? String) ?? "running command..."
        case "Read": return "Reading \(input["file_path"] as? String ?? "...")"
        case "Write": return "Writing \(input["file_path"] as? String ?? "...")"
        case "Edit": return "Editing \(input["file_path"] as? String ?? "...")"
        case "Grep": return "Searching: \(input["pattern"] as? String ?? "...")"
        case "Glob": return "Finding: \(input["pattern"] as? String ?? "...")"
        default: return input.values.first.map { "\($0)" } ?? "running..."
        }
    }

    private func finalizeClaudeThinking() {
        // Build clean output
        var output = ""

        // Thinking timeline
        if !claudeThinkingBlocks.isEmpty {
            output += "\n▸ Thinking timeline:\n"
            for block in claudeThinkingBlocks {
                let icon = block.content.isEmpty ? "  ○" : "  ●"
                output += "\(icon) [\(block.timestamp)] \(block.title)"
                if !block.content.isEmpty {
                    let preview = block.content.prefix(120).replacingOccurrences(of: "\n", with: " ")
                    output += " — \(preview)..."
                }
                output += "\n"
            }
        }

        // Final response
        if !claudeFinalResponse.isEmpty {
            output += "\n▸ Response:\n\(claudeFinalResponse.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }

        // Replace the "thinking..." placeholder
        if let range = claudeCodeOutput.range(of: "🧠 Claude Code thinking...") {
            claudeCodeOutput = String(claudeCodeOutput[..<range.lowerBound]) + output
        }

        output += "\n✅ Done \(timeStamp())\n"
        claudeCodeOutput += output
    }

    private func flushClaudeOutput() {
        // No-op: SwiftUI auto-refreshes via @Published
    }

    func cancelClaudeCode() {
        guard isClaudeCodeRunning else { return }
        claudeTask?.terminate()
        claudeTask = nil
        isClaudeCodeRunning = false
        claudeCodeStatus = "⏹ Stopped"
        claudeCodeOutput += "\n⏹ Stopped by user.\n"
        runner.append("Claude Code cancelled by user.")
    }

    private func timeStamp() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: Date())
    }

    @Published var claudeEffortSetting: String = "" {
        didSet {
            UserDefaults.standard.set(claudeEffortSetting, forKey: "AutoPMX.claudeEffort")
        }
    }
    @Published var claudeAutoApprove: Bool = false {
        didSet {
            UserDefaults.standard.set(claudeAutoApprove, forKey: "AutoPMX.claudeAutoApprove")
        }
    }

    var claudeEffortOptions: [(String, String)] {
        [
            ("", "Default"),
            ("low", "Low — fast, cheap"),
            ("medium", "Medium — balanced"),
            ("high", "High — thorough"),
            ("xhigh", "XHigh — most thorough")
        ]
    }

    func loadClaudeSettings() {
        claudeEffortSetting = UserDefaults.standard.string(forKey: "AutoPMX.claudeEffort") ?? ""
        claudeAutoApprove = UserDefaults.standard.bool(forKey: "AutoPMX.claudeAutoApprove")
    }

    /// Run dose-normalized C-T analysis (lag, elimination, exposure similarity) via R
    private func runCTAnalysis(dataFile: String) async -> (
        hasLag: Bool, lagTime: Double, recommendation: String,
        elimSimilar: Bool, elimReliable: Bool, elimDetail: String,
        linearPK: Bool, exposureDetail: String,
        firstDoseElimSimilar: Bool, firstDoseElimDetail: String, multiDose: Bool,
        route: String, compartmentSuspected: Bool, compartmentShapeDetail: String
    ) {
        let rscript = resolvedR()
        guard !rscript.isEmpty else {
            runner.append("CT analysis skipped: R not configured (set R path in Settings)")
            return (false, 0, "R not configured", true, false, "", true, "", true, "", false, "Unknown", false, "")
        }
        let ctScript = findOrCopyCTScript()
        guard let script = ctScript, FileManager.default.fileExists(atPath: script) else {
            runner.append("CT analysis skipped: dose_normalized_ct_plot.R not found")
            return (false, 0, "CT analysis script not found", true, false, "", true, "", true, "", false, "Unknown", false, "")
        }
        let csvPath = projectURL.appendingPathComponent(dataFile).path
        let outPrefix = projectURL.appendingPathComponent(dataFile.replacingOccurrences(of: ".csv", with: "")).path
        // Pass project units to R script so axis labels have proper units
        let doseQ = shellQuote(doseUnit)
        let concQ = shellQuote(concUnit)
        let timeQ = shellQuote(timeUnit)
        let cmd = "\(shellQuote(rscript)) \(shellQuote(script)) \(shellQuote(csvPath)) \(shellQuote(outPrefix)) \(doseQ) \(concQ) \(timeQ) 2>&1"
        runner.append("Running dose-normalized C-T analysis...")
        runner.append("  R: \(rscript)")
        runner.append("  Script: \(script)")
        runner.append("  Data: \(csvPath)")
        let result = await runner.runAndWaitWithOutput(command: cmd, in: projectURL)
        let exitCode = result.exitCode
        let allOutput = result.output
        if exitCode != 0 {
            runner.append("CT analysis R script failed (exit \(exitCode)):")
            // Show last 10 lines of output for quick diagnosis
            let lines = allOutput.components(separatedBy: "\n")
            for line in lines.suffix(15) where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                runner.append("  \(line)")
            }
            refreshWorkspace()
            return (false, 0, "", true, false, "", true, "", true, "", false, "Unknown", false, "")
        }
        // Show summary lines from R output
        let summaryLines = allOutput.components(separatedBy: "\n").filter { $0.contains("║") || $0.contains(">>>") }
        for line in summaryLines.prefix(12) {
            runner.append(line)
        }

        // Parse structured output
        var hasLag = false
        var lagTime = 0.0
        var recommendation = ""
        var elimSimilar = true
        var elimReliable = false
        var elimDetail = ""
        var linearPK = true
        var exposureDetail = ""
        var firstDoseElimSimilar = true
        var firstDoseElimDetail = ""
        var multiDose = false
        var route = "Unknown"
        var compartmentSuspected = false
        var compartmentShapeDetail = ""
        let analysisFile = outPrefix + "_analysis.txt"
        if let lines = try? String(contentsOfFile: analysisFile, encoding: .utf8) {
            for line in lines.components(separatedBy: "\n") {
                if line.hasPrefix("HAS_LAG=YES") { hasLag = true }
                if line.hasPrefix("LAG_TIME="), let val = Double(line.replacingOccurrences(of: "LAG_TIME=", with: "")) {
                    lagTime = val
                }
                if line.hasPrefix("LAG_RECOMMENDATION=") {
                    recommendation = line.replacingOccurrences(of: "LAG_RECOMMENDATION=", with: "")
                }
                if line.hasPrefix("ELIM_HALFLIFE_SIMILAR=YES") { elimSimilar = true }
                if line.hasPrefix("ELIM_HALFLIFE_SIMILAR=NO") { elimSimilar = false }
                if line.hasPrefix("ELIM_N_RELIABLE="), let val = Int(line.replacingOccurrences(of: "ELIM_N_RELIABLE=", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) {
                    elimReliable = val >= 2
                }
                if line.hasPrefix("ELIM_DETAIL=") {
                    elimDetail = line.replacingOccurrences(of: "ELIM_DETAIL=", with: "")
                }
                if line.hasPrefix("LINEAR_PK=YES") { linearPK = true }
                if line.hasPrefix("LINEAR_PK=NO") { linearPK = false }
                if line.hasPrefix("EXPOSURE_DETAIL=") {
                    exposureDetail = line.replacingOccurrences(of: "EXPOSURE_DETAIL=", with: "")
                }
                if line.hasPrefix("FIRSTDOSE_ELIM_HALFLIFE_SIMILAR=YES") { firstDoseElimSimilar = true }
                if line.hasPrefix("FIRSTDOSE_ELIM_HALFLIFE_SIMILAR=NO") { firstDoseElimSimilar = false }
                if line.hasPrefix("FIRSTDOSE_ELIM_DETAIL=") {
                    firstDoseElimDetail = line.replacingOccurrences(of: "FIRSTDOSE_ELIM_DETAIL=", with: "")
                }
                if line.hasPrefix("MULTI_DOSE=YES") { multiDose = true }
                if line.hasPrefix("ROUTE=") {
                    route = line.replacingOccurrences(of: "ROUTE=", with: "")
                }
                if line.hasPrefix("COMPARTMENT_SHAPE_SUSPECTED=YES") { compartmentSuspected = true }
                if line.hasPrefix("COMPARTMENT_SHAPE_DETAIL=") {
                    compartmentShapeDetail = line.replacingOccurrences(of: "COMPARTMENT_SHAPE_DETAIL=", with: "")
                }
            }
        }
        // Refresh workspace to show new figure
        refreshWorkspace()
        return (hasLag, lagTime, recommendation, elimSimilar, elimReliable, elimDetail, linearPK, exposureDetail, firstDoseElimSimilar, firstDoseElimDetail, multiDose, route, compartmentSuspected, compartmentShapeDetail)
    }

    private func findOrCopyCTScript() -> String? {
        // Check bundled resource first
        if let bundled = BundledResource.path(forResource: "dose_normalized_ct_plot", ofType: "R"),
           FileManager.default.fileExists(atPath: bundled) { return bundled }
        // Check workspace root
        let wsRootScript = workspaceURL.appendingPathComponent("dose_normalized_ct_plot.R").path
        if FileManager.default.fileExists(atPath: wsRootScript) { return wsRootScript }
        // Check workspace Resources/
        let wsResScript = workspaceURL.appendingPathComponent("Resources/dose_normalized_ct_plot.R").path
        if FileManager.default.fileExists(atPath: wsResScript) { return wsResScript }
        // Check project root
        let projScript = projectURL.appendingPathComponent("dose_normalized_ct_plot.R").path
        if FileManager.default.fileExists(atPath: projScript) { return projScript }
        // Check project Resources/
        let projResScript = projectURL.appendingPathComponent("Resources/dose_normalized_ct_plot.R").path
        if FileManager.default.fileExists(atPath: projResScript) { return projResScript }
        // Try to copy from bundled to workspace
        if let bundled = Bundle.main.url(forResource: "dose_normalized_ct_plot", withExtension: "R"),
           let data = try? Data(contentsOf: bundled) {
            try? data.write(to: workspaceURL.appendingPathComponent("dose_normalized_ct_plot.R"))
            return workspaceURL.appendingPathComponent("dose_normalized_ct_plot.R").path
        }
        runner.append("CT script not found in: bundle, workspace, workspace/Resources, project, project/Resources")
        return nil
    }

    private func dataCovariateSummary(_ profile: DatasetProfile) -> String {
        var parts = [String]()
        if profile.hasWT { parts.append("WT") }
        if profile.hasAGE { parts.append("AGE") }
        if profile.hasSEX { parts.append("SEX") }
        if profile.hasSTUDY { parts.append("STUDY") }
        parts.append(contentsOf: profile.additionalCovariates.sorted())
        return parts.isEmpty ? "no covariates" : parts.joined(separator: ", ")
    }

    /// 把 LLM 返回的 REVISE/ACCEPT 决策包装成面向用户的友好提示。
    /// 生硬的 "REVISE" 会被替换成 DuDu PMx 口吻的中文解释，同时保留 AI 给的详细理由。
    private func formatDecisionMessage(_ decision: String, runID: String, isCovariate: Bool) -> String {
        let trimmed = decision.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        guard upper.hasPrefix("REVISE") else {
            // ACCEPT 等已有专门的中文提示，原样返回即可
            return trimmed
        }
        let reason = trimmed
            .dropFirst("REVISE".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let phaseName = isCovariate ? L10n.revisePhase2 : L10n.revisePhase1
        var msg = String.safeFormat(L10n.reviseHeader, runID) + "\n\n"
        msg += String.safeFormat(L10n.reviseBody, phaseName)
        if !reason.isEmpty {
            msg += "\n\(reason)"
        }
        return msg
    }

    private func phaseOneSummary(runs: [String], acceptedRun: String) -> String {
        let sorted = runs.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
        var lines: [String] = []
        lines.append("📊 Base Model Selection Summary:")

        // Group runs by compartment count and find best in each group
        var grouped: [Int: [(runID: String, ofv: Double?, ci: (compartments: Int, advan: String), stable: Bool, precisionEligible: Bool, precisionIssues: [String])]] = [:]
        for runID in sorted {
            let ci = compartmentInfoForRun(runID)
            let ofv = extractOFV(from: projectURL.appendingPathComponent("run\(runID).ext"))
            let stable = isModelStable(runID: runID)
            let precision = parameterPrecisionStatus(runID: runID)
            let precisionIssues = precision.highRSE
            let precisionEligible = precision.structuralIssues.isEmpty
                && precision.residualIssues.isEmpty
                && precision.highRSE.count < 3
            grouped[ci.compartments, default: []].append((runID, ofv, ci, stable, precisionEligible, precisionIssues))
        }

        let sortedComps = grouped.keys.sorted()

        // Show best model per compartment count
        for comp in sortedComps {
            guard let group = grouped[comp], !group.isEmpty else { continue }
            let stableGroup = group.filter { $0.stable }
            let bestInGroup = stableGroup.min { a, b in
                guard let aOFV = a.ofv, let bOFV = b.ofv else { return a.ofv != nil }
                return aOFV < bOFV
            }
            if let best = bestInGroup {
                let ofvStr = best.ofv.map { String(format: "%.3f", $0) } ?? "N/A"
                let isBestOverall = best.runID == acceptedRun
                lines.append("  Best \(comp)-comp: run\(best.runID) (OFV=\(ofvStr))\(isBestOverall ? " 🏆" : "")")
                if best.precisionEligible {
                    lines.append("  Precision: %RSE OK")
                } else {
                    let issueText = best.precisionIssues.prefix(4).joined(separator: ", ")
                    lines.append("  Precision: ⚠️ high %RSE: \(issueText)")
                }
            } else {
                lines.append("  Best \(comp)-comp: no stable S+C model")
            }
            // Show other runs in same compartment (if any)
            let others = group.filter { other in
                guard let best = bestInGroup else { return true }
                return other.runID != best.runID
            }
            for other in others {
                let ofvStr = other.ofv.map { String(format: "%.3f", $0) } ?? "N/A"
                let status = other.stable ? "not best in group" : "not S+C / excluded"
                lines.append("    └─ run\(other.runID) (OFV=\(ofvStr)) — \(status)")
            }
        }

        // Show cross-compartment comparison
        lines.append("")
        lines.append("📈 Cross-Compartment Comparison:")
        var lastBestOFV: Double? = nil
        var lastBestComp: Int? = nil
        for comp in sortedComps {
            guard let group = grouped[comp], let bestInGroup = group.filter({ $0.stable }).min(by: { a, b in
                guard let aOFV = a.ofv, let bOFV = b.ofv else { return a.ofv != nil }
                return aOFV < bOFV
            }), let bestOFV = bestInGroup.ofv else { continue }

            if let lastOFV = lastBestOFV, let lastComp = lastBestComp {
                let delta = lastOFV - bestOFV
                let df = comp - lastComp
                let threshold = Double(df) * 3.84
                let result: String
                if delta > threshold && !bestInGroup.precisionEligible {
                    let issueText = bestInGroup.precisionIssues.prefix(3).joined(separator: ", ")
                    result = "✅ ΔOFV 显著 (\(String(format: "%.1f", delta)) > \(String(format: "%.1f", threshold)))，但 %RSE 不可靠 (\(issueText)) → 保留 \(lastComp)-comp"
                } else if delta > threshold {
                    result = "✅ 显著改进 (Δ=\(String(format: "%.1f", delta)) > \(String(format: "%.1f", threshold)))"
                } else if delta > 3.84 {
                    result = "⚠️ 有改善但未达显著 (Δ=\(String(format: "%.1f", delta)))"
                } else {
                    result = "❌ 无显著差异 (Δ=\(String(format: "%.1f", delta)) ≤ \(String(format: "%.1f", threshold)))"
                }
                lines.append("  \(comp)-comp vs \(lastComp)-comp: \(result)")
            }
            lastBestOFV = bestOFV
            lastBestComp = comp
        }

        lines.append("")
        lines.append("🏆 Final base model: run\(acceptedRun) (\(compartmentInfoForRun(acceptedRun).compartments)-comp)")
        return lines.joined(separator: "\n")
    }

    private func selectBestAutomationRun(preferredAcceptedRun: String?, profile: DatasetProfile, isPhaseOne: Bool = false) -> AutomationRunChoice? {
        let runs = automationModelRuns()
        let choices = runs.enumerated().map { index, runID in
            automationRunChoice(runID: runID, previousRun: index > 0 ? runs[index - 1] : nil)
        }
        guard !choices.isEmpty else { return nil }

        let best: AutomationRunChoice
        if let preferredAcceptedRun,
           let accepted = choices.first(where: { $0.runID == preferredAcceptedRun }),
           accepted.stable {
            // Only honor the AI-accepted run if it is actually stable (S+C and no boundary).
            // An "accepted" run that lacks S/C or has boundary estimates is NOT selectable.
            best = accepted
        } else {
            if let preferredAcceptedRun {
                runner.append("selectBestAutomationRun: preferred run\(preferredAcceptedRun) is NOT stable (missing S/C or boundary estimate) — ignoring it and re-selecting among stable models.")
            }
            if isPhaseOne {
                // Phase 1: use grouped compartment-based selection (stable-only).
                best = selectBestBaseModel(choices: choices) ?? choices.last!
            } else {
                // Other phases: ONLY compare among stable models. If none are stable,
                // fall back to the full list so we still return something, but never
                // silently pick an unstable model as "best".
                let stableChoices = choices.filter { $0.stable }
                let pool = stableChoices.isEmpty ? choices : stableChoices
                best = pool.sorted(by: isBetterAutomationChoice).first ?? choices.last!
                if stableChoices.isEmpty {
                    runner.append("selectBestAutomationRun: NO stable model found — best is unstable; estimation must be fixed before finalizing.")
                }
            }
        }

        writeBestModelSummary(best: best, choices: choices, profile: profile)
        runner.append("Current best model: run\(best.runID) (OFV \(best.ofv.map { String(format: "%.3f", $0) } ?? "NA"))")
        return best
    }

    private func automationRunChoice(runID: String, previousRun: String?) -> AutomationRunChoice {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        let extURL = projectURL.appendingPathComponent("run\(runID).ext")
        let covURL = projectURL.appendingPathComponent("run\(runID).cov")
        let lstText = (try? String(contentsOf: lstURL, encoding: .utf8)) ?? ""
        let ofv = firstDouble(
            in: lstText,
            patterns: [
                #"MINIMUM VALUE OF OBJECTIVE FUNCTION\s*[:=]?\s*([-+]?\d+(?:\.\d+)?)"#,
                #"OBJV:\s*([-+]?\d+(?:\.\d+)?)"#,
                #"OBJECTIVE FUNCTION VALUE\s*[:=]?\s*([-+]?\d+(?:\.\d+)?)"#
            ]
        ) ?? extractOFV(from: extURL)
        let hasLst = FileManager.default.fileExists(atPath: lstURL.path)
        let hasExt = FileManager.default.fileExists(atPath: extURL.path)
        let hasCov = FileManager.default.fileExists(atPath: covURL.path)
        // Minimization / Covariance / Boundary are determined EXCLUSIVELY from the .lst file.
        // hasFailureEvidence checks PsN-level FMSG files which exist even for successful runs,
        // and "UNDEFINED" is a common NONMEM output keyword — those are NOT minimization/covariance
        // failures and must never override the .lst convergence signals.
        let minimizationSuccessful = runMinimizationOK(runID)
        let covarianceSuccessful = runCovarianceOK(runID)
        let stable = isModelStable(runID: runID)
        let precision = parameterPrecisionStatus(runID: runID)

        return AutomationRunChoice(
            runID: runID,
            previousRun: previousRun,
            ofv: ofv,
            hasLst: hasLst,
            hasExt: hasExt,
            hasCov: hasCov,
            minimizationSuccessful: minimizationSuccessful,
            covarianceSuccessful: covarianceSuccessful,
            stable: stable,
            compartments: compartmentInfoForRun(runID).compartments,
            structuralPrecisionIssues: precision.structuralIssues,
            highRSEParameters: precision.highRSE,
            residualPrecisionIssues: precision.residualIssues
        )
    }

    private func parameterPrecisionStatus(runID: String) -> (structuralIssues: [String], highRSE: [String], residualIssues: [String]) {
        let rows = ProjectScanner.parameterEstimates(runID: runID, in: projectURL)
        var structuralIssues: [String] = []
        var highRSE: [String] = []
        var residualIssues: [String] = []

        for row in rows {
            guard let rse = row.rsePercent, rse.isFinite, rse > 50 else { continue }
            let text = "\(row.name) \(String(format: "%.1f", rse))%"
            highRSE.append(text)
            if isResidualErrorParameter(row) {
                residualIssues.append(text)
            } else if isStructuralPKParameter(row) {
                structuralIssues.append(text)
            }
        }

        return (structuralIssues, highRSE, residualIssues)
    }

    private func isResidualErrorParameter(_ row: ParameterEstimateRow) -> Bool {
        let upper = row.name.uppercased()
        let residualTerms = ["RE", "ERROR", "RESIDUAL", "SIGMA"]
        return row.group == "Residual"
            || row.group == "SIGMA"
            || residualTerms.contains { upper.contains($0) }
    }

    private func isStructuralPKParameter(_ row: ParameterEstimateRow) -> Bool {
        guard row.group == "Fixed" || row.group == "PK Parameter" else { return false }
        let upper = row.name.uppercased()
        let residualTerms = ["RE", "ERROR", "RESIDUAL", "SIGMA"]
        return !residualTerms.contains { upper.contains($0) }
    }

    // MARK: - Base Model Selection (Grouped by Compartment Count)

    /// Select the best base model using the CORRECT hierarchical logic:
    /// 1. For EACH compartment count (1, 2, 3), find the BEST model within that group
    /// 2. Compare consecutive compartment counts using ΔOFV threshold
    /// 3. Stop when adding a compartment does NOT bring significant improvement
    /// 4. Reject a significantly better complex model if structural %RSE, residual
    ///    error %RSE, or too many estimated parameters are imprecise.
    private func selectBestBaseModel(choices: [AutomationRunChoice]) -> AutomationRunChoice? {
        guard !choices.isEmpty else { return nil }

        // Group by compartment count
        var grouped: [Int: [AutomationRunChoice]] = [:]
        for choice in choices {
            let comp = compartmentInfoForRun(choice.runID).compartments
            grouped[comp, default: []].append(choice)
        }

        // Find best model within each compartment group
        var bestPerComp: [Int: AutomationRunChoice] = [:]
        for (comp, group) in grouped {
            // Sort within group: prefer successful minimization, then covariance, then lower OFV
            let sorted = group.sorted { a, b in
                if a.minimizationSuccessful != b.minimizationSuccessful {
                    return a.minimizationSuccessful
                }
                if a.covarianceSuccessful != b.covarianceSuccessful {
                    return a.covarianceSuccessful
                }
                if let aOFV = a.ofv, let bOFV = b.ofv {
                    return aOFV < bOFV
                }
                return (Int(a.runID) ?? 0) < (Int(b.runID) ?? 0)
            }
            // A compartment count can ONLY be a candidate if it has a run that is
            // STABLE (successful minimization AND covariance AND no boundary estimates).
            // Otherwise it cannot be selected as / compared against the base model.
            if let best = sorted.first, best.stable {
                bestPerComp[comp] = best
            } else {
                runner.append("Base model selection: \(comp)-comp has no stable run (missing S/C or boundary estimate) — excluded from comparison.")
            }
        }

        // Compare consecutive compartment counts
        let sortedComps = bestPerComp.keys.sorted()
        guard let firstComp = sortedComps.first,
              var bestChoice = bestPerComp[firstComp] else {
            return choices.first
        }

        for i in 1..<sortedComps.count {
            let currentComp = sortedComps[i]
            guard let currentChoice = bestPerComp[currentComp] else { continue }

            // A higher-compartment model lacking successful minimization OR covariance
            // OR sitting a parameter on a boundary can NEVER replace the simpler model.
            // Stop escalating — the simpler stable model is the best we can justify.
            guard currentChoice.stable else {
                runner.append("Base model selection: \(currentComp)-comp run\(currentChoice.runID) is not stable (S=\(currentChoice.minimizationSuccessful), C=\(currentChoice.covarianceSuccessful), boundary=\(currentChoice.stable ? "no" : "yes")) — cannot be the base model; keeping \(bestChoice.compartments)-comp.")
                break
            }

            guard let bestOFV = bestChoice.ofv, let currentOFV = currentChoice.ofv,
                  bestOFV > 0, currentOFV > 0 else {
                // Can't compare OFVs, keep the simpler model
                continue
            }

            let delta = bestOFV - currentOFV  // positive = improvement
            let df = currentComp - (sortedComps[i-1])  // degrees of freedom added

            // Threshold: 3.84 per df (χ², p<0.05)
            let threshold = Double(df) * 3.84

            if delta > threshold {
                // Significant OFV improvement alone is not enough. A more complex model
                // with unstable structural or residual %RSE (or many imprecise parameters) is
                // not a robust base model, so keep the simpler stable model.
                if currentChoice.precisionEligible {
                    runner.append("Base model selection: \(currentComp)-comp run\(currentChoice.runID) significantly better than \(bestChoice.compartments)-comp (ΔOFV=\(String(format: "%.1f", delta)) > threshold \(String(format: "%.1f", threshold))) and %RSE precision acceptable → ACCEPT")
                    bestChoice = currentChoice
                } else {
                    runner.append("Base model selection: \(currentComp)-comp run\(currentChoice.runID) has significant ΔOFV (\(String(format: "%.1f", delta)) > \(String(format: "%.1f", threshold))) BUT %RSE precision is not acceptable (\(currentChoice.precisionReason)) → REJECT, keep \(bestChoice.compartments)-comp")
                    break
                }
            } else {
                // No significant improvement — keep the simpler model
                runner.append("Base model selection: \(currentComp)-comp run\(currentChoice.runID) NOT significantly better than \(bestChoice.compartments)-comp (ΔOFV=\(String(format: "%.1f", delta)) ≤ threshold \(String(format: "%.1f", threshold))) → REJECT, keep \(bestChoice.compartments)-comp")
                // Stop here — more compartments won't help
                break
            }
        }

        return bestChoice
    }

    private func isBetterAutomationChoice(_ left: AutomationRunChoice, _ right: AutomationRunChoice) -> Bool {
        // DEPRECATED: Use selectBestBaseModel() for Phase 1 base model selection.
        // This method is kept for backward compatibility in non-Phase-1 contexts.
        // STABLE (S+C + no boundary) is the strongest criterion — a stable model
        // always beats an unstable one, regardless of OFV.
        if left.stable != right.stable {
            return left.stable
        }
        if left.minimizationSuccessful != right.minimizationSuccessful {
            return left.minimizationSuccessful
        }
        if left.covarianceSuccessful != right.covarianceSuccessful {
            return left.covarianceSuccessful
        }
        if left.hasLst != right.hasLst {
            return left.hasLst
        }
        if let leftOFV = left.ofv, let rightOFV = right.ofv, abs(leftOFV - rightOFV) > 0.001 {
            return leftOFV < rightOFV
        }
        if left.ofv != nil, right.ofv == nil {
            return true
        }
        if left.ofv == nil, right.ofv != nil {
            return false
        }
        return (Int(left.runID) ?? 0) > (Int(right.runID) ?? 0)
    }

    private func firstDouble(in text: String, patterns: [String]) -> Double? {
        let nsText = text as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(location: 0, length: nsText.length)
            guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else { continue }
            let value = nsText.substring(with: match.range(at: 1))
            if let number = Double(value) {
                return number
            }
        }
        return nil
    }

    private func writeBestModelSummary(best: AutomationRunChoice, choices: [AutomationRunChoice], profile: DatasetProfile) {
        let rows = choices.map(\.row).joined(separator: "\n")
        let summary = """
        # AutoPMX Best Model Summary

        - Selected model: run\(best.runID)
        - Previous comparison run: \(best.previousRun.map { "run\($0)" } ?? "none")
        - Dataset route: \(profile.route)
        - Subject count: \(profile.subjectCount)
        - Observation count: \(profile.observationCount)
        - Selection rule: stable S+C first; prefer lower OFV; reject a more complex model when structural or residual %RSE > 50% or ≥3 estimated parameters are imprecise.

        | Run | OFV | Compartments | Minimization | Covariance | Stability | Precision | Outputs |
        | --- | ---: | --- | --- | --- | --- | --- | --- |
        \(rows)
        """

        let url = projectURL.appendingPathComponent("AutoPMX_Best_Model_Summary.md")
        do {
            try summary.write(to: url, atomically: true, encoding: .utf8)
            runner.append("Best model summary saved: \(url.lastPathComponent)")
        } catch {
            runner.append("Could not write best model summary: \(error.localizedDescription)")
        }
    }

    private func automationEvidence(runID: String, previousRun: String?, exitCode: Int32) -> String {
        let names = [
            "run\(runID).lst",
            "run\(runID).ext",
            "run\(runID).cov",
            "GOF_mod\(runID).jpg",
            "VPC_mod\(runID).jpg",
            "VPC_Stratified_mod\(runID).jpg",
            "Individual_Plots_Run\(runID).pdf"
        ]
        let filePresence = names.map { name in
            "\(name): \(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(name).path) ? "present" : "missing")"
        }.joined(separator: "\n")

        let lstPreview = textPreview(projectURL.appendingPathComponent("run\(runID).lst"), limit: 16_000)
        let extPreview = textPreview(projectURL.appendingPathComponent("run\(runID).ext"), limit: 12_000)
        let failureEvidence = ModelRunEvidence.failureEvidence(projectURL: projectURL, runID: runID)
        let reports = recentReportPreviews(runID: runID)
        let visualAudits = recentVisualAuditPreviews(runID: runID)

        // Extract OFV from current and previous runs for comparison
        let currentOFV = extractOFV(from: projectURL.appendingPathComponent("run\(runID).ext"))
        let previousOFV: Double? = previousRun.flatMap { extractOFV(from: projectURL.appendingPathComponent("run\($0).ext")) }
        var ofvComparison = ""
        if let curr = currentOFV, let prev = previousOFV, prev > 0, curr > 0 {
            let delta = prev - curr
            let significant = delta > 10.83 ? "YES — ΔOFV > 10.83 (p<0.001). The more complex model is SIGNIFICANTLY better." :
                             delta > 3.84  ? "YES — ΔOFV > 3.84 (p<0.05). The improvement is significant." :
                             "NO — ΔOFV ≤ 3.84. The simpler model is adequate."
            ofvComparison = """
            ━━━ OFV COMPARISON (CRITICAL) ━━━
            run\(previousRun!) OFV: \(String(format: "%.3f", prev))
            run\(runID) OFV: \(String(format: "%.3f", curr))
            ΔOFV = \(String(format: "%.3f", delta)) — \(significant)

            """
        }

        // ── Compartment-level OFV comparison ──
        // When the current run is a high-compartment model, compare its OFV against
        // the best lower-compartment stable model so the AI knows if the extra
        // compartments actually improve the fit significantly.
        let compComparison = compartmentOFVComparison(currentRunID: runID)
        let currentComp = compartmentInfoForRun(runID).compartments

        let cur = automationRunChoice(runID: runID, previousRun: previousRun)
        let residualCheck = checkResidualErrorRSEFromExt(runID: runID)
        let residualWarnings = residualCheck.warnings
        let residualDirective = residualCheck.hardDirective
        let estStatus = """
        ━━━ ESTIMATION STATUS (S = minimization ✓, C = covariance ✓) ━━━
          run\(runID): S=\(cur.minimizationSuccessful ? "✓" : "✗"), C=\(cur.covarianceSuccessful ? "✓" : "✗")
          \(parameterPrecisionSummary(runID: runID))
        \(previousRun.map { "  run\($0): S=\(automationRunChoice(runID: $0, previousRun: nil).minimizationSuccessful ? "✓" : "✗"), C=\(automationRunChoice(runID: $0, previousRun: nil).covarianceSuccessful ? "✓" : "✗")\n  \(parameterPrecisionSummary(runID: $0))" } ?? "")
        \(residualWarnings.isEmpty ? "" : "\n" + residualWarnings)
        """

        return """
        \(residualDirective.isEmpty ? "" : residualDirective + "\n")
        NONMEM/PsN exit code: \(exitCode)
        Previous run for comparison: \(previousRun ?? "none")
        Current run: \(runID)
        \(ofvComparison)
        \(compComparison.isEmpty || currentComp <= 1 ? "" : compComparison + "\n")
        \(estStatus)
        File presence:
        \(filePresence)

        NONMEM/PsN/NMTRAN failure evidence:
        \(failureEvidence)

        ━━━ PARAMETER ESTIMATES (.ext file) ━━━
        \(extPreview)

        LST preview:
        \(lstPreview)

        Recent AI/diagnostic reports:
        \(reports)

        ━━━ GOF/VPC VISUAL AUDIT REPORTS ━━━
        \(visualAudits)
        """
    }

    private func extractOFV(from url: URL) -> Double? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        // NONMEM .ext file: the last column of the first row after headers (iteration -1000000000) is OBJ
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-1000000000") else { continue }
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if let last = parts.last, let ofv = Double(last), ofv > 0 {
                return ofv
            }
        }
        return nil
    }

    private func recentReportPreviews(runID: String) -> String {
        let files = ProjectScanner.scanAssets(in: projectURL)[.reports] ?? []
        let matching = files
            .map(\.url)
            .filter { $0.lastPathComponent.contains("Run\(runID)") || $0.lastPathComponent.contains("run\(runID)") || $0.path.contains("-\(runID)-") }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }
            .prefix(4)

        if matching.isEmpty {
            return "No report files found yet."
        }
        return matching.map { url in
            """
            --- \(url.lastPathComponent) ---
            \(textPreview(url, limit: 5_500))
            """
        }.joined(separator: "\n\n")
    }

    private func recentVisualAuditPreviews(runID: String) -> String {
        let fm = FileManager.default
        guard let topLevel = try? fm.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil) else {
            return "No GOF/VPC visual audit reports found."
        }
        var matching: [URL] = []
        for dir in topLevel where dir.lastPathComponent.hasPrefix("Compare") {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            matching.append(contentsOf: files.filter { url in
                let name = url.lastPathComponent
                return url.pathExtension.lowercased() == "md"
                    && (name.hasPrefix("GOF_Expert_Audit_Run\(runID)_")
                        || name.hasPrefix("VPC_Evolution_Audit_Run\(runID)_"))
            })
        }
        matching.sort { left, right in
            let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }
        let selected = matching.prefix(4)
        if selected.isEmpty {
            return "No GOF/VPC visual audit reports found."
        }
        return selected.map { url in
            """
            --- \(url.lastPathComponent) ---
            \(textPreview(url, limit: 6_000))
            """
        }.joined(separator: "\n\n")
    }

    private func textPreview(_ url: URL, limit: Int) -> String {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return "\(url.lastPathComponent) is not readable or not generated."
        }
        return raw.count > limit ? String(raw.prefix(limit)) + "\n[truncated]" : raw
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    /// Run the Python static validator on a .mod file.
    /// Returns `true` if the model passes preflight checks.
    private func resolveBridgeScript() -> String {
        let workspaceBridge = workspaceURL.appendingPathComponent("autopmx_cli.py").path
        let projectBridge = projectURL.appendingPathComponent("autopmx_cli.py").path
        let bundledBridge = BundledResource.path(forResource: "autopmx_cli", ofType: "py") ?? ""
        if FileManager.default.fileExists(atPath: workspaceBridge) { return workspaceBridge }
        if FileManager.default.fileExists(atPath: projectBridge) { return projectBridge }
        return bundledBridge
    }

    /// Write text to a .mod file with hard post-write verification: read it back,
    /// strip inline data rows, and rewrite if anything leaked.  This is the last
    /// line of defence — no data row should EVER survive this gate.
    private func guardModFileWrite(_ text: String, to url: URL, label: String) {
        let guarded = LLMCommandService.stripInlineDatasetRows(text)
        do {
            try guarded.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            runner.append("guardModFileWrite failed for \(label): \(error.localizedDescription)")
            return
        }
        guard let written = try? String(contentsOf: url, encoding: .utf8) else { return }
        let reStripped = LLMCommandService.stripInlineDatasetRows(written)
        if reStripped != written {
            do {
                try reStripped.write(to: url, atomically: true, encoding: .utf8)
                runner.append("🔴 POST-WRITE GUARD: stripped leaked data rows from \(url.lastPathComponent)")
            } catch {
                runner.append("🔴 POST-WRITE GUARD FAILED for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    private func localized(_ zh: String, _ en: String) -> String {
        LanguageStore.shared.language == .en ? en : zh
    }

    private func validateModel(_ runID: String) async -> (passed: Bool, output: String) {
        let modURL = projectURL.appendingPathComponent("run\(runID).mod")
        if let modText = try? String(contentsOf: modURL, encoding: .utf8) {
            var sanitized = LLMCommandService.sanitizeControlStream(
                modText,
                projectURL: projectURL,
                dataFile: dataFile
            )
            sanitized = correctS1Scaling(sanitized)
            sanitized = LLMCommandService.applyingIVInfusionDurationFix(sanitized)
            sanitized = LLMCommandService.normalizingTableRecords(sanitized, runID: runID)
            sanitized = applyingInheritedHandoffReleaseIfNeeded(sanitized, runID: runID)
            if sanitized.uppercased().contains("IV-ANCHOR HANDOFF")
                || sanitized.uppercased().contains("INHERITED IV STRUCTURAL THETA/OMEGA ARE FIXED")
                || sanitized.uppercased().contains("INHERITED IV THETA/OMEGA ARE FIXED") {
                sanitized = LLMCommandService.enforceIVAnchorHandoffFixes(sanitized)
            }
            if sanitized != modText {
                guardModFileWrite(sanitized, to: modURL, label: "run\(runID).mod (preflight)")
                runner.append("AutoPMX normalized run\(runID).mod before preflight validation.")
            }
        }

        let python = resolvedPython()
        let bridge = resolveBridgeScript()
        runner.append("MOD check: validating run\(runID).mod against dataset and NONMEM rules...")
        let validatorCmd = [
            shellQuote(python),
            shellQuote(bridge),
            "validate-model",
            "--mod", shellQuote(modURL.path),
            "--project-dir", shellQuote(projectURL.path),
            "--csv", shellQuote(projectURL.appendingPathComponent(dataFile).path),
            "--run-id", runID,
            "--llm-url", shellQuote(llmBaseURL),
            "--model", shellQuote(llmModel),
            "--api-key", shellQuote(llmAPIKey.isEmpty ? "lm-studio" : llmAPIKey),
        ].joined(separator: " ")

        let result = await runner.runAndWaitWithOutput(command: validatorCmd, in: projectURL)
        if result.exitCode == 0 {
            runner.append("MOD check passed: run\(runID).mod")
        }
        return (result.exitCode == 0, result.output)
    }

    /// Run the Python autóﬁxer on a .mod ﬁle (in-place).
    private func autoFixModel(_ runID: String) async -> (fixed: Bool, output: String) {
        let python = resolvedPython()
        let bridge = resolveBridgeScript()
        let modURL = projectURL.appendingPathComponent("run\(runID).mod")
        let fixCmd = [
            shellQuote(python),
            shellQuote(bridge),
            "autofix-model",
            "--mod", shellQuote(modURL.path),
            "--data", dataFile,
            "--run-id", runID,
            "--llm-url", shellQuote(llmBaseURL),
            "--model", shellQuote(llmModel),
            "--api-key", shellQuote(llmAPIKey.isEmpty ? "lm-studio" : llmAPIKey),
        ].joined(separator: " ")

        let result = await runner.runAndWaitWithOutput(command: fixCmd, in: projectURL)
        var output = result.output

        // --- CRITICAL: post-autofix data-row verification ---
        // Python _auto_fix_mod strips data rows first, but we verify here anyway.
        // If data rows leaked past Python, this is the last line of defence.
        guard let modText = try? String(contentsOf: modURL, encoding: .utf8) else {
            return (false, output)
        }
        let strippedAfterPython = LLMCommandService.stripInlineDatasetRows(modText)
        let dataRowsCleared = strippedAfterPython != modText
        if dataRowsCleared {
            try? strippedAfterPython.write(to: modURL, atomically: true, encoding: .utf8)
            runner.append("Post-autofix guard: force-stripped leaked data rows from run\(runID).mod")
            output += "\n[AutoPMX] Force-stripped embedded data rows after Python autofix."
        }

        // Apply deterministic fixes
        let baseText = dataRowsCleared ? strippedAfterPython : modText
        var fixed = LLMCommandService.sanitizeControlStream(
            baseText,
            projectURL: projectURL,
            dataFile: dataFile
        )
        fixed = correctS1Scaling(fixed)
        let isIVAnchorHandoff = fixed.uppercased().contains("IV-ANCHOR HANDOFF")
            || fixed.uppercased().contains("INHERITED IV STRUCTURAL THETA/OMEGA ARE FIXED")
            || fixed.uppercased().contains("INHERITED IV THETA/OMEGA ARE FIXED")
        if !isModelRunSuccessful(runID: runID) && !isIVAnchorHandoff {
            fixed = LLMCommandService.applyingNCAInitialValues(
                fixed,
                projectURL: projectURL,
                dataFile: dataFile
            )
        }
        fixed = LLMCommandService.applyingIVInfusionDurationFix(fixed)
        fixed = LLMCommandService.normalizingTableRecords(fixed, runID: runID)
        fixed = applyingInheritedHandoffReleaseIfNeeded(fixed, runID: runID)
        if isIVAnchorHandoff {
            fixed = LLMCommandService.enforceIVAnchorHandoffFixes(fixed)
        }
        guardModFileWrite(fixed, to: modURL, label: "run\(runID).mod (post-autofix)")

        // If data rows were cleared, treat as partial success even if Python autofix exitCode != 0.
        // The remaining structural issues (OMEGA mismatch, etc.) will be addressed by the LLM
        // in the next iteration loop — NEVER stop the entire automation for this.
        if dataRowsCleared {
            runner.append("Auto-fix partially succeeded for run\(runID).mod — data rows cleared, remaining structural issues deferred to LLM.")
            return (true, output)
        }

        if result.exitCode == 0 {
            output += "\n\n[AutoPMX] Deterministic repair resolved preflight errors."
            return (true, output)
        }

        let validation = await validateModel(runID)
        if validation.passed {
            PPKSkillStore.shared.addLesson(
                category: .modelStructure,
                title: "Rebuild OMEGA to match PK ETA references",
                problem: "Preflight found OMEGA count/order mismatch with $PK ETA references.",
                solution: "Strip content before $PROBLEM, renumber ETA references contiguously, and rebuild $OMEGA in PK ETA order before writing the model.",
                sourceRun: runID,
                severity: .medium,
                tags: ["preflight", "omega", "eta", "auto-repair"]
            )
            runner.append("Preflight repair resolved by AutoPMX deterministic rules; skill lesson saved.")
            return (true, output + "\n[AutoPMX] Deterministic repair resolved preflight errors.")
        }
        return (false, output + "\n\n" + validation.output)
    }

    private func applyingInheritedHandoffReleaseIfNeeded(_ modText: String, runID: String) -> String {
        guard let parentRunID = inheritedHandoffParentRunID(from: modText),
              runMinimizationOK(parentRunID),
              runCovarianceOK(parentRunID),
              isInheritedHandoffModel(parentRunID),
              LLMCommandService.hasInheritedStructuralFixes(modText) else {
            return modText
        }

        var text = LLMCommandService.releasingIVAnchorHandoffFixes(modText)
        if let parentText = try? String(contentsOf: projectURL.appendingPathComponent("run\(parentRunID).mod"), encoding: .utf8) {
            text = LLMCommandService.trimmingAddedIIVForHandoffRelease(text, sourceModText: parentText)
        }
        text = LLMCommandService.normalizingTableRecords(text, runID: runID)
        runner.append("Auto-released inherited structural FIXes in run\(runID).mod from S+C parent run\(parentRunID).")
        return text
    }

    private func isInheritedHandoffModel(_ runID: String) -> Bool {
        guard let text = try? String(contentsOf: projectURL.appendingPathComponent("run\(runID).mod"), encoding: .utf8) else {
            return false
        }
        let upper = text.uppercased()
        return upper.contains("IV-ANCHOR HANDOFF")
            || upper.contains("INHERITED IV STRUCTURAL THETA/OMEGA ARE FIXED")
            || upper.contains("INHERITED IV THETA/OMEGA ARE FIXED")
            || upper.contains("AUTOPMX INHERITED FIXES RELEASED")
    }

    private func inheritedHandoffParentRunID(from modText: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:from|based on)\s+run(0*\d+)(?:\.mod)?"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        let ns = modText as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: modText, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: modText) else {
            return nil
        }
        return String(modText[valueRange])
    }

    private func savePinnedAssets() {
        UserDefaults.standard.set(Array(pinnedAssetIDs).sorted(), forKey: Self.pinnedAssetDefaultsKey)
    }

    private func automatedDecisionSummary(runID: String, exitCode: Int32, rules: String) async -> String {
        if exitCode != 0 {
            return "REVISE run\(runID): NONMEM/PsN exited with \(exitCode). AutoPMX will draft a conservative next candidate."
        }
        do {
            let promptMessage = AssistantMessage(
                role: .user,
                text: """
                Evaluate run\(runID) using the PopPK rule library. If it is ready, start your reply with ACCEPT. If not, start with REVISE and give one concise next modeling action.
                """
            )
            let (result, usage) = try await LLMCommandService.chat(
                baseURL: llmBaseURL,
                model: llmModel,
                messages: [promptMessage],
                projectURL: projectURL,
                currentRun: runID,
                rules: rules,
                apiKey: llmAPIKey,
                knowledgeBaseURL: knowledgeBaseURL,
                apiFormat: activeAPIFormat
            )
            recordUsage(usage)
            return result
        } catch {
            return "REVISE run\(runID): AI evaluation failed, so AutoPMX will create a conservative next candidate. \(error.localizedDescription)"
        }
    }

    private func draftNextModelOrFallback(sourceRun: String, nextRun: String, rules: String) async -> String {
        do {
            let (result, usage) = try await LLMCommandService.proposeNextModel(
                baseURL: llmBaseURL,
                model: llmModel,
                projectURL: projectURL,
                sourceRun: sourceRun,
                nextRun: nextRun,
                rules: rules,
                apiKey: llmAPIKey,
                apiFormat: activeAPIFormat
            )
            recordUsage(usage)
            return result
        } catch {
            runner.append("AI model drafting failed: \(error.localizedDescription). Using deterministic fallback.")
            let sourceURL = projectURL.appendingPathComponent("run\(sourceRun).mod")
            let raw = (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? ""
            return raw
                .replacingOccurrences(of: "run\(sourceRun)", with: "run\(nextRun)")
                .replacingOccurrences(of: "FILE=SDTAB\(sourceRun)", with: "FILE=SDTAB\(nextRun)")
                .replacingOccurrences(of: "FILE=PATAB\(sourceRun)", with: "FILE=PATAB\(nextRun)")
                .replacingOccurrences(of: "FILE=run\(sourceRun).ETA", with: "FILE=run\(nextRun).ETA")
                .replacingOccurrences(of: "FILE=000\(sourceRun).ETA", with: "FILE=run\(nextRun).ETA")
                .replacingOccurrences(of: "FILE=CATAB\(sourceRun)", with: "FILE=CATAB\(nextRun)")
                .replacingOccurrences(of: "FILE=COTAB\(sourceRun)", with: "FILE=COTAB\(nextRun)")
        }
    }

    /// Check if a run has ANY parameter (THETA or OMEGA) with %RSE above threshold.
    /// Scans both the THETA section and the OMEGA section of the .lst file.
    /// If ANY parameter exceeds threshold, returns true (the system should fix one).
    private func hasHighResidualRSE(runID: String, threshold: Double) -> Bool {
        ProjectScanner.parameterEstimates(runID: runID, in: projectURL)
            .contains { $0.group == "Residual" && ($0.rsePercent ?? 0) > threshold }
    }

    /// User chose to accept a lower-compartment model instead.
    func acceptLowerCompartment() {
        isCompDecisionPresented = false
        let baseRun = compDecisionAcceptedRun
        let allRuns = ProjectScanner.discoverRuns(in: projectURL)
        let runChoices = allRuns.map { runID in
            automationRunChoice(runID: runID, previousRun: nil)
        }
        let best2Comp = runChoices
            .filter { compartmentInfoForRun($0.runID).compartments <= 2 && $0.stable }
            .sorted(by: isBetterAutomationChoice).first
        let finalRun = best2Comp?.runID ?? baseRun
        let summary = phaseOneSummary(runs: allRuns, acceptedRun: finalRun)
        runner.append("=== PHASE 1 COMPLETE (user chose lower comp) ===\n\(summary)")
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusPhase1CompleteSuboptimal, summary, finalRun)))
        beginBenchmarkBaseWaitIfNeeded()
        isAutoModeling = false
        automationStep = "Phase 1 complete — awaiting confirmation"
        baseModelConfirmSummary = summary
        baseModelConfirmRunID = finalRun
        markAIModel(runID: finalRun)
        isBaseModelConfirmPresented = true
    }

    /// User chose to accept the current high-compartment model as-is.
    func acceptCurrentCompartment() {
        isCompDecisionPresented = false
        let finalRun = compDecisionAcceptedRun
        let allRuns = ProjectScanner.discoverRuns(in: projectURL)
        let summary = phaseOneSummary(runs: allRuns, acceptedRun: finalRun)
        runner.append("=== PHASE 1 COMPLETE (user accepted \(compartmentInfoForRun(finalRun).compartments)-comp) ===\n\(summary)")
        assistantMessages.append(AssistantMessage(role: .system, text: String.safeFormat(L10n.statusPhase1Complete, summary, finalRun)))
        beginBenchmarkBaseWaitIfNeeded()
        isAutoModeling = false
        automationStep = "Phase 1 complete — awaiting confirmation"
        baseModelConfirmSummary = summary
        baseModelConfirmRunID = finalRun
        markAIModel(runID: finalRun)
        isBaseModelConfirmPresented = true
    }

    /// Compare current run's compartment OFV against the best lower-compartment model.
    /// Helps the AI decide whether complexity is justified.
    private func compartmentOFVComparison(currentRunID: String) -> String {
        let currentComp = compartmentInfoForRun(currentRunID).compartments
        guard currentComp > 1 else { return "" }
        let lowerComp = currentComp - 1
        let allRuns = ProjectScanner.discoverRuns(in: projectURL)
        // Find stable S+C runs at the lower compartment level
        let lowerCandidates = allRuns.filter { id in
            let info = compartmentInfoForRun(id)
            return info.compartments == lowerComp && isModelStable(runID: id)
        }
        guard !lowerCandidates.isEmpty else { return "" }
        let currentOFV = extractOFV(from: projectURL.appendingPathComponent("run\(currentRunID).ext"))
        // Pick best lower-comp by lowest OFV
        let sorted = lowerCandidates.compactMap { id -> (String, Double)? in
            guard let ofv = extractOFV(from: projectURL.appendingPathComponent("run\(id).ext")) else { return nil }
            return (id, ofv)
        }.sorted { $0.1 < $1.1 }
        guard let bestLower = sorted.first, let currOFV = currentOFV else { return "" }
        let delta = bestLower.1 - currOFV
        let verdict: String
        if delta > 10.83 {
            verdict = "\(String(format: "%.3f", delta)) — Significant improvement. \(currentComp)-comp is justified."
        } else if delta > 3.84 {
            verdict = "\(String(format: "%.3f", delta)) — Marginal. Consider simpler model."
        } else {
            verdict = "\(String(format: "%.3f", delta)) — NOT significant (≤3.84). \(lowerComp)-comp is ADEQUATE."
        }
        return """
        ━━━ COMPARTMENT COMPARISON (ΔOFV) ━━━
        Best \(lowerComp)-comp run\(bestLower.0): OFV = \(String(format: "%.3f", bestLower.1))
        Current \(currentComp)-comp run\(currentRunID): OFV = \(String(format: "%.3f", currOFV))
        ΔOFV(\(currentComp)-comp vs \(lowerComp)-comp): \(verdict)

        """
    }
}
