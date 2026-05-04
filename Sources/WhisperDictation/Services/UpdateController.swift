import Foundation
import SwiftUI
import Sparkle

@MainActor
final class UpdateController: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates: Bool

    init() {
        let standardController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller = standardController
        automaticallyChecksForUpdates = standardController.updater.automaticallyChecksForUpdates

        standardController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)

        DebugLog.write("updater initialized canCheck=\(standardController.updater.canCheckForUpdates) auto=\(standardController.updater.automaticallyChecksForUpdates) feed=\(standardController.updater.feedURL?.absoluteString ?? "nil")")
    }

    func checkForUpdates() {
        DebugLog.write("updater manual check triggered")
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ value: Bool) {
        controller.updater.automaticallyChecksForUpdates = value
        automaticallyChecksForUpdates = value
        DebugLog.write("updater automaticallyChecksForUpdates=\(value)")
    }

    var currentVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
