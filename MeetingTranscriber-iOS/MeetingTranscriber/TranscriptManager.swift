import Foundation
import AVFoundation

protocol TranscriptManagerDelegate: AnyObject {
    func didReceiveSegment(_ segment: AttributedString)
    func didReceiveError(_ message: String)
}

final class TranscriptManager: NSObject {
    static let shared = TranscriptManager()

    weak var delegate: TranscriptManagerDelegate?

    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode? { audioEngine.inputNode }

    private let session = AVAudioSession.sharedInstance()

    private let azure = AzureTranscriber()

    private override init() { super.init(); azure.delegate = self }

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
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetooth, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startEngine() throws {
        guard let inputNode = inputNode else { throw NSError(domain: "TranscriptManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No input node"]) }

        let inputFormat = inputNode.inputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)!

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
    }
}

extension TranscriptManager: AzureTranscriberDelegate {
    func didTranscribe(text: String, speakerId: String?) {
        guard !text.isEmpty else { return }
        let label = speakerId?.isEmpty == false ? speakerId! : "Unknown"
        var speaker = AttributedString("\(label): ")
        speaker.foregroundColor = .secondary
        var content = AttributedString(text)
        var combined = speaker
        combined.append(content)
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveSegment(combined)
        }
    }

    func didError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveError(message)
        }
    }
}

