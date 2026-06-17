import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct WindowInfo: Hashable, Identifiable {
    let windowID: CGWindowID
    let title: String
    let bounds: CGRect
    let ownerPID: pid_t
    let ownerName: String
    let isMinimized: Bool

    var id: CGWindowID { windowID }
}

final class WindowCollector {
    func windows(for app: NSRunningApplication) -> [WindowInfo] {
        windows(for: app.processIdentifier, fallbackOwnerName: app.localizedName ?? "Unknown App")
    }

    func windows(for processIdentifier: pid_t, fallbackOwnerName: String = "Unknown App") -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            DWLog("CGWindowListCopyWindowInfo returned no window list")
            return []
        }

        var seenWindowIDs = Set<CGWindowID>()
        var results: [WindowInfo] = []

        for dictionary in rawWindows {
            guard
                let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t,
                ownerPID == processIdentifier,
                let windowNumber = dictionary[kCGWindowNumber as String] as? CGWindowID,
                !seenWindowIDs.contains(windowNumber),
                let layer = dictionary[kCGWindowLayer as String] as? Int,
                layer == 0
            else {
                continue
            }

            let isOnscreen = (dictionary[kCGWindowIsOnscreen as String] as? Bool) ?? false
            guard isOnscreen else { continue }

            let alpha = (dictionary[kCGWindowAlpha as String] as? Double) ?? 1
            guard alpha > 0.01 else { continue }

            guard
                let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                bounds.width >= 40,
                bounds.height >= 40
            else {
                continue
            }

            let title = (dictionary[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let ownerName = (dictionary[kCGWindowOwnerName as String] as? String) ?? fallbackOwnerName
            let displayTitle = title?.isEmpty == false ? title! : ownerName

            seenWindowIDs.insert(windowNumber)
            results.append(WindowInfo(
                windowID: windowNumber,
                title: displayTitle,
                bounds: bounds,
                ownerPID: ownerPID,
                ownerName: ownerName,
                isMinimized: false
            ))
        }

        appendMinimizedAXWindows(
            to: &results,
            processIdentifier: processIdentifier,
            fallbackOwnerName: fallbackOwnerName
        )

        return results
    }

    private func appendMinimizedAXWindows(
        to results: inout [WindowInfo],
        processIdentifier: pid_t,
        fallbackOwnerName: String
    ) {
        guard AXIsProcessTrusted() else { return }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        guard let axWindows = attribute(appElement, kAXWindowsAttribute) as [AXUIElement]? else {
            return
        }

        var syntheticIndex: UInt32 = 0
        for axWindow in axWindows {
            guard (attribute(axWindow, kAXMinimizedAttribute) as Bool?) == true else {
                continue
            }

            let title = ((attribute(axWindow, kAXTitleAttribute) as String?) ?? fallbackOwnerName)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = title.isEmpty ? fallbackOwnerName : title
            let bounds = frame(of: axWindow) ?? CGRect(x: 0, y: 0, width: 900, height: 560)

            if results.contains(where: { existing in
                normalize(existing.title) == normalize(displayTitle)
                    && abs(existing.bounds.width - bounds.width) < 12
                    && abs(existing.bounds.height - bounds.height) < 12
            }) {
                continue
            }

            syntheticIndex += 1
            results.append(WindowInfo(
                windowID: syntheticWindowID(
                    processIdentifier: processIdentifier,
                    title: displayTitle,
                    bounds: bounds,
                    index: syntheticIndex
                ),
                title: displayTitle,
                bounds: bounds.width >= 40 && bounds.height >= 40 ? bounds : CGRect(x: 0, y: 0, width: 900, height: 560),
                ownerPID: processIdentifier,
                ownerName: fallbackOwnerName,
                isMinimized: true
            ))
        }
    }

    private func syntheticWindowID(processIdentifier: pid_t, title: String, bounds: CGRect, index: UInt32) -> CGWindowID {
        var hash: UInt32 = 2166136261
        let string = "\(processIdentifier)|\(title)|\(Int(bounds.width))x\(Int(bounds.height))|\(index)"
        for byte in string.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return 0x8000_0000 | (hash & 0x7fff_ffff)
    }

    private func attribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? T
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue = attribute(element, kAXPositionAttribute) as AXValue?,
            let sizeValue = attribute(element, kAXSizeAttribute) as AXValue?
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue, .cgPoint, &point),
            AXValueGetValue(sizeValue, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: point, size: size)
    }

    private func normalize(_ string: String) -> String {
        string
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }
}
