import SwiftUI
import AppKit

// MARK: - DuDu PMx Typography Presets

/// Rounded, open typography for DuDu PMx — much more comfortable for Chinese text.
enum DuDuFont {
    // Body text (chat messages, descriptions)
    static func body(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func bodyMedium(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func bodySemibold(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    // Headline / title
    static func title(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    // Caption / small labels
    static func caption(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func captionMedium(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func captionSemibold(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    // Monospace (code, NONMEM)
    static func mono(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    // Icon labels
    static func icon(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
}

// MARK: - Overlay

struct AIAssistantOverlay: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared
    @State private var dragOffset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Liquid-glass notice card: model-only action requested but no .mod files exist
            if store.noModelCardVisible {
                NoModelNoticeCard()
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            if store.isAssistantPanelPresented {
                AssistantPanel()
                    .frame(width: 420, height: 600)
                    .transition(.opacity)
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
            }

            // Warning banner during auto modeling / SCM / bootstrap
            if store.isAutoModeling || store.isSCMRunning || store.isBootstrapRunning {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(store.isSCMRunning ? L10n.scmBusySwitchWarning
                        : (store.isBootstrapRunning ? L10n.bootstrapBusySwitchWarning : L10n.aiAutoModelingBusy))
                        .font(DuDuFont.captionSemibold(11))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .transition(.scale.combined(with: .opacity))
            }

            // Compact progress popup when DuDu panel is hidden during auto modeling / SCM
            if (store.isAutoModeling || store.isSCMRunning || store.isBootstrapRunning) && !store.isAssistantPanelPresented {
                MiniProgressPopup(
                    title: store.isSCMRunning ? L10n.scmPopupTitle
                        : (store.isBootstrapRunning ? L10n.bootstrapPopupTitle : "DuDu Auto"),
                    step: store.automationStep
                )
                    .onTapGesture { store.isAssistantPanelPresented = true }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            Button {
                withAnimation(.easeOut(duration: 0.1)) {
                    store.isAssistantPanelPresented.toggle()
                }
            } label: {
                FloatingButton(isActive: store.isAutoModeling || store.isSCMRunning || store.isBootstrapRunning || store.isAssistantThinking || store.isAIThinking, showingDuDu: duDuThumb != nil)
            }
        }
        .offset(x: settledOffset.width + dragOffset.width, y: settledOffset.height + dragOffset.height)
        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.7, blendDuration: 0), value: dragOffset)
        .gesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                let candidate = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
                let clamped = clampedDuDuOffset(candidate)
                dragOffset = CGSize(
                    width: clamped.width - settledOffset.width,
                    height: clamped.height - settledOffset.height
                )
            }
            .onEnded { value in
                let candidate = CGSize(
                    width: settledOffset.width + value.translation.width,
                    height: settledOffset.height + value.translation.height
                )
                settledOffset = clampedDuDuOffset(candidate)
                dragOffset = .zero
            }
        )
        .buttonStyle(.plain)
        .help("DuDu PMx")
    }

    private var duDuThumb: NSImage? {
        let candidates = [
            BundledResource.url(forResource: "DuDuPMxButton", withExtension: "png"),
            BundledResource.url(forResource: "DuDuPMxSource", withExtension: "png")
        ]
        for u in candidates {
            if let u, let img = NSImage(contentsOf: u) { return img }
        }
        return nil
    }

    private func clampedDuDuOffset(_ candidate: CGSize) -> CGSize {
        guard let frame = NSApp.keyWindow?.frame ?? NSApp.mainWindow?.frame else {
            return candidate
        }

        let buttonSize: CGFloat = 56
        let margin: CGFloat = 12
        let padding: CGFloat = 24

        // Offset 0 is the button's natural bottom-trailing position.
        let originalX = frame.width - buttonSize - padding
        let originalY = frame.height - buttonSize - padding

        let minX = margin - originalX
        let maxX = frame.width - buttonSize - margin - originalX
        let minY = margin - originalY
        let maxY = frame.height - buttonSize - margin - originalY

        return CGSize(
            width: min(max(candidate.width, minX), maxX),
            height: min(max(candidate.height, minY), maxY)
        )
    }
}

// MARK: - DuDu Mood

enum DuDuMood: String, CaseIterable {
    case happy
    case thinking
    case working
    case excited
    case sad
    case angry

    var emoji: String {
        switch self {
        case .happy:    return "\u{1F60A}"  // 😊
        case .thinking: return "\u{1F914}"  // 🤔
        case .working:  return "\u{1F9D0}"  // 🧐
        case .excited:  return "\u{1F929}"  // 🤩
        case .sad:      return "\u{1F622}"  // 😢
        case .angry:    return "\u{1F620}"  // 😠
        }
    }

    var auraColor: Color {
        switch self {
        case .happy:    return .blue
        case .thinking: return .purple
        case .working:  return .cyan
        case .excited:  return .orange
        case .sad:      return .gray
        case .angry:    return .red
        }
    }

    var bounceHeight: CGFloat {
        switch self {
        case .happy:    return 3
        case .thinking: return 2
        case .working:  return 1.5
        case .excited:  return 8
        case .sad:      return 0.5
        case .angry:    return 5
        }
    }
}

// MARK: - DuDu Pet Button (replaces FloatingButton)

struct FloatingButton: View {
    let isActive: Bool
    let showingDuDu: Bool

    @EnvironmentObject private var store: WorkbenchStore
    @State private var glowPhase: Double = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var wiggleAngle: Double = 0
    @State private var showEmotionPopup: Bool = false
    @State private var emotionPhase: Int = 0

    private let auroraColors: [Color] = [
        Color(hue: 0.58, saturation: 0.7, brightness: 0.9),
        Color(hue: 0.65, saturation: 0.6, brightness: 0.85),
        Color(hue: 0.75, saturation: 0.55, brightness: 0.88),
        Color(hue: 0.82, saturation: 0.5, brightness: 0.9),
        Color(hue: 0.72, saturation: 0.65, brightness: 0.85),
        Color(hue: 0.60, saturation: 0.6, brightness: 0.88),
        Color(hue: 0.55, saturation: 0.7, brightness: 0.9),
        Color(hue: 0.68, saturation: 0.5, brightness: 0.92),
    ]

    var body: some View {
        let mood = store.duDuMood

        ZStack {
            // Emotion popup bubble
            if showEmotionPopup {
                emotionPopup(mood: mood)
                    .offset(y: -48)
                    .transition(.scale.combined(with: .opacity))
            }

            ZStack {
                // Ambient glow ring
                Circle()
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: auroraColors), center: .center),
                        lineWidth: 1.5
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(glowPhase * 360))
                    .blur(radius: 2)
                    .opacity(isActive ? 1 : 0.25)
                    .onAppear {
                        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                            glowPhase = 1
                        }
                    }

                // Active aurora rings
                if isActive {
                    AuroraRing(
                        colors: [mood.auraColor.opacity(0.4), mood.auraColor.opacity(0.15), .clear],
                        size: 56, lineWidth: 3, duration: 4
                    )
                    AuroraRing(
                        colors: [mood.auraColor.opacity(0.35), mood.auraColor.opacity(0.15), .clear],
                        size: 48, lineWidth: 2, duration: 3, reverse: true
                    )
                }

                // Background circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                    .overlay(
                        Circle()
                            .stroke(isActive ? mood.auraColor.opacity(0.3) : .clear, lineWidth: 1)
                    )

                // DuDu logo or default icon
                if showingDuDu,
                   let logo = NSImage(contentsOf: BundledResource.url(forResource: "DuDuPMxButton", withExtension: "png")
                    ?? BundledResource.url(forResource: "DuDuPMxSource", withExtension: "png")!) {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                        .saturation(mood == .sad ? 0.3 : 1)
                        .brightness(mood == .angry ? -0.1 : 0)
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(DuDuFont.icon(16))
                        .foregroundStyle(mood.auraColor)
                }

                // Personality badge: lets each chat style read differently at a glance.
                if showingDuDu {
                    Text(store.duDuPersonality.icon)
                        .font(.system(size: 10))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                        .offset(x: 15, y: -15)
                }
            }
        }
        .frame(width: 56, height: 56)
        // Bounce animation
        .offset(y: bounceOffset)
        // Wiggle for thinking/angry
        .rotationEffect(.degrees(wiggleAngle))
        // Spring feel
        .onAppear { startIdleAnimation() }
        .onChangeCompat(of: store.duDuMood) { newMood in
            reactToMood(newMood)
        }
    }

    // MARK: - Emotion Popup

    @ViewBuilder
    private func emotionPopup(mood: DuDuMood) -> some View {
        Text(mood.emoji)
            .font(.system(size: 24))
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }

    // MARK: - Animations

    private func startIdleAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            bounceOffset = -3
        }
    }

    private func reactToMood(_ mood: DuDuMood) {
        // Show emotion popup
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showEmotionPopup = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                showEmotionPopup = false
            }
        }

        // Mood-specific animations using Task-based sequencing
        switch mood {
        case .happy:
            bounceJump(count: 1, height: -6, settleAt: -3)
        case .thinking:
            wiggleShake(times: 3, angle: 8)
        case .working:
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) {
                bounceOffset = -1.5
            }
        case .excited:
            bounceJump(count: 3, height: -10, settleAt: -3)
        case .sad:
            withAnimation(.easeInOut(duration: 0.8)) { bounceOffset = 0 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    bounceOffset = -3
                }
            }
        case .angry:
            wiggleShake(times: 4, angle: -10)
            bounceJump(count: 2, height: -6, settleAt: -3)
        }
    }

    private func bounceJump(count: Int, height: CGFloat, settleAt: CGFloat) {
        Task { @MainActor in
            for i in 0..<count {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
                    bounceOffset = height
                }
                try? await Task.sleep(nanoseconds: UInt64(200_000_000))
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    bounceOffset = settleAt
                }
                if i < count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(100_000_000))
                }
            }
        }
    }

    private func wiggleShake(times: Int, angle: Double) {
        Task { @MainActor in
            for _ in 0..<times {
                withAnimation(.easeInOut(duration: 0.08)) {
                    wiggleAngle = angle
                }
                try? await Task.sleep(nanoseconds: UInt64(80_000_000))
                withAnimation(.easeInOut(duration: 0.08)) {
                    wiggleAngle = -angle * 0.6
                }
                try? await Task.sleep(nanoseconds: UInt64(80_000_000))
            }
            withAnimation(.easeInOut(duration: 0.1)) { wiggleAngle = 0 }
        }
    }
}



