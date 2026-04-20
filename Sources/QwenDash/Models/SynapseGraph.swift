import Foundation
import SwiftUI

/// A graph of glowing nodes + pulses used to visualise a query flowing
/// through the model. Three regions: input tokens on the left, a cluster of
/// "hidden" thinking nodes in the middle, output tokens stream in on the right.
struct SynapseGraph {

    // MARK: - Node / Edge / Pulse

    enum Region { case input, hidden, output }

    struct Node: Identifiable {
        let id = UUID()
        var region: Region
        /// Position in unit space (0...1 x 0...1). View maps to pixels.
        var position: CGPoint
        var label: String
        var color: Color
        /// Current activation 0...1 — drives glow intensity. Decays over time.
        var activation: Double = 0
        /// Jitter frequency for subtle drift.
        var phase: Double = .random(in: 0..<(2 * .pi))
    }

    struct Edge: Identifiable {
        let id = UUID()
        let from: UUID
        let to: UUID
        /// Visual weight 0...1.
        var weight: Double
    }

    /// A traveling pulse along an edge. `progress` goes 0 → 1 then is removed.
    struct Pulse: Identifiable {
        let id = UUID()
        let edgeID: UUID
        var progress: Double = 0
        var speed: Double
        var color: Color
        var intensity: Double
    }

    // MARK: - State

    private(set) var nodes: [Node] = []
    private(set) var edges: [Edge] = []
    private(set) var pulses: [Pulse] = []

    private var hiddenNodeIDs: [UUID] = []
    private var outputNodeIDs: [UUID] = []   // appended as tokens stream in

    /// Incremented whenever observers need to redraw off-thread state updates.
    private(set) var version: Int = 0

    // MARK: - Construction

    init() { seedHiddenCluster() }

    private mutating func seedHiddenCluster() {
        nodes.removeAll()
        edges.removeAll()
        pulses.removeAll()
        hiddenNodeIDs.removeAll()
        outputNodeIDs.removeAll()

        // Build an organically-scattered cluster in the middle column.
        // Deterministic-ish positions using a sunflower-like distribution.
        let count = 28
        let centerX: Double = 0.50
        let centerY: Double = 0.50
        let rX: Double = 0.17
        let rY: Double = 0.36

        for i in 0..<count {
            let t = Double(i) / Double(count)
            let angle = Double(i) * 2.399963229728653 // golden angle
            let radiusFactor = sqrt(t)
            let x = centerX + cos(angle) * rX * radiusFactor + .random(in: -0.01...0.01)
            let y = centerY + sin(angle) * rY * radiusFactor + .random(in: -0.01...0.01)

            let tint: Color = {
                switch i % 3 {
                case 0: return Theme.neonCyan
                case 1: return Theme.neonViolet
                default: return Theme.neonMagenta
                }
            }()
            let n = Node(region: .hidden, position: CGPoint(x: x, y: y), label: "", color: tint)
            nodes.append(n)
            hiddenNodeIDs.append(n.id)
        }

        // Wire a sparse hidden-to-hidden mesh so the cluster feels connected.
        for (i, fromID) in hiddenNodeIDs.enumerated() {
            let picks = (1...2).map { _ in Int.random(in: 0..<hiddenNodeIDs.count) }
            for j in picks where j != i {
                let toID = hiddenNodeIDs[j]
                if edges.contains(where: { $0.from == fromID && $0.to == toID }) { continue }
                edges.append(Edge(from: fromID, to: toID, weight: .random(in: 0.15...0.55)))
            }
        }
    }

    // MARK: - Input tokens

    /// Tokenise the query (crude whitespace split, max 12 nodes) and wire them
    /// to random hidden nodes. Fires a pulse for each wire.
    mutating func ingestUserQuery(_ text: String) {
        // Clear old input nodes and their edges/pulses.
        let inputIDs = nodes.filter { $0.region == .input }.map(\.id)
        nodes.removeAll { $0.region == .input }
        edges.removeAll { inputIDs.contains($0.from) || inputIDs.contains($0.to) }
        pulses.removeAll { edge in
            guard let e = edges.first(where: { $0.id == edge.edgeID }) else { return true }
            return inputIDs.contains(e.from) || inputIDs.contains(e.to)
        }

        let raw = text
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
        let tokens = Array(raw.prefix(12))
        guard !tokens.isEmpty else { return }

        let n = tokens.count
        let topY: Double = 0.18
        let botY: Double = 0.86
        let xCol: Double = 0.08

        var newInputIDs: [UUID] = []
        for (i, tok) in tokens.enumerated() {
            let y = n == 1 ? 0.5 : topY + (botY - topY) * Double(i) / Double(n - 1)
            let node = Node(
                region: .input,
                position: CGPoint(x: xCol, y: y),
                label: String(tok.prefix(12)),
                color: Theme.neonCyan
            )
            nodes.append(node)
            newInputIDs.append(node.id)
        }

        // Connect each input to 3–5 random hidden nodes, fire pulses.
        for inID in newInputIDs {
            let degree = Int.random(in: 3...5)
            let targets = hiddenNodeIDs.shuffled().prefix(degree)
            for t in targets {
                let edge = Edge(from: inID, to: t, weight: .random(in: 0.4...0.9))
                edges.append(edge)
                pulses.append(Pulse(
                    edgeID: edge.id,
                    progress: 0,
                    speed: .random(in: 0.6...1.1),
                    color: Theme.neonCyan,
                    intensity: .random(in: 0.7...1.0)
                ))
            }
            activate(nodeID: inID, to: 1.0)
        }

        // Cross-chatter inside the hidden cluster to feel like it's "thinking".
        for _ in 0..<24 {
            let a = hiddenNodeIDs.randomElement()!
            let b = hiddenNodeIDs.randomElement()!
            guard a != b else { continue }
            if let edge = edges.first(where: {
                ($0.from == a && $0.to == b) || ($0.from == b && $0.to == a)
            }) {
                pulses.append(Pulse(
                    edgeID: edge.id,
                    progress: .random(in: 0...0.3),
                    speed: .random(in: 0.4...0.9),
                    color: [Theme.neonCyan, Theme.neonViolet, Theme.neonMagenta].randomElement()!,
                    intensity: .random(in: 0.4...0.8)
                ))
            }
        }

        version &+= 1
    }

