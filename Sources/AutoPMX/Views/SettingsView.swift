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

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "switch.2"
        case .chat: return "message.badge"
        case .llm: return "cpu"
        case .tools: return "wrench.and.screwdriver"
        case .rules: return "book.pages"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared
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
            case .chat: DuDuPersonalityPane()
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

                Divider()

                // Particle effects
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.particleEffects).font(.system(size: 12, weight: .semibold))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.particleEffectsEnable)
                                .font(.system(size: 12))
                            Text(L10n.particleEffectsDesc)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: $store.particleEffectsEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    if store.particleEffectsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.particleCount)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                ForEach([10, 30, 100, 1000, 10000], id: \.self) { count in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            store.particleCount = count
                                        }
                                    } label: {
                                        VStack(spacing: 3) {
                                            Text("\(count)")
                                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                            Text(count <= 30 ? L10n.particleLite : count <= 100 ? L10n.particleStandard : L10n.particlePerformance)
                                                .font(.system(size: 9))
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(width: 64, height: 42)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(store.particleCount == count
                                                      ? Color.blue.opacity(0.10)
                                                      : Color.primary.opacity(0.03))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(store.particleCount == count
                                                        ? Color.blue.opacity(0.35) : Color.primary.opacity(0.08),
                                                        lineWidth: store.particleCount == count ? 1.2 : 0.6)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Particle preview
                            ParticlePreview(count: store.particleCount, enabled: store.particleEffectsEnabled)
                                .frame(height: 48)
                                .background(.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(.primary.opacity(0.06), lineWidth: 0.5)
                                )
                                .padding(.top, 4)
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
                Text(L10n.settingsLLM)
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button {
                    startAddingProvider()
                } label: {
                    Label(L10n.settingsAddProvider, systemImage: "plus")
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
                    Text(provider.name.isEmpty ? L10n.settingsUnnamed : provider.name)
                        .font(.system(size: 12, weight: .medium))
                    Text(provider.model.isEmpty ? L10n.settingsNoModel : provider.model)
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
                                Text(L10n.settingsName).font(.system(size: 10)).foregroundStyle(.tertiary)
                                TextField("Provider name", text: binding.name)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.settingsApiFormat).font(.system(size: 10)).foregroundStyle(.tertiary)
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
                            Text(L10n.settingsBaseURL).font(.system(size: 10)).foregroundStyle(.tertiary)
                            TextField("https://api.example.com/v1", text: binding.baseURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.settingsModel).font(.system(size: 10)).foregroundStyle(.tertiary)
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
                            Text(L10n.settingsApiKey).font(.system(size: 10)).foregroundStyle(.tertiary)
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
                Text(L10n.settingsAddProvider)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsName).font(.system(size: 10)).foregroundStyle(.tertiary)
                        TextField("My Provider", text: $newProviderDraft.name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.settingsApiFormat).font(.system(size: 10)).foregroundStyle(.tertiary)
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
                    Text(L10n.settingsBaseURL).font(.system(size: 10)).foregroundStyle(.tertiary)
                    TextField("https://api.example.com/v1", text: $newProviderDraft.baseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.settingsModel).font(.system(size: 10)).foregroundStyle(.tertiary)
                    TextField("model-name", text: $newProviderDraft.model)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.settingsApiKey).font(.system(size: 10)).foregroundStyle(.tertiary)
                    SecureField("sk-...", text: $newProviderDraft.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }

                HStack {
                    Spacer()
                    Button(L10n.cancel) { withAnimation { isAddingProvider = false } }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button(L10n.settingsAddProvider) {
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
                    Text(L10n.toolsTitle)
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
                    Text(L10n.toolsFileViewers)
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.settingsToolsViewersHint)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // Data file
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.toolsDataFile)
                        .font(.system(size: 11, weight: .semibold))
                    HStack(spacing: 8) {
                        TextField("NM_dat_new.csv", text: $store.dataFile)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 240)
                        Text(L10n.toolsDataFileDesc)
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

                Button(L10n.settingsAutoDetect, action: onAutoDetect)
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
                     : L10n.settingsNotFound)
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
                    Text(L10n.rulesTitle)
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                }

                // Rule sources editor
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.settingsSourceFiles)
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.rulesSourceFilesDesc)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    TextField("poppk_rules.json, poppk_model_library.md, NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md", text: $store.ruleSourceFiles)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))

                    HStack {
                        Button {
                            store.refreshRuleContextStatus()
                        } label: {
                            Label(L10n.settingsReloadRules, systemImage: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered).controlSize(.small)

                        Button {
                            store.ruleSourceFiles = "poppk_rules.json, poppk_model_library.md, PopPK_Expert_Audit_Report.md, NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md"
                            store.refreshRuleContextStatus()
                        } label: {
                            Label(L10n.settingsLoadAllDefaults, systemImage: "books.vertical")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                }

                Divider()

                // Status
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
                .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))

                Divider()

                // Available rule files in workspace
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.settingsKnownFiles)
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.rulesKnownFilesDesc)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    let knownFiles = discoverKnownRuleFiles()
                    if knownFiles.isEmpty {
                        Text(L10n.settingsNoRuleFiles)
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
                                    Button(L10n.settingsAdd) {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 8) {
                    Text("DuDu 对话风格")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                }
                .padding(.bottom, 4)

                Text("选择你喜欢的对话风格，DuDu 会根据你的偏好调整语气和回答方式。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                // Personality cards
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

                // Custom personality editor (shown when custom is selected)
                if store.duDuPersonality == .custom {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil.line")
                                .foregroundStyle(.blue)
                            Text("自定义人设 Prompt")
                                .font(.system(size: 14, weight: .semibold))
                        }

                        Text("在这里写你想让 DuDu 扮演的角色、说话方式、口头禅等。这段内容会直接注入到 LLM 的 System Prompt 中。")
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
                            Text("例如：你是一个说话喜欢用「咱就是说」开头的东北老铁版药代顾问，专业但不失亲切，喜欢用大碴子味的比喻来解释复杂概念。")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
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
                        Text("学习你的说话风格")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text("开启后，DuDu 会收集你的聊天消息。可在收集一定数量后点击「生成风格档案」，由 LLM 为你生成一份结构化的说话风格 skill 文档，注入到 DuDu 的 System Prompt 中。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Toggle
                    HStack {
                        Toggle("启用风格学习", isOn: $store.isLearningUserStyle)
                            .font(.system(size: 13))

                        Spacer()

                        if store.isLearningUserStyle {
                            HStack(spacing: 4) {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 10))
                                Text("已收集 \(store.userMessageArchive.count) 条消息")
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
                                        Text("正在生成...")
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("生成风格档案")
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
                                Text("至少需要 5 条消息")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                    }

                    // Show generated style report
                    if store.isLearningUserStyle && !store.styleReport.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("风格档案")
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text("由 LLM 生成")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
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
                                Label("清空全部记录", systemImage: "trash")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)

                            Button(action: { store.generateStyleReport() }) {
                                Label("重新生成", systemImage: "arrow.triangle.2.circlepath")
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
                            Text("开启后，每当你和 DuDu 聊天，消息会被收集。积累一定量后，点击「生成风格档案」，LLM 会分析你的说话习惯并生成一份 skill 文档，之后 DuDu 的回复就会自动匹配你的风格～")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
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
                } else {
                    Text("🦆")
                        .font(.system(size: 32))
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                        )
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
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .liquidGlassHover(cornerRadius: 14)
    }
}

