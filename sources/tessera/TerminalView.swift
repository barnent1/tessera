import Cocoa
import SwiftTerm

class TerminalView: NSView {
    private var terminalView: LocalProcessTerminalView!
    private var headerView: NSView!
    let headerHeight: CGFloat = 24
    var terminalNumber: Int = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        applySettings()
        startShell()
        observeSettings()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        applySettings()
        startShell()
        observeSettings()
    }

    override var isOpaque: Bool { return false }

    private func setupUI() {
        wantsLayer = true
        layer?.borderColor = NSColor.darkGray.cgColor
        layer?.borderWidth = 1

        // Create header bar
        let headerFrame = NSRect(x: 0, y: bounds.height - headerHeight, width: bounds.width, height: headerHeight)
        headerView = NSView(frame: headerFrame)
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.8).cgColor
        headerView.autoresizingMask = [.width, .minYMargin]

        // Add drag handle icon on left
        let dragIcon = NSTextField(labelWithString: "⋮⋮")
        dragIcon.font = NSFont.systemFont(ofSize: 14)
        dragIcon.textColor = NSColor.lightGray
        dragIcon.frame = NSRect(x: 6, y: 4, width: 20, height: 16)
        headerView.addSubview(dragIcon)

        // Add terminal number on right
        let numberLabel = NSTextField(labelWithString: "#\(terminalNumber)")
        numberLabel.font = NSFont.systemFont(ofSize: 11)
        numberLabel.textColor = NSColor.gray
        numberLabel.alignment = .right
        numberLabel.frame = NSRect(x: bounds.width - 50, y: 5, width: 44, height: 14)
        numberLabel.autoresizingMask = [.minXMargin]
        headerView.addSubview(numberLabel)

        addSubview(headerView)

        // Create SwiftTerm terminal view below header
        let terminalFrame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - headerHeight)
        terminalView = LocalProcessTerminalView(frame: terminalFrame)
        terminalView.autoresizingMask = [.width, .height]

        // Force the terminal view to use layers and make it transparent
        terminalView.wantsLayer = true
        terminalView.layer?.backgroundColor = NSColor.clear.cgColor
        terminalView.layer?.isOpaque = false

        addSubview(terminalView)
    }

    private func applySettings() {
        let settings = Settings.shared

        // Keep the layer background transparent
        terminalView.layer?.backgroundColor = NSColor.clear.cgColor
        terminalView.layer?.isOpaque = false

        // Set terminal background to fully transparent (no opacity stacking)
        terminalView.nativeBackgroundColor = NSColor.clear

        terminalView.nativeForegroundColor = settings.foregroundColor
        terminalView.font = NSFont(name: settings.fontName, size: settings.fontSize) ??
                           NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        terminalView.caretColor = settings.cursorColor

        // Force redraw
        terminalView.needsDisplay = true
        needsDisplay = true
    }

    private func observeSettings() {
        NotificationCenter.default.addObserver(
            forName: Settings.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }
    }

    private func startShell() {
        // Start zsh shell
        terminalView.startProcess(executable: "/bin/zsh", args: ["-l"], environment: getEnvironment())
    }

    private func getEnvironment() -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"

        return env.map { "\($0.key)=\($0.value)" }
    }

    override var acceptsFirstResponder: Bool { return true }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Check if click is in header - don't pass to terminal
        if headerView.frame.contains(location) {
            // Header click - will be handled by parent for dragging
            super.mouseDown(with: event)
        } else {
            // Terminal area click - make terminal first responder
            window?.makeFirstResponder(terminalView)
            super.mouseDown(with: event)
        }
    }

    func updateTerminalNumber(_ number: Int) {
        terminalNumber = number

        // Update the number label if it exists
        if let numberLabel = headerView.subviews.last as? NSTextField {
            numberLabel.stringValue = "#\(number)"
        }
    }

    // Get the header frame in window coordinates for drag detection
    func headerFrameInWindow() -> NSRect? {
        guard let window = window else { return nil }
        let headerFrameInView = headerView.frame
        return convert(headerFrameInView, to: nil)
    }
}
