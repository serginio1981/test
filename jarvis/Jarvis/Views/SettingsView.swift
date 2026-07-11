import AVFoundation
import SwiftUI

/// Ajustes: clave de API (Keychain), modelo de Claude, idioma de
/// reconocimiento, voz y prueba de conexión.
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

    @State private var voiceId = UserDefaults.standard.string(forKey: SpeechSynthesizer.voiceDefaultsKey) ?? ""
    @State private var previewSynthesizer = SpeechSynthesizer()

    @State private var hapticsEnabled = UserDefaults.standard.object(forKey: AssistantViewModel.hapticsDefaultsKey) == nil
        || UserDefaults.standard.bool(forKey: AssistantViewModel.hapticsDefaultsKey)
    @State private var devMode = UserDefaults.standard.bool(forKey: JarvisLog.devModeDefaultsKey)

    @State private var msClientId = UserDefaults.standard.string(forKey: MicrosoftAuthService.clientIdDefaultsKey) ?? ""
    @State private var msAccountName = MicrosoftAuthService.shared.accountName
    @State private var isMsSignedIn = MicrosoftAuthService.shared.isSignedIn
    @State private var isSigningIn = false
    @State private var msError: String?

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
                microsoftSection
                voiceSection
                appSection
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

    private var microsoftSection: some View {
        Section {
            TextField("Application (client) ID", text: $msClientId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: msClientId) { _, newValue in
                    UserDefaults.standard.set(
                        newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                        forKey: MicrosoftAuthService.clientIdDefaultsKey
                    )
                }

            if isMsSignedIn {
                HStack {
                    Label(msAccountName ?? "Sesión iniciada", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .lineLimit(1)
                    Spacer()
                    Button("Cerrar sesión", role: .destructive) {
                        MicrosoftAuthService.shared.signOut()
                        refreshMicrosoftState()
                    }
                }
            } else {
                Button {
                    signInWithMicrosoft()
                } label: {
                    if isSigningIn {
                        HStack {
                            ProgressView()
                            Text("Iniciando sesión…")
                        }
                    } else {
                        Text("Iniciar sesión con Microsoft")
                    }
                }
                .disabled(isSigningIn || msClientId.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let msError {
                Label(msError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Outlook (Microsoft)")
        } footer: {
            Text("Registra una app gratuita en Azure y pega aquí su Application ID. Instrucciones en el README del proyecto.")
        }
    }

    private var voiceSection: some View {
        Section {
            Picker("Idioma", selection: $locale) {
                ForEach(Self.locales, id: \.id) { entry in
                    Text(entry.name).tag(entry.id)
                }
            }
            .onChange(of: locale) { _, newValue in
                viewModel.updateLocale(newValue)
            }

            Picker("Voz de Jarvis", selection: $voiceId) {
                Text("Automática (masculina)").tag("")
                ForEach(SpeechSynthesizer.availableSpanishVoices(), id: \.identifier) { voice in
                    Text(voiceLabel(for: voice)).tag(voice.identifier)
                }
            }
            .onChange(of: voiceId) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: SpeechSynthesizer.voiceDefaultsKey)
            }

            Button("Escuchar prueba de voz") {
                Task {
                    await previewSynthesizer.speak("A su servicio, señor. Sistemas operativos y a la espera de sus órdenes.")
                }
            }
        } header: {
            Text("Voz")
        } footer: {
            Text("Las voces marcadas «compacta» suenan robóticas. Descarga una voz masculina mejorada o premium en Ajustes de iOS → Accesibilidad → Contenido hablado → Voces → Español, y aparecerá aquí.")
        }
    }

    private func voiceLabel(for voice: AVSpeechSynthesisVoice) -> String {
        let gender: String
        switch voice.gender {
        case .male: gender = "masc."
        case .female: gender = "fem."
        default: gender = ""
        }
        let quality: String
        switch voice.quality {
        case .premium: quality = "premium"
        case .enhanced: quality = "mejorada"
        default: quality = "compacta"
        }
        let parts = [voice.name, voice.language, gender, quality].filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    private var appSection: some View {
        Section {
            Toggle("Vibración al activar a Jarvis", isOn: $hapticsEnabled)
                .onChange(of: hapticsEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: AssistantViewModel.hapticsDefaultsKey)
                }
            Toggle("Modo desarrollador", isOn: $devMode)
                .onChange(of: devMode) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: JarvisLog.devModeDefaultsKey)
                }
            if devMode {
                NavigationLink {
                    LogView()
                } label: {
                    Label("Ver registro de la app", systemImage: "terminal")
                }
            }
        } header: {
            Text("Aplicación")
        } footer: {
            devMode
                ? Text("El registro guarda los últimos 500 eventos internos (voz, Claude, herramientas) para diagnosticar fallos. No contiene claves ni tokens.")
                : Text("")
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

    private func signInWithMicrosoft() {
        isSigningIn = true
        msError = nil
        Task {
            do {
                try await MicrosoftAuthService.shared.signIn()
            } catch let error as ToolError {
                msError = error.message
            } catch {
                msError = error.localizedDescription
            }
            isSigningIn = false
            refreshMicrosoftState()
        }
    }

    private func refreshMicrosoftState() {
        isMsSignedIn = MicrosoftAuthService.shared.isSignedIn
        msAccountName = MicrosoftAuthService.shared.accountName
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
