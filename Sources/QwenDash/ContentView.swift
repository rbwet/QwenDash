import SwiftUI

/// The full dashboard. Top: stats. Middle: synapse map. Bottom: chat + input.
struct ContentView: View {
    @StateObject private var vm = ChatViewModel()

    var body: some View {
        ZStack {
            CyberBackground()
                .ignoresSafeArea()

            VStack(spacing: 12) {
                StatsBar(vm: vm)

                // Synapse map panel
                GlassPanel(cornerRadius: 14) {
                    ZStack(alignment: .topLeading) {
                        SynapseMapView(vm: vm)
                            .padding(.top, 30)
                            .padding(.horizontal, 4)

                        PanelLabel(text: "Synapse Map")
                            .padding(.leading, 16)
                            .padding(.top, 12)
                    }
                }
                .frame(minHeight: 280, idealHeight: 340, maxHeight: 380)
                .padding(.horizontal, 18)

                // Chat panel
                GlassPanel(cornerRadius: 14) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            PanelLabel(text: "Conversation")
                            Spacer()
                            if !vm.messages.isEmpty {
                                Button {
                                    vm.messages.removeAll()
                                    vm.lastError = nil
                                    vm.graph.clear()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10, weight: .medium))
                                        Text("Clear")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        Divider()

                        ChatView(vm: vm)
                    }
                }
                .padding(.horizontal, 18)

                // Input panel
                GlassPanel(cornerRadius: 14) {
                    InputBar(vm: vm)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }
}

/// Restrained window backdrop. A single dark base tone with a whisper of
/// vertical gradient for subtle depth — the rest of the perceived depth
/// comes from the system materials on the panels that sit over it.
private struct CyberBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.075, green: 0.080, blue: 0.095),
                Color(red: 0.055, green: 0.060, blue: 0.075)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview {
    ContentView()
        .frame(width: 1280, height: 880)
}
