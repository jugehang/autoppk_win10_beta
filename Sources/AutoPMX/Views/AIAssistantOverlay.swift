import SwiftUI
import AppKit

// MARK: - Overlay

struct AIAssistantOverlay: View {
    @EnvironmentObject private var store: WorkbenchStore
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
            Bundle.main.url(forResource: "DuDuPMxButton", withExtension: "png"),
            Bundle.main.url(forResource: "DuDuPMxSource", withExtension: "png")
        ]
        for u in candidates {
            if let u, let img = NSImage(contentsOf: u) { return img }
        }
        return nil
    }
}

// MARK: - Floating Button (Aurora)

struct FloatingButton: View {
    let isActive: Bool
    let showingDuDu: Bool

    @State private var glowPhase: Double = 0

    // Aurora color palette — warm pastel hues blending into each other
    private let auroraColors: [Color] = [
        Color(hue: 0.58, saturation: 0.7, brightness: 0.9),  // cyan
        Color(hue: 0.65, saturation: 0.6, brightness: 0.85), // soft blue
        Color(hue: 0.75, saturation: 0.55, brightness: 0.88), // indigo
        Color(hue: 0.82, saturation: 0.5, brightness: 0.9),  // violet
        Color(hue: 0.72, saturation: 0.65, brightness: 0.85), // purple-blue
        Color(hue: 0.60, saturation: 0.6, brightness: 0.88), // teal
        Color(hue: 0.55, saturation: 0.7, brightness: 0.9),  // cyan-mint
        Color(hue: 0.68, saturation: 0.5, brightness: 0.92), // periwinkle
    ]

    var body: some View {
        ZStack {
            // Subtle ambient glow ring always visible
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: auroraColors),
                        center: .center
                    ),
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

            // Aurora glow rings when modeling is active
            if isActive {
                // Outer aurora ring - slow rotation
                AuroraRing(
                    colors: [.cyan.opacity(0.4), .purple.opacity(0.3), .blue.opacity(0.2), .clear],
                    size: 56,
                    lineWidth: 3,
                    duration: 4
                )
                // Middle aurora ring - reverse direction
                AuroraRing(
                    colors: [.mint.opacity(0.35), .indigo.opacity(0.25), .teal.opacity(0.15), .clear],
                    size: 48,
                    lineWidth: 2,
                    duration: 3,
                    reverse: true
                )
                // Pulsing dot particles
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
                        .stroke(isActive ? .white.opacity(0.3) : .clear, lineWidth: 1)
                )

