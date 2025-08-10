import SwiftUI

struct SpeakerCloudView: View {
    let speakers: [String]
    let known: [KnownSpeaker]

    var body: some View {
        let filtered = speakers.filter { !$0.isEmpty && $0 != "Speaker ?" }
        let counts = Dictionary(filtered.map { ($0, 1) }, uniquingKeysWith: +)
        // Preserve order of first appearance so avatars don't jump around
        let order = orderedUnique(from: speakers)
        let unique = order.filter { counts.keys.contains($0) }

        // Determine a center-dominant arrangement
        let indexMap = Dictionary(unique.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let ranked = unique.sorted { a, b in
            let ca = counts[a] ?? 0
            let cb = counts[b] ?? 0
            if ca != cb { return ca > cb }
            return (indexMap[a] ?? 0) < (indexMap[b] ?? 0)
        }
        let center = ranked.first
        let rest = Array(ranked.dropFirst())
        let left: [String] = rest.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        let right: [String] = rest.enumerated().filter { $0.offset % 2 != 0 }.map { $0.element }

        GeometryReader { geo in
            let layout = buildLayout(center: center, left: left, right: right, counts: counts, totalWidth: geo.size.width)
            ZStack {
                ForEach(Array(layout.enumerated()), id: \.offset) { _, item in
                    SpeakerAvatarView(name: item.name, known: known)
                        .frame(width: item.size, height: item.size)
                        .position(x: geo.size.width/2 + item.x, y: geo.size.height/2 + item.y)
                        .zIndex(item.z)
                }
            }
        }
        .frame(height: 100)
    }

    private func sizeForCount(_ c: Int, minCount: Int, maxCount: Int, centerBoost: Bool = false) -> CGFloat {
        let base: CGFloat = 32 // minimum visual size
        let maxExtra: CGFloat = 20 // up to +20dp based on contribution
        let minC = CGFloat(minCount)
        let maxC = CGFloat(max(maxCount, minCount + 1))
        let t = (CGFloat(c) - minC) / (maxC - minC)
        let size = base + maxExtra * max(0, min(1, t))
        return size + (centerBoost ? 4 : 0)
    }

    private struct LayoutItem { let name: String; let size: CGFloat; let x: CGFloat; let y: CGFloat; let z: Double }

    private func buildLayout(center: String?, left: [String], right: [String], counts: [String: Int], totalWidth: CGFloat) -> [LayoutItem] {
        var items: [LayoutItem] = []
        let values = counts.values
        let minCount = values.min() ?? 1
        let maxCount = values.max() ?? 1
        let margin: CGFloat = 6 // ensure no touching
        // Center
        if let c = center {
            let size = sizeForCount(counts[c] ?? 1, minCount: minCount, maxCount: maxCount, centerBoost: true)
            items.append(LayoutItem(name: c, size: size, x: 0, y: 0, z: 10))
        }
        let centerSize = items.first?.size ?? 36
        let leftItems = sideLayout(names: left.reversed(), counts: counts, direction: -1, minCount: minCount, maxCount: maxCount, startFrom: centerSize, margin: margin)
        let rightItems = sideLayout(names: right, counts: counts, direction: 1, minCount: minCount, maxCount: maxCount, startFrom: centerSize, margin: margin)
        items.append(contentsOf: leftItems)
        items.append(contentsOf: rightItems)
        // Clamp within totalWidth by shrinking offsets if needed
        let maxX = items.map { abs($0.x) + $0.size/2 }.max() ?? 0
        if maxX * 2 > totalWidth {
            let scale = (totalWidth - 16) / (maxX * 2)
            return items.map { LayoutItem(name: $0.name, size: $0.size, x: $0.x * scale, y: $0.y, z: $0.z) }
        }
        return items
    }

    private func sideLayout(names: [String], counts: [String: Int], direction: CGFloat, minCount: Int, maxCount: Int, startFrom centerSize: CGFloat, margin: CGFloat) -> [LayoutItem] {
        var out: [LayoutItem] = []
        var previousRadius: CGFloat = centerSize / 2
        var runningX: CGFloat = previousRadius
        for (idx, name) in names.enumerated() {
            let size = sizeForCount(counts[name] ?? 1, minCount: minCount, maxCount: maxCount)
            let radius = size / 2
            // position so edges do not touch: prevRadius + margin + radius
            runningX += margin + radius
            let wave: CGFloat = [6, -4, 8, -6, 4, -2][idx % 6]
            let item = LayoutItem(name: name, size: size, x: direction * runningX, y: wave, z: Double(5 - idx))
            out.append(item)
            runningX += radius
            previousRadius = radius
        }
        return out
    }

    private func orderedUnique(from list: [String]) -> [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for s in list where s != "Speaker ?" {
            if !seen.contains(s) { seen.insert(s); out.append(s) }
        }
        return out
    }
}

