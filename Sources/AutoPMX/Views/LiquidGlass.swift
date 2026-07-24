import SwiftUI

// MARK: - Liquid Glass Hover Effect (Particles + Gradient)

struct LiquidGlassHoverModifier: ViewModifier {
    let cornerRadius: CGFloat
    let gradientColors: [Color]

    @State private var isHovered = false
    @Environment(\.particleEffectsEnabled) private var effectsEnabled
    @Environment(\.particleCount) private var maxParticles

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

                    // Fine floating particles — random drift, blue gradient, 3× speed
                    if isHovered, effectsEnabled, maxParticles > 0 {
                        TimelineView(.animation) { timeline in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let displayCount = min(maxParticles, 10000)
                            Canvas { context, size in
                                for i in 0..<displayCount {
                                    let seed   = Double(i) * 1.9 + 0.3
                                    let phaseX = Double(i) * 0.619
                                    let phaseY = Double(i) * 0.427
                                    // 3× faster multi-octave pseudo-random drift
                                    let rawX = sin(t * 0.54 + phaseX) * cos(t * 0.39 + phaseX * 2.7) * 0.6
                                             + sin(t * 0.27 + phaseX * 0.4) * 0.4
                                    let rawY = cos(t * 0.48 + phaseY) * sin(t * 0.33 + phaseY * 1.6) * 0.6
                                             + cos(t * 0.21 + phaseY * 1.1) * 0.4
                                    let x = size.width  * (0.08 + 0.84 * ((rawX + 1.0) / 2.0))
                                    let y = size.height * (0.10 + 0.80 * ((rawY + 1.0) / 2.0))
                                    let alpha  = 0.10 + 0.10 * sin(t * 2.1 + seed)
                                    let radius = 0.6 + 0.7 * sin(t * 1.05 + seed * 0.7)

                                    // Blue gradient shades
                                    let bright = 0.55 + 0.45 * sin(t * 0.8 + seed * 1.3)
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
                        .allowsHitTesting(false)
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

// MARK: - Environment Keys for Particle Settings

private struct ParticleEffectsEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

private struct ParticleCountKey: EnvironmentKey {
    static let defaultValue: Int = 30
}

extension EnvironmentValues {
    var particleEffectsEnabled: Bool {
        get { self[ParticleEffectsEnabledKey.self] }
        set { self[ParticleEffectsEnabledKey.self] = newValue }
    }
    var particleCount: Int {
        get { self[ParticleCountKey.self] }
        set { self[ParticleCountKey.self] = newValue }
    }
}
