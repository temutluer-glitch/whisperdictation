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

    var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }

    var menuBarIconName: String {
        switch status {
        case .idle: return "mic"
        case .recording: return "mic.fill"
        case .transcribing, .processing: return "waveform"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
