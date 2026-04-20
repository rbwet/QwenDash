import SwiftUI

/// Cyberpunk-glass palette. Think Blade Runner 2049 hologram terminal.
enum Theme {
    // Base
    static let background      = Color(red: 0.020, green: 0.025, blue: 0.045) // near-black, slight indigo
    static let backgroundDeep  = Color(red: 0.005, green: 0.005, blue: 0.020)
    static let panel           = Color.white.opacity(0.04)
    static let panelStroke     = Color.white.opacity(0.10)

    // Neons
    static let neonCyan    = Color(red: 0.30, green: 0.95, blue: 1.00)
    static let neonMagenta = Color(red: 1.00, green: 0.18, blue: 0.62)
    static let neonViolet  = Color(red: 0.62, green: 0.30, blue: 1.00)
    static let neonAmber   = Color(red: 1.00, green: 0.62, blue: 0.20)
    static let neonGreen   = Color(red: 0.40, green: 1.00, blue: 0.65)

    // Text
    static let textPrimary   = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.62)
    static let textMuted     = Color.white.opacity(0.38)

    // Fonts
    static let monoSmall  = Font.system(size: 11, weight: .medium,  design: .monospaced)
    static let monoBody   = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoLabel  = Font.system(size: 10, weight: .semibold, design: .monospaced)
    static let titleFont  = Font.system(size: 14, weight: .semibold, design: .rounded)
}

/// A frosted glass card with real depth: a material substrate, a tinted body
/// wash, a slowly drifting caustic shimmer, a top sheen + bottom darken to
/// simulate a curved glass surface, a two-tone edge stroke, and stacked
/// shadows for elevation.
struct GlassPanel<Content: View>: View {
    var tint: Color = Theme.neonCyan
    var cornerRadius: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                GlassSurface(tint: tint, cornerRadius: cornerRadius)
            }
            .overlay {
                // Outer edge — bright at the top, darker at the bottom, like
                // light rolling over a curved glass lip.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                tint.opacity(0.45),
                                Color.white.opacity(0.06),
                                Theme.neonMagenta.opacity(0.22),
                                Color.black.opacity(0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                // Inner hairline — thin pale line offset inward so the edge
                // feels etched rather than painted.
                RoundedRectangle(cornerRadius: max(cornerRadius - 1, 1), style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                    .padding(1)
                    .allowsHitTesting(false)
            }
            .compositingGroup()
            // Coloured bloom from the tint — gives each panel its own aura.
            .shadow(color: tint.opacity(0.28), radius: 26, x: 0, y: 10)
            // Deep cast shadow for physical elevation above the background.
            .shadow(color: Color.black.opacity(0.55), radius: 34, x: 0, y: 22)
    }
}

/// The stack of layers that make up the glass interior. Split out so the
/// compositingGroup/shadows on `GlassPanel` don't fight with the animated
/// shimmer layer's blend mode.
private struct GlassSurface: View {
    let tint: Color
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            // 1. True material blur — pulls colour from whatever sits behind
            //    the panel (backgrounds, other panels) for real depth.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            // 2. Tinted body wash — gives each panel its colour identity
            //    without washing out the material underneath.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.14),
                            Color.clear,
                            Theme.neonViolet.opacity(0.08),
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 3. Slow liquid shimmer — a conic sweep that rotates once every
            //    ~40s. Feels like light moving through water. Low-framerate
            //    timeline so it doesn't tax the GPU on every panel.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let angle = Angle(degrees: (t * 9).truncatingRemainder(dividingBy: 360))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        AngularGradient(
                            colors: [
                                tint.opacity(0.18),
                                Color.clear,
                                Theme.neonMagenta.opacity(0.12),
                                Color.clear,
                                Theme.neonViolet.opacity(0.16),
                                Color.clear,
                                tint.opacity(0.18)
                            ],
                            center: .center,
                            angle: angle
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.55)
                    .blur(radius: 30)
            }
            .allowsHitTesting(false)

            // 4. Top sheen — highlight catching the upper curve.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.45)
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // 5. Bottom darken — the underside of the glass falls into shadow.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// A small neon section label like `▍ SYNAPSE MAP`.
struct PanelLabel: View {
    let text: String
    var color: Color = Theme.neonCyan
    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 11)
                .shadow(color: color.opacity(0.9), radius: 5)
                .shadow(color: color.opacity(0.5), radius: 10)
            Text(text.uppercased())
                .font(Theme.monoLabel)
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
