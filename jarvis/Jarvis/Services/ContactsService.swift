import Contacts
import Foundation

/// Resultado de buscar un contacto por nombre.
enum ContactMatch {
    case unique(name: String, phone: String?, email: String?)
    case ambiguous([String]) // nombres candidatos, para que Claude repregunte
    case none
}

/// Búsqueda difusa en la agenda del usuario (nombre, apellidos, apodo).
final class ContactsService {
    private let store = CNContactStore()

    func findContact(named query: String) async throws -> ContactMatch {
        try await requestAccess()

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var scored: [(score: Int, name: String, phone: String?, email: String?)] = []
        let normalizedQuery = Self.normalize(query)
        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)

        try store.enumerateContacts(with: request) { contact, _ in
            let fullName = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let candidates = [fullName, contact.givenName, contact.nickname]
                .filter { !$0.isEmpty }
                .map(Self.normalize)

            var score = 0
            if candidates.contains(normalizedQuery) {
                score = 3
            } else if queryTokens.allSatisfy({ token in
                candidates.contains(where: { $0.split(separator: " ").map(String.init).contains(token) })
            }) {
                score = 2
            } else if candidates.contains(where: { $0.contains(normalizedQuery) }) {
                score = 1
            }

            guard score > 0 else { return }
            scored.append((
                score: score,
                name: fullName.isEmpty ? contact.nickname : fullName,
                phone: contact.phoneNumbers.first?.value.stringValue,
                email: contact.emailAddresses.first.map { String($0.value) }
            ))
        }

        guard !scored.isEmpty else { return .none }

        let best = scored.max(by: { $0.score < $1.score })!
        let top = scored.filter { $0.score == best.score }

        if top.count == 1 {
            return .unique(name: best.name, phone: best.phone, email: best.email)
        }
        return .ambiguous(top.prefix(5).map(\.name))
    }

    private func requestAccess() async throws {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .denied || status == .restricted {
            throw ToolError("El usuario no ha concedido acceso a los contactos.")
        }
        let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
        guard granted else {
            throw ToolError("El usuario no ha concedido acceso a los contactos.")
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Teléfonos

    /// Convierte un teléfono al formato de wa.me: dígitos con prefijo de país,
    /// sin `+`. "+34 600 11 22 33" → "34600112233". Si no trae prefijo, se
    /// antepone el del locale de reconocimiento configurado.
    static func normalizePhoneForWhatsApp(_ raw: String) -> String? {
        var digits = raw.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        if raw.trimmingCharacters(in: .whitespaces).hasPrefix("+") {
            return digits
        }
        if digits.hasPrefix("00") {
            return String(digits.dropFirst(2))
        }
        // Sin prefijo internacional: usar el del idioma configurado.
        let prefix = defaultCountryPrefix()
        if !digits.hasPrefix(prefix) || digits.count <= 9 {
            digits = prefix + digits
        }
        return digits
    }

    private static func defaultCountryPrefix() -> String {
        // Mismo valor que AssistantViewModel.localeDefaultsKey (aislado a
        // @MainActor, no accesible desde aquí).
        let locale = UserDefaults.standard.string(forKey: "jarvis.locale") ?? "es-ES"
        switch locale {
        case "es-MX": return "52"
        case "es-AR": return "54"
        case "es-US": return "1"
        default: return "34"
        }
    }
}
