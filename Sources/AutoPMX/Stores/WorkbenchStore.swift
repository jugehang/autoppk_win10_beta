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
        case .cute: return "嘟嘟本嘟"
        case .concise: return "极简高效"
        case .expert: return "专业学者"
        case .humorous: return "幽默调侃"
        case .custom: return "自定义人设"
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
        case .cute: return "鸭鸭驾到，用可爱的语气回答所有问题，适合心情好的时候～"
        case .concise: return "直奔主题，只给干货，像命令行一样高效。"
        case .expert: return "严谨专业的学术风格，引用文献和数据，适合正式场景。"
        case .humorous: return "毒舌又幽默的药代专家，边抖机灵边帮你建模。"
        case .custom: return "完全由你定义 DuDu 的说话方式和风格，想怎么调教就怎么调教～"
        }
    }

    var welcomeMessage: String {
        switch self {
        case .cute:
            return "呱呱～ 我是 DuDu PMx，一只超爱药代动力学的小鸭子 🦆💊！点击 \"DuDu Auto\" 我可以帮你自动建模哦，或者在下面戳我提问～ 一起探索 PopPK 的奇妙世界吧！"
        case .concise:
            return "DuDu PMx 已就绪。⚡ 高效模式：直接说需求，我会用最短的路径给你结果。自动建模、模型评估、诊断解读，随时可用。"
        case .expert:
            return "DuDu PMx 已就绪。🔬 专业模式：我将以严谨的药代动力学方法学视角，为你提供系统的建模建议、参数解读与诊断分析。请随时提出你的建模需求。"
        case .humorous:
            return "哟，来了啊～ 我是 DuDu PMx 😏 毒舌但靠谱的药代小鸭子。建模翻车了？没事，我帮你把 OFV 从'惨不忍睹'修到'还能看'。尽管问，别玻璃心就行～"
        case .custom:
            return "DuDu PMx 已就绪。🎭 自定义模式：我将按照你设定的风格与你对话。你可以在设置 → Chat 中随时调整我的说话方式～"
        }
    }

    // The actual system prompt personality block — what gets injected into the assistant's system message
    func systemPersonalityBlock(customPrompt: String = "", learnedStyle: String = "") -> String {
        switch self {
        case .cute:
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
    @Published var assets: [AssetCategory: [ProjectAsset]] = [:]
    @Published var recentProjectURLs: [URL] = []
    @Published var selectedAsset: ProjectAsset?
    @Published var pinnedAssetIDs: Set<String> = []
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
    @Published var previousRun = "38"
    @Published var currentRun = "41"
    @Published var dataFile = "NM_dat_new.csv"

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
    @Published var assistantMessages: [AssistantMessage] = [
        AssistantMessage(role: .assistant, text: "呱呱～ 我是 DuDu PMx，一只超爱药代动力学的小鸭子 🦆💊！点击 \"DuDu Auto\" 我可以帮你自动建模哦，或者在下面戳我提问～ 一起探索 PopPK 的奇妙世界吧！")
    ]
    @Published var showSCMDialog = false
    @Published var scmModelRunID = ""
    @Published var scmDataFileName = ""
    @Published var scmPForward = "0.01"       // 前向纳入 p 值: 0.05 / 0.01 / 0.001
    @Published var scmPBackward = "0.001"     // 逆向剔除 p 值: 0.01 / 0.001; ≤ p_forward
    @Published var isSCMRunning = false
    private var scmCancelled = false
    @Published var duDuPersonality: DuDuPersonality = .cute {
        didSet {
            UserDefaults.standard.set(duDuPersonality.rawValue, forKey: Self.duDuPersonalityKey)
            resetAssistantConversation()
        }
    }
    private static let duDuPersonalityKey = "AutoPMX.duDuPersonality.v1"

    // MARK: - Particle effects
    @Published var particleEffectsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(particleEffectsEnabled, forKey: Self.particleEnabledKey) }
    }
    @Published var particleCount: Int = 30 {
        didSet { UserDefaults.standard.set(particleCount, forKey: Self.particleCountKey) }
    }
    private static let particleEnabledKey = "AutoPMX.particleEnabled.v1"
    private static let particleCountKey = "AutoPMX.particleCount.v1"

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

        let prompt = """
        You are a linguistic style analyst. Below are sample messages from a user of a pharmacometrics AI assistant called DuDu PMx.

        Analyze these messages and generate a structured **User Speaking Style Guide** — a skill document that describes how this user speaks, so that DuDu can match their tone when replying.

        Format the output as a clean markdown document:

        ## 用户说话风格档案

        ### 核心语气特征
        (2-4 bullet points summarizing the dominant tone, e.g. casual/formal, warm/direct, playful/serious)

        ### 常用表达
        (specific phrases, pet names, slang they use frequently — note exact Chinese terms)

        ### 标点与节奏
        (how they use punctuation, sentence length preference, paragraph style)

        ### 适配建议
        (how DuDu should adjust its replies — tone, vocabulary level, whether to use emojis, etc.)

        Keep it concise (under 300 words total). Write in Chinese. Focus on actionable adaptation advice.

        User message samples:
        \(samples)
        """

        Task {
            do {
                let report = try await LLMCommandService.chat(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    messages: [AssistantMessage(role: .user, text: prompt)],
                    projectURL: projectURL,
                    currentRun: currentRun,
                    rules: "",
                    apiKey: llmAPIKey,
                    personality: "You are a professional linguistic style analyst. Respond ONLY with the requested markdown document, no extra commentary."
                )
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
        var traits: [String] = []
        if allText.contains("宝贝") || allText.contains("宝宝") { traits.append("喜欢使用亲昵称呼（宝贝、宝宝）") }
        if allText.contains("😂") || allText.contains("哈哈") { traits.append("常用笑声和幽默表达") }
        if allText.contains("牛逼") || allText.contains("厉害") { traits.append("使用网络流行语和夸赞词") }
        let emojiCount = allText.unicodeScalars.filter { $0.properties.isEmojiPresentation }.count
        if emojiCount > 3 { traits.append("频繁使用 emoji（共约\(emojiCount)个）") }

        let lines = traits.isEmpty ? ["暂未检测到显著风格特征，继续聊天后会逐渐学习～"] : traits
        return """
        ## 用户说话风格档案（自动生成）

        ### 检测到的特征
        \(lines.map { "- \($0)" }.joined(separator: "\n"))

        ### 适配建议
        - 匹配用户的语气温度和用词习惯
        - 如果用户用亲昵称呼，可以适当回应
        """
    }

    @Published var assistantInput = ""
    @Published var isAssistantPanelPresented = false
    @Published var isAssistantThinking = false
    @Published var isAutoModeling = false
    @Published var automationStep = "Idle"
    @Published var duDuMood: DuDuMood = .happy
    @Published var lastRunSucceeded: Bool? = nil
    @Published var liveTokenCount: Int = 0
    private var tokenTimer: Timer?
    @Published var isAutomationOptionsPresented = false
    @Published var isBaseModelConfirmPresented = false
    @Published var baseModelConfirmSummary = ""
    @Published var baseModelConfirmRunID = ""
    @Published var automationStartMode: AutomationStartMode = .continueLatest
    @Published var automationStartRunID = ""
    @Published var automationUserGuidance = ""
    @Published var automationStopRequested = false
    @Published var pendingDeleteAsset: ProjectAsset?
    @Published var isDeleteConfirmationPresented = false

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

    init() {
        pinnedAssetIDs = Set(UserDefaults.standard.stringArray(forKey: Self.pinnedAssetDefaultsKey) ?? [])

        // Determine project URL: last opened > demo
        let defaultURL = ProjectScanner.defaultWorkspaceURL()
        let saved: URL? = {
            guard let path = UserDefaults.standard.string(forKey: "AutoPMX.lastProjectPath"),
                  FileManager.default.fileExists(atPath: path) else { return nil }
            return URL(fileURLWithPath: path)
        }()

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
        if nonmemPath.isEmpty { autoDetectNonmemPath() }
        if psnPath.isEmpty { autoDetectPsnPath() }
        if pythonPath.isEmpty { autoDetectPythonPath() }
        if rPath.isEmpty { autoDetectRPath() }

        // Load DuDu personality preference
        if let raw = UserDefaults.standard.string(forKey: Self.duDuPersonalityKey),
           let personality = DuDuPersonality(rawValue: raw) {
            duDuPersonality = personality
        }

        // Load particle effect preferences
        if UserDefaults.standard.object(forKey: Self.particleEnabledKey) != nil {
            particleEffectsEnabled = UserDefaults.standard.bool(forKey: Self.particleEnabledKey)
        }
        if UserDefaults.standard.object(forKey: Self.particleCountKey) != nil {
            let saved = UserDefaults.standard.integer(forKey: Self.particleCountKey)
            if saved > 0 { particleCount = saved }
        }

        // Load custom personality & learning style
        customPersonalityPrompt = UserDefaults.standard.string(forKey: Self.customPersonalityKey) ?? ""
        styleReport = UserDefaults.standard.string(forKey: Self.styleReportKey) ?? ""
        isLearningUserStyle = UserDefaults.standard.bool(forKey: Self.learningEnabledKey)
        loadMessageArchive()

        refreshWorkspace()
    }

    // MARK: - Provider management

    var activeProvider: LLMProviderProfile? {
        providers.first { $0.id == activeProviderID }
    }

    func loadRecentProjects() {
        guard let paths = UserDefaults.standard.stringArray(forKey: Self.recentProjectsKey) else {
            recentProjectURLs = []
            return
        }
        recentProjectURLs = paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: path) ? url : nil
        }
    }

    func saveRecentProject(_ url: URL) {
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
        let saved = LLMProviderProfile.loadProviders()
        if saved.isEmpty {
            providers = LLMProviderProfile.builtInPresets
        } else {
            providers = saved
        }
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
            "/opt/nm750/run/nmfe75",
            "/opt/nm74/run/nmfe74"
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
            "/usr/bin/execute"
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

    func autoDetectPythonPath() {
        let candidates = [
            projectURL.appendingPathComponent(".venv/bin/python3").path,
            workspaceURL.appendingPathComponent(".venv/bin/python3").path,
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

    func refreshWorkspace() {
        let runs = ProjectScanner.discoverRuns(in: projectURL)
        if !runs.isEmpty {
            if !runs.contains(previousRun) {
                previousRun = runs.count > 1 ? runs[runs.count - 2] : runs[0]
            }
            if !runs.contains(currentRun) {
                currentRun = runs.last ?? currentRun
            }
        }

        assets = ProjectScanner.scanAssets(in: projectURL)
        // Only reset the PsN command if it's empty or if the current run changed.
        // Don't overwrite user-edited commands.
        let defaultCommand = ProjectScanner.psnExecuteCommand(runID: currentRun)
        if commandText.isEmpty || !commandText.contains("run\(currentRun)") {
            commandText = defaultCommand
        }
        refreshRuleContextStatus()
        refreshChecks()
        if selectedAsset == nil {
            showOverview()
        }
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

    func activeRuleContext(userGuidance: String = "") -> RuleContext {
        let context = ProjectScanner.ruleContext(projectURL: projectURL, workspaceURL: workspaceURL, sourcesText: ruleSourceFiles)
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

        let executable = commandText.split(separator: " ").first.map(String.init) ?? ""
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
        // Covariance OK as long as R-matrix was computed (STANDARD ERROR OF ESTIMATE present).
        // COVARIANCE STEP ABORTED due to R-matrix non-positive-definite is a warning, not failure.
        covarianceOK = upper.contains("STANDARD ERROR OF ESTIMATE")
        hasBoundaryWarnings = upper.contains("PARAMETER IS NEAR ITS BOUNDARY")
    }

    func activateRun(_ runID: String) {
        currentRun = runID
        commandText = ProjectScanner.psnExecuteCommand(runID: runID)
        refreshChecks()
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

    func createProjectFromCurrentRun(name: String) {
        guard !isAutoModeling else {
            runner.append("⚠️ 自动建模进行中，请勿创建/切换项目。先停止建模。")
            assistantMessages.append(AssistantMessage(role: .system, text: "⚠️ DuDu 自动建模运行中，无法创建新项目。请先停止建模。"))
            return
        }
        do {
            projectURL = try ProjectScanner.createProjectFromRun(
                workspaceURL: workspaceURL,
                sourceURL: projectURL,
                name: name,
                runID: currentRun,
                dataFile: dataFile
            )
            runner.append("Created project: \(projectURL.path)")
            selectedAsset = nil
            refreshWorkspace()
        } catch {
            runner.append("Create project failed: \(error.localizedDescription)")
        }
    }

    func createBlankProject(name: String) {
        guard !isAutoModeling else {
            runner.append("⚠️ 自动建模进行中，请勿创建/切换项目。先停止建模。")
            assistantMessages.append(AssistantMessage(role: .system, text: "⚠️ DuDu 自动建模运行中，无法创建新项目。请先停止建模。"))
            return
        }
        do {
            projectURL = try ProjectScanner.createBlankProject(workspaceURL: workspaceURL, name: name)
            runner.append("Created blank project: \(projectURL.path)")
            selectedAsset = nil
            refreshWorkspace()
        } catch {
            runner.append("Create blank project failed: \(error.localizedDescription)")
        }
    }

    func openProject(url: URL) {
        guard !isAutoModeling else {
            runner.append("⚠️ 自动建模进行中，请勿切换项目！当前模型文件可能写入错误目录。")
            assistantMessages.append(AssistantMessage(role: .system, text: "⚠️ DuDu 自动建模正在运行中，请勿切换项目路径，否则新生成的 mod 文件会写到错误的项目下。先停止建模再切换。"))
            return
        }
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
        refreshWorkspace()
    }

    /// Save PPK Skill before switching/closing project.
    func savePPKSkill() {
        PPKSkillStore.shared.save(to: projectURL)
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
                    apiKey: llmAPIKey
                )
                commandText = command
                runner.append("AI command draft inserted. Review before running.")
                refreshChecks()
            } catch {
                commandText = ProjectScanner.psnExecuteCommand(runID: currentRun)
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
                assistantMessages.append(AssistantMessage(role: .system, text: "LLM 已连接 [\(format.displayName)]。\(modelText)"))
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
        chatTask = Task {
            do {
                let reply = try await LLMCommandService.chat(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    messages: assistantMessages,
                    projectURL: projectURL,
                    currentRun: currentRun,
                    rules: activeRuleContext().text + "\n" + PPKSkillStore.shared.contextBlock(),
                    apiKey: llmAPIKey,
                    personality: activePersonalityBlock
                )
                try Task.checkCancellation()
                assistantMessages.append(AssistantMessage.parse(reply, role: .assistant))
                if isLearningUserStyle { captureUserStyleFromLatestExchange() }
                // Learn from user's modeling instructions
                learnFromUserMessage(prompt)
                updateLastThinkingStep(type: .done)
            } catch is CancellationError {
                assistantMessages.append(AssistantMessage(role: .assistant, text: "DuDu 已停止回复。"))
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
                let reply = try await LLMCommandService.chat(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    messages: assistantMessages,
                    projectURL: projectURL,
                    currentRun: currentRun,
                    rules: activeRuleContext().text + "\n" + PPKSkillStore.shared.contextBlock(),
                    apiKey: llmAPIKey,
                    personality: activePersonalityBlock
                )
                try Task.checkCancellation()
                assistantMessages.append(AssistantMessage.parse(reply, role: .assistant))
                if isLearningUserStyle { captureUserStyleFromLatestExchange() }
                // Learn from user's modeling instructions
                learnFromUserMessage(trimmed)
                updateLastThinkingStep(type: .done)
            } catch is CancellationError {
                assistantMessages.append(AssistantMessage(role: .assistant, text: "DuDu 已停止回复。"))
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
        duDuPersonality.systemPersonalityBlock(
            customPrompt: customPersonalityPrompt,
            learnedStyle: isLearningUserStyle ? learnedStyleSection : ""
        ) + markdownFormattingGuide
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
        automationModelRuns()
    }

    var automationOptionsSubtitle: String {
        let runs = automationAvailableRunIDs
        if isAutomationProject(projectURL), let last = runs.last {
            return "Current AutoModel project: run\(last) is the latest available model."
        }
        return "A clean AutoModel project will be created from \(dataFile)."
    }

    func presentAutomationOptions() {
        guard !isAutoModeling else { return }
        let runs = automationAvailableRunIDs
        if isAutomationProject(projectURL), !runs.isEmpty {
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
        isAutomationOptionsPresented = false
        startAutomatedModelingDemo()
    }

    /// Prepare SCM files and run PsN SCM for fast covariate screening.
    private func prepareAndRunSCM(baseRun: String, dataFile: String, profile: DatasetProfile,
                                   pForward: String = "0.01", pBackward: String = "0.001") async -> String? {
        let scmSubDirName = "SCM_run\(baseRun)"
        let scmDir = projectURL.appendingPathComponent(scmSubDirName)
        try? FileManager.default.createDirectory(at: scmDir, withIntermediateDirectories: true)

        // 1. Copy and clean the base model for SCM
        let sourceMod = projectURL.appendingPathComponent("run\(baseRun).mod")
        guard let modText = try? String(contentsOf: sourceMod, encoding: .utf8) else {
            runner.append("SCM: base model run\(baseRun).mod not found")
            return nil
        }
        // Remove $TABLE block and ;替换内容 / ; comments
        let lines = modText.components(separatedBy: "\n")
        var cleaned: [String] = []
        var inTable = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("$TABLE") { inTable = true; continue }
            if inTable && trimmed.hasPrefix("$") { inTable = false }
            if inTable { continue }
            if trimmed.hasPrefix(";") && (trimmed.contains("替换") || trimmed.contains("替代") || trimmed.isEmpty) { continue }
            cleaned.append(line)
        }
        let cleanMod = cleaned.joined(separator: "\n")

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
                log: { msg in Task { @MainActor in self.runner.append(msg) } }
            )
            runner.append("SCM: AI config generated")
            updateLastThinkingStep(type: .done, detail: configName)
        } catch {
            runner.append("SCM: AI config failed (\(error.localizedDescription)), using fallback")
            let pkParams = detectPKParams(in: cleanMod)

            // Same fallback as SCM config: if dataset profile has no covariates but $INPUT does, trust $INPUT
            let dsAllFalse = !profile.hasWT && !profile.hasAGE && !profile.hasSEX && !profile.hasSTUDY
            let inputHasAny = modelInput.contains("WT") || modelInput.contains("AGE") || modelInput.contains("SEX") || modelInput.contains("STUD")
            let useFallback = dsAllFalse && inputHasAny
            let effWT  = useFallback ? modelInput.contains("WT")  : profile.hasWT
            let effAGE = useFallback ? modelInput.contains("AGE") : profile.hasAGE
            let effSEX = useFallback ? modelInput.contains("SEX") : profile.hasSEX
            let effSTUDY = useFallback ? (modelInput.contains("STUD") || modelInput.contains("STUDY")) : profile.hasSTUDY

            let allCovs = (effAGE && modelInput.contains("AGE") ? ["AGE"] : []) +
                          (effWT && modelInput.contains("WT") ? ["WT"] : []) +
                          (effSEX && modelInput.contains("SEX") ? ["SEX"] : []) +
                          (effSTUDY && (modelInput.contains("STUD") || modelInput.contains("STUDY")) ? ["STUD"] : [])
            let contCovs = allCovs.filter { ["WT", "AGE"].contains($0) }
            let catCovs = allCovs.filter { ["SEX", "STUD"].contains($0) }
            let covLine = { (covs: [String]) in covs.isEmpty ? "WT" : covs.sorted().joined(separator: ",") }
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
                "",
                "[test_relations]",
            ]
            if pkParams.isEmpty {
                fallback.append("CL=\(allCovs.isEmpty ? "WT,AGE,SEX" : allCovs.sorted().joined(separator: ","))")
            } else {
                for p in pkParams.sorted() {
                    fallback.append("\(p)=\(allCovs.sorted().joined(separator: ","))")
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

        // 3. Run PsN SCM with auto-retry on error
        let maxRetries = 2
        var currentRetry = 0
        var finalSCMResult: String? = nil
        let psnDir = resolvedPsNDir()
        let scmBin = psnDir + "/scm"

        while currentRetry <= maxRetries {
            // Check for user cancellation
            if scmCancelled { runner.append("SCM: cancelled by user"); updateLastThinkingStep(type: .error, detail: "SCM cancelled"); break }

            let attemptLabel = currentRetry == 0 ? "" : " (retry \(currentRetry))"
            runner.append("SCM: running scm -config_file=\(scmPath.lastPathComponent) -model=\(scmModPath.lastPathComponent)\(attemptLabel)")
            addThinkingStep("PsN SCM running for run\(baseRun)\(attemptLabel)...", type: .working)
            let scmCmd = shellQuote(scmBin) + " -config_file=" + shellQuote(scmPath.path) + " -model=" + shellQuote(scmModPath.path)
            let exit = await runner.runAndWait(command: "cd \(shellQuote(scmDir.path)) && \(scmCmd)", in: scmDir)
            runner.append("SCM: completed with exit code \(exit)\(attemptLabel)")

            // Read SCM output
            let scmLogCandidates = [
                scmDir.appendingPathComponent("scm_log.txt"),
                scmDir.appendingPathComponent("scm_results.csv"),
                scmDir.appendingPathComponent("final_scm.txt"),
                projectURL.appendingPathComponent("scm_log.txt"),
                projectURL.appendingPathComponent("scm_results.csv"),
            ]
            var logText: String? = nil
            for logURL in scmLogCandidates {
                if FileManager.default.fileExists(atPath: logURL.path),
                   let text = try? String(contentsOf: logURL, encoding: .utf8), !text.isEmpty {
                    logText = String(text.prefix(15_000))
                    break
                }
            }
            if logText == nil, let contents = try? FileManager.default.contentsOfDirectory(at: scmDir, includingPropertiesForKeys: nil) {
                for subdir in contents where subdir.hasDirectoryPath {
                    let logFile = subdir.appendingPathComponent("scm_log.txt")
                    if let text = try? String(contentsOf: logFile, encoding: .utf8), !text.isEmpty {
                        logText = String(text.prefix(15_000))
                        break
                    }
                }
            }
            let rawLog = logText ?? "SCM completed but no log found."

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
                    pBackward: pBackward
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

    func confirmBaseModelAndStartPhase2() {
        isBaseModelConfirmPresented = false
        guard !isAutoModeling else { return }
        let acceptedRun = baseModelConfirmRunID
        guard !acceptedRun.isEmpty else { return }
        automationStopRequested = false
        isAutoModeling = true
        isAssistantPanelPresented = true
        duDuMood = .working
        tokenTimer?.invalidate()
        tokenTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.liveTokenCount = self?.estimatedTokenCount() ?? 0
            }
        }
        liveTokenCount = estimatedTokenCount()
        assistantMessages.append(AssistantMessage(role: .system, text: "✅ 已确认基础模型为 run\(acceptedRun)。DuDu 进入协变量筛选阶段（Phase 2）。"))
        runner.append("=== PHASE 2: Covariate screening starting from run\(acceptedRun) ===")

        automationTask = Task {
            defer {
                isAutoModeling = false
                automationStep = "Idle"
                automationTask = nil
                tokenTimer?.invalidate()
                tokenTimer = nil
                liveTokenCount = estimatedTokenCount()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if !isAutoModeling { duDuMood = .happy }
                }
            }
            do {
                let activeDataFile = automationDataFile.isEmpty ? dataFile : automationDataFile
                let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: activeDataFile)
                let ruleContext = activeRuleContext()
                let rules = ruleContext.text
                var modelRuns = automationModelRuns()
                guard modelRuns.contains(acceptedRun) else {
                    runner.append("Base model run\(acceptedRun) not found — cannot start Phase 2.")
                    return
                }
                var sourceRun = acceptedRun
                var nextRunNumber = ((modelRuns.compactMap(Int.init).max()) ?? (Int(acceptedRun) ?? 0)) + 1
                let maxEvaluations = 100

                // ━━━ SCM Fast Screening ━━━
                runner.append("=== PHASE 2: Running SCM fast covariate screening ===")
                assistantMessages.append(AssistantMessage(role: .system, text: "🔬 DuDu 正在通过 SCM 快速筛选协变量..."))
                let scmResult = await prepareAndRunSCM(baseRun: acceptedRun, dataFile: activeDataFile, profile: profile)
                if let scmResult {
                    runner.append("SCM screening complete:\n\(scmResult)")
                    assistantMessages.append(AssistantMessage(role: .system, text: "SCM 协变量快速筛选完成。DuDu 将分析结果并验证关键协变量。"))
                } else {
                    runner.append("SCM: not available, falling back to AI-driven covariate screening")
                    assistantMessages.append(AssistantMessage(role: .system, text: "SCM 不可用，DuDu 将通过 AI 逐步筛选协变量。"))
                }

                // ━━━ AI-driven verification ━━━
                var previousForComparison = modelRuns.firstIndex(of: acceptedRun).map { idx in idx > 0 ? modelRuns[idx - 1] : nil } ?? nil

                for iteration in 1...maxEvaluations {
                    try checkAutomationStop("Phase2 iteration \(iteration)")
                    automationStep = "Running NONMEM run\(sourceRun)"
                    currentRun = sourceRun
                    previousRun = previousForComparison ?? sourceRun
                    commandText = ProjectScanner.psnExecuteCommand(runID: sourceRun)
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
                        if !diagExists {
                            automationStep = "Diagnosing run\(sourceRun)"
                            _ = await runAutomationDiagnostics(runID: sourceRun, previousRun: previousForComparison ?? sourceRun)
                        }
                    } else {
                        duDuMood = .sad; lastRunSucceeded = false
                        runner.append("NONMEM run\(sourceRun) failed — repairing")
                    }

                    automationStep = "AI evaluating run\(sourceRun)"
                    let evidence = automationEvidence(runID: sourceRun, previousRun: previousForComparison, exitCode: exit)
                    let skillCtx = PPKSkillStore.shared.contextBlock(for: ["modeling", "covariate", "convergence"])
                    let fullEvidence = "Dataset: \(profile.summary)\n\n\(skillCtx)\n\(evidence)"
                    let decision = try await LLMCommandService.evaluateModelRun(
                        baseURL: llmBaseURL, model: llmModel, projectURL: projectURL,
                        runID: sourceRun, previousRun: previousForComparison,
                        rules: rules + "\n" + skillCtx, diagnosticSummary: fullEvidence, apiKey: llmAPIKey
                    )
                    try checkAutomationStop("AI evaluation run\(sourceRun)")
                    assistantMessages.append(AssistantMessage.parse(decision, role: .assistant))
                    runner.append(decision)

                    if decision.localizedCaseInsensitiveContains("ACCEPT") || decision.localizedCaseInsensitiveContains("定稿") {
                        runner.append("=== PHASE 2 COMPLETE: Covariate model run\(sourceRun) accepted ===")
                        assistantMessages.append(AssistantMessage(role: .system, text: "🎉 协变量筛选完毕！最终模型：run\(sourceRun)。"))
                        break
                    }

                    guard iteration < maxEvaluations else {
                        runner.append("Reached max evaluations (\(maxEvaluations) iterations).")
                        break
                    }
                    let nextRun = formattedRun(nextRunNumber)
                    nextRunNumber += 1
                    automationStep = "AI screening covariate for run\(nextRun)"
                    let optSkillCtx = PPKSkillStore.shared.contextBlock(for: ["modeling", "covariate", "optimization"])
                    let nextModel = try await LLMCommandService.proposeOptimizedModel(
                        baseURL: llmBaseURL, model: llmModel, projectURL: projectURL,
                        sourceRun: sourceRun, nextRun: nextRun,
                        rules: rules + "\n" + optSkillCtx, diagnosticSummary: "\(decision)\n\n\(evidence)",
                        isCovariatePhase: true, apiKey: llmAPIKey
                    )
                    try checkAutomationStop("model drafting run\(nextRun)")
                    try nextModel.write(to: projectURL.appendingPathComponent("run\(nextRun).mod"), atomically: true, encoding: .utf8)
                    if !(await validateModel(nextRun)) { _ = await autoFixModel(nextRun) }
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
                }
                PPKSkillStore.shared.save(to: projectURL)
            }
        }
    }

    func requestStopAutomation() {
        guard isAutoModeling else { return }
        automationStopRequested = true
        automationTask?.cancel()
        runner.append("Automation stopped by user.")
        assistantMessages.append(AssistantMessage(role: .system, text: "DuDu 自动建模已停止。"))
        runner.stopCurrentProcess()
        // Mark as stopped after short delay so UI updates cleanly
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            isAutoModeling = false
            automationStep = "Stopped"
            duDuMood = .happy
            tokenTimer?.invalidate()
            tokenTimer = nil
            liveTokenCount = estimatedTokenCount()
            clearThinkingSteps()
        }
    }

    func startAutomatedModelingDemo() {
        guard !isAutoModeling else { return }
        automationStopRequested = false
        clearThinkingSteps()
        let selectedMode = automationStartMode
        let selectedRunID = automationStartRunID
        let userGuidance = automationUserGuidance.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeDataFile = automationDataFile.isEmpty ? dataFile : automationDataFile

        // Fresh Start: create new project BEFORE automation begins (avoid openProject guard)
        if selectedMode == .fresh || !isAutomationProject(projectURL) {
            do {
                let demo = try ProjectScanner.createAutomationDemoProject(workspaceURL: workspaceURL, sourceURL: workspaceURL)
                projectURL = demo
                selectedAsset = nil
                commandText = ""
                runner.append("Prepared clean AutoModel project: \(demo.path)")
                UserDefaults.standard.set(demo.path, forKey: "AutoPMX.lastProjectPath")
                saveRecentProject(demo)
                if demo.path.contains("/AutoPMX_Projects/") {
                    let parts = demo.path.components(separatedBy: "/AutoPMX_Projects/")
                    if let prefix = parts.first {
                        workspaceURL = URL(fileURLWithPath: prefix)
                    }
                }
                refreshWorkspace()
                assistantMessages.append(AssistantMessage(role: .system, text: "已创建干净 AutoModel 项目；原 Demo/历史项目不会被当作自动建模续跑起点。"))
            } catch {
                runner.append("Failed to create AutoModel project: \(error.localizedDescription)")
                return
            }
        }

        isAutoModeling = true
        isAssistantPanelPresented = true
        duDuMood = .working

        // Start live token counter
        tokenTimer?.invalidate()
        tokenTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.liveTokenCount = self?.estimatedTokenCount() ?? 0
            }
        }
        liveTokenCount = estimatedTokenCount()

        assistantMessages.append(AssistantMessage(role: .system, text: "DuDu PMx 自动建模已从 \(activeDataFile) 启动：先分析数据集确定给药途径，再由 LLM 生成初始模型，逐步迭代优化。"))
        assistantMessages.append(AssistantMessage(role: .system, text: "⚠️ 自动建模期间请不要切换项目路径，否则新生成的 mod 文件会写入错误的目录。如需切换请先点击 STOP 停止建模。"))
        if !userGuidance.isEmpty {
            assistantMessages.append(AssistantMessage(role: .system, text: "本轮已加入你的建模建议：\(userGuidance)"))
        }
        runner.append("=== AutoPMX automated modeling started from \(activeDataFile) ===")

        automationTask = Task {
            defer {
                isAutoModeling = false
                automationStep = "Idle"
                automationTask = nil
                tokenTimer?.invalidate()
                tokenTimer = nil
                liveTokenCount = estimatedTokenCount()
                // Reset mood after a delay
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if !isAutoModeling { duDuMood = .happy }
                }
            }

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

                let ruleContext = activeRuleContext(userGuidance: userGuidance)
                let rules = ruleContext.text
                ruleContextStatus = ruleContext.summary
                runner.append("Rule context for DuDu PMx: \(ruleContext.summary)")

                automationStep = "Analyzing dataset"
                addThinkingStep("Analyzing dataset: \(activeDataFile)", type: .working)
                let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: activeDataFile)
                runner.append("Dataset:\n\(profile.summary)")
                assistantMessages.append(AssistantMessage(role: .system, text: "📊 数据分析完成！\n\n\(profile.summary)"))
                updateLastThinkingStep(type: .done, detail: "\(profile.route) route, \(profile.subjectCount) subjects, \(dataCovariateSummary(profile))")

                // Run dose-normalized C-T plot + lag detection
                var lagInfo: (hasLag: Bool, lagTime: Double, recommendation: String) = (false, 0, "")
                if resolvedR().isEmpty == false {
                    addThinkingStep("Plotting dose-normalized C-T curves", type: .working)
                    lagInfo = runCTAnalysis(dataFile: activeDataFile)
                    // Show the C-T plot to the user in the chat
                    let ctImgName = activeDataFile.replacingOccurrences(of: ".csv", with: "") + "_dose_norm_ct.png"
                    let ctImgPath = projectURL.appendingPathComponent(ctImgName).path
                    if FileManager.default.fileExists(atPath: ctImgPath) {
                        assistantMessages.append(AssistantMessage(role: .system, text: "📊 Dose-Normalized C-T Plot: file://\(ctImgPath)"))
                    }
                    if lagInfo.hasLag {
                        runner.append("CT analysis: absorption lag detected (Tlag ≈ \(String(format: "%.2f", lagInfo.lagTime))).\n\(lagInfo.recommendation)")
                        assistantMessages.append(AssistantMessage(role: .system, text: "📈 C-T 分析：检测到吸收滞后（Tlag ≈ \(String(format: "%.2f", lagInfo.lagTime))）。\n\n\(lagInfo.recommendation)"))
                    } else {
                        assistantMessages.append(AssistantMessage(role: .system, text: "📈 C-T 分析完成：未检测到吸收滞后。C-T 曲线图已在侧边栏 Figures 中查看。"))
                    }
                }

                var modelRuns = automationModelRuns()
                var sourceRun = modelRuns.last ?? "001"
                var previousForComparison = modelRuns.dropLast().last
                var nextRunNumber = ((modelRuns.compactMap(Int.init).max()) ?? (Int(sourceRun) ?? 0)) + 1

                if selectedMode == .selectedRun, modelRuns.contains(selectedRunID) {
                    sourceRun = selectedRunID
                    let sorted = modelRuns.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
                    if let index = sorted.firstIndex(of: selectedRunID), index > 0 {
                        previousForComparison = sorted[index - 1]
                    } else {
                        previousForComparison = nil
                    }
                    nextRunNumber = ((modelRuns.compactMap(Int.init).max()) ?? (Int(sourceRun) ?? 0)) + 1
                    runner.append("User selected run\(sourceRun) as the continuation parent; next new candidate will be run\(formattedRun(nextRunNumber)).")
                }

                if modelRuns.isEmpty {
                    automationStep = "AI writing run001.mod"
                    addThinkingStep("AI drafting run001.mod — initial model from \(profile.route)", type: .working)
                    let initialModel = try await LLMCommandService.generateInitialModel(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        projectURL: projectURL,
                        runID: "001",
                        dataFile: activeDataFile,
                        rules: rules,
                        apiKey: llmAPIKey,
                        hasLag: lagInfo.hasLag,
                        lagTime: lagInfo.lagTime
                    )
                    try checkAutomationStop("initial model drafting")
                    try initialModel.write(to: projectURL.appendingPathComponent("run001.mod"), atomically: true, encoding: .utf8)
                    // Preflight validation of the generated model
                    if !(await validateModel("001")) {
                        runner.append("Initial model run001.mod has preflight issues -- attempting auto-fix")
                        if await autoFixModel("001") {
                            runner.append("Auto-fix applied to run001.mod")
                        }
                    }
                    sourceRun = "001"
                    previousForComparison = nil
                    modelRuns = ["001"]
                    nextRunNumber = 2
                    assistantMessages.append(AssistantMessage(role: .system, text: "DuDu PMx 已根据 \(activeDataFile)（\(profile.route) 给药）创建 run001.mod，从 1-房室模型开始。"))
                    runner.append("Created AI-generated starting model: run001.mod (\(profile.route) route)")
                    updateLastThinkingStep(type: .done, detail: "run001.mod — 1-comp \(profile.route)")
                    refreshWorkspace()
                } else {
                    runner.append("=== AutoPMX RESUMING from run\(sourceRun); next candidate will be run\(formattedRun((Int(sourceRun) ?? 0) + 1)) ===")
                    assistantMessages.append(AssistantMessage(role: .system, text: "检测到 AutoModel 项目已有 run\(sourceRun)，将从该模型继续；不会重新从 run001 开始。"))
                    // Previous run for comparison: use the run directly before sourceRun.
                    // If no earlier run exists, use "001" itself (meaning: no true comparison).
                    if let idx = modelRuns.firstIndex(of: sourceRun), idx > 0 {
                        previousForComparison = modelRuns[idx - 1]
                    }
                }

                var accepted = false
                var acceptedRun: String?
                var covariatePhase = false
                var forceEscalation = false
                let maxEvaluations = 100

                for iteration in 1...maxEvaluations {
                    automationStep = "Running NONMEM run\(sourceRun)"
                    currentRun = sourceRun
                    previousRun = previousForComparison ?? sourceRun
                    commandText = ProjectScanner.psnExecuteCommand(runID: sourceRun)
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
                        if diagExists {
                            runner.append("Diagnostics already exist for run\(sourceRun) — reusing existing GOF/VPC/audit outputs.")
                        } else {
                            automationStep = "Diagnosing run\(sourceRun)"
                            _ = await runAutomationDiagnostics(runID: sourceRun, previousRun: previousForComparison ?? sourceRun)
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
                    let fullEvidence = """
                    Dataset: \(profile.summary)

                    \(evidence)
                    """
                    let decision = try await LLMCommandService.evaluateModelRun(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        projectURL: projectURL,
                        runID: sourceRun,
                        previousRun: previousForComparison,
                        rules: rules,
                        diagnosticSummary: fullEvidence,
                        apiKey: llmAPIKey
                    )
                    try checkAutomationStop("AI evaluation run\(sourceRun)")
                    assistantMessages.append(AssistantMessage.parse(decision, role: .assistant))
                    runner.append(decision)

                    if decision.localizedCaseInsensitiveContains("ACCEPT") || decision.localizedCaseInsensitiveContains("定稿") {
                        // Prevent premature acceptance: AUTO-REVISE if the next compartment level has NOT been tested.
                        let preventAccept = shouldPreventAcceptance(runID: sourceRun, decision: decision, modelRuns: modelRuns, profile: profile)
                        if preventAccept {
                            let runInfo = compartmentInfoForRun(sourceRun)
                            let nextComp = runInfo.compartments + 1
                            runner.append("AI said ACCEPT but next compartment not yet tested — auto-overriding to REVISE. Current: \(runInfo.compartments)-comp. Must also test \(nextComp)-comp before acceptance.")
                            assistantMessages.append(AssistantMessage(role: .system, text: "DuDu PMx 判定 run\(sourceRun) (\(runInfo.compartments)-房室) 可接受，但建模规则要求对比 \(nextComp)-房室模型后才能确认。自动生成 \(nextComp)-房室对比模型。"))
                            forceEscalation = true  // signal to proposeOptimizedModel
                            // Force continue — skip the accept break
                        } else if !covariatePhase {
                            // Base model accepted — PAUSE and ask user for confirmation
                            accepted = true
                            acceptedRun = sourceRun
                            duDuMood = .excited
                            let summary = phaseOneSummary(runs: modelRuns, acceptedRun: sourceRun)
                            runner.append("=== PHASE 1 COMPLETE ===\n\(summary)")
                            assistantMessages.append(AssistantMessage(role: .system, text: "🏆 Phase 1 基础模型筛选完毕！\n\n\(summary)\n\n⚠️ 请确认是否以 run\(sourceRun) 作为最终基础模型进入协变量筛选阶段（Phase 2）。"))
                            // Pause and show confirmation dialog
                            isAutoModeling = false
                            automationStep = "Phase 1 complete — awaiting confirmation"
                            tokenTimer?.invalidate()
                            tokenTimer = nil
                            baseModelConfirmSummary = summary
                            baseModelConfirmRunID = sourceRun
                            isBaseModelConfirmPresented = true
                            break
                        } else {
                            // Phase 2 covariate model accepted — final
                            accepted = true
                            acceptedRun = sourceRun
                            duDuMood = .excited
                            break
                        }
                    }

                    guard iteration < maxEvaluations else {
                        runner.append("Reached max evaluations (\(maxEvaluations) iterations). Best candidate: run\(sourceRun). Click DuDu Auto again to continue from the latest run — it will NOT restart from scratch.")
                        assistantMessages.append(AssistantMessage(role: .system, text: "本轮自动建模已达到单次上限（\(maxEvaluations)轮迭代）。当前最佳候选：run\(sourceRun)。再次点击 DuDu Auto 会从最新 run 继续，不会重新开始。"))
                        break
                    }
                    let nextRun = formattedRun(nextRunNumber)
                    nextRunNumber += 1
                    automationStep = covariatePhase ? "AI screening covariate for run\(nextRun)" : "AI drafting run\(nextRun).mod"
                    let nextModel = try await LLMCommandService.proposeOptimizedModel(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        projectURL: projectURL,
                        sourceRun: sourceRun,
                        nextRun: nextRun,
                        rules: rules,
                        diagnosticSummary: "\(decision)\n\n\(evidence)",
                        isCovariatePhase: covariatePhase,
                        forceCompartmentEscalation: forceEscalation,
                        apiKey: llmAPIKey
                    )
                    try checkAutomationStop("model drafting run\(nextRun)")
                    try nextModel.write(to: projectURL.appendingPathComponent("run\(nextRun).mod"), atomically: true, encoding: .utf8)
                    runner.append("Created candidate model run\(nextRun).mod")
                    // Preflight validation before NONMEM
                    if !(await validateModel(nextRun)) {
                        runner.append("Candidate model run\(nextRun).mod has preflight issues -- attempting auto-fix")
                        if await autoFixModel(nextRun) {
                            runner.append("Auto-fix applied to run\(nextRun).mod")
                        }
                    }
                    previousForComparison = sourceRun
                    sourceRun = nextRun
                    modelRuns.append(nextRun)
                    refreshWorkspace()
                }

                let best = selectBestAutomationRun(preferredAcceptedRun: acceptedRun, profile: profile)
                automationStep = accepted ? "Accepted run\(best?.runID ?? sourceRun)" : "Best candidate run\(best?.runID ?? sourceRun)"
                if let best {
                    currentRun = best.runID
                    previousRun = best.previousRun ?? best.runID
                    commandText = ProjectScanner.psnExecuteCommand(runID: best.runID)
                }
                let phaseLabel = covariatePhase ? "（含协变量筛选）" : "（基础模型）"
                assistantMessages.append(AssistantMessage(role: .system, text: accepted
                    ? "🎉 自动建模完成\(phaseLabel)！AI 判断 run\(best?.runID ?? sourceRun) 已满足规则库要求。\n\n最佳模型已切换到侧边栏，可查看参数估计和诊断图。"
                    : "本轮自动建模已达到单次上限（\(maxEvaluations)轮迭代）。当前最佳候选：run\(best?.runID ?? sourceRun)，已按 OFV/协方差/诊断结果排序。再次点击 DuDu Auto 会从最新候选继续——不会重新从 run001 开始。"))
                refreshWorkspace()
                if let best,
                   let asset = asset(withID: projectURL.appendingPathComponent("run\(best.runID).mod").path) {
                    select(asset)
                }
            } catch let stop as AutomationStoppedError {
                let best = selectBestAutomationRun(preferredAcceptedRun: nil, profile: LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: dataFile))
                if let best {
                    currentRun = best.runID
                    previousRun = best.previousRun ?? best.runID
                    commandText = ProjectScanner.psnExecuteCommand(runID: best.runID)
                    refreshWorkspace()
                    if let asset = asset(withID: projectURL.appendingPathComponent("run\(best.runID).mod").path) {
                        select(asset)
                    }
                }
                runner.append("Automation stopped at \(stop.step).")
                assistantMessages.append(AssistantMessage(role: .system, text: "自动建模已停在：\(stop.step)。当前可从 run\(best?.runID ?? currentRun) 继续，也可以在下次启动时选择从头开始或指定模型继续。"))
            } catch is CancellationError {
                runner.append("Automation cancelled.")
                assistantMessages.append(AssistantMessage(role: .system, text: "DuDu 自动建模已停止。"))
            } catch {
                // If stop was already requested, don't show "connection failed" — it was cancelled
                if automationStopRequested {
                    runner.append("Automation cancelled.")
                    return
                }
                let message = LLMCommandService.friendlyError(error, baseURL: llmBaseURL)
                runner.append("Automated modeling failed: \(message)")
                assistantMessages.append(AssistantMessage(role: .assistant, text: "自动建模失败。\n\n\(message)"))
                runner.append("Attempting to re-verify LLM connection...")
                _ = try? await LLMCommandService.detectEndpoint(
                    preferredBaseURL: llmBaseURL, apiKey: llmAPIKey, apiFormat: activeAPIFormat
                )
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

    func runDiagnostics() {
        runDiagnostics(for: currentRun)
    }

    func runDiagnostics(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "r-diagnostics", previous: previousRun, current: runID))
    }

    func runBootstrap(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "bootstrap", previous: previousRun, current: runID))
    }

    func runSCM(for runID: String, dataFile: String? = nil, pForward: String = "0.01", pBackward: String = "0.001") {
        guard !runner.isRunning else {
            runner.append("A task is already running. Please stop it first or wait for it to complete.")
            return
        }
        activateRun(runID)
        let resolvedData = dataFile ?? (automationDataFile.isEmpty ? self.dataFile : automationDataFile)
        isSCMRunning = true
        scmCancelled = false
        duDuMood = .working
        Task {
            // Analyze dataset + $INPUT fallback for covariate detection
            let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: resolvedData,
                                                           log: { msg in Task { @MainActor in self.runner.append(msg) } })

            // Read $INPUT from model for fallback when dataset analysis returns no covariates
            let modPath = projectURL.appendingPathComponent("run\(runID).mod")
            let modelInput: Set<String>
            if let modText = try? String(contentsOf: modPath, encoding: .utf8) {
                modelInput = detectModelInput(in: modText)
            } else {
                modelInput = []
            }

            // Fallback: if dataset profile has zero covariates but $INPUT does, use $INPUT
            let dsAllFalse = !profile.hasWT && !profile.hasAGE && !profile.hasSEX && !profile.hasSTUDY
            let inputHasAny = modelInput.contains("WT") || modelInput.contains("AGE") || modelInput.contains("SEX") || modelInput.contains("STUD")
            let useFallback = dsAllFalse && inputHasAny
            let showWT  = useFallback ? modelInput.contains("WT")  : profile.hasWT
            let showAGE = useFallback ? modelInput.contains("AGE") : profile.hasAGE
            let showSEX = useFallback ? modelInput.contains("SEX") : profile.hasSEX
            let showSTUDY = useFallback ? (modelInput.contains("STUD") || modelInput.contains("STUDY")) : profile.hasSTUDY

            let covList = [showWT ? "WT" : nil, showAGE ? "AGE" : nil, showSEX ? "SEX" : nil, showSTUDY ? "STUD" : nil].compactMap { $0 }.joined(separator: " ")
            let ofvForward = ofvForPValue(Double(pForward) ?? 0.01)
            let ofvBackward = ofvForPValue(Double(pBackward) ?? 0.001)
            assistantMessages.append(AssistantMessage(role: .system, text: "🔬 正在对 run\(runID) 启动 PsN SCM 协变量快速筛选...\n\n📁 子目录：SCM_run\(runID)/\n📊 数据集：\(resolvedData)\n📊 协变量：\(covList)\n📈 前向纳入：p=\(pForward) (ΔOFV>\(ofvForward))\n📉 逆向剔除：p=\(pBackward) (ΔOFV>\(ofvBackward))\n\n查看终端 Run Log 了解实时进度。"))

            if let result = await prepareAndRunSCM(baseRun: runID, dataFile: resolvedData, profile: profile,
                                                    pForward: pForward, pBackward: pBackward) {
                assistantMessages.append(AssistantMessage(role: .system, text: "✅ SCM 协变量筛选完成！\n\n\(String(result.prefix(3000)))"))
            } else {
                assistantMessages.append(AssistantMessage(role: .system, text: "❌ SCM 筛选未完成。请检查 Run Log 中的错误信息。常见原因：\n1. run\(runID).mod 不存在\n2. PsN execute 命令未配置（Settings → Tools → PsN）\n3. 数据集文件丢失"))
            }
            duDuMood = .happy
            isSCMRunning = false
            refreshWorkspace()
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
    func presentSCMDialog(runID: String? = nil) {
        let mods = availableModFiles()
        let csvs = availableCSVFiles()
        if let runID {
            scmModelRunID = runID
        } else {
            scmModelRunID = mods.first?.replacingOccurrences(of: "run", with: "").replacingOccurrences(of: ".mod", with: "") ?? currentRun
        }
        scmDataFileName = csvs.first ?? dataFile
        scmPForward = "0.01"
        scmPBackward = "0.001"
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

    func confirmSCMRun() {
        showSCMDialog = false
        guard !scmModelRunID.isEmpty, !scmDataFileName.isEmpty else { return }
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
            assistantMessages.append(AssistantMessage(role: .system, text: "⚠️ run\(currentRun) 未成功运行，跳过诊断。请先确保模型收敛后再运行诊断。"))
            return
        }
        guard !runner.isRunning else {
            runner.append("A task is already running.")
            return
        }
        isAssistantPanelPresented = true
        assistantMessages.append(AssistantMessage(role: .system, text: "正在为 run\(currentRun) 运行 GOF、VPC、个体图和 AI 审计。"))
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
            assistantMessages.append(AssistantMessage(role: .system, text: "❌ GA: run\(currentRun).mod 不存在，请先创建模型。"))
            return
        }

        isRunningGA = true
        gaStatus = "Starting GA initial estimate optimization..."
        gaResultText = nil
        isAssistantPanelPresented = true
        assistantMessages.append(AssistantMessage(role: .system, text: "🧬 正在用遗传算法优化 run\(currentRun) 的 THETA 初值..."))
        runner.append("🧬 GA: launching initial estimate optimizer for run\(currentRun)")

        Task {
            let python = resolvedPython()
            let gaScript = findGAScript()
            let nmfe = nonmemPath.isEmpty ? "nmfe76" : nonmemPath
            let rscript = resolvedR()

            guard let script = gaScript else {
                runner.append("GA: autopmx_ga.py not found. Place it in Resources/ or your workspace.")
                assistantMessages.append(AssistantMessage(role: .system, text: "❌ GA: 找不到 autopmx_ga.py，请把它放到 workspace 或 Resources 目录。"))
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
                    assistantMessages.append(AssistantMessage(role: .system, text: "✅ GA 初值优化完成！GA\(currentRun).mod 已生成。请在侧边栏打开对比 THETA 初值变化。"))
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
                assistantMessages.append(AssistantMessage(role: .system, text: "❌ GA 优化失败，exit code: \(exit)。请检查 Run Log 查看详情。"))
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
            assistantMessages.append(AssistantMessage(role: .system, text: "❌ GA Structural: run\(currentRun).mod 不存在，请先创建模型。"))
            return
        }

        isRunningStructuralGA = true
        structuralGAStatus = "Starting structural GA search..."
        structuralGAResultText = nil
        isAssistantPanelPresented = true
        assistantMessages.append(AssistantMessage(role: .system, text: "🧬 正在用 GA 搜索最优模型结构 + 优化 THETA 参数..."))
        runner.append("🧬 GA Structural: launching hybrid optimizer for run\(currentRun)")

        Task {
            let python = resolvedPython()
            let gaScript = findGAScript()
            let nmfe = nonmemPath.isEmpty ? "nmfe76" : nonmemPath
            let rscript = resolvedR()

            guard let script = gaScript else {
                runner.append("GA Structural: autopmx_ga.py not found.")
                assistantMessages.append(AssistantMessage(role: .system, text: "❌ GA Structural: 找不到 autopmx_ga.py。"))
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
                    assistantMessages.append(AssistantMessage(role: .system, text: "✅ GA 结构搜索完成！GA\(currentRun).mod 已生成。请在侧边栏打开查看最优结构选择和参数。"))
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
                assistantMessages.append(AssistantMessage(role: .system, text: "❌ GA 结构搜索失败，exit code: \(exit)。请检查 Run Log 查看详情。"))
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
            assistantMessages.append(AssistantMessage(role: .system, text: "⚠️ run\(runID) 未成功运行，无法审计。请先检查 LST 错误并修复模型。"))
            return
        }
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: kind, previous: previousRun, current: runID))
    }

    func evaluateModelWithAI(_ runID: String) {
        guard isModelRunSuccessful(runID: runID) else {
            runner.append("Model run\(runID) has not succeeded — cannot evaluate. Run NONMEM first.")
            assistantMessages.append(AssistantMessage(role: .system, text: "⚠️ run\(runID) 未成功运行，无法 AI 评估。请先运行 NONMEM 并确保模型收敛。"))
            return
        }
        activateRun(runID)
        isAssistantPanelPresented = true
        assistantMessages.append(AssistantMessage(role: .system, text: "正在为 run\(runID) 启动完整自动诊断和 AI 模型判读。"))
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
            assistantMessages.append(AssistantMessage(role: .system, text: "正在解读 run\(runID) 的 GOF 图。"))
            runAudit("gof-audit", runID: runID)
        } else if lower.contains("vpc") {
            assistantMessages.append(AssistantMessage(role: .system, text: "正在解读 run\(runID) 的 VPC 图。"))
            runAudit("vpc-audit", runID: runID)
        } else if ["lst", "ext", "cov"].contains(asset.url.pathExtension.lowercased()) {
            assistantMessages.append(AssistantMessage(role: .system, text: "正在审阅 run\(runID) 的 NONMEM 输出和参数估计。"))
            runAudit("parameter-audit", runID: runID)
        } else {
            assistantMessages.append(AssistantMessage(role: .system, text: "已选中 \(asset.title)。DuDu 会结合当前模型上下文进行解读。"))
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
                let reply = try await LLMCommandService.chat(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    messages: assistantMessages,
                    projectURL: projectURL,
                    currentRun: currentRun,
                    rules: activeRuleContext().text,
                    apiKey: llmAPIKey,
                    personality: activePersonalityBlock
                )
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
        let gofAudit = automationAuditExists(runID: runID, kind: "gof")
        let vpcAudit = automationAuditExists(runID: runID, kind: "vpc")
        let hasGOF = fm.fileExists(atPath: gofJPG.path) || fm.fileExists(atPath: gofPNG.path)
        let hasVPC = fm.fileExists(atPath: vpcStrat.path) || fm.fileExists(atPath: vpcMod.path)
        let hasIndiv = fm.fileExists(atPath: indivPDF.path)
        return hasGOF && hasVPC && hasIndiv && gofAudit && vpcAudit
    }

    private func automationAuditExists(runID: String, kind: String) -> Bool {
        let fm = FileManager.default
        let prefix = kind == "gof" ? "GOF_Expert_Audit" : "VPC_Expert_Audit"
        // Check Compare dirs for existing audit reports
        let compareDirs = (try? fm.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)) ?? []
        for dir in compareDirs {
            let name = dir.lastPathComponent
            guard name.hasPrefix("Compare") else { continue }
            let auditFile = dir.appendingPathComponent("\(prefix)_Run\(runID)_20260717.md")
            if fm.fileExists(atPath: auditFile.path) { return true }
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
        // Always pass the project directory so Python/R scripts can find project_config.json etc.
        args.append(contentsOf: ["--project-dir", shellQuote(projectURL.path)])
        // Pass R path if configured
        let rscript = resolvedR()
        if !rscript.isEmpty {
            args.append(contentsOf: ["--rscript", shellQuote(rscript)])
        }
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
        let candidates = ["/usr/local/bin/Rscript", "/opt/homebrew/bin/Rscript", "/usr/bin/Rscript"]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? ""
    }

    /// Resolve PsN directory (containing execute, scm, bootstrap etc.)
    func resolvedPsNDir() -> String {
        if !psnPath.isEmpty {
            let path = psnPath.hasSuffix("execute") ? (psnPath as NSString).deletingLastPathComponent : psnPath
            if FileManager.default.fileExists(atPath: path + "/execute") { return path }
        }
        for dir in ["/usr/local/bin", "/opt/homebrew/bin"] {
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

    private func formattedRun(_ value: Int) -> String {
        String(format: "%03d", value)
    }

    // MARK: - Model Compare

    func presentModelCompare() {
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
        ProjectScanner.discoverRuns(in: projectURL)
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
            assistantMessages.append(AssistantMessage(role: .system, text: "请先选择两个要比较的模型。"))
            return
        }

        // Show thinking state during comparison
        isAssistantThinking = true

        // Run parameter audit to extract estimates + diagnostics for both runs
        isCompareSheetPresented = false
        isAssistantPanelPresented = true
        let prev = compareRunA
        let curr = compareRunB
        assistantMessages.append(AssistantMessage(role: .system, text: "🔍 正在比较 run\(prev) 和 run\(curr)..."))
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
        - IIV（OMEGA）估计值，以及对应的 η-Shrinkage，和 IIV 的覆盖范围（哪些参数有/无 IIV）
        
        NOTE on Shrinkage：Shrinkage 仅出现在残差模型（EPS(1), EPS(2)）和 IIV（ETA）相关输出中。只在这些地方提及 Shrinkage，不要单独列出 "Shrinkage" 章节。

        ## 三、模型拟合优度
        - OFV / AIC 对比（标注 ΔOFV, ΔAIC）
        - 解释统计学意义（引用 p<0.05 或 p<0.001 阈值）
        - 协方差步骤是否成功

        ## 四、综合评价与建议
        - 哪个模型更优，依据是什么（引用具体数值）
        - 改进是否具有临床意义
        - 还需关注的问题（边界估计、高 RSE、Shrinkage 过高等）
        - 下一步优化建议

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
            let reply = try await LLMCommandService.chat(
                baseURL: llmBaseURL,
                model: llmModel,
                messages: [AssistantMessage(role: .user, text: comparePrompt)],
                projectURL: projectURL,
                currentRun: curr,
                rules: activeRuleContext().text,
                apiKey: llmAPIKey
            )
            assistantMessages.append(AssistantMessage(role: .assistant, text: reply))
        } catch {
            updateLastThinkingStep(type: .error, detail: "LLM call failed")
            assistantMessages.append(AssistantMessage(role: .assistant, text: "AI 比较失败：\(error.localizedDescription)\n\n请查看 Reports 中生成的参数表格手动比较。"))
        }
    }

    private struct AutomationStoppedError: Error {
        let step: String
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

        var row: String {
            let ofvText = ofv.map { String(format: "%.3f", $0) } ?? "NA"
            return "| run\(runID) | \(ofvText) | \(minimizationSuccessful ? "yes" : "no") | \(covarianceSuccessful ? "yes" : "no") | \(hasLst ? "lst " : "")\(hasExt ? "ext " : "")\(hasCov ? "cov" : "") |"
        }
    }

    private func isAutomationProject(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix("AutoModel_")
            || name == "AutoModel_Demo_NMData"
            || FileManager.default.fileExists(atPath: url.appendingPathComponent(".autopmx_automation.json").path)
    }

    /// Prevent premature ACCEPT: require testing the next compartment level before accepting.
    private func shouldPreventAcceptance(runID: String, decision: String, modelRuns: [String], profile: DatasetProfile) -> Bool {
        guard decision.localizedCaseInsensitiveContains("ACCEPT") else { return false }
        let runInfo = compartmentInfoForRun(runID)
        let currentComp = runInfo.compartments
        let hasHigherComp = modelRuns.contains { compartmentInfoForRun($0).compartments > currentComp }
        if !hasHigherComp && currentComp < 3 {
            return true
        }
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

    /// Check if LST has actual NONMEM parameter estimates + minimization finished.
    /// Returns true ONLY when: ext exists, LST has no fatal errors,
    /// MINIMIZATION SUCCESSFUL must be present. Covariance STEP ABORTED is a warning,
    /// not a hard failure -- parameter estimates and standard errors from the
    /// $COV UNCONDITIONAL run are still usable for evaluation. We treat the model
    /// as "successful" if minimization converged and the .ext file has estimates at
    /// iteration -1000000000. The missing SE for some parameters (coded as 0 or huge
    /// values in NONMEM) is handled gracefully by the parameter table display.
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

        // Must not have fatal errors
        if ModelRunEvidence.fileLooksLikeFailure(lstURL) { return false }

        // Must have minimization success
        let minimizationOK = upper.contains("MINIMIZATION SUCCESSFUL")
        if !minimizationOK { return false }

        // Check that .ext actually contains final estimates (iteration -1000000000)
        guard let extText = try? String(contentsOf: extURL, encoding: .utf8),
              extText.contains("-1000000000") else {
            return false
        }

        // Covariance STEP ABORTED is a flag but not a hard failure.
        // NONMEM still outputs the R-matrix and standard errors are available
        // from the $COV UNCONDITIONAL run. Accept models that converged.
        return true
    }

    // MARK: - Claude Code CLI integration

    func openClaudeCodeTerminal() {
        // Toggle the built-in Claude Code panel instead of opening Terminal.app
        isClaudeCodePanelOpen.toggle()
        if isClaudeCodePanelOpen {
            isAssistantPanelPresented = false  // close DuDu if open, so panels don't overlap
            runner.append("Claude Code panel opened. Type your prompt and press Enter to send to Claude Code.")
            assistantMessages.append(AssistantMessage(role: .system, text: "🧠 Claude Code 面板已打开。可以在右侧输入框输入提示词，按 Enter 发送给 Claude Code 处理。"))
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

    /// Run dose-normalized C-T analysis and lag detection via R
    private func runCTAnalysis(dataFile: String) -> (hasLag: Bool, lagTime: Double, recommendation: String) {
        let rscript = resolvedR()
        guard !rscript.isEmpty else { return (false, 0, "R not configured") }
        let ctScript = findOrCopyCTScript()
        guard let script = ctScript, FileManager.default.fileExists(atPath: script) else {
            return (false, 0, "CT analysis script not found")
        }
        let csvPath = projectURL.appendingPathComponent(dataFile).path
        let outPrefix = projectURL.appendingPathComponent(dataFile.replacingOccurrences(of: ".csv", with: "")).path
        let cmd = "\(shellQuote(rscript)) \(shellQuote(script)) \(shellQuote(csvPath)) \(shellQuote(outPrefix))"
        runner.append("Running dose-normalized C-T analysis...")
        // Run synchronously (fast R script)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", cmd + " 2>/dev/null"]
        task.currentDirectoryURL = projectURL
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        runner.append(output)

        // Parse structured output
        var hasLag = false
        var lagTime = 0.0
        var recommendation = ""
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
            }
        }
        // Refresh workspace to show new figure
        refreshWorkspace()
        return (hasLag, lagTime, recommendation)
    }

    private func findOrCopyCTScript() -> String? {
        // Check bundled resource first
        if let bundled = BundledResource.path(forResource: "dose_normalized_ct_plot", ofType: "R"),
           FileManager.default.fileExists(atPath: bundled) { return bundled }
        // Also check workspace
        let wsScript = workspaceURL.appendingPathComponent("dose_normalized_ct_plot.R").path
        if FileManager.default.fileExists(atPath: wsScript) { return wsScript }
        // Try to copy from bundled to workspace
        if let bundled = Bundle.main.url(forResource: "dose_normalized_ct_plot", withExtension: "R"),
           let data = try? Data(contentsOf: bundled) {
            try? data.write(to: workspaceURL.appendingPathComponent("dose_normalized_ct_plot.R"))
            return workspaceURL.appendingPathComponent("dose_normalized_ct_plot.R").path
        }
        return nil
    }

    private func dataCovariateSummary(_ profile: DatasetProfile) -> String {
        var parts = [String]()
        if profile.hasWT { parts.append("WT") }
        if profile.hasAGE { parts.append("AGE") }
        if profile.hasSEX { parts.append("SEX") }
        if profile.hasSTUDY { parts.append("STUDY") }
        return parts.isEmpty ? "no covariates" : parts.joined(separator: ", ")
    }

    private func phaseOneSummary(runs: [String], acceptedRun: String) -> String {
        let sorted = runs.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
        var lines: [String] = []
        lines.append("📊 Base Model Selection Summary:")
        for (i, runID) in sorted.enumerated() {
            let ci = compartmentInfoForRun(runID)
            let ofv = extractOFV(from: projectURL.appendingPathComponent("run\(runID).ext"))
            let ofvStr = ofv.map { String(format: "%.3f", $0) } ?? "N/A"
            if i > 0, let prevRun = Int(sorted[i-1]), let currRun = Int(runID),
               let prevOFV = extractOFV(from: projectURL.appendingPathComponent("run\(sorted[i-1]).ext")),
               let currOFV = ofv, prevOFV > 0, currOFV > 0 {
                let delta = prevOFV - currOFV
                let result = delta > 10.83 ? "✅ 显著改进 (Δ=\(String(format: "%.1f", delta)))" :
                             delta > 3.84  ? "✅ 有改善 (Δ=\(String(format: "%.1f", delta)))" :
                             "无显著差异 (Δ=\(String(format: "%.1f", delta)))"
                lines.append("  run\(runID) (\(ci.compartments)-comp): OFV=\(ofvStr) vs run\(sorted[i-1]) \(result)")
            } else {
                lines.append("  run\(runID) (\(ci.compartments)-comp): OFV=\(ofvStr) (initial)")
            }
        }
        lines.append("")
        lines.append("🏆 Final base model: run\(acceptedRun) (\(compartmentInfoForRun(acceptedRun).compartments)-comp)")
        return lines.joined(separator: "\n")
    }

    private func selectBestAutomationRun(preferredAcceptedRun: String?, profile: DatasetProfile) -> AutomationRunChoice? {
        let runs = automationModelRuns()
        let choices = runs.enumerated().map { index, runID in
            automationRunChoice(runID: runID, previousRun: index > 0 ? runs[index - 1] : nil)
        }
        guard !choices.isEmpty else { return nil }

        let best: AutomationRunChoice
        if let preferredAcceptedRun, let accepted = choices.first(where: { $0.runID == preferredAcceptedRun }) {
            best = accepted
        } else {
            best = choices.sorted(by: isBetterAutomationChoice).first ?? choices.last!
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
        let upper = lstText.uppercased()
        let hasFailureEvidence = ModelRunEvidence.hasFailureEvidence(projectURL: projectURL, runID: runID)
        let ofv = firstDouble(
            in: lstText,
            patterns: [
                #"MINIMUM VALUE OF OBJECTIVE FUNCTION\s*[:=]?\s*([-+]?\d+(?:\.\d+)?)"#,
                #"OBJV:\s*([-+]?\d+(?:\.\d+)?)"#,
                #"OBJECTIVE FUNCTION VALUE\s*[:=]?\s*([-+]?\d+(?:\.\d+)?)"#
            ]
        )
        let hasLst = FileManager.default.fileExists(atPath: lstURL.path)
        let hasExt = FileManager.default.fileExists(atPath: extURL.path)
        let hasCov = FileManager.default.fileExists(atPath: covURL.path)
        let minimizationSuccessful = !hasFailureEvidence && (upper.contains("MINIMIZATION SUCCESSFUL") || (hasExt && !upper.contains("MINIMIZATION TERMINATED")))
        let covarianceSuccessful = !hasFailureEvidence && (hasCov || (upper.contains("COVARIANCE STEP") && upper.contains("SUCCESSFUL")))

        return AutomationRunChoice(
            runID: runID,
            previousRun: previousRun,
            ofv: ofv,
            hasLst: hasLst,
            hasExt: hasExt,
            hasCov: hasCov,
            minimizationSuccessful: minimizationSuccessful,
            covarianceSuccessful: covarianceSuccessful
        )
    }

    private func isBetterAutomationChoice(_ left: AutomationRunChoice, _ right: AutomationRunChoice) -> Bool {
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
        - Selection rule: prefer successful minimization, successful covariance, then lower OFV.

        | Run | OFV | Minimization | Covariance | Outputs |
        | --- | ---: | --- | --- | --- |
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

        return """
        NONMEM/PsN exit code: \(exitCode)
        Previous run for comparison: \(previousRun ?? "none")
        Current run: \(runID)
        \(ofvComparison)
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

    private func validateModel(_ runID: String) async -> Bool {
        let python = ProjectScanner.pythonExecutable(projectURL: projectURL, workspaceURL: workspaceURL)
        let bridge = resolveBridgeScript()
        let validatorCmd = [
            shellQuote(python),
            shellQuote(bridge),
            "validate-model",
            "--mod", shellQuote(projectURL.appendingPathComponent("run\(runID).mod").path),
            "--project-dir", shellQuote(projectURL.path),
            "--csv", shellQuote(projectURL.appendingPathComponent(dataFile).path),
            "--run-id", runID,
        ].joined(separator: " ")

        let exit = await runner.runAndWait(command: validatorCmd, in: projectURL)
        return exit == 0
    }

    /// Run the Python autóﬁxer on a .mod ﬁle (in-place).
    private func autoFixModel(_ runID: String) async -> Bool {
        let python = ProjectScanner.pythonExecutable(projectURL: projectURL, workspaceURL: workspaceURL)
        let bridge = resolveBridgeScript()
        let fixCmd = [
            shellQuote(python),
            shellQuote(bridge),
            "autofix-model",
            "--mod", shellQuote(projectURL.appendingPathComponent("run\(runID).mod").path),
            "--data", dataFile,
            "--run-id", runID,
        ].joined(separator: " ")

        let exit = await runner.runAndWait(command: fixCmd, in: projectURL)
        return exit == 0
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
                Rules:
                \(rules.prefix(8_000))
                """
            )
            return try await LLMCommandService.chat(
                baseURL: llmBaseURL,
                model: llmModel,
                messages: [promptMessage],
                projectURL: projectURL,
                currentRun: runID,
                rules: rules,
                apiKey: llmAPIKey
            )
        } catch {
            return "REVISE run\(runID): AI evaluation failed, so AutoPMX will create a conservative next candidate. \(error.localizedDescription)"
        }
    }

    private func draftNextModelOrFallback(sourceRun: String, nextRun: String, rules: String) async -> String {
        do {
            return try await LLMCommandService.proposeNextModel(
                baseURL: llmBaseURL,
                model: llmModel,
                projectURL: projectURL,
                sourceRun: sourceRun,
                nextRun: nextRun,
                rules: rules,
                apiKey: llmAPIKey
            )
        } catch {
            runner.append("AI model drafting failed: \(error.localizedDescription). Using deterministic fallback.")
            let sourceURL = projectURL.appendingPathComponent("run\(sourceRun).mod")
            let raw = (try? String(contentsOf: sourceURL, encoding: .utf8)) ?? ""
            return raw
                .replacingOccurrences(of: "run\(sourceRun)", with: "run\(nextRun)")
                .replacingOccurrences(of: "FILE=SDTAB\(sourceRun)", with: "FILE=SDTAB\(nextRun)")
                .replacingOccurrences(of: "FILE=PATAB\(sourceRun)", with: "FILE=PATAB\(nextRun)")
                .replacingOccurrences(of: "FILE=000\(sourceRun).ETA", with: "FILE=000\(nextRun).ETA")
                .replacingOccurrences(of: "FILE=CATAB\(sourceRun)", with: "FILE=CATAB\(nextRun)")
                .replacingOccurrences(of: "FILE=COTAB\(sourceRun)", with: "FILE=COTAB\(nextRun)")
                .replacingOccurrences(of: "$PROBLEM", with: "$PROBLEM\n;; AutoPMX fallback candidate based on run\(sourceRun)")
        }
    }
}
