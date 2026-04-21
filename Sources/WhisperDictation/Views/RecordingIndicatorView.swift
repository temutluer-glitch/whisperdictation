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
                BarsWaveformView(recorder: recorder)
                    .frame(width: 64, height: 20)
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

final class WaveformAnimator: ObservableObject {
    @Published private(set) var bars: [CGFloat]

    private let barCount: Int
    private let attackTime: TimeInterval
    private let releaseTime: TimeInterval

    private var smoothLevel: CGFloat = 0
    private var lastTick: Date = Date()
    private var timer: Timer?

    init(barCount: Int, attackTime: TimeInterval, releaseTime: TimeInterval) {
        self.barCount = barCount
        self.attackTime = attackTime
        self.releaseTime = releaseTime
        self.bars = Array(repeating: 0, count: barCount)
    }

    func start(levelProvider: @escaping () -> Float) {
        stop()
        lastTick = Date()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick(level: levelProvider())
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick(level: Float) {
        let now = Date()
        let dt = max(0.001, now.timeIntervalSince(lastTick))
        lastTick = now

        let target = CGFloat(level)
        let attack: CGFloat = 1.0 - exp(-CGFloat(dt) / CGFloat(attackTime))
        let release: CGFloat = 1.0 - exp(-CGFloat(dt) / CGFloat(releaseTime))
        let coeff = target > smoothLevel ? attack : release
        smoothLevel += (target - smoothLevel) * coeff
        if smoothLevel < 0.02 { smoothLevel = 0 }

        var next = bars
        next.removeFirst()
        next.append(smoothLevel)
        bars = next
    }
}

struct BarsWaveformView: View {
    let recorder: AudioRecorder

    private let barCount = 18
    private let barWidth: CGFloat = 2
    private let maxBarHeight: CGFloat = 18
    private let minBarHeight: CGFloat = 2.5

    @StateObject private var animator = WaveformAnimator(
        barCount: 18,
        attackTime: 0.013,
        releaseTime: 0.033
    )

    var body: some View {
        Canvas { context, size in
            draw(into: &context, size: size)
        }
        .onAppear {
            animator.start { [recorder] in recorder.currentLevel }
        }
        .onDisappear {
            animator.stop()
        }
    }

    private func draw(into context: inout GraphicsContext, size: CGSize) {
        let history = animator.bars
        let totalBarsWidth = barWidth * CGFloat(barCount)
        let spacing = (size.width - totalBarsWidth) / CGFloat(max(1, barCount - 1))
        let midY = size.height / 2

        for i in 0..<min(barCount, history.count) {
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
