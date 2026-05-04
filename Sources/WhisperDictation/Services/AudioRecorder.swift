import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorder: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var currentLevel: Float = 0

    private let session = AVCaptureSession()
    private var audioInput: AVCaptureDeviceInput?
    private let fileOutput = AVCaptureAudioFileOutput()
    private var currentURL: URL?
    private var meterTimer: Timer?
    private(set) var startTime: Date?
    private(set) var maxLevelDb: Float = -160
    private var stopContinuation: CheckedContinuation<Void, Never>?

    /// uniqueID of the explicitly selected input device, or empty for system default.
    /// Set this before each `start()` call to lock the recorder to a specific microphone.
    var preferredInputDeviceID: String = ""

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

        try configureSession()

        let url = makeTempURL()
        self.currentURL = url
        self.startTime = Date()
        self.maxLevelDb = -160
        self.currentLevel = 0

        if !session.isRunning {
            session.startRunning()
        }

        // AVCaptureAudioFileOutput.audioSettings is read-only at the codec level for AAC,
        // but channels and sample rate can be tuned via the settings dict.
        fileOutput.audioSettings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        fileOutput.startRecording(to: url, outputFileType: .m4a, recordingDelegate: self)
        startMetering()
        return url
    }

    struct StopResult {
        let url: URL
        let durationSeconds: TimeInterval
        let maxLevelDb: Float
    }

    func stop() -> StopResult? {
        guard let url = currentURL else { return nil }
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let maxDb = maxLevelDb

        if fileOutput.isRecording {
            fileOutput.stopRecording()
        }
        stopMetering()
        teardownSession()

        self.currentURL = nil
        self.startTime = nil
        self.currentLevel = 0
        return StopResult(url: url, durationSeconds: duration, maxLevelDb: maxDb)
    }

    func cancel() {
        if fileOutput.isRecording {
            fileOutput.stopRecording()
        }
        stopMetering()
        teardownSession()
        if let url = currentURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentURL = nil
        startTime = nil
        currentLevel = 0
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let existing = audioInput {
            session.removeInput(existing)
            audioInput = nil
        }
        if !session.outputs.contains(fileOutput) {
            if session.canAddOutput(fileOutput) {
                session.addOutput(fileOutput)
            } else {
                throw RecorderError.recordingFailed("Konnte Audio-File-Output nicht zur Capture-Session hinzufügen.")
            }
        }

        let device = resolveInputDevice()
        guard let device else {
            throw RecorderError.recordingFailed("Kein Mikrofon gefunden.")
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw RecorderError.recordingFailed("Capture-Session lehnt das Mikrofon ab: \(device.localizedName)")
            }
            session.addInput(input)
            self.audioInput = input
            DebugLog.write("audio device=\(device.localizedName) uid=\(device.uniqueID) preferredID=\(preferredInputDeviceID.isEmpty ? "default" : preferredInputDeviceID)")
        } catch let recorderError as RecorderError {
            throw recorderError
        } catch {
            throw RecorderError.recordingFailed(error.localizedDescription)
        }
    }

    private func resolveInputDevice() -> AVCaptureDevice? {
        if !preferredInputDeviceID.isEmpty,
           let preferred = AudioDeviceCatalog.device(forUniqueID: preferredInputDeviceID) {
            return preferred
        }
        if !preferredInputDeviceID.isEmpty {
            DebugLog.write("audio preferred device \(preferredInputDeviceID) not available, falling back to default")
        }
        return AVCaptureDevice.default(for: .audio)
    }

    private func teardownSession() {
        if session.isRunning {
            session.stopRunning()
        }
        if let input = audioInput {
            session.removeInput(input)
            audioInput = nil
        }
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
        guard let connection = fileOutput.connection(with: .audio) else { return }
        let channels = connection.audioChannels
        guard !channels.isEmpty else { return }
        let avg = channels.map { $0.averagePowerLevel }.max() ?? -160
        let peak = channels.map { $0.peakHoldLevel }.max() ?? -160
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

    // MARK: - AVCaptureFileOutputRecordingDelegate

    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        if let error {
            DebugLog.write("audio file output finished with error: \(error.localizedDescription)")
        }
    }
}
