import Foundation

/// Errores de la app con un mensaje pensado para ser leído en voz alta.
enum JarvisError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case apiError(String)
    case networkError
    case tooManyToolIterations
    case speechUnavailable
    case permissionsDenied

    var errorDescription: String? { spokenMessage }

    var spokenMessage: String {
        switch self {
        case .missingAPIKey:
            return "Necesito una clave de API de Anthropic, señor. Puede configurarla en los ajustes."
        case .invalidAPIKey:
            return "Me temo que la clave de API no es válida, señor."
        case .rateLimited:
            return "Estamos enviando demasiadas peticiones, señor. Le sugiero esperar un momento."
        case .apiError(let message):
            return "Ha ocurrido un problema con el servicio: \(message)"
        case .networkError:
            return "No consigo conectar con mis servidores, señor. Compruebe la conexión."
        case .tooManyToolIterations:
            return "La operación se ha complicado más de lo previsto, señor. He preferido detenerme."
        case .speechUnavailable:
            return "El reconocimiento de voz no está disponible en este momento, señor."
        case .permissionsDenied:
            return "Necesito permiso para usar el micrófono y el reconocimiento de voz. Puede concederlo en Ajustes."
        }
    }
}
