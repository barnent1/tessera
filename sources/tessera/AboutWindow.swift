import Cocoa

class AboutWindowController: NSWindowController {
    private var aboutWindow: NSWindow!

    init() {
        // Create window with fixed size
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "About Tessera"
        window.isReleasedWhenClosed = false
        window.center()

        // Set window level to float above other windows
        window.level = .floating

        super.init(window: window)
        self.aboutWindow = window

        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        guard let contentView = aboutWindow.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let containerView = NSView(frame: contentView.bounds)
        containerView.autoresizingMask = [.width, .height]
        contentView.addSubview(containerView)

        var yPosition: CGFloat = 280

        // App Icon
        let iconView = NSImageView(frame: NSRect(x: 136, y: yPosition - 128, width: 128, height: 128))
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            iconView.image = icon
        } else {
            // Fallback to app icon
            iconView.image = NSApp.applicationIconImage
        }
        containerView.addSubview(iconView)

        yPosition -= 140

        // App Name
        let nameLabel = NSTextField(labelWithString: "Tessera")
        nameLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        nameLabel.alignment = .center
        nameLabel.frame = NSRect(x: 0, y: yPosition, width: 400, height: 30)
        containerView.addSubview(nameLabel)

        yPosition -= 30

        // Version
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 0, y: yPosition, width: 400, height: 20)
        containerView.addSubview(versionLabel)

        yPosition -= 35

        // Author
        let authorLabel = NSTextField(labelWithString: "by Glen Barnhardt")
        authorLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        authorLabel.alignment = .center
        authorLabel.frame = NSRect(x: 0, y: yPosition, width: 400, height: 20)
        containerView.addSubview(authorLabel)

        yPosition -= 35

        // Description
        let description = "A macOS menu bar app for tiling Alacritty terminal windows. " +
                         "Tessera creates a working pane layout with one large terminal " +
                         "on the right and multiple smaller terminals tiling on the left."

        let descriptionLabel = createWrappingLabel(text: description, width: 340)
        descriptionLabel.frame.origin = NSPoint(x: 30, y: yPosition - descriptionLabel.frame.height)
        containerView.addSubview(descriptionLabel)
    }

    private func createWrappingLabel(text: String, width: CGFloat) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.alignment = .center
        label.preferredMaxLayoutWidth = width
        label.frame.size.width = width

        // Calculate height for wrapped text
        let maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let rect = text.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: label.font!]
        )
        label.frame.size.height = ceil(rect.height) + 10

        return label
    }

    func show() {
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
