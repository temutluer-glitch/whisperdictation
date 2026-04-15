import Foundation
import AVFoundation

final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

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
            recorder.prepareToRecord()
            if !recorder.record() {
                throw RecorderError.recordingFailed("record() returned false")
            }
            self.recorder = recorder
            self.currentURL = url
            return url
        } catch {
            throw RecorderError.recordingFailed(error.localizedDescription)
        }
    }

    func stop() -> URL? {
        guard let recorder = recorder else { return nil }
        recorder.stop()
        let url = currentURL
        self.recorder = nil
        self.currentURL = nil
        return url
    }

    func cancel() {
        recorder?.stop()
        if let url = currentURL {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        currentURL = nil
    }

    private func makeTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisperDictation", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("rec-\(UUID().uuidString).m4a")
    }
}