// MARK: - Aurora Ring

struct AuroraRing: View {
    let colors: [Color]
    let size: CGFloat
    let lineWidth: CGFloat
    let duration: Double
    var reverse: Bool = false

    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: colors),
                    center: .center
                ),
                lineWidth: lineWidth
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .blur(radius: 1.5)
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = reverse ? -360 : 360
                }
            }
    }
}

// MARK: - Context Usage Ring

/// Small ring showing how much of the LLM context window is occupied by the
/// currently loaded rule/knowledge context (and the latest request prompt).
private struct ContextUsageRing: View {
    let used: Int
    let limit: Int

    private var ratio: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(used) / Double(limit))
    }
    private var ringColor: Color {
        ratio < 0.6 ? .green : (ratio < 0.85 ? .orange : .red)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: ratio)
            Text("\(Int(ratio * 100))%")
                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(width: 24, height: 24)
    }
}

/// Header badge: a ring plus a hover popover with full context-usage details.
struct ContextUsageBadge: View {
    @ObservedObject var store: WorkbenchStore

    @State private var show = false
    @State private var closeTask: DispatchWorkItem?

    init(store: WorkbenchStore) {
        self.store = store
    }

    private var used: Int { max(store.lastTokenUsage.input, store.contextTokenEstimate) }
    private var limit: Int { store.contextWindowLimitTokens }
    private var ratio: Double { limit > 0 ? min(1.0, Double(used) / Double(limit)) : 0 }

    private func keepOpen() { closeTask?.cancel(); show = true }
    private func scheduleClose() {
        closeTask?.cancel()
        let task = DispatchWorkItem { show = false }
        closeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
    }

    var body: some View {
        ContextUsageRing(used: used, limit: limit)
            .contentShape(Circle())
            .onHover { inside in inside ? keepOpen() : scheduleClose() }
            .popover(isPresented: $show, arrowEdge: .bottom) {
                contextPopover
            }
    }

