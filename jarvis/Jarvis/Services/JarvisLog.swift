import Foundation
import os

/// Registro interno de la app para el modo desarrollador: guarda las últimas
/// entradas en memoria (visor en Ajustes) y las espeja en os.Logger para que
/// también se vean en Console.app. Seguro para llamar desde cualquier hilo.
/// Nunca se registran secretos (API keys, tokens).
final class JarvisLog: @unchecked Sendable {
    static let shared = JarvisLog()

    static let devModeDefaultsKey = "jarvis.devMode"

    enum Level: String {
        case info = "INFO"
        case warn = "AVISO"
        case error = "ERROR"
    }

    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let level: Level
        let message: String
    }

    private let lock = NSLock()
    private var entries: [Entry] = []
    private let maxEntries = 500
    private let osLogger = Logger(subsystem: "com.serginio.jarvis", category: "jarvis")

    private init() {}

    func info(_ message: String) { append(.info, message) }
    func warn(_ message: String) { append(.warn, message) }
    func error(_ message: String) { append(.error, message) }

    private func append(_ level: Level, _ message: String) {
        lock.lock()
        entries.append(Entry(date: .now, level: level, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()

        switch level {
        case .info: osLogger.info("\(message, privacy: .public)")
        case .warn: osLogger.warning("\(message, privacy: .public)")
        case .error: osLogger.error("\(message, privacy: .public)")
        }
    }

    var snapshot: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }

    var exportText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return snapshot
            .map { "\(formatter.string(from: $0.date)) [\($0.level.rawValue)] \($0.message)" }
            .joined(separator: "\n")
    }
}
