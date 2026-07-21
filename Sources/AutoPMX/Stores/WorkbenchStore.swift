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
        case info

        var symbol: String {
            switch self {
            case .thinking: return "ellipsis.circle"
            case .working: return "arrow.triangle.2.circlepath"
            case .done: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle"
            }
        }

        var color: Color {
            switch self {
            case .thinking: return .orange
            case .working: return .blue
            case .done: return .green
            case .error: return .red
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
        AssistantMessage(role: .assistant, text: "Hi，我是 DuDu PMx — AI 药代动力学建模助手。点击 \"DuDu Auto\" 启动自动化建模，或在下方输入框中向我提问。")
    ]
    @Published var assistantInput = ""
    @Published var isAssistantPanelPresented = false
    @Published var isAssistantThinking = false
    @Published var isAutoModeling = false
    @Published var automationStep = "Idle"
    @Published var isAutomationOptionsPresented = false
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

    // MARK: - Thinking Steps

    @Published var thinkingSteps: [ThinkingStep] = []
    @Published var isAIThinking = false
    @Published var currentThinkingText = ""

    let runner = ProcessRunner()
    private var automationTask: Task<Void, Never>?

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
        currentRun = String(modFileName.dropFirst(3).dropLast(4))
            .replacingOccurrences(of: "_ga_opt", with: "")
        commandText = "execute \(modFileName) -model_dir_name"
        refreshChecks()
    }

    func refreshParameterEstimates() {
        parameterRunID = currentRun
        parameterRows = ProjectScanner.parameterEstimates(runID: currentRun, in: projectURL)
    }

    func createProjectFromCurrentRun(name: String) {
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
        refreshWorkspace()
    }

    func openWorkspaceRoot() {
        openProject(url: workspaceURL)
    }

    func openDemoProject() {
        openProject(url: ProjectScanner.ensureDemoProject(workspaceURL: workspaceURL))
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

    func sendAssistantMessage() {
        let prompt = assistantInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isAssistantThinking else { return }
        assistantMessages.append(AssistantMessage(role: .user, text: prompt))
        assistantInput = ""
        isAssistantThinking = true
        addThinkingStep("DuDu is thinking...", type: .thinking)
        Task {
            do {
                let reply = try await LLMCommandService.chat(
                    baseURL: llmBaseURL,
                    model: llmModel,
                    messages: assistantMessages,
                    projectURL: projectURL,
                    currentRun: currentRun,
                    rules: activeRuleContext().text,
                    apiKey: llmAPIKey
                )
                assistantMessages.append(AssistantMessage(role: .assistant, text: reply))
                updateLastThinkingStep(type: .done)
            } catch {
                assistantMessages.append(AssistantMessage(role: .assistant, text: LLMCommandService.friendlyError(error, baseURL: llmBaseURL)))
                updateLastThinkingStep(type: .error, detail: error.localizedDescription)
            }
            isAssistantThinking = false
        }
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

    func requestStopAutomation() {
        guard isAutoModeling else { return }
        automationStopRequested = true
        automationTask?.cancel()
        runner.append("Automation stop requested by user. AutoPMX will stop at the nearest safe checkpoint.")
        assistantMessages.append(AssistantMessage(role: .system, text: "已收到停止请求：当前外部任务会被终止，自动建模会停在最近的安全检查点。"))
        runner.stopCurrentProcess()
    }

    func startAutomatedModelingDemo() {
        guard !isAutoModeling else { return }
        automationStopRequested = false
        isAutoModeling = true
        isAssistantPanelPresented = true
        clearThinkingSteps()
        let selectedMode = automationStartMode
        let selectedRunID = automationStartRunID
        let userGuidance = automationUserGuidance.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeDataFile = automationDataFile.isEmpty ? dataFile : automationDataFile
        assistantMessages.append(AssistantMessage(role: .system, text: "DuDu PMx 自动建模已从 \(activeDataFile) 启动：先分析数据集确定给药途径，再由 LLM 生成初始模型，逐步迭代优化。"))
        if !userGuidance.isEmpty {
            assistantMessages.append(AssistantMessage(role: .system, text: "本轮已加入你的建模建议：\(userGuidance)"))
        }
        runner.append("=== AutoPMX automated modeling started from \(activeDataFile) ===")

        automationTask = Task {
            defer {
                isAutoModeling = false
                automationStep = "Idle"
                automationTask = nil
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
                if selectedMode == .fresh || !isAutomationProject(projectURL) {
                    let demo = try ProjectScanner.createAutomationDemoProject(workspaceURL: workspaceURL, sourceURL: workspaceURL)
                    try checkAutomationStop("project setup")
                    openProject(url: demo)
                    previousRun = "001"
                    currentRun = "001"
                    commandText = ProjectScanner.psnExecuteCommand(runID: "001")
                    refreshWorkspace()
                    runner.append("Prepared clean AutoModel project: \(projectURL.path)")
                    assistantMessages.append(AssistantMessage(role: .system, text: "已创建干净 AutoModel 项目；原 Demo/历史项目不会被当作自动建模续跑起点。"))
                } else {
                    runner.append("Using current AutoModel project: \(projectURL.path)")
                }

                updateLastThinkingStep(type: .done, detail: projectURL.lastPathComponent)

                let ruleContext = activeRuleContext(userGuidance: userGuidance)
                let rules = ruleContext.text
                ruleContextStatus = ruleContext.summary
                runner.append("Rule context for DuDu PMx: \(ruleContext.summary)")

                automationStep = "Analyzing dataset"
                addThinkingStep("Analyzing dataset: \(activeDataFile)", type: .working)
                let profile = LLMCommandService.analyzeDataset(projectURL: projectURL, dataFile: activeDataFile)
                runner.append("Dataset: \(profile.route) route, \(profile.subjectCount) subjects, \(profile.observationCount) obs, dose levels: \(profile.doseLevels.map { String($0) }.joined(separator: ", "))")
                assistantMessages.append(AssistantMessage(role: .system, text: "数据分析完成：\(profile.route) 给药途径，\(profile.subjectCount) 例参与者。"))
                updateLastThinkingStep(type: .done, detail: "\(profile.route) route, \(profile.subjectCount) subjects")

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
                        apiKey: llmAPIKey
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
                let maxEvaluations = 12

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
                    let decision = try await LLMCommandService.evaluateModelRun(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        projectURL: projectURL,
                        runID: sourceRun,
                        previousRun: previousForComparison,
                        rules: rules,
                        diagnosticSummary: evidence,
                        apiKey: llmAPIKey
                    )
                    try checkAutomationStop("AI evaluation run\(sourceRun)")
                    assistantMessages.append(AssistantMessage(role: .assistant, text: decision))
                    runner.append(decision)

                    if decision.localizedCaseInsensitiveContains("ACCEPT") || decision.localizedCaseInsensitiveContains("定稿") {
                        // Prevent premature acceptance: AUTO-REVISE if the next compartment level has NOT been tested.
                        let preventAccept = shouldPreventAcceptance(runID: sourceRun, decision: decision, modelRuns: modelRuns, profile: profile)
                        if preventAccept {
                            let runInfo = compartmentInfoForRun(sourceRun)
                            let nextComp = runInfo.compartments + 1
                            runner.append("AI said ACCEPT but next compartment not yet tested — auto-overriding to REVISE. Current: \(runInfo.compartments)-comp. Must also test \(nextComp)-comp before acceptance.")
                            assistantMessages.append(AssistantMessage(role: .system, text: "DuDu PMx 判定 run\(sourceRun) (\(runInfo.compartments)-房室) 可接受，但建模规则要求对比 \(nextComp)-房室模型后才能确认。自动生成 \(nextComp)-房室对比模型。"))
                            // Force continue — skip the accept break
                        } else {
                            accepted = true
                            acceptedRun = sourceRun
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
                    automationStep = "AI drafting run\(nextRun).mod"
                    let nextModel = try await LLMCommandService.proposeOptimizedModel(
                        baseURL: llmBaseURL,
                        model: llmModel,
                        projectURL: projectURL,
                        sourceRun: sourceRun,
                        nextRun: nextRun,
                        rules: rules,
                        diagnosticSummary: "\(decision)\n\n\(evidence)",
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
                assistantMessages.append(AssistantMessage(role: .system, text: accepted
                    ? "自动建模完成：AI 判断 run\(best?.runID ?? sourceRun) 已满足规则库要求，已切换到该模型。"
                    : "本轮自动建模已到单次上限（\(maxEvaluations)轮迭代）。当前最佳候选：run\(best?.runID ?? sourceRun)，已按 OFV/协方差/诊断结果排序。再次点击 DuDu Auto 会从最新候选继续——不会重新从 run001 开始。"))
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
            } catch {
                let message = LLMCommandService.friendlyError(error, baseURL: llmBaseURL)
                runner.append("Automated modeling failed: \(message)")
                assistantMessages.append(AssistantMessage(role: .assistant, text: "自动建模失败。\n\n\(message)"))
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

    func runSCM(for runID: String) {
        activateRun(runID)
        runCommandAndRefresh(pythonBridgeCommand(task: "scm", previous: previousRun, current: runID))
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
            Bundle.main.resourceURL?.appendingPathComponent("autopmx_ga.py").path,
            Bundle.main.resourceURL?.appendingPathComponent("Resources/autopmx_ga.py").path,
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/autopmx_ga.py").path,
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
                    apiKey: llmAPIKey
                )
                assistantMessages.append(AssistantMessage(role: .assistant, text: reply))
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
        let bridge = FileManager.default.fileExists(atPath: workspaceBridge.path) ? workspaceBridge.path : projectBridge.path
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

        For each run, analyze:
        1. Structural model: ADVAN/TRANS, number of compartments, route
        2. Parameter estimates: CL, V, Q, V2, KA etc. — compare values and units
        3. %RSE of each parameter — which model estimates parameters more precisely
        4. OFV and AIC — quantify the improvement (ΔOFV, ΔAIC)
        5. Shrinkage: eta-shrinkage and epsilon-shrinkage values
        6. Residual error: Prop.RE and Add.RE estimates
        7. IIV: which parameters have IIV, and how large are the OMEGAs
        8. Covariance step: successful or not

        Then give your verdict:
        - Which model is better overall and WHY (cite specific numbers)
        - Is the improvement clinically meaningful? (ΔOFV > 3.84 per added parameter = significant at p<0.05)
        - Are there remaining issues to address (high RSE, boundary estimates, shrinkage issues)?
        - What would you optimize next?

        Keep the response in Chinese, concise but thorough. Cite actual numbers.

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
        let failureEvidence = ModelRunEvidence.failureEvidence(projectURL: projectURL, runID: runID)
        let reports = recentReportPreviews(runID: runID)

        return """
        NONMEM/PsN exit code: \(exitCode)
        Previous run for comparison: \(previousRun ?? "none")
        Current run: \(runID)

        File presence:
        \(filePresence)

        NONMEM/PsN/NMTRAN failure evidence:
        \(failureEvidence)

        LST preview:
        \(lstPreview)

        Recent AI/diagnostic reports:
        \(reports)
        """
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
    private func validateModel(_ runID: String) async -> Bool {
        let python = ProjectScanner.pythonExecutable(projectURL: projectURL, workspaceURL: workspaceURL)
        let validatorCmd = [
            shellQuote(python),
            shellQuote((workspaceURL.appendingPathComponent("autopmx_cli.py").path)),
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
        let fixCmd = [
            shellQuote(python),
            shellQuote((workspaceURL.appendingPathComponent("autopmx_cli.py").path)),
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
