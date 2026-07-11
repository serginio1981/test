import Foundation
import UIKit

/// Definiciones de herramientas que se anuncian a Claude en cada petición.
/// Fuera de ToolExecutor para poder leerlas desde contextos no aislados.
enum JarvisTools {
    static let definitions: [ToolDefinition] = [
        ToolDefinition(
            name: "get_current_datetime",
            description: "Devuelve la fecha y hora actuales del dispositivo del usuario.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([:]),
            ])
        ),
        ToolDefinition(
            name: "get_weather",
            description: "Devuelve el tiempo actual. Si no se indican coordenadas, usa la ubicación del usuario.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "latitude": .object([
                        "type": .string("number"),
                        "description": .string("Latitud en grados decimales (opcional)"),
                    ]),
                    "longitude": .object([
                        "type": .string("number"),
                        "description": .string("Longitud en grados decimales (opcional)"),
                    ]),
                ]),
            ])
        ),
        ToolDefinition(
            name: "create_reminder",
            description: "Crea un recordatorio en la app Recordatorios del usuario.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Título del recordatorio"),
                    ]),
                    "due_date": .object([
                        "type": .string("string"),
                        "description": .string("Fecha y hora ISO-8601, p. ej. 2026-07-11T09:00:00 (opcional)"),
                    ]),
                    "notes": .object([
                        "type": .string("string"),
                        "description": .string("Notas adicionales (opcional)"),
                    ]),
                ]),
                "required": .array([.string("title")]),
            ])
        ),
        ToolDefinition(
            name: "open_url",
            description: "Abre una página web en el navegador del usuario.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "url": .object([
                        "type": .string("string"),
                        "description": .string("URL completa con esquema http o https"),
                    ]),
                ]),
                "required": .array([.string("url")]),
            ])
        ),
        ToolDefinition(
            name: "read_emails",
            description: "Lee los últimos correos de la bandeja de entrada de Outlook del usuario y devuelve remitente, asunto, fecha y un extracto.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "count": .object([
                        "type": .string("integer"),
                        "description": .string("Número de correos a leer, entre 1 y 10 (por defecto 5)"),
                    ]),
                    "unread_only": .object([
                        "type": .string("boolean"),
                        "description": .string("Si es true, solo correos no leídos (por defecto false)"),
                    ]),
                ]),
            ])
        ),
        ToolDefinition(
            name: "send_email",
            description: "Envía un correo desde la cuenta de Outlook del usuario. Confirma siempre con el usuario el destinatario y el contenido antes de enviar.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "to": .object([
                        "type": .string("string"),
                        "description": .string("Dirección de correo o nombre de un contacto de la agenda"),
                    ]),
                    "subject": .object([
                        "type": .string("string"),
                        "description": .string("Asunto del correo"),
                    ]),
                    "body": .object([
                        "type": .string("string"),
                        "description": .string("Cuerpo del correo en texto plano"),
                    ]),
                ]),
                "required": .array([.string("to"), .string("subject"), .string("body")]),
            ])
        ),
        ToolDefinition(
            name: "play_music",
            description: "Busca y reproduce música en Apple Music: una canción, un artista, un álbum o una playlist de la biblioteca del usuario.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "query": .object([
                        "type": .string("string"),
                        "description": .string("Qué reproducir, p. ej. «Back in Black de AC/DC»"),
                    ]),
                    "type": .object([
                        "type": .string("string"),
                        "enum": .array([.string("song"), .string("artist"), .string("album"), .string("playlist")]),
                        "description": .string("Tipo de búsqueda (por defecto song)"),
                    ]),
                ]),
                "required": .array([.string("query")]),
            ])
        ),
        ToolDefinition(
            name: "control_music",
            description: "Controla la reproducción de música en curso.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "action": .object([
                        "type": .string("string"),
                        "enum": .array([.string("pause"), .string("resume"), .string("next"), .string("previous")]),
                        "description": .string("Acción de reproducción"),
                    ]),
                ]),
                "required": .array([.string("action")]),
            ])
        ),
        ToolDefinition(
            name: "send_whatsapp",
            description: "Prepara un mensaje de WhatsApp para un contacto: abre WhatsApp con el mensaje escrito y el usuario solo tiene que pulsar enviar. Acepta nombre de contacto o número de teléfono.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "contact": .object([
                        "type": .string("string"),
                        "description": .string("Nombre del contacto en la agenda o número de teléfono"),
                    ]),
                    "message": .object([
                        "type": .string("string"),
                        "description": .string("Texto del mensaje"),
                    ]),
                ]),
                "required": .array([.string("contact"), .string("message")]),
            ])
        ),
        ToolDefinition(
            name: "request_uber",
            description: "Prepara un viaje en Uber hasta un destino: abre Uber con la recogida en la ubicación actual y el destino fijado; el usuario confirma el pedido en la app.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "destination": .object([
                        "type": .string("string"),
                        "description": .string("Destino en texto libre, p. ej. «aeropuerto de Barajas»"),
                    ]),
                ]),
                "required": .array([.string("destination")]),
            ])
        ),
    ]
}

/// Ejecuta las herramientas que Claude solicita vía tool_use y devuelve el
/// resultado como texto para el bloque tool_result correspondiente.
@MainActor
final class ToolExecutor {
    private let weatherService = WeatherService()
    private let remindersService = RemindersService()
    private let outlookService = OutlookService()
    private let musicService = MusicService()
    private let contactsService = ContactsService()

