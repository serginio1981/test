import EventKit
import Foundation

/// Crea recordatorios en la app Recordatorios vía EventKit.
final class RemindersService {
    private let store = EKEventStore()

    func createReminder(title: String, dueDateISO8601: String?, notes: String?) async throws -> String {
        let granted = try await store.requestFullAccessToReminders()
        guard granted else {
            throw ToolError("El usuario no ha concedido acceso a los recordatorios.")
        }

        guard let calendar = store.defaultCalendarForNewReminders() else {
            throw ToolError("No hay una lista de recordatorios por defecto.")
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar
        reminder.notes = notes

        var confirmation = "Recordatorio «\(title)» creado"
        if let dueDateISO8601, let dueDate = Self.parseISO8601(dueDateISO8601) {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            confirmation += " para el \(formatter.string(from: dueDate))"
        }

        try store.save(reminder, commit: true)
        return confirmation + "."
    }

    /// Acepta ISO-8601 con o sin zona horaria ("2026-07-11T09:00:00" se
    /// interpreta en la zona local del dispositivo).
    static func parseISO8601(_ string: String) -> Date? {
        let withTimeZone = ISO8601DateFormatter()
        withTimeZone.formatOptions = [.withInternetDateTime]
        if let date = withTimeZone.date(from: string) {
            return date
        }
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = .current
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = local.date(from: string) {
            return date
        }
        local.dateFormat = "yyyy-MM-dd"
        return local.date(from: string)
    }
}
