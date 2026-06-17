import AppKit

enum AppIconFactory {
    static func appIcon(size: CGFloat = 128) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let scale = size / 128
        func r(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
            NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
        }

        let background = NSBezierPath(roundedRect: r(10, 10, 108, 108), xRadius: 28 * scale, yRadius: 28 * scale)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.42, alpha: 1),
            NSColor(calibratedRed: 0.06, green: 0.42, blue: 0.78, alpha: 1)
        ])?.draw(in: background, angle: 45)

        NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
        background.lineWidth = 1.5 * scale
        background.stroke()

        drawWindow(rect: r(29, 48, 62, 46), radius: 8 * scale, alpha: 0.62, scale: scale)
        drawWindow(rect: r(42, 36, 62, 46), radius: 8 * scale, alpha: 0.94, scale: scale)

        let dock = NSBezierPath(roundedRect: r(31, 23, 66, 10), xRadius: 5 * scale, yRadius: 5 * scale)
        NSColor(calibratedWhite: 1, alpha: 0.82).setFill()
        dock.fill()

        let indicator = NSBezierPath(ovalIn: r(58, 18, 12, 4))
        NSColor(calibratedRed: 0.52, green: 0.88, blue: 1, alpha: 0.95).setFill()
        indicator.fill()

        image.unlockFocus()
        return image
    }

    static func statusBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.black.setFill()
        NSColor.black.setStroke()

        let back = NSBezierPath(roundedRect: NSRect(x: 3, y: 7, width: 9, height: 7), xRadius: 1.8, yRadius: 1.8)
        back.lineWidth = 1.4
        back.stroke()

        let front = NSBezierPath(roundedRect: NSRect(x: 6, y: 4, width: 9, height: 7), xRadius: 1.8, yRadius: 1.8)
        front.lineWidth = 1.4
        front.stroke()

        let dock = NSBezierPath(roundedRect: NSRect(x: 4, y: 1.5, width: 10, height: 1.8), xRadius: 0.9, yRadius: 0.9)
        dock.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func drawWindow(rect: NSRect, radius: CGFloat, alpha: CGFloat, scale: CGFloat) {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 10 * scale
        shadow.shadowOffset = NSSize(width: 0, height: -3 * scale)
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.24)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()

        let body = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSColor(calibratedWhite: 1, alpha: alpha).setFill()
        body.fill()
        NSGraphicsContext.restoreGraphicsState()

        let titleBar = NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.maxY - 11 * scale, width: rect.width, height: 11 * scale), xRadius: radius, yRadius: radius)
        NSColor(calibratedWhite: 1, alpha: 0.28).setFill()
        titleBar.fill()

        for index in 0..<3 {
            let dot = NSBezierPath(ovalIn: NSRect(
                x: rect.minX + (8 + CGFloat(index) * 8) * scale,
                y: rect.maxY - 7.5 * scale,
                width: 3.2 * scale,
                height: 3.2 * scale
            ))
            NSColor(calibratedRed: 0.08, green: 0.27, blue: 0.52, alpha: 0.55).setFill()
            dot.fill()
        }

        let preview = NSBezierPath(roundedRect: NSRect(
            x: rect.minX + 8 * scale,
            y: rect.minY + 9 * scale,
            width: rect.width - 16 * scale,
            height: rect.height - 25 * scale
        ), xRadius: 4 * scale, yRadius: 4 * scale)
        NSColor(calibratedRed: 0.08, green: 0.40, blue: 0.86, alpha: 0.34).setFill()
        preview.fill()
    }
}
