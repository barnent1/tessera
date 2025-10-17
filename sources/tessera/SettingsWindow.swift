import Cocoa

class SettingsWindow: NSWindow {
    private var opacitySlider: NSSlider!
    private var fontSizeSlider: NSSlider!
    private var fontNamePopup: NSPopUpButton!
    private var foregroundColorWell: NSColorWell!

    init() {
        let rect = NSRect(x: 0, y: 0, width: 400, height: 240)
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Tessera Settings"
        self.isReleasedWhenClosed = false
        self.level = .floating  // Ensure it appears above other windows
        self.center()

        setupUI()
        loadCurrentSettings()
    }

    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 240))
        self.contentView = contentView

        var yPos: CGFloat = 200

        // Opacity
        addLabel("Window Opacity:", at: NSPoint(x: 20, y: yPos), to: contentView)
        opacitySlider = NSSlider(frame: NSRect(x: 150, y: yPos - 2, width: 200, height: 25))
        opacitySlider.minValue = 0.5
        opacitySlider.maxValue = 1.0
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        contentView.addSubview(opacitySlider)
        yPos -= 40

        // Font Name
        addLabel("Font:", at: NSPoint(x: 20, y: yPos), to: contentView)
        fontNamePopup = NSPopUpButton(frame: NSRect(x: 150, y: yPos - 5, width: 200, height: 25))
        fontNamePopup.addItems(withTitles: [
            "Menlo",
            "Monaco",
            "SF Mono",
            "Courier New",
            "Courier",
            "Andale Mono"
        ])
        fontNamePopup.target = self
        fontNamePopup.action = #selector(fontChanged)
        contentView.addSubview(fontNamePopup)
        yPos -= 40

        // Font Size
        addLabel("Font Size:", at: NSPoint(x: 20, y: yPos), to: contentView)
        fontSizeSlider = NSSlider(frame: NSRect(x: 150, y: yPos - 2, width: 200, height: 25))
        fontSizeSlider.minValue = 8
        fontSizeSlider.maxValue = 24
        fontSizeSlider.numberOfTickMarks = 17
        fontSizeSlider.allowsTickMarkValuesOnly = true
        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(fontSizeChanged)
        contentView.addSubview(fontSizeSlider)

        let fontSizeLabel = NSTextField(labelWithString: "12")
        fontSizeLabel.frame = NSRect(x: 360, y: yPos, width: 30, height: 20)
        fontSizeLabel.tag = 100  // Tag for updating
        contentView.addSubview(fontSizeLabel)
        yPos -= 40

        // Font Color
        addLabel("Font Color:", at: NSPoint(x: 20, y: yPos), to: contentView)
        foregroundColorWell = NSColorWell(frame: NSRect(x: 150, y: yPos - 5, width: 60, height: 30))
        foregroundColorWell.target = self
        foregroundColorWell.action = #selector(foregroundColorChanged)
        contentView.addSubview(foregroundColorWell)

        // Close button
        let closeButton = NSButton(frame: NSRect(x: 290, y: 20, width: 90, height: 30))
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.keyEquivalent = "\r"  // Enter key
        contentView.addSubview(closeButton)
    }

    private func addLabel(_ text: String, at point: NSPoint, to view: NSView) {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: point.x, y: point.y, width: 130, height: 20)
        label.alignment = .right
        view.addSubview(label)
    }

    private func loadCurrentSettings() {
        let settings = Settings.shared

        opacitySlider.doubleValue = settings.windowOpacity
        fontSizeSlider.doubleValue = Double(settings.fontSize)
        updateFontSizeLabel()

        // Select current font in popup
        if let index = fontNamePopup.itemTitles.firstIndex(of: settings.fontName) {
            fontNamePopup.selectItem(at: index)
        }

        foregroundColorWell.color = settings.foregroundColor
    }

    private func updateFontSizeLabel() {
        if let label = contentView?.viewWithTag(100) as? NSTextField {
            label.stringValue = "\(Int(fontSizeSlider.doubleValue))"
        }
    }

    // MARK: - Actions

    @objc private func opacityChanged() {
        Settings.shared.windowOpacity = opacitySlider.doubleValue
    }

    @objc private func fontChanged() {
        if let selectedFont = fontNamePopup.titleOfSelectedItem {
            Settings.shared.fontName = selectedFont
        }
    }

    @objc private func fontSizeChanged() {
        Settings.shared.fontSize = CGFloat(fontSizeSlider.doubleValue)
        updateFontSizeLabel()
    }

    @objc private func foregroundColorChanged() {
        Settings.shared.foregroundColor = foregroundColorWell.color
    }

    @objc private func closeWindow() {
        close()
    }
}
