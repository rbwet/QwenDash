import Foundation
import SwiftUI
import Combine

/// Central state for chat, streaming, and the synapse animation.
/// Published fields drive SwiftUI updates.
@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Public state

    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""

    @Published var isStreaming: Bool = false
    @Published var lastError: String?

    // Connection + model
    @Published var connected: Bool = false
    @Published var modelId: String = "—"
    @Published var latencyMS: Int?

    // Streaming stats
    @Published var tokensThisTurn: Int = 0
    @Published var tokensPerSecond: Double = 0

    /// Rolling average of per-token probabilities reported by the backend
    /// (when logprobs are available). 0...1; nil when the backend doesn't
    /// provide any confidence data for this turn.
    @Published var avgConfidence: Double? = nil

    /// Top-k alternative tokens at the most recent step, with probabilities.
    /// Not rendered yet but exposed for future visualisations.
    @Published var lastAlternatives: [(token: String, probability: Double)] = []

    private var confidenceSamples: [Double] = []

    // Synapse graph state (driven by tokenization + streaming).
    // Intentionally NOT @Published: SynapseMapView reads it from inside a
    // TimelineView(.animation) that already redraws every frame, so marking
    // it @Published would pointlessly invalidate the whole view hierarchy at
    // 60fps. Mutations are still safe because all access goes through
    // MainActor-isolated methods on this view-model.
    var graph = SynapseGraph()

    // MARK: - Internals

    private let client = LMStudioClient()
    private var streamTask: Task<Void, Never>?
    private var streamStart: Date = .distantPast
    private var pingTimer: Timer?

    init() {
        Task { [weak self] in await self?.refreshConnection() }
        // Periodic ping (every 5s) to keep the connection indicator honest.
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refreshConnection() }
        }
    }

    deinit {
        pingTimer?.invalidate()
    }

    // MARK: - Connection

    func refreshConnection() async {
        let t0 = Date()
        let id = await client.fetchFirstModelId()
        let dt = Int(Date().timeIntervalSince(t0) * 1000)
        if let id = id {
            self.connected = true
            self.modelId = id
            self.latencyMS = dt
            await client.updateConfig { $0.model = id }
        } else {
            self.connected = false
            self.latencyMS = nil
        }
    }

    // MARK: - Sending

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        input = ""
        lastError = nil

        // Seed graph with input-token nodes and fire initial pulses.
        graph.ingestUserQuery(text)

        // Prepare assistant message to stream into.
        var assistant = ChatMessage(role: .assistant, content: "")
        assistant.isStreaming = true
        messages.append(assistant)
        let assistantID = assistant.id

        isStreaming = true
        tokensThisTurn = 0
        tokensPerSecond = 0
        avgConfidence = nil
        lastAlternatives = []
        confidenceSamples.removeAll()
        streamStart = Date()

        streamTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let msgs = self.messages.filter { $0.role != .assistant || $0.id != assistantID }
                let stream = await self.client.streamChat(messages: msgs)
                for try await delta in stream {
                    if Task.isCancelled { break }
                    self.applyDelta(delta, to: assistantID)
                }
                self.finishStreaming(id: assistantID)
            } catch {
                self.lastError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                self.finishStreaming(id: assistantID, failed: true)
            }
        }
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
    }

    // MARK: - Private

    private func applyDelta(_ delta: TokenDelta, to id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].content += delta.content

        // Update stats
        tokensThisTurn += estimateTokens(in: delta.content)
        let elapsed = max(Date().timeIntervalSince(streamStart), 0.001)
        tokensPerSecond = Double(tokensThisTurn) / elapsed

        if let p = delta.confidence {
            confidenceSamples.append(p)
            // Keep the rolling window bounded so older tokens don't dominate
            // once a long generation has been running.
            if confidenceSamples.count > 128 {
                confidenceSamples.removeFirst(confidenceSamples.count - 128)
            }
            avgConfidence = confidenceSamples.reduce(0, +) / Double(confidenceSamples.count)
        }
        if !delta.alternatives.isEmpty {
            lastAlternatives = delta.alternatives
        }

        // Feed the graph: fire a pulse from the hidden cluster to a new output
        // node. When the backend supplied logprobs, the node's glow + pulse
        // intensity track the model's confidence for that token.
        graph.ingestAssistantToken(delta.content, confidence: delta.confidence)
    }

    private func finishStreaming(id: UUID, failed: Bool = false) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isStreaming = false
            if failed && messages[idx].content.isEmpty {
                messages.remove(at: idx)
            }
        }
        isStreaming = false
        graph.finishThinking()
    }

    /// Rough token count — good enough for tokens/sec display.
    private func estimateTokens(in text: String) -> Int {
        // ~4 chars ≈ 1 token for English/code. Floor of 1 per non-empty delta.
        guard !text.isEmpty else { return 0 }
        return max(1, text.count / 4)
    }
}
