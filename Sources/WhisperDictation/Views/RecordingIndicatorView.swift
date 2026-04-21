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
            BarsWaveformView(recorder: recorder)
                .frame(width: 96, height: 20)
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

@MainActor
final class WaveformAnimator: ObservableObject {
    @Published private(set) var bars: [CGFloat]

    private let barCount: Int
    private var smoothLevel: CGFloat = 0
    private var timer: Timer?
    private weak var recorder: AudioRecorder?
    private var lastTick = Date()

    init(barCount: Int) {
        self.barCount = barCount
        self.bars = Array(repeating: 0, count: barCount)
    }

    func start(recorder: AudioRecorder) {
        stop()
        self.recorder = recorder
        self.lastTick = Date()
        self.smoothLevel = 0
        self.bars = Array(repeating: 0, count: barCount)
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder = nil
    }

    private func tick() {
        guard let recorder else { return }
        let now = Date()
        let dt = max(0.001, now.timeIntervalSince(lastTick))
        lastTick = now

        let target = CGFloat(recorder.currentLevel)
        let attackTau: CGFloat = 0.03
        let releaseTau: CGFloat = 0.12
        let tau = target > smoothLevel ? attackTau : releaseTau
        let coeff = 1.0 - exp(-CGFloat(dt) / tau)
        smoothLevel += (target - smoothLevel) * coeff
        if smoothLevel < 0.015 { smoothLevel = 0 }

        var next = bars
        next.removeFirst()
        next.append(smoothLevel)
        bars = next
    }
}

struct BarsWaveformView: View {
    @ObservedObject var recorder: AudioRecorder
    @StateObject private var animator = WaveformAnimator(barCount: 10)

    private let maxBarHeight: CGFloat = 18
    private let minBarHeight: CGFloat = 2.5

    var body: some View {
        Canvas { context, size in
            draw(into: &context, size: size, bars: animator.bars)
        }
        .onAppear { animator.start(recorder: recorder) }
        .onDisappear { animator.stop() }
    }

    private func draw(into context: inout GraphicsContext, size: CGSize, bars: [CGFloat]) {
        let count = bars.count
        guard count > 0 else { return }
        let spacing: CGFloat = 3
        let totalSpacing = spacing * CGFloat(count - 1)
        let barWidth = max(2, (size.width - totalSpacing) / CGFloat(count))
        let midY = size.height / 2

        for i in 0..<count {
            let value = bars[i]
            let envelope = sin((CGFloat(i) + 0.5) / CGFloat(count) * .pi)
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
