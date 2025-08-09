import Foundation
import Combine

final class ContentViewModel: ObservableObject, TranscriptManagerDelegate {
    @Published var recordingState: RecordingState = .idle
    @Published var transcriptLines: [AttributedString] = []
    @Published var errorMessage: String?

    func onAppear() {
        TranscriptManager.shared.delegate = self
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
        transcriptLines.append(segment)
    }

    func didUpdateLastSegment(_ segment: AttributedString) {
        guard !transcriptLines.isEmpty else {
            transcriptLines = [segment]
            return
        }
        transcriptLines[transcriptLines.count - 1] = segment
    }

    func didReceiveError(_ message: String) {
        errorMessage = message
    }
}

