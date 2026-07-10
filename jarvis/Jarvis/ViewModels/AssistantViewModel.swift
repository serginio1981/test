import Foundation
import Observation
import SwiftUI
import UIKit

/// Orquesta el ciclo completo del asistente:
/// wake word → transcripción de la orden → Claude (con herramientas) → voz.
@Observable
@MainActor
final class AssistantViewModel {
    static let localeDefaultsKey = "jarvis.locale"

    // Estado observable por la UI.
    private(set) var state: AssistantState = .idle
    private(set) var messages: [ChatMessage] = []
    private(set) var liveTranscript = ""
    private(set) var currentResponse = ""
    private(set) var audioLevel: Float = 0
    var hasAPIKey = KeychainStore.hasAPIKey

    private let recognizer: SpeechRecognizer
    private let synthesizer = SpeechSynthesizer()
    private let claude: ClaudeClient
    private var permissionsGranted = false
    private var hasBootstrapped = false

    /// Últimos turnos que se envían como contexto a Claude.
    private static let historyWindow = 20

    init() {
        let toolExecutor = ToolExecutor()
        claude = ClaudeClient(toolExecutor: toolExecutor)
        let locale = UserDefaults.standard.string(forKey: Self.localeDefaultsKey) ?? "es-ES"
        recognizer = SpeechRecognizer(localeIdentifier: locale)

        recognizer.onWakeWordDetected = { [weak self] in
            self?.wakeWordDetected()
        }
        recognizer.onPartialTranscript = { [weak self] transcript in
            self?.liveTranscript = transcript
        }
        recognizer.onCommandFinished = { [weak self] transcript in
            self?.handleCommand(transcript)
        }
        recognizer.onAudioLevel = { [weak self] level in
            self?.audioLevel = level
        }
    }

    // MARK: - Arranque / ciclo de vida

    /// Llamado al aparecer la pantalla principal.
    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        permissionsGranted = await SpeechRecognizer.requestPermissions()
        guard permissionsGranted else {
            state = .error(JarvisError.permissionsDenied.spokenMessage)
            return
        }

        do {
            try AudioSessionManager.configure()
        } catch {
            state = .error(JarvisError.speechUnavailable.spokenMessage)
            return
        }

        startWakeWordListening()
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            guard phase == .background else { return }
            synthesizer.stop()
            recognizer.stop()
            state = .idle
        case .active:
            if hasBootstrapped, permissionsGranted, state == .idle {
                startWakeWordListening()
            }
        @unknown default:
            break
        }
    }

    /// Tocar el reactor: atajo de pulsar-para-hablar o botón de parada.
    func reactorTapped() {
        switch state {
        case .listeningForWakeWord, .idle, .error:
            guard permissionsGranted else { return }
            beginCommand()
        case .listeningForCommand:
            recognizer.stop()
            startWakeWordListening()
        case .speaking:
            synthesizer.stop()
        case .thinking:
            break
        }
    }

    func refreshAPIKeyStatus() {
        hasAPIKey = KeychainStore.hasAPIKey
    }

    func updateLocale(_ identifier: String) {
        UserDefaults.standard.set(identifier, forKey: Self.localeDefaultsKey)
        recognizer.setLocale(identifier)
        if state.isListening {
            startWakeWordListening()
        }
    }

    func clearConversation() {
        messages = []
    }

    // MARK: - Máquina de estados

    private func startWakeWordListening() {
        liveTranscript = ""
        do {
            try recognizer.start(mode: .wakeWord)
            state = .listeningForWakeWord
        } catch {
            state = .error(JarvisError.speechUnavailable.spokenMessage)
        }
    }

    private func wakeWordDetected() {
        guard state == .listeningForWakeWord else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        beginCommand()
    }

    private func beginCommand() {
        liveTranscript = ""
        currentResponse = ""
        do {
            try recognizer.start(mode: .command)
            state = .listeningForCommand
        } catch {
            state = .error(JarvisError.speechUnavailable.spokenMessage)
        }
    }

    private func handleCommand(_ transcript: String) {
        guard !transcript.isEmpty else {
            startWakeWordListening()
            return
        }

        liveTranscript = transcript
        messages.append(ChatMessage(role: .user, text: transcript))
        state = .thinking

        Task {
            await self.respond()
        }
    }

    private func respond() async {
        do {
            let reply = try await claude.send(history: apiHistory())
            messages.append(ChatMessage(role: .assistant, text: reply))
            await speak(reply)
        } catch let error as JarvisError {
            await speak(error.spokenMessage, isError: true)
        } catch {
            await speak(JarvisError.networkError.spokenMessage, isError: true)
        }
        startWakeWordListening()
    }

    private func speak(_ text: String, isError: Bool = false) async {
        currentResponse = text
        // El reconocedor ya está parado (el modo comando se detiene solo),
        // pero nos aseguramos: Jarvis no debe escucharse a sí mismo.
        recognizer.stop()
        state = isError ? .error(text) : .speaking
        await synthesizer.speak(text)
    }

    private func apiHistory() -> [APIMessage] {
        messages.suffix(Self.historyWindow).map { message in
            switch message.role {
            case .user: return .user(message.text)
            case .assistant: return .assistant(message.text)
            }
        }
    }

    // MARK: - Ajustes

    var claudeClient: ClaudeClient { claude }
}
