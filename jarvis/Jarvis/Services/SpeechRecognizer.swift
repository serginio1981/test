import AVFoundation
import Foundation
import Speech

/// Reconocimiento de voz sobre AVAudioEngine + SFSpeechRecognizer con dos modos:
/// - `wakeWord`: sesión continua que busca "jarvis" en las transcripciones parciales.
/// - `command`: transcribe una orden y la da por terminada tras 1,5 s de silencio.
///
/// Apple limita cada tarea de reconocimiento a ~1 minuto, así que en modo
/// wake-word la tarea se reinicia cada 50 s sin parar el motor de audio.
@MainActor
final class SpeechRecognizer {
    enum Mode {
        case wakeWord
        case command
    }

    // Callbacks hacia el view model (siempre en el main actor).
    var onWakeWordDetected: (() -> Void)?
    var onPartialTranscript: ((String) -> Void)?
    var onCommandFinished: ((String) -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var mode: Mode = .wakeWord
    private var restartTimer: Timer?
    private var silenceTimer: Timer?
    private var latestTranscript = ""
    private(set) var isRunning = false

    /// El reconocimiento de "Jarvis" en es-ES es difuso; se aceptan variantes fonéticas.
    private static let wakeWordVariants = ["jarvis", "yarvis", "harvis", "jarbis", "yarbis"]

    private static let wakeTaskRestartInterval: TimeInterval = 50
    private static let commandSilenceTimeout: TimeInterval = 1.5
    private static let commandMaxDuration: TimeInterval = 15

    init(localeIdentifier: String = "es-ES") {
        setLocale(localeIdentifier)
    }

    func setLocale(_ identifier: String) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    }

    // MARK: - Permisos

    static func requestPermissions() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Ciclo de vida

    /// Arranca el motor de audio y una tarea de reconocimiento en el modo dado.
    func start(mode: Mode) throws {
        stop()
        self.mode = mode
        latestTranscript = ""

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw JarvisError.speechUnavailable
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw JarvisError.speechUnavailable
        }

        // Quitar cualquier tap huérfano (p. ej. si un arranque anterior falló
        // a medias); instalar dos taps en el mismo bus provoca un crash.
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.request?.append(buffer)
            let level = Self.rmsLevel(of: buffer)
            Task { @MainActor in
                self.onAudioLevel?(level)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true

        startRecognitionTask()
        scheduleModeTimers()
    }

    /// Para todo: tarea, tap y motor. Se llama antes de hablar por TTS
    /// para que Jarvis no se escuche (ni se active) a sí mismo.
    func stop() {
        restartTimer?.invalidate()
        restartTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            isRunning = false
        }
        onAudioLevel?(0)
    }

    // MARK: - Tarea de reconocimiento

    private func startRecognitionTask() {
        task?.cancel()
        task = nil

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            newRequest.requiresOnDeviceRecognition = true
        }
        newRequest.taskHint = mode == .wakeWord ? .search : .dictation
        request = newRequest

        latestTranscript = ""
        let currentMode = mode

        task = speechRecognizer?.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                self.handleRecognition(result: result, error: error, taskMode: currentMode)
            }
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?, taskMode: Mode) {
        // Ignora resultados de tareas antiguas si el modo ya cambió.
        guard isRunning, taskMode == mode else { return }

        if let result {
            let transcript = result.bestTranscription.formattedString
            latestTranscript = transcript

            switch mode {
            case .wakeWord:
                if Self.containsWakeWord(transcript) {
                    onWakeWordDetected?()
                }
            case .command:
                onPartialTranscript?(transcript)
                resetSilenceTimer()
                if result.isFinal {
                    finishCommand()
                }
            }
        }

        if error != nil {
            switch mode {
            case .wakeWord:
                // Las tareas caducan (~1 min) o fallan puntualmente: rearmar.
                startRecognitionTask()
            case .command:
                finishCommand()
            }
        }
    }

    private func scheduleModeTimers() {
        switch mode {
        case .wakeWord:
            restartTimer = Timer.scheduledTimer(
                withTimeInterval: Self.wakeTaskRestartInterval,
                repeats: true
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.isRunning, self.mode == .wakeWord else { return }
                    self.startRecognitionTask()
                }
            }
        case .command:
            // Tope duro por si el usuario no habla o el silencio no se detecta.
            restartTimer = Timer.scheduledTimer(
                withTimeInterval: Self.commandMaxDuration,
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.finishCommand()
                }
            }
            resetSilenceTimer()
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: Self.commandSilenceTimeout,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.finishCommand()
            }
        }
    }

    private func finishCommand() {
        guard mode == .command, isRunning else { return }
        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        stop()
        onCommandFinished?(transcript)
    }

    // MARK: - Utilidades

    static func containsWakeWord(_ transcript: String) -> Bool {
        let normalized = transcript
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
        return wakeWordVariants.contains { normalized.contains($0) }
    }

    private static func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<frameLength {
            let sample = channelData[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        // Normaliza a un rango útil para la UI (el habla suele quedar en 0.01–0.3).
        return min(1, rms * 8)
    }
}
