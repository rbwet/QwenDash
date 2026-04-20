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

/// Deep nightside background — radial gradient + faint vignette + drifting noise.
private struct CyberBackground: View {
    var body: some View {
        ZStack {
            Theme.backgroundDeep

            // Hot violet glow upper-right
            RadialGradient(
                colors: [Theme.neonViolet.opacity(0.30), Color.clear],
                center: UnitPoint(x: 0.85, y: 0.05),
                startRadius: 50, endRadius: 700
            )

            // Cool cyan glow lower-left
            RadialGradient(
                colors: [Theme.neonCyan.opacity(0.18), Color.clear],
                center: UnitPoint(x: 0.10, y: 0.95),
                startRadius: 40, endRadius: 650
            )

            // Magenta wash
            RadialGradient(
                colors: [Theme.neonMagenta.opacity(0.10), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 100, endRadius: 800
            )

            // Vignette
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.55)],
                center: .center, startRadius: 250, endRadius: 950
            )
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1280, height: 880)
}
