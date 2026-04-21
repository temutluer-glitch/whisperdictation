import SwiftUI

struct RecordingIndicatorView: View {
    let status: DictationStatus
    @ObservedObject var recorder: AudioRecorder

    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.82))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(height: 36)
        .frame(minWidth: 120)
        .fixedSize()
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .recording:
            WaveformView(level: recorder.currentLevel)
                .frame(width: 90, height: 20)
        case .transcribing, .processing:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.55)
                    .tint(.white)
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
        case .error(let msg):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(msg)
                    .lineLimit(1)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
            }
        case .idle:
            EmptyView()
        }
    }

    private var label: String {
        switch status {
        case .transcribing: return "Transkribiere…"
        case .processing: return "Verarbeite…"
        default: return ""
        }
    }
}

struct WaveformView: View {
    let level: Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 4.5
            Canvas { context, size in
                draw(into: &context, size: size, phase: phase)
            }
        }
    }

    private func draw(into context: inout GraphicsContext, size: CGSize, phase: Double) {
        let amplitude = max(0.08, Double(level)) * Double(size.height) * 0.45
        let midY = Double(size.height) / 2
        let cyclesPrimary: Double = 2.4
        let cyclesSecondary: Double = 1.6
        let stepX: Double = 1.5

        var primary = Path()
        var secondary = Path()

        for x in stride(from: 0.0, through: Double(size.width), by: stepX) {
            let normalized = x / Double(size.width)
            let envelope = sin(normalized * .pi)
            let p1 = sin(normalized * cyclesPrimary * 2 * .pi + phase) * amplitude * envelope
            let p2 = sin(normalized * cyclesSecondary * 2 * .pi - phase * 0.7) * amplitude * 0.55 * envelope

            let y1 = midY + p1
            let y2 = midY + p2

            if x == 0 {
                primary.move(to: CGPoint(x: x, y: y1))
                secondary.move(to: CGPoint(x: x, y: y2))
            } else {
                primary.addLine(to: CGPoint(x: x, y: y1))
                secondary.addLine(to: CGPoint(x: x, y: y2))
            }
        }

        context.stroke(secondary, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        context.stroke(primary, with: .color(.white), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }
}
