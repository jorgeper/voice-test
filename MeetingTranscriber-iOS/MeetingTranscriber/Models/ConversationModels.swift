import Foundation

struct TranscriptLine: Identifiable, Equatable {
    let id: UUID = UUID()
    var speaker: String
    var text: String
    let timestamp: Date
}

