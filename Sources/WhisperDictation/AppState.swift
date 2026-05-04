import Foundation
import SwiftUI

enum DictationStatus: Equatable {
    case idle
    case recording
    case transcribing
    case processing
    case error(String)
}

@MainActor
final class AppState: ObservableObject {
    @Published var status: DictationStatus = .idle
    @Published var lastTranscription: String = ""

    let isBeta: Bool

    init(isBeta: Bool = AppState.detectBeta()) {
        self.isBeta = isBeta
    }

    nonisolated static func detectBeta() -> Bool {
        Bundle.main.bundleIdentifier?.hasSuffix(".beta") ?? false
    }

    var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }

    var menuBarIconName: String {
        switch status {
        case .idle:
            return isBeta ? "mic.circle" : "mic"
        case .recording:
            return isBeta ? "mic.circle.fill" : "mic.fill"
        case .transcribing, .processing:
            return isBeta ? "waveform.circle" : "waveform"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
