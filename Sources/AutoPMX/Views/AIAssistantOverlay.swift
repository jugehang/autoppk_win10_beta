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
            if store.isAssistantPanelPresented {
                AssistantPanel()
                    .frame(width: 420, height: 600)
                    .transition(.opacity)
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
            }

            // Warning banner during auto modeling
            if store.isAutoModeling {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("自动建模中，请勿切换项目")
                        .font(DuDuFont.captionSemibold(11))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.isAssistantPanelPresented.toggle()
                }
            } label: {
                FloatingButton(isActive: store.isAutoModeling || store.isAssistantThinking || store.isAIThinking, showingDuDu: duDuThumb != nil)
            }
        }
        .offset(x: settledOffset.width + dragOffset.width, y: settledOffset.height + dragOffset.height)
        .gesture(DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded {
                settledOffset.width += $0.translation.width
                settledOffset.height += $0.translation.height
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
                    AuroraParticles()
                        .frame(width: 54, height: 54)
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

// MARK: - Aurora Particles

struct AuroraParticles: View {
    @EnvironmentObject private var store: WorkbenchStore

    @State private var seedParticles: [(fraction: Double, offset: Double, speed: Double, driftAmp: Double, driftFreq: Double)] = []

    private let maxSeeds = 10000

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                guard store.particleEffectsEnabled, store.particleCount > 0 else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate
                let count = min(store.particleCount, seedParticles.count)
                let baseRadius = size.width * 0.38

                for i in 0..<count {
                    let p = seedParticles[i]
                    // 3× faster orbit
                    let angle = Angle.degrees(p.fraction * 360 + t * p.speed * 24)
                    // Gentle radial drift for organic feel (3×)
                    let drift = sin(t * p.driftFreq + p.offset * .pi * 2) * p.driftAmp
                    let radius = baseRadius + drift * (baseRadius * 0.25)
                    let x = size.width / 2 + cos(angle.radians) * radius
                    let y = size.height / 2 + sin(angle.radians) * radius
                    let brightness = 0.55 + 0.45 * sin(t * p.speed * 4.5 + p.offset * .pi * 2)
                    let dotSize: CGFloat = 1.0 + 1.2 * sin(t * p.speed * 3.6 + p.offset * .pi)
                    let dot = Path(ellipseIn: CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize))

                    // Blue gradient: hue fixed near blue, vary brightness
                    let color = Color(
                        hue: 0.57 + 0.06 * sin(t * 0.2 + p.fraction * .pi * 2),
                        saturation: 0.65 + 0.35 * sin(t * 0.35 + p.offset * .pi),
                        brightness: brightness
                    )
                    context.fill(dot, with: .color(color.opacity(0.75)))
                    // Subtle glow
                    let glow = Path(ellipseIn: CGRect(x: x - dotSize, y: y - dotSize, width: dotSize*2, height: dotSize*2))
                    context.fill(glow, with: .color(color.opacity(0.08)))
                }
            }
        }
        .onAppear {
            seedParticles = (0..<maxSeeds).map { _ in
                (
                    fraction: Double.random(in: 0..<1),
                    offset: Double.random(in: 0..<1),
                    speed: Double.random(in: 0.9..<2.4),
                    driftAmp: Double.random(in: 0.3..<1.0),
                    driftFreq: Double.random(in: 0.45..<1.35)
                )
            }
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
            contextIndicator
            quickActionsBar
            inputBarView
        }
        .background(
            GlassBackground()
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(.white.opacity(0.15), lineWidth: 0.5))
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
    }

    // MARK: Header
    private var headerView: some View {
        HStack(spacing: 8) {
            if let logo = duDuThumb {
                Image(nsImage: logo).resizable().scaledToFit()
                    .frame(width: 22, height: 22).clipShape(Circle())
            }
            Text("DuDu PMx").font(DuDuFont.bodySemibold())
            Spacer()
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
                    .help("Compress context (~\(store.estimatedTokenCount()/1000)K tokens)")
                }
                if store.isAutoModeling || store.isAssistantThinking || store.isAIThinking {
                    Button {
                        if store.isAutoModeling {
                            store.requestStopAutomation()
                        } else {
                            store.requestStopChat()
                        }
                    } label: {
                        Label(L10n.aiStop, systemImage: "stop.fill")
                            .font(DuDuFont.captionMedium())
                            .padding(.horizontal, 10).frame(height: 22)
                    }
                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                }
            }
            Button { store.isAssistantPanelPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .regular)).foregroundStyle(.tertiary) // SFSymbol
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(GlassMaterial())
    }

    // MARK: Thinking Steps
    @State private var isThinkingCollapsed = true

    private var thinkingStepsView: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isThinkingCollapsed.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: isThinkingCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary) // SFSymbol
                    Text(L10n.aiReasoning).font(DuDuFont.caption()).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.thinkingSteps.count) \(L10n.aiSteps)").font(DuDuFont.caption()).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.vertical, 5)
            if !isThinkingCollapsed {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(store.thinkingSteps) { step in
                            HStack(spacing: 4) {
                                Circle().fill(step.type == .done ? Color.green.opacity(0.5) :
                                    step.type == .error ? Color.red.opacity(0.5) : Color.blue.opacity(0.4))
                                    .frame(width: 4, height: 4)
                                Text(step.text).font(DuDuFont.caption())
                                    .foregroundStyle(step.type == .done ? .secondary : .primary)
                                if !step.detail.isEmpty {
                                    Text(step.detail).font(DuDuFont.mono(9)).foregroundStyle(.tertiary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 2)
                        }
                    }.padding(.vertical, 3)
                }.frame(maxHeight: 100)
            }
        }
    }

    // MARK: Messages — iMessage style
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.assistantMessages) { msg in
                        iMessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if store.isAssistantThinking || store.isAIThinking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small).scaleEffect(0.6)
                            Text("思考中...").font(DuDuFont.caption(11)).foregroundStyle(.tertiary)
                        }.padding(.horizontal, 16).padding(.vertical, 6)
                    }
                }.padding(.vertical, 8)
            }
            .onChange(of: store.assistantMessages.count) { _ in
                if let last = store.assistantMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // iMessage-style bubble with Markdown rendering for assistant messages
    private func iMessageBubble(message: AssistantMessage) -> some View {
        let isUser = message.role == .user
        return HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 50) }

            if isUser {
                Text(message.text)
                    .font(DuDuFont.body()).textSelection(.enabled).lineSpacing(3)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(
                        Color.blue,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .contextMenu {
                        Button(L10n.aiCopy) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        }
                        Button(L10n.aiFillInput) { store.assistantInput = message.text }
                    }
                    .frame(maxWidth: 300, alignment: .trailing)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    MarkdownMessageView(text: message.text)
                        .contextMenu {
                            Button(L10n.aiCopy) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.text, forType: .string)
                            }
                            Button(L10n.aiFillInput) { store.assistantInput = message.text }
                        }
                        .frame(maxWidth: 380, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(
                            Color.green.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )

                    // Collapsible Source Citations
                    if !message.citations.isEmpty {
                        CitationSection(citations: message.citations)
                            .padding(.horizontal, 18).padding(.bottom, 2)
                    }

                    // Copy button
                    HStack(spacing: 2) {
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10, weight: .regular)) // SFSymbol
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                        .help(L10n.aiCopyHint)
                    }

                    // Action keyword chips
                    let actions = detectedActions(in: message.text)
                    if !actions.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(actions.indices, id: \.self) { idx in
                                AnimatedActionChip(
                                    label: actions[idx].label,
                                    systemImage: actions[idx].icon,
                                    baseColors: actions[idx].colors,
                                    action: actions[idx].handler
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    }
                }
            }

            if !isUser { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 12).padding(.vertical, 1)
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
                label: "SCM 协变量筛选",
                icon: "square.grid.3x3.topleft.filled",
                colors: [.orange, .red],
                handler: { store.presentSCMDialog() }
            ))
        }

        // Deduplicate by label
        var seen: Set<String> = []
        actions = actions.filter { seen.insert($0.label).inserted }

        return actions
    }

    // MARK: Context Indicator
    private var contextIndicator: some View {
        let tokens = store.isAutoModeling ? store.liveTokenCount : store.estimatedTokenCount()
        let maxTokens = 131_072
        let pct = Double(tokens) / Double(maxTokens)
        let pctInt = min(Int(pct * 100), 100)

        return HStack(spacing: 0) {
            Spacer()
            Button {
                store.compressChatContext()
            } label: {
                HStack(spacing: 5) {
                    ContextRing(pct: pct)
                        .frame(width: 16, height: 16)
                    Text("\(pctInt)%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(pct > 0.7 ? Color.orange : pct > 0.5 ? Color.yellow : Color.secondary)
                    Text("·")
                        .font(.system(size: 9)).foregroundStyle(.quaternary)
                    Text("\(tokens / 1000)K / \(maxTokens / 1000)K")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help("Context usage. Click to compress.")
        }
        .padding(.horizontal, 14).padding(.top, 2)
    }

    // MARK: Input Bar
    @State private var showQuickActions: Bool = false

    // MARK: Run Picker for diagnostic shortcuts
    enum RunPickerAction: Identifiable {
        case gof, vpc, individual, pkParams
        var id: Self { self }
    }
    @State private var showRunPicker: RunPickerAction? = nil

    // MARK: Quick Actions Bar (above input)
    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // ── Stop button: visible only when a process is running ──
                if store.runner.isRunning || store.isSCMRunning {
                    Button {
                        if store.isSCMRunning {
                            store.cancelSCM()
                        } else {
                            store.runner.stopCurrentProcess()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("停止")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.red))
                    }
                    .buttonStyle(.plain)
                }

                quickActionButton(label: "自动建模", icon: "wand.and.stars", colors: [.blue, .cyan]) {
                    store.presentAutomationOptions()
                }
                .disabled(store.isAutoModeling || store.runner.isRunning)

                quickActionButton(label: "GOF", icon: "chart.xyaxis.line", colors: [.teal, .blue]) {
                    showRunPicker = .gof
                }
                .disabled(store.runner.isRunning)

                quickActionButton(label: "VPC", icon: "chart.bar.doc.horizontal", colors: [.indigo, .cyan]) {
                    showRunPicker = .vpc
                }
                .disabled(store.runner.isRunning)

                quickActionButton(label: "个体图", icon: "person.2.wave.2", colors: [.mint, .green]) {
                    showRunPicker = .individual
                }
                .disabled(store.runner.isRunning)

                quickActionButton(label: "PK参数", icon: "tablecells", colors: [.orange, .yellow]) {
                    showRunPicker = .pkParams
                }
                .disabled(store.runner.isRunning)

                quickActionButton(label: "SCM", icon: "square.grid.3x3.topleft.filled", colors: [.orange, .red]) {
                    store.presentSCMDialog()
                }
                .disabled(store.runner.isRunning)

                quickActionButton(label: "模型比较", icon: "arrow.left.arrow.right", colors: [.purple, .indigo]) {
                    store.presentModelCompare()
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .background(.regularMaterial)
    }

    private func quickActionButton(label: String, icon: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(DuDuFont.captionMedium(10))
            }
            .foregroundStyle(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: colors.map { $0.opacity(0.12) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Input Bar
    private var inputBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                TextField("向 DuDu PMx 提问...", text: $store.assistantInput)
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
                        .font(.system(size: 26)) // emoji
                        .foregroundStyle(
                            store.assistantInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                                ? Color.gray.opacity(0.3) : Color.blue
                        )
                }
                .buttonStyle(.plain)
                .disabled(store.assistantInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.regularMaterial)
        }
    }
}

