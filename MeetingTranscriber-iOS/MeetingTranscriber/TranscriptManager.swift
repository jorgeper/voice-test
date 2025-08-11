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
    // The raw identifier provided by the service for the last active line
    // (e.g., "guest-1", a real name, or "Unknown"). This is used to avoid
    // false positives when display names change (e.g., Unknown -> identified).
    private var lastRawSpeakerId: String?
    private var lastUpdateAt: Date = .distantPast
    private var rollingText: String = ""
    private let pauseThreshold: TimeInterval = 1.5
    private var lastWasFinal: Bool = false
    private var lastWasProvisionalLine: Bool = false

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
    /// Handles a single transcription hypothesis or final result emitted by the Azure SDK.
    ///
    /// Coalesces streaming partials into readable bubbles, chooses when to
    /// start a new line versus update the last one, and reconciles diarization
    /// changes (e.g., upgrading from "Unknown" to an identified speaker) while
    /// avoiding duplicate text.
    ///
    /// - Parameters:
    ///   - text: The recognized text for this event. Empty strings are ignored.
    ///   - speakerId: The service-provided speaker identifier (e.g., "guest-1",
    ///     "Unknown", or a known name). It is normalized to a display label via
    ///     `displayName(for:)` and used to group/update conversation bubbles.
    ///   - isFinal: Whether this event represents a finalized segment from the
    ///     service. Finals influence line breaks and de-duplication decisions.
    ///
    /// - Note: UI updates are dispatched onto the main queue via the delegate.
    ///
    /// - Logic overview:
    ///   1. Normalize incoming `text` and the current rolling text for overlap checks.
    ///   2. Derive a displayable speaker label and detect if a speaker change is
    ///      likely a refinement (Unknown -> identified) based on text overlap.
    ///   3. Decide whether to start a new line when the speaker truly changes,
    ///      when there is a pause after a final, or when no rolling text exists.
    ///   4. If starting a new line, emit `didReceiveSegment`; otherwise, update
    ///      the existing line with the newer/better hypothesis via `didUpdateLastSegment`.
    ///   5. Maintain internal state (`lastSpeakerId`, `rollingText`, timestamps,
    ///      and flags) to inform future coalescing decisions.
    func didTranscribe(text: String, speakerId: String?, isFinal: Bool) {
        guard !text.isEmpty else { return }
        // rawSpeaker: The untouched identifier from the service, or a fallback of
        // "Unknown" when the incoming `speakerId` is nil/empty.
        let rawSpeaker = speakerId?.isEmpty == false ? speakerId! : "Unknown"
        // Always render unknown as provisional label; do NOT reuse the last speaker
        // speaker: Human-friendly display label derived from `rawSpeaker` for UI grouping.
        let speaker: String = displayName(for: rawSpeaker)
        // now: Timestamp of this callback; used to decide pause-based line breaks.
        let now = Date()
        // normalizedNew: Lowercased, punctuation/whitespace-normalized form of `text` for overlap checks.
        let normalizedNew = normalize(text)
        // normalizedRolling: Normalized form of the currently shown (rolling) text, for comparisons.
        let normalizedRolling = normalize(rollingText)

        // Treat Unknown -> identified as same speaker if text overlaps significantly
        // speakerChangedButLikelySame: Heuristic that treats a transition from an
        // unknown label to an identified speaker as the same person when the text
        // matches/overlaps, avoiding unnecessary new bubbles.
        let overlapsNewWithRolling = normalizedNew.contains(normalizedRolling) || normalizedRolling.contains(normalizedNew)
        let lastWasUnknownDisplay = (lastSpeakerId == "Speaker ?")
        let lastWasUnknownRaw = (lastRawSpeakerId == "Unknown")
        let speakerChangedButLikelySame = ((lastWasUnknownDisplay || lastWasUnknownRaw) && rawSpeaker != "Unknown" && !rollingText.isEmpty && overlapsNewWithRolling)

        // sameSpeaker: Whether we consider this event to belong to the same speaker line.
        let sameSpeaker = (lastRawSpeakerId != nil && rawSpeaker == lastRawSpeakerId) || (speaker == lastSpeakerId) || speakerChangedButLikelySame
        // Start a new line only when speaker truly changes, or after a pause following a finalized segment
        // shouldStartNewLine: Primary decision flag for creating a fresh bubble vs. updating the last one.
        var shouldStartNewLine = !sameSpeaker || ((now.timeIntervalSince(lastUpdateAt) > pauseThreshold) && lastWasFinal) || rollingText.isEmpty

        // If the new hypothesis overlaps the rolling text and it's the same speaker, keep replacing instead of starting a new line
        if shouldStartNewLine && sameSpeaker {
            // overlaps: Whether new and rolling text share substantial content (in either direction).
            let overlaps = overlapsNewWithRolling
            if overlaps { shouldStartNewLine = false }
        }

        // If this is a final from the same speaker and it's a refinement of the current line, do NOT start new line
        if isFinal && sameSpeaker && !rollingText.isEmpty {
            if normalizedNew.contains(normalizedRolling) || normalizedRolling.contains(normalizedNew) {
                shouldStartNewLine = false
            }
        }

        // Merge when diarization flips speaker mid-utterance (overlapping text within a short window)
        if !sameSpeaker && !rollingText.isEmpty {
            // closeInTime: Guards against merging when the handoff is not temporally close.
            let closeInTime = now.timeIntervalSince(lastUpdateAt) < 1.5
            // overlap: Confirms that the content appears to be a refinement rather than a new utterance.
            let overlap = overlapsNewWithRolling
            // Upgrade the existing bubble when content strongly overlaps within a short window.
            // This handles diarization flips mid-utterance (e.g., Unknown -> identified, or guest-1 -> guest-2).
            if closeInTime && overlap {
                lastSpeakerId = speaker
                lastRawSpeakerId = rawSpeaker
                rollingText = normalizedNew.count >= normalizedRolling.count ? text : rollingText
                lastUpdateAt = now
                // combined: `speaker` label + `rollingText` as an attributed string for UI rendering.
                let combined = makeAttributed(speaker: displayName(for: speaker), text: rollingText)
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.didUpdateLastSegment(combined)
                }
                lastWasFinal = isFinal
                lastWasProvisionalLine = (speaker == "Speaker ?")
                return
            }
        }

        if shouldStartNewLine {
            rollingText = text
            lastSpeakerId = speaker
            lastRawSpeakerId = rawSpeaker
            lastUpdateAt = now
            // combined: New bubble content built from the current `speaker` and `rollingText`.
            let combined = makeAttributed(speaker: speaker, text: rollingText)
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didReceiveSegment(combined)
            }
            lastWasProvisionalLine = (speaker == "Speaker ?")
            // Reset final flag for a fresh line so delayed finals don't spawn duplicates
            lastWasFinal = isFinal
            return
        }

        // Same speaker in active window: replace with the newest hypothesis to avoid duplicates
        if normalizedNew == normalizedRolling {
            // identical text; nothing to change
        } else if normalizedNew.contains(normalizedRolling) || isFinal {
            rollingText = text
        } else if normalizedRolling.contains(normalizedNew) {
            // keep existing longer text
        } else {
            // fallback: prefer newer hypothesis without concatenation to avoid duplication
            rollingText = text
        }
        lastUpdateAt = now
        // If we upgraded speaker from Unknown -> identified, rebuild with new label
        if speakerChangedButLikelySame { lastSpeakerId = speaker; lastRawSpeakerId = rawSpeaker }
        // combined: Updated content for the existing bubble with possibly upgraded speaker label.
        let combined = makeAttributed(speaker: lastSpeakerId ?? speaker, text: rollingText)
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didUpdateLastSegment(combined)
        }
        lastWasFinal = isFinal
        lastWasProvisionalLine = (lastSpeakerId == "Speaker ?")
    }

    func didError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didReceiveError(message)
        }
    }
}

private extension TranscriptManager {
    func displayName(for serviceSpeakerId: String) -> String {
        if serviceSpeakerId.lowercased().hasPrefix("guest-") {
            let num = serviceSpeakerId.split(separator: "-").last.map(String.init) ?? "?"
            return "Speaker \(num)"
        }
        if serviceSpeakerId == "Unknown" { return "Speaker ?" }
        return serviceSpeakerId
    }
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

