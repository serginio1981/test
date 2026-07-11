import SwiftUI

/// Barras de onda en la base del HUD. Mientras escucha reaccionan al nivel
/// del micrófono; mientras habla se anima una onda sintética; en reposo
/// quedan casi planas.
struct WaveformView: View {
    let state: AssistantState
    let audioLevel: Float

    private static let barCount = 24

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<Self.barCount, id: \.self) { index in
                    Capsule()
                        .fill(Theme.reactorColor(for: state))
                        .frame(width: 4, height: barHeight(index: index, time: time))
                }
            }
        }
        .frame(height: 44)
        .animation(.linear(duration: 0.1), value: audioLevel)
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = Double(index) / Double(Self.barCount) * 2 * .pi
        let base: CGFloat = 5

        switch state {
        case .listeningForCommand, .listeningForWakeWord:
            let wobble = 0.5 + 0.5 * sin(time * 9 + phase * 3)
            return base + CGFloat(audioLevel) * 36 * wobble
        case .speaking:
            let wave = 0.5 + 0.5 * sin(time * 7 + phase * 2)
            return base + 26 * wave
        case .thinking:
            let sweep = 0.5 + 0.5 * sin(time * 3 - phase)
            return base + 10 * sweep
        case .idle, .error:
            return base
        }
    }
}

#Preview {
    WaveformView(state: .speaking, audioLevel: 0.5)
        .padding()
        .background(Theme.background)
}
