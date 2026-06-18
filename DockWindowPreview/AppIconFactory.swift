import AppKit

enum AppIconFactory {
    static func appIcon(size: CGFloat = 128) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let scale = size / 128
        func r(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
            NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
        }

        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()

        let backgroundShadow = NSShadow()
        backgroundShadow.shadowBlurRadius = 10 * scale
        backgroundShadow.shadowOffset = NSSize(width: 0, height: -2 * scale)
        backgroundShadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.12)
        NSGraphicsContext.saveGraphicsState()
        backgroundShadow.set()

        let background = NSBezierPath(roundedRect: r(10, 10, 108, 108), xRadius: 28 * scale, yRadius: 28 * scale)
        NSGradient(colors: [
            NSColor(calibratedWhite: 1.0, alpha: 1),
            NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.99, alpha: 1)
        ])?.draw(in: background, angle: 225)
        NSGraphicsContext.restoreGraphicsState()

        let subtleRing = NSBezierPath(roundedRect: r(10.75, 10.75, 106.5, 106.5), xRadius: 27 * scale, yRadius: 27 * scale)
        NSColor(calibratedWhite: 0, alpha: 0.06).setStroke()
        subtleRing.lineWidth = 1 * scale
        subtleRing.stroke()

        let glow = NSBezierPath(roundedRect: r(31, 32, 68, 66), xRadius: 19 * scale, yRadius: 19 * scale)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.42, green: 0.28, blue: 0.80, alpha: 1),
            NSColor(calibratedRed: 0.96, green: 0.42, blue: 0.52, alpha: 1),
            NSColor(calibratedRed: 0.98, green: 0.70, blue: 0.45, alpha: 1)
        ])?.draw(in: glow, angle: 315)

        let inner = NSBezierPath(roundedRect: r(39, 42, 52, 44), xRadius: 10 * scale, yRadius: 10 * scale)
        NSColor(calibratedWhite: 1, alpha: 0.93).setFill()
        inner.fill()

        drawPreviewWindow(rect: r(47, 68, 34, 18), radius: 5 * scale, accent: NSColor(calibratedRed: 0.42, green: 0.47, blue: 0.80, alpha: 1), scale: scale)
        drawPreviewWindow(rect: r(40, 55, 34, 20), radius: 5 * scale, accent: NSColor(calibratedRed: 0.30, green: 0.58, blue: 0.92, alpha: 1), scale: scale)
        drawPreviewWindow(rect: r(56, 51, 34, 24), radius: 6 * scale, accent: NSColor(calibratedRed: 0.96, green: 0.49, blue: 0.58, alpha: 1), scale: scale)

        let dockShadow = NSShadow()
        dockShadow.shadowBlurRadius = 5 * scale
        dockShadow.shadowOffset = NSSize(width: 0, height: -1.5 * scale)
        dockShadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.16)
        NSGraphicsContext.saveGraphicsState()
        dockShadow.set()

        let dock = NSBezierPath(roundedRect: r(38, 32, 52, 9), xRadius: 4.5 * scale, yRadius: 4.5 * scale)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.16, green: 0.45, blue: 0.92, alpha: 1),
            NSColor(calibratedRed: 0.35, green: 0.34, blue: 0.86, alpha: 1)
        ])?.draw(in: dock, angle: 0)
        NSGraphicsContext.restoreGraphicsState()

        for index in 0..<4 {
            let dot = NSBezierPath(ovalIn: r(47 + CGFloat(index) * 9, 35, 4, 4))
            NSColor(calibratedWhite: 1, alpha: index == 1 ? 0.95 : 0.56).setFill()
            dot.fill()
        }

        let activeIndicator = NSBezierPath(ovalIn: r(61, 25, 7, 3))
        NSColor(calibratedRed: 0.27, green: 0.50, blue: 1, alpha: 0.45).setFill()
        activeIndicator.fill()

        image.unlockFocus()
        return image
    }

    static func statusBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.black.setFill()
        NSColor.black.setStroke()

        let back = NSBezierPath(roundedRect: NSRect(x: 3, y: 8, width: 8, height: 5.5), xRadius: 1.6, yRadius: 1.6)
        back.lineWidth = 1.4
        back.stroke()

        let middle = NSBezierPath(roundedRect: NSRect(x: 7, y: 6, width: 8, height: 5.5), xRadius: 1.6, yRadius: 1.6)
        middle.lineWidth = 1.4
        middle.stroke()

        let front = NSBezierPath(roundedRect: NSRect(x: 5, y: 3.5, width: 8, height: 5.5), xRadius: 1.6, yRadius: 1.6)
        front.lineWidth = 1.4
        front.stroke()

        let dock = NSBezierPath(roundedRect: NSRect(x: 4, y: 1.5, width: 10, height: 1.8), xRadius: 0.9, yRadius: 0.9)
        dock.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawPreviewWindow(rect: NSRect, radius: CGFloat, accent: NSColor, scale: CGFloat) {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 7 * scale
        shadow.shadowOffset = NSSize(width: 0, height: -2 * scale)
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.18)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()

        let body = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSColor(calibratedWhite: 1, alpha: 0.96).setFill()
        body.fill()
        NSGraphicsContext.restoreGraphicsState()

        let titleBar = NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.maxY - 6 * scale, width: rect.width, height: 6 * scale), xRadius: radius, yRadius: radius)
        accent.withAlphaComponent(0.22).setFill()
        titleBar.fill()

        let lineOne = NSBezierPath(roundedRect: NSRect(x: rect.minX + 6 * scale, y: rect.minY + rect.height * 0.44, width: rect.width - 12 * scale, height: 3 * scale), xRadius: 1.5 * scale, yRadius: 1.5 * scale)
        accent.withAlphaComponent(0.18).setFill()
        lineOne.fill()

        let lineTwo = NSBezierPath(roundedRect: NSRect(x: rect.minX + 6 * scale, y: rect.minY + rect.height * 0.25, width: rect.width * 0.56, height: 3 * scale), xRadius: 1.5 * scale, yRadius: 1.5 * scale)
        NSColor(calibratedWhite: 0.68, alpha: 0.28).setFill()
        lineTwo.fill()
    }
}
