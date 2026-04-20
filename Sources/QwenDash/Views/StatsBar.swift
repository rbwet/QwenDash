import SwiftUI

/// Top status bar: connection dot, model id, tokens/sec, latency.
struct StatsBar: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        HStack(spacing: 18) {
            // Title / brand
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.neonMagenta.opacity(0.25))
                        .frame(width: 22, height: 22)
                        .blur(radius: 6)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.neonCyan, Theme.neonMagenta],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Text("QWENDASH")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.textPrimary)
                Text("/ NEURAL INTERFACE")
                    .font(Theme.monoLabel)
                    .tracking(1.5)
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer()

            stat(label: "STATUS", value: vm.connected ? "ONLINE" : "OFFLINE",
                 color: vm.connected ? Theme.neonGreen : Theme.neonAmber,
                 showDot: true)

            stat(label: "MODEL", value: truncated(vm.modelId, 32),
                 color: Theme.neonCyan)

            stat(label: "LATENCY",
                 value: vm.latencyMS.map { "\($0)MS" } ?? "—",
                 color: Theme.neonViolet)

            stat(label: "TOK/S",
                 value: vm.isStreaming ? String(format: "%.1f", vm.tokensPerSecond) : "—",
                 color: Theme.neonMagenta)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func stat(label: String, value: String, color: Color, showDot: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.monoLabel)
                .tracking(1.4)
                .foregroundStyle(Theme.textMuted)
            HStack(spacing: 6) {
                if showDot {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .shadow(color: color, radius: 4)
                }
                Text(value)
                    .font(Theme.monoBody)
                    .foregroundStyle(color)
            }
        }
    }

    private func truncated(_ s: String, _ n: Int) -> String {
        s.count <= n ? s : "…" + s.suffix(n - 1)
    }
}
