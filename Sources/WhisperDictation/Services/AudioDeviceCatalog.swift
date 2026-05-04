import Foundation
import AVFoundation

struct AudioInputDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let manufacturer: String
}

enum AudioDeviceCatalog {
    static func availableInputDevices() -> [AudioInputDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return session.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                manufacturer: device.manufacturer
            )
        }
    }

    static func device(forUniqueID id: String) -> AVCaptureDevice? {
        guard !id.isEmpty else { return nil }
        return AVCaptureDevice(uniqueID: id)
    }
}
