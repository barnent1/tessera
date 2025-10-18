import Cocoa

class SettingsWindow: NSWindow {
    private var opacitySlider: NSSlider!
    private var fontSizeSlider: NSSlider!
    private var fontNamePopup: NSPopUpButton!
    private var foregroundColorWell: NSColorWell!
    private var projectsDirectoryLabel: NSTextField!
    private var anthropicApiKeyField: NSSecureTextField!
    private var openAIApiKeyField: NSSecureTextField!
    private var geminiApiKeyField: NSSecureTextField!

    init() {
        let rect = NSRect(x: 0, y: 0, width: 400, height: 480)
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Tessera Settings"
        self.isReleasedWhenClosed = false
        self.level = .normal  // Normal window behavior
        self.center()

        setupUI()
        loadCurrentSettings()
    }

    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 480))
        self.contentView = contentView

        var yPos: CGFloat = 440

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
        yPos -= 50

        // Projects Directory
        addLabel("Projects Directory:", at: NSPoint(x: 20, y: yPos + 10), to: contentView)

        // Directory path label (truncated middle)
        projectsDirectoryLabel = NSTextField(labelWithString: "")
        projectsDirectoryLabel.frame = NSRect(x: 150, y: yPos + 10, width: 150, height: 20)
        projectsDirectoryLabel.lineBreakMode = .byTruncatingMiddle
        projectsDirectoryLabel.font = NSFont.systemFont(ofSize: 11)
        contentView.addSubview(projectsDirectoryLabel)

        // Choose button
        let chooseButton = NSButton(frame: NSRect(x: 305, y: yPos + 6, width: 80, height: 28))
        chooseButton.title = "Choose..."
        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseProjectsDirectory)
        contentView.addSubview(chooseButton)
        yPos -= 60

        // API Keys Section
        let apiKeysLabel = NSTextField(labelWithString: "API Keys")
        apiKeysLabel.frame = NSRect(x: 20, y: yPos, width: 360, height: 20)
        apiKeysLabel.font = NSFont.boldSystemFont(ofSize: 13)
        contentView.addSubview(apiKeysLabel)
        yPos -= 30

        // Anthropic API Key
        addLabel("Anthropic:", at: NSPoint(x: 20, y: yPos), to: contentView)
        anthropicApiKeyField = NSSecureTextField(frame: NSRect(x: 150, y: yPos - 2, width: 230, height: 24))
        anthropicApiKeyField.placeholderString = "sk-ant-..."
        anthropicApiKeyField.target = self
        anthropicApiKeyField.action = #selector(anthropicApiKeyChanged)
        contentView.addSubview(anthropicApiKeyField)
        yPos -= 35

        // OpenAI API Key
        addLabel("OpenAI:", at: NSPoint(x: 20, y: yPos), to: contentView)
        openAIApiKeyField = NSSecureTextField(frame: NSRect(x: 150, y: yPos - 2, width: 230, height: 24))
        openAIApiKeyField.placeholderString = "sk-..."
        openAIApiKeyField.target = self
        openAIApiKeyField.action = #selector(openAIApiKeyChanged)
        contentView.addSubview(openAIApiKeyField)
        yPos -= 35

        // Gemini API Key
        addLabel("Gemini:", at: NSPoint(x: 20, y: yPos), to: contentView)
        geminiApiKeyField = NSSecureTextField(frame: NSRect(x: 150, y: yPos - 2, width: 230, height: 24))
        geminiApiKeyField.placeholderString = "AIza..."
        geminiApiKeyField.target = self
        geminiApiKeyField.action = #selector(geminiApiKeyChanged)
        contentView.addSubview(geminiApiKeyField)

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

        // Load projects directory
        projectsDirectoryLabel.stringValue = settings.projectsDirectory

        // Load API keys
        anthropicApiKeyField.stringValue = settings.anthropicApiKey
        openAIApiKeyField.stringValue = settings.openAIApiKey
        geminiApiKeyField.stringValue = settings.geminiApiKey
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

    @objc private func chooseProjectsDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select the directory containing your projects"
        panel.prompt = "Choose"

        // Set initial directory to current setting
        let currentPath = Settings.shared.projectsDirectory
        panel.directoryURL = URL(fileURLWithPath: currentPath)

        panel.beginSheetModal(for: self) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            Settings.shared.projectsDirectory = url.path
            self?.projectsDirectoryLabel.stringValue = url.path
        }
    }

    @objc private func anthropicApiKeyChanged() {
        Settings.shared.anthropicApiKey = anthropicApiKeyField.stringValue
    }

    @objc private func openAIApiKeyChanged() {
        Settings.shared.openAIApiKey = openAIApiKeyField.stringValue
    }

    @objc private func geminiApiKeyChanged() {
        Settings.shared.geminiApiKey = geminiApiKeyField.stringValue
    }

    @objc private func closeWindow() {
        close()
    }
}
