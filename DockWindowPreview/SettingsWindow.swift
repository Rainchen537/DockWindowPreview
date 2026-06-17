import AppKit
import Foundation

final class SettingsWindowController: NSWindowController {
    convenience init(
        settings: AppSettings = .shared,
        permissionsManager: PermissionsManager = PermissionsManager(),
        launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager()
    ) {
        let viewController = SettingsViewController(
            settings: settings,
            permissionsManager: permissionsManager,
            launchAtLoginManager: launchAtLoginManager
        )
        let window = NSWindow(contentViewController: viewController)
        window.title = "DockWindowPreview Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 420))
        window.center()
        self.init(window: window)
    }

    func show(requestPermissions: Bool = false) {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let viewController = contentViewController as? SettingsViewController {
            viewController.refreshPermissionStatus()
            if requestPermissions {
                viewController.requestMissingPermissions()
            }
        }
    }
}

private final class SettingsViewController: NSViewController {
    private let settings: AppSettings
    private let permissionsManager: PermissionsManager
    private let launchAtLoginManager: LaunchAtLoginManager
    private let hoverDelaySlider = NSSlider(value: 0.10, minValue: 0.05, maxValue: 0.8, target: nil, action: nil)
    private let hoverDelayValueLabel = NSTextField(labelWithString: "")
    private let thumbnailSlider = NSSlider(value: 150, minValue: 100, maxValue: 260, target: nil, action: nil)
    private let thumbnailValueLabel = NSTextField(labelWithString: "")
    private lazy var showTitleCheckbox = NSButton(checkboxWithTitle: "显示窗口标题", target: self, action: #selector(showTitleChanged(_:)))
    private lazy var launchAtLoginCheckbox = NSButton(checkboxWithTitle: "开机启动", target: self, action: #selector(launchAtLoginChanged(_:)))
    private let launchAtLoginStatusLabel = NSTextField(labelWithString: "")
    private lazy var openLoginItemsButton = NSButton(title: "登录项设置", target: self, action: #selector(openLoginItemsSettings))
    private lazy var debugCheckbox = NSButton(checkboxWithTitle: "启用调试日志", target: self, action: #selector(debugChanged(_:)))
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let screenCaptureStatusLabel = NSTextField(labelWithString: "")
    private lazy var requestAccessibilityButton = NSButton(title: "请求", target: self, action: #selector(requestAccessibilityPermission))
    private lazy var openAccessibilityButton = NSButton(title: "打开设置", target: self, action: #selector(openAccessibilitySettings))
    private lazy var requestScreenCaptureButton = NSButton(title: "请求", target: self, action: #selector(requestScreenCapturePermission))
    private lazy var openScreenCaptureButton = NSButton(title: "打开设置", target: self, action: #selector(openScreenCaptureSettings))
    private lazy var requestAllButton = NSButton(title: "请求缺失权限", target: self, action: #selector(requestAllPermissions))
    private lazy var recheckButton = NSButton(title: "重新检测", target: self, action: #selector(recheckPermissions))
    private var permissionRefreshTimer: Timer?

    init(settings: AppSettings, permissionsManager: PermissionsManager, launchAtLoginManager: LaunchAtLoginManager) {
        self.settings = settings
        self.permissionsManager = permissionsManager
        self.launchAtLoginManager = launchAtLoginManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        permissionRefreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        buildUI()
        refreshValues()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        startPermissionRefreshTimer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recheckPermissions),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = nil
        NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    private func buildUI() {
        hoverDelaySlider.target = self
        hoverDelaySlider.action = #selector(hoverDelayChanged(_:))
        thumbnailSlider.target = self
        thumbnailSlider.action = #selector(thumbnailSizeChanged(_:))
        launchAtLoginCheckbox.allowsMixedState = true
        openLoginItemsButton.bezelStyle = .rounded

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        stack.addArrangedSubview(row(title: "悬停延迟", control: hoverDelaySlider, valueLabel: hoverDelayValueLabel))
        stack.addArrangedSubview(row(title: "缩略图高度", control: thumbnailSlider, valueLabel: thumbnailValueLabel))
        stack.addArrangedSubview(showTitleCheckbox)
        stack.addArrangedSubview(launchAtLoginRow())
        stack.addArrangedSubview(debugCheckbox)
        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(permissionsSection())

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        ])
    }

    private func permissionsSection() -> NSStackView {
        let title = NSTextField(labelWithString: "Privacy & Security 权限")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let note = NSTextField(labelWithString: "macOS 不允许 App 自动授予权限；授权后这里会自动刷新。若刚重新安装过，请在系统设置里重新勾选一次。")
        note.font = NSFont.systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.maximumNumberOfLines = 2

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(note)
        stack.addArrangedSubview(permissionRow(
            title: "Accessibility",
            statusLabel: accessibilityStatusLabel,
            requestButton: requestAccessibilityButton,
            openButton: openAccessibilityButton
        ))
        stack.addArrangedSubview(permissionRow(
            title: "屏幕录制",
            statusLabel: screenCaptureStatusLabel,
            requestButton: requestScreenCaptureButton,
            openButton: openScreenCaptureButton
        ))

        requestAllButton.bezelStyle = .rounded
        recheckButton.bezelStyle = .rounded
        let actions = NSStackView(views: [requestAllButton, recheckButton])
        actions.orientation = .horizontal
        actions.spacing = 10
        actions.alignment = .leading
        stack.addArrangedSubview(actions)
        return stack
    }

    private func launchAtLoginRow() -> NSStackView {
        launchAtLoginStatusLabel.widthAnchor.constraint(equalToConstant: 84).isActive = true
        openLoginItemsButton.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let row = NSStackView(views: [launchAtLoginCheckbox, launchAtLoginStatusLabel, openLoginItemsButton])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func permissionRow(
        title: String,
        statusLabel: NSTextField,
        requestButton: NSButton,
        openButton: NSButton
    ) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.alignment = .right
        titleLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true

        statusLabel.alignment = .left
        statusLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true
        requestButton.widthAnchor.constraint(equalToConstant: 72).isActive = true
        openButton.widthAnchor.constraint(equalToConstant: 88).isActive = true

        let row = NSStackView(views: [titleLabel, statusLabel, requestButton, openButton])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func row(title: String, control: NSView, valueLabel: NSTextField) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.alignment = .right
        titleLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true

        valueLabel.alignment = .left
        valueLabel.widthAnchor.constraint(equalToConstant: 74).isActive = true

        let row = NSStackView(views: [titleLabel, control, valueLabel])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        control.widthAnchor.constraint(equalToConstant: 210).isActive = true
        return row
    }

    private func refreshValues() {
        hoverDelaySlider.doubleValue = settings.hoverDelay
        hoverDelayValueLabel.stringValue = String(format: "%.0f ms", settings.hoverDelay * 1000)

        thumbnailSlider.doubleValue = Double(settings.thumbnailHeight)
        thumbnailValueLabel.stringValue = String(format: "%.0f px", settings.thumbnailHeight)

        showTitleCheckbox.state = settings.showWindowTitles ? .on : .off
        refreshLaunchAtLoginStatus()
        debugCheckbox.state = settings.debugLoggingEnabled ? .on : .off
        refreshPermissionStatus()
    }

    private func refreshLaunchAtLoginStatus() {
        switch launchAtLoginManager.status {
        case .enabled:
            launchAtLoginCheckbox.state = .on
            launchAtLoginStatusLabel.stringValue = "已开启"
            launchAtLoginStatusLabel.textColor = .systemGreen
        case .requiresApproval:
            launchAtLoginCheckbox.state = .mixed
            launchAtLoginStatusLabel.stringValue = "需要批准"
            launchAtLoginStatusLabel.textColor = .systemOrange
        case .notRegistered:
            launchAtLoginCheckbox.state = .off
            launchAtLoginStatusLabel.stringValue = "未开启"
            launchAtLoginStatusLabel.textColor = .secondaryLabelColor
        case .notFound:
            launchAtLoginCheckbox.state = .off
            launchAtLoginStatusLabel.stringValue = "不可用"
            launchAtLoginStatusLabel.textColor = .systemRed
        @unknown default:
            launchAtLoginCheckbox.state = .off
            launchAtLoginStatusLabel.stringValue = "未知"
            launchAtLoginStatusLabel.textColor = .systemOrange
        }

        settings.launchAtLogin = launchAtLoginManager.isEnabled
    }

    func refreshPermissionStatus() {
        let accessibilityTrusted = permissionsManager.isAccessibilityTrusted()
        accessibilityStatusLabel.stringValue = accessibilityTrusted ? "已开启" : "未开启"
        accessibilityStatusLabel.textColor = accessibilityTrusted ? .systemGreen : .systemOrange
        requestAccessibilityButton.isEnabled = !accessibilityTrusted

        let screenCaptureTrusted = permissionsManager.isScreenCaptureTrusted()
        screenCaptureStatusLabel.stringValue = screenCaptureTrusted ? "已开启" : "未开启"
        screenCaptureStatusLabel.textColor = screenCaptureTrusted ? .systemGreen : .systemOrange
        requestScreenCaptureButton.isEnabled = !screenCaptureTrusted
        requestAllButton.isEnabled = !accessibilityTrusted || !screenCaptureTrusted
    }

    private func startPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    func requestMissingPermissions() {
        _ = permissionsManager.requestMissingPrivacyPermissions()
        refreshPermissionStatus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshPermissionStatus()
        }
    }

    @objc private func hoverDelayChanged(_ sender: NSSlider) {
        settings.hoverDelay = sender.doubleValue
        refreshValues()
    }

    @objc private func thumbnailSizeChanged(_ sender: NSSlider) {
        settings.thumbnailHeight = CGFloat(sender.doubleValue)
        refreshValues()
    }

    @objc private func showTitleChanged(_ sender: NSButton) {
        settings.showWindowTitles = sender.state == .on
        refreshValues()
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let shouldEnable = sender.state == .on || sender.state == .mixed
        switch launchAtLoginManager.setEnabled(shouldEnable) {
        case .success:
            refreshLaunchAtLoginStatus()
            if launchAtLoginManager.status == .requiresApproval {
                showLaunchAtLoginApprovalAlert()
            }
        case .failure(let error):
            refreshLaunchAtLoginStatus()
            showLaunchAtLoginError(error)
        }
    }

    @objc private func debugChanged(_ sender: NSButton) {
        settings.debugLoggingEnabled = sender.state == .on
        refreshValues()
    }

    @objc private func requestAllPermissions() {
        requestMissingPermissions()
    }

    @objc private func recheckPermissions() {
        refreshPermissionStatus()
    }

    @objc private func requestAccessibilityPermission() {
        _ = permissionsManager.requestAccessibilityPermission()
        refreshPermissionStatus()
    }

    @objc private func openAccessibilitySettings() {
        permissionsManager.openAccessibilitySettings()
    }

    @objc private func requestScreenCapturePermission() {
        _ = permissionsManager.requestScreenCapturePermission()
        refreshPermissionStatus()
    }

    @objc private func openScreenCaptureSettings() {
        permissionsManager.openScreenCaptureSettings()
    }

    @objc private func openLoginItemsSettings() {
        launchAtLoginManager.openLoginItemsSettings()
    }

    private func showLaunchAtLoginApprovalAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "需要批准开机启动"
        alert.informativeText = "macOS 已记录开机启动请求。请在 System Settings → General → Login Items 中允许 DockWindowPreview。"
        alert.addButton(withTitle: "打开登录项设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            launchAtLoginManager.openLoginItemsSettings()
        }
    }

    private func showLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "开机启动设置失败"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
