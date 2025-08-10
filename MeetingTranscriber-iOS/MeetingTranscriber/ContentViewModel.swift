import Foundation
import Combine

final class ContentViewModel: ObservableObject, TranscriptManagerDelegate {
    @Published var recordingState: RecordingState = .idle
    @Published var transcriptItems: [TranscriptLine] = []
    @Published var errorMessage: String?
    @Published var isDirty: Bool = false
    @Published var knownSpeakers: [KnownSpeaker] = [] {
        didSet { persistSpeakers() }
    }
    private var colorMap: [String: String] = [:]
    private let palette: [String] = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#14B8A6", "#F97316", "#06B6D4"]

    func onAppear() {
        TranscriptManager.shared.delegate = self
        loadSpeakers()
    }

    func startStop() {
        switch recordingState {
        case .idle:
            Task { await start() }
        case .recording, .paused:
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
        assignColorIfNeeded(for: speaker)
        isDirty = true
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
        assignColorIfNeeded(for: speaker)
        isDirty = true
    }

    func didReceiveError(_ message: String) {
        errorMessage = message
    }
}
// MARK: - Import/Export
extension ContentViewModel {
    struct JSONMessage: Codable { let t: String; let speaker: String; let text: String }
    struct JSONConversation: Codable { let id: String; let date: String; let participants: [String]; let messages: [JSONMessage] }

    func exportJSON(conversationId: UUID) -> Data? {
        let iso = ISO8601DateFormatter()
        let participants = Array(Set(transcriptItems.map { $0.speaker }).subtracting(["Speaker ?"]))
        let msgs = transcriptItems.map { JSONMessage(t: iso.string(from: $0.timestamp), speaker: $0.speaker, text: $0.text) }
        let convo = JSONConversation(id: conversationId.uuidString, date: iso.string(from: Date()), participants: participants, messages: msgs)
        return try? JSONEncoder().encode(convo)
    }

    func importJSON(_ data: Data) {
        if let decoded = try? JSONDecoder().decode(JSONConversation.self, from: data) {
            let iso = ISO8601DateFormatter()
            transcriptItems = decoded.messages.compactMap { msg in
                TranscriptLine(speaker: msg.speaker, text: msg.text, timestamp: iso.date(from: msg.t) ?? Date())
            }
            rebuildColors()
            isDirty = false
        }
    }

    func participantsList() -> [String] { Array(Set(transcriptItems.map { $0.speaker }).subtracting(["Speaker ?"])) }
    func lastSnippet() -> String { transcriptItems.last?.text ?? "" }
    func clearDirty() { isDirty = false }
    // Colors
    private func assignColorIfNeeded(for speaker: String) {
        guard speaker != "Speaker ?" else { return }
        if colorMap[speaker] != nil { return }
        let used = Set(colorMap.values)
        if let next = palette.first(where: { !used.contains($0) }) {
            colorMap[speaker] = next
        } else {
            colorMap[speaker] = palette[colorMap.count % palette.count]
        }
    }
    private func rebuildColors() {
        colorMap.removeAll(); for s in participantsList() { assignColorIfNeeded(for: s) }
    }
    func colorHex(for speaker: String) -> String? { colorMap[speaker] }
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

