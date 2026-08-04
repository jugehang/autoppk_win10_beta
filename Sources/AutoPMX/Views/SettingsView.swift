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
    case chat = "Chat"
    case llm = "LLM"
    case tools = "Tools"
    case rules = "Rules"
    case tokens = "Tokens"
    case benchmark = "Benchmarks"
    case aiSkill = "AI Skill"
    case contact = "Contact"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "switch.2"
        case .chat: return "message.badge"
        case .llm: return "cpu"
        case .tools: return "wrench.and.screwdriver"
        case .rules: return "book.pages"
        case .tokens: return "chart.bar.xaxis"
        case .benchmark: return "clock.badge.checkmark"
        case .aiSkill: return "sparkles"
        case .contact: return "envelope"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared
    @State private var selectedTab: SettingsTab = .llm

    private let openTokensNotification = NotificationCenter.default.publisher(for: .init("AutoPMXOpenTokensPane"))

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
            .frame(width: 140)
            .background(.ultraThinMaterial)

            Divider()

            // Content
            switch selectedTab {
            case .general: GeneralSettingsPane()
            case .chat: DuDuPersonalityPane()
            case .llm: LLMSettingsPane()
            case .tools: ToolsSettingsPane()
            case .rules: RulesSettingsPane()
            case .tokens: TokensSettingsPane()
            case .benchmark: BenchmarkSettingsPane()
            case .aiSkill: AISkillSettingsPane()
            case .contact: ContactSettingsPane()
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        .frame(maxWidth: 820, maxHeight: 620)
        .background(LiquidGlassBackdrop())
        .id(lang.language.rawValue)
        .onReceive(openTokensNotification) { _ in selectedTab = .tokens }
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
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassCard(cornerRadius: 8, tint: isSelected ? .blue : .secondary)
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
    @ObservedObject private var lang = LanguageStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.general).font(.system(size: 16, weight: .bold))
                Divider()

                // Language
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.language).font(.system(size: 12, weight: .semibold))
                    Picker(L10n.selectLanguage, selection: Binding<AppLanguage>(
                        get: { LanguageStore.shared.language },
                        set: {
                            LanguageStore.shared.setLanguage($0)
                            store.appLanguage = $0
                        }
                    )) {
                        ForEach(AppLanguage.allCases) { languageOption in
                            Text(languageOption.displayName).tag(languageOption)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                Divider()

                // Appearance
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.appearance).font(.system(size: 12, weight: .semibold))

                    HStack(spacing: 12) {
                        ThemeButton(mode: "system", icon: "circle.lefthalf.filled", label: L10n.followSystem, isSelected: store.colorSchemeMode == "system") {
                            store.setColorSchemeMode("system")
                        }
                        ThemeButton(mode: "light", icon: "sun.max.fill", label: L10n.lightTheme, isSelected: store.colorSchemeMode == "light") {
                            store.setColorSchemeMode("light")
                        }
                        ThemeButton(mode: "dark", icon: "moon.fill", label: L10n.darkTheme, isSelected: store.colorSchemeMode == "dark") {
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
                    .liquidGlassCard(cornerRadius: 12, tint: isSelected ? .blue : .secondary)
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
    @ObservedObject private var lang = LanguageStore.shared
    @State private var expandedProviderID: UUID?
    @State private var isAddingProvider = false
    @State private var newProviderDraft = LLMProviderProfile.custom()
    @State private var newProviderFormat: APIFormat = .openAICompatible

    private var orderedProviders: [LLMProviderProfile] {
        store.providers.sorted { left, right in
            let leftPinned = left.isPinned == true
            let rightPinned = right.isPinned == true
            if leftPinned != rightPinned { return leftPinned }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.settingsLLM)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    startAddingProvider()
                } label: {
                    Label(L10n.settingsAddProvider, systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .liquidGlassButton()
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(orderedProviders.enumerated()), id: \.element.id) { index, provider in
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
        let iconSelection = Binding<String?>(
            get: { provider.customSymbolName },
            set: { newValue in
                var updated = provider
                updated.customSymbolName = newValue
                store.updateProvider(updated)
            }
        )

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
                    Text(provider.name.isEmpty ? L10n.settingsUnnamed : provider.name)
                        .font(.system(size: 12, weight: .medium))
                    Text(provider.model.isEmpty ? L10n.settingsNoModel : provider.model)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    var updated = provider
                    updated.isPinned = provider.isPinned == true ? false : true
                    store.updateProvider(updated)
                } label: {
                    Image(systemName: provider.isPinned == true ? "pin.fill" : "pin")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(provider.isPinned == true ? .blue : .secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(provider.isPinned == true ? L10n.settingsUnpinProvider : L10n.settingsPinProvider)

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
                                Text(L10n.settingsName).font(.system(size: 10)).foregroundStyle(.secondary)
                                TextField("Provider name", text: binding.name)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.settingsApiFormat).font(.system(size: 10)).foregroundStyle(.secondary)
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

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.settingsProviderIcon).font(.system(size: 10)).foregroundStyle(.secondary)
                                ProviderIconPicker(
                                    selection: iconSelection,
                                    autoSymbol: provider.inferredSymbolName
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.settingsBaseURL).font(.system(size: 10)).foregroundStyle(.secondary)
                            TextField("https://api.example.com/v1", text: binding.baseURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.settingsModel).font(.system(size: 10)).foregroundStyle(.secondary)
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
                            Text(L10n.settingsApiKey).font(.system(size: 10)).foregroundStyle(.secondary)
                            SecureField("sk-...", text: binding.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                        }

                        HStack(spacing: 8) {
                            Button { onTest() } label: {
                                Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 11))
                            }
                            .liquidGlassButton()
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
                            .liquidGlassButton(colors: [.red, .orange])
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.ultraThinMaterial.opacity(0.45))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .liquidGlassCard(cornerRadius: 12, tint: isActive ? .blue : .secondary)
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    // MARK: New Provider Card

    private func newProviderCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text(L10n.settingsAddProvider)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsName).font(.system(size: 10)).foregroundStyle(.secondary)
                        TextField("My Provider", text: $newProviderDraft.name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsApiFormat).font(.system(size: 10)).foregroundStyle(.secondary)
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
                            case .codeBuddy:
                                newProviderDraft.baseURL = "https://copilot.tencent.com/v2"
                                newProviderDraft.model = "deepseek-v4-flash"
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsProviderIcon).font(.system(size: 10)).foregroundStyle(.secondary)
                        ProviderIconPicker(
                            selection: $newProviderDraft.customSymbolName,
                            autoSymbol: newProviderDraft.inferredSymbolName
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.settingsBaseURL).font(.system(size: 10)).foregroundStyle(.secondary)
                    TextField("https://api.example.com/v1", text: $newProviderDraft.baseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.settingsModel).font(.system(size: 10)).foregroundStyle(.secondary)
                    TextField("model-name", text: $newProviderDraft.model)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.settingsApiKey).font(.system(size: 10)).foregroundStyle(.secondary)
                    SecureField("sk-...", text: $newProviderDraft.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }

                HStack {
                    Spacer()
                    Button(L10n.cancel) { withAnimation { isAddingProvider = false } }
                        .liquidGlassButton().controlSize(.small)
                    Button(L10n.settingsAddProvider) {
                        store.addProvider(newProviderDraft)
                        store.activateProvider(newProviderDraft)
                        withAnimation { isAddingProvider = false }
                    }
                    .liquidGlassButton().controlSize(.small)
                    .disabled(newProviderDraft.name.isEmpty && newProviderDraft.baseURL.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .padding(12)
        .liquidGlassCard(cornerRadius: 12, tint: .blue)
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

private struct ProviderIconPicker: View {
    @Binding var selection: String?
    let autoSymbol: String

    private static let icons = [
        "server.rack",
        "desktopcomputer",
        "memorychip",
        "shippingbox",
        "cpu",
        "internaldrive.fill",
        "network",
        "globe",
        "cloud.fill",
        "building.2",
        "brain.head.profile",
        "sparkles",
        "terminal.fill",
        "bubble.left.and.bubble.right.fill",
        "bolt.horizontal.circle.fill",
        "bolt.fill",
        "wand.and.stars",
        "chart.bar.doc.horizontal",
        "doc.text.fill",
        "book.closed.fill",
        "cube.fill",
        "lock.shield.fill",
        "gearshape.2"
    ]

    var body: some View {
        Picker("", selection: Binding(
            get: { selection ?? "" },
            set: { selection = $0.isEmpty ? nil : $0 }
        )) {
            Label(L10n.settingsProviderIconAuto, systemImage: autoSymbol).tag("")
            ForEach(Self.icons, id: \.self) { icon in
                Label(iconDisplayName(icon), systemImage: icon).tag(icon)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private func iconDisplayName(_ icon: String) -> String {
        icon
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .capitalized
    }
}

// MARK: - Tools Settings Pane

struct ToolsSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text(L10n.toolsTitle)
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }

                Divider()

                // NONMEM
                toolPathSection(
                    title: "NONMEM (nmfe)",
                    subtitle: "Path to the NONMEM executable (e.g., nmfe76). AutoPMx detects it from common install locations on first launch.",
                    path: $store.nonmemPath,
                    isDetected: store.nonmemDefaultChecked,
                    onBrowse: { browseForNonmem() },
                    onAutoDetect: { store.autoDetectNonmemPath() }
                )
                .liquidGlassCard(cornerRadius: 12)
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
                .liquidGlassCard(cornerRadius: 12)
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
                .liquidGlassCard(cornerRadius: 12)
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
                .liquidGlassCard(cornerRadius: 12)
                .onChangeCompat(of: store.rPath) { _ in store.saveToolPaths() }

                Divider()

                // Viewer info
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.toolsFileViewers)
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.settingsToolsViewersHint)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            HStack(spacing: 8) {
                TextField("", text: path)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))

                Button(action: onBrowse) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                }
                .liquidGlassButton()
                .controlSize(.small)

                Button(L10n.settingsAutoDetect, action: onAutoDetect)
                    .liquidGlassButton()
                    .font(.system(size: 10))
                    .controlSize(.small)
            }

            HStack(spacing: 6) {
                let pathText = path.wrappedValue
                let found = isDetected || (!pathText.isEmpty && FileManager.default.fileExists(atPath: pathText))
                Image(systemName: found ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(found ? .green : .orange)
                Text(found
                     ? "Found: \(pathText)"
                     : L10n.settingsNotFound)
                    .font(.system(size: 10))
                    .foregroundStyle(found ? Color.secondary : Color.orange)
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
        .padding(12)
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

    private func browseForKnowledgeBase() {
        let panel = NSOpenPanel()
        panel.title = "Select Knowledge Base Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.knowledgeBaseURL = url
            store.saveKnowledgeBasePath()
        }
    }
}

