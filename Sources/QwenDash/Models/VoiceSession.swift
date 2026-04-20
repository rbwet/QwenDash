import Foundation
import AVFoundation
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

    enum State: Equatable {
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

        var errorDescription: String? {
            switch self {
            case .engineFailed(let m): return "Audio engine failed: \(m)"
            case .noAudio:              return "No audio captured."
            case .whisperNotReady:      return "Speech model isn't loaded yet."
            }
        }
    }

    // MARK: - Audio capture

    private let engine = AVAudioEngine()
    /// 16 kHz mono Float32 — the format Whisper wants.
    private let targetFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
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
        didSet { stateDidChange?(state) }
    }

    /// Callback fired whenever state transitions. Set once by the controller.
    var stateDidChange: ((State) -> Void)?

    func setStateObserver(_ observer: @escaping @Sendable (State) -> Void) {
        self.stateDidChange = observer
    }

    // MARK: - Model loading

    /// Pre-warm the Whisper model. Safe to call multiple times; first call
    /// downloads and loads, subsequent calls are no-ops.
    func prepare() async {
        guard whisperKit == nil else { return }
        state = .loadingModel
        do {
            let config = WhisperKitConfig(model: modelVariant, verbose: false)
            whisperKit = try await WhisperKit(config)
        } catch {
            // Leave state at .idle so the UI can offer a retry on next use.
        }
        state = .idle
    }

    // MARK: - Recording

    func startRecording() throws {
        guard state == .idle || state == .loadingModel else { return }

        samples.removeAll(keepingCapacity: true)

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        if !isTapInstalled {
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                Task { await self.ingest(buffer) }
            }
            isTapInstalled = true
        }

        do {
            try engine.start()
        } catch {
            throw VoiceError.engineFailed(error.localizedDescription)
        }
        state = .recording
    }

    private func ingest(_ buffer: AVAudioPCMBuffer) {
        guard let converter = converter else { return }

        // Over-allocate the output buffer — AVAudioConverter will write at
        // most this many frames, typically far fewer at 16 kHz.
        let capacity = AVAudioFrameCount(
            Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate + 1024
        )
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if consumed {
                status.pointee = .endOfStream
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        if let channelData = out.floatChannelData?[0] {
            let count = Int(out.frameLength)
            samples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: count))
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
        await prepare()
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
