import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var currentLevel: Float = 0

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var meterTimer: Timer?
    private(set) var startTime: Date?
    private(set) var maxLevelDb: Float = -160

    enum RecorderError: LocalizedError {
        case permissionDenied
        case recordingFailed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Mikrofon-Zugriff verweigert. Bitte in den Systemeinstellungen aktivieren."
            case .recordingFailed(let msg): return "Aufnahme fehlgeschlagen: \(msg)"
            }
        }
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws -> URL {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .authorized else {
            throw RecorderError.permissionDenied
        }

        let url = makeTempURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            if !recorder.record() {
                throw RecorderError.recordingFailed("record() returned false")
            }
            self.recorder = recorder
            self.currentURL = url
            self.startTime = Date()
            self.maxLevelDb = -160
            self.currentLevel = 0
            startMetering()
            return url
        } catch {
            throw RecorderError.recordingFailed(error.localizedDescription)
        }
    }

    struct StopResult {
        let url: URL
        let durationSeconds: TimeInterval
        let maxLevelDb: Float
    }

    func stop() -> StopResult? {
        guard let recorder = recorder, let url = currentURL else { return nil }
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        recorder.stop()
        stopMetering()
        let maxDb = maxLevelDb
        self.recorder = nil
        self.currentURL = nil
        self.startTime = nil
        self.currentLevel = 0
        return StopResult(url: url, durationSeconds: duration, maxLevelDb: maxDb)
    }

    func cancel() {
        recorder?.stop()
        stopMetering()
        if let url = currentURL {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        currentURL = nil
        startTime = nil
        currentLevel = 0
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer = meterTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func tick() {
        guard let recorder = recorder else { return }
        recorder.updateMeters()
        let avg = recorder.averagePower(forChannel: 0)
        let peak = recorder.peakPower(forChannel: 0)
        let db = max(avg, peak - 6)
        if db > maxLevelDb { maxLevelDb = db }
        let normalized = max(0, min(1, (db + 50) / 50))
        currentLevel = normalized
    }

    private func makeTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisperDictation", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("rec-\(UUID().uuidString).m4a")
    }
}
