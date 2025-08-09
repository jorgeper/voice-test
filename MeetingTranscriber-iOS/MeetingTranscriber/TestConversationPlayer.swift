import Foundation
import AVFoundation

final class TestConversationPlayer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var isRunningInternal = false
    private var currentSpeakerIndex = 0
    private var nextWorkItem: DispatchWorkItem?

    private let speakers: [(name: String, voiceId: String)] = [
        ("Alex", "en-US"),
        ("Samantha", "en-US"),
        ("Daniel", "en-GB")
    ]

    private let sampleLines: [String] = [
        "Hey, this is a test. Hello, hello.",
        "I'm loving this. This is looking great.",
        "What's up?",
        "Let's try a longer sentence to simulate natural speech and pauses.",
        "Can you hear me clearly from your side?",
        "Okay, let's continue with the meeting notes.",
        "Thank you all for joining today.",
        "Do we have any blockers or questions?",
        "Sounds good to me.",
        "Let's wrap up in a minute."
    ]

    var isRunning: Bool { isRunningInternal }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start() {
        guard !isRunningInternal else { return }
        isRunningInternal = true
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
        let line = sampleLines.randomElement() ?? "Testing one two three."
        let speaker = speakers[currentSpeakerIndex % speakers.count]
        currentSpeakerIndex += 1

        let utterance = AVSpeechUtterance(string: line)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.2
        utterance.voice = AVSpeechSynthesisVoice(language: speaker.voiceId)

        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        scheduleNext(after: 0.4)
    }
}

