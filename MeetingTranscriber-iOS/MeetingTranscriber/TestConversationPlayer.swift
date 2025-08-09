import Foundation
import AVFoundation

final class TestConversationPlayer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var isRunningInternal = false
    private var currentLineIndex = 0
    private var nextWorkItem: DispatchWorkItem?

    private struct ScriptLine { let speaker: String; let text: String }

    // Deterministic script stored as "speaker: text" pairs
    private let script: [ScriptLine] = [
        .init(speaker: "Alex", text: "Morning team, quick stand-up: we’re finalizing the onboarding flow today."),
        .init(speaker: "Samantha", text: "I pushed the new welcome screens last night, but analytics gating needs a review."),
        .init(speaker: "Daniel", text: "Jorge, can you confirm the event names for the funnel?"),
        .init(speaker: "Alex", text: "Yep, renamed signup start to onboarding begin and added step labels."),
        .init(speaker: "Samantha", text: "We still need a guard so we don’t double report when users bounce back."),
        .init(speaker: "Daniel", text: "After lunch I’ll also run the A/B test export and update the dashboard."),
        .init(speaker: "Alex", text: "Perfect. I’ll wire the gating to the new IDs and check dashboards."),
        .init(speaker: "Samantha", text: "By the way, support reported that the microphone permission sheet appears twice."),
        .init(speaker: "Daniel", text: "I saw it once on simulator; could be restarting the audio engine during the alert."),
        .init(speaker: "Alex", text: "Let’s add a debounce so we never present it twice. I can tackle that."),
        .init(speaker: "Samantha", text: "Great. For the demo we’ll run a one‑minute mock conversation and record it."),
        .init(speaker: "Daniel", text: "If the transcript looks solid we’ll ship a TestFlight build tonight."),
        .init(speaker: "Alex", text: "Any blockers before we wrap?"),
        .init(speaker: "Samantha", text: "None from me. I’ll polish the UI spacing on the transcript bubbles."),
        .init(speaker: "Daniel", text: "I’ll validate diarization and clean up duplicate lines in the coalescer."),
        .init(speaker: "Alex", text: "Awesome. Thanks everyone—let’s get this out!"),
    ]

    // Voice assignment for each speaker
    private let speakerVoices: [String: String] = [
        "Alex": "en-US",
        "Samantha": "en-US",
        "Daniel": "en-GB"
    ]

    // Roughly ~60s at the configured rate and pauses by looping the script

    var isRunning: Bool { isRunningInternal }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start() {
        guard !isRunningInternal else { return }
        isRunningInternal = true
        currentLineIndex = 0
        scheduleNext(after: 0.1)
    }

    func stop() {
        isRunningInternal = false
        nextWorkItem?.cancel()
        nextWorkItem = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func scheduleNext(after delay: TimeInterval) {
        guard isRunningInternal else { return }
        let work = DispatchWorkItem { [weak self] in self?.speakRandomUtterance() }
        nextWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func speakRandomUtterance() {
        guard isRunningInternal else { return }
        let line = script[currentLineIndex % script.count]
        currentLineIndex += 1

        let utterance = AVSpeechUtterance(string: line.text)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.35
        let lang = speakerVoices[line.speaker] ?? "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: lang)

        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        scheduleNext(after: 0.25)
    }
}