    private var contextPopover: some View {
        let mem = MemoryMonitor.shared
        return VStack(alignment: .leading, spacing: 8) {
            Text(L10n.ctxUsagePanel).font(.headline)
            row(L10n.ctxWindowLimit, "\(limit) tok")
            row(L10n.ctxRuleContext, "\(store.contextTokenEstimate) tok")
            row(L10n.ctxRequestPrompt, "\(store.lastTokenUsage.input) tok")
            row(L10n.ctxOutput, "\(store.lastTokenUsage.output) tok")
            Divider()
            row(L10n.t("tokens.memUsed"), "\(mem.formatBytes(mem.snapshot.usedBytes)) (\(Int(mem.snapshot.usageRatio * 100))%)")
            row(L10n.t("tokens.memLLM"), mem.llmProcessName.isEmpty
                ? L10n.t("tokens.memLLMNone")
                : "\(mem.llmProcessName) · \(mem.formatBytes(mem.llmProcessBytes))")
            if mem.snapshot.usageRatio >= 0.8 {
                Text(L10n.t("tokens.memWarning"))
                    .font(.caption2).foregroundStyle(.red)
            }
            Divider()
            row(L10n.ctxTotalInput, "\(store.totalInputTokens) tok")
            row(L10n.ctxTotalOutput, "\(store.totalOutputTokens) tok")
            let cached = store.totalCacheReadTokens
            let written = store.totalCacheWriteTokens
            let base = cached + written
            row(L10n.ctxCacheRead, "\(cached) tok")
            row(L10n.ctxCacheWrite, "\(written) tok")
            if base > 0 {
                row(L10n.ctxCacheHitRate, String(format: "%.0f%%", Double(cached) / Double(base) * 100))
            }
            Text(String(format: L10n.ctxWindowOccupied, Int(ratio * 100)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ratio < 0.6 ? .green : (ratio < 0.85 ? .orange : .red))
            if store.lastTokenUsage.input == 0 {
                Text(L10n.ctxNoUsage)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 240)
        .onAppear { MemoryMonitor.shared.refresh() }
        .onHover { inside in inside ? keepOpen() : scheduleClose() }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - Assistant Panel

struct AssistantPanel: View {
    @EnvironmentObject private var store: WorkbenchStore
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
            if !store.thinkingSteps.isEmpty { thinkingStepsView }
            messagesView
            inputBarView
        }
        .background(
            GlassBackground()
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // Simple, quiet border around the card
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.black.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 18, y: 6)
        .onAppear {
            // Self-heal stale "busy" state so quick actions / STOP are never stuck.
            store.runner.recoverIfStuck()
        }
        .sheet(isPresented: $store.isAutomationOptionsPresented) {
            AutomationOptionsSheetView().environmentObject(store)
        }
        .sheet(isPresented: $store.isCompareSheetPresented) {
            ModelCompareSheetView().environmentObject(store)
        }
        .sheet(isPresented: $store.showSCMDialog) {
            SCMSetupSheetView().environmentObject(store)
        }
        .sheet(item: $showRunPicker) { action in
            RunPickerSheet(action: action)
                .environmentObject(store)
                .frame(width: 260, height: 320)
        }
        .sheet(isPresented: $store.isBaseModelConfirmPresented) {
            BaseModelConfirmView()
                .environmentObject(store)
                .frame(width: 440, height: 380)
        }
        .sheet(isPresented: $store.isCompDecisionPresented) {
            CompDecisionView()
                .environmentObject(store)
                .frame(width: 480, height: 360)
        }
    }

    // MARK: Header
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let logo = duDuThumb {
                    Image(nsImage: logo).resizable().scaledToFit()
                        .frame(width: 22, height: 22).clipShape(Circle())
                }
                Text("DuDu PMx").font(DuDuFont.bodySemibold())
                Spacer()
                // Context-usage ring — hover to see details
                ContextUsageBadge(store: store)
                    .padding(.trailing, 4)
                HStack(spacing: 6) {
                    if store.assistantMessages.count > 10 {
                        Button {
                            store.compressChatContext()
                        } label: {
                            Image(systemName: "compress")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Compress chat context to save memory")
                    }
                }
                Button {
                    withAnimation(.easeOut(duration: 0.1)) {
                        store.isAssistantPanelPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Hide DuDu panel")
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    // MARK: Thinking Steps
    @State private var isThinkingCollapsed = true
    @State private var isThinkingHovered = false
    @State private var thinkingPulse = false

    private var hasActiveThinkingSteps: Bool {
        store.thinkingSteps.contains { $0.type == .thinking || $0.type == .working }
    }

    private var thinkingHeaderIcon: String {
        if hasActiveThinkingSteps { return "sparkles" }
        if !store.thinkingSteps.isEmpty,
           store.thinkingSteps.allSatisfy({ $0.type == .done }) { return "checkmark.circle.fill" }
        return "brain"
    }

    private var thinkingHeaderColor: Color {
        if hasActiveThinkingSteps { return .blue }
        if !store.thinkingSteps.isEmpty,
           store.thinkingSteps.allSatisfy({ $0.type == .done }) { return .green }
        return .secondary
    }

    private var thinkingStepsView: some View {
        VStack(spacing: 6) {
            // ── Collapsed header: liquid-glass pill ──
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isThinkingCollapsed.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: thinkingHeaderIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(thinkingHeaderColor)
                        .opacity(hasActiveThinkingSteps && thinkingPulse ? 0.45 : 1.0)
                        .animation(
                            hasActiveThinkingSteps
                                ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true)
                                : .default,
                            value: thinkingPulse
                        )
                    Text(L10n.aiReasoning)
                        .font(DuDuFont.captionSemibold(11))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Text("\(store.thinkingSteps.count) \(L10n.aiSteps)")
                        .font(DuDuFont.caption(10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.white.opacity(0.22), in: Capsule())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isThinkingCollapsed ? -90 : 0))
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(isThinkingHovered ? 0.06 : 0.0))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .onHover { inside in
                withAnimation(.easeOut(duration: 0.15)) { isThinkingHovered = inside }
            }

            // ── Expanded: glass step list ──
            if !isThinkingCollapsed {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(store.thinkingSteps) { step in
                            let isLive = hasActiveThinkingSteps && step.id == store.thinkingSteps.last?.id
                            HStack(alignment: .top, spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(step.type.color.opacity(isLive ? 0.20 : 0.13))
                                        .frame(width: 19, height: 19)
                                    Image(systemName: step.type.symbol)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(step.type.color)
                                }
                                .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.text)
                                        .font(DuDuFont.caption())
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                    if !step.detail.isEmpty {
                                        Text(step.detail)
                                            .font(DuDuFont.mono(9))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .textSelection(.enabled)
                                    }
                                }

                                Spacer(minLength: 0)

                                if isLive {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(
                                isLive
                                    ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(step.type.color.opacity(0.08))
                                    : nil
                            )
                        }
                    }
                    .padding(6)
                }
                .scrollContentBackground(.hidden)
                .frame(maxHeight: 150)
                .padding(.horizontal, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { thinkingPulse = true }
    }

    // MARK: Messages — iMessage style
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.assistantMessages) { msg in
                        iMessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if store.isAssistantThinking || store.isAIThinking {
                        HStack(alignment: .bottom, spacing: 8) {
                            duDuAvatarView
                            TypingIndicator()
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(assistantBubbleBackground)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: store.assistantMessages.count) { _ in
                if let last = store.assistantMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // DuDu's circular avatar (reuses the app's DuDu image when available)
    private var duDuAvatarView: some View {
        Group {
            if let img = duDuThumb {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(
                        LinearGradient(colors: [Color(red: 0.45, green: 0.68, blue: 1.0),
                                                Color(red: 0.70, green: 0.35, blue: 1.0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        .padding(.bottom, 1)
    }

    // Your avatar — a friendly person chip on the right side
    private var userAvatarView: some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            Image(systemName: "person.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: .blue.opacity(0.25), radius: 2, y: 1)
    }

    // DuDu's message bubble — light-gray liquid glass (iMessage style).
    // Frosted material + a soft gray tint + a white top-edge highlight give it the
    // "liquid glass" look while staying neutral; the user's own bubbles stay blue.
    private var assistantBubbleBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(0.92))
            .overlay(
                LinearGradient(
                    colors: [Color.gray.opacity(0.12), Color.gray.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.60), .white.opacity(0.10)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .overlay(
                LinearGradient(colors: [.white.opacity(0.28), .clear],
                               startPoint: .top, endPoint: .center)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 5, y: 1.5)
    }

    // Conversation-style bubble with avatars and Markdown rendering for DuDu's messages
    private func iMessageBubble(message: AssistantMessage) -> some View {
        let isUser = message.role == .user
        return HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 42)
            } else {
                duDuAvatarView
            }

            if isUser {
                // Your message — blue gradient bubble on the right
                Text(message.text)
                    .font(DuDuFont.body())
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(colors: [Color.blue.opacity(0.92), Color(red: 0.25, green: 0.55, blue: 1.0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .blue.opacity(0.22), radius: 4, y: 1)
                    .contextMenu {
                        Button(L10n.aiCopy) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        }
                        Button(L10n.aiFillInput) { store.assistantInput = message.text }
                    }
                    .frame(maxWidth: 300, alignment: .trailing)
                userAvatarView
            } else {
                // DuDu's message — soft glass bubble on the left, avatar beside it
                VStack(alignment: .leading, spacing: 3) {
                    MarkdownMessageView(text: message.text)
                        .contextMenu {
                            Button(L10n.aiCopy) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.text, forType: .string)
                            }
                            Button(L10n.aiFillInput) { store.assistantInput = message.text }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(assistantBubbleBackground)
                        .frame(maxWidth: 360, alignment: .leading)

                    // Collapsible Source Citations
                    if !message.citations.isEmpty {
                        CitationSection(citations: message.citations)
                            .padding(.horizontal, 4)
                    }

                    // Action keyword chips
                    let actions = detectedActions(in: message.text)
                    if !actions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(actions.indices, id: \.self) { idx in
                                AnimatedActionChip(
                                    label: actions[idx].label,
                                    systemImage: actions[idx].icon,
                                    baseColors: actions[idx].colors,
                                    action: actions[idx].handler
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    // Copy button
                    HStack(spacing: 2) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10, weight: .regular)) // SFSymbol
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                        .help(L10n.aiCopyHint)
                    }
                }
                Spacer(minLength: 42)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: Action Keywords Detection
    private struct DetectedAction {
        let label: String
        let icon: String
        let colors: [Color]
        let handler: () -> Void
    }

    private func extractRunID(from text: String) -> String? {
        let patterns = [
            #"run\s*(\d+)"#,
            #"run(\d+)"#,
        ]
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        return nil
    }

    private func detectedActions(in text: String) -> [DetectedAction] {
        var actions: [DetectedAction] = []
        let lower = text.lowercased()

        // Auto modeling
        if lower.contains("dudu auto") || lower.contains("自动建模") {
            actions.append(DetectedAction(
                label: L10n.actionAutoModel,
                icon: "wand.and.stars",
                colors: [.blue, .cyan],
                handler: { store.presentAutomationOptions() }
            ))
        }

        // Model comparison
        if lower.contains("compare") || lower.contains("模型比较") || lower.contains("比较模型") {
            actions.append(DetectedAction(
                label: L10n.actionCompare,
                icon: "arrow.left.arrow.right",
                colors: [.purple, .indigo],
                handler: { store.presentModelCompare() }
            ))
        }

        // Model evaluation
        if lower.contains("evaluate") || lower.contains("模型评估") || lower.contains("评估模型") || lower.contains("ai 评估") || lower.contains("ai评估") {
            actions.append(DetectedAction(
                label: L10n.actionEvaluate,
                icon: "checkmark.seal",
                colors: [.green, .mint],
                handler: { store.evaluateModelWithAI(store.currentRun) }
            ))
        }

        // Parameter extraction / PK parameters
        if lower.contains("pk 参数") || lower.contains("pk参数") || lower.contains("参数提取") || lower.contains("提取参数") || lower.contains("parameter extraction") {
            actions.append(DetectedAction(
                label: L10n.actionPKParams,
                icon: "tablecells",
                colors: [.orange, .yellow],
                handler: { store.runPKParameterExtraction(for: store.currentRun) }
            ))
        }

        // GA optimization
        if lower.contains("ga 优化") || lower.contains("ga优化") || lower.contains("遗传算法") || lower.contains("ga parameter") || lower.contains("初始估计") || lower.contains("ga optimisation") {
            actions.append(DetectedAction(
                label: L10n.actionGAOpt,
                icon: "cpu",
                colors: [.pink, .purple],
                handler: { store.runGAOptimization() }
            ))
        }

        // GOF / diagnostics
        if lower.contains("gof") || lower.contains("拟合优度") || lower.contains("诊断") || lower.contains("模型诊断") || lower.contains("goodness of fit") {
            actions.append(DetectedAction(
                label: L10n.actionGOF,
                icon: "chart.xyaxis.line",
                colors: [.teal, .blue],
                handler: { store.runAudit("gof") }
            ))
        }

        // VPC
        if lower.contains("vpc") || lower.contains("视觉预测") || lower.contains("预测检验") || lower.contains("visual predictive check") {
            actions.append(DetectedAction(
                label: L10n.actionVPC,
                icon: "chart.bar.doc.horizontal",
                colors: [.indigo, .cyan],
                handler: { store.runAudit("vpc-plot") }
            ))
        }

        // SCM covariate screening
        if lower.contains("scm") || lower.contains("协变量筛选") || lower.contains("协变量模型") || lower.contains("covariate screening") {
            actions.append(DetectedAction(
                label: L10n.quickSCMCov,
                icon: "square.grid.3x3.topleft.filled",
                colors: [.orange, .red],
                handler: { store.presentSCMDialog() }
            ))
        }

        // ETA covariate screening
        if lower.contains("eta 预筛选") || lower.contains("eta预筛选") ||
            lower.contains("eta covariate") || lower.contains("eta screening") ||
            lower.contains("eta 协变量") || lower.contains("eta协变量") {
            actions.append(DetectedAction(
                label: L10n.quickETAScreen,
                icon: "chart.bar.doc.horizontal",
                colors: [.teal, .blue],
                handler: { store.runETACovariateScreening(for: store.currentRun) }
            ))
        }

        // EDA Analysis
        if lower.contains("eda") || lower.contains("数据特征分析") || lower.contains("数据探索") || lower.contains("exploratory data") || lower.contains("missing data") || lower.contains("缺失数据") || lower.contains("correlation heatmap") || lower.contains("相关矩阵") || lower.contains("sampling schedule") || lower.contains("采样计划") || lower.contains("spaghetti plot") || lower.contains("意大利面图") {
            actions.append(DetectedAction(
                label: L10n.detectEDA,
                icon: "chart.bar",
                colors: [.teal, .green],
                handler: { store.runEDA() }
            ))
        }

        // C-T Curves
        if lower.contains("c-t curve") || lower.contains("ct curve") || lower.contains("浓度时间曲线") || lower.contains("concentration-time") || lower.contains("pk profile") || lower.contains("药时曲线") || lower.contains("dose-normalized") || lower.contains("剂量归一化") || lower.contains("个体浓度") || lower.contains("群体浓度") || lower.contains("ct图") || lower.contains("c-t图") || lower.contains("浓度曲线") || lower.contains("ct曲线") {
            actions.append(DetectedAction(
                label: L10n.detectCT,
                icon: "chart.xyaxis.line",
                colors: [.blue, .cyan],
                handler: { store.runCTCurves() }
            ))
        }

        // Deduplicate by label
        var seen: Set<String> = []
        actions = actions.filter { seen.insert($0.label).inserted }

        return actions
    }

    // MARK: Input Bar
    @State private var showQuickActions: Bool = false

    // MARK: Run Picker for diagnostic shortcuts
    enum RunPickerAction: Identifiable {
        case gof, vpc, individual, pkParams, bootstrap
        var id: Self { self }
    }
    @State private var showRunPicker: RunPickerAction? = nil

    // MARK: Input Bar
    private var inputBarView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    showQuickActions.toggle()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showQuickActions, arrowEdge: .bottom) {
                    QuickActionsPopover(showRunPicker: $showRunPicker)
                        .environmentObject(store)
                }
                .help(L10n.t("quick.title"))

                if store.isAutoModeling || store.isAssistantThinking || store.isAIThinking || store.runner.isRunning || store.isSCMRunning {
                    Button {
                        if store.isAutoModeling {
                            // Full stop: cancel the automation task AND terminate any running process.
                            store.requestStopAutomation()
                            store.requestStopChat()
                        } else if store.isSCMRunning {
                            store.cancelSCM()
                        } else if store.isAssistantThinking || store.isAIThinking {
                            store.requestStopChat()
                            store.runner.stopCurrentProcess()
                        } else {
                            store.runner.stopCurrentProcess()
                        }
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.aiStop)
                }

                TextField(L10n.aiPlaceholder, text: $store.assistantInput)
                    .textFieldStyle(.plain)
                    .font(DuDuFont.body())
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.primary.opacity(0.06))
                    )
                    .focused($isInputFocused)
                    .onSubmit {
                        let trimmed = store.assistantInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        if !trimmed.isEmpty, !store.isAssistantThinking {
                            store.sendAssistantMessage()
                            isInputFocused = true
                        }
                    }

                Button {
                    let trimmed = store.assistantInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !trimmed.isEmpty { store.sendAssistantMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            store.assistantInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                                ? Color.gray.opacity(0.3) : Color.blue
                        )
                }
                .buttonStyle(.plain)
                .disabled(store.assistantInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }
}

// MARK: - Quick Actions Popover

struct QuickActionsPopover: View {
    @EnvironmentObject private var store: WorkbenchStore
    @Environment(\.dismiss) private var dismiss
    @Binding var showRunPicker: AssistantPanel.RunPickerAction?

    private struct QuickAction {
        let label: String
        let icon: String
        let colors: [Color]
        let disabled: Bool
        let handler: () -> Void
    }

    private var actions: [QuickAction] {
        var items = [
            QuickAction(
                label: L10n.quickAutoModeling,
                icon: "wand.and.stars",
                colors: [.blue, .cyan],
                disabled: store.isAutoModeling,
                handler: { store.presentAutomationOptions() }
            ),
            QuickAction(
                label: L10n.quickGOFPlots,
                icon: "chart.xyaxis.line",
                colors: [.teal, .blue],
                disabled: store.runner.isRunning,
                handler: {
                    guard store.ensureModelFilesExist() else { return }
                    showRunPicker = .gof
                }
            ),
            QuickAction(
                label: L10n.quickVPCCheck,
                icon: "chart.bar.doc.horizontal",
                colors: [.indigo, .cyan],
                disabled: store.runner.isRunning,
                handler: {
                    guard store.ensureModelFilesExist() else { return }
                    showRunPicker = .vpc
                }
            ),
            QuickAction(
                label: L10n.quickIndividualDV,
                icon: "person.2.wave.2",
                colors: [.mint, .green],
                disabled: store.runner.isRunning,
                handler: {
                    guard store.ensureModelFilesExist() else { return }
                    showRunPicker = .individual
                }
            ),
            QuickAction(
                label: L10n.quickPKExtract,
                icon: "tablecells",
                colors: [.orange, .yellow],
                disabled: store.runner.isRunning,
                handler: {
                    guard store.ensureModelFilesExist() else { return }
                    showRunPicker = .pkParams
                }
            ),
            QuickAction(
                label: "Final Model Analysis",
                icon: "doc.text.magnifyingglass",
                colors: [.blue, .green],
                disabled: store.runner.isRunning,
                handler: {
                    guard store.ensureModelFilesExist() else { return }
                    store.analyzeFinalModel(runID: store.currentRun)
                }
            ),
            QuickAction(
                label: L10n.quickETAScreen,
                icon: "chart.bar.doc.horizontal",
                colors: [.teal, .blue],
                disabled: store.runner.isRunning,
                handler: {
                    guard store.ensureModelFilesExist() else { return }
                    store.runETACovariateScreening(for: store.currentRun)
                }
            ),
            QuickAction(
                label: L10n.quickSCMCov,
                icon: "square.grid.3x3.topleft.filled",
                colors: [.orange, .red],
                disabled: store.runner.isRunning,
                handler: { store.presentSCMDialog() }
            ),
            QuickAction(
                label: L10n.ctxBootstrap,
                icon: "repeat",
                colors: [.green, .teal],
                disabled: store.runner.isRunning,
                handler: { store.presentBootstrapSheet() }
            ),
            QuickAction(
                label: L10n.quickModelCompare,
                icon: "arrow.left.arrow.right",
                colors: [.purple, .indigo],
                disabled: store.runner.isRunning,
                handler: { store.presentModelCompare() }
            ),
        ]
        if store.runner.isRunning || store.isSCMRunning {
            items.append(QuickAction(
                label: L10n.aiStop,
                icon: "stop.fill",
                colors: [.red, .orange],
                disabled: false,
                handler: {
                    if store.isAutoModeling {
                        store.requestStopAutomation()
                        store.requestStopChat()
                    } else if store.isSCMRunning {
                        store.cancelSCM()
                    } else {
                        store.runner.stopCurrentProcess()
                    }
                }
            ))
        }
        return items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.quickTitle)
                    .font(DuDuFont.captionSemibold(11))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)

                Divider()

                ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                    Button {
                        dismiss()
                        action.handler()
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: action.colors.map { $0.opacity(0.15) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 24, height: 24)
                                Image(systemName: action.icon)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: action.colors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            Text(action.label)
                                .font(DuDuFont.body(12))
                                .foregroundStyle(action.disabled ? Color.secondary.opacity(0.7) : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(action.disabled)
                }
            }
            .frame(width: 190)
            .padding(.bottom, 6)

            if store.runner.isRunning {
                HStack(spacing: 5) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 9))
                    Text(L10n.quickBusyHint)
                        .font(DuDuFont.caption(9))
                        .lineLimit(2)
                }
                .foregroundStyle(.primary.opacity(0.86))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .frame(maxHeight: 380)
        .onAppear {
            // Self-heal: if the runner state says "busy" but no process actually exists,
            // clear it so the quick actions don't stay gray.
            store.runner.recoverIfStuck()
        }
    }
}

// MARK: - Quick Sheet Glass Components

struct QuickSheetCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.adaptiveSheetText)
            content
                .foregroundStyle(Color.adaptiveSheetText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.12), Color.primary.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

struct BootstrapSampleButton: View {
    let value: Int
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.adaptiveSheetText)
                Text(name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.adaptiveSheetText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.primary.opacity(0.04))
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.06), lineWidth: isSelected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bootstrap Setup Sheet

