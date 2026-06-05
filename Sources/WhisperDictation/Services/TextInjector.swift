import Foundation
import AppKit
import Carbon.HIToolbox

enum TextInjector {
    static func inject(_ text: String, mode: OutputMode, target: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        let trusted = AXIsProcessTrusted()
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        let targetBundle = target?.bundleIdentifier ?? "nil"
        DebugLog.write("inject mode=\(mode.rawValue) axTrusted=\(trusted) frontApp=\(frontBundle) target=\(targetBundle) length=\(text.count)")

        if mode == .clipboardOnly {
            writeConcealed(text, to: pasteboard)
            DebugLog.write("inject clipboardOnly written (concealed)")
            return
        }

        let snapshot = snapshotPasteboard(pasteboard)
        writeConcealed(text, to: pasteboard)

        // Fokus auf die Ziel-App sicherstellen, dann einfügen (mit Wiederholungen,
        // falls der Fokus noch nicht zurück ist).
        pasteWithFocusRestore(target: target, attemptsLeft: 8)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            restorePasteboard(pasteboard, snapshot: snapshot)
            DebugLog.write("inject snapshot restored")
        }
    }

    /// Schreibt Text in die Zwischenablage und markiert ihn als vertraulich
    /// (org.nspasteboard.ConcealedType), damit Clipboard-History-Tools das Diktat
    /// nicht mitspeichern.
    private static func writeConcealed(_ text: String, to pasteboard: NSPasteboard) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data([UInt8(1)]), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    /// Aktiviert die Ziel-App falls nötig und postet dann Cmd+V. Solange die
    /// Ziel-App nicht im Vordergrund ist, wird kurz gewartet und erneut versucht,
    /// damit der Text zuverlässig im richtigen Feld landet.
    private static func pasteWithFocusRestore(target: NSRunningApplication?, attemptsLeft: Int) {
        if let target, attemptsLeft > 0,
           NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier {
            target.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pasteWithFocusRestore(target: target, attemptsLeft: attemptsLeft - 1)
            }
            return
        }
        let (downOk, upOk) = simulateCmdV()
        DebugLog.write("inject simulateCmdV keyDown=\(downOk) keyUp=\(upOk)")
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

    @discardableResult
    private static func simulateCmdV() -> (Bool, Bool) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        return (keyDown != nil, keyUp != nil)
    }
}

enum PermissionHelper {
    static func checkAccessibilityOnLaunch() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Bedienungshilfen-Zugriff erforderlich"
            alert.informativeText = """
            InnoWhisper braucht Zugriff auf die Bedienungshilfen, um den transkribierten Text in die aktive App einzufügen.

            Klicke auf "Einstellungen öffnen", aktiviere InnoWhisper unter \
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
