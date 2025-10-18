import Cocoa
import SwiftTerm

class TerminalView: NSView {
    private var terminalView: LocalProcessTerminalView!
    private var headerView: NSView!
    private var nameLabel: NSTextField!  // Editable terminal name
    private var returnButton: NSButton!  // Button to return to left panel
    let headerHeight: CGFloat = 24
    let headerPadding: CGFloat = 2  // Small gap between header and terminal content
    var terminalNumber: Int = 0
    var terminalName: String = "Terminal" {
        didSet {
            nameLabel?.stringValue = terminalName
        }
    }
    var isMainTerminal: Bool = false {
        didSet {
            // Show/hide return button based on whether this is the main terminal
            returnButton?.isHidden = !isMainTerminal
        }
    }

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

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)

        // Don't adjust frames if header is hidden (fullscreen mode)
        if headerView != nil && terminalView != nil && !headerView.isHidden {
            let headerFrame = NSRect(x: 0, y: bounds.height - headerHeight, width: bounds.width, height: headerHeight)
            headerView.frame = headerFrame

            // Terminal starts below header with padding
            let terminalFrame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - headerHeight - headerPadding)
            terminalView.frame = terminalFrame
        } else if headerView != nil && terminalView != nil && headerView.isHidden {
            // In fullscreen mode, terminal fills entire view
            terminalView.frame = bounds
            headerView.frame = NSRect(x: 0, y: bounds.height, width: 0, height: 0)
        }
    }

    private func setupUI() {
        wantsLayer = true
        layer?.borderColor = NSColor.darkGray.cgColor
        layer?.borderWidth = 1

        // Create header bar
        let headerFrame = NSRect(x: 0, y: bounds.height - headerHeight, width: bounds.width, height: headerHeight)
        headerView = DraggableHeaderView(frame: headerFrame)
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.8).cgColor
        headerView.autoresizingMask = [.width, .minYMargin]

        // Add drag handle icon on left
        let dragIcon = NSTextField(labelWithString: "⋮⋮")
        dragIcon.font = NSFont.systemFont(ofSize: 14)
        dragIcon.textColor = NSColor.lightGray
        dragIcon.frame = NSRect(x: 6, y: 4, width: 20, height: 16)
        dragIcon.isEditable = false
        dragIcon.isSelectable = false
        dragIcon.isBordered = false
        dragIcon.drawsBackground = false
        headerView.addSubview(dragIcon)

        // Add editable terminal name label in center
        nameLabel = DoubleClickTextField(string: terminalName)
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = NSColor.lightGray
        nameLabel.alignment = .center
        nameLabel.frame = NSRect(x: 30, y: 5, width: bounds.width - 80, height: 14)
        nameLabel.autoresizingMask = [.width]
        nameLabel.isEditable = false  // Only editable on double-click
        nameLabel.isSelectable = false
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        nameLabel.focusRingType = .none
        nameLabel.delegate = self
        nameLabel.target = self
        nameLabel.action = #selector(nameFieldChanged)
        (nameLabel as? DoubleClickTextField)?.terminalView = self
        headerView.addSubview(nameLabel)

        // Add return button (hidden by default, shown when in main panel)
        returnButton = NSButton(frame: NSRect(x: bounds.width - 40, y: 4, width: 16, height: 16))
        returnButton.title = ""
        returnButton.bezelStyle = .inline
        returnButton.isBordered = false
        returnButton.image = NSImage(systemSymbolName: "arrow.left.circle.fill", accessibilityDescription: "Return to Left")
        returnButton.contentTintColor = NSColor.systemBlue
        returnButton.target = self
        returnButton.action = #selector(returnToLeft)
        returnButton.autoresizingMask = [.minXMargin]
        returnButton.isHidden = true  // Hidden by default
        headerView.addSubview(returnButton)

        // Add close button on far right
        let closeButton = NSButton(frame: NSRect(x: bounds.width - 22, y: 4, width: 16, height: 16))
        closeButton.title = ""
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = NSColor.gray
        closeButton.target = self
        closeButton.action = #selector(closeTerminal)
        closeButton.autoresizingMask = [.minXMargin]
        headerView.addSubview(closeButton)

        // Create SwiftTerm terminal view below header with padding
        // Note: In AppKit, y=0 is at bottom, so terminal occupies bottom portion
        let terminalFrame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - headerHeight - headerPadding)
        terminalView = LocalProcessTerminalView(frame: terminalFrame)
        terminalView.autoresizingMask = [.width, .height]

        // Force the terminal view to use layers and make it transparent
        terminalView.wantsLayer = true
        terminalView.layer?.backgroundColor = NSColor.clear.cgColor
        terminalView.layer?.isOpaque = false

        // Add terminal first (back), then header (front) so header is on top
        addSubview(terminalView)
        addSubview(headerView)
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

    private var isForwardingMouseEvents = false

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        print("Tessera: TerminalView mouseDown at \(location), headerView.frame = \(headerView.frame)")

        // Check if click is in the header area
        if headerView.frame.contains(location) {
            print("Tessera: click in header, forwarding to ContentView via nextResponder")
            // Forward to ContentView for drag handling
            isForwardingMouseEvents = true
            nextResponder?.mouseDown(with: event)
            return
        }

        // Terminal area click - make terminal first responder
        window?.makeFirstResponder(terminalView)
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if isForwardingMouseEvents {
            print("Tessera: TerminalView mouseDragged - forwarding to ContentView")
            nextResponder?.mouseDragged(with: event)
            return
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isForwardingMouseEvents {
            print("Tessera: TerminalView mouseUp - forwarding to ContentView")
            nextResponder?.mouseUp(with: event)
            isForwardingMouseEvents = false
            return
        }
        super.mouseUp(with: event)
    }

    func updateTerminalNumber(_ number: Int) {
        terminalNumber = number
        // Update default name if user hasn't customized it
        if terminalName == "Terminal" || terminalName.hasPrefix("Terminal ") {
            terminalName = "Terminal \(number)"
        }
    }

    @objc private func nameFieldChanged() {
        terminalName = nameLabel.stringValue
        // Move focus back to terminal
        window?.makeFirstResponder(terminalView)
    }

    @objc private func closeTerminal() {
        // Notify the app delegate to remove this terminal
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.closeTerminal(self)
    }

    @objc private func returnToLeft() {
        // Return this terminal from main panel to left panel
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.returnTerminalToLeft(self)
    }

    // Set terminal background to solid black for fullscreen mode
    func setOpaqueBackground(_ opaque: Bool) {
        if opaque {
            // Solid black background
            terminalView.nativeBackgroundColor = NSColor.black
            terminalView.layer?.backgroundColor = NSColor.black.cgColor
        } else {
            // Transparent background
            terminalView.nativeBackgroundColor = NSColor.clear
            terminalView.layer?.backgroundColor = NSColor.clear.cgColor
        }
        terminalView.needsDisplay = true
    }

    // Hide/show header for fullscreen mode
    func setHeaderHidden(_ hidden: Bool) {
        headerView.isHidden = hidden

        // Force layout update after hiding/showing
        if hidden {
            // Expand terminal to fill entire view
            terminalView.frame = bounds
            // Ensure header is completely out of view
            headerView.frame = NSRect(x: 0, y: bounds.height, width: 0, height: 0)
        } else {
            // Restore header at top
            headerView.frame = NSRect(x: 0, y: bounds.height - headerHeight, width: bounds.width, height: headerHeight)
            // Restore terminal below header with padding
            terminalView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - headerHeight - headerPadding)
        }

        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    // Get the header frame in window coordinates for drag detection
    func headerFrameInWindow() -> NSRect? {
        guard let window = window else { return nil }
        let headerFrameInView = headerView.frame
        return convert(headerFrameInView, to: nil)
    }
}

