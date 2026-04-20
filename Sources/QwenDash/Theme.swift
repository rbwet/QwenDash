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

/// A frosted glass card with a subtle neon hairline.
struct GlassPanel<Content: View>: View {
    var tint: Color = Theme.neonCyan
    var cornerRadius: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.06),
                                        Color.clear,
                                        Theme.neonViolet.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.55),
                                Color.white.opacity(0.10),
                                Theme.neonMagenta.opacity(0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: tint.opacity(0.18), radius: 22, x: 0, y: 8)
    }
}

/// A small neon section label like `▍ SYNAPSE MAP`.
struct PanelLabel: View {
    let text: String
    var color: Color = Theme.neonCyan
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 11)
                .shadow(color: color, radius: 4)
            Text(text.uppercased())
                .font(Theme.monoLabel)
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
