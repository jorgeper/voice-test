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
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(model.transcriptLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.body, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
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


