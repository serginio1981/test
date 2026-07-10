import SwiftUI

/// Paleta y estilos del HUD estilo Iron Man.
enum Theme {
    static let background = Color(red: 0.02, green: 0.04, blue: 0.08)      // #050A14
    static let arcBlue = Color(red: 0.31, green: 0.76, blue: 0.97)         // #4FC3F7
    static let gold = Color(red: 1.0, green: 0.79, blue: 0.30)             // #FFC94D
    static let textPrimary = Color(red: 0.84, green: 0.94, blue: 1.0)      // #D6EFFF
    static let textSecondary = Color(red: 0.84, green: 0.94, blue: 1.0).opacity(0.55)

    /// Color principal del reactor según el estado del asistente.
    static func reactorColor(for state: AssistantState) -> Color {
        switch state {
        case .idle: return arcBlue.opacity(0.35)
        case .listeningForWakeWord: return arcBlue
        case .listeningForCommand: return arcBlue
        case .thinking: return gold
        case .speaking: return Color(red: 0.75, green: 0.95, blue: 1.0)
        case .error: return Color(red: 1.0, green: 0.45, blue: 0.35)
        }
    }

    static func hudFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Resplandor doble típico de los HUD.
struct GlowModifier: ViewModifier {
    let color: Color
    var radius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius / 2)
            .shadow(color: color.opacity(0.4), radius: radius)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 8) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}