    // MARK: - Output tokens

    /// As each streaming delta arrives, drop a new output node and fire a pulse
    /// from a random hidden node to it.
    mutating func ingestAssistantToken(_ delta: String) {
        // Cap output column so it never overflows visually.
        let maxOutputs = 16
        if outputNodeIDs.count >= maxOutputs {
            // Keep a rolling window — drop the oldest.
            if let oldestID = outputNodeIDs.first {
                nodes.removeAll { $0.id == oldestID }
                edges.removeAll { $0.to == oldestID || $0.from == oldestID }
                pulses.removeAll { edge in
                    !edges.contains(where: { $0.id == edge.edgeID })
                }
                outputNodeIDs.removeFirst()
            }
        }

        let count = outputNodeIDs.count + 1
        let topY: Double = 0.18
        let botY: Double = 0.86
        let xCol: Double = 0.92

        // Re-space existing output nodes as we grow the column.
        for (idx, id) in outputNodeIDs.enumerated() {
            if let i = nodes.firstIndex(where: { $0.id == id }) {
                let y = count == 1 ? 0.5 : topY + (botY - topY) * Double(idx) / Double(count - 1)
                nodes[i].position.y = y
            }
        }
        let newY = count == 1 ? 0.5 : topY + (botY - topY) * Double(count - 1) / Double(count - 1)

        let label = delta
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "⏎")
        let node = Node(
            region: .output,
            position: CGPoint(x: xCol, y: newY),
            label: String(label.prefix(10)),
            color: Theme.neonMagenta
        )
        nodes.append(node)
        outputNodeIDs.append(node.id)

        // Fire 2–3 pulses from random hidden nodes to this new output.
        let incoming = Int.random(in: 2...3)
        for _ in 0..<incoming {
            guard let from = hiddenNodeIDs.randomElement() else { break }
            let edge = Edge(from: from, to: node.id, weight: .random(in: 0.5...0.95))
            edges.append(edge)
            pulses.append(Pulse(
                edgeID: edge.id,
                progress: 0,
                speed: .random(in: 0.8...1.4),
                color: Theme.neonMagenta,
                intensity: .random(in: 0.8...1.0)
            ))
            if let i = nodes.firstIndex(where: { $0.id == from }) {
                nodes[i].activation = max(nodes[i].activation, 0.9)
            }
        }
        activate(nodeID: node.id, to: 1.0)

        // Additional hidden chatter per token.
        for _ in 0..<4 {
            let a = hiddenNodeIDs.randomElement()!
            let b = hiddenNodeIDs.randomElement()!
            guard a != b,
                  let edge = edges.first(where: {
                      ($0.from == a && $0.to == b) || ($0.from == b && $0.to == a)
                  })
            else { continue }
            pulses.append(Pulse(
                edgeID: edge.id,
                progress: .random(in: 0...0.2),
                speed: .random(in: 0.5...1.0),
                color: [Theme.neonCyan, Theme.neonViolet, Theme.neonMagenta].randomElement()!,
                intensity: .random(in: 0.35...0.75)
            ))
        }

        version &+= 1
    }

    /// Signal the final token has arrived. Caller can use this to dampen things.
    mutating func finishThinking() {
        // Gentle tail-off: halve remaining pulse intensity.
        for i in pulses.indices { pulses[i].intensity *= 0.7 }
        version &+= 1
    }

    // MARK: - Animation tick

    /// Advances pulses and decays node activations by `dt` seconds.
    mutating func tick(dt: Double) {
        // Decay node activations.
        for i in nodes.indices {
            nodes[i].activation = max(0, nodes[i].activation - dt * 0.8)
        }

        // Advance pulses and activate their target node on arrival.
        var finished: [Int] = []
        for i in pulses.indices {
            pulses[i].progress += pulses[i].speed * dt
            if pulses[i].progress >= 1 {
                if let edge = edges.first(where: { $0.id == pulses[i].edgeID }),
                   let ni = nodes.firstIndex(where: { $0.id == edge.to }) {
                    nodes[ni].activation = max(nodes[ni].activation, pulses[i].intensity * 0.9)
                }
                finished.append(i)
            }
        }
        for i in finished.reversed() { pulses.remove(at: i) }
    }

    mutating func clear() {
        seedHiddenCluster()
        version &+= 1
    }

    // MARK: - Helpers

    private mutating func activate(nodeID: UUID, to value: Double) {
        if let i = nodes.firstIndex(where: { $0.id == nodeID }) {
            nodes[i].activation = max(nodes[i].activation, value)
        }
    }

    func node(_ id: UUID) -> Node? { nodes.first { $0.id == id } }
}