// MARK: - Rules Settings Pane

struct RulesSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared
    @State private var rulesText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text(L10n.rulesTitle)
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }

                Divider()

                // 1. System built-in rules (bundled with the app)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.rulesBuiltInTitle)
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.rulesBuiltInDesc)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    let builtIn = bundledRuleFiles()
                    if builtIn.isEmpty {
                        Text(L10n.settingsNoRuleFiles)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(builtIn, id: \.self) { file in
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10)).foregroundStyle(.green)
                                    Text(file)
                                        .font(.system(size: 10, design: .monospaced))
                                    Spacer()
                                    Text(L10n.settingsLoaded)
                                        .font(.system(size: 9)).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }

                    HStack {
                        Button {
                            store.refreshRuleContextStatus()
                        } label: {
                            Label(L10n.settingsReloadRules, systemImage: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        .liquidGlassButton().controlSize(.small)
                    }
                }

                Divider()

                // 2. Your own rules (upload)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.rulesUserTitle)
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.rulesUserDesc)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    HStack {
                        Button { uploadYourRule() } label: {
                            Label(L10n.rulesUpload, systemImage: "square.and.arrow.up")
                                .font(.system(size: 11))
                        }
                        .liquidGlassButton().controlSize(.small)

                        Button {
                            store.ruleSourceFiles = ProjectScanner.defaultLLMRuleSourcesText()
                            store.refreshRuleContextStatus()
                        } label: {
                            Label(L10n.settingsLoadAllDefaults, systemImage: "books.vertical")
                                .font(.system(size: 11))
                        }
                        .liquidGlassButton().controlSize(.small)
                    }

                    let userRules = userRulePaths()
                    if !userRules.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(userRules, id: \.self) { path in
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 10)).foregroundStyle(.blue)
                                    Text(path)
                                        .font(.system(size: 10, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button { removeUserRule(path) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }

                Divider()

                // 3. Load status
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.settingsLoadStatus)
                        .font(.system(size: 11, weight: .semibold))

                    let ctx = store.activeRuleContext()
                    if !ctx.loadedSources.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.settingsLoaded)
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
                            Text(L10n.settingsMissing)
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
                        Text(L10n.settingsNoRules)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .liquidGlassCard(cornerRadius: 10, tint: .blue)

                Divider()

                // 4. Rule library overview
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.rulesLibraryOverview)
                        .font(.system(size: 11, weight: .semibold))

                    HStack(spacing: 10) {
                        RuleLibraryStat(
                            value: "\(bundledRuleFiles().count)",
                            label: L10n.rulesFiles,
                            icon: "doc.text.fill",
                            color: .blue
                        )
                        RuleLibraryStat(
                            value: "\(bundledRuleCount())",
                            label: L10n.rulesTotal,
                            icon: "checkmark.seal.fill",
                            color: .green
                        )
                        RuleLibraryStat(
                            value: bundledRuleSizeKB(),
                            label: L10n.rulesSizeKB,
                            icon: "internaldrive.fill",
                            color: .purple
                        )
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                        spacing: 8
                    ) {
                        ForEach(ruleCategories, id: \.key) { category in
                            RuleLibraryStat(
                                value: "\(category.count)",
                                label: L10n.rulesCategoryTitle(category.key),
                                icon: ruleCategoryIcon(category.key),
                                color: ruleCategoryColor(category.key)
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: Built-in / user rule helpers

    private func bundledRuleFiles() -> [String] {
        guard let res = Bundle.main.resourceURL else { return [] }
        return ProjectScanner.defaultLLMRuleSources.filter {
            FileManager.default.fileExists(atPath: res.appendingPathComponent($0).path)
        }
    }

    private func bundledRuleCount() -> Int {
        guard let res = Bundle.main.resourceURL,
              let data = try? Data(contentsOf: res.appendingPathComponent("poppk_rules.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lib = json["rule_library"] as? [String: Any],
              let namespaces = lib["namespaces"] as? [String: Any] else {
            return 0
        }
        return namespaces.values.reduce(0) { total, value in
            guard let rules = value as? [[String: Any]] else { return total }
            return total + rules.count
        }
    }

    private func bundledRuleFileSizeKB(_ name: String) -> String {
        guard let res = Bundle.main.resourceURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: res.appendingPathComponent(name).path),
              let size = attrs[.size] as? Int else {
            return "0"
        }
        return String(format: "%.1f", Double(size) / 1024.0)
    }

    private func bundledRuleSizeKB() -> String {
        let total = bundledRuleFiles().reduce(0.0) { sum, file in
            sum + (Double(bundledRuleFileSizeKB(file)) ?? 0)
        }
        return String(format: "%.1f", total)
    }

    private var ruleCategories: [(key: String, count: Int)] {
        guard let res = Bundle.main.resourceURL,
              let data = try? Data(contentsOf: res.appendingPathComponent("poppk_rules.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lib = json["rule_library"] as? [String: Any],
              let namespaces = lib["namespaces"] as? [String: Any] else {
            return []
        }
        return namespaces.compactMap { key, value in
            guard let rules = value as? [[String: Any]] else { return nil }
            return (key: key, count: rules.count)
        }.sorted { $0.count > $1.count }
    }

    private func ruleCategoryIcon(_ key: String) -> String {
        switch key {
        case "@Regulatory": return "checkmark.shield.fill"
        case "@BioPhys": return "atom"
        case "@ModelingTechniques": return "square.stack.3d.up.fill"
        case "@DataStandards": return "tablecells.fill"
        case "@ModelEvaluation": return "chart.xyaxis.line"
        case "@CovariateAnalysis": return "point.3.connected.trianglepath.dotted"
        case "@mAb_EarlyClinical": return "cross.case.fill"
        case "@Reporting": return "doc.text.fill"
        default: return "book.pages"
        }
    }

    private func ruleCategoryColor(_ key: String) -> Color {
        switch key {
        case "@Regulatory": return .indigo
        case "@BioPhys": return .purple
        case "@ModelingTechniques": return .blue
        case "@DataStandards": return .teal
        case "@ModelEvaluation": return .green
        case "@CovariateAnalysis": return .orange
        case "@mAb_EarlyClinical": return .pink
        case "@Reporting": return .brown
        default: return .secondary
        }
    }

    private func userRulePaths() -> [String] {
        store.ruleSourceFiles
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("/") }
    }

    private func uploadYourRule() {
        let panel = NSOpenPanel()
        panel.title = L10n.rulesUpload
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["json", "md", "txt"]
        if panel.runModal() == .OK {
            let paths = panel.urls.map { $0.path }
            var current = userRulePaths()
            for p in paths where !current.contains(p) { current.append(p) }
            let builtIn = ProjectScanner.defaultLLMRuleSourcesText()
            let merged = (current.isEmpty ? builtIn : builtIn + ", " + current.joined(separator: ", "))
            store.ruleSourceFiles = merged
            store.refreshRuleContextStatus()
        }
    }

    private func removeUserRule(_ path: String) {
        let current = store.ruleSourceFiles
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != path }
        store.ruleSourceFiles = current.joined(separator: ", ")
        store.refreshRuleContextStatus()
    }
}

struct RuleLibraryStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(10)
        .liquidGlassCard(cornerRadius: 10, tint: color)
    }
}

// MARK: - Tokens Settings Pane

enum TokenChartRange: String, CaseIterable, Identifiable {
    case week, month
    var id: String { rawValue }
    var label: String {
        switch self {
        case .week:  return L10n.tokensWeek
        case .month: return L10n.tokensMonth
        }
    }
}

struct TokensSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared
    @State private var displayedMonth: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var displayedWeek: Date = Date()
    @State private var chartRange: TokenChartRange = .month

    private let contextTiers: [(label: String, value: Int)] = [
        ("64K", 64_000), ("128K", 128_000), ("256K", 256_000), ("512K", 512_000)
    ]

    private var allTimeRequests: Int { store.usageHistory.reduce(0) { $0 + $1.requests } }
    private var allTimeInput: Int { store.usageHistory.reduce(0) { $0 + $1.inputTokens } }
    private var allTimeOutput: Int { store.usageHistory.reduce(0) { $0 + $1.outputTokens } }
    private var allTimeTotal: Int { allTimeInput + allTimeOutput }

    private var monthKey: String {
        let c = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }
    private var monthLabel: String {
        let c = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
        let fmt = LanguageStore.shared.language == .zhCN ? "%04d 年 %02d 月" : "%04d-%02d"
        return String(format: fmt, c.year ?? 0, c.month ?? 0)
    }
    private var monthRequests: Int {
        store.usageHistory.filter { $0.date.hasPrefix(monthKey) }.reduce(0) { $0 + $1.requests }
    }
    private var monthTotal: Int {
        store.usageHistory.filter { $0.date.hasPrefix(monthKey) }.reduce(0) { $0 + $1.totalTokens }
    }

    /// Daily [label, input, output] for every day of the displayed month.
    private var monthData: [(label: String, input: Int, output: Int)] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let byDate = Dictionary(uniqueKeysWithValues: store.usageHistory.map { ($0.date, $0) })
        return range.map { day in
            let ds = String(format: "%@-%02d", monthKey, day)
            let u = byDate[ds]
            return (label: "\(day)", input: u?.inputTokens ?? 0, output: u?.outputTokens ?? 0)
        }
    }

    /// Compute the start (Monday) of the week containing `displayedWeek`.
    private var weekStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: displayedWeek)
        return cal.date(from: comps) ?? displayedWeek
    }
    private var weekLabel: String {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return "\(f.string(from: weekStart)) – \(f.string(from: end))"
    }
    /// Per-day [label, input, output] for the 7 days of the displayed week.
    /// Label format: "Mon 28" / "Mon" — includes the day-of-month for clarity.
    private var weekData: [(label: String, input: Int, output: Int)] {
        let cal = Calendar.current
        let dayNameFmt = DateFormatter()
        dayNameFmt.dateFormat = "EEE"  // Mon/Tue/...
        dayNameFmt.locale = Locale(identifier: LanguageStore.shared.language == .zhCN ? "zh_CN" : "en_US")
        let dayNumFmt = DateFormatter()
        dayNumFmt.dateFormat = "d"
        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            let key = weekKey(for: day)
            let u = store.usageHistory.first(where: { $0.date == key })
            let label = "\(dayNameFmt.string(from: day)) \(dayNumFmt.string(from: day))"
            return (label: label, input: u?.inputTokens ?? 0, output: u?.outputTokens ?? 0)
        }
    }
    private func weekKey(for day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: day)
    }
    private var weekRequests: Int {
        let cal = Calendar.current
        return (0..<7).reduce(0) { sum, offset in
            let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            return sum + (store.usageHistory.first(where: { $0.date == weekKey(for: day) })?.requests ?? 0)
        }
    }
    private var weekTotal: Int {
        let cal = Calendar.current
        return (0..<7).reduce(0) { sum, offset in
            let day = cal.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            return sum + (store.usageHistory.first(where: { $0.date == weekKey(for: day) })?.totalTokens ?? 0)
        }
    }
    private var weekSummary: String {
        String(format: L10n.t("tokens.weekSummary"), weekRequests, formatTokens(weekTotal))
    }

    /// Currently displayed chart data, based on chartRange.
    private var currentChartData: [(label: String, input: Int, output: Int)] {
        chartRange == .week ? weekData : monthData
    }
    private var currentSummaryText: String {
        chartRange == .week ? weekSummary : String(format: L10n.t("tokens.monthSummary"), monthRequests, formatTokens(monthTotal))
    }
    private var currentPeriodLabel: String {
        chartRange == .week ? weekLabel : monthLabel
    }
    /// Shift the displayed period by 7 days (week) or 1 month (month).
    private func shiftPeriod(_ delta: Int) {
        let cal = Calendar.current
        if chartRange == .week {
            displayedWeek = cal.date(byAdding: .day, value: 7 * delta, to: displayedWeek) ?? displayedWeek
        } else {
            displayedMonth = cal.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text(L10n.t("tokens.title"))
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }

                Divider()

                // MARK: Context window limit
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("tokens.contextWindow"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.t("tokens.contextWindowDesc"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        ForEach(contextTiers, id: \.value) { tier in
                            Button {
                                store.contextWindowLimitTokens = tier.value
                            } label: {
                                VStack(spacing: 3) {
                                    Text(tier.label)
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                }
                                .frame(width: 72, height: 38)
                                .liquidGlassCard(cornerRadius: 8, tint: store.contextWindowLimitTokens == tier.value ? .blue : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(.green)
                        Text("\(L10n.t("tokens.currentLimit"))：\(store.contextWindowLimitTokens) tokens")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }

                Divider()

                // MARK: Memory usage monitor
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.t("tokens.memory"))
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        memoryPressureBadge
                    }
                    Text(L10n.t("tokens.memoryDesc"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Usage bar
                    let ratio = memoryMonitor.snapshot.usageRatio
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.primary.opacity(0.08))
                            Capsule()
                                .fill(memoryBarColor(ratio))
                                .frame(width: geo.size.width * ratio)
                        }
                    }
                    .frame(height: 8)
                    HStack {
                        Text(L10n.t("tokens.memPressure"))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                        Spacer()
                        Text(memoryPressureLabel(ratio))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(memoryBarColor(ratio))
                    }

                    HStack(spacing: 12) {
                        memCard(title: L10n.t("tokens.memTotal"), value: memoryMonitor.formatBytes(memoryMonitor.snapshot.totalBytes), accent: .blue)
                        memCard(title: L10n.t("tokens.memUsed"), value: "\(memoryMonitor.formatBytes(memoryMonitor.snapshot.usedBytes)) (\(Int(ratio * 100))%)", accent: .orange)
                        memCard(title: L10n.t("tokens.memAvailable"), value: memoryMonitor.formatBytes(memoryMonitor.snapshot.availableBytes), accent: .green)
                        memCard(title: L10n.t("tokens.memApp"), value: memoryMonitor.formatBytes(memoryMonitor.snapshot.appFootprintBytes), accent: .purple)
                    }

                    // Local LLM service row
                    HStack(spacing: 6) {
                        Image(systemName: memoryMonitor.llmProcessName.isEmpty ? "cpu" : "memorychip")
                            .font(.system(size: 11))
                            .foregroundStyle(memoryMonitor.llmProcessName.isEmpty ? Color.secondary : Color.blue)
                        if memoryMonitor.llmProcessName.isEmpty {
                            Text(L10n.t("tokens.memLLMNone"))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(L10n.t("tokens.memLLM"))：\(memoryMonitor.llmProcessName) · \(memoryMonitor.formatBytes(memoryMonitor.llmProcessBytes))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(8)
                    .liquidGlassCard(cornerRadius: 8, tint: .blue)

                    if ratio >= 0.8 {
                        Text(String(format: L10n.t("tokens.memWarning"), ratio * 100))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }

                Divider()

                // MARK: All-time statistics
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("tokens.stats"))
                        .font(.system(size: 12, weight: .semibold))
                    HStack(spacing: 12) {
                        statCard(title: L10n.t("tokens.requests"), value: "\(allTimeRequests)", accent: .blue)
                        statCard(title: L10n.t("tokens.input"), value: formatTokens(allTimeInput), accent: .blue)
                        statCard(title: L10n.t("tokens.output"), value: formatTokens(allTimeOutput), accent: .green)
                        statCard(title: L10n.t("tokens.total"), value: formatTokens(allTimeTotal), accent: .purple)
                    }
                }

                Divider()

                // MARK: Daily bar chart (with Week/Month switcher)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.t("tokens.dailyChart"))
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Picker("", selection: $chartRange) {
                            ForEach(TokenChartRange.allCases) { r in
                                Text(r.label).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 110)
                        .id(lang.language.rawValue)
                    }
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Button { shiftPeriod(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 11)) }
                                .liquidGlassButton().controlSize(.small)
                            Text(currentPeriodLabel).font(.system(size: 11, weight: .medium)).frame(minWidth: 140, alignment: .center)
                            Button { shiftPeriod(1) } label: { Image(systemName: "chevron.right").font(.system(size: 11)) }
                                .liquidGlassButton().controlSize(.small)
                        }
                    }
                    Text(currentSummaryText)
                        .font(.system(size: 10)).foregroundStyle(.secondary)

                    TokenBarChart(data: currentChartData)
                        .frame(height: 220)
                        .padding(10)
                        .liquidGlassCard(cornerRadius: 10, tint: .blue)

                    if allTimeRequests == 0 {
                        Text(L10n.t("tokens.empty"))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }

                // MARK: Per-provider comparison
                if !store.providerUsageRecords.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("tokens.perProvider"))
                            .font(.system(size: 12, weight: .semibold))
                        ProviderComparisonTable(records: store.providerUsageRecords)
                            .frame(minHeight: 60)
                    }
                }

                Spacer(minLength: 12)
            }
            .padding(20)
        }
        .onAppear { memoryMonitor.start() }
        .onDisappear { memoryMonitor.stop() }
    }

    private func statCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .liquidGlassCard(cornerRadius: 10, tint: accent)
    }

    // MARK: Memory monitor helpers

    @ObservedObject private var memoryMonitor = MemoryMonitor.shared

    private var memoryPressureBadge: some View {
        let ratio = memoryMonitor.snapshot.usageRatio
        return HStack(spacing: 5) {
            Circle().fill(memoryBarColor(ratio)).frame(width: 8, height: 8)
            Text(memoryPressureLabel(ratio))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(memoryBarColor(ratio))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(memoryBarColor(ratio).opacity(0.12), in: Capsule())
    }

    private func memoryBarColor(_ ratio: Double) -> Color {
        ratio < 0.6 ? .green : (ratio < 0.8 ? .orange : .red)
    }

    private func memoryPressureLabel(_ ratio: Double) -> String {
        ratio < 0.6 ? L10n.t("tokens.memLow") : (ratio < 0.8 ? L10n.t("tokens.memMed") : L10n.t("tokens.memHigh"))
    }

    private func memCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .liquidGlassCard(cornerRadius: 10, tint: accent)
    }

    private func formatTokens(_ n: Int) -> String {
        let f = Double(n) / 1000.0
        if f >= 1000 { return String(format: "%.2fM", f / 1000.0) }
        if f >= 1 { return String(format: "%.1fK", f) }
        return "\(n)"
    }

    private func shiftMonth(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = next
        }
    }
}

