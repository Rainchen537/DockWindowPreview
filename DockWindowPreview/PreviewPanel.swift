import AppKit
import Foundation
import QuartzCore

final class PreviewPanel: NSPanel {
    var onSelectWindow: ((WindowInfo) -> Void)?
    var onCloseWindow: ((WindowInfo) -> Void)?

    private let thumbnailProvider: WindowThumbnailProvider
    private let settings: AppSettings
    private let rootView = PreviewRootView()
    private let stackView = NSStackView()

    private struct PreviewItem {
        let window: WindowInfo
        let thumbnail: NSImage
        let thumbnailSize: NSSize
    }

    private var currentWindows: [WindowInfo] = []
    private var currentApp: NSRunningApplication?
    private var currentAnchor: NSPoint?
    private var currentDockEdge: DockEdge?

    init(thumbnailProvider: WindowThumbnailProvider, settings: AppSettings = .shared) {
        self.thumbnailProvider = thumbnailProvider
        self.settings = settings

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        isOpaque = false
        hasShadow = true
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        setupContent()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(windows: [WindowInfo], app: NSRunningApplication, anchor: NSPoint, dockEdge: DockEdge?) {
        guard !windows.isEmpty else {
            hide()
            return
        }

        currentWindows = windows
        currentApp = app
        currentAnchor = anchor
        currentDockEdge = dockEdge

        let items = makePreviewItems(for: windows)
        rebuildContent(items: items, app: app)

        let targetSize = preferredPanelSize(for: items)
        setFrame(NSRect(origin: frame.origin, size: targetSize), display: false)
        contentView?.layoutSubtreeIfNeeded()

        let targetFrame = positionedFrame(size: targetSize, anchor: anchor, dockEdge: dockEdge)
        setFrame(targetFrame, display: true)
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
        currentWindows = []
        currentApp = nil
        currentAnchor = nil
        currentDockEdge = nil
    }

    func removeWindow(_ windowID: CGWindowID) {
        let previousCount = currentWindows.count
        currentWindows.removeAll { $0.windowID == windowID }
        guard currentWindows.count != previousCount else { return }

        guard
            !currentWindows.isEmpty,
            let app = currentApp,
            let anchor = currentAnchor
        else {
            hide()
            return
        }

        show(windows: currentWindows, app: app, anchor: anchor, dockEdge: currentDockEdge)
    }

    func containsScreenPoint(_ point: NSPoint) -> Bool {
        frame.insetBy(dx: -10, dy: -10).contains(point)
    }

    private func setupContent() {
        rootView.material = .hudWindow
        rootView.blendingMode = .behindWindow
        rootView.state = .active
        rootView.wantsLayer = true
        rootView.layer?.cornerRadius = 14
        rootView.layer?.masksToBounds = true
        contentView = rootView

        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: rootView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])
    }

    private func makePreviewItems(for windows: [WindowInfo]) -> [PreviewItem] {
        windows.map { window in
            let size = settings.thumbnailSize(for: window)
            let thumbnail = thumbnailProvider.thumbnail(for: window, targetSize: size)
            return PreviewItem(window: window, thumbnail: thumbnail, thumbnailSize: size)
        }
    }

    private func rebuildContent(items: [PreviewItem], app: NSRunningApplication) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let rows = makeRows(for: items, appIcon: app.icon)
        for row in rows {
            stackView.addArrangedSubview(row)
        }
    }

    private func makeRows(for items: [PreviewItem], appIcon: NSImage?) -> [NSStackView] {
        let groups = rowGroups(for: items)
        var rows: [NSStackView] = []

        for group in groups {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            row.alignment = .top
            row.distribution = .fill

            for item in group {
                let card = WindowPreviewCardView(
                    window: item.window,
                    appIcon: appIcon,
                    thumbnail: item.thumbnail,
                    thumbnailSize: item.thumbnailSize,
                    settings: settings
                )
                card.onClick = { [weak self] selectedWindow in
                    self?.onSelectWindow?(selectedWindow)
                }
                card.onClose = { [weak self] selectedWindow in
                    self?.onCloseWindow?(selectedWindow)
                }
                row.addArrangedSubview(card)
            }

            rows.append(row)
        }

        return rows
    }

    private func rowGroups(for items: [PreviewItem]) -> [[PreviewItem]] {
        let availableWidth = (NSScreen.main?.visibleFrame.width ?? 1440) - 32
        let maxContentWidth = max(280, availableWidth - 16)
        let spacing: CGFloat = 8
        var groups: [[PreviewItem]] = []
        var currentGroup: [PreviewItem] = []
        var currentWidth: CGFloat = 0

        for item in items {
            let itemWidth = cardSize(for: item).width
            let nextWidth = currentGroup.isEmpty ? itemWidth : currentWidth + spacing + itemWidth
            if !currentGroup.isEmpty, (currentGroup.count >= 4 || nextWidth > maxContentWidth) {
                groups.append(currentGroup)
                currentGroup = [item]
                currentWidth = itemWidth
            } else {
                currentGroup.append(item)
                currentWidth = nextWidth
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    private func preferredPanelSize(for items: [PreviewItem]) -> NSSize {
        let groups = rowGroups(for: items)
        let spacing: CGFloat = 8
        let rowWidths = groups.map { group in
            group.reduce(CGFloat(0)) { $0 + cardSize(for: $1).width } + CGFloat(max(group.count - 1, 0)) * spacing
        }
        let rowHeights = groups.map { group in
            group.map { cardSize(for: $0).height }.max() ?? 0
        }
        let width = (rowWidths.max() ?? 0) + 16
        let height = rowHeights.reduce(CGFloat(0), +) + CGFloat(max(groups.count - 1, 0)) * spacing + 16

        guard let screen = NSScreen.main else {
            return NSSize(width: width, height: height)
        }

        return NSSize(
            width: min(width, screen.visibleFrame.width - 32),
            height: min(height, screen.visibleFrame.height - 32)
        )
    }

    private func cardSize(for item: PreviewItem) -> NSSize {
        let titleHeight: CGFloat = settings.showWindowTitles ? 30 : 0
        return NSSize(width: item.thumbnailSize.width + 16, height: item.thumbnailSize.height + titleHeight + 16)
    }

    private func positionedFrame(size: NSSize, anchor: NSPoint, dockEdge: DockEdge?) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let screenFrame = screen?.frame ?? visibleFrame
        let padding: CGFloat = 10

        var origin: NSPoint
        switch dockEdge {
        case .bottom:
            let y = visibleFrame.minY > screenFrame.minY + 20 ? visibleFrame.minY + padding : screenFrame.minY + 92
            origin = NSPoint(x: anchor.x - size.width / 2, y: y)
        case .left:
            let x = visibleFrame.minX > screenFrame.minX + 20 ? visibleFrame.minX + padding : screenFrame.minX + 92
            origin = NSPoint(x: x, y: anchor.y - size.height / 2)
        case .right:
            let x = visibleFrame.maxX < screenFrame.maxX - 20 ? visibleFrame.maxX - size.width - padding : screenFrame.maxX - size.width - 92
            origin = NSPoint(x: x, y: anchor.y - size.height / 2)
        case nil:
            origin = NSPoint(x: anchor.x - size.width / 2, y: anchor.y + 24)
        }

        origin.x = min(max(origin.x, visibleFrame.minX + padding), visibleFrame.maxX - size.width - padding)
        origin.y = min(max(origin.y, visibleFrame.minY + padding), visibleFrame.maxY - size.height - padding)

        return NSRect(origin: origin, size: size)
    }
}

private final class PreviewRootView: NSVisualEffectView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }
}