            // DuDu icon
            if showingDuDu,
               let logo = NSImage(contentsOf: Bundle.main.url(forResource: "DuDuPMxButton", withExtension: "png")
                ?? Bundle.main.url(forResource: "DuDuPMxSource", withExtension: "png")!) {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: 56, height: 56)
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
    @State private var particles: [(Double, Double, Double)] = (0..<8).map { _ in
        (Double.random(in: 0..<1), Double.random(in: 0..<1), Double.random(in: 1.5..<3))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for (fraction, offset, speed) in particles {
                    let angle = Angle.degrees(fraction * 360 + t * speed * 40)
                    let radius = size.width * 0.4
                    let x = size.width / 2 + cos(angle.radians) * radius
                    let y = size.height / 2 + sin(angle.radians) * radius
                    let brightness = 0.6 + 0.4 * sin(t * speed * 3 + offset * .pi * 2)
                    let dotSize: CGFloat = 2.5 + 1.5 * sin(t * speed * 2 + offset * .pi)
                    let dot = Path(ellipseIn: CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize))
                    let color = Color(
                        hue: (fraction + t * 0.03).truncatingRemainder(dividingBy: 1),
                        saturation: 0.8,
                        brightness: brightness
                    )
                    context.fill(dot, with: .color(color.opacity(0.85)))
                    // Soft glow around each particle
                    let glow = Path(ellipseIn: CGRect(x: x - dotSize*1.5, y: y - dotSize*1.5, width: dotSize*3, height: dotSize*3))
                    context.fill(glow, with: .color(color.opacity(0.15)))
                }
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
    }

    // MARK: Header
    private var headerView: some View {
        HStack(spacing: 8) {
            if let logo = duDuThumb {
                Image(nsImage: logo).resizable().scaledToFit()
                    .frame(width: 22, height: 22).clipShape(Circle())
            }
            Text("DuDu PMx").font(.system(size: 13, weight: .semibold))
            Spacer()
            HStack(spacing: 6) {
                Button("Compare") { store.presentModelCompare() }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 10).frame(height: 22)
                    .background(.purple.opacity(0.08), in: Capsule())
                    .buttonStyle(.plain)
                Button("DuDu Auto") { store.presentAutomationOptions() }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 10).frame(height: 22)
                    .background(.blue.opacity(0.08), in: Capsule())
                    .buttonStyle(.plain)
                if store.isAutoModeling {
                    Button { store.requestStopAutomation() } label: {
                        Label("停止", systemImage: "stop.fill")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 10).frame(height: 22)
                    }
                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                }
            }
            Button { store.isAssistantPanelPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15)).foregroundStyle(.tertiary)
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
                        .font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                    Text("推理过程").font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.thinkingSteps.count) 步").font(.system(size: 10)).foregroundStyle(.tertiary)
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
                                Text(step.text).font(.system(size: 10))
                                    .foregroundStyle(step.type == .done ? .secondary : .primary)
                                if !step.detail.isEmpty {
                                    Text(step.detail).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
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
                            Text("思考中...").font(.system(size: 11)).foregroundStyle(.tertiary)
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
                    .font(.system(size: 13)).textSelection(.enabled).lineSpacing(3)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(
                        Color.blue,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .contextMenu {
                        Button("复制") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        }
                        Button("填入输入框") { store.assistantInput = message.text }
                    }
                    .frame(maxWidth: 300, alignment: .trailing)
            } else {
                MarkdownMessageView(text: message.text)
                    .contextMenu {
                        Button("复制") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.text, forType: .string)
                        }
                        Button("填入输入框") { store.assistantInput = message.text }
                    }
                    .frame(maxWidth: 380, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(
                        Color.green.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }

            if !isUser { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 12).padding(.vertical, 1)
    }

    // MARK: Input Bar
    private var inputBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 6) {
                TextField("向 DuDu PMx 提问...", text: $store.assistantInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
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
            .background(.regularMaterial)
        }
    }
}

// MARK: - Automation Sheet

