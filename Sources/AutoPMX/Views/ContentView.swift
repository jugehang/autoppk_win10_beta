import SwiftUI
import AppKit

// MARK: - Root layout

struct ContentView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                WorkbenchToolbar()

                HSplitView {
                    SidebarView()
                        .frame(minWidth: 240, idealWidth: 270, maxWidth: 360)

                    VSplitView {
                        DetailView()
                            .frame(minWidth: 520, minHeight: 380)
                        TerminalView()
                            .frame(minHeight: 150, idealHeight: 200, maxHeight: 300)
                    }

                    // Claude Code panel (right side, like VSCode)
                    if store.isClaudeCodePanelOpen {
                        ClaudeCodePanel()
                            .frame(minWidth: 380, idealWidth: 480, maxWidth: 600)
                    }

                    InspectorView()
                        .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
                }
            }
            .background(LiquidGlassBackdrop())

            AIAssistantOverlay()
                .padding(24)

            if store.showDemoGuide {
                DemoGuideView()
                    .padding(24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.showDemoGuide)
        .id(lang.language.rawValue)
        .sheet(isPresented: $store.showSCMDialog) {
            SCMSetupSheetView().environmentObject(store)
        }
        .sheet(isPresented: $store.isBootstrapSheetPresented) {
            BootstrapSetupSheet().environmentObject(store)
        }
        .alert("Move File to Trash?", isPresented: $store.isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) { store.cancelDelete() }
            Button("Move to Trash", role: .destructive) { store.confirmDeletePendingAsset() }
        } message: {
            Text(store.deleteConfirmationText)
        }
        .alert("Delete Project?", isPresented: $store.isDeleteProjectConfirmed) {
            Button("Cancel", role: .cancel) { store.pendingDeleteProject = nil }
            Button("Move to Trash", role: .destructive) { store.confirmDeleteProject() }
        } message: {
            if let url = store.pendingDeleteProject {
                Text("Move \"\(url.lastPathComponent)\" to Trash? This will remove all models, data, and diagnostics in this project.")
            } else {
                Text("Move this project to Trash?")
            }
        }
    }
}

// MARK: - Toolbar

struct WorkbenchToolbar: View {
    @EnvironmentObject private var store: WorkbenchStore
    @State private var projectName = "Run_Project"
    @State private var showingProjectSheet = false
    @State private var projectCreationMode: ProjectCreationMode = .fromRun
    @State private var projectParentDir: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory())
    var body: some View {
        HStack(spacing: 6) {
            ToolbarBrand()

            Divider().frame(height: 26).opacity(0.4).padding(.horizontal, 2)

            LiquidGlassToolbarButton("New Project", icon: "folder.badge.plus") {
                projectName = "New_AutoPMX_Project"
                projectCreationMode = .blank
                showingProjectSheet = true
            }
            LiquidGlassToolbarButton("Open", icon: "folder") { openProjectPanel() }
            demoButton
            LiquidGlassToolbarButton("Root", icon: "house") { store.openWorkspaceRoot() }
            LiquidGlassToolbarButton("From Run", icon: "doc.badge.plus") {
                projectName = "Run\(store.currentRun)_Project"
                projectCreationMode = .fromRun
                showingProjectSheet = true
            }

            Divider().frame(height: 26).opacity(0.4).padding(.horizontal, 2)

            LiquidGlassToolbarButton("Refresh", icon: "arrow.clockwise") { store.refreshWorkspace() }

            Button {
                store.runCurrentModel()
            } label: {
                HStack(spacing: 5) {
                    if store.runner.isRunning {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(store.runner.isRunning ? "Running" : "Run Model")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .frame(height: 28)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: .blue.opacity(0.2), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .liquidGlassHover(cornerRadius: 8)
            .disabled(store.runner.isRunning)
            .opacity(store.runner.isRunning ? 0.6 : 1)
            .scaleEffect(store.runner.isRunning ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.2), value: store.runner.isRunning)

            Spacer()

            // Claude Code quick launch button
            if store.isCCSwitchActive {
                Button {
                    store.openClaudeCodeTerminal()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 11))
                        Text("Claude Code")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .liquidGlassHover(cornerRadius: 7, colors: [.purple, Color(red: 0.6, green: 0.3, blue: 0.9)])
                .help("Open Claude Code in Terminal")
            }

            ProjectLocationBadge()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .overlay(Divider().opacity(0.6), alignment: .bottom)
        .sheet(isPresented: $showingProjectSheet) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                    Text(projectCreationMode.title(currentRun: store.currentRun))
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(projectCreationMode.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Name")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("", text: $projectName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(projectParentDir.path)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.canCreateDirectories = true
                            panel.message = "Choose parent folder for the new project"
                            if panel.runModal() == .OK, let url = panel.url {
                                projectParentDir = url
                            }
                        }
                        .font(.system(size: 10))
                        .controlSize(.small)
                    }
                }

                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { showingProjectSheet = false }
                        .controlSize(.large)
                    Button("Create") {
                        if projectCreationMode == .blank {
                            store.createBlankProject(name: projectName, parentDirectory: projectParentDir)
                        } else {
                            store.createProjectFromCurrentRun(name: projectName, parentDirectory: projectParentDir)
                        }
                        showingProjectSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(28)
            .frame(width: 500)
        }
    }

    private var demoButton: some View {
        Button {
            store.openDemoProject()
        } label: {
            Label("Demo", systemImage: "sparkles")
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .liquidGlassHover(cornerRadius: 7)
        .help("Open Demo Project with guided AI PPK examples")
    }

    private func openProjectPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open AutoPMx Project"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // Start from the parent of current project, or workspace
        panel.directoryURL = store.projectURL.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            store.openProject(url: url)
        }
    }
}