    func execute(name: String, input: [String: JSONValue]) async throws -> String {
        switch name {
        case "get_current_datetime":
            return currentDateTime()
        case "get_weather":
            return try await weatherService.currentWeather(
                latitude: input["latitude"]?.doubleValue,
                longitude: input["longitude"]?.doubleValue
            )
        case "create_reminder":
            guard let title = input["title"]?.stringValue, !title.isEmpty else {
                throw ToolError("Falta el título del recordatorio.")
            }
            return try await remindersService.createReminder(
                title: title,
                dueDateISO8601: input["due_date"]?.stringValue,
                notes: input["notes"]?.stringValue
            )
        case "open_url":
            return try await openURL(input["url"]?.stringValue)
        case "read_emails":
            let count = Int(input["count"]?.doubleValue ?? 5)
            return try await outlookService.readInbox(
                count: count,
                unreadOnly: input["unread_only"]?.boolValue ?? false
            )
        case "send_email":
            return try await sendEmail(input: input)
        case "play_music":
            guard let query = input["query"]?.stringValue, !query.isEmpty else {
                throw ToolError("Falta qué reproducir.")
            }
            let type = MusicService.SearchType(rawValue: input["type"]?.stringValue ?? "song") ?? .song
            return try await musicService.play(query: query, type: type)
        case "control_music":
            guard let action = input["action"]?.stringValue else {
                throw ToolError("Falta la acción de reproducción.")
            }
            return try await musicService.control(action: action)
        case "send_whatsapp":
            return try await sendWhatsApp(input: input)
        case "request_uber":
            guard let destination = input["destination"]?.stringValue, !destination.isEmpty else {
                throw ToolError("Falta el destino del viaje.")
            }
            return try await DeepLinks.requestUber(destination: destination)
        default:
            throw ToolError("Herramienta desconocida: \(name)")
        }
    }

    // MARK: - Correo

    private func sendEmail(input: [String: JSONValue]) async throws -> String {
        guard let to = input["to"]?.stringValue, !to.isEmpty else {
            throw ToolError("Falta el destinatario del correo.")
        }
        guard let subject = input["subject"]?.stringValue, !subject.isEmpty else {
            throw ToolError("Falta el asunto del correo.")
        }
        guard let body = input["body"]?.stringValue, !body.isEmpty else {
            throw ToolError("Falta el cuerpo del correo.")
        }

        // Si no es una dirección, buscar el email del contacto en la agenda.
        var recipient = to
        if !to.contains("@") {
            switch try await contactsService.findContact(named: to) {
            case .unique(let name, _, let email):
                guard let email else {
                    throw ToolError("El contacto \(name) no tiene correo en la agenda.")
                }
                recipient = email
            case .ambiguous(let names):
                throw ToolError("He encontrado varios contactos: \(names.joined(separator: ", ")). ¿A cuál se refiere?")
            case .none:
                throw ToolError("No encuentro a «\(to)» en la agenda.")
            }
        }
        return try await outlookService.sendMail(to: recipient, subject: subject, body: body)
    }

    // MARK: - WhatsApp

    private func sendWhatsApp(input: [String: JSONValue]) async throws -> String {
        guard let contact = input["contact"]?.stringValue, !contact.isEmpty else {
            throw ToolError("Falta el destinatario del mensaje.")
        }
        guard let message = input["message"]?.stringValue, !message.isEmpty else {
            throw ToolError("Falta el texto del mensaje.")
        }

        // ¿Es un número de teléfono directo? (mayoría de dígitos)
        let digitCount = contact.filter(\.isNumber).count
        if digitCount >= 7 && digitCount * 2 >= contact.count {
            guard let number = ContactsService.normalizePhoneForWhatsApp(contact) else {
                throw ToolError("Ese número de teléfono no parece válido.")
            }
            return try await DeepLinks.openWhatsApp(number: number, recipientName: contact, message: message)
        }

        switch try await contactsService.findContact(named: contact) {
        case .unique(let name, let phone, _):
            guard let phone, let number = ContactsService.normalizePhoneForWhatsApp(phone) else {
                throw ToolError("El contacto \(name) no tiene teléfono en la agenda.")
            }
            return try await DeepLinks.openWhatsApp(number: number, recipientName: name, message: message)
        case .ambiguous(let names):
            throw ToolError("He encontrado varios contactos: \(names.joined(separator: ", ")). ¿A cuál se refiere?")
        case .none:
            throw ToolError("No encuentro a «\(contact)» en la agenda.")
        }
    }

    // MARK: - Herramientas simples

    private func currentDateTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: .now)
    }

    private func openURL(_ urlString: String?) async throws -> String {
        guard var urlString, !urlString.isEmpty else {
            throw ToolError("Falta la URL.")
        }
        if !urlString.contains("://") {
            urlString = "https://" + urlString
        }
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw ToolError("La URL no es válida o no usa http/https.")
        }
        let opened = await UIApplication.shared.open(url)
        guard opened else {
            throw ToolError("No se pudo abrir la URL.")
        }
        return "Abierta la página \(url.absoluteString)."
    }
}

/// Error de herramienta con mensaje legible que se devuelve a Claude
/// en un tool_result con is_error.
struct ToolError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
