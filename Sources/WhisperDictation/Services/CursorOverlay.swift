import AppKit
import SwiftUI
import ApplicationServices

@MainActor
final class CursorOverlay {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<RecordingIndicatorView>?
    private var anchorPoint: NSPoint?
    private weak var recorder: AudioRecorder?

    func show(status: DictationStatus, recorder: AudioRecorder) {
        self.recorder = recorder
        let position = resolveAnchor()
        anchorPoint = position

        let view = RecordingIndicatorView(status: status, recorder: recorder)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 160, height: 36)
        hosting.wantsLayer = true
        hosting.layer?.isOpaque = false
        hosting.layer?.backgroundColor = CGColor.clear

        if let existing = panel {
            existing.contentView = hosting
            self.hostingView = hosting
            let size = hosting.fittingSize
            existing.setContentSize(size)
            hosting.frame = NSRect(origin: .zero, size: size)
            reposition(panel: existing)
            existing.orderFrontRegardless()
            return
        }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = true
        p.contentView = hosting

        let size = hosting.fittingSize
        p.setContentSize(size)
        hosting.frame = NSRect(origin: .zero, size: size)

        reposition(panel: p)
        p.orderFrontRegardless()

        self.panel = p
        self.hostingView = hosting
    }

    func updateStatus(_ status: DictationStatus) {
        guard let hostingView, let recorder else { return }
        hostingView.rootView = RecordingIndicatorView(status: status, recorder: recorder)
        let size = hostingView.fittingSize
        panel?.setContentSize(size)
        hostingView.frame = NSRect(origin: .zero, size: size)
        if let panel { reposition(panel: panel) }
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        anchorPoint = nil
        recorder = nil
    }

    private func reposition(panel: NSPanel) {
        guard let anchor = anchorPoint else { return }
        let size = hostingView?.fittingSize ?? NSSize(width: 160, height: 36)

        let screen = screenContaining(anchor) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame

        var x = anchor.x - size.width / 2
        var y = anchor.y + 6

        if y + size.height > visible.maxY {
            y = anchor.y - size.height - 18
        }

        x = min(max(x, visible.minX + 4), visible.maxX - size.width - 4)
        y = min(max(y, visible.minY + 4), visible.maxY - size.height - 4)

        let final = NSPoint(x: x, y: y)
        DebugLog.write("overlay reposition anchor=\(Int(anchor.x)),\(Int(anchor.y)) screen=\(Int(visible.minX)),\(Int(visible.minY))-\(Int(visible.maxX)),\(Int(visible.maxY)) final=\(Int(x)),\(Int(y))")
        panel.setFrameOrigin(final)
    }

    private func elementTopCenter() -> NSPoint? {
        guard let element = focusedElement() else { return nil }

        var posValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }

        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        if size.width < 20 || size.height < 12 { return nil }
        if size.width > 1600 || size.height > 900 { return nil }
        if pos.x == 0 && pos.y == 0 { return nil }

        let topCenterAX = CGPoint(x: pos.x + size.width / 2, y: pos.y)
        return convertAXToScreenCoordinates(topCenterAX)
    }

    private func cursorScreenPosition() -> NSPoint? {
        guard let element = focusedElement() else { return nil }

        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success else {
            return nil
        }

        var boundsValue: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue!,
            &boundsValue
        ) == .success else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else {
            return nil
        }

        if rect.height < 6 || rect.height > 200 { return nil }
        if rect.origin.x == 0 && rect.origin.y == 0 { return nil }
        if !rect.origin.x.isFinite || !rect.origin.y.isFinite { return nil }

        let topCenter = CGPoint(x: rect.midX, y: rect.minY)
        return convertAXToScreenCoordinates(topCenter)
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppValue: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success else {
            return nil
        }
        var focusedElementValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedAppValue as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue) == .success else {
            return nil
        }
        return (focusedElementValue as! AXUIElement)
    }

    private func primaryScreen() -> NSScreen? {
        if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return primary
        }
        return NSScreen.screens.first
    }

    private func screenContaining(_ point: NSPoint) -> NSScreen? {
        return NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func convertAXToScreenCoordinates(_ point: CGPoint) -> NSPoint {
        guard let primary = primaryScreen() else {
            return NSPoint(x: point.x, y: point.y)
        }
        let primaryHeight = primary.frame.height
        return NSPoint(x: point.x, y: primaryHeight - point.y)
    }

    private func mouseAnchor() -> NSPoint {
        let m = NSEvent.mouseLocation
        return NSPoint(x: m.x, y: m.y + 14)
    }

    private func resolveAnchor() -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let maxDistance: CGFloat = 350

        if let p = cursorScreenPosition(), isPlausible(p), distance(p, mouse) < maxDistance {
            DebugLog.write("overlay anchor=caret p=\(Int(p.x)),\(Int(p.y)) mouse=\(Int(mouse.x)),\(Int(mouse.y))")
            return p
        }
        if let p = elementTopCenter(), isPlausible(p), distance(p, mouse) < maxDistance {
            DebugLog.write("overlay anchor=element p=\(Int(p.x)),\(Int(p.y)) mouse=\(Int(mouse.x)),\(Int(mouse.y))")
            return p
        }
        let fallback = mouseAnchor()
        DebugLog.write("overlay anchor=mouse p=\(Int(fallback.x)),\(Int(fallback.y))")
        return fallback
    }

    private func distance(_ a: NSPoint, _ b: NSPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private func isPlausible(_ p: NSPoint) -> Bool {
        if !p.x.isFinite || !p.y.isFinite { return false }
        return screenContaining(p) != nil
    }
}
