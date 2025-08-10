import SwiftUI

struct SpeakerCloudView: View {
    let speakers: [String]
    let known: [KnownSpeaker]

    var body: some View {
        let filtered = speakers.filter { !$0.isEmpty && $0 != "Speaker ?" }
        let counts = Dictionary(filtered.map { ($0, 1) }, uniquingKeysWith: +)
        let unique = Array(counts.keys)
        let maxCount = max(counts.values.max() ?? 1, 1)
        HStack(spacing: -12) {
            ForEach(Array(unique.enumerated()), id: \.offset) { idx, name in
                let count = counts[name] ?? 1
                let size = sizeForCount(count, maxCount: maxCount)
                SpeakerAvatarView(name: name, known: known)
                    .frame(width: size, height: size)
                    .offset(y: offsetForIndex(idx))
            }
        }
        .frame(height: 72)
    }

    private func sizeForCount(_ c: Int, maxCount: Int) -> CGFloat {
        let minSize: CGFloat = 28
        let maxSize: CGFloat = 56
        let t = CGFloat(c) / CGFloat(maxCount)
        return minSize + (maxSize - minSize) * t
    }

    private func offsetForIndex(_ i: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, 8, -6, 10, -8, 6, -4, 4]
        return i < pattern.count ? pattern[i] : 0
    }
}

