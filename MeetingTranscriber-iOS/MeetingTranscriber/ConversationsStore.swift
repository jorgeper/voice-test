import Foundation
import SwiftUI

struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var lastSnippet: String
    var date: Date
    var participants: [String]
}

final class ConversationsStore: ObservableObject {
    @Published var items: [Conversation] = [] {
        didSet { persist() }
    }

    private let storageKey = "conversations_store_items"

    init() { load() }

    func createNewConversation() -> Conversation {
        let c = Conversation(id: UUID(), title: "New Conversation", lastSnippet: "", date: Date(), participants: [])
        items.insert(c, at: 0)
        return c
    }

    func updateConversation(id: UUID, snippet: String?, participants: [String]?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var c = items[idx]
        if let s = snippet, !s.isEmpty { c.lastSnippet = s; c.title = inferredTitle(from: c) }
        if let p = participants { c.participants = p }
        c.date = Date()
        items[idx] = c
    }

    private func inferredTitle(from c: Conversation) -> String {
        if !c.participants.isEmpty { return c.participants.joined(separator: ", ") }
        if !c.lastSnippet.isEmpty { return String(c.lastSnippet.prefix(32)) }
        return c.title
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: storageKey) }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey), let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            items = decoded
        }
    }
}

