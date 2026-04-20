import SwiftUI

/// The full dashboard. Top: stats. Middle: synapse map. Bottom: chat + input.
struct ContentView: View {
    @StateObject private var vm = ChatViewModel()

    var body: some View {
        ZStack {
            CyberBackground()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                StatsBar(vm: vm)

                // Synapse map panel
                GlassPanel(tint: Theme.neonViolet, cornerRadius: 22) {
                    ZStack(alignment: .topLeading) {
                        SynapseMapView(vm: vm)
                            .padding(.top, 28) // leave space for column labels
                            .padding(.horizontal, 4)

                        PanelLabel(text: "▍ Synapse Map", color: Theme.neonViolet)
                            .padding(.leading, 16)
                            .padding(.top, 12)
                    }
                }
                .frame(minHeight: 280, idealHeight: 340, maxHeight: 380)
                .padding(.horizontal, 18)

                // Chat panel
                GlassPanel(tint: Theme.neonCyan, cornerRadius: 22) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            PanelLabel(text: "▍ Conversation", color: Theme.neonCyan)
                            Spacer()
                            if !vm.messages.isEmpty {
                                Button {
                                    vm.messages.removeAll()
                                    vm.lastError = nil
                                    vm.graph.clear()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("CLEAR")
                                    }
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundStyle(Theme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                        Divider()
                            .background(Color.white.opacity(0.06))

                        ChatView(vm: vm)
                    }
                }
                .padding(.horizontal, 18)

                // Input panel
                GlassPanel(tint: Theme.neonMagenta, cornerRadius: 18) {
                    InputBar(vm: vm)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }
}

/// Deep nightside backdrop — three coloured blobs drift slowly under a
/// vignette, so the glass panels pick up a living, refracting world behind
/// them instead of a static wash. The blobs are heavily blurred radial
/// gradients; their positions are sine-driven so they breathe rather than
/// loop.
private struct CyberBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Theme.backgroundDeep

                // Violet blob — orbits upper-right area.
                blob(
                    color: Theme.neonViolet,
                    opacity: 0.38,
                    center: UnitPoint(
                        x: 0.80 + 0.08 * sin(t * 0.07),
                        y: 0.12 + 0.06 * cos(t * 0.09)
                    )
                )

                // Cyan blob — drifts across the lower-left quadrant.
                blob(
                    color: Theme.neonCyan,
                    opacity: 0.22,
                    center: UnitPoint(
                        x: 0.12 + 0.07 * cos(t * 0.05),
                        y: 0.90 + 0.05 * sin(t * 0.06)
                    )
                )

                // Magenta core — slowly orbits the centre.
                blob(
                    color: Theme.neonMagenta,
                    opacity: 0.14,
                    center: UnitPoint(
                        x: 0.50 + 0.12 * cos(t * 0.04),
                        y: 0.50 + 0.10 * sin(t * 0.045)
                    )
                )

                // Wandering amber spark — smaller, quicker, low opacity.
                blob(
                    color: Theme.neonAmber,
                    opacity: 0.08,
                    center: UnitPoint(
                        x: 0.65 + 0.15 * sin(t * 0.11),
                        y: 0.75 + 0.10 * cos(t * 0.13)
                    ),
                    radius: 420
                )

                // Vignette — seals the edges and pushes focus to centre.
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.65)],
                    center: .center, startRadius: 260, endRadius: 980
                )
            }
        }
    }

    /// A single soft radial glow. `opacity` is applied to the *inner* stop
    /// so the blob fades cleanly into the darkness around it.
    @ViewBuilder
    private func blob(
        color: Color,
        opacity: Double,
        center: UnitPoint,
        radius: CGFloat = 720
    ) -> some View {
        RadialGradient(
            colors: [color.opacity(opacity), Color.clear],
            center: center,
            startRadius: 40,
            endRadius: radius
        )
    }
}

#Preview {
    ContentView()
        .frame(width: 1280, height: 880)
}
