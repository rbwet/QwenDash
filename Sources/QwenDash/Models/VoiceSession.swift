@preconcurrency import AVFoundation
import Foundation
import WhisperKit

/// On-device voice pipeline: microphone capture → Whisper transcription →
/// token-streaming TTS via `AVSpeechSynthesizer`.
///
/// Audio capture happens via `AVAudioEngine`. We install a tap on the input
/// node and stream-convert its native format to 16 kHz mono Float32 (what
/// Whisper expects) so we never have to touch the buffer again at
/// transcription time.
///
/// The first call to `transcribe()` triggers a model download (once per
/// machine, ~150 MB for the base model); subsequent calls are fully offline.
actor VoiceSession {

    enum State: Equatable, Sendable {
        case idle
        case loadingModel
        case recording
        case transcribing
        case speaking
    }

    enum VoiceError: LocalizedError {
        case engineFailed(String)
        case noAudio
        case whisperNotReady
        case micDenied
        case modelDownloadFailed(String)

        var errorDescription: String? {
            switch self {
            case .engineFailed(let m):         return "Audio engine failed: \(m)"
            case .noAudio:                     return "No audio captured."
            case .whisperNotReady:             return "Speech model isn't loaded yet."
            case .micDenied:                   return "Microphone access was denied. Enable it in System Settings → Privacy & Security → Microphone."
            case .modelDownloadFailed(let m):  return "Couldn't download the Whisper model. First-run needs internet access. (\(m))"
            }
        }
    }

    // MARK: - Audio capture

    private let engine = AVAudioEngine()
    /// Sample rate Whisper expects. Kept as a static so the audio-thread
    /// tap closure can read it without crossing the actor boundary.
    private static let whisperSampleRate: Double = 16_000
    /// 16 kHz mono Float32 — the format Whisper wants.
    private let targetFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: VoiceSession.whisperSampleRate,
            channels: 1,
            interleaved: false
        )!
    }()
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private var isTapInstalled = false

    // MARK: - Model

    private var whisperKit: WhisperKit?
    /// Smaller models transcribe faster but are less accurate. `"base"` is
    /// the sweet spot for short dictation on Apple Silicon.
    private let modelVariant = "base"

    // MARK: - TTS

    private let synthesizer = AVSpeechSynthesizer()
    /// Text buffered while a streaming answer arrives; we speak one sentence
    /// at a time so the voice output stays in sync with the text.
    private var ttsBuffer = ""

    // MARK: - State

    private(set) var state: State = .idle {
        didSet { stateContinuation?.yield(state) }
    }

    private var stateContinuation: AsyncStream<State>.Continuation?

    /// Stream of state transitions. Consume this from the main actor to keep
    /// a `@Published` mirror in sync with the session.
    func stateStream() -> AsyncStream<State> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
            continuation.yield(state)
        }
    }

    // MARK: - Model loading

    /// Pre-warm the Whisper model. Safe to call multiple times; first call
    /// downloads and loads, subsequent calls are no-ops. Throws if the
    /// download fails (typically because the first run is offline).
    func prepare() async throws {
        guard whisperKit == nil else { return }
        state = .loadingModel
        do {
            let config = WhisperKitConfig(model: modelVariant, verbose: false)
            whisperKit = try await WhisperKit(config)
            state = .idle
        } catch {
            state = .idle
            throw VoiceError.modelDownloadFailed(error.localizedDescription)
        }
    }

    /// Non-throwing prewarm used for startup warmup. Any failure is
    /// swallowed here — the error will resurface loudly the next time the
    /// user actually tries to use voice.
    func prewarm() async {
        _ = try? await prepare()
    }

    // MARK: - Recording

    /// Ensure mic permission has been granted, prompting the user if needed.
    /// Without this, `AVAudioEngine.start()` fails with `-10877` because the
    /// input node reports a zero-rate format.
    private func ensureMicPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted { throw VoiceError.micDenied }
        case .denied, .restricted:
            throw VoiceError.micDenied
        @unknown default:
            throw VoiceError.micDenied
        }
    }

    func startRecording() async throws {
        guard state == .idle || state == .loadingModel else { return }

        try await ensureMicPermission()

        samples.removeAll(keepingCapacity: true)

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        // A zero-rate format here means the engine hasn't seen the mic yet
        // (usually a permission race). Surface a clearer error.
        guard inputFormat.sampleRate > 0 else {
            throw VoiceError.engineFailed("Mic not available — try toggling the input device.")
        }
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        if !isTapInstalled {
            // Target rate is captured by value so the tap closure stays
            // Sendable and doesn't have to hop back into the actor to read
            // it. Whisper always wants 16 kHz; we enforce that here.
            let dstRate = Self.whisperSampleRate
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
                // AVAudioPCMBuffer isn't Sendable; copy the frames out on
                // this audio thread before hopping to the actor.
                let samples = VoiceSession.copySamples(from: buffer)
                let srcRate = buffer.format.sampleRate
                Task { [weak self] in
                    await self?.ingestRaw(samples, srcRate: srcRate, dstRate: dstRate)
                }
            }
            isTapInstalled = true
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            throw VoiceError.engineFailed(error.localizedDescription)
        }
        state = .recording
    }

    /// Pull interleaved mono Float32 samples out of a PCM buffer without
    /// retaining the buffer (it's not Sendable and the audio thread owns it).
    private nonisolated static func copySamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let count = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: count))
    }

    private func ingestRaw(_ raw: [Float], srcRate: Double, dstRate: Double) {
        guard !raw.isEmpty else { return }
        if srcRate == dstRate {
            samples.append(contentsOf: raw)
            return
        }
        // Linear resample. Whisper is forgiving enough for this to be fine
        // for dictation at 48 kHz → 16 kHz.
        let ratio = dstRate / srcRate
        let outCount = Int(Double(raw.count) * ratio)
        guard outCount > 0 else { return }
        samples.reserveCapacity(samples.count + outCount)
        for i in 0..<outCount {
            let srcIndex = Double(i) / ratio
            let lo = Int(srcIndex)
            let hi = min(lo + 1, raw.count - 1)
            let t = Float(srcIndex - Double(lo))
            samples.append(raw[lo] * (1 - t) + raw[hi] * t)
        }
    }

    func stopRecording() {
        if engine.isRunning { engine.stop() }
        state = .idle
    }

    /// Stop recording and return the captured 16 kHz mono samples.
    func finishRecording() -> [Float] {
        stopRecording()
        return samples
    }

    // MARK: - Transcription

    func transcribe(_ audio: [Float]) async throws -> String {
        guard !audio.isEmpty else { throw VoiceError.noAudio }
        try await prepare()
        guard let whisperKit = whisperKit else { throw VoiceError.whisperNotReady }

        state = .transcribing
        defer { state = .idle }

        let results = try await whisperKit.transcribe(audioArray: audio)
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }

    // MARK: - Text-to-speech

    /// Append a streaming delta. Every time the buffered text contains a
    /// sentence terminator we flush that sentence to the synthesizer, so
    /// spoken output keeps pace with the streamed response.
    func speakStreaming(_ delta: String) {
        ttsBuffer += delta
        while let cutIndex = ttsBuffer.firstIndex(where: { ".!?\n".contains($0) }) {
            let upTo = ttsBuffer.index(after: cutIndex)
            let sentence = String(ttsBuffer[..<upTo])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ttsBuffer = String(ttsBuffer[upTo...])
            if !sentence.isEmpty { enqueue(sentence) }
        }
    }

    /// Flush anything still buffered after the stream ends.
    func flushSpeaking() {
        let tail = ttsBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        ttsBuffer.removeAll(keepingCapacity: true)
        if !tail.isEmpty { enqueue(tail) }
    }

    /// Cancel any pending or in-flight utterances. Used when the user
    /// interrupts the model or starts a new recording.
    func cancelSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        ttsBuffer.removeAll(keepingCapacity: true)
        if state == .speaking { state = .idle }
    }

    private func enqueue(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = preferredVoice()
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)
        state = .speaking
    }

    /// Pick the best available macOS voice: prefer "Premium" / "Enhanced"
    /// English voices that ship with macOS 14; fall back to the system
    /// default if the user hasn't downloaded any high-quality voices.
    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        if let premium = voices.first(where: {
            $0.language.hasPrefix("en") && $0.quality == .premium
        }) {
            return premium
        }
        if let enhanced = voices.first(where: {
            $0.language.hasPrefix("en") && $0.quality == .enhanced
        }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}
