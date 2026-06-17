import AppKit
import Foundation
import ServiceManagement

final class LaunchAtLoginManager {
    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    var statusText: String {
        switch status {
        case .enabled:
            return "已开启"
        case .notRegistered:
            return "未开启"
        case .requiresApproval:
            return "需要批准"
        case .notFound:
            return "不可用"
        @unknown default:
            return "未知"
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Result<Void, Error> {
        do {
            if enabled {
                if status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if status != .notRegistered && status != .notFound {
                    try SMAppService.mainApp.unregister()
                }
            }
            return .success(())
        } catch {
            DWLog("Failed to \(enabled ? "register" : "unregister") launch at login: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    func openLoginItemsSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.users?LoginItems"
        ]

        for path in urls {
            if let url = URL(string: path), NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