struct BootstrapSetupSheet: View {
    @EnvironmentObject private var store: WorkbenchStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRunID = ""
    @State private var selectedSamples = 500

    private let sampleOptions: [(value: Int, name: String)] = [
        (50, "Lite"),
        (200, "Balanced"),
        (500, "Medium"),
        (1000, "High")
    ]

    private var availableRuns: [String] {
        let base = store.availableRunIDs.isEmpty
            ? ProjectScanner.discoverRuns(in: store.projectURL)
            : store.availableRunIDs
        return base
            .filter { FileManager.default.fileExists(atPath: store.projectURL.appendingPathComponent("run\($0).mod").path) }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Image(systemName: "repeat")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.ctxBootstrap)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.adaptiveSheetText)
                    Text(L10n.bootstrapSamplesHint)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.adaptiveSheetText)
                }
                Spacer()
            }

            QuickSheetCard(title: L10n.pickerModel) {
                Picker("", selection: $selectedRunID) {
                    ForEach(availableRuns, id: \.self) { runID in
                        Text("run\(runID)").tag(runID)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                if !selectedRunID.isEmpty && selectedRunID == store.currentRun {
                    Text(L10n.pickerCurrent)
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                }
            }

            QuickSheetCard(title: L10n.bootstrapSamplesTitle) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(sampleOptions, id: \.value) { option in
                        BootstrapSampleButton(
                            value: option.value,
                            name: option.name,
                            isSelected: selectedSamples == option.value
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedSamples = option.value
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(L10n.cancel, role: .cancel) {
                    store.cancelBootstrapSheet()
                    dismiss()
                }
                    .buttonStyle(.bordered)
                Button(L10n.bootstrapStart) {
                    let runID = selectedRunID
                    let samples = selectedSamples
                    dismiss()
                    DispatchQueue.main.async {
                        store.runBootstrapWithAI(for: runID, samples: samples)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRunID.isEmpty || store.runner.isRunning)
            }
        }
        .padding(28)
        .frame(width: 430)
        .background(LiquidGlassBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            if selectedRunID.isEmpty {
                selectedRunID = availableRuns.contains(store.bootstrapSheetRunID)
                    ? store.bootstrapSheetRunID
                    : (availableRuns.contains(store.currentRun) ? store.currentRun : (availableRuns.first ?? ""))
            }
        }
    }
}


// MARK: - Automation Sheet

struct AutomationOptionsSheetView: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(L10n.autoSheetTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.adaptiveSheetText)
                Spacer()
            }

            QuickSheetCard(title: L10n.autoMode) {
                Picker("", selection: $store.automationStartMode) {
                    ForEach(AutomationStartMode.allCases) { mode in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.title).font(DuDuFont.bodyMedium(12))
                            Text(mode.detail).font(DuDuFont.caption()).foregroundStyle(Color.adaptiveSheetText)
                        }.tag(mode).padding(.vertical, 4)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            if store.automationStartMode == .selectedRun {
                QuickSheetCard(title: L10n.autoParentModel) {
                    Picker("", selection: $store.automationStartRunID) {
                        ForEach(store.automationAvailableRunIDs, id: \.self) { r in Text("run\(r)").tag(r) }
                    }
                    .pickerStyle(.menu)
                    .disabled(store.automationAvailableRunIDs.isEmpty)
                }
            }

            QuickSheetCard(title: L10n.autoDatasetLabel) {
                Picker("", selection: $store.automationDataFile) {
                    Text(L10n.autoUnspecified).tag("")
                    ForEach(store.availableCSVFiles(), id: \.self) { csv in
                        Text(csv).tag(csv)
                    }
                }
                .pickerStyle(.menu)
                .disabled(store.availableCSVFiles().count <= 1)
                if store.availableCSVFiles().count <= 1 {
                    Text(String(format: L10n.autoSingleDataset, store.dataFile))
                        .font(DuDuFont.caption(11))
                        .foregroundStyle(Color.adaptiveSheetText)
                }
            }

            QuickSheetCard(title: "Dataset Units") {
                HStack(spacing: 10) {
                    unitPicker("Dose", $store.doseUnit, WorkbenchStore.doseUnitOptions, { store.saveAutomationUnitsToConfig() })
                    unitPicker("AMT", $store.amtUnit, WorkbenchStore.doseUnitOptions, { store.saveAutomationUnitsToConfig() })
                    unitPicker("Conc.", $store.concUnit, WorkbenchStore.concUnitOptions, { store.saveAutomationUnitsToConfig() })
                    unitPicker("Time", $store.timeUnit, WorkbenchStore.timeUnitOptions, { store.saveAutomationUnitsToConfig() })
                }
            }

            QuickSheetCard(title: L10n.autoGuidanceLabel) {
                TextEditor(text: $store.automationUserGuidance)
                    .font(DuDuFont.body(12))
                    .frame(height: 76)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Spacer()
                Button(L10n.cancel, role: .cancel) { store.isAutomationOptionsPresented = false }
                    .buttonStyle(.bordered)
                Button(L10n.start) { store.startAutomationFromOptions() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.automationStartMode == .selectedRun && store.automationStartRunID.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(LiquidGlassBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onDisappear { store.handleSCMDialogDismissedIfNeeded() }
    }
}

// MARK: - Model Compare Sheet

// MARK: - Unit picker helper

fileprivate func unitPicker(_ label: String, _ selection: Binding<String>, _ options: [String], _ onChange: @escaping () -> Void) -> some View {
    VStack(alignment: .leading, spacing: 1) {
        Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(Color.adaptiveSheetText)
        Picker("", selection: selection) {
            ForEach(options, id: \.self) { opt in
                Text(opt).tag(opt)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 78, idealWidth: 88, maxWidth: 110)
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: selection.wrappedValue) { _ in onChange() }
    }
}

struct ModelCompareSheetView: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(L10n.compareTitle)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }

            QuickSheetCard(title: L10n.compareSubtitle) {
                if store.availableRunIDsForCompare().count < 2 {
                    Text(L10n.aiCompareNeedsTwo)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }

                VStack(spacing: 12) {
                    compareRow(label: "Run A", selection: $store.compareRunA)
                    compareRow(label: "Run B", selection: $store.compareRunB)
                }
            }

            HStack {
                Spacer()
                Button(L10n.cancel, role: .cancel) { store.isCompareSheetPresented = false }
                    .buttonStyle(.bordered)
                Button(L10n.aiCompareStart) { store.runModelCompareAudit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.compareRunA == store.compareRunB || store.runner.isRunning)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(LiquidGlassBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func compareRow(label: String, selection: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 52, alignment: .leading)
            Picker("", selection: selection) {
                ForEach(store.availableRunIDsForCompare(), id: \.self) { r in
                    Text("run\(r)").tag(r)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Circle()
                .fill(store.isModelRunSuccessful(runID: selection.wrappedValue) ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
        }
        .padding(10)
        .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - SCM Configuration Sheet

struct SCMSetupSheetView: View {
    @EnvironmentObject private var store: WorkbenchStore

    /// χ²(1df) critical values for labelling
    private let ofvMap: [String: String] = ["0.05": "3.84", "0.01": "6.63", "0.001": "10.83"]
    private let forwardOptions = ["0.05", "0.01", "0.001"]
    private let backwardOptions = ["0.01", "0.001"]

    private var backwardOutOfRange: Bool {
        guard let pf = Double(store.scmPForward),
              let pb = Double(store.scmPBackward) else { return false }
        return pb > pf
    }

    private var backwardPickerOptions: [String] {
        backwardOptions.filter { opt in
            guard let pf = Double(store.scmPForward),
                  let po = Double(opt) else { return true }
            return po <= pf
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(L10n.scmSheetTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.adaptiveSheetText)
                Spacer()
            }

            QuickSheetCard(title: L10n.scmBaseModel) {
                Picker("", selection: $store.scmModelRunID) {
                    ForEach(store.availableModFiles(), id: \.self) { mod in
                        Text(mod).tag(mod.replacingOccurrences(of: "run", with: "").replacingOccurrences(of: ".mod", with: ""))
                    }
                }
                .pickerStyle(.menu)
            }

            QuickSheetCard(title: L10n.autoDataFileLabel) {
                Picker("", selection: $store.scmDataFileName) {
                    ForEach(store.availableCSVFiles(), id: \.self) { csv in
                        Text(csv).tag(csv)
                    }
                }
                .pickerStyle(.menu)
            }

            if store.etaScreeningRunID == store.scmModelRunID,
               !store.etaScreeningRecommendation.isEmpty {
                QuickSheetCard(title: L10n.scmEtaSuggestionTitle) {
                    Text(store.etaScreeningRecommendation)
                        .font(DuDuFont.caption(11))
                    Text(L10n.scmEtaSuggestionHint)
                        .font(DuDuFont.caption(10))
                        .foregroundStyle(Color.adaptiveSheetText)
                    HStack(spacing: 8) {
                        if !store.etaScreeningRecommendedCovariates.isEmpty {
                            Button(L10n.scmEtaApplySuggestion) {
                                store.applyETAScreeningRecommendedCovariates()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Button(L10n.scmEtaResetAll) {
                            store.resetSCMCovariatesToAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            QuickSheetCard(title: L10n.scmCandidates) {
                Toggle(L10n.scmCovWT, isOn: $store.scmIncludeWT)
                Toggle(L10n.scmCovAGE, isOn: $store.scmIncludeAGE)
                Toggle(L10n.scmCovSEX, isOn: $store.scmIncludeSEX)
                Toggle(L10n.scmCovSTUDY, isOn: $store.scmIncludeSTUDY)
                    Text(L10n.scmCovNote)
                    .font(DuDuFont.caption(11)).foregroundStyle(Color.adaptiveSheetText)
            }

            QuickSheetCard(title: L10n.scmThreshold) {
                HStack(spacing: 6) {
                    Text(L10n.scmForwardP).font(.system(size: 11)).foregroundStyle(Color.adaptiveSheetText).frame(width: 72, alignment: .leading)
                    Picker("", selection: $store.scmPForward) {
                        ForEach(forwardOptions, id: \.self) { p in
                            Text("p=\(p)  (ΔOFV>\(ofvMap[p] ?? "-"))").tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: store.scmPForward) { _ in
                        if backwardOutOfRange {
                            store.scmPBackward = store.scmPForward
                        }
                    }
                }
                HStack(spacing: 6) {
                    Text(L10n.scmBackwardP).font(.system(size: 11)).foregroundStyle(Color.adaptiveSheetText).frame(width: 72, alignment: .leading)
                    Picker("", selection: $store.scmPBackward) {
                        ForEach(backwardPickerOptions, id: \.self) { p in
                            Text("p=\(p)  (ΔOFV>\(ofvMap[p] ?? "-"))").tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if backwardOutOfRange {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text(L10n.scmBackwardRange)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.orange)
                }
            }

            Text(L10n.scmRunNote)
                .font(DuDuFont.caption(11)).foregroundStyle(Color.adaptiveSheetText)

            HStack {
                Spacer()
                Button {
                    let runID = store.scmModelRunID
                    store.showSCMDialog = false
                    store.runETACovariateScreening(for: runID) {
                        store.presentSCMDialog(runID: runID)
                    }
                } label: {
                    Label(L10n.scmRunEtaScreen, systemImage: "chart.bar.doc.horizontal")
                }
                .buttonStyle(.bordered)
                .help(L10n.scmRunEtaHint)
                .disabled(store.scmModelRunID.isEmpty)
                Button(L10n.cancel, role: .cancel) { store.cancelSCMDialog() }
                    .buttonStyle(.bordered)
                Button(L10n.autoStartSCM) { store.confirmSCMRun() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.scmModelRunID.isEmpty || store.scmDataFileName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(LiquidGlassBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onChange(of: store.scmModelRunID) { _ in
            store.applyETAScreeningDefaultsIfAvailable(for: store.scmModelRunID)
        }
    }
}

// MARK: - Helpers

private var duDuThumb: NSImage? {
    let candidates = [
        BundledResource.url(forResource: "DuDuPMxButton", withExtension: "png"),
        BundledResource.url(forResource: "DuDuPMxSource", withExtension: "png")
    ]
    for u in candidates {
        if let u, let img = NSImage(contentsOf: u) { return img }
    }
    return nil
}

// MARK: - Glass Effects (iOS 27 liquid glass style)

struct GlassMaterial: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        if environment.colorScheme == .dark {
            return Material.ultraThinMaterial
        } else {
            return Material.thinMaterial
        }
    }
}

struct GlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Plain, calm background — a soft gray card (dark gray in dark mode).
        // No material, no gradients, so nothing can bleed through or create lines.
        Rectangle()
            .fill(
                colorScheme == .dark
                    ? Color(red: 0.13, green: 0.13, blue: 0.14)
                    : Color(red: 0.93, green: 0.93, blue: 0.94)
            )
    }
}

// MARK: - Gradient Glow Border (DuDu PMx panel edge)

/// A single lightweight gradient border around the AI panel.
struct GradientGlowBorder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: [
                        Color(red: 0.30, green: 0.55, blue: 0.95),
                        Color(red: 0.55, green: 0.35, blue: 0.90),
                        Color(red: 0.90, green: 0.40, blue: 0.60),
                        Color(red: 0.30, green: 0.75, blue: 0.85),
                        Color(red: 0.30, green: 0.55, blue: 0.95)
                    ],
                    center: .center
                ),
                lineWidth: 1.0
            )
            .opacity(0.32)
    }
}

// MARK: - No Model Notice Card

/// Liquid-glass card shown when a model-only action (GOF / VPC / individual DV-TIME / SCM ...)
/// is triggered in a project that has no .mod files yet. Offers a one-tap path into
/// DuDu Auto Modeling so the user can build a model first.
struct NoModelNoticeCard: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.orange.opacity(0.25), .yellow.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 30, height: 30)
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.noModelCardTitle)
                    .font(DuDuFont.bodySemibold(12))
                Text(L10n.noModelCardBody)
                    .font(DuDuFont.caption(10))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button {
                withAnimation(.easeOut(duration: 0.15)) { store.noModelCardVisible = false }
                store.isAssistantPanelPresented = true
                store.presentAutomationOptions()
            } label: {
                Text(L10n.noModelBuildCta)
                    .font(DuDuFont.captionSemibold(10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color(red: 0.20, green: 0.50, blue: 1.0), Color.cyan.opacity(0.9)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 3, y: 1)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeOut(duration: 0.15)) { store.noModelCardVisible = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(width: 330, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(colors: [.orange.opacity(0.10), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                )
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.22), .clear],
                                   startPoint: .top, endPoint: .center)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        )
        .onAppear {
            // Auto-dismiss so the card never lingers
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                withAnimation(.easeOut(duration: 0.25)) { store.noModelCardVisible = false }
            }
        }
    }
}

// MARK: - Markdown Message View (renders bold, inline code, tables, headings)

// MARK: - Mini Progress Popup (shown when DuDu panel is hidden during auto modeling)

/// A compact floating bubble that shows the current automation step when the
/// DuDu PMx panel is dismissed. Tapping it reopens the full panel.
struct MiniProgressPopup: View {
    let title: String
    let step: String
    @State private var pulse = false

    init(title: String = "DuDu Auto", step: String) {
        self.title = title
        self.step = step
    }

    var body: some View {
        HStack(spacing: 10) {
            // Pulsing active dot
            Circle()
                .fill(Color.cyan)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.cyan, lineWidth: 2)
                        .scaleEffect(pulse ? 1.8 : 1.0)
                        .opacity(pulse ? 0.0 : 0.6)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.adaptiveSheetText)
                Text(step)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.adaptiveSheetText)
                    .lineLimit(1)
            }
            .frame(maxWidth: 200, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Typing Indicator

/// Three gently bouncing dots shown while DuDu is thinking.
private struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.green.opacity(0.55))
                    .frame(width: 6, height: 6)
                    .offset(y: animate ? -3 : 2)
                    .animation(.easeInOut(duration: 0.5).delay(Double(i) * 0.15).repeatForever(autoreverses: true),
                               value: animate)
            }
        }
        .onAppear { animate = true }
    }
}

