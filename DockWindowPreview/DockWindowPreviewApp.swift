import AppKit
import Foundation

final class DockWindowPreviewApp: NSObject, NSApplicationDelegate {
    private static var retainedDelegate: DockWindowPreviewApp?

    private let settings = AppSettings.shared
    private let permissionsManager = PermissionsManager()
    private let windowCollector = WindowCollector()
    private let thumbnailProvider = WindowThumbnailProvider()
    private let windowActivator = WindowActivator()
    private let dockInspector = DockInspector()

    private struct PreviewContext {
        let appPID: pid_t
        let anchor: NSPoint
        let dockEdge: DockEdge?
    }

    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var menuAnchorPanel: NSPanel?
    private var fallbackMenuPanel: NSPanel?
    private var settingsWindowController: SettingsWindowController?
    private var previewContext: PreviewContext?

    private lazy var previewPanel: PreviewPanel = {
        let panel = PreviewPanel(thumbnailProvider: thumbnailProvider, settings: settings)
        panel.onSelectWindow = { [weak self] window in
            self?.windowActivator.activate(window)
            self?.previewPanel.hide()
            self?.previewContext = nil
        }
        panel.onCloseWindow = { [weak self] window in
            self?.closeWindowFromPreview(window)
        }
        return panel
    }()

