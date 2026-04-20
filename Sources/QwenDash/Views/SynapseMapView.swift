import SwiftUI

/// The neural-activity map. Renders hidden cluster + input/output columns with
/// pulses traveling along edges. Drives `graph.tick(dt:)` every frame via
/// `TimelineView(.animation)`.
struct SynapseMapView: View {
    @ObservedObject var vm: ChatViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { ctx, size in
                let time = context.date.timeIntervalSinceReferenceDate
                drawBackdrop(ctx: ctx, size: size, time: time)
                drawEdges(ctx: ctx, size: size, time: time)
                drawPulses(ctx: ctx, size: size)
                drawNodes(ctx: ctx, size: size, time: time)
                drawColumnLabels(ctx: ctx, size: size)
            }
        }
        .task {
            // Drive graph mutation (pulse progress, activation decay) at ~60fps.
            // TimelineView already repaints — this just advances the model state.
            // `.task` already runs on the MainActor, so mutating vm.graph is safe.
            let frame: UInt64 = 16_000_000 // ~60 fps
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: frame)
                vm.graph.tick(dt: 1.0 / 60.0)
            }
        }
        .background(
            // Deep space gradient sits behind the canvas for that nightside-LA feel.
            ZStack {
                RadialGradient(
                    colors: [
                        Theme.neonViolet.opacity(0.16),
                        Theme.background.opacity(0.0)
                    ],
                    center: .center, startRadius: 40, endRadius: 480
                )
                RadialGradient(
                    colors: [
                        Theme.neonCyan.opacity(0.10),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.1, y: 0.85), startRadius: 20, endRadius: 320
                )
                RadialGradient(
                    colors: [
                        Theme.neonMagenta.opacity(0.10),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.92, y: 0.15), startRadius: 20, endRadius: 320
                )
            }
        )
    }

    // MARK: - Background grid + scanlines

    private func drawBackdrop(ctx: GraphicsContext, size: CGSize, time: TimeInterval) {
        // Subtle perspective grid.
        var gridPath = Path()
        let cols = 18
        let rows = 10
        for c in 0...cols {
            let x = CGFloat(c) / CGFloat(cols) * size.width
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.addLine(to: CGPoint(x: x, y: size.height))
        }
        for r in 0...rows {
            let y = CGFloat(r) / CGFloat(rows) * size.height
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(gridPath, with: .color(Color.white.opacity(0.025)), lineWidth: 0.5)

        // Slow horizontal scanline.
        let scan = (sin(time * 0.4) + 1) * 0.5 // 0...1
        let scanY = CGFloat(scan) * size.height
        let scanRect = CGRect(x: 0, y: scanY - 1, width: size.width, height: 2)
        ctx.fill(Path(scanRect), with: .linearGradient(
            Gradient(colors: [
                Color.clear,
                Theme.neonCyan.opacity(0.18),
                Color.clear
            ]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: 0)
        ))
    }

    private func drawColumnLabels(ctx: GraphicsContext, size: CGSize) {
        let inText = Text("◀ INPUT TOKENS")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Theme.neonCyan.opacity(0.6))
        let hiText = Text("◆ HIDDEN ACTIVATION")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Theme.neonViolet.opacity(0.6))
        let outText = Text("OUTPUT STREAM ▶")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Theme.neonMagenta.opacity(0.6))

        ctx.draw(inText,  at: CGPoint(x: size.width * 0.08, y: 14), anchor: .center)
        ctx.draw(hiText,  at: CGPoint(x: size.width * 0.50, y: 14), anchor: .center)
        ctx.draw(outText, at: CGPoint(x: size.width * 0.92, y: 14), anchor: .center)
    }

    // MARK: - Edges

    private func drawEdges(ctx: GraphicsContext, size: CGSize, time: TimeInterval) {
        let nodes = vm.graph.nodes
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        for edge in vm.graph.edges {
            guard let a = nodeMap[edge.from], let b = nodeMap[edge.to] else { continue }
            let p1 = a.position.scaled(to: size)
            let p2 = b.position.scaled(to: size)
            let path = curve(from: p1, to: p2)

            // Base dim line.
            ctx.stroke(
                path,
                with: .color(Color.white.opacity(0.06 + 0.10 * edge.weight)),
                lineWidth: 0.6
            )
        }
    }

    // MARK: - Pulses

    private func drawPulses(ctx: GraphicsContext, size: CGSize) {
        let nodes = vm.graph.nodes
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let edgeMap = Dictionary(uniqueKeysWithValues: vm.graph.edges.map { ($0.id, $0) })

        for pulse in vm.graph.pulses {
            guard let edge = edgeMap[pulse.edgeID],
                  let a = nodeMap[edge.from],
                  let b = nodeMap[edge.to] else { continue }
            let p1 = a.position.scaled(to: size)
            let p2 = b.position.scaled(to: size)

            let t = max(0.0, min(1.0, pulse.progress))
            let pos = bezierPoint(t: t, p1: p1, p2: p2)

            // Trailing comet — three blurred dots descending in size/alpha.
            for i in 0..<3 {
                let offsetT = max(0.0, t - Double(i) * 0.06)
                let trailPos = bezierPoint(t: offsetT, p1: p1, p2: p2)
                let alpha = pulse.intensity * (1.0 - Double(i) * 0.30)
                let radius = 2.5 - Double(i) * 0.6
                let rect = CGRect(
                    x: trailPos.x - radius,
                    y: trailPos.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                ctx.fill(Path(ellipseIn: rect),
                         with: .color(pulse.color.opacity(alpha)))
            }

            // Bright head with halo.
            let head = CGRect(x: pos.x - 2.5, y: pos.y - 2.5, width: 5, height: 5)
            ctx.fill(Path(ellipseIn: head), with: .color(pulse.color))

            // Soft halo.
            let halo = CGRect(x: pos.x - 6, y: pos.y - 6, width: 12, height: 12)
            ctx.fill(Path(ellipseIn: halo),
                     with: .radialGradient(
                        Gradient(colors: [pulse.color.opacity(pulse.intensity * 0.55), .clear]),
                        center: pos, startRadius: 0, endRadius: 6
                     ))
        }
    }

    // MARK: - Nodes

    private func drawNodes(ctx: GraphicsContext, size: CGSize, time: TimeInterval) {
        for node in vm.graph.nodes {
            let p = node.position.scaled(to: size)

            // Subtle drift for hidden nodes only.
            let drift: CGSize = {
                guard node.region == .hidden else { return .zero }
                let dx = sin(time * 0.6 + node.phase) * 1.2
                let dy = cos(time * 0.5 + node.phase * 1.3) * 1.2
                return CGSize(width: dx, height: dy)
            }()
            let center = CGPoint(x: p.x + drift.width, y: p.y + drift.height)

            let baseRadius: CGFloat = node.region == .hidden ? 3.0 : 5.0
            let activation = node.activation
            let pulseR = baseRadius + CGFloat(activation) * 4.5

            // Outer halo (bigger when activated)
            let haloR = pulseR + 14 + CGFloat(activation) * 8
            let haloRect = CGRect(
                x: center.x - haloR, y: center.y - haloR,
                width: haloR * 2, height: haloR * 2
            )
            ctx.fill(Path(ellipseIn: haloRect),
                     with: .radialGradient(
                        Gradient(colors: [
                            node.color.opacity(0.05 + activation * 0.45),
                            .clear
                        ]),
                        center: center, startRadius: 0, endRadius: haloR
                     ))

            // Ring.
            let ringRect = CGRect(
                x: center.x - pulseR, y: center.y - pulseR,
                width: pulseR * 2, height: pulseR * 2
            )
            ctx.stroke(Path(ellipseIn: ringRect),
                       with: .color(node.color.opacity(0.45 + activation * 0.55)),
                       lineWidth: 1.0)

            // Core dot.
            let coreR: CGFloat = max(1.2, pulseR - 1.6)
            let coreRect = CGRect(
                x: center.x - coreR, y: center.y - coreR,
                width: coreR * 2, height: coreR * 2
            )
            ctx.fill(Path(ellipseIn: coreRect),
                     with: .color(node.color.opacity(0.85)))

            // Optional label for input/output.
            if !node.label.isEmpty {
                let label = Text(node.label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(node.color.opacity(0.85))
                let yOffset: CGFloat = node.region == .input ? 0 : 0
                let xOffset: CGFloat = node.region == .input ? -28 : 28
                ctx.draw(label,
                         at: CGPoint(x: center.x + xOffset, y: center.y + yOffset),
                         anchor: .center)
            }
        }
    }

    // MARK: - Curves

    private func curve(from p1: CGPoint, to p2: CGPoint) -> Path {
        var path = Path()
        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        // Sag the bezier slightly so lines feel organic, not architectural.
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let len = sqrt(dx * dx + dy * dy)
        let nx = -dy / max(len, 1)
        let ny =  dx / max(len, 1)
        let bend = max(15, len * 0.12)
        let c = CGPoint(x: mid.x + nx * bend * 0.4, y: mid.y + ny * bend * 0.4)
        path.move(to: p1)
        path.addQuadCurve(to: p2, control: c)
        return path
    }

    private func bezierPoint(t: Double, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let len = sqrt(dx * dx + dy * dy)
        let nx = -dy / max(len, 1)
        let ny =  dx / max(len, 1)
        let bend = max(15, len * 0.12)
        let c = CGPoint(x: mid.x + nx * bend * 0.4, y: mid.y + ny * bend * 0.4)

        let u = 1.0 - t
        let x = u * u * Double(p1.x) + 2 * u * t * Double(c.x) + t * t * Double(p2.x)
        let y = u * u * Double(p1.y) + 2 * u * t * Double(c.y) + t * t * Double(p2.y)
        return CGPoint(x: x, y: y)
    }
}

private extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}