// MARK: - Particle Preview

struct ParticlePreview: View {
    let count: Int
    let enabled: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard enabled, count > 0 else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate
                let displayCount = min(count, 10000)

                for i in 0..<displayCount {
                    let seed   = Double(i) * 1.9 + 0.5
                    let px = Double(i) * 0.553
                    let py = Double(i) * 0.371
                    // 3× faster multi-octave pseudo-random drift
                    let rawX = sin(t * 0.51 + px) * cos(t * 0.36 + px * 2.1) * 0.6
                             + sin(t * 0.24 + px * 0.5) * 0.4
                    let rawY = cos(t * 0.45 + py) * sin(t * 0.30 + py * 1.4) * 0.6
                             + cos(t * 0.18 + py * 0.8) * 0.4
                    let x = size.width  * (0.08 + 0.84 * ((rawX + 1.0) / 2.0))
                    let y = size.height * (0.10 + 0.80 * ((rawY + 1.0) / 2.0))
                    let alpha = 0.10 + 0.12 * sin(t * 1.95 + seed)
                    let radius: CGFloat = 0.6 + 0.7 * sin(t * 1.05 + seed * 0.7)

                    // Blue gradient shades
                    let bright = 0.55 + 0.45 * sin(t * 0.6 + seed * 1.3)
                    let color = Color(
                        hue: 0.58 + 0.05 * sin(t * 0.3 + seed),
                        saturation: 0.65 + 0.35 * sin(t * 0.4 + seed * 0.6),
                        brightness: bright
                    ).opacity(alpha)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}