// MARK: - Modeling Time Benchmarks

struct BenchmarkSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared
    @State private var copiedCSV = false

    private var records: [ModelingBenchmarkRecord] {
        store.benchmarkRecords
    }

    private var avgComparable: TimeInterval {
        guard !records.isEmpty else { return 0 }
        return records.map(\.comparableSeconds).reduce(0, +) / Double(records.count)
    }

    private var avgThinking: TimeInterval {
        guard !records.isEmpty else { return 0 }
        return records.map(\.thinkingSeconds).reduce(0, +) / Double(records.count)
    }

    private var avgExecution: TimeInterval {
        guard !records.isEmpty else { return 0 }
        return records.map(\.executionSeconds).reduce(0, +) / Double(records.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("benchmark.title"))
                    .font(.system(size: 16, weight: .bold))
                Text(L10n.t("benchmark.desc"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    statCard(title: L10n.t("benchmark.avgRecords"), value: "\(records.count)", accent: .blue)
                    statCard(title: L10n.t("benchmark.avgComparable"), value: formatDuration(avgComparable), accent: .purple)
                    statCard(title: L10n.t("benchmark.avgThinking"), value: formatDuration(avgThinking), accent: .orange)
                    statCard(title: L10n.t("benchmark.avgExecution"), value: formatDuration(avgExecution), accent: .green)
                }

                HStack {
                    Button(copiedCSV ? "✓" : L10n.t("benchmark.copyCSV")) {
                        let csv = store.benchmarkCSV()
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(csv, forType: .string)
                        copiedCSV = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedCSV = false
                        }
                    }
                    .liquidGlassButton()
                    .controlSize(.small)
                    .disabled(records.isEmpty)

                    Button(L10n.t("benchmark.clear"), role: .destructive) {
                        store.clearBenchmarkRecords()
                    }
                    .liquidGlassButton(colors: [.red, .orange])
                    .controlSize(.small)
                    .disabled(records.isEmpty)
                }

                if records.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text(L10n.t("benchmark.empty"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 8) {
                        ForEach(records) { record in
                            benchmarkRow(record)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func benchmarkRow(_ record: ModelingBenchmarkRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.datasetName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text("\(record.providerName) · \(record.modelName)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(statusLabel(record.status))
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(record.status).opacity(0.12), in: Capsule())
                    .foregroundStyle(statusColor(record.status))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                metric(L10n.t("benchmark.startedAt"), formattedDate(record.startedAt))
                metric(L10n.t("benchmark.phase1"), formatDuration(record.phase1Seconds))
                metric(L10n.t("benchmark.thinking"), formatDuration(record.thinkingSeconds))
                metric(L10n.t("benchmark.execution"), formatDuration(record.executionSeconds))
                metric(L10n.t("benchmark.baseWait"), formatDuration(record.baseModelWaitSeconds))
                metric(L10n.t("benchmark.phase2"), formatDuration(record.phase2OrSCMSeconds))
                metric(L10n.t("benchmark.comparable"), formatDuration(record.comparableSeconds))
                metric(L10n.t("benchmark.total"), formatDuration(record.totalElapsedSeconds))
            }

            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .liquidGlassCard(cornerRadius: 10, tint: .blue)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .liquidGlassCard(cornerRadius: 10, tint: accent)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        if interval >= 3600 { return String(format: "%.1fh", interval / 3600) }
        if interval >= 60 { return String(format: "%.1fm", interval / 60) }
        return String(format: "%.1fs", interval)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func statusLabel(_ status: ModelingBenchmarkRecord.Status) -> String {
        switch status {
        case .completed: return L10n.t("benchmark.statusCompleted")
        case .stopped: return L10n.t("benchmark.statusStopped")
        case .failed: return L10n.t("benchmark.statusFailed")
        case .paused: return L10n.t("benchmark.statusPaused")
        }
    }

    private func statusColor(_ status: ModelingBenchmarkRecord.Status) -> Color {
        switch status {
        case .completed: return .green
        case .stopped: return .orange
        case .failed: return .red
        case .paused: return .gray
        }
    }
}

// MARK: - Provider Comparison Table

struct ProviderComparisonTable: View {
    let records: [ProviderUsageRecord]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 10) {
                    Text("Provider").font(.system(size: 9, weight: .semibold)).frame(width: 120, alignment: .leading)
                    Text("Req").font(.system(size: 9, weight: .semibold)).frame(width: 40, alignment: .trailing)
                    Text("In").font(.system(size: 9, weight: .semibold)).frame(width: 70, alignment: .trailing)
                    Text("Out").font(.system(size: 9, weight: .semibold)).frame(width: 70, alignment: .trailing)
                    Text("In/s").font(.system(size: 9, weight: .semibold)).frame(width: 75, alignment: .trailing)
                    Text("Out/s").font(.system(size: 9, weight: .semibold)).frame(width: 75, alignment: .trailing)
                }
                .foregroundStyle(.secondary)
                Divider()
                ForEach(records) { rec in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rec.providerName).font(.system(size: 10, weight: .medium)).lineLimit(1)
                            Text(rec.modelName).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(width: 120, alignment: .leading)
                        Text("\(rec.requests)").font(.system(size: 10, design: .monospaced)).frame(width: 40, alignment: .trailing)
                        Text(formatT(rec.inputTokens)).font(.system(size: 10, design: .monospaced)).frame(width: 70, alignment: .trailing).foregroundStyle(.blue)
                        Text(formatT(rec.outputTokens)).font(.system(size: 10, design: .monospaced)).frame(width: 70, alignment: .trailing).foregroundStyle(.green)
                        Text(rec.avgInputSpeed).font(.system(size: 10, design: .monospaced)).frame(width: 75, alignment: .trailing).foregroundStyle(.orange)
                        Text(rec.avgOutputSpeed).font(.system(size: 10, design: .monospaced)).frame(width: 75, alignment: .trailing).foregroundStyle(.orange)
                    }
                    Divider().opacity(0.4)
                }
            }
            .padding(8)
        }
        .liquidGlassCard(cornerRadius: 8, tint: .blue)
    }

    private func formatT(_ n: Int) -> String {
        let f = Double(n) / 1000.0
        if f >= 1000 { return String(format: "%.1fM", f / 1000.0) }
        if f >= 1 { return String(format: "%.0fK", f) }
        return "\(n)"
    }
}

