import SwiftUI

struct RecordingIndicatorView: View {
    let status: DictationStatus
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        )
        .onAppear { isPulsing = true }
    }

    private var dotColor: Color {
        switch status {
        case .recording: return .red
        case .transcribing, .processing: return .yellow
        default: return .gray
        }
    }

    private var backgroundColor: Color {
        .black.opacity(0.75)
    }

    private var label: String {
        switch status {
        case .recording: return "Aufnahme…"
        case .transcribing: return "Transkribiere…"
        case .processing: return "Verarbeite…"
        default: return ""
        }
    }
}
