import Foundation

/// Lectura y envío de correo de Outlook vía Microsoft Graph.
@MainActor
final class OutlookService {
    private let auth = MicrosoftAuthService.shared

    // MARK: - Leer bandeja de entrada

    func readInbox(count: Int, unreadOnly: Bool) async throws -> String {
        let top = min(max(count, 1), 10)
        var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages")!
        var queryItems = [
            URLQueryItem(name: "$top", value: String(unreadOnly ? 20 : top)),
            URLQueryItem(name: "$select", value: "from,subject,bodyPreview,receivedDateTime,isRead"),
            URLQueryItem(name: "$orderby", value: "receivedDateTime desc"),
        ]
        if unreadOnly {
            queryItems.append(URLQueryItem(name: "$filter", value: "isRead eq false"))
        }
        components.queryItems = queryItems

        var (data, status) = try await graphRequest(url: components.url!)

        // Graph a veces rechaza $filter + $orderby combinados (InefficientFilter):
        // reintentar sin $orderby (el inbox ya viene en orden descendente).
        if status == 400 && unreadOnly {
            components.queryItems = queryItems.filter { $0.name != "$orderby" }
            (data, status) = try await graphRequest(url: components.url!)
        }

        guard status == 200 else {
            throw ToolError("No he podido leer el correo (error \(status) de Microsoft).")
        }

        guard let list = try? JSONDecoder().decode(GraphMessageList.self, from: data) else {
            throw ToolError("Respuesta de correo no válida.")
        }

        let messages = Array(list.value.prefix(top))
        guard !messages.isEmpty else {
            return unreadOnly ? "No tiene correos sin leer." : "La bandeja de entrada está vacía."
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .full
        let isoParser = ISO8601DateFormatter()
        isoParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoParserNoFraction = ISO8601DateFormatter()

        let lines = messages.enumerated().map { index, message -> String in
            let sender = message.from?.emailAddress?.name
                ?? message.from?.emailAddress?.address
                ?? "remitente desconocido"
            let subject = message.subject?.isEmpty == false ? message.subject! : "sin asunto"
            var when = ""
            if let dateString = message.receivedDateTime,
               let date = isoParser.date(from: dateString) ?? isoParserNoFraction.date(from: dateString) {
                when = ", recibido \(formatter.localizedString(for: date, relativeTo: .now))"
            }
            let unread = message.isRead == false ? " (sin leer)" : ""
            let preview = (message.bodyPreview ?? "")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let shortPreview = preview.isEmpty ? "" : ": \(String(preview.prefix(140)))"
            return "\(index + 1). De \(sender), asunto «\(subject)»\(when)\(unread)\(shortPreview)"
        }

        let header = unreadOnly
            ? "Tiene \(messages.count) correos sin leer."
            : "Estos son los últimos \(messages.count) correos."
        return ([header] + lines).joined(separator: " ")
    }

    // MARK: - Enviar

    func sendMail(to recipient: String, subject: String, body: String) async throws -> String {
        let payload: [String: Any] = [
            "message": [
                "subject": subject,
                "body": ["contentType": "Text", "content": body],
                "toRecipients": [["emailAddress": ["address": recipient]]],
            ],
            "saveToSentItems": true,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)

        let (_, status) = try await graphRequest(
            url: URL(string: "https://graph.microsoft.com/v1.0/me/sendMail")!,
            method: "POST",
            body: bodyData
        )

        guard status == 202 else {
            throw ToolError("No he podido enviar el correo (error \(status) de Microsoft).")
        }
        return "Correo enviado a \(recipient)."
    }

    // MARK: - Petición a Graph con reintento tras 401

    private func graphRequest(url: URL, method: String = "GET", body: Data? = nil) async throws -> (Data, Int) {
        func perform(token: String) async throws -> (Data, Int) {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if body != nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            request.httpBody = body

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw ToolError("No se pudo conectar con Microsoft.")
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (data, status)
        }

        let token = try await auth.validAccessToken()
        let result = try await perform(token: token)
        guard result.1 == 401 else { return result }

        // Token rechazado pese a no estar caducado: refrescar y reintentar una vez.
        let freshToken = try await auth.forceRefreshedAccessToken()
        return try await perform(token: freshToken)
    }
}

// MARK: - Modelos de Graph

private struct GraphMessageList: Decodable {
    let value: [GraphMessage]
}

private struct GraphMessage: Decodable {
    struct From: Decodable {
        struct EmailAddress: Decodable {
            let name: String?
            let address: String?
        }

        let emailAddress: EmailAddress?
    }

    let from: From?
    let subject: String?
    let bodyPreview: String?
    let receivedDateTime: String?
    let isRead: Bool?
}
