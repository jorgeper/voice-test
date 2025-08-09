import Foundation
import AVFoundation

protocol TranscriptManagerDelegate: AnyObject {
    func didReceiveSegment(_ segment: AttributedString)
    func didUpdateLastSegment(_ segment: AttributedString)
    func didReceiveError(_ message: String)
}

extension TranscriptManagerDelegate {
    func didUpdateLastSegment(_ segment: AttributedString) {}
}

final class TranscriptManager: NSObject {
    static let shared = TranscriptManager()

    weak var delegate: TranscriptManagerDelegate?

    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode? { audioEngine.inputNode }
    private var tapInstalled: Bool = false

    private let session = AVAudioSession.sharedInstance()

    private let azure = AzureTranscriber()

    private override init() { super.init(); azure.delegate = self }

    // Coalescing state
    private var lastSpeakerId: String?
    private var lastUpdateAt: Date = .distantPast
    private var rollingText: String = ""
    private let pauseThreshold: TimeInterval = 1.5
    private var lastWasFinal: Bool = false

    func start() async throws {
        try await requestMicPermission()
        try configureAudioSession()
        try startEngine()
        try azure.start()
    }

    func pause() {
        audioEngine.pause()
    }

    func stop() {
        if tapInstalled, let inputNode {
            inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        audioEngine.stop()
        audioEngine.reset()
        azure.stop()
    }

    // MARK: - Private

    private func requestMicPermission() async throws {
        try await withCheckedThrowingContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "TranscriptManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"]))
                }
            }
        }
    }

    private func configureAudioSession() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.mixWithOthers, .duckOthers, .allowBluetooth, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startEngine() throws {
        guard let inputNode = inputNode else { throw NSError(domain: "TranscriptManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No input node"]) }

        let inputFormat = inputNode.inputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)!

        if tapInstalled {
            inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // Convert to 16kHz mono PCM for cloud SDKs
            let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(targetFormat.sampleRate/10))!
            var error: NSError?
            converter.convert(to: pcmBuffer, error: &error) { inPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if let error = error {
                self.delegate?.didReceiveError("Audio conversion error: \(error.localizedDescription)")
            }

            // TODO: Feed pcmBuffer to Azure stream if using push audio stream.
        }

        try audioEngine.start()
        tapInstalled = true
    }
}

extension TranscriptManager: AzureTranscriberDelegate {
    func didTranscribe(text: String, speakerId: String?, isFinal: Bool) {
        guard !text.isEmpty else { return }
        let speaker = speakerId?.isEmpty == false ? speakerId! : "Unknown"
        let now = Date()
        let normalizedNew = normalize(text)
        let normalizedRolling = normalize(rollingText)

        // Treat Unknown -> identified as same speaker if text overlaps significantly
        let speakerChangedButLikelySame = (lastSpeakerId == "Unknown" && speaker != "Unknown" && !rollingText.isEmpty && (normalizedNew.contains(normalizedRolling) || normalizedRolling.contains(normalizedNew)))

        let sameSpeaker = speaker == lastSpeakerId || speakerChangedButLikelySame
        // Start a new line only for interim hypotheses when there's a pause after a finalized segment
        let shouldStartNewLine = !sameSpeaker || ((now.timeIntervalSince(lastUpdateAt) > pauseThreshold) && lastWasFinal) || rollingText.isEmpty

        if shouldStartNewLine {
            rollingText = text
            lastSpeakerId = speaker
            lastUpdateAt = now
            let combined = makeAttributed(speaker: speaker, text: rollingText)
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didReceiveSegment(combined)
            }
            return
        }

        // Same speaker in active window: replace with the newest hypothesis to avoid duplicates
        if normalizedNew.contains(normalizedRolling) || isFinal {
            rollingText = text
        } else if normalizedRolling.contains(normalizedNew) {
            // keep existing longer text
        } else {
            // fallback: prefer newer hypothesis without concatenation to avoid duplication
            rollingText = text
        }
        lastUpdateAt = now
        // If we upgraded speaker from Unknown -> identified, rebuild with new label
        if speakerChangedButLikelySame { lastSpeakerId = speaker }
        let combined = makeAttributed(speaker: lastSpeakerId ?? speaker, text: rollingText)
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didUpdateLastSegment(combined)
        }
        lastWasFinal = isFinal
    }

    func didError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveError(message)
        }
    }
}

private extension TranscriptManager {
    func makeAttributed(speaker: String, text: String) -> AttributedString {
        var speakerAttr = AttributedString("\(speaker): ")
        speakerAttr.foregroundColor = .secondary
        var content = AttributedString(text)
        var combined = speakerAttr
        combined.append(content)
        return combined
    }

    func normalize(_ s: String) -> String {
        let lowered = s.lowercased()
        let noPunctScalars = lowered.unicodeScalars.filter { !CharacterSet.punctuationCharacters.contains($0) }
        let noPunct = String(String.UnicodeScalarView(noPunctScalars))
        let collapsed = noPunct.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

