import SwiftUI

/// Scrolling message list.
struct ChatView: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if vm.messages.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    }
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }

                    if let err = vm.lastError {
                        ErrorRow(text: err)
                            .transition(.opacity)
                    }

                    Color.clear.frame(height: 8).id("BOTTOM")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .onChange(of: vm.messages.last?.content) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.neonCyan, Theme.neonMagenta],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Theme.neonCyan.opacity(0.5), radius: 12)
            Text("AWAITING INPUT")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(Theme.textSecondary)
            Text("ask the model anything. watch it think.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var tint: Color {
        isUser ? Theme.neonCyan : Theme.neonMagenta
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 60) }

            if !isUser { avatar }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isUser ? "YOU" : "QWEN")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(tint.opacity(0.8))
                    if message.isStreaming {
                        StreamingDots()
                    }
                }
                Text(message.content + (message.isStreaming ? "▍" : ""))
                    .font(.system(size: 13, design: .default))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tint.opacity(0.06))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 0.7)
            }
            .shadow(color: tint.opacity(0.15), radius: 10, x: 0, y: 4)

            if isUser { avatar }
            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(tint.opacity(0.15))
            Circle().strokeBorder(tint.opacity(0.7), lineWidth: 0.7)
            Image(systemName: isUser ? "person.fill" : "bolt.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: 26, height: 26)
        .shadow(color: tint.opacity(0.6), radius: 6)
    }
}

private struct StreamingDots: View {
    @State private var phase: Double = 0
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.neonMagenta)
                    .frame(width: 4, height: 4)
                    .opacity(dotAlpha(i))
            }
        }
        .shadow(color: Theme.neonMagenta.opacity(0.7), radius: 4)
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
    private func dotAlpha(_ i: Int) -> Double {
        let base = (phase + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
        return 0.3 + 0.7 * abs(sin(base * .pi))
    }
}

private struct ErrorRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.neonAmber)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.neonAmber.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.neonAmber.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.neonAmber.opacity(0.5), lineWidth: 0.6)
        }
    }
}
