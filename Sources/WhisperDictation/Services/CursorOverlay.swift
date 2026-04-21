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
        let position = elementTopCenter() ?? cursorScreenPosition() ?? fallbackPosition()
        anchorPoint = position

        let view = RecordingIndicatorView(status: status, recorder: recorder)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 160, height: 36)

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
        var x = anchor.x - size.width / 2
        var y = anchor.y + 6

        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) })
            ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            x = min(max(x, frame.minX + 4), frame.maxX - size.width - 4)
            if y + size.height > frame.maxY { y = anchor.y - size.height - 6 }
            if y < frame.minY { y = frame.minY + 4 }
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
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

        if size.width <= 0 || size.height <= 0 { return nil }

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

    private func convertAXToScreenCoordinates(_ point: CGPoint) -> NSPoint {
        guard let primaryScreen = NSScreen.screens.first else {
            return NSPoint(x: point.x, y: point.y)
        }
        let primaryHeight = primaryScreen.frame.height
        return NSPoint(x: point.x, y: primaryHeight - point.y)
    }

    private func fallbackPosition() -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        return NSPoint(x: mouseLocation.x, y: mouseLocation.y - 60)
    }
}
