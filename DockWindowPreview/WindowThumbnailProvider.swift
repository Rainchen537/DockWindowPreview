import AppKit
import CoreGraphics
import Foundation

final class WindowThumbnailProvider {
    func thumbnail(for window: WindowInfo, targetSize: NSSize) -> NSImage {
        if window.isMinimized {
            return placeholderImage(title: window.title, reason: "已最小化", size: targetSize)
        }

        let options: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]
        if let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, window.windowID, options) {
            return NSImage(cgImage: cgImage, size: targetSize)
        }

        let reason = CGPreflightScreenCaptureAccess() ? "无法截图" : "需要屏幕录制权限"
        DWLog("Failed to capture thumbnail for window \(window.windowID), reason: \(reason)")
        return placeholderImage(title: window.title, reason: reason, size: targetSize)
    }

    private func placeholderImage(title: String, reason: String, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: size)
        NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()

        NSColor(calibratedWhite: 0.32, alpha: 1).setStroke()
        let insetRect = rect.insetBy(dx: 1, dy: 1)
        let border = NSBezierPath(roundedRect: insetRect, xRadius: 9, yRadius: 9)
        border.lineWidth = 1
        border.stroke()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.82, alpha: 1),
            .paragraphStyle: paragraphStyle
        ]
        let text = "\(reason)\n\(title)"
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textRect = NSRect(x: 12, y: (size.height - 44) / 2, width: size.width - 24, height: 44)
        attributed.draw(in: textRect)

        image.unlockFocus()
        return image
    }
}
