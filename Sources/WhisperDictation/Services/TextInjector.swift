import Foundation
import AppKit
import Carbon.HIToolbox

enum TextInjector {
    static func inject(_ text: String, mode: OutputMode) {
        let pasteboard = NSPasteboard.general
        let trusted = AXIsProcessTrusted()
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        NSLog("WD:inject mode=\(mode.rawValue) axTrusted=\(trusted) frontApp=\(frontBundle) length=\(text.count)")

        if mode == .clipboardOnly {
            pasteboard.clearContents()
            let ok = pasteboard.setString(text, forType: .string)
            NSLog("WD:inject clipboardOnly setString=\(ok)")
            return
        }

        let snapshot = snapshotPasteboard(pasteboard)

        pasteboard.clearContents()
        let setOk = pasteboard.setString(text, forType: .string)
        let readBack = pasteboard.string(forType: .string) ?? ""
        NSLog("WD:inject setString=\(setOk) clipboardNow=\"\(readBack.prefix(40))\"")

        simulateCmdV()
        NSLog("WD:inject simulateCmdV posted")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            restorePasteboard(pasteboard, snapshot: snapshot)
            NSLog("WD:inject snapshot restored")
        }
    }

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        guard let items = pasteboard.pasteboardItems else {
            return PasteboardSnapshot(items: [])
        }
        let copied: [[NSPasteboard.PasteboardType: Data]] = items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
        return PasteboardSnapshot(items: copied)
    }

    private static func restorePasteboard(_ pasteboard: NSPasteboard, snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }
        let newItems: [NSPasteboardItem] = snapshot.items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(newItems)
    }

    private static func simulateCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum PermissionHelper {
    static func checkAccessibilityOnLaunch() {
        let trusted = AXIsProcessTrustedWithOptions(nil)
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Bedienungshilfen-Zugriff erforderlich"
            alert.informativeText = """
            WhisperDictation braucht Zugriff auf die Bedienungshilfen, um den transkribierten Text in die aktive App einzufügen.

            Klicke auf "Einstellungen öffnen", aktiviere WhisperDictation unter \
            Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen, und starte die App neu.
            """
            alert.addButton(withTitle: "Einstellungen öffnen")
            alert.addButton(withTitle: "Später")
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
