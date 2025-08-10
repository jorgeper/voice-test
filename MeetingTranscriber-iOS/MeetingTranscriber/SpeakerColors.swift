import Foundation
import SwiftUI

enum SpeakerColors {
    // Shared deterministic palette
    static let palette: [String] = [
        "#3B82F6", "#10B981", "#F59E0B", "#EF4444",
        "#8B5CF6", "#14B8A6", "#F97316", "#06B6D4",
        "#6366F1", "#22C55E", "#DB2777", "#84CC16"
    ]

    static func colorHex(for speaker: String) -> String {
        // Stable mapping based on name hash
        let index = abs(speaker.hashValue) % palette.count
        return palette[index]
    }
}

