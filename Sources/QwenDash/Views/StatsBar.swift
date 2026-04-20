import SwiftUI

/// Top toolbar: app identity on the left, data readouts on the right.
/// All text is SF Pro; only the data values use monospaced digits so their
/// widths don't jitter as they update.
struct StatsBar: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        HStack(spacing: 22) {
            identity
            Spacer()

            stat(label: "Status",
                 value: vm.connected ? "Online" : "Offline",
                 dotColor: vm.connected ? Theme.signalOK : Theme.signalWarn)

            stat(label: "Model",
                 value: truncated(vm.modelId, 28),
                 mono: true)

            stat(label: "Latency",
                 value: vm.latencyMS.map { "\($0) ms" } ?? "—",
                 mono: true)

            stat(label: "Tokens/s",
                 value: vm.isStreaming ? String(format: "%.1f", vm.tokensPerSecond) : "—",
                 mono: true)

            stat(label: "Confidence",
                 value: vm.avgConfidence.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                 mono: true,
                 dotColor: vm.avgConfidence.map(confidenceColor))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.6)
        }
    }

    // MARK: - Identity

    @ViewBuilder
    private var identity: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.accent.opacity(0.16))
                    .frame(width: 22, height: 22)
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("QwenDash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Local LLM Interface")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Stat block

    @ViewBuilder
    private func stat(
        label: String,
        value: String,
        mono: Bool = false,
        dotColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                if let dot = dotColor {
                    Circle()
                        .fill(dot)
                        .frame(width: 6, height: 6)
                }
                Text(value)
                    .font(
                        mono
                            ? .system(size: 12, weight: .medium, design: .monospaced)
                            : .system(size: 12, weight: .medium)
                    )
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Helpers

    private func truncated(_ s: String, _ n: Int) -> String {
        s.count <= n ? s : "…" + s.suffix(n - 1)
    }

    /// Grade the confidence dot from warn → ok as the model becomes more
    /// decisive. Only two stops to keep it readable.
    private func confidenceColor(_ p: Double) -> Color {
        p >= 0.5 ? Theme.signalOK : Theme.signalWarn
    }
}
