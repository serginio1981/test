import Foundation

/// Un turno de la conversación visible en el historial.
struct ChatMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
    let date: Date

    init(role: Role, text: String, date: Date = .now) {
        self.role = role
        self.text = text
        self.date = date
    }
}