// MARK: - Brand

struct ToolbarBrand: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        HStack(spacing: 10) {
            // DuDu PMx logo
            if let logo = duDuLogoImage {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: .blue.opacity(0.15), radius: 3, y: 1)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.3, green: 0.6, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Text("A")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: .blue.opacity(0.2), radius: 4, y: 1)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    TechBrandTitle()
                    Circle()
                        .fill(store.isAutoModeling || store.isSCMRunning ? .cyan : .green)
                        .frame(width: 5, height: 5)
                        .shadow(color: (store.isAutoModeling || store.isSCMRunning ? Color.cyan : Color.green).opacity(0.4), radius: 2)
                }
                Text("DuDu PMx Workbench")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .frame(minWidth: 190, alignment: .leading)
    }

    private var duDuLogoImage: NSImage? {
        // Try multiple locations: Resources folder, app bundle
        let candidates = [
            BundledResource.url(forResource: "DuDuPMxButton", withExtension: "png"),
            BundledResource.url(forResource: "DuDuPMxSource", withExtension: "png"),
        ]
        for url in candidates {
            if let url, let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }
}

// MARK: - Tech Brand Title

/// Static monochrome brand mark, kept lightweight during long model runs.
struct TechBrandTitle: View {
    var body: some View {
        Text("AutoPMx")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .fixedSize()
    }
}

// MARK: - Location Badge

struct ProjectLocationBadge: View {
    @EnvironmentObject private var store: WorkbenchStore
    @State private var showCopied = false

    var body: some View {
        Menu {
            // Recent projects (excluding current)
            let others = store.recentProjectURLs.filter { $0 != store.projectURL }
            if !others.isEmpty {
                Section("Recent Projects") {
                    ForEach(others, id: \.self) { url in
                        Button {
                            store.openProject(url: url)
                        } label: {
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                        }
                    }
                }
                Divider()
            }
            // Actions
            Button {
                let path = store.projectURL.path
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showCopied = false
                }
            } label: {
                Label(showCopied ? "Copied!" : "Copy Path", systemImage: showCopied ? "checkmark" : "doc.on.doc")
            }
            Button {
                NSWorkspace.shared.selectFile(store.projectURL.path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "arrow.up.right.square")
            }
            Divider()
            Button(role: .destructive) {
                store.pendingDeleteProject = store.projectURL
                store.isDeleteProjectConfirmed = true
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue.opacity(0.7))
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.projectURL.lastPathComponent)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Text(store.projectURL.path)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: 260, alignment: .leading)
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .help("Recent projects & actions")
    }
}

// MARK: - Creation Mode

enum ProjectCreationMode {
    case blank
    case fromRun

    func title(currentRun: String) -> String {
        switch self {
        case .blank: return "Create Blank Project"
        case .fromRun: return "Create Project From Run \(currentRun)"
        }
    }

    var message: String {
        switch self {
        case .blank:
            return "AutoPMx will create a clean data-only project with rules and diagnostic scripts, but no run*.mod files. Please import your own dataset (e.g., NM_dat.csv) afterward. DuDu PMx can write run001.mod from scratch once data is in place."
        case .fromRun:
            return "AutoPMx will copy the selected model, outputs, data file, project config, and rules into a new project folder."
        }
    }
}

// MARK: - Claude Code Panel