// MARK: - AI Skill Memory Pane

struct AISkillSettingsPane: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var skillStore = PPKSkillStore.shared
    @ObservedObject private var lang = LanguageStore.shared
    @State private var showClearConfirm = false
    @State private var isDistilling = false
    @State private var distillMessage: String?
    @State private var skillFeedback: (message: String, isError: Bool)?

    private var data: PPKSkillData { skillStore.skillData }

    private var isEmpty: Bool {
        data.lessons.isEmpty && data.successes.isEmpty
            && data.insights.isEmpty && data.scmErrorPatterns.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(.blue)
                    Text(L10n.aiSkillTitle).font(.system(size: 16, weight: .bold))
                    Spacer()
                    if isDistilling {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.8)
                            if !store.distillProgressText.isEmpty {
                                Text(store.distillProgressText)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            Task {
                                isDistilling = true
                                store.distillProgressText = L10n.settingsDistillProgress
                                distillMessage = nil
                                let n = await store.distillSkillsFromProjectHistory()
                                distillMessage = n > 0
                                    ? String(format: L10n.settingsDistillSuccess, n)
                                    : L10n.settingsDistillNone
                                isDistilling = false
                            }
                        } label: {
                            Label(L10n.settingsDistillFromHistory, systemImage: "wand.and.stars")
                                .font(.system(size: 11))
                        }
                        .liquidGlassButton()
                        .controlSize(.small)
                    }
                }
                .onAppear {
                    // Only (re)load from disk when the in-memory store is empty, so skills that
                    // were just distilled in this session are never wiped by a reload.
                    if skillStore.skillData.lessons.isEmpty && skillStore.skillData.successes.isEmpty {
                        skillStore.load(from: store.projectURL)
                    }
                }

                Divider()

                Text(L10n.aiSkillDesc)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Summary cards
                HStack(spacing: 12) {
                    skillStatCard(count: data.lessons.count, label: L10n.aiSkillLessons, accent: .orange)
                    skillStatCard(count: data.successes.count, label: L10n.aiSkillSuccesses, accent: .green)
                    skillStatCard(count: data.insights.count, label: L10n.aiSkillInsights, accent: .blue)
                    skillStatCard(count: data.scmErrorPatterns.count, label: L10n.aiSkillScmErrors, accent: .purple)
                }

                // Last updated
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("\(L10n.aiSkillUpdated): \(formattedDate(data.lastUpdated))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }

                if isEmpty {
                    emptyState
                } else {
                    if !data.lessons.isEmpty {
                        sectionHeader(L10n.aiSkillLessons, count: data.lessons.count)
                        ForEach(data.lessons) { lessonRow($0) }
                        if !data.successes.isEmpty || !data.insights.isEmpty || !data.scmErrorPatterns.isEmpty {
                            Divider()
                        }
                    }
                    if !data.successes.isEmpty {
                        sectionHeader(L10n.aiSkillSuccesses, count: data.successes.count)
                        ForEach(data.successes) { successRow($0) }
                        if !data.insights.isEmpty || !data.scmErrorPatterns.isEmpty {
                            Divider()
                        }
                    }
                    if !data.insights.isEmpty {
                        sectionHeader(L10n.aiSkillInsights, count: data.insights.count)
                        ForEach(data.insights) { insightRow($0) }
                        if !data.scmErrorPatterns.isEmpty {
                            Divider()
                        }
                    }
                    if !data.scmErrorPatterns.isEmpty {
                        sectionHeader(L10n.aiSkillScmErrors, count: data.scmErrorPatterns.count)
                        ForEach(data.scmErrorPatterns) { scmRow($0) }
                    }
                }

                Divider()

                if let msg = distillMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 14))
                        Text(msg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlassCard(cornerRadius: 8, tint: .green)
                }

                if let feedback = skillFeedback {
                    HStack(spacing: 8) {
                        Image(systemName: feedback.isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                            .foregroundStyle(feedback.isError ? .red : .green)
                            .font(.system(size: 14))
                        Text(feedback.message)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(feedback.isError ? .red : .green)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlassCard(cornerRadius: 8, tint: feedback.isError ? .red : .green)
                }

                // Clear all
                HStack {
                    Button {
                        exportSkills()
                    } label: {
                        Label(L10n.aiSkillExport, systemImage: "square.and.arrow.up")
                            .font(.system(size: 11))
                    }
                    .liquidGlassButton()
                    .controlSize(.small)

                    Button {
                        importSkills()
                    } label: {
                        Label(L10n.aiSkillImport, systemImage: "square.and.arrow.down")
                            .font(.system(size: 11))
                    }
                    .liquidGlassButton()
                    .controlSize(.small)

                    Spacer()

                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label(L10n.aiSkillClear, systemImage: "trash")
                            .font(.system(size: 11))
                    }
                    .liquidGlassButton(colors: [.red, .orange])
                    .controlSize(.small)
                    .disabled(isEmpty)
                    .confirmationDialog(L10n.aiSkillClearConfirm, isPresented: $showClearConfirm) {
                        Button(L10n.aiSkillClear, role: .destructive) {
                            skillStore.clearAll()
                            if !store.projectURL.path.isEmpty {
                                skillStore.save(to: store.projectURL)
                            }
                        }
                        Button(L10n.cancel, role: .cancel) {}
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(20)
        }
    }

    // MARK: Rows

    private func lessonRow(_ lesson: PPKLesson) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(severityColor(lesson.severity)).frame(width: 8, height: 8)
                Text(lesson.category.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(severityColor(lesson.severity))
                Spacer()
                if let run = lesson.sourceRun {
                    Text("run \(run)").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            Text(lesson.title).font(.system(size: 12, weight: .semibold))
            if !lesson.problem.isEmpty {
                Text("\(L10n.t("problem")): \(lesson.problem)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !lesson.solution.isEmpty {
                Text("\(L10n.t("solution")): \(lesson.solution)")
                    .font(.system(size: 10)).foregroundStyle(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !lesson.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(lesson.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(10)
        .liquidGlassCard(cornerRadius: 8, tint: severityColor(lesson.severity))
    }

    private func successRow(_ s: PPKSuccessPattern) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(s.title).font(.system(size: 12, weight: .semibold))
            if !s.context.isEmpty {
                Text("\(L10n.t("context")): \(s.context)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !s.action.isEmpty {
                Text("\(L10n.t("action")): \(s.action)")
                    .font(.system(size: 10)).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !s.result.isEmpty {
                Text("\(L10n.t("result")): \(s.result)")
                    .font(.system(size: 10)).foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .liquidGlassCard(cornerRadius: 8, tint: .green)
    }

    private func insightRow(_ ins: PPKParameterInsight) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(ins.parameter)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if let tv = ins.typicalValue {
                    Text("Typical ≈ \(String(format: "%.4g", tv))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if let om = ins.typicalOmega {
                    Text("ω ≈ \(String(format: "%.4g", om))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if !ins.covariates.isEmpty {
                    Text("Cov: \(ins.covariates.joined(separator: ", "))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if !ins.note.isEmpty {
                    Text(ins.note)
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .liquidGlassCard(cornerRadius: 8, tint: .blue)
    }

    private func scmRow(_ p: SCMErrorPattern) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("×\(p.occurrenceCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.purple)
                Text(p.diagnosis)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            Text("\(L10n.t("match")): \(p.pattern)")
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !p.fix.isEmpty {
                Text("\(L10n.t("fix")): \(p.fix)")
                    .font(.system(size: 10)).foregroundStyle(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .liquidGlassCard(cornerRadius: 8, tint: .purple)
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bookmark.fill").font(.system(size: 10)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 12, weight: .semibold))
            Text("(\(count))").font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func skillStatCard(count: Int, label: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .liquidGlassCard(cornerRadius: 10, tint: accent)
    }

    private func severityColor(_ s: LessonSeverity) -> Color {
        switch s {
        case .critical: return .red
        case .high:     return .orange
        case .medium:   return .yellow
        case .low:      return .gray
        }
    }

    private func formattedDate(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: d)
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(.secondary)
            Text(L10n.aiSkillEmpty)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: Import / Export

    private func exportSkills() {
        let panel = NSSavePanel()
        panel.title = L10n.aiSkillExport
        panel.allowedFileTypes = ["json"]
        panel.nameFieldStringValue = "AutoPMX_AI_Skills.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try skillStore.exportSkills(to: url)
            skillFeedback = (L10n.aiSkillExportSuccess, false)
        } catch {
            skillFeedback = (String(format: L10n.aiSkillExportFailed, error.localizedDescription), true)
        }
    }

    private func importSkills() {
        let panel = NSOpenPanel()
        panel.title = L10n.aiSkillImport
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["json"]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try skillStore.importSkills(from: url, merge: true)
            skillFeedback = (L10n.aiSkillImportSuccess, false)
        } catch {
            skillFeedback = (String(format: L10n.aiSkillImportFailed, error.localizedDescription), true)
        }
    }
}

// MARK: - Contact / Support
struct ContactSettingsPane: View {
    @ObservedObject private var lang = LanguageStore.shared

    private let supportEmail = "jugehang1995@163.com"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.t("contact.title"))
                    .font(.system(size: 16, weight: .bold))

                Divider()

                Text(L10n.t("contact.desc"))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Email card
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("contact.emailLabel"))
                        .font(.headline)
                    HStack(spacing: 8) {
                        Image(systemName: "envelope")
                            .foregroundColor(.accentColor)
                        Text(supportEmail)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(action: copyEmail) {
                            Label(L10n.t("contact.copy"), systemImage: "doc.on.doc")
                        }
                        .liquidGlassButton()
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .liquidGlassCard(cornerRadius: 10, tint: .blue)

                // Quick feedback button -> opens mail client
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("contact.feedbackLabel"))
                        .font(.headline)
                    Text(L10n.t("contact.feedbackDesc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: sendFeedback) {
                        Label(L10n.t("contact.send"), systemImage: "paperplane")
                    }
                    .liquidGlassButton()
                    .controlSize(.regular)
                }
                .padding(12)
                .liquidGlassCard(cornerRadius: 10, tint: .blue)

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func copyEmail() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(supportEmail, forType: .string)
    }

    private func sendFeedback() {
        let subject = L10n.t("contact.mailSubject")
        let body = L10n.t("contact.mailBody")
        var comps = URLComponents(string: "mailto:\(supportEmail)")!
        comps.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
    }
}

struct TokenBarChart: View {
    let data: [(label: String, input: Int, output: Int)]
    @State private var hoveredIndex: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let labelH: CGFloat = 22
            let axisW: CGFloat = 48
            let plotW = w - axisW - 6
            let n = max(1, data.count)
            let gap: CGFloat = 6
            let barW = max(4.0, (plotW - gap * CGFloat(n - 1)) / CGFloat(n))
            // Round max up to a "nice" number (1, 2, 5 × 10^n) for clean grid lines
            let rawMax = max(1, data.map { $0.input + $0.output }.max() ?? 1)
            let niceMax = niceCeil(rawMax)
            HStack(alignment: .top, spacing: 6) {
                // Y-axis labels — distributed so each tick aligns with its grid line.
                // Top label (100%) at top, bottom label (0%) at bottom of the plot area.
                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatAxisValue(Int(Double(niceMax) * 1.0)))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.75))
                    Spacer()
                    Text(formatAxisValue(Int(Double(niceMax) * 0.75)))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.75))
                    Spacer()
                    Text(formatAxisValue(Int(Double(niceMax) * 0.5)))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.75))
                    Spacer()
                    Text(formatAxisValue(Int(Double(niceMax) * 0.25)))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.75))
                    Spacer()
                    Text(formatAxisValue(0))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.75))
                }
                .frame(width: axisW)
                .frame(height: h - labelH, alignment: .top)

                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        // Subtle grid lines (one per tick)
                        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { frac in
                            Rectangle()
                                .fill(.primary.opacity(0.06))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .offset(y: (h - labelH) * (1 - frac))
                        }
                        HStack(alignment: .bottom, spacing: gap) {
                            ForEach(Array(data.enumerated()), id: \.offset) { idx, d in
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    if d.output > 0 {
                                        Rectangle().fill(Color.green.opacity(hoveredIndex == idx ? 1.0 : 0.9))
                                            .frame(width: barW, height: max(1, (h - labelH) * CGFloat(d.output) / CGFloat(niceMax)))
                                    }
                                    if d.input > 0 {
                                        Rectangle().fill(Color.blue.opacity(hoveredIndex == idx ? 1.0 : 0.9))
                                            .frame(width: barW, height: max(1, (h - labelH) * CGFloat(d.input) / CGFloat(niceMax)))
                                    }
                                }
                                .frame(width: barW, height: h - labelH, alignment: .bottom)
                            }
                        }
                        .frame(height: h - labelH)

                        // Hover highlight: vertical guide line + tooltip
                        if let hIdx = hoveredIndex, hIdx < data.count {
                            let barX = CGFloat(hIdx) * (barW + gap)
                            let d = data[hIdx]
                            Rectangle()
                                .fill(Color.primary.opacity(0.4))
                                .frame(width: 1, height: h - labelH)
                                .offset(x: barX + barW / 2)
                            // Tooltip card above the bar
                            VStack(alignment: .leading, spacing: 3) {
                                Text(d.label).font(.system(size: 10, weight: .semibold))
                                HStack(spacing: 4) {
                                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                                    Text("\(formatAxisValue(d.input))").font(.system(size: 9, design: .monospaced))
                                }
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                    Text("\(formatAxisValue(d.output))").font(.system(size: 9, design: .monospaced))
                                }
                                Text("Total: \(formatAxisValue(d.input + d.output))").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.95), in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                            .fixedSize()
                            .offset(x: max(0, min(barX + barW / 2 - 50, plotW - 110)),
                                    y: 4)
                        }

                        // Hover detection: each bar column gets its own invisible hit area
                        HStack(spacing: gap) {
                            ForEach(Array(data.enumerated()), id: \.offset) { idx, _ in
                                Color.clear
                                    .frame(width: barW, height: h - labelH)
                                    .contentShape(Rectangle())
                                    .onHover { inside in
                                        hoveredIndex = inside ? idx : nil
                                    }
                            }
                        }
                        .frame(height: h - labelH)
                    }
                    .frame(height: h - labelH)

                    HStack(spacing: gap) {
                        ForEach(Array(data.enumerated()), id: \.offset) { _, d in
                            Text(d.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.65))
                                .frame(width: barW, alignment: .center)
                        }
                    }
                    .frame(height: labelH)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
    }

    /// Round `n` up to a "nice" axis max (1, 2, 2.5, 5, 10 × 10^k).
    private func niceCeil(_ n: Int) -> Int {
        guard n > 0 else { return 1 }
        let exp = Int(floor(log10(Double(n))))
        let pow10 = pow(10.0, Double(exp))
        let frac = Double(n) / pow10
        let niceFrac: Double
        if frac <= 1.0 { niceFrac = 1.0 }
        else if frac <= 2.0 { niceFrac = 2.0 }
        else if frac <= 2.5 { niceFrac = 2.5 }
        else if frac <= 5.0 { niceFrac = 5.0 }
        else { niceFrac = 10.0 }
        return Int(niceFrac * pow10)
    }

    private func formatAxisValue(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1000 { return String(format: "%.1fK", Double(n) / 1000) }
        return "\(n)"
    }
}

