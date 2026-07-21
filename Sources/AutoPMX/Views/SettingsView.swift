import SwiftUI
import AppKit

// MARK: - macOS 13 compatible onChange

extension View {
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            return self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            return self.onChange(of: value) { newValue in action(newValue) }
        }
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case llm = "LLM"
    case tools = "Tools"
    case rules = "Rules"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "switch.2"
        case .llm: return "cpu"
        case .tools: return "wrench.and.screwdriver"
        case .rules: return "book.pages"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @State private var selectedTab: SettingsTab = .llm

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar tabs
            VStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
                Spacer()
            }
            .frame(width: 120)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content
            switch selectedTab {
            case .general: GeneralSettingsPane()
            case .llm: LLMSettingsPane()
            case .tools: ToolsSettingsPane()
            case .rules: RulesSettingsPane()
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        .frame(maxWidth: 820, maxHeight: 620)
        .frame(minWidth: 680, minHeight: 500)
        .frame(maxWidth: 820, maxHeight: 620)
    }
}

// MARK: - Tab Button

struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(isHovered ? 1.0 : 0.6))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : (isHovered ? .primary : .secondary))
                    .lineLimit(1)
                    .fixedSize()
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.blue.opacity(0.08)
                    : (isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(.blue)
                        .frame(width: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                        .padding(.vertical, 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - General Settings Pane

struct GeneralSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("General").font(.system(size: 16, weight: .bold))
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance").font(.system(size: 12, weight: .semibold))

                    HStack(spacing: 12) {
                        ThemeButton(mode: "system", icon: "circle.lefthalf.filled", label: "跟随系统", isSelected: store.colorSchemeMode == "system") {
                            store.setColorSchemeMode("system")
                        }
                        ThemeButton(mode: "light", icon: "sun.max.fill", label: "浅色", isSelected: store.colorSchemeMode == "light") {
                            store.setColorSchemeMode("light")
                        }
                        ThemeButton(mode: "dark", icon: "moon.fill", label: "深色", isSelected: store.colorSchemeMode == "dark") {
                            store.setColorSchemeMode("dark")
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

struct ThemeButton: View {
    let mode: String
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.blue.opacity(0.10) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : .clear, lineWidth: 1.5)
                    )
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LLM Providers Pane

struct LLMSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore
    @State private var expandedProviderID: UUID?
    @State private var isAddingProvider = false
    @State private var newProviderDraft = LLMProviderProfile.custom()
    @State private var newProviderFormat: APIFormat = .openAICompatible

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LLM Providers")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button {
                    startAddingProvider()
                } label: {
                    Label("Add Provider", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(store.providers.enumerated()), id: \.element.id) { index, provider in
                        llmProviderCard(
                            provider: provider,
                            index: index,
                            isActive: provider.id == store.activeProviderID,
                            isExpanded: expandedProviderID == provider.id,
                            onToggleActive: {
                                if provider.id != store.activeProviderID {
                                    store.activateProvider(provider)
                                }
                            },
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    expandedProviderID = (expandedProviderID == provider.id) ? nil : provider.id
                                }
                            },
                            onTest: {
                                store.activeProviderID = provider.id
                                store.syncFromActiveProvider()
                                store.testLLMConnection()
                            },
                            onDelete: {
                                if store.providers.count > 1 {
                                    store.removeProvider(provider)
                                }
                            }
                        )
                        if index < store.providers.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }

                    if isAddingProvider {
                        newProviderCard()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Provider Card

    private func llmProviderCard(
        provider: LLMProviderProfile,
        index: Int,
        isActive: Bool,
        isExpanded: Bool,
        onToggleActive: @escaping () -> Void,
        onToggleExpand: @escaping () -> Void,
        onTest: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        let binding = providerBinding(for: provider.id)

        return VStack(spacing: 0) {
            // Collapsed row
            HStack(spacing: 10) {
                Toggle(isOn: Binding(get: { isActive }, set: { _ in onToggleActive() })) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isActive)

                Image(systemName: provider.symbolName)
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? .blue : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name.isEmpty ? "Unnamed" : provider.name)
                        .font(.system(size: 12, weight: .medium))
                    Text(provider.model.isEmpty ? "No model configured" : provider.model)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Circle()
                    .fill(provider.availableModels.isEmpty ? Color.secondary.opacity(0.3) : Color.green)
                    .frame(width: 7, height: 7)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { onToggleExpand() }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name").font(.system(size: 10)).foregroundStyle(.tertiary)
                                TextField("Provider name", text: binding.name)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API Format").font(.system(size: 10)).foregroundStyle(.tertiary)
                                Picker("", selection: binding.apiFormat) {
                                    ForEach(APIFormat.allCases, id: \.self) { f in
                                        Text(f.displayName).tag(f)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.system(size: 11))
                                .frame(maxWidth: .infinity)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Base URL").font(.system(size: 10)).foregroundStyle(.tertiary)
                            TextField("https://api.example.com/v1", text: binding.baseURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model").font(.system(size: 10)).foregroundStyle(.tertiary)
                            HStack(spacing: 6) {
                                TextField("model-name", text: binding.model)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11, design: .monospaced))
                                if !provider.availableModels.isEmpty {
                                    Menu {
                                        ForEach(provider.availableModels, id: \.self) { m in
                                            Button(m) { binding.wrappedValue.model = m }
                                        }
                                    } label: {
                                        Image(systemName: "list.bullet")
                                            .font(.system(size: 11))
                                    }
                                    .menuStyle(.borderlessButton)
                                    .frame(width: 20)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Key (optional)").font(.system(size: 10)).foregroundStyle(.tertiary)
                            SecureField("sk-...", text: binding.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                        }

                        HStack(spacing: 8) {
                            Button { onTest() } label: {
                                Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            if !provider.availableModels.isEmpty {
                                Text("\(provider.availableModels.count) models found")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) { onDelete() } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.primary.opacity(0.02))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    // MARK: New Provider Card

    private func newProviderCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text("New Provider")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name").font(.system(size: 10)).foregroundStyle(.tertiary)
                        TextField("My Provider", text: $newProviderDraft.name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Format").font(.system(size: 10)).foregroundStyle(.tertiary)
                        Picker("", selection: $newProviderFormat) {
                            ForEach(APIFormat.allCases, id: \.self) { f in
                                Text(f.displayName).tag(f)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 11))
                        .onChangeCompat(of: newProviderFormat) { newFormat in
                            newProviderDraft.apiFormat = newFormat
                            switch newFormat {
                            case .openAICompatible:
                                newProviderDraft.baseURL = "http://127.0.0.1:8080/v1"
                            case .anthropic:
                                newProviderDraft.baseURL = "https://api.anthropic.com"
                                newProviderDraft.model = "claude-sonnet-5-20251001"
                            case .gemini:
                                newProviderDraft.baseURL = "https://generativelanguage.googleapis.com/v1beta"
                                newProviderDraft.model = "gemini-2.5-pro"
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Base URL").font(.system(size: 10)).foregroundStyle(.tertiary)
                    TextField("https://api.example.com/v1", text: $newProviderDraft.baseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Model").font(.system(size: 10)).foregroundStyle(.tertiary)
                    TextField("model-name", text: $newProviderDraft.model)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key (optional)").font(.system(size: 10)).foregroundStyle(.tertiary)
                    SecureField("sk-...", text: $newProviderDraft.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }

                HStack {
                    Spacer()
                    Button("Cancel") { withAnimation { isAddingProvider = false } }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button("Add Provider") {
                        store.addProvider(newProviderDraft)
                        store.activateProvider(newProviderDraft)
                        withAnimation { isAddingProvider = false }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(newProviderDraft.name.isEmpty && newProviderDraft.baseURL.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .padding(12)
        .background(Color.blue.opacity(0.03))
    }

    private func providerBinding(for id: UUID) -> Binding<LLMProviderProfile> {
        Binding(
            get: { store.providers.first(where: { $0.id == id }) ?? LLMProviderProfile.custom() },
            set: { store.updateProvider($0) }
        )
    }

    private func startAddingProvider() {
        newProviderDraft = LLMProviderProfile(id: UUID(), name: "", baseURL: "http://127.0.0.1:8080/v1", apiKey: "", model: "", apiFormat: .openAICompatible, availableModels: [])
        newProviderFormat = .openAICompatible
        withAnimation { isAddingProvider = true }
    }
}

// MARK: - Tools Settings Pane

struct ToolsSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Tools & Paths")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }
                .padding(.bottom, 4)

                // NONMEM
                toolPathSection(
                    title: "NONMEM (nmfe)",
                    subtitle: "Path to the NONMEM executable (e.g., nmfe76). AutoPMX detects it from common install locations on first launch.",
                    path: $store.nonmemPath,
                    isDetected: store.nonmemDefaultChecked,
                    onBrowse: { browseForNonmem() },
                    onAutoDetect: { store.autoDetectNonmemPath() }
                )
                .onChangeCompat(of: store.nonmemPath) { _ in store.saveToolPaths() }

                Divider()

                // PsN
                toolPathSection(
                    title: "PsN (execute)",
                    subtitle: "Path to the Perl-speaks-NONMEM execute command. Auto-detected from common install locations.",
                    path: $store.psnPath,
                    isDetected: store.psnDefaultChecked,
                    onBrowse: { browseForPsn() },
                    onAutoDetect: { store.autoDetectPsnPath() }
                )
                .onChangeCompat(of: store.psnPath) { _ in store.saveToolPaths() }

                Divider()

                // Python
                toolPathSection(
                    title: "Python Environment",
                    subtitle: "Path to the Python 3 interpreter for running bridge scripts (GOF, VPC, diagnostics, audits). Set a project .venv or a custom Python installation.",
                    path: $store.pythonPath,
                    isDetected: store.pythonDefaultChecked,
                    onBrowse: { browseForPython() },
                    onAutoDetect: { store.autoDetectPythonPath() },
                    resolvedNote: {
                        let resolved = store.resolvedPython()
                        return (resolved != store.pythonPath && !resolved.isEmpty) ? resolved : nil
                    }()
                )
                .onChangeCompat(of: store.pythonPath) { _ in store.saveToolPaths() }

                Divider()

                // R
                toolPathSection(
                    title: "R Environment (Rscript)",
                    subtitle: "Path to Rscript for running R-based diagnostics and plotting. R 4.x with xpose, ggplot2, and dplyr is recommended.",
                    path: $store.rPath,
                    isDetected: store.rDefaultChecked,
                    onBrowse: { browseForR() },
                    onAutoDetect: { store.autoDetectRPath() },
                    resolvedNote: {
                        let resolved = store.resolvedR()
                        return (resolved != store.rPath && !resolved.isEmpty) ? resolved : nil
                    }()
                )
                .onChangeCompat(of: store.rPath) { _ in store.saveToolPaths() }

                Divider()

                // Viewer info
                VStack(alignment: .leading, spacing: 6) {
                    Text("File Viewers")
                        .font(.system(size: 11, weight: .semibold))
                    Text("AutoPMX uses macOS built-in QuickLook for previewing images, PDF, DOCX, XLSX, PPTX, HTML directly in the Detail pane. No plugins needed.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // Data file
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Dataset Filename")
                        .font(.system(size: 11, weight: .semibold))
                    HStack(spacing: 8) {
                        TextField("NM_dat_new.csv", text: $store.dataFile)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 240)
                        Text("Default CSV filename when creating new projects. To set dataset per-project, right-click a CSV in the sidebar → Set as Modeling Dataset.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func toolPathSection(
        title: String,
        subtitle: String,
        path: Binding<String>,
        isDetected: Bool,
        onBrowse: @escaping () -> Void,
        onAutoDetect: @escaping () -> Void,
        resolvedNote: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineSpacing(2)

            HStack(spacing: 8) {
                TextField("", text: path)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))

                Button(action: onBrowse) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Auto Detect", action: onAutoDetect)
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            HStack(spacing: 6) {
                Image(systemName: isDetected ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(isDetected ? .green : .orange)
                Text(isDetected
                     ? "Found: \(path.wrappedValue)"
                     : "Not detected. Please set manually.")
                    .font(.system(size: 10))
                    .foregroundStyle(isDetected ? Color.secondary : Color.orange)
                    .lineLimit(2)
            }

            if let note = resolvedNote {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text("Actual: \(note)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private func browseForNonmem() {
        let panel = NSOpenPanel()
        panel.title = "Select NONMEM Executable (nmfe)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.nonmemPath = url.path
            store.nonmemDefaultChecked = true
            store.saveToolPaths()
        }
    }

    private func browseForPsn() {
        let panel = NSOpenPanel()
        panel.title = "Select PsN Execute Command"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.psnPath = url.path
            store.psnDefaultChecked = true
            store.saveToolPaths()
        }
    }

    private func browseForPython() {
        let panel = NSOpenPanel()
        panel.title = "Select Python 3 Interpreter"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.pythonPath = url.path
            store.pythonDefaultChecked = true
            store.saveToolPaths()
        }
    }

    private func browseForR() {
        let panel = NSOpenPanel()
        panel.title = "Select Rscript Executable"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.rPath = url.path
            store.rDefaultChecked = true
            store.saveToolPaths()
        }
    }
}

// MARK: - Rules Settings Pane

struct RulesSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore
    @State private var rulesText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Rule & Knowledge Sources")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                }

                // Rule sources editor
                VStack(alignment: .leading, spacing: 6) {
                    Text("Source Files")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Comma-separated list of rule, knowledge, and audit files. AutoPMX searches the project directory, workspace root, and AutoPMX_Projects folder.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    TextField("poppk_rules.json, poppk_model_library.md, NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md", text: $store.ruleSourceFiles)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))

                    HStack {
                        Button {
                            store.refreshRuleContextStatus()
                        } label: {
                            Label("Reload Rules", systemImage: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered).controlSize(.small)

                        Button {
                            store.ruleSourceFiles = "poppk_rules.json, poppk_model_library.md, PopPK_Expert_Audit_Report.md, NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md"
                            store.refreshRuleContextStatus()
                        } label: {
                            Label("Load All Defaults", systemImage: "books.vertical")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }

                Divider()

                // Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Load Status")
                        .font(.system(size: 11, weight: .semibold))

                    let ctx = store.activeRuleContext()
                    if !ctx.loadedSources.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Loaded")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.green)
                            ForEach(ctx.loadedSources, id: \.self) { src in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10)).foregroundStyle(.green)
                                    Text(src)
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                        }
                    }

                    if !ctx.missingSources.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Missing / Skipped")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.orange)
                            ForEach(ctx.missingSources, id: \.self) { src in
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10)).foregroundStyle(.orange)
                                    Text(src)
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                        }
                    }

                    if ctx.loadedSources.isEmpty && ctx.missingSources.isEmpty {
                        Text("No rules loaded. Add source files above and reload.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))

                Divider()

                // Available rule files in workspace
                VStack(alignment: .leading, spacing: 8) {
                    Text("Known Source Files in Workspace")
                        .font(.system(size: 11, weight: .semibold))
                    Text("These files exist in your workspace and can be added as sources. Click to append.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    let knownFiles = discoverKnownRuleFiles()
                    if knownFiles.isEmpty {
                        Text("No rule files found in workspace.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(knownFiles, id: \.self) { file in
                                HStack {
                                    Image(systemName: file.hasSuffix(".json") ? "curlybraces" : "doc.text")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    Text(file)
                                        .font(.system(size: 10, design: .monospaced))
                                    Spacer()
                                    Button("Add") {
                                        appendRuleSource(file)
                                    }
                                    .font(.system(size: 10)).buttonStyle(.bordered).controlSize(.small)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func discoverKnownRuleFiles() -> [String] {
        var files = Set<String>()
        let searchDirs = [store.projectURL, store.workspaceURL]
        let workspaceProjects = store.workspaceURL.appendingPathComponent("AutoPMX_Projects")

        for dir in searchDirs + [workspaceProjects] {
            guard let enumerator = FileManager.default.enumerator(atPath: dir.path) else { continue }
            for case let filename as String in enumerator {
                let lower = filename.lowercased()
                if lower.hasSuffix(".json") || lower.hasSuffix(".md") || lower.hasSuffix(".txt") {
                    if lower.contains("rule") || lower.contains("audit") || lower.contains("knowledge")
                        || lower.contains("poppk") || lower.contains("model_library") || lower.contains("expert") {
                        files.insert(filename)
                    }
                }
                // Don't recurse too deep
                if filename.contains("/") && filename.components(separatedBy: "/").count > 3 {
                    enumerator.skipDescendants()
                }
            }
        }
        return files.sorted()
    }

    private func appendRuleSource(_ filename: String) {
        let current = store.ruleSourceFiles
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if !current.contains(filename) {
            store.ruleSourceFiles = (current + [filename]).joined(separator: ", ")
            store.refreshRuleContextStatus()
        }
    }
}

// MARK: - About Pane

struct AboutPane: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // DuDu logo
            if let logo = duDuAboutLogo {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .blue.opacity(0.15), radius: 10, y: 4)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.3, green: 0.6, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    Text("A")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: .blue.opacity(0.2), radius: 10, y: 4)
            }

            VStack(spacing: 4) {
                Text("AutoPMX")
                    .font(.system(size: 20, weight: .bold))
                Text("DuDu PMx Workbench")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Version 1.1.0 (Build 2)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 6) {
                Text("macOS native pharmacometrics modeling workbench.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Integrated NONMEM/PsN execution, AI-assisted model building (DuDu PMx),")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("GA optimization, diagnostic visualization, and liquid-glass Dark Mode.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                Text("Author")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Graham Ju")
                    .font(.system(size: 14, weight: .medium))
                Text("Changsha Duxact Biotechnology Co., Ltd.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)

            VStack(spacing: 6) {
                Text("LLM Provider Support")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("OpenAI-compatible · Anthropic Claude · Google Gemini\nMLX · LM Studio · Ollama · vLLM · Custom APIs")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            VStack(spacing: 8) {
                Divider()
                    .frame(width: 120)
                HStack(spacing: 4) {
                    Image(systemName: "swift")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("Built with SwiftUI · macOS 13+")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Text("© 2025–2026 Graham Ju. All rights reserved.")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var duDuAboutLogo: NSImage? {
        let candidates = [
            Bundle.main.url(forResource: "DuDuPMxButton", withExtension: "png"),
            Bundle.main.url(forResource: "DuDuPMxSource", withExtension: "png"),
        ]
        for url in candidates {
            if let url, let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }
}

// MARK: - Shared Helpers

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}