struct ClaudeCodePanel: View {
    @EnvironmentObject private var store: WorkbenchStore
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13))
                        .foregroundStyle(.purple)
                    Text("Claude Code")
                        .font(.system(size: 13, weight: .semibold))
                }
                Spacer()
                if store.isClaudeCodeRunning {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                            .tint(.purple)
                        Text("Running")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    store.isClaudeCodePanelOpen = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Divider().opacity(0.6), alignment: .bottom)

            // Output area
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        if store.claudeCodeOutput.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.yellow)
                                    Text(L10n.claudeHintTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(L10n.claudeHintText1)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(4)
                                    Text(L10n.claudeHintText2)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(4)
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(L10n.claudeExampleTitle)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(L10n.claudeExample1)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(L10n.claudeExample2)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(L10n.claudeExample3)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(16)
                        } else {
                            Text(store.claudeCodeOutput)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .id("bottom")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .onChange(of: store.claudeCodeOutput) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))

            Divider().opacity(0.5)

            // Input area
            VStack(spacing: 8) {
                // Toolbar row
                HStack(spacing: 8) {
                    Menu {
                        ForEach(store.claudeEffortOptions, id: \.0) { (value, label) in
                            Button(label) { store.claudeEffortSetting = value }
                        }
                    } label: {
                        Label(
                            store.claudeEffortSetting.isEmpty ? "Effort" : store.claudeEffortSetting,
                            systemImage: "gauge.with.dots.needle.33percent"
                        )
                        .font(.system(size: 10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(height: 24)

                    Toggle(isOn: $store.claudeAutoApprove) {
                        Label("Auto", systemImage: "checkmark.shield")
                            .font(.system(size: 10))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                    if store.isClaudeCodeRunning {
                        Button {
                            store.cancelClaudeCode()
                        } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                    }

                    Spacer()

                    if !store.claudeCodeStatus.isEmpty && !store.isClaudeCodeRunning {
                        Text(store.claudeCodeStatus)
                            .font(.system(size: 10))
                            .foregroundStyle(store.claudeCodeStatus.contains("✅") ? .green : .secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                // Skill chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        skillChip(L10n.claudeSkillAnalyze) {
                            store.claudeCodeInput = "项目: \(store.projectURL.path)\n当前模型: run\(store.currentRun).mod\n数据: \(store.dataFile)\n\n请分析 run\(store.currentRun).mod 和对应的 LST/EXT 输出，评估模型是否满足 PopPK 规则库的判定标准，给出 ACCEPT 或 REVISE 的结论。"
                        }
                        skillChip(L10n.claudeSkillFix) {
                            store.claudeCodeInput = "项目: \(store.projectURL.path)\n当前模型: run\(store.currentRun).mod\n\n请检查 run\(store.currentRun).lst 中的错误信息，根据 PopPK 规则库修复控制流。注意：这是 IV 给药数据，不要切换成口服模型。只修复编译/运行错误，不要添加额外的模型复杂度。"
                        }
                        skillChip(L10n.claudeSkillCompare) {
                            store.claudeCodeInput = "项目: \(store.projectURL.path)\n\n请比较 run\(store.previousRun).mod 和 run\(store.currentRun).mod 的 NONMEM 输出，根据 PopPK 规则库判断当前模型相比前一个模型是否有改进。列出 OFV 变化、参数估计变化、诊断图改进情况。"
                        }
                        skillChip(L10n.claudeSkillCovariate) {
                            store.claudeCodeInput = "项目: \(store.projectURL.path)\n当前模型: run\(store.currentRun).mod\n数据: \(store.dataFile)\n\n请根据 PopPK 规则库评估是否可以添加协变量（WT, SEX, AGE, STUDY）到当前模型。只在结构模型和残差模型稳定后才考虑协变量。不要一次性添加多个协变量。"
                        }
                        skillChip(L10n.claudeSkillNewModel) {
                            store.claudeCodeInput = "项目: \(store.projectURL.path)\n数据: \(store.dataFile)\n\n请根据 PopPK 模型库模板创建一个新的 runXXX.mod 控制流。数据集是 IV Infusion 给药途径，从1房室模型开始。$INPUT 必须严格按照 CSV 表头顺序。$TABLE 的参数必须和 $PK 定义的参数完全一致。"
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    TextEditor(text: $store.claudeCodeInput)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 44, maxHeight: 100)
                        .focused($isFocused)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isFocused ? .purple.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 0.5)
                        )

                    Button {
                        store.sendToClaudeCode()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.purple)
                            .frame(width: 32, height: 32)
                            .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.claudeCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isClaudeCodeRunning)
                    .opacity(store.claudeCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isClaudeCodeRunning ? 0.4 : 1)
                    .onSubmit {
                        if !store.claudeCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isClaudeCodeRunning {
                            store.sendToClaudeCode()
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
    }

    private func skillChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.purple.opacity(0.12), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
