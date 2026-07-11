import Combine
import SwiftUI
import UIKit

/// Visor del registro interno (modo desarrollador): entradas más recientes
/// arriba, con botones para copiar, compartir y limpiar.
struct LogView: View {
    @State private var entries: [JarvisLog.Entry] = JarvisLog.shared.snapshot
    @State private var copied = false

    private let refresh = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if entries.isEmpty {
                Text("Sin entradas todavía.")
                    .font(Theme.hudFont(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(entries.reversed())) { entry in
                            row(for: entry)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .navigationTitle("Registro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = JarvisLog.shared.exportText
                    copied = true
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                ShareLink(item: JarvisLog.shared.exportText) {
                    Image(systemName: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    JarvisLog.shared.clear()
                    entries = []
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .onReceive(refresh) { _ in
            entries = JarvisLog.shared.snapshot
            copied = false
        }
        .preferredColorScheme(.dark)
    }

    private func row(for entry: JarvisLog.Entry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(Self.timeFormatter.string(from: entry.date))
                    .foregroundStyle(Theme.textSecondary)
                Text(entry.level.rawValue)
                    .fontWeight(.bold)
                    .foregroundStyle(color(for: entry.level))
            }
            .font(.system(size: 11, design: .monospaced))

            Text(entry.message)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for level: JarvisLog.Level) -> Color {
        switch level {
        case .info: return Theme.arcBlue
        case .warn: return Theme.gold
        case .error: return Color(red: 1.0, green: 0.45, blue: 0.35)
        }
    }
}

#Preview {
    NavigationStack {
        LogView()
    }
}
