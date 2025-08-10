import Foundation
import SwiftUI

enum SpeakerColors {
    // Shared deterministic palette
    // Pleasant, balanced mid-tone palette (good contrast with white text)
    static let palette: [String] = [
        "#2563EB", // blue
        "#0EA5E9", // sky
        "#06B6D4", // cyan
        "#0D9488", // teal
        "#059669", // emerald
        "#84CC16", // lime green (darker)
        "#CA8A04", // amber
        "#D97706", // orange
        "#DC2626", // red
        "#DB2777", // rose
        "#7C3AED", // violet
        "#6366F1"  // indigo
    ]

    static func colorHex(for speaker: String) -> String {
        // Stable mapping based on name hash
        let index = abs(speaker.hashValue) % palette.count
        return palette[index]
    }
}

