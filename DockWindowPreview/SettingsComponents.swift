import AppKit

enum SettingsUI {
    static let panelWidth: CGFloat = 408
    static let panelHeight: CGFloat = 680
    static let contentWidth: CGFloat = 372
    static let outerInset: CGFloat = 14
    static let sectionSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let cardSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 7

    static func rootView() -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    static func scrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }

    static func contentStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = sectionSpacing
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: outerInset, left: outerInset, bottom: outerInset, right: outerInset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    static func rowTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    static func secondaryLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    static func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    static func divider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    static func makeSwitch(target: AnyObject, action: Selector) -> NSSwitch {
        let control = NSSwitch()
        control.target = target
        control.action = action
        control.controlSize = .small
        control.setContentHuggingPriority(.required, for: .horizontal)
        return control
    }

    static func makeButton(title: String, symbolName: String, target: AnyObject, action: Selector) -> NSButton {
        let button = SettingsActionButton(title: title, symbolName: symbolName)
        button.target = target
        button.action = action
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }
}

final class SettingsHeaderView: NSView {
    init(icon: NSImage, title: String, subtitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: SettingsUI.contentWidth).isActive = true

        let iconView = NSImageView(image: icon)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 52),
            iconView.heightAnchor.constraint(equalToConstant: 52)
        ])

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        let subtitleLabel = SettingsUI.secondaryLabel(subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [iconView, textStack, SettingsUI.spacer()])
        row.orientation = .horizontal
        row.spacing = 14
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class SettingsCardView: NSView {
    let stack = NSStackView()

    init(title: String, symbolName: String) {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: SettingsUI.contentWidth).isActive = true

        stack.orientation = .vertical
        stack.spacing = SettingsUI.cardSpacing
        stack.alignment = .width
        stack.edgeInsets = NSEdgeInsets(
            top: SettingsUI.cardPadding,
            left: SettingsUI.cardPadding,
            bottom: SettingsUI.cardPadding,
            right: SettingsUI.cardPadding
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stack.addArrangedSubview(SettingsSectionHeaderView(title: title, symbolName: symbolName))

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
        layer?.cornerRadius = 17
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.46).cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.48).cgColor
    }
}

final class SettingsSectionHeaderView: NSView {
    init(title: String, symbolName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        imageView.contentTintColor = .controlAccentColor
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 14, weight: .semibold)

        let row = NSStackView(views: [imageView, label, SettingsUI.spacer()])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class SettingsPill: NSView {
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
        heightAnchor.constraint(equalToConstant: 24).isActive = true
        widthAnchor.constraint(greaterThanOrEqualToConstant: 68).isActive = true

        label.stringValue = text
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
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
        layer?.cornerRadius = 12
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
                NSColor.separatorColor.withAlphaComponent(0.44)
            )
        case .accent:
            return (
                .controlAccentColor,
                NSColor.controlAccentColor.withAlphaComponent(0.15),
                NSColor.controlAccentColor.withAlphaComponent(0.36)
            )
        case .success:
            return (
                .systemGreen,
                NSColor.systemGreen.withAlphaComponent(0.16),
                NSColor.systemGreen.withAlphaComponent(0.36)
            )
        case .warning:
            return (
                .systemOrange,
                NSColor.systemOrange.withAlphaComponent(0.15),
                NSColor.systemOrange.withAlphaComponent(0.34)
            )
        case .danger:
            return (
                .systemRed,
                NSColor.systemRed.withAlphaComponent(0.15),
                NSColor.systemRed.withAlphaComponent(0.34)
            )
        }
    }
}

final class SettingsActionButton: NSButton {
    private let buttonTitle: String
    private let titleLabel = NSTextField(labelWithString: "")
    private let symbolView = NSImageView()
    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false

    init(title: String, symbolName: String) {
        buttonTitle = title
        super.init(frame: .zero)
        self.title = ""
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryPushIn)
        focusRingType = .none
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 25).isActive = true

        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.usesSingleLineMode = true

        symbolView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        symbolView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            symbolView.widthAnchor.constraint(equalToConstant: 14),
            symbolView.heightAnchor.constraint(equalToConstant: 14)
        ])

        let content = NSStackView(views: [symbolView, titleLabel])
        content.orientation = .horizontal
        content.spacing = 5
        content.alignment = .centerY
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10)
        ])

        updateLayerStyle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        let textSize = (buttonTitle as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
        ])
        return NSSize(width: max(58, ceil(textSize.width) + 43), height: 25)
    }

    override var isEnabled: Bool {
        didSet {
            updateLayerStyle()
        }
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        updateLayerStyle()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateLayerStyle()
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateLayerStyle()
        super.mouseExited(with: event)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerStyle()
    }

    private func updateLayerStyle() {
        let foreground: NSColor
        let background: NSColor
        let border: NSColor

        if !isEnabled {
            foreground = .disabledControlTextColor
            background = NSColor.secondaryLabelColor.withAlphaComponent(0.08)
            border = NSColor.separatorColor.withAlphaComponent(0.20)
        } else if isHighlighted {
            foreground = .labelColor
            background = NSColor.controlAccentColor.withAlphaComponent(0.24)
            border = NSColor.controlAccentColor.withAlphaComponent(0.42)
        } else if isHovering {
            foreground = .labelColor
            background = NSColor.secondaryLabelColor.withAlphaComponent(0.18)
            border = NSColor.separatorColor.withAlphaComponent(0.48)
        } else {
            foreground = .labelColor
            background = NSColor.secondaryLabelColor.withAlphaComponent(0.12)
            border = NSColor.separatorColor.withAlphaComponent(0.34)
        }

        titleLabel.textColor = foreground
        symbolView.contentTintColor = foreground
        alphaValue = isEnabled ? 1 : 0.74
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = background.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = border.cgColor
    }
}
