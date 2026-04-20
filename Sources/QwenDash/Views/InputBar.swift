import SwiftUI

/// Bottom input row: text editor + send/stop button.
/// Cmd+Enter and Enter both send.
struct InputBar: View {
    @ObservedObject var vm: ChatViewModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            editorField
            sendButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorField: some View {
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
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)

                // Tinted wash — brighter when focused, like the glass lights up.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.neonCyan.opacity(focused ? 0.14 : 0.04),
                                Color.clear,
                                Theme.neonViolet.opacity(focused ? 0.10 : 0.03),
                                Color.black.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Top sheen.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.5)
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay {
            // Two-tone edge — bright top, darker bottom, extra cyan when focused.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: focused
                            ? [
                                Color.white.opacity(0.55),
                                Theme.neonCyan.opacity(0.75),
                                Theme.neonViolet.opacity(0.45),
                                Color.black.opacity(0.35)
                            ]
                            : [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.08),
                                Color.black.opacity(0.25)
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: focused ? 1.0 : 0.7
                )
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.white.opacity(focused ? 0.10 : 0.04), lineWidth: 0.5)
                .padding(1)
                .allowsHitTesting(false)
        }
        .shadow(color: Theme.neonCyan.opacity(focused ? 0.32 : 0.0),
                radius: focused ? 14 : 0)
        .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
    }

    // MARK: - Send button

    @ViewBuilder
    private var sendButton: some View {
        let accent: Color = vm.isStreaming ? Theme.neonAmber : Theme.neonCyan
        let accentB: Color = vm.isStreaming ? Theme.neonMagenta : Theme.neonMagenta

        Button {
            if vm.isStreaming {
                vm.cancelStreaming()
            } else {
                vm.send()
            }
        } label: {
            ZStack {
                // Base blur for glass.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)

                // Coloured core — bold enough to read as a button, not a panel.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.55),
                                accentB.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Top sheen.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.45),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.plusLighter)

                // Inner stroke — glass lip.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.75),
                                accent.opacity(0.8),
                                Color.black.opacity(0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )

                Image(systemName: vm.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .shadow(color: accent.opacity(0.9), radius: 6)
            }
            .frame(width: 48, height: 46)
            .compositingGroup()
            .shadow(color: accent.opacity(0.55), radius: 14, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(!vm.isStreaming && vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(
            (!vm.isStreaming && vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ? 0.55 : 1.0
        )
    }
}