struct AutomationOptionsSheetView: View {
    @EnvironmentObject private var store: WorkbenchStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DuDu Auto — 自动建模").font(.system(size: 15, weight: .semibold))
            Picker("模式", selection: $store.automationStartMode) {
                ForEach(AutomationStartMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.title).font(.system(size: 12, weight: .medium))
                        Text(mode.detail).font(.system(size: 10)).foregroundStyle(.tertiary)
                    }.tag(mode).padding(.vertical, 4)
                }
            }.pickerStyle(.radioGroup)
            if store.automationStartMode == .selectedRun {
                Picker("父模型", selection: $store.automationStartRunID) {
                    ForEach(store.automationAvailableRunIDs, id: \.self) { r in Text("run\(r)").tag(r) }
                }.disabled(store.automationAvailableRunIDs.isEmpty)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("建模数据集").font(.system(size: 11, weight: .semibold))
                Picker("数据集", selection: $store.automationDataFile) {
                    Text("（不指定）").tag("")
                    ForEach(store.availableCSVFiles(), id: \.self) { csv in
                        Text(csv).tag(csv)
                    }
                }
                .pickerStyle(.menu)
                .disabled(store.availableCSVFiles().count <= 1)
                if store.availableCSVFiles().count <= 1 {
                    Text("当前项目只有一个数据集：\(store.dataFile)").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("建模指导（可选）").font(.system(size: 11, weight: .semibold))
                TextEditor(text: $store.automationUserGuidance).font(.system(size: 12)).frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Spacer()
                Button("取消", role: .cancel) { store.isAutomationOptionsPresented = false }
                Button("开始") { store.startAutomationFromOptions() }
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
            Text("模型比较").font(.system(size: 15, weight: .semibold))
            Text("选择两个已成功运行的模型进行比较审计。")
                .font(.system(size: 11)).foregroundStyle(.secondary)

            let runs = store.availableRunIDsForCompare()
            if runs.count < 2 {
                Text("至少需要两个已生成的模型才能进行比较。").font(.system(size: 11)).foregroundStyle(.orange)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Run A").font(.system(size: 11, weight: .medium)).frame(width: 60, alignment: .leading)
                    Picker("", selection: $store.compareRunA) {
                        ForEach(runs, id: \.self) { r in Text("run\(r)").tag(r) }
                    }.pickerStyle(.menu).labelsHidden()
                    Circle().fill(store.isModelRunSuccessful(runID: store.compareRunA) ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
                HStack {
                    Text("Run B").font(.system(size: 11, weight: .medium)).frame(width: 60, alignment: .leading)
                    Picker("", selection: $store.compareRunB) {
                        ForEach(runs, id: \.self) { r in Text("run\(r)").tag(r) }
                    }.pickerStyle(.menu).labelsHidden()
                    Circle().fill(store.isModelRunSuccessful(runID: store.compareRunB) ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
            }

            HStack {
                Spacer()
                Button("取消", role: .cancel) { store.isCompareSheetPresented = false }
                Button("开始比较") { store.runModelCompareAudit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.compareRunA == store.compareRunB || store.runner.isRunning)
            }
        }
        .padding(24).frame(width: 400)
    }
}

// MARK: - Helpers

private var duDuThumb: NSImage? {
    let candidates = [
        Bundle.main.url(forResource: "DuDuPMxButton", withExtension: "png"),
        Bundle.main.url(forResource: "DuDuPMxSource", withExtension: "png")
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
        .font(.system(size: 13))
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

        func flushText() {
            let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                blocks.append(AnyView(parseInlineMarkdown(trimmed)))
            }
            pendingText = ""
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
                        .font(.system(size: 11, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                ))
                codeLines = []
            }
            inCodeBlock = false
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                flushText()
                if inCodeBlock { flushCodeBlock() } else { inCodeBlock = true }
                continue
            }
            if inCodeBlock { codeLines.append(line); continue }

            if trimmed.hasPrefix("|"), trimmed.hasSuffix("|") {
                let sepPattern = try? NSRegularExpression(pattern: #"^\|[\s:\|-]+\|$"#)
                if sepPattern?.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) != nil { continue }
                flushText()
                let cells = trimmed.dropFirst().dropLast().components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                tableRows.append(cells)
                inTable = true
                continue
            } else if inTable { flushTable() }

            if trimmed.hasPrefix("### ") {
                flushText()
                blocks.append(AnyView(parseInlineMarkdown(String(trimmed.dropFirst(4))).font(.system(size: 13, weight: .bold)).padding(.top, 4)))
                continue
            }
            if trimmed.hasPrefix("## ") {
                flushText()
                blocks.append(AnyView(parseInlineMarkdown(String(trimmed.dropFirst(3))).font(.system(size: 14, weight: .bold)).padding(.top, 6)))
                continue
            }

            if trimmed.isEmpty { flushText(); continue }

            pendingText += (pendingText.isEmpty ? "" : " ") + trimmed
        }

        flushText(); flushTable(); flushCodeBlock()
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
                result = result + Text(inner).font(.system(size: 12, design: .monospaced)).foregroundColor(.pink)
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
                    Text(headers[i]).font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
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
            .font(.system(size: 10, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(isEven ? Color.clear : Color.blue.opacity(0.03))
    }
}