struct MarkdownMessageView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parsedBlocks.indices, id: \.self) { idx in
                parsedBlocks[idx]
            }
        }
        .textSelection(.enabled)
        .font(DuDuFont.body())
        .lineSpacing(4)
    }

    private var parsedBlocks: [AnyView] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [AnyView] = []
        var tableRows: [[String]] = []
        var inTable = false
        var inCodeBlock = false
        var codeLines: [String] = []
        var pendingText = ""

        // List accumulation: collect consecutive bullet/numbered items
        var listItems: [String] = []
        var listIndent: Int = 0
        var isOrderedList = false

        func flushText() {
            let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                blocks.append(AnyView(parseInlineMarkdown(trimmed)))
            }
            pendingText = ""
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            let items = listItems  // snapshot to prevent mutation during ForEach rendering (crash fix)
            let indent = listIndent
            let ordered = isOrderedList
            listItems = []
            listIndent = 0
            isOrderedList = false
            blocks.append(AnyView(
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(items.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 6) {
                            Text(ordered ? "\(i+1)." : "•")
                                .font(DuDuFont.body())
                                .foregroundStyle(.secondary)
                                .frame(width: 14, alignment: ordered ? .trailing : .center)
                            parseInlineMarkdown(items[i])
                        }
                        .padding(.leading, CGFloat(indent * 12))
                    }
                }
                .padding(.vertical, 2)
            ))
        }

        func flushTable() {
            if tableRows.count >= 2 {
                blocks.append(AnyView(
                    MarkdownTableView(headers: tableRows[0], rows: Array(tableRows.dropFirst()))
                ))
            }
            tableRows = []
            inTable = false
        }

        func flushCodeBlock() {
            if !codeLines.isEmpty {
                blocks.append(AnyView(
                    Text(codeLines.joined(separator: "\n"))
                        .font(DuDuFont.mono())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                ))
                codeLines = []
            }
            inCodeBlock = false
        }

        /// Detect if a line is a list item; returns (isListItem, indentLevel, isOrdered, content)
        func parseListItem(_ line: String) -> (Bool, Int, Bool, String) {
            let pattern = try? NSRegularExpression(pattern: #"^([ \t]*)([-*]|\d+\.)\s+(.+)$"#)
            guard let match = pattern?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) else {
                return (false, 0, false, "")
            }
            let indent = String(line[Range(match.range(at: 1), in: line)!]).count / 2
            let marker = String(line[Range(match.range(at: 2), in: line)!])
            let isOrdered = marker.hasSuffix(".")
            let content = String(line[Range(match.range(at: 3), in: line)!])
            return (true, indent, isOrdered, content)
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                flushText(); flushList()
                if inCodeBlock { flushCodeBlock() } else { inCodeBlock = true }
                continue
            }
            if inCodeBlock { codeLines.append(line); continue }

            // Table
            if trimmed.hasPrefix("|"), trimmed.hasSuffix("|") {
                let sepPattern = try? NSRegularExpression(pattern: #"^\|[\s:\|-]+\|$"#)
                if sepPattern?.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) != nil { continue }
                flushText(); flushList()
                let cells = trimmed.dropFirst().dropLast().components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                tableRows.append(cells)
                inTable = true
                continue
            } else if inTable { flushTable() }

            // Headings
            if trimmed.hasPrefix("### ") {
                flushText(); flushList()
                blocks.append(AnyView(parseInlineMarkdown(String(trimmed.dropFirst(4))).font(DuDuFont.bodySemibold()).padding(.top, 4)))
                continue
            }
            if trimmed.hasPrefix("## ") {
                flushText(); flushList()
                blocks.append(AnyView(parseInlineMarkdown(String(trimmed.dropFirst(3))).font(DuDuFont.title(14)).padding(.top, 6)))
                continue
            }

            // List items
            let (isListItem, indent, isOrdered, content) = parseListItem(trimmed)
            if isListItem {
                flushText()
                // Flush existing list if type/indent changes
                if !listItems.isEmpty && (isOrderedList != isOrdered || listIndent != indent) {
                    flushList()
                }
                isOrderedList = isOrdered
                listIndent = indent
                listItems.append(content)
                continue
            } else {
                flushList()
            }

            // Empty line → paragraph break
            if trimmed.isEmpty { flushText(); continue }

            // Regular text line
            pendingText += (pendingText.isEmpty ? "" : "\n") + trimmed
        }

        flushList(); flushText(); flushTable(); flushCodeBlock()
        return blocks
    }

    private func parseInlineMarkdown(_ text: String) -> Text {
        var result = Text("")
        var remaining = text
        while !remaining.isEmpty {
            if let m = remaining.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
                let before = String(remaining[..<m.lowerBound])
                if !before.isEmpty { result = result + Text(before) }
                let inner = String(remaining[m]).dropFirst(2).dropLast(2)
                result = result + Text(inner).bold()
                remaining = String(remaining[m.upperBound...])
                continue
            }
            if let m = remaining.range(of: "`[^`]+`", options: .regularExpression) {
                let before = String(remaining[..<m.lowerBound])
                if !before.isEmpty { result = result + Text(before) }
                let inner = String(remaining[m]).dropFirst().dropLast()
                result = result + Text(inner).font(DuDuFont.mono(12)).foregroundColor(.pink)
                remaining = String(remaining[m.upperBound...])
                continue
            }
            result = result + Text(remaining)
            remaining = ""
        }
        return result
    }
}

