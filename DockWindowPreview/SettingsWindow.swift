import AppKit
import Foundation

final class SettingsPopoverController: NSObject, NSPopoverDelegate {
    private let viewController: SettingsViewController
    private let popover: NSPopover

    init(
        settings: AppSettings = .shared,
        permissionsManager: PermissionsManager = PermissionsManager(),
        launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager(),
        updateChecker: UpdateChecker = .shared
    ) {
        viewController = SettingsViewController(
            settings: settings,
            permissionsManager: permissionsManager,
            launchAtLoginManager: launchAtLoginManager,
            updateChecker: updateChecker
        )

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = viewController
        super.init()
        popover.delegate = self
    }

    var isShown: Bool {
        popover.isShown
    }

    func toggle(relativeTo button: NSStatusBarButton, requestPermissions: Bool = false) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            show(relativeTo: button, requestPermissions: requestPermissions)
        }
    }

    func show(relativeTo button: NSStatusBarButton, requestPermissions: Bool = false) {
        viewController.refreshForPresentation()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        guard requestPermissions else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.viewController.requestMissingPermissions()
        }
    }

    func close() {
        popover.performClose(nil)
    }
}

private final class SettingsViewController: NSViewController {
    private let settings: AppSettings
    private let permissionsManager: PermissionsManager
    private let launchAtLoginManager: LaunchAtLoginManager
    private let updateChecker: UpdateChecker
    private let githubURL = URL(string: "https://github.com/Rainchen537/DockWindowPreview")!

    private let hoverDelaySlider = NSSlider(value: 0.10, minValue: 0.05, maxValue: 0.8, target: nil, action: nil)
    private let hoverDelayValuePill = PillLabel(text: "100 ms", tone: .accent)
    private let thumbnailSlider = NSSlider(value: 150, minValue: 100, maxValue: 260, target: nil, action: nil)
    private let thumbnailValuePill = PillLabel(text: "150 px", tone: .neutral)
    private let launchAtLoginStatusPill = PillLabel(text: "未开启", tone: .neutral)
    private let updateStatusPill = PillLabel(text: "", tone: .neutral)
    private let accessibilityStatusPill = PillLabel(text: "检测中", tone: .neutral)
    private let screenCaptureStatusPill = PillLabel(text: "检测中", tone: .neutral)