private final class WindowPreviewCardView: NSView {
    var onClick: ((WindowInfo) -> Void)?
    var onClose: ((WindowInfo) -> Void)?

    private let windowInfo: WindowInfo
    private let iconView = NSImageView()
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private lazy var closeButton: NSButton = {
        let button = NSButton(title: "×", target: self, action: #selector(closeButtonClicked))
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        button.contentTintColor = NSColor(calibratedWhite: 1, alpha: 0.92)
        button.toolTip = "关闭窗口"
        button.alphaValue = 0
        button.isEnabled = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.20).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private let thumbnailSize: NSSize
    private let settings: AppSettings

    init(window: WindowInfo, appIcon: NSImage?, thumbnail: NSImage, thumbnailSize: NSSize, settings: AppSettings) {
        self.windowInfo = window
        self.thumbnailSize = thumbnailSize
        self.settings = settings
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.06).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.10).cgColor

        setupViews(appIcon: appIcon, thumbnail: thumbnail)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        let titleHeight: CGFloat = settings.showWindowTitles ? 30 : 0
        return NSSize(width: thumbnailSize.width + 16, height: thumbnailSize.height + titleHeight + 16)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor(calibratedRed: 0.25, green: 0.47, blue: 0.95, alpha: 0.26).cgColor
        layer?.borderColor = NSColor(calibratedRed: 0.45, green: 0.65, blue: 1, alpha: 0.70).cgColor
        setCloseButtonVisible(true)
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.06).cgColor
        layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.10).cgColor
        setCloseButtonVisible(false)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(windowInfo)
    }

    private func setCloseButtonVisible(_ visible: Bool) {
        closeButton.isEnabled = visible
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.07
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            closeButton.animator().alphaValue = visible ? 1 : 0
        }
    }

    @objc private func closeButtonClicked() {
        closeButton.isEnabled = false
        closeButton.alphaValue = 0.35
        onClose?(windowInfo)
    }

    private func setupViews(appIcon: NSImage?, thumbnail: NSImage) {
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 6
        contentStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if settings.showWindowTitles {
            let titleRow = NSStackView()
            titleRow.orientation = .horizontal
            titleRow.spacing = 8
            titleRow.alignment = .centerY
            titleRow.distribution = .fill
            titleRow.widthAnchor.constraint(equalToConstant: thumbnailSize.width).isActive = true

            iconView.image = appIcon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true

            titleLabel.stringValue = windowInfo.title
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = NSColor(calibratedWhite: 0.94, alpha: 1)
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.maximumNumberOfLines = 1
            titleLabel.alignment = .left
            titleLabel.usesSingleLineMode = true
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

            closeButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
            closeButton.heightAnchor.constraint(equalToConstant: 22).isActive = true

            titleRow.addArrangedSubview(iconView)
            titleRow.addArrangedSubview(titleLabel)
            titleRow.addArrangedSubview(closeButton)
            contentStack.addArrangedSubview(titleRow)
        } else {
            addSubview(closeButton)
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 6),
                closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
                closeButton.widthAnchor.constraint(equalToConstant: 24),
                closeButton.heightAnchor.constraint(equalToConstant: 22)
            ])
        }

        imageView.image = thumbnail
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        imageView.widthAnchor.constraint(equalToConstant: thumbnailSize.width).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: thumbnailSize.height).isActive = true
        contentStack.addArrangedSubview(imageView)
    }
}
