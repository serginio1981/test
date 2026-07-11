import Foundation

/// Estados por los que pasa el asistente. La UI (reactor, waveform, caption)
/// se dibuja en función del estado actual.
enum AssistantState: Equatable {
    case idle                  // micrófono apagado (permiso denegado o app en segundo plano)
    case listeningForWakeWord  // escucha continua esperando "Jarvis"
    case listeningForCommand   // wake word detectado (o pulsar-para-hablar): transcribiendo la orden
    case thinking              // esperando respuesta de Claude (incluye bucle de herramientas)
    case speaking              // leyendo la respuesta en voz alta
    case error(String)

    /// Texto de estado que se muestra bajo el reactor.
    var caption: String {
        switch self {
        case .idle:
            return "En reposo. Toca el reactor para activarme."
        case .listeningForWakeWord:
            return "A la espera, señor. Diga «Jarvis» o toque el reactor."
        case .listeningForCommand:
            return "Le escucho, señor…"
        case .thinking:
            return "Procesando…"
        case .speaking:
            return ""
        case .error(let message):
            return message
        }
    }

    var isListening: Bool {
        self == .listeningForWakeWord || self == .listeningForCommand
    }
}
