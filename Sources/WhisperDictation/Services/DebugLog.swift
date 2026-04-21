import Foundation

enum DebugLog {
    private static let path = "/tmp/whisperdictation.log"
    private static let queue = DispatchQueue(label: "com.innosolv.WhisperDictation.debuglog")
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func write(_ message: String) {
        let line = "\(isoFormatter.string(from: Date())) \(message)\n"
        NSLog("WD:%@", message)
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
    }
}
