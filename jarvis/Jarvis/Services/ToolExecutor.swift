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
    ]
}

/// Ejecuta las herramientas que Claude solicita vía tool_use y devuelve el
/// resultado como texto para el bloque tool_result correspondiente.
@MainActor
final class ToolExecutor {
    private let weatherService = WeatherService()
    private let remindersService = RemindersService()

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
        default:
            throw ToolError("Herramienta desconocida: \(name)")
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
