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

        // Add terminal number on right
        let numberLabel = NSTextField(labelWithString: "#\(terminalNumber)")
        numberLabel.font = NSFont.systemFont(ofSize: 11)
        numberLabel.textColor = NSColor.gray
        numberLabel.alignment = .right
        numberLabel.frame = NSRect(x: bounds.width - 50, y: 5, width: 44, height: 14)
        numberLabel.autoresizingMask = [.minXMargin]
        numberLabel.isEditable = false
        numberLabel.isSelectable = false
        numberLabel.isBordered = false
        numberLabel.drawsBackground = false
        headerView.addSubview(numberLabel)

        // Create SwiftTerm terminal view below header
        let terminalFrame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - headerHeight)
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

        // Update the number label if it exists
        if let numberLabel = headerView.subviews.last as? NSTextField {
            numberLabel.stringValue = "#\(number)"
        }
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

        // Adjust terminal view frame to fill the space
        if hidden {
            // Expand terminal to fill entire view
            terminalView.frame = bounds
        } else {
            // Restore terminal below header
            terminalView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - headerHeight)
        }
    }

    // Get the header frame in window coordinates for drag detection
    func headerFrameInWindow() -> NSRect? {
        guard let window = window else { return nil }
        let headerFrameInView = headerView.frame
        return convert(headerFrameInView, to: nil)
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
