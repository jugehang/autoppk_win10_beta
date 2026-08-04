import SwiftUI

extension Color {
    /// High-contrast text color for liquid-glass sheets: pure black in light mode
    /// and near-white in dark mode, so the same UI stays readable in both appearances.
    static let adaptiveSheetText = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.97, alpha: 1)
            : NSColor.black
    }))
}

// MARK: - Liquid Glass Hover Effect (Gradient)

struct LiquidGlassHoverModifier: ViewModifier {
    let cornerRadius: CGFloat
    let gradientColors: [Color]

    @State private var isHovered = false
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Liquid glass base
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial.opacity(isHovered ? 0.25 : 0))

                    // Subtle gradient glow on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        gradientColors.first?.opacity(0.12) ?? Color.blue.opacity(0.12),
                                        gradientColors.last?.opacity(0.06) ?? Color.blue.opacity(0.06),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    // Liquid glass border
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isHovered
                                    ? [gradientColors.first?.opacity(0.18) ?? Color.blue.opacity(0.18),
                                       gradientColors.last?.opacity(0.10) ?? Color.blue.opacity(0.10)]
                                    : [Color.primary.opacity(0.06), Color.primary.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHovered ? 1.0 : 0.5
                        )
                }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Convenience Extension

extension View {
    func liquidGlassHover(cornerRadius: CGFloat = 7, colors: [Color] = [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)]) -> some View {
        modifier(LiquidGlassHoverModifier(cornerRadius: cornerRadius, gradientColors: colors))
    }
}

// MARK: - Liquid Glass Backdrop

struct LiquidGlassBackdrop: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.06),
                    Color.purple.opacity(0.04),
                    Color.cyan.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Liquid Glass Card

struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.14), Color.primary.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 10, tint: Color = Color.blue) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }
}

extension Button {
    func liquidGlassButton(
        cornerRadius: CGFloat = 7,
        colors: [Color] = [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
        height: CGFloat = 26
    ) -> some View {
        buttonStyle(.plain)
            .padding(.horizontal, 10)
            .frame(minHeight: height)
            .liquidGlassHover(cornerRadius: cornerRadius, colors: colors)
    }
}

// MARK: - Liquid Glass Toolbar Button

struct LiquidGlassToolbarButton: View {
    let label: String
    let icon: String
    let colors: [Color]
    let action: () -> Void

    init(_ label: String, icon: String, colors: [Color] = [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)], action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.colors = colors
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 28)
        }
        .buttonStyle(.plain)
        .liquidGlassHover(cornerRadius: 7, colors: colors)
        .help(label)
    }
}
