import AppKit
import SwiftUI
import ApplicationServices

@MainActor
final class CursorOverlay {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<RecordingIndicatorView>?

    func show(status: DictationStatus) {
        let position = cursorScreenPosition() ?? fallbackPosition()

        if let panel {
            hostingView?.rootView = RecordingIndicatorView(status: status)
            repositionPanel(panel, at: position)
            panel.orderFrontRegardless()
            return
        }

        let indicator = RecordingIndicatorView(status: status)
        let hosting = NSHostingView(rootView: indicator)
        hosting.frame = NSRect(x: 0, y: 0, width: 150, height: 30)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 30),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.hidesOnDeactivate = false
        p.contentView = hosting

        let fittingSize = hosting.fittingSize
        p.setContentSize(fittingSize)
        hosting.frame = NSRect(origin: .zero, size: fittingSize)

        repositionPanel(p, at: position)
        p.orderFrontRegardless()

        self.panel = p
        self.hostingView = hosting
    }

    func updateStatus(_ status: DictationStatus) {
        guard let hostingView else { return }
        hostingView.rootView = RecordingIndicatorView(status: status)
        let fittingSize = hostingView.fittingSize
        panel?.setContentSize(fittingSize)
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    private func repositionPanel(_ panel: NSPanel, at cursorPos: NSPoint) {
        let fittingSize = hostingView?.fittingSize ?? NSSize(width: 150, height: 30)
        let x = cursorPos.x
        let y = cursorPos.y - fittingSize.height - 4

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
                ?? NSScreen.main else {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            return
        }

        let screenFrame = screen.visibleFrame
        let clampedX = min(max(x, screenFrame.minX), screenFrame.maxX - fittingSize.width)
        let clampedY: CGFloat
        if y < screenFrame.minY {
            clampedY = cursorPos.y + 20
        } else {
            clampedY = y
        }

        panel.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }

    private func cursorScreenPosition() -> NSPoint? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedAppValue: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success else {
            return nil
        }
        let focusedApp = focusedAppValue as! AXUIElement

        var focusedElementValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp, kAXFocusedUIElementAttribute as CFString, &focusedElementValue) == .success else {
            return nil
        }
        let focusedElement = focusedElementValue as! AXUIElement

        var selectedRangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success else {
            return insertionPointFromElement(focusedElement)
        }

        var boundsValue: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRangeValue!,
            &boundsValue
        ) == .success else {
            return insertionPointFromElement(focusedElement)
        }

        var axBounds = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &axBounds) else {
            return insertionPointFromElement(focusedElement)
        }

        let screenPoint = convertAXToScreenCoordinates(axBounds)
        return screenPoint
    }

    private func insertionPointFromElement(_ element: AXUIElement) -> NSPoint? {
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

        let axRect = CGRect(origin: pos, size: CGSize(width: 0, height: size.height))
        return convertAXToScreenCoordinates(axRect)
    }

    private func convertAXToScreenCoordinates(_ axRect: CGRect) -> NSPoint {
        guard let primaryScreen = NSScreen.screens.first else {
            return NSPoint(x: axRect.origin.x, y: axRect.origin.y)
        }
        let primaryHeight = primaryScreen.frame.height
        let nsY = primaryHeight - axRect.origin.y - axRect.height
        return NSPoint(x: axRect.origin.x, y: nsY)
    }

    private func fallbackPosition() -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        return NSPoint(x: mouseLocation.x, y: mouseLocation.y - 30)
    }
}
