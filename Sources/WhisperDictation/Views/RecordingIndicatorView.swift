import SwiftUI

struct RecordingIndicatorView: View {
    let status: DictationStatus
    @ObservedObject var recorder: AudioRecorder

    var body: some View {
        ZStack {
            Capsule()
                .fill(.black.opacity(0.88))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 3)

            content
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(height: 34)
        .fixedSize()
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .recording:
            HStack(spacing: 8) {
                PulseDot()
                BarsWaveformView(level: recorder.currentLevel)
                    .frame(width: 96, height: 20)
            }
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

private struct PulseDot: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 7, height: 7)
            .scaleEffect(pulse ? 1.0 : 0.7)
            .opacity(pulse ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

struct BarsWaveformView: View {
    let level: Float

    private let barCount = 18
    private let maxBarHeight: CGFloat = 18
    private let minBarHeight: CGFloat = 2.5

    @State private var history: [CGFloat]
    @State private var smoothLevel: CGFloat = 0
    @State private var lastTick: Date = Date()

    init(level: Float) {
        self.level = level
        _history = State(initialValue: Array(repeating: 0, count: 18))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                advance(to: timeline.date)
                draw(into: &context, size: size)
            }
        }
    }

    private func advance(to now: Date) {
        let dt = max(0.001, now.timeIntervalSince(lastTick))
        lastTick = now

        let target = CGFloat(level)
        let attack: CGFloat = 1.0 - exp(-CGFloat(dt) / 0.04)
        let release: CGFloat = 1.0 - exp(-CGFloat(dt) / 0.10)
        let coeff = target > smoothLevel ? attack : release
        smoothLevel += (target - smoothLevel) * coeff
        if smoothLevel < 0.02 { smoothLevel = 0 }

        history.removeFirst()
        history.append(smoothLevel)
    }

    private func draw(into context: inout GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 2
        let totalSpacing = spacing * CGFloat(barCount - 1)
        let barWidth = max(2, (size.width - totalSpacing) / CGFloat(barCount))
        let midY = size.height / 2

        for i in 0..<barCount {
            let value = history[i]
            let envelope = sin((CGFloat(i) + 0.5) / CGFloat(barCount) * .pi)
            let magnitude = value * envelope
            let height = max(minBarHeight, magnitude * maxBarHeight)
            let x = CGFloat(i) * (barWidth + spacing)
            let rect = CGRect(
                x: x,
                y: midY - height / 2,
                width: barWidth,
                height: height
            )
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
            let alpha = 0.55 + 0.45 * value
            context.fill(path, with: .color(.white.opacity(Double(alpha))))
        }
    }
}
