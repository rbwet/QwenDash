import SwiftUI

/// Scrolling message list. Apple-native bubble styling: user bubbles filled
/// with the accent colour (think Messages), assistant bubbles in a neutral
/// material so the content reads cleanly against the window background.
struct ChatView: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if vm.messages.isEmpty {
                        emptyState
                            .padding(.top, 48)
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

                    Color.clear.frame(height: 4).id("BOTTOM")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No messages yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Ask the model anything. Watch it think.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 60) }
            if !isUser { avatar }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isUser ? "You" : "Qwen")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isUser ? Color.white.opacity(0.85) : .secondary)
                    if message.isStreaming {
                        StreamingDots()
                    }
                }
                Text(message.content + (message.isStreaming ? "▍" : ""))
                    .font(.system(size: 13))
                    .foregroundStyle(isUser ? Color.white : Color.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isUser
                          ? AnyShapeStyle(Theme.accent)
                          : AnyShapeStyle(.regularMaterial))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isUser ? Color.clear : Theme.hairline,
                        lineWidth: 0.5
                    )
            }

            if isUser { avatar }
            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(isUser ? Theme.accent.opacity(0.18) : Color.white.opacity(0.08))
            Image(systemName: isUser ? "person.fill" : "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isUser ? Theme.accent : .secondary)
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Streaming indicator

private struct StreamingDots: View {
    @State private var phase: Double = 0
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 3, height: 3)
                    .opacity(dotAlpha(i))
            }
        }
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

// MARK: - Error row

private struct ErrorRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.signalWarn)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.signalWarn.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.signalWarn.opacity(0.35), lineWidth: 0.5)
        }
    }
}
