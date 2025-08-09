import SwiftUI

enum RecordingState {
    case idle, recording, paused
}

struct ContentView: View {
    @StateObject private var model = ContentViewModel()

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
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(model.transcriptItems.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 6) {
                            if index == 0 || model.transcriptItems[index - 1].speaker != item.speaker {
                                Text(item.speaker)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                            }
                            Text(item.text)
                                .font(.system(.body, design: .rounded))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color(UIColor.separator), lineWidth: 0.25)
                                )
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
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


