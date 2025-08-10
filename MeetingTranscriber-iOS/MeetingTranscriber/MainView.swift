import SwiftUI

struct MainView: View {
    @StateObject private var store = ConversationsStore()
    @State private var showingConversation = false
    @State private var activeConversationId: UUID?

    var body: some View {
        NavigationView {
            List {
                ForEach(store.items) { convo in
                    Button {
                        activeConversationId = convo.id
                        showingConversation = true
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(Color(UIColor.systemGray5)).frame(width: 44, height: 44)
                                .overlay(Text(initials(from: convo)).font(.headline))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(convo.title).font(.headline)
                                Text(convo.lastSnippet).lineLimit(1).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(Self.timeFormatter.string(from: convo.date)).foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { store.items.remove(atOffsets: $0) }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startNewConversation) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingConversation) {
                ConversationContainerView(conversationId: activeConversationId, store: store)
            }
        }
    }

    private func startNewConversation() {
        let c = store.createNewConversation()
        activeConversationId = c.id
        showingConversation = true
    }

    private func initials(from c: Conversation) -> String {
        if let first = c.participants.first, let f = first.first { return String(f) }
        return "?"
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

struct ConversationContainerView: View {
    let conversationId: UUID?
    @ObservedObject var store: ConversationsStore

    var body: some View {
        NavigationView {
            ContentView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Back") { dismiss() } }
                }
        }
    }

    @Environment(\ .dismiss) private var dismiss
}