    private lazy var showTitleSwitch = makeSwitch(action: #selector(showTitleChanged(_:)))
    private lazy var launchAtLoginSwitch = makeSwitch(action: #selector(launchAtLoginChanged(_:)))
    private lazy var debugSwitch = makeSwitch(action: #selector(debugChanged(_:)))
    private lazy var openLoginItemsButton = makeButton(title: "登录项", symbolName: "person.crop.circle.badge.checkmark", action: #selector(openLoginItemsSettings))
    private lazy var checkUpdatesButton = makeButton(title: "检查更新", symbolName: "arrow.triangle.2.circlepath", action: #selector(checkForUpdatesClicked))
    private lazy var githubButton = makeButton(title: "GitHub", symbolName: "chevron.left.forwardslash.chevron.right", action: #selector(openGitHub))
    private lazy var requestAccessibilityButton = makeButton(title: "请求", symbolName: "hand.raised", action: #selector(requestAccessibilityPermission))
    private lazy var openAccessibilityButton = makeButton(title: "打开", symbolName: "gearshape", action: #selector(openAccessibilitySettings))
    private lazy var requestScreenCaptureButton = makeButton(title: "请求", symbolName: "rectangle.on.rectangle", action: #selector(requestScreenCapturePermission))
    private lazy var openScreenCaptureButton = makeButton(title: "打开", symbolName: "gearshape", action: #selector(openScreenCaptureSettings))
    private lazy var requestAllButton = makeButton(title: "请求缺失权限", symbolName: "lock.open", action: #selector(requestAllPermissions))
    private lazy var recheckButton = makeButton(title: "重新检测", symbolName: "checkmark.shield", action: #selector(recheckPermissions))

    private var permissionRefreshTimer: Timer?

    init(
        settings: AppSettings,
        permissionsManager: PermissionsManager,
        launchAtLoginManager: LaunchAtLoginManager,
        updateChecker: UpdateChecker
    ) {
        self.settings = settings
        self.permissionsManager = permissionsManager
        self.launchAtLoginManager = launchAtLoginManager
        self.updateChecker = updateChecker
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 390, height: 560)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        permissionRefreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        let rootView = NSVisualEffectView()
        rootView.material = .popover
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.translatesAutoresizingMaskIntoConstraints = false
        view = rootView

        buildUI(in: rootView)
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

    func refreshForPresentation() {
        guard isViewLoaded else { return }
        refreshValues()
    }

    private func buildUI(in rootView: NSView) {
        hoverDelaySlider.target = self
        hoverDelaySlider.action = #selector(hoverDelayChanged(_:))
        thumbnailSlider.target = self
        thumbnailSlider.action = #selector(thumbnailSizeChanged(_:))
        updateStatusPill.setText("v\(updateChecker.currentVersion)", tone: .neutral)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(stack)

        stack.addArrangedSubview(headerView())
        stack.addArrangedSubview(previewCard())
        stack.addArrangedSubview(systemCard())
        stack.addArrangedSubview(permissionsCard())
        stack.addArrangedSubview(aboutCard())

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: rootView.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor)
        ])
    }

    private func headerView() -> NSView {
        let iconView = NSImageView(image: AppIconFactory.appIcon(size: 42))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 42),
            iconView.heightAnchor.constraint(equalToConstant: 42)
        ])

        let titleLabel = NSTextField(labelWithString: "DockWindowPreview")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail

        let subtitleLabel = NSTextField(labelWithString: "Dock 多窗口预览 · v\(updateChecker.currentVersion)")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let row = NSStackView(views: [iconView, textStack, spacer()])
        row.orientation = .horizontal
        row.spacing = 11
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 350).isActive = true

        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }

    private func previewCard() -> NSView {
        let card = SettingsCardView()
        card.stack.addArrangedSubview(sectionHeader(title: "预览", symbolName: "rectangle.3.group"))
        card.stack.addArrangedSubview(sliderRow(title: "悬停延迟", slider: hoverDelaySlider, valueLabel: hoverDelayValuePill))
        card.stack.addArrangedSubview(sliderRow(title: "缩略图高度", slider: thumbnailSlider, valueLabel: thumbnailValuePill))
        card.stack.addArrangedSubview(divider())
        card.stack.addArrangedSubview(switchRow(title: "显示窗口标题", trailingView: showTitleSwitch))
        card.stack.addArrangedSubview(switchRow(title: "启用调试日志", trailingView: debugSwitch))
        return card
    }

    private func systemCard() -> NSView {
        let card = SettingsCardView()
        card.stack.addArrangedSubview(sectionHeader(title: "系统", symbolName: "power"))
        card.stack.addArrangedSubview(statusSwitchRow(
            title: "开机启动",
            statusPill: launchAtLoginStatusPill,
            switchControl: launchAtLoginSwitch
        ))
        card.stack.addArrangedSubview(actionRow(primary: openLoginItemsButton))
        return card
    }

    private func permissionsCard() -> NSView {
        let card = SettingsCardView()
        card.stack.addArrangedSubview(sectionHeader(title: "权限", symbolName: "lock.shield"))
        card.stack.addArrangedSubview(permissionRow(
            title: "辅助功能",
            statusPill: accessibilityStatusPill,
            requestButton: requestAccessibilityButton,
            openButton: openAccessibilityButton
        ))
        card.stack.addArrangedSubview(permissionRow(
            title: "屏幕录制",
            statusPill: screenCaptureStatusPill,
            requestButton: requestScreenCaptureButton,
            openButton: openScreenCaptureButton
        ))
        card.stack.addArrangedSubview(actionRow(primary: requestAllButton, secondary: recheckButton))
        return card
    }

    private func aboutCard() -> NSView {
        let card = SettingsCardView()
        card.stack.addArrangedSubview(sectionHeader(title: "关于", symbolName: "info.circle"))
        card.stack.addArrangedSubview(statusRow(title: "当前版本", statusPill: updateStatusPill, trailingView: checkUpdatesButton))
        card.stack.addArrangedSubview(statusRow(title: "项目主页", statusPill: nil, trailingView: githubButton))
        return card
    }

    private func sectionHeader(title: String, symbolName: String) -> NSView {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        imageView.contentTintColor = .controlAccentColor
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let row = NSStackView(views: [imageView, label, spacer()])
        row.orientation = .horizontal
        row.spacing = 7
        row.alignment = .centerY
        return row
    }

    private func sliderRow(title: String, slider: NSSlider, valueLabel: PillLabel) -> NSView {
        let label = rowTitle(title)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let topRow = NSStackView(views: [label, spacer(), valueLabel])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY

        slider.controlSize = .small

        let stack = NSStackView(views: [topRow, slider])
        stack.orientation = .vertical
        stack.spacing = 5
        return stack
    }

    private func switchRow(title: String, trailingView: NSView) -> NSView {
        statusRow(title: title, statusPill: nil, trailingView: trailingView)
    }

    private func statusSwitchRow(title: String, statusPill: PillLabel, switchControl: NSSwitch) -> NSView {
        let trailing = NSStackView(views: [statusPill, switchControl])
        trailing.orientation = .horizontal
        trailing.spacing = 8
        trailing.alignment = .centerY
        return statusRow(title: title, statusPill: nil, trailingView: trailing)
    }

    private func statusRow(title: String, statusPill: PillLabel?, trailingView: NSView) -> NSView {
        let titleLabel = rowTitle(title)
        let views = statusPill.map { [titleLabel, spacer(), $0, trailingView] } ?? [titleLabel, spacer(), trailingView]
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 9
        row.alignment = .centerY
        return row
    }

    private func permissionRow(
        title: String,
        statusPill: PillLabel,
        requestButton: NSButton,
        openButton: NSButton
    ) -> NSView {
        requestButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
        openButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true

        let actions = NSStackView(views: [requestButton, openButton])
        actions.orientation = .horizontal
        actions.spacing = 6
        actions.alignment = .centerY
        return statusRow(title: title, statusPill: statusPill, trailingView: actions)
    }

    private func actionRow(primary: NSButton, secondary: NSButton? = nil) -> NSView {
        let actions = secondary.map { [primary, $0] } ?? [primary]
        let row = NSStackView(views: [spacer()] + actions)
        row.orientation = .horizontal
        row.spacing = 7
        row.alignment = .centerY
        return row
    }

    private func divider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    private func rowTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    private func makeSwitch(action: Selector) -> NSSwitch {
        let control = NSSwitch()
        control.target = self
        control.action = action
        control.controlSize = .small
        return control
    }

    private func makeButton(title: String, symbolName: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        return button
    }

    private func refreshValues() {
        hoverDelaySlider.doubleValue = settings.hoverDelay
        hoverDelayValuePill.setText(String(format: "%.0f ms", settings.hoverDelay * 1000), tone: .accent)

        thumbnailSlider.doubleValue = Double(settings.thumbnailHeight)
        thumbnailValuePill.setText(String(format: "%.0f px", settings.thumbnailHeight), tone: .neutral)

        showTitleSwitch.state = settings.showWindowTitles ? .on : .off
        debugSwitch.state = settings.debugLoggingEnabled ? .on : .off
        refreshLaunchAtLoginStatus()
        refreshPermissionStatus()
    }

    private func refreshLaunchAtLoginStatus() {
        switch launchAtLoginManager.status {
        case .enabled:
            launchAtLoginSwitch.state = .on
            launchAtLoginStatusPill.setText("已开启", tone: .success)
        case .requiresApproval:
            launchAtLoginSwitch.state = .on
            launchAtLoginStatusPill.setText("需批准", tone: .warning)
        case .notRegistered:
            launchAtLoginSwitch.state = .off
            launchAtLoginStatusPill.setText("未开启", tone: .neutral)
        case .notFound:
            launchAtLoginSwitch.state = .off
            launchAtLoginStatusPill.setText("不可用", tone: .danger)
        @unknown default:
            launchAtLoginSwitch.state = .off
            launchAtLoginStatusPill.setText("未知", tone: .warning)
        }

        settings.launchAtLogin = launchAtLoginManager.isEnabled
    }

    func refreshPermissionStatus() {
        let accessibilityTrusted = permissionsManager.isAccessibilityTrusted()
        accessibilityStatusPill.setText(accessibilityTrusted ? "已开启" : "未开启", tone: accessibilityTrusted ? .success : .warning)
        requestAccessibilityButton.isEnabled = !accessibilityTrusted

        let screenCaptureTrusted = permissionsManager.isScreenCaptureTrusted()
        screenCaptureStatusPill.setText(screenCaptureTrusted ? "已开启" : "未开启", tone: screenCaptureTrusted ? .success : .warning)
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

    @objc private func showTitleChanged(_ sender: NSSwitch) {
        settings.showWindowTitles = sender.state == .on
        refreshValues()
    }

    @objc private func launchAtLoginChanged(_ sender: NSSwitch) {
        let shouldEnable = sender.state == .on
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

    @objc private func debugChanged(_ sender: NSSwitch) {
        settings.debugLoggingEnabled = sender.state == .on
        refreshValues()
    }

    @objc private func checkForUpdatesClicked() {
        checkUpdatesButton.isEnabled = false
        updateStatusPill.setText("检查中", tone: .neutral)

        updateChecker.checkForUpdates { [weak self] result in
            DispatchQueue.main.async {
                self?.checkUpdatesButton.isEnabled = true
                self?.handleUpdateCheckResult(result, showsAlert: true)
            }
        }
    }

    private func handleUpdateCheckResult(_ result: UpdateChecker.CheckResult, showsAlert: Bool) {
        switch result {
        case .updateAvailable(_, let latest):
            updateStatusPill.setText("新版本 \(latest.displayVersion)", tone: .accent)
            if showsAlert {
                showUpdateAvailableAlert(latest)
            }
        case .upToDate(let currentVersion, _):
            updateStatusPill.setText("最新版 \(currentVersion)", tone: .success)
        case .failure(let error):
            updateStatusPill.setText("检查失败", tone: .warning)
            if showsAlert {
                showUpdateCheckError(error)
            }
        }
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

    @objc private func openGitHub() {
        NSWorkspace.shared.open(githubURL)
    }

    private func showLaunchAtLoginApprovalAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "需要批准开机启动"
        alert.informativeText = "请在 System Settings → General → Login Items 中允许 DockWindowPreview。"
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

    private func showUpdateAvailableAlert(_ release: UpdateChecker.ReleaseInfo) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "发现新版本 \(release.displayVersion)"
        alert.informativeText = "\(release.name)\n\n当前可以打开下载页面获取最新 DMG。"
        alert.addButton(withTitle: "打开下载页面")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            updateChecker.openDownloadOrReleasePage(release)
        }
    }

    private func showUpdateCheckError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "检查更新失败"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

private final class SettingsCardView: NSView {
    let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 350).isActive = true

        stack.orientation = .vertical
        stack.spacing = 9
        stack.alignment = .width
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateLayerStyle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerStyle()
    }

    private func updateLayerStyle() {
        layer?.cornerRadius = 13
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.58).cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
    }
}

private final class PillLabel: NSView {
    enum Tone {
        case neutral
        case accent
        case success
        case warning
        case danger
    }

    private let label = NSTextField(labelWithString: "")
    private var tone: Tone

    init(text: String, tone: Tone) {
        self.tone = tone
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        heightAnchor.constraint(equalToConstant: 22).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: 62).isActive = true

        label.stringValue = text
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateLayerStyle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerStyle()
    }

    func setText(_ text: String, tone: Tone) {
        label.stringValue = text
        self.tone = tone
        updateLayerStyle()
    }

    private func updateLayerStyle() {
        let colors = palette(for: tone)
        label.textColor = colors.foreground
        layer?.cornerRadius = 11
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = colors.background.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = colors.border.cgColor
    }

    private func palette(for tone: Tone) -> (foreground: NSColor, background: NSColor, border: NSColor) {
        switch tone {
        case .neutral:
            return (
                .secondaryLabelColor,
                NSColor.secondaryLabelColor.withAlphaComponent(0.10),
                NSColor.separatorColor.withAlphaComponent(0.45)
            )
        case .accent:
            return (
                .controlAccentColor,
                NSColor.controlAccentColor.withAlphaComponent(0.15),
                NSColor.controlAccentColor.withAlphaComponent(0.35)
            )
        case .success:
            return (
                .systemGreen,
                NSColor.systemGreen.withAlphaComponent(0.16),
                NSColor.systemGreen.withAlphaComponent(0.34)
            )
        case .warning:
            return (
                .systemOrange,
                NSColor.systemOrange.withAlphaComponent(0.15),
                NSColor.systemOrange.withAlphaComponent(0.33)
            )
        case .danger:
            return (
                .systemRed,
                NSColor.systemRed.withAlphaComponent(0.15),
                NSColor.systemRed.withAlphaComponent(0.33)
            )
        }
    }
}