// MARK: - NSTextFieldDelegate

extension TerminalView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        // Save the terminal name when editing ends
        terminalName = nameLabel.stringValue
        // Disable editing again
        (nameLabel as? DoubleClickTextField)?.finishEditing()
        // Return focus to terminal
        window?.makeFirstResponder(terminalView)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle Enter key to finish editing
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            terminalName = nameLabel.stringValue
            (nameLabel as? DoubleClickTextField)?.finishEditing()
            window?.makeFirstResponder(terminalView)
            return true
        }
        return false
    }
}

// MARK: - Double Click Text Field

class DoubleClickTextField: NSTextField {
    weak var terminalView: TerminalView?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Double-click: enable editing
            isEditable = true
            isSelectable = true
            window?.makeFirstResponder(currentEditor())
            currentEditor()?.selectAll(nil)
        } else {
            // Single click: forward to header for drag detection
            superview?.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        // Forward drag events to header
        superview?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        // Forward mouse up to header
        superview?.mouseUp(with: event)
    }

    func finishEditing() {
        isEditable = false
        isSelectable = false
    }
}

// MARK: - Draggable Header View

class DraggableHeaderView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        print("Tessera: DraggableHeaderView hitTest at \(point), returning \(String(describing: result))")
        return result
    }

    // Pass all mouse events to superview's superview (ContentView) for drag detection
    override func mouseDown(with event: NSEvent) {
        print("Tessera: DraggableHeaderView mouseDown - forwarding to ContentView")
        print("Tessera: superview = \(String(describing: superview))")
        print("Tessera: superview?.superview = \(String(describing: superview?.superview))")
        superview?.superview?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        print("Tessera: DraggableHeaderView mouseDragged - forwarding to ContentView")
        superview?.superview?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        print("Tessera: DraggableHeaderView mouseUp - forwarding to ContentView")
        superview?.superview?.mouseUp(with: event)
    }
}
