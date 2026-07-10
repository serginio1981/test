import SwiftUI

/// Ajustes: clave de API (Keychain), modelo de Claude, idioma de
/// reconocimiento y prueba de conexión.
struct SettingsView: View {
    @Environment(AssistantViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyInput = ""
    @State private var model = UserDefaults.standard.string(forKey: ClaudeClient.modelDefaultsKey)
        ?? ClaudeClient.defaultModel
    @State private var locale = UserDefaults.standard.string(forKey: AssistantViewModel.localeDefaultsKey)
        ?? "es-ES"
    @State private var testResult: TestResult?
    @State private var isTesting = false

    private enum TestResult: Equatable {
        case success
        case failure(String)
    }

    private static let locales: [(id: String, name: String)] = [
        ("es-ES", "Español (España)"),
        ("es-MX", "Español (México)"),
        ("es-AR", "Español (Argentina)"),
        ("es-US", "Español (EE. UU.)"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                modelSection
                voiceSection
                testSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Theme.arcBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var apiKeySection: some View {
        Section {
            if viewModel.hasAPIKey && apiKeyInput.isEmpty {
                HStack {
                    Label("Clave configurada", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Borrar", role: .destructive) {
                        KeychainStore.deleteAPIKey()
                        viewModel.refreshAPIKeyStatus()
                        testResult = nil
                    }
                }
            }
            SecureField("sk-ant-…", text: $apiKeyInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !apiKeyInput.isEmpty {
                Button("Guardar clave") {
                    KeychainStore.saveAPIKey(apiKeyInput)
                    apiKeyInput = ""
                    viewModel.refreshAPIKeyStatus()
                    testResult = nil
                }
            }
        } header: {
            Text("Clave de API de Anthropic")
        } footer: {
            Text("Se guarda cifrada en el llavero del dispositivo. Consíguela en console.anthropic.com.")
        }
    }

    private var modelSection: some View {
        Section {
            TextField("Modelo", text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: model) { _, newValue in
                    UserDefaults.standard.set(
                        newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                        forKey: ClaudeClient.modelDefaultsKey
                    )
                }
        } header: {
            Text("Modelo de Claude")
        } footer: {
            Text("Por defecto: \(ClaudeClient.defaultModel)")
        }
    }

    private var voiceSection: some View {
        Section("Reconocimiento de voz") {
            Picker("Idioma", selection: $locale) {
                ForEach(Self.locales, id: \.id) { entry in
                    Text(entry.name).tag(entry.id)
                }
            }
            .onChange(of: locale) { _, newValue in
                viewModel.updateLocale(newValue)
            }
        }
    }

    private var testSection: some View {
        Section {
            Button {
                testConnection()
            } label: {
                if isTesting {
                    HStack {
                        ProgressView()
                        Text("Probando…")
                    }
                } else {
                    Text("Probar conexión")
                }
            }
            .disabled(isTesting || !viewModel.hasAPIKey)

            if let testResult {
                switch testResult {
                case .success:
                    Label("Todo en orden, señor.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failure(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Text("El wake word «Jarvis» solo funciona con la app abierta: iOS no permite a apps de terceros escuchar en segundo plano.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                try await viewModel.claudeClient.testConnection()
                testResult = .success
            } catch let error as JarvisError {
                testResult = .failure(error.spokenMessage)
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}

#Preview {
    SettingsView()
        .environment(AssistantViewModel())
}
