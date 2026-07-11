import Foundation

/// Cliente del Anthropic Messages API (no streaming) con bucle agéntico de
/// herramientas. Tras un protocolo para poder sustituirlo por una variante
/// streaming en el futuro.
protocol MessagesAPIClient {
    func send(history: [APIMessage]) async throws -> String
}

final class ClaudeClient: MessagesAPIClient {
    static let defaultModel = "claude-sonnet-5"
    static let modelDefaultsKey = "jarvis.model"

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let maxToolIterations = 5

    private static let systemPrompt = """
    Eres J.A.R.V.I.S., el asistente personal de inteligencia artificial creado por el usuario, \
    inspirado en el asistente de Iron Man. Hablas siempre en español, con un tono formal, \
    elegante y sutilmente irónico, al estilo de un mayordomo británico. Te diriges al usuario \
    como «señor». Tus respuestas se leerán en voz alta: sé breve (una a tres frases), sin \
    listas, sin markdown y sin emojis. Usa las herramientas disponibles cuando la petición lo \
    requiera: hora, tiempo, recordatorios, abrir páginas web, leer y enviar correo de Outlook, \
    reproducir y controlar música de Apple Music, preparar mensajes de WhatsApp (el usuario \
    pulsa enviar) y pedir un Uber (el usuario confirma en la app). Antes de enviar un correo, \
    confirma con el usuario el destinatario y el contenido. Si un contacto resulta ambiguo, \
    pregunta a cuál se refiere. Si una herramienta falla, discúlpate con elegancia y explica \
    el problema brevemente.
    """

    private let toolExecutor: ToolExecutor
    private let urlSession: URLSession

    init(toolExecutor: ToolExecutor) {
        self.toolExecutor = toolExecutor
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        urlSession = URLSession(configuration: configuration)
    }

    /// Envía el historial y resuelve el bucle de herramientas hasta obtener
    /// la respuesta final en texto.
    func send(history: [APIMessage]) async throws -> String {
        guard let apiKey = KeychainStore.readAPIKey() else {
            throw JarvisError.missingAPIKey
        }

        var messages = history
        JarvisLog.shared.info("Claude: enviando petición (\(messages.count) mensajes)")

        for iteration in 0..<Self.maxToolIterations {
            let response = try await post(messages: messages, apiKey: apiKey)
            JarvisLog.shared.info("Claude: respuesta \(iteration + 1), stop_reason=\(response.stopReason ?? "?")")

            // El contenido del asistente se reenvía tal cual (incluidos los
            // bloques tool_use) para mantener el contrato del API.
            messages.append(APIMessage(role: "assistant", content: response.content))

            guard response.stopReason == "tool_use" else {
                return response.text
            }

            var results: [ContentBlock] = []
            for toolUse in response.toolUses {
                JarvisLog.shared.info("Tool: \(toolUse.name)(\(toolUse.input.keys.sorted().joined(separator: ", ")))")
                do {
                    let output = try await toolExecutor.execute(name: toolUse.name, input: toolUse.input)
                    results.append(.toolResult(toolUseId: toolUse.id, content: output, isError: false))
                } catch {
                    JarvisLog.shared.error("Tool \(toolUse.name) falló: \(error.localizedDescription)")
                    results.append(.toolResult(
                        toolUseId: toolUse.id,
                        content: error.localizedDescription,
                        isError: true
                    ))
                }
            }
            // Todos los tool_result de un turno van en UN solo mensaje user.
            messages.append(APIMessage(role: "user", content: results))
        }

        throw JarvisError.tooManyToolIterations
    }

    /// Petición de prueba usada por el botón «Probar conexión» de Ajustes.
    func testConnection() async throws {
        _ = try await send(history: [.user("Di solo: sistemas operativos, señor.")])
    }

    // MARK: - HTTP

    private func post(messages: [APIMessage], apiKey: String) async throws -> MessagesResponse {
        let model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? Self.defaultModel

        // Nota: sin `temperature`/`top_p` (los modelos Sonnet 5 rechazan sampling
        // no-default) y con thinking desactivado para minimizar la latencia de voz.
        let body = MessagesRequest(
            model: model,
            maxTokens: 1024,
            system: Self.systemPrompt,
            messages: messages,
            tools: JarvisTools.definitions,
            thinking: MessagesRequest.Thinking(type: "disabled")
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw JarvisError.networkError
        }

        guard let http = response as? HTTPURLResponse else {
            throw JarvisError.networkError
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(MessagesResponse.self, from: data)
        case 401, 403:
            JarvisLog.shared.error("Claude: HTTP \(http.statusCode) (clave rechazada)")
            throw JarvisError.invalidAPIKey
        case 429:
            JarvisLog.shared.warn("Claude: HTTP 429 (rate limit)")
            throw JarvisError.rateLimited
        default:
            let message = (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?
                .error?.message ?? "código \(http.statusCode)"
            JarvisLog.shared.error("Claude: HTTP \(http.statusCode): \(String(message.prefix(200)))")
            throw JarvisError.apiError(message)
        }
    }
}