// MARK: - Quick Actions Popover

struct QuickActionsPopover: View {
    @EnvironmentObject private var store: WorkbenchStore
    @Environment(\.dismiss) private var dismiss

    private struct QuickAction {
        let label: String
        let icon: String
        let colors: [Color]
        let disabled: Bool
        let handler: () -> Void
    }

    private var actions: [QuickAction] {
        let run = store.currentRun
        return [
            QuickAction(
                label: "自动建模",
                icon: "wand.and.stars",
                colors: [.blue, .cyan],
                disabled: store.isAutoModeling,
                handler: { store.presentAutomationOptions() }
            ),
            QuickAction(
                label: "GOF 诊断图",
                icon: "chart.xyaxis.line",
                colors: [.teal, .blue],
                disabled: run.isEmpty || store.runner.isRunning,
                handler: { store.runGOF(for: run) }
            ),
            QuickAction(
                label: "VPC 预测检验",
                icon: "chart.bar.doc.horizontal",
                colors: [.indigo, .cyan],
                disabled: run.isEmpty || store.runner.isRunning,
                handler: { store.runVPCPlot(for: run) }
            ),
            QuickAction(
                label: "个体 DV-TIME",
                icon: "person.2.wave.2",
                colors: [.mint, .green],
                disabled: run.isEmpty || store.runner.isRunning,
                handler: { store.runIndividualDVTime(for: run) }
            ),
            QuickAction(
                label: "PK 参数提取",
                icon: "tablecells",
                colors: [.orange, .yellow],
                disabled: run.isEmpty || store.runner.isRunning,
                handler: { store.runPKParameterExtraction(for: run) }
            ),
            QuickAction(
                label: "SCM 协变量筛选",
                icon: "square.grid.3x3.topleft.filled",
                colors: [.orange, .red],
                disabled: store.runner.isRunning,
                handler: { store.presentSCMDialog() }
            ),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("快捷功能")
                .font(DuDuFont.captionSemibold(11))
                .foregroundStyle(.secondary)
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
                            .foregroundStyle(action.disabled ? .tertiary : .primary)
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
    }
}

// MARK: - Automation Sheet

struct AutomationOptionsSheetView: View {
    @EnvironmentObject private var store: WorkbenchStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DuDu Auto — 自动建模").font(DuDuFont.title())
            Picker("模式", selection: $store.automationStartMode) {
                ForEach(AutomationStartMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.title).font(DuDuFont.bodyMedium(12))
                        Text(mode.detail).font(DuDuFont.caption()).foregroundStyle(.tertiary)
                    }.tag(mode).padding(.vertical, 4)
                }
            }.pickerStyle(.radioGroup)
            if store.automationStartMode == .selectedRun {
                Picker("父模型", selection: $store.automationStartRunID) {
                    ForEach(store.automationAvailableRunIDs, id: \.self) { r in Text("run\(r)").tag(r) }
                }.disabled(store.automationAvailableRunIDs.isEmpty)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("建模数据集").font(DuDuFont.captionSemibold())
                Picker("数据集", selection: $store.automationDataFile) {
                    Text("（不指定）").tag("")
                    ForEach(store.availableCSVFiles(), id: \.self) { csv in
                        Text(csv).tag(csv)
                    }
                }
                .pickerStyle(.menu)
                .disabled(store.availableCSVFiles().count <= 1)
                if store.availableCSVFiles().count <= 1 {
                    Text("当前项目只有一个数据集：\(store.dataFile)").font(DuDuFont.caption()).foregroundStyle(.tertiary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("建模指导（可选）").font(DuDuFont.captionSemibold())
                TextEditor(text: $store.automationUserGuidance).font(DuDuFont.body(12)).frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Spacer()
                Button(L10n.cancel, role: .cancel) { store.isAutomationOptionsPresented = false }
                Button(L10n.start) { store.startAutomationFromOptions() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(store.automationStartMode == .selectedRun && store.automationStartRunID.isEmpty)
            }
        }.padding(24).frame(width: 440)
    }
}

