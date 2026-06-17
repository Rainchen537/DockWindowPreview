import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

final class PermissionsManager {
    func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func isScreenCaptureTrusted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestScreenCapturePermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    @discardableResult
    func requestMissingPrivacyPermissions() -> Bool {
        if !isAccessibilityTrusted() {
            _ = requestAccessibilityPermission()
        }

        if !isScreenCaptureTrusted() {
            _ = requestScreenCapturePermission()
        }

        return isAccessibilityTrusted() && isScreenCaptureTrusted()
    }

    func showInitialPermissionGuidanceIfNeeded() {
        let hasAccessibility = isAccessibilityTrusted()
        let hasScreenCapture = isScreenCaptureTrusted()

        _ = requestMissingPrivacyPermissions()

        guard !hasAccessibility || !hasScreenCapture else { return }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "DockWindowPreview 需要权限"
            alert.informativeText = """
            请在 System Settings → Privacy & Security 中开启：

            • Accessibility：用于读取 Dock 和聚焦窗口
            • Screen & System Audio Recording：用于生成窗口缩略图

            开启后建议重启本 App。
            """
            alert.addButton(withTitle: "打开 Accessibility")
            alert.addButton(withTitle: "请求屏幕录制")
            alert.addButton(withTitle: "稍后")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                self.openAccessibilitySettings()
            case .alertSecondButtonReturn:
                _ = self.requestScreenCapturePermission()
            default:
                break
            }
        }
    }

    func openAccessibilitySettings() {
        openSystemSettings(path: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenCaptureSettings() {
        openSystemSettings(path: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func openSystemSettings(path: String) {
        guard let url = URL(string: path), NSWorkspace.shared.open(url) else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
            return
        }
    }
}
