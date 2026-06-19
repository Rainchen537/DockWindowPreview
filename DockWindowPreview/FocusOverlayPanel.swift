import AppKit

final class FocusOverlayController {
    private var panel: FocusOverlayPanel?

    func show(image: NSImage, windowBounds: CGRect) {
        let overlayFrame = Self.allScreensFrame()

        if panel == nil {
            panel = FocusOverlayPanel(frame: overlayFrame)
        }

        panel?.setFrame(overlayFrame, display: false)
        panel?.configure(image: image, windowBounds: windowBounds)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private static func allScreensFrame() -> NSRect {
        guard let firstScreen = NSScreen.screens.first else {
            return NSRect(x: 0, y: 0, width: 1440, height: 900)
        }

        return NSScreen.screens.dropFirst().reduce(firstScreen.frame) { partialResult, screen in
            partialResult.union(screen.frame)
        }
    }
}

private final class FocusOverlayPanel: NSPanel {
    private let overlayView = FocusOverlayView()

    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Public-API visual focus only: this panel covers the desktop and draws
        // the selected window snapshot instead of actually hiding other apps.
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        contentView = overlayView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func configure(image: NSImage, windowBounds: CGRect) {
        overlayView.configure(
            image: image,
            windowBounds: windowBounds,
            overlayFrame: frame
        )
    }
}

private final class FocusOverlayView: NSView {
    private var image: NSImage?
    private var focusRect: NSRect = .zero

    override var isFlipped: Bool { false }

    func configure(image: NSImage, windowBounds: CGRect, overlayFrame: NSRect) {
        self.image = image
        focusRect = Self.windowRect(for: windowBounds, overlayFrame: overlayFrame)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.015, alpha: 0.34).setFill()
        bounds.fill()

        guard let image, !focusRect.isEmpty else { return }

        let shadow = NSShadow()
        shadow.shadowBlurRadius = 18
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.30)

        let roundedRect = NSBezierPath(roundedRect: focusRect, xRadius: 12, yRadius: 12)

        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor(calibratedWhite: 0.02, alpha: 0.88).setFill()
        roundedRect.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        roundedRect.addClip()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: focusRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
        let border = NSBezierPath(roundedRect: focusRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 11.5, yRadius: 11.5)
        border.lineWidth = 1
        border.stroke()
    }

    private static func windowRect(for windowBounds: CGRect, overlayFrame: NSRect) -> NSRect {
        // CGWindow/AX bounds are reported in global display coordinates. AppKit
        // draws this non-flipped overlay from the bottom-left, so flip the Y axis
        // over the all-screens frame and preserve the window's original size.
        return NSRect(
            x: windowBounds.minX - overlayFrame.minX,
            y: overlayFrame.maxY - windowBounds.maxY,
            width: windowBounds.width,
            height: windowBounds.height
        )
    }
}