// MARK: - Model Compare Sheet

struct ModelCompareSheetView: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("模型比较").font(DuDuFont.title())
            Text("选择两个已成功运行的模型进行比较审计。")
                .font(DuDuFont.caption(11)).foregroundStyle(.secondary)

            let runs = store.availableRunIDsForCompare()
            if runs.count < 2 {
                Text("至少需要两个已生成的模型才能进行比较。").font(DuDuFont.caption(11)).foregroundStyle(.orange)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Run A").font(DuDuFont.captionMedium(11)).frame(width: 60, alignment: .leading)
                    Picker("", selection: $store.compareRunA) {
                        ForEach(runs, id: \.self) { r in Text("run\(r)").tag(r) }
                    }.pickerStyle(.menu).labelsHidden()
                    Circle().fill(store.isModelRunSuccessful(runID: store.compareRunA) ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
                HStack {
                    Text("Run B").font(DuDuFont.captionMedium(11)).frame(width: 60, alignment: .leading)
                    Picker("", selection: $store.compareRunB) {
                        ForEach(runs, id: \.self) { r in Text("run\(r)").tag(r) }
                    }.pickerStyle(.menu).labelsHidden()
                    Circle().fill(store.isModelRunSuccessful(runID: store.compareRunB) ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
            }

            HStack {
                Spacer()
                Button(L10n.cancel, role: .cancel) { store.isCompareSheetPresented = false }
                Button(L10n.aiCompareStart) { store.runModelCompareAudit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.compareRunA == store.compareRunB || store.runner.isRunning)
            }
        }
        .padding(24).frame(width: 400)
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
        VStack(alignment: .leading, spacing: 20) {
            Text("PsN SCM 协变量筛选").font(DuDuFont.title())

            VStack(alignment: .leading, spacing: 4) {
                Text("基础模型").font(DuDuFont.captionSemibold())
                Picker("模型文件", selection: $store.scmModelRunID) {
                    ForEach(store.availableModFiles(), id: \.self) { mod in
                        Text(mod).tag(mod.replacingOccurrences(of: "run", with: "").replacingOccurrences(of: ".mod", with: ""))
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("数据集").font(DuDuFont.captionSemibold())
                Picker("数据集文件", selection: $store.scmDataFileName) {
                    ForEach(store.availableCSVFiles(), id: \.self) { csv in
                        Text(csv).tag(csv)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            // ── SCM Threshold Settings ──
            VStack(alignment: .leading, spacing: 8) {
                Text("假设检验阈值").font(DuDuFont.captionSemibold())

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("前向纳入 p").font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
                        Picker("前向纳入", selection: $store.scmPForward) {
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
                        Text("逆向剔除 p").font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
                        Picker("逆向剔除", selection: $store.scmPBackward) {
                            ForEach(backwardPickerOptions, id: \.self) { p in
                                Text("p=\(p)  (ΔOFV>\(ofvMap[p] ?? "-"))").tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if backwardOutOfRange {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("逆向剔除 p 值不能大于前向纳入 p 值")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.orange)
                }
            }

            Text("AI 将根据选定的模型文件和数据集自动撰写 runCONCOV{模型序号}.scm，然后在 SCM_run{模型序号}/ 子目录中运行 PsN SCM。")
                .font(DuDuFont.caption(11)).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L10n.cancel, role: .cancel) { store.showSCMDialog = false }
                Button("开始 SCM") { store.confirmSCMRun() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.scmModelRunID.isEmpty || store.scmDataFileName.isEmpty)
            }
        }
        .padding(24).frame(width: 420)
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
        ZStack {
            // Base frosted glass
            Rectangle()
                .fill(.ultraThinMaterial)

            // Subtle gradient overlay for liquid depth
            LinearGradient(
                colors: colorScheme == .dark
                    ? [.white.opacity(0.06), .white.opacity(0.02), .white.opacity(0.04)]
                    : [.white.opacity(0.40), .white.opacity(0.15), .white.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Top highlight edge
            LinearGradient(
                colors: [.white.opacity(0.20), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

// MARK: - Markdown Message View (renders bold, inline code, tables, headings)

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

    @State private var isHovered = false

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
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
                                    baseColors[0].opacity(0.12 + 0.05 * sin(t * 1.4)),
                                    baseColors[1].opacity(0.12 + 0.05 * cos(t * 1.2 + 0.6)),
                                ]),
                                startPoint: UnitPoint(x: 0.5 + 0.2 * sin(t * 0.6), y: 0),
                                endPoint: UnitPoint(x: 0.5 + 0.2 * cos(t * 0.6), y: 1)
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    baseColors[0].opacity(0.2 + 0.1 * sin(t * 1.0)),
                                    baseColors[1].opacity(0.2 + 0.1 * cos(t * 0.8)),
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
                                .foregroundStyle(.tertiary)
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

struct BaseModelConfirmView: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        VStack(spacing: 20) {
            Text("🏆 Phase 1 基础模型筛选完成")
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

            Text("是否以 run\(store.baseModelConfirmRunID) 作为最终基础模型，继续 Phase 2 协变量筛选？")
                .font(DuDuFont.body(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("取消，稍后手动启动") {
                    store.isBaseModelConfirmPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("✅ 确认，开始协变量筛选") {
                    store.confirmBaseModelAndStartPhase2()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
            }
        }
        .padding(28)
    }
}

// MARK: - Context Ring

struct ContextRing: View {
    let pct: Double  // 0.0–1.0

    var body: some View {
        let clamped = min(max(pct, 0), 1)
        let color: Color = clamped > 0.7 ? .orange : clamped > 0.5 ? .yellow : .green
        return ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 2)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: clamped)
        }
    }
}

// MARK: - Run Picker Sheet for Diagnostic Shortcuts

struct RunPickerSheet: View {
    let action: AssistantPanel.RunPickerAction
    @EnvironmentObject private var store: WorkbenchStore
    @Environment(\.dismiss) private var dismiss

    private var availableRuns: [String] {
        ProjectScanner.discoverRuns(in: store.projectURL)
            .filter { runID in
                FileManager.default.fileExists(atPath: store.projectURL.appendingPathComponent("run\(runID).mod").path)
            }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    private var actionLabel: String {
        switch action {
        case .gof:        return "GOF 诊断图"
        case .vpc:        return "VPC 预测检验"
        case .individual: return "个体拟合图"
        case .pkParams:   return "PK 参数提取"
        }
    }

    private var actionIcon: String {
        switch action {
        case .gof:        return "chart.xyaxis.line"
        case .vpc:        return "chart.bar.doc.horizontal"
        case .individual: return "person.2.wave.2"
        case .pkParams:   return "tablecells"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: actionIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.blue)
                Text(actionLabel)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            Divider()

            if availableRuns.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text("当前项目没有模型")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(availableRuns, id: \.self) { runID in
                    Button {
                        dismiss()
                        DispatchQueue.main.async {
                            execute(for: runID)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("run\(runID)")
                                .font(.system(size: 13, weight: runID == store.currentRun ? .semibold : .regular, design: .monospaced))
                                .foregroundStyle(runID == store.currentRun ? Color.blue : .primary)
                            Spacer()
                            if runID == store.currentRun {
                                Text("当前")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(.blue.opacity(0.12)))
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 240, minHeight: 240)
    }

    private func execute(for runID: String) {
        store.activateRun(runID)
        switch action {
        case .gof:        store.runGOF(for: runID)
        case .vpc:        store.runVPCPlot(for: runID)
        case .individual: store.runIndividualDVTime(for: runID)
        case .pkParams:   store.runPKParameterExtraction(for: runID)
        }
    }
}

