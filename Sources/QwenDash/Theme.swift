import SwiftUI

/// Restrained, native-feeling palette. One accent colour, a lot of greyscale,
/// SF Pro for chrome and monospaced only where the text is genuinely data.
enum Theme {
    // Window surface — a single very-dark base so the system materials can
    // layer translucency over it. We intentionally don't paint big coloured
    // washes; let `.regularMaterial` do the work.
    static let windowBase = Color(red: 0.085, green: 0.090, blue: 0.105)

    // The one accent colour used across selection, focus, caret, active
    // elements. Deliberately the only saturated hue in the app.
    static let accent = Color(red: 0.30, green: 0.66, blue: 1.00)

    // Muted palette for the synapse map and secondary signals. These are
    // desaturated versions of the old neons so the visualisation still reads
    // as three distinct regions without screaming.
    static let mapInput   = Color(red: 0.40, green: 0.78, blue: 1.00)
    static let mapHidden  = Color(red: 0.70, green: 0.65, blue: 0.95)
    static let mapOutput  = Color(red: 1.00, green: 0.52, blue: 0.68)

    // Status signals — kept close to the macOS system palette.
    static let signalOK   = Color(red: 0.30, green: 0.82, blue: 0.48)
    static let signalWarn = Color(red: 1.00, green: 0.70, blue: 0.25)

    // Legacy aliases so existing call sites keep compiling. Prefer the
    // semantic names above in new code.
    static let background      = windowBase
    static let backgroundDeep  = windowBase
    static let panel           = Color.white.opacity(0.03)
    static let panelStroke     = Color.white.opacity(0.08)
    static let neonCyan        = mapInput
    static let neonMagenta     = mapOutput
    static let neonViolet      = mapHidden
    static let neonAmber       = signalWarn
    static let neonGreen       = signalOK
    static let textPrimary     = Color.primary
    static let textSecondary   = Color.secondary
    static let textMuted       = Color.secondary.opacity(0.7)

    // Typography — SF Pro for everything UI, monospaced digits only where a
    // value needs to sit still (counters, model IDs).
    static let monoSmall  = Font.system(size: 11, weight: .medium,  design: .monospaced)
    static let monoBody   = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoLabel  = Font.system(size: 10, weight: .semibold)
    static let titleFont  = Font.system(size: 14, weight: .semibold)

    // Panel hairline — the single stroke colour used everywhere.
    static let hairline = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.14)
}

/// A restrained content panel. Uses the system material so translucency reads
/// as depth, with a single thin hairline for definition and a low-contrast
/// shadow for elevation. No tinted washes, no animated shimmer — the content
/// inside is the thing worth looking at.
struct GlassPanel<Content: View>: View {
    /// Kept for source compatibility with existing call sites; ignored now.
    var tint: Color = Theme.accent
    var cornerRadius: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 6)
    }
}

/// A small all-caps section label, the kind you see above sidebar sections
/// and toolbar groups in native macOS apps.
struct PanelLabel: View {
    let text: String
    /// Kept for source compatibility; ignored in the native palette.
    var color: Color = Theme.accent
    var body: some View {
        Text(cleaned(text).uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    /// Existing call sites pass strings like "▍ Synapse Map". Strip the
    /// decorative prefix so we render clean label text.
    private func cleaned(_ s: String) -> String {
        var t = s
        while let first = t.first, !first.isLetter && !first.isNumber {
            t.removeFirst()
        }
        return t.trimmingCharacters(in: .whitespaces)
    }
}
