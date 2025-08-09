import Foundation

struct SpeakerAttributedSegment {
    let speakerLabel: String
    let text: String
    let timestamp: Date

    var attributed: AttributedString {
        var speaker = AttributedString("\(speakerLabel): ")
        speaker.foregroundColor = .secondary
        var content = AttributedString(text)
        var combined = speaker
        combined.append(content)
        return combined
    }
}

