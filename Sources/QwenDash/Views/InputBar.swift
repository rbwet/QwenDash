import SwiftUI

/// Bottom input row: text editor + send/stop button.
/// Cmd+Enter and Enter both send.
struct InputBar: View {
    @ObservedObject var vm: ChatViewModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if vm.input.isEmpty {
                    Text("Type a query…  (⌘⏎ to send, ⏎ for newline)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $vm.input)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.neonCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .focused($focused)
                    .onAppear { focused = true }
            }
            .frame(minHeight: 46, maxHeight: 110)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.neonCyan.opacity(focused ? 0.07 : 0.03))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        focused ? Theme.neonCyan.opacity(0.7) : Color.white.opacity(0.12),
                        lineWidth: focused ? 1.0 : 0.7
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: Theme.neonCyan.opacity(focused ? 0.30 : 0.0),
                    radius: focused ? 12 : 0)

            sendButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var sendButton: some View {
        Button {
            if vm.isStreaming {
                vm.cancelStreaming()
            } else {
                vm.send()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: vm.isStreaming
                                ? [Theme.neonAmber.opacity(0.25), Theme.neonMagenta.opacity(0.25)]
                                : [Theme.neonCyan.opacity(0.30), Theme.neonMagenta.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 46)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        vm.isStreaming ? Theme.neonAmber : Theme.neonCyan,
                        lineWidth: 1.0
                    )
                    .frame(width: 48, height: 46)
                Image(systemName: vm.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(vm.isStreaming ? Theme.neonAmber : Theme.neonCyan)
            }
            .shadow(color: (vm.isStreaming ? Theme.neonAmber : Theme.neonCyan).opacity(0.5),
                    radius: 10)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(!vm.isStreaming && vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(
            (!vm.isStreaming && vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ? 0.5 : 1.0
        )
    }
}