// MARK: - Table inside Markdown bubble

struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(headers.indices, id: \.self) { i in
                    Text(headers[i]).font(DuDuFont.captionSemibold()).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(.primary.opacity(0.06))
                }
            }
            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
                let isEven = ri % 2 == 0
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        let count = min(headers.count, row.count)
                        ForEach(0..<count, id: \.self) { ci in
                            TableCellView(text: row[ci], isEven: isEven)
                        }
                    }
                    if ri < rows.count - 1 { Divider().opacity(0.3) }
                }
            }
        }
        .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
    }
}

// Small helper to avoid type-check complexity in Markdown table cells
private struct TableCellView: View {
    let text: String
    let isEven: Bool
    var body: some View {
        Text(text)
            .font(DuDuFont.caption())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(isEven ? Color.clear : Color.blue.opacity(0.03))
    }
}

// MARK: - Animated Gradient Capsule Button

struct AnimatedGradientCapsule: View {
    let text: String
    let baseColors: [Color]
    let action: () -> Void

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Button(action: action) {
                Text(text)
                    .font(DuDuFont.captionMedium())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        baseColors[0].opacity(0.10 + 0.06 * sin(t * 1.5)),
                                        baseColors[1].opacity(0.10 + 0.06 * cos(t * 1.3)),
                                        baseColors[2].opacity(0.10 + 0.06 * sin(t * 1.1 + 0.5)),
                                    ]),
                                    startPoint: UnitPoint(x: 0.5 + 0.3 * sin(t * 0.7), y: 0),
                                    endPoint: UnitPoint(x: 0.5 + 0.3 * cos(t * 0.7), y: 1)
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        baseColors[0].opacity(0.25 + 0.15 * sin(t * 1.2)),
                                        baseColors[1].opacity(0.25 + 0.15 * cos(t * 1.0)),
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Animated Action Chip (inline clickable chip under messages)

