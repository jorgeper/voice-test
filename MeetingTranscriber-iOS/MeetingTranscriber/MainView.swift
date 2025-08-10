import SwiftUI

struct MainView: View {
    @StateObject private var store = ConversationsStore()
    @State private var showingConversation = false
    @State private var activeConversationId: UUID?
    @State private var preloadData: Data?

    var body: some View {
        NavigationView {
            List {
                ForEach(store.items) { convo in
                    Button {
                        activeConversationId = convo.id
                        // Load JSON into model before presenting
                        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let fileURL = docsURL.appendingPathComponent("\(convo.id.uuidString).json")
                        print("Looking for conversation file at: \(fileURL.path)")
                        
                        if let data = try? Data(contentsOf: fileURL) {
                            print("Found conversation file: \(data.count) bytes")
                            preloadData = data
                        } else {
                            print("Failed to load conversation file")
                            preloadData = nil
                        }
                        // Ensure state updates for activeConversationId/preloadData commit
                        // before presenting the sheet
                        DispatchQueue.main.async {
                            showingConversation = true
                        }
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
            .sheet(item: $activeConversationId) { id in
                ConversationContainerView(conversationId: id, store: store, preload: preloadData)
                    .id(id) // ensure fresh state per conversation
            }
        }
    }

    private func startNewConversation() {
        let c = store.createNewConversation()
        preloadData = nil
        // Present via the item-bound sheet to avoid race conditions
        DispatchQueue.main.async { activeConversationId = c.id }
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
    var preload: Data?
    @StateObject private var model = ContentViewModel()

    var body: some View {
        NavigationView {
            ContentView(onBack: { saveAndDismiss() })
                .environmentObject(model)
        }
        .onDisappear { saveIfNeeded() }
        .onAppear {
            // Reset and load conversation data
            model.transcriptItems.removeAll()
            model.clearDirty()
            if let data = preload {
                print("Loading conversation data: \(data.count) bytes")
                model.importJSON(data)
                print("After import: \(model.transcriptItems.count) items")
            } else {
                print("No preload data for conversation")
            }
        }
        .navigationBarHidden(true)
    }

    @Environment(\ .dismiss) private var dismiss
    private func saveAndDismiss() {
        guard let id = conversationId, let data = model.exportJSON(conversationId: id) else { dismiss(); return }
        // Persist file to Documents
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("\(id.uuidString).json")
        try? data.write(to: url)
        store.updateConversation(id: id, snippet: model.lastSnippet(), participants: model.participantsList())
        model.clearDirty()
        dismiss()
    }

    private func saveIfNeeded() {
        guard model.isDirty else { return }
        saveAndDismiss()
    }
}

// Allow using UUID directly with .sheet(item:)
extension UUID: Identifiable {
    public var id: UUID { self }
}

