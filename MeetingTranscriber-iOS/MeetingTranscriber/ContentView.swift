import SwiftUI

enum RecordingState {
    case idle, recording, paused
}

struct ContentView: View {
    @StateObject private var model = ContentViewModel()
    @StateObject private var tester = TestConversationPlayer()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: model.toggleRecording) {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .padding(10)
                        .background(Circle().fill(buttonColor.opacity(0.15)))
                        .foregroundStyle(buttonColor)
                }
                .padding(.top, 14)
                .padding(.trailing, 16)
                Button(action: toggleTest) {
                    Text(tester.isRunning ? "Stop test" : "Start test")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
                }
                .padding(.top, 14)
                .padding(.trailing, 16)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let enumerated = Array(model.transcriptItems.enumerated())
                        ForEach(enumerated, id: \.element.id) { index, item in
                            let isSameAsPrevious = index > 0 && model.transcriptItems[index - 1].speaker == item.speaker
                            VStack(alignment: .leading, spacing: isSameAsPrevious ? 4 : 8) {
                                if !isSameAsPrevious {
                                    Text(item.speaker)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                }
                                Text(item.text)
                                    .font(.system(.body, design: .rounded))
                                    .padding(.vertical, 12)
                                    .padding(.leading, 18)
                                    .padding(.trailing, 12)
                                    .background(
                                        LeftBubbleShape(cornerRadius: 18, tailSize: 8)
                                            .fill(Color(UIColor.secondarySystemBackground))
                                    )
                                    .overlay(
                                        LeftBubbleShape(cornerRadius: 18, tailSize: 8)
                                            .stroke(Color(UIColor.separator).opacity(0.6), lineWidth: 0.5)
                                    )
                                    .padding(.horizontal, 16)
                                    .id(item.id)
                            }
                            .padding(.top, isSameAsPrevious ? 4 : 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .onChange(of: model.transcriptItems) { items in
                    guard let last = items.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .background(Color(UIColor.systemBackground))
        }
        .background(Color(UIColor.secondarySystemBackground))
        .onAppear { model.onAppear() }
        .alert("Error", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var iconName: String {
        switch model.recordingState {
        case .idle: return "record.circle.fill"
        case .recording: return "pause.circle.fill"
        case .paused: return "stop.circle.fill"
        }
    }

    private var buttonColor: Color {
        switch model.recordingState {
        case .idle: return .red
        case .recording: return .orange
        case .paused: return .blue
        }
    }
}

private extension ContentView {
    func toggleTest() {
        if tester.isRunning {
            tester.stop()
        } else {
            tester.start()
        }
    }
}