// MARK: - About Pane

struct AboutPane: View {
    @ObservedObject private var lang = LanguageStore.shared
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
                Text("AutoPMx")
                    .font(.system(size: 20, weight: .bold))
                Text("DuDu PMx Workbench")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Version 1.1.0 (Build 3)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("macOS native pharmacometrics modeling workbench.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Integrated NONMEM/PsN execution, AI-assisted model building (DuDu PMx),")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("GA optimization, diagnostic visualization, and liquid-glass Dark Mode.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                    Text("Built with SwiftUI · macOS 13+")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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

// MARK: - DuDu Personality Pane

struct DuDuPersonalityPane: View {
    @EnvironmentObject var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 8) {
                    Text(L10n.duduChatStyle)
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }

                Divider()

                // Personality cards
                Group {
                    ForEach(DuDuPersonality.allCases) { personality in
                        PersonalityCard(
                            personality: personality,
                            isSelected: store.duDuPersonality == personality,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    store.duDuPersonality = personality
                                }
                            }
                        )
                    }
                }
                .id(lang.language.rawValue)

                // Custom personality editor (shown when custom is selected)
                if store.duDuPersonality == .custom {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.line")
                                .foregroundStyle(.blue)
                            Text(L10n.duduCustomPrompt)
                                .font(.system(size: 14, weight: .semibold))
                        }

                        Text(L10n.duduCustomPromptDesc)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TextEditor(text: $store.customPersonalityPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                            )

                        if store.customPersonalityPrompt.isEmpty {
                            Text(L10n.duduCustomPromptPlaceholder)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Learning style section — LLM-generated skill document
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.blue)
                        Text(L10n.duduLearnStyle)
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text(L10n.duduLearnStyleDesc)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Toggle
                    HStack {
                        Toggle(L10n.duduLearnStyleToggle, isOn: $store.isLearningUserStyle)
                            .font(.system(size: 13))

                        Spacer()

                        if store.isLearningUserStyle {
                            HStack(spacing: 4) {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 10))
                                Text(String(format: L10n.duduCollectedMessages, store.userMessageArchive.count))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Generate report button
                    if store.isLearningUserStyle {
                        HStack(spacing: 8) {
                            Button(action: { store.generateStyleReport() }) {
                                HStack(spacing: 4) {
                                    if store.isGeneratingStyleReport {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 14, height: 14)
                                        Text(L10n.duduGenerating)
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text(L10n.duduGenerateProfile)
                                    }
                                }
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(store.userMessageArchive.count < 5 || store.isGeneratingStyleReport
                                          ? Color.secondary.opacity(0.3)
                                          : Color.blue)
                            )
                            .disabled(store.userMessageArchive.count < 5 || store.isGeneratingStyleReport)

                            if store.userMessageArchive.count < 5 {
                                Text(L10n.duduMinMessages)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }

                    // Show generated style report
                    if store.isLearningUserStyle && !store.styleReport.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L10n.duduStyleProfile)
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text(L10n.duduGeneratedByLLM)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }

                            ScrollView {
                                Text(store.styleReport)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 160)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.blue.opacity(0.12), lineWidth: 1)
                            )
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                store.styleReport = ""
                                store.userMessageArchive.removeAll()
                            }) {
                                Label(L10n.duduClearAll, systemImage: "trash")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            Button(action: { store.generateStyleReport() }) {
                                Label(L10n.duduRegenerate, systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            .disabled(store.isGeneratingStyleReport)

                            Spacer()
                        }
                    }

                    // Empty state hint
                    if !store.isLearningUserStyle && store.styleReport.isEmpty && store.userMessageArchive.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                            Text(L10n.duduLearnStyleHint)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
    }
}

struct PersonalityCard: View {
    let personality: DuDuPersonality
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var lang = LanguageStore.shared

    private var duDuLogo: NSImage? {
        let candidates = [
            BundledResource.url(forResource: "DuDuPMxButton", withExtension: "png"),
            BundledResource.url(forResource: "DuDuPMxSource", withExtension: "png"),
        ]
        for url in candidates {
            if let url, let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                // DuDu app icon
                if let logo = duDuLogo {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Text(personality.icon)
                                .font(.system(size: 11))
                                .padding(2)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                } else if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Text(personality.icon)
                                .font(.system(size: 11))
                                .padding(2)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 28))
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Text(personality.icon)
                                .font(.system(size: 11))
                                .padding(2)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(personality.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(personality.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .liquidGlassCard(cornerRadius: 14, tint: isSelected ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .liquidGlassHover(cornerRadius: 14)
    }
}

// MARK: - Reusable Unit Picker

fileprivate struct PickerView: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    let width: CGFloat
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .frame(width: width)
            .onChange(of: selection) { _ in onChange() }
        }
    }
}