struct AnimatedActionChip: View {
    let label: String
    let systemImage: String
    let baseColors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 8, weight: .semibold))
                Text(label)
                    .font(DuDuFont.captionMedium())
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                baseColors[0].opacity(0.16),
                                baseColors[1].opacity(0.16),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                baseColors[0].opacity(0.30),
                                baseColors[1].opacity(0.20),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(.plain)
        .help("\(L10n.aiClickToRun) \(label)")
    }
}

// MARK: - Citation Section

struct CitationSection: View {
    let citations: [String]
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: expanded ? "chevron.down" : "book.closed")
                        .font(.system(size: 9))
                    Text(expanded ? "Hide sources" : "\(citations.count) source\(citations.count > 1 ? "s" : "")")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(citations.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 6) {
                            Text("·")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.blue.opacity(0.6))
                            Text(citations[i])
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Base Model Confirmation

// MARK: - High-Compartment Decision View

struct CompDecisionView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "questionmark.bubble")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text(L10n.compDecisionTitle)
                .font(.title2.weight(.semibold))
            ScrollView {
                Text(store.compDecisionInfo)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxHeight: 120)
            HStack(spacing: 16) {
                Button(L10n.compDecisionAcceptLower) {
                    store.acceptLowerCompartment()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                Button(L10n.compDecisionAcceptCurrent) {
                    store.acceptCurrentCompartment()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            .controlSize(.large)
            Text(L10n.compDecisionDesc)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .onDisappear { store.handleBaseModelPromptDismissedIfNeeded() }
    }
}

struct BaseModelConfirmView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @ObservedObject private var lang = LanguageStore.shared

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.phase1Complete)
                .font(DuDuFont.title(18))

            ScrollView {
                Text(store.baseModelConfirmSummary)
                    .font(DuDuFont.mono(12))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxHeight: 200)

            Text(String(format: L10n.phase1ConfirmMsg, store.baseModelConfirmRunID))
                .font(DuDuFont.body(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(L10n.phase1CancelLater) {
                    store.cancelBaseModelConfirmation()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(L10n.baseModelStartSCM) {
                    store.presentSCMDialogAfterBaseModel()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)

                Button(L10n.baseModelSkipSCM) {
                    store.confirmBaseModelAndStartPhase2(skipSCM: true)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(28)
    }
}

struct SCMFinalModelConfirmView: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(.green)
            Text(L10n.scmFinalConfirmTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.adaptiveSheetText)
            Text(String(format: L10n.scmFinalConfirmBody, store.scmFinalModelRunID))
                .font(.system(size: 13))
                .foregroundStyle(Color.adaptiveSheetText)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(L10n.scmFinalConfirmLater, role: .cancel) {
                    store.cancelSCMFinalModelAnalysis()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(L10n.scmFinalConfirmContinue) {
                    store.confirmSCMFinalModelAnalysis()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(LiquidGlassBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Run Picker Sheet for Diagnostic Shortcuts

struct RunPickerSheet: View {
    let action: AssistantPanel.RunPickerAction
    @EnvironmentObject private var store: WorkbenchStore
    @Environment(\.dismiss) private var dismiss
    @State private var bootstrapRunID = ""
    @State private var bootstrapSamples = 500

    private let sampleOptions: [(value: Int, name: String)] = [
        (50, "Lite"),
        (200, "Balanced"),
        (500, "Medium"),
        (1000, "High")
    ]

    private var availableRuns: [String] {
        // Use cached run IDs from the store (updated by refreshWorkspace) instead of
        // re-scanning the directory on every body evaluation.
        let base = store.availableRunIDs.isEmpty
            ? ProjectScanner.discoverRuns(in: store.projectURL)
            : store.availableRunIDs
        return base
            .filter { runID in
                FileManager.default.fileExists(atPath: store.projectURL.appendingPathComponent("run\(runID).mod").path)
            }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    private var actionLabel: String {
        switch action {
        case .gof:        return L10n.quickGOFPlots
        case .vpc:        return L10n.quickVPCCheck
        case .individual: return L10n.pickIndividual
        case .pkParams:   return L10n.quickPKExtract
        case .bootstrap:  return L10n.ctxBootstrap
        }
    }

    private var actionIcon: String {
        switch action {
        case .gof:        return "chart.xyaxis.line"
        case .vpc:        return "chart.bar.doc.horizontal"
        case .individual: return "person.2.wave.2"
        case .pkParams:   return "tablecells"
        case .bootstrap:  return "repeat"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    Image(systemName: actionIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(actionLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.adaptiveSheetText)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 16)

            Divider()

            if action == .bootstrap {
                bootstrapBody
            } else if availableRuns.isEmpty {
                QuickSheetCard(title: L10n.pickerModel) {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 30)).foregroundStyle(Color.adaptiveSheetText)
                        Text(L10n.pickerNoModels)
                            .font(.system(size: 12)).foregroundStyle(Color.adaptiveSheetText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                }
                .padding(16)
            } else {
                QuickSheetCard(title: L10n.pickerModel) {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(availableRuns, id: \.self) { runID in
                                Button {
                                    dismiss()
                                    DispatchQueue.main.async {
                                        execute(for: runID)
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Text("run\(runID)")
                                            .font(.system(size: 13, weight: runID == store.currentRun ? .semibold : .regular, design: .monospaced))
                                            .foregroundStyle(Color.adaptiveSheetText)
                                        Spacer()
                                        if runID == store.currentRun {
                                            Text(L10n.pickerCurrent)
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.blue)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Capsule().fill(.blue.opacity(0.12)))
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color.adaptiveSheetText)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
                .padding(16)
            }
        }
        .frame(minWidth: 330, minHeight: action == .bootstrap ? 420 : 380)
        .background(LiquidGlassBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            if bootstrapRunID.isEmpty {
                bootstrapRunID = availableRuns.contains(store.currentRun) ? store.currentRun : (availableRuns.first ?? "")
            }
        }
    }

    @ViewBuilder
    private var bootstrapBody: some View {
        VStack(spacing: 16) {
            QuickSheetCard(title: L10n.pickerModel) {
                Picker("", selection: $bootstrapRunID) {
                    ForEach(availableRuns, id: \.self) { runID in
                        Text("run\(runID)").tag(runID)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            QuickSheetCard(title: L10n.bootstrapSamplesTitle) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(sampleOptions, id: \.value) { option in
                        BootstrapSampleButton(
                            value: option.value,
                            name: option.name,
                            isSelected: bootstrapSamples == option.value
                        ) {
                            bootstrapSamples = option.value
                        }
                    }
                }
            }

            Text(L10n.bootstrapSamplesHint)
                .font(.system(size: 10))
                .foregroundStyle(Color.adaptiveSheetText)

            HStack {
                Spacer()
                Button(L10n.cancel, role: .cancel) { dismiss() }
                Button(L10n.bootstrapStart) {
                    let runID = bootstrapRunID
                    let samples = bootstrapSamples
                    dismiss()
                    DispatchQueue.main.async {
                        store.runBootstrapWithAI(for: runID, samples: samples)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(bootstrapRunID.isEmpty || store.runner.isRunning)
            }
        }
        .padding(16)
    }

    private func execute(for runID: String) {
        store.activateRun(runID)
        switch action {
        case .gof:        store.runGOF(for: runID)
        case .vpc:        store.runVPCPlot(for: runID)
        case .individual: store.runIndividualDVTime(for: runID)
        case .pkParams:   store.runPKParameterExtraction(for: runID)
        case .bootstrap:  break
        }
    }
}
