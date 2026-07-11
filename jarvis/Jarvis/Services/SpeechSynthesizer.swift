import AVFoundation
import Foundation

/// Envoltorio async de AVSpeechSynthesizer. La voz se elige en Ajustes; si no
/// hay elección, se prefiere automáticamente una voz masculina en español de
/// la mayor calidad instalada (premium > enhanced > por defecto).
@MainActor
final class SpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate {
    static let voiceDefaultsKey = "jarvis.voiceId"

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
        // Sesión de audio propia del sistema para la voz: evita que el estado
        // de la sesión de grabación (AVAudioEngine) pueda silenciar el TTS.
        synthesizer.usesApplicationAudioSession = false
    }

    /// Lee el texto en voz alta y retorna cuando termina (o se cancela).
    func speak(_ text: String) async {
        let sanitized = Self.sanitizeForSpeech(text)
        guard !sanitized.isEmpty else { return }

        JarvisLog.shared.info("TTS: hablando (\(sanitized.count) caracteres)")
        stop()

        let utterance = AVSpeechUtterance(string: sanitized)
        utterance.voice = Self.selectedVoice()
        utterance.pitchMultiplier = 0.9 // algo más grave, tono de mayordomo
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.continuation = continuation
            self.synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        resumeContinuation()
    }

    private func resumeContinuation() {
        continuation?.resume()
        continuation = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.resumeContinuation()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.resumeContinuation()
        }
    }

    // MARK: - Selección de voz

    /// Voz elegida en Ajustes; si no hay (o ya no está instalada), la mejor
    /// voz automática.
    static func selectedVoice() -> AVSpeechSynthesisVoice? {
        if let id = UserDefaults.standard.string(forKey: voiceDefaultsKey),
           !id.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return bestSpanishVoice()
    }

    /// Voces en español instaladas, ordenadas: masculinas primero, luego
    /// mayor calidad, luego es-ES. Es también el orden de la selección
    /// automática (el primer elemento) y del selector de Ajustes.
    static func availableSpanishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("es") }
            .sorted { a, b in
                if (a.gender == .male) != (b.gender == .male) {
                    return a.gender == .male
                }
                if a.quality != b.quality {
                    return a.quality.rawValue > b.quality.rawValue
                }
                if (a.language == "es-ES") != (b.language == "es-ES") {
                    return a.language == "es-ES"
                }
                return a.name < b.name
            }
    }

    /// Selección automática: masculina de la mayor calidad disponible.
    /// En el README se recomienda descargar una voz mejorada
    /// (Ajustes → Accesibilidad → Contenido hablado → Voces).
    static func bestSpanishVoice() -> AVSpeechSynthesisVoice? {
        availableSpanishVoices().first ?? AVSpeechSynthesisVoice(language: "es-ES")
    }

    /// Limpia el texto para que suene natural: quita markdown y adornos.
    static func sanitizeForSpeech(_ text: String) -> String {
        var result = text
        for token in ["**", "*", "`", "#", "_"] {
            result = result.replacingOccurrences(of: token, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
