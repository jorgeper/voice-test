import Foundation
import Combine

final class ContentViewModel: ObservableObject, TranscriptManagerDelegate {
    @Published var recordingState: RecordingState = .idle
    @Published var transcriptItems: [TranscriptLine] = []
    @Published var errorMessage: String?
    @Published var knownSpeakers: [KnownSpeaker] = [] {
        didSet { persistSpeakers() }
    }

    func onAppear() {
        TranscriptManager.shared.delegate = self
        loadSpeakers()
    }

    func toggleRecording() {
        switch recordingState {
        case .idle:
            Task { await start() }
        case .recording:
            TranscriptManager.shared.pause()
            recordingState = .paused
        case .paused:
            TranscriptManager.shared.stop()
            recordingState = .idle
        }
    }

    private func start() async {
        do {
            try await TranscriptManager.shared.start()
            await MainActor.run { self.recordingState = .recording }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.recordingState = .idle
            }
        }
    }

    // MARK: - TranscriptManagerDelegate
    func didReceiveSegment(_ segment: AttributedString) {
        // Expect format "Speaker: text" from manager helper
        let parts = segment.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let speaker = String(parts.first.map(String.init) ?? "Unknown")
        let text = String(parts.dropFirst().joined()) .trimmingCharacters(in: .whitespaces)
        transcriptItems.append(TranscriptLine(speaker: speaker, text: text, timestamp: Date()))
    }

    func didUpdateLastSegment(_ segment: AttributedString) {
        guard !transcriptItems.isEmpty else {
            let parts = segment.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let speaker = String(parts.first.map(String.init) ?? "Unknown")
            let text = String(parts.dropFirst().joined()) .trimmingCharacters(in: .whitespaces)
            transcriptItems = [TranscriptLine(speaker: speaker, text: text, timestamp: Date())]
            return
        }
        let parts = segment.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let speaker = String(parts.first.map(String.init) ?? "Unknown")
        let text = String(parts.dropFirst().joined()) .trimmingCharacters(in: .whitespaces)
        transcriptItems[transcriptItems.count - 1].speaker = speaker
        transcriptItems[transcriptItems.count - 1].text = text
    }

    func didReceiveError(_ message: String) {
        errorMessage = message
    }
}

// MARK: - Persistence
private extension ContentViewModel {
    func persistSpeakers() {
        if let data = try? JSONEncoder().encode(knownSpeakers) {
            UserDefaults.standard.set(data, forKey: "knownSpeakers")
        }
    }
    func loadSpeakers() {
        if let data = UserDefaults.standard.data(forKey: "knownSpeakers"), let arr = try? JSONDecoder().decode([KnownSpeaker].self, from: data) {
            knownSpeakers = arr
        }
    }
}

