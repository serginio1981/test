import Foundation

// MARK: - JSONValue

/// JSON arbitrario con Codable. Se usa para los `input` de las herramientas
/// (cuya forma decide Claude) y para declarar los `input_schema`.
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Valor JSON no soportado"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .string(let value): return Bool(value.lowercased())
        default: return nil
        }
    }
}

// MARK: - Bloques de contenido

/// Bloque de contenido del Messages API. Cubre los tres tipos que usa la app.
enum ContentBlock: Codable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: JSONValue])
    case toolResult(toolUseId: String, content: String, isError: Bool)

    private enum CodingKeys: String, CodingKey {
        case type, text, id, name, input
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "tool_use":
            self = .toolUse(
                id: try container.decode(String.self, forKey: .id),
                name: try container.decode(String.self, forKey: .name),
                input: try container.decode([String: JSONValue].self, forKey: .input)
            )
        case "tool_result":
            self = .toolResult(
                toolUseId: try container.decode(String.self, forKey: .toolUseId),
                content: try container.decodeIfPresent(String.self, forKey: .content) ?? "",
                isError: try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
            )
        default:
            // Bloques desconocidos (p. ej. "thinking") se ignoran como texto vacío.
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseId, let content, let isError):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseId, forKey: .toolUseId)
            try container.encode(content, forKey: .content)
            if isError {
                try container.encode(true, forKey: .isError)
            }
        }
    }
}

// MARK: - Mensajes

struct APIMessage: Codable, Equatable {
    let role: String // "user" | "assistant"
    let content: [ContentBlock]

    static func user(_ text: String) -> APIMessage {
        APIMessage(role: "user", content: [.text(text)])
    }

    static func assistant(_ text: String) -> APIMessage {
        APIMessage(role: "assistant", content: [.text(text)])
    }
}

// MARK: - Herramientas

struct ToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: JSONValue

    private enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

// MARK: - Petición / respuesta

struct MessagesRequest: Codable {
    struct Thinking: Codable {
        let type: String
    }

    let model: String
    let maxTokens: Int
    let system: String
    let messages: [APIMessage]
    let tools: [ToolDefinition]
    /// Desactivado explícitamente: el thinking adaptativo añade latencia
    /// que no queremos en un asistente de voz.
    let thinking: Thinking

    private enum CodingKeys: String, CodingKey {
        case model, system, messages, tools, thinking
        case maxTokens = "max_tokens"
    }
}

struct MessagesResponse: Codable {
    struct Usage: Codable {
        let inputTokens: Int?
        let outputTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    let content: [ContentBlock]
    let stopReason: String?
    let usage: Usage?

    private enum CodingKeys: String, CodingKey {
        case content, usage
        case stopReason = "stop_reason"
    }

    /// Texto plano de la respuesta (todos los bloques de texto concatenados).
    var text: String {
        content.compactMap { block in
            if case .text(let text) = block, !text.isEmpty { return text }
            return nil
        }.joined(separator: " ")
    }

    var toolUses: [(id: String, name: String, input: [String: JSONValue])] {
        content.compactMap { block in
            if case .toolUse(let id, let name, let input) = block {
                return (id, name, input)
            }
            return nil
        }
    }
}

struct APIErrorResponse: Codable {
    struct APIError: Codable {
        let type: String?
        let message: String?
    }

    let error: APIError?
}
