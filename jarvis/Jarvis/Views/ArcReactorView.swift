import SwiftUI

/// Reactor arc dibujado íntegramente con Canvas (sin assets):
/// anillo exterior segmentado que rota, anillo de resplandor y núcleo con
/// pulso. El color y la velocidad dependen del estado; el pulso se amplifica
/// con el nivel de audio mientras escucha.
struct ArcReactorView: View {
    let state: AssistantState
    let audioLevel: Float

    private var rotationSpeed: Double {
        state == .thinking ? 1.6 : 0.4 // vueltas por segundo aprox. (rad/s abajo)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                let color = Theme.reactorColor(for: state)

                // Pulso: respiración lenta + empuje del nivel de audio.
                let breathing = 0.05 * sin(time * 2 * .pi * 0.6)
                let audioBoost = state.isListening ? CGFloat(audioLevel) * 0.25 : 0
                let pulse = 1 + breathing + audioBoost

                drawOuterRing(in: &context, center: center, radius: radius * 0.95, color: color, time: time)
                drawGlowRing(in: &context, center: center, radius: radius * 0.62 * pulse, color: color)
                drawCore(in: &context, center: center, radius: radius * 0.30 * pulse, color: color)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func drawOuterRing(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        time: TimeInterval
    ) {
        let segments = 10
        let gapRatio = 0.28
        let segmentAngle = (2 * Double.pi) / Double(segments)
        let arcAngle = segmentAngle * (1 - gapRatio)
        let rotation = time * rotationSpeed * 2 * .pi / 4

        for index in 0..<segments {
            let start = Angle(radians: Double(index) * segmentAngle + rotation)
            let end = Angle(radians: Double(index) * segmentAngle + arcAngle + rotation)
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }

        // Anillo fino interior fijo.
        var innerRing = Path()
        innerRing.addEllipse(in: CGRect(
            x: center.x - radius * 0.82,
            y: center.y - radius * 0.82,
            width: radius * 1.64,
            height: radius * 1.64
        ))
        context.stroke(innerRing, with: .color(color.opacity(0.5)), lineWidth: 1.5)
    }

    private func drawGlowRing(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        var glowContext = context
        glowContext.addFilter(.blur(radius: 10))
        glowContext.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [color.opacity(0.55), color.opacity(0.0)]),
                center: center,
                startRadius: radius * 0.3,
                endRadius: radius
            )
        )
    }

    private func drawCore(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [.white, color, color.opacity(0.15)]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }
}

#Preview {
    ArcReactorView(state: .listeningForWakeWord, audioLevel: 0.4)
        .frame(width: 260, height: 260)
        .padding()
        .background(Theme.background)
}
