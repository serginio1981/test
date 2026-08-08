import AVFoundation
import Foundation

/// Envoltorio async de AVSpeechSynthesizer con selección de la mejor voz
/// en español disponible (premium > enhanced > por defecto).
@MainActor
final class SpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Lee el texto en voz alta y retorna cuando termina (o se cancela).
    func speak(_ text: String) async {
        let sanitized = Self.sanitizeForSpeech(text)
        guard !sanitized.isEmpty else { return }

        stop()

        let utterance = AVSpeechUtterance(string: sanitized)
        utterance.voice = Self.bestSpanishVoice()
        utterance.pitchMultiplier = 0.95
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

    /// Prefiere voces es-ES de mayor calidad. En el README se recomienda
    /// descargar una voz mejorada (Ajustes → Accesibilidad → Contenido hablado).
    static func bestSpanishVoice() -> AVSpeechSynthesisVoice? {
        let spanishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("es") }

        func pick(quality: AVSpeechSynthesisVoiceQuality) -> AVSpeechSynthesisVoice? {
            spanishVoices.first { $0.quality == quality && $0.language == "es-ES" }
                ?? spanishVoices.first { $0.quality == quality }
        }

        return pick(quality: .premium)
            ?? pick(quality: .enhanced)
            ?? AVSpeechSynthesisVoice(language: "es-ES")
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