    private lazy var mouseTracker: MouseTracker = {
        let tracker = MouseTracker(dockInspector: dockInspector, settings: settings)
        tracker.isPointInsidePreviewPanel = { [weak self] point in
            self?.previewPanel.containsScreenPoint(point) ?? false
        }
        tracker.onHoverResolved = { [weak self] item, point in
            self?.showPreview(for: item, anchor: point)
        }
        tracker.onMouseLeftDockAndPreview = { [weak self] in
            self?.previewPanel.hide()
            self?.previewContext = nil
        }
        return tracker
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.retainedDelegate = self
        NSApp.setActivationPolicy(.regular)
        setupDockIcon()
        setupApplicationMenu()
        setupStatusItem()
        let isShowingStartupMenu = showRequestedStartupUIIfNeeded()
        if !isShowingStartupMenu {
            permissionsManager.showInitialPermissionGuidanceIfNeeded()
        }
        mouseTracker.start()
        DWLog("DockWindowPreview launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        mouseTracker.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettingsAndRequestPermissions()
        return true
    }

    private func setupDockIcon() {
        NSApp.applicationIconImage = AppIconFactory.appIcon()
    }

    private func setupApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(menuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ","))
        appMenu.addItem(menuItem(title: "请求隐私权限", action: #selector(requestPrivacyPermissions)))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(menuItem(title: "退出 DockWindowPreview", action: #selector(quit), keyEquivalent: "q"))

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.title = ""
            button.image = AppIconFactory.statusBarIcon()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "DockWindowPreview：点击打开设置"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        statusMenu = makeStatusMenu()
        statusItem = item
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(menuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(menuItem(title: "请求隐私权限", action: #selector(requestPrivacyPermissions)))
        menu.addItem(menuItem(title: "打开 Accessibility 权限", action: #selector(openAccessibilitySettings)))
        menu.addItem(menuItem(title: "打开屏幕录制权限", action: #selector(openScreenCaptureSettings)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        return menu
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let shouldShowMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true

        if shouldShowMenu {
            showFallbackMenuPanel()
        } else {
            openSettingsAndRequestPermissions()
        }
    }

    @discardableResult
    private func showRequestedStartupUIIfNeeded() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        NSLog("[DockWindowPreview] launch arguments: %@", arguments.joined(separator: " "))
        guard arguments.contains("--show-status-menu") else { return false }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            NSLog("[DockWindowPreview] showing fallback menu panel")
            self?.showFallbackMenuPanel()
        }
        return true
    }

    private func showStatusMenuAtTopRight() {
        guard let statusMenu else { return }
        NSApp.activate(ignoringOtherApps: true)

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let anchorFrame = NSRect(x: visibleFrame.maxX - 260, y: visibleFrame.maxY - 24, width: 1, height: 1)
        let panel = NSPanel(
            contentRect: anchorFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let anchorView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        panel.contentView = anchorView
        menuAnchorPanel = panel
        panel.orderFrontRegardless()

        statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: anchorView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self, weak panel] in
            panel?.orderOut(nil)
            if self?.menuAnchorPanel === panel {
                self?.menuAnchorPanel = nil
            }
        }
    }

    private func showFallbackMenuPanel() {
        NSLog("[DockWindowPreview] showFallbackMenuPanel invoked")
        fallbackMenuPanel?.orderOut(nil)

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelSize = NSSize(width: 280, height: 240)
        let origin = NSPoint(x: visibleFrame.midX - panelSize.width / 2, y: visibleFrame.midY - panelSize.height / 2)

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: panelSize),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "DockWindowPreview 菜单"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = true
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true

        let rootView = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        rootView.material = .sidebar
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.wantsLayer = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(stack)

        stack.addArrangedSubview(fallbackMenuButton(title: "设置...", action: #selector(openSettings)))
        stack.addArrangedSubview(fallbackMenuButton(title: "请求隐私权限", action: #selector(requestPrivacyPermissions)))
        stack.addArrangedSubview(separatorLine())
        stack.addArrangedSubview(fallbackMenuButton(title: "打开 Accessibility 权限", action: #selector(openAccessibilitySettings)))
        stack.addArrangedSubview(fallbackMenuButton(title: "打开屏幕录制权限", action: #selector(openScreenCaptureSettings)))
        stack.addArrangedSubview(separatorLine())
        stack.addArrangedSubview(fallbackMenuButton(title: "退出 DockWindowPreview", action: #selector(quit)))

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: rootView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        panel.contentView = rootView
        fallbackMenuPanel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func fallbackMenuButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.alignment = .left
        button.font = NSFont.systemFont(ofSize: 13)
        button.contentTintColor = .labelColor
        button.setButtonType(.momentaryPushIn)
        button.bezelStyle = .rounded
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    private func separatorLine() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func showPreview(for dockItem: DockItem, anchor: NSPoint) {
        guard let app = dockItem.runningApplication else {
            DWLog("Dock item '\(dockItem.title)' has no running app")
            previewPanel.hide()
            previewContext = nil
            return
        }

        let windows = windowCollector.windows(for: app)
        guard !windows.isEmpty else {
            DWLog("No visible windows for \(app.localizedName ?? dockItem.title)")
            previewPanel.hide()
            previewContext = nil
            return
        }

        previewContext = PreviewContext(appPID: app.processIdentifier, anchor: anchor, dockEdge: dockItem.dockEdge)
        previewPanel.show(windows: windows, app: app, anchor: anchor, dockEdge: dockItem.dockEdge)
    }

    private func closeWindowFromPreview(_ window: WindowInfo) {
        guard windowActivator.close(window) else {
            NSSound.beep()
            return
        }

        previewPanel.removeWindow(window.windowID)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.refreshPreviewAfterClosingWindow(pid: window.ownerPID)
        }
    }

    private func refreshPreviewAfterClosingWindow(pid: pid_t) {
        guard
            let context = previewContext,
            context.appPID == pid,
            let app = NSRunningApplication(processIdentifier: pid)
        else {
            previewPanel.hide()
            previewContext = nil
            return
        }

        let windows = windowCollector.windows(for: app)
        guard !windows.isEmpty else {
            previewPanel.hide()
            previewContext = nil
            return
        }

        previewPanel.show(windows: windows, app: app, anchor: context.anchor, dockEdge: context.dockEdge)
    }

    @objc private func openSettings() {
        openSettingsAndRequestPermissions()
    }

    private func openSettingsAndRequestPermissions() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings, permissionsManager: permissionsManager)
        }
        settingsWindowController?.show(requestPermissions: true)
    }

    @objc private func openAccessibilitySettings() {
        permissionsManager.openAccessibilitySettings()
    }

    @objc private func openScreenCaptureSettings() {
        permissionsManager.openScreenCaptureSettings()
    }

    @objc private func requestPrivacyPermissions() {
        _ = permissionsManager.requestMissingPrivacyPermissions()
    }

    @objc private func requestScreenCapturePermission() {
        if permissionsManager.requestScreenCapturePermission() {
            DWLog("Screen capture permission is already granted or was granted")
        } else {
            permissionsManager.openScreenCaptureSettings()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
