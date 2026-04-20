import SwiftUI

/// Bottom input row: text field + send/stop button.
/// Cmd+Return sends; plain Return inserts a newline.
struct InputBar: View {
    @ObservedObject var vm: ChatViewModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            editorField
            micButton
            sendButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Microphone

    @ViewBuilder
    private var micButton: some View {
        let state = vm.voiceState
        let (fill, glyph, active): (Color, String, Bool) = {
            switch state {
            case .idle:
                return (Color.white.opacity(0.10), "mic.fill", false)
            case .loadingModel:
                return (Color.white.opacity(0.10), "mic.fill", false)
            case .recording:
                return (Theme.signalWarn, "mic.fill", true)
            case .transcribing:
                return (Theme.accent.opacity(0.6), "waveform", true)
            case .speaking:
                return (Theme.accent, "speaker.wave.2.fill", true)
            }
        }()

        Button {
            vm.toggleVoice()
        } label: {
            ZStack {
                Circle().fill(fill)
                Image(systemName: glyph)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? Color.white : Color.primary.opacity(0.7))
            }
            .frame(width: 30, height: 30)
            .scaleEffect(state == .recording ? 1.0 + sin(Date().timeIntervalSinceReferenceDate * 6) * 0.04 : 1.0)
        }
        .buttonStyle(.plain)
        .help(micTooltip(for: state))
        .animation(.easeOut(duration: 0.15), value: state)
    }

    private func micTooltip(for state: VoiceSession.State) -> String {
        switch state {
        case .idle:          return "Start voice input (⌥-Space)"
        case .loadingModel:  return "Loading speech model…"
        case .recording:     return "Stop and send (⌥-Space)"
        case .transcribing:  return "Transcribing…"
        case .speaking:      return "Tap to stop speaking"
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorField: some View {
        ZStack(alignment: .topLeading) {
            if vm.input.isEmpty {
                Text("Ask anything…  ⌘⏎ to send · ⏎ for newline")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $vm.input)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundStyle(.primary)
                .tint(Theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .focused($focused)
                .onAppear { focused = true }
        }
        .frame(minHeight: 40, maxHeight: 110)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.25))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    focused ? Theme.accent.opacity(0.75) : Theme.hairline,
                    lineWidth: focused ? 1.0 : 0.5
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - Send button

    @ViewBuilder
    private var sendButton: some View {
        let disabled = !vm.isStreaming && vm.input
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        Button {
            if vm.isStreaming {
                vm.cancelStreaming()
            } else {
                vm.send()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        vm.isStreaming
                            ? Theme.signalWarn
                            : (disabled ? Color.white.opacity(0.10) : Theme.accent)
                    )
                Image(systemName: vm.isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        vm.isStreaming || !disabled
                            ? Color.white
                            : Color.primary.opacity(0.4)
                    )
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(disabled)
        .animation(.easeOut(duration: 0.12), value: disabled)
        .animation(.easeOut(duration: 0.12), value: vm.isStreaming)
    }
}
