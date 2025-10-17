import Cocoa
import SwiftTerm

class TerminalView: NSView {
    private var terminalView: LocalProcessTerminalView!

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

        // Create SwiftTerm terminal view
        terminalView = LocalProcessTerminalView(frame: bounds)
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
        // Make terminal view first responder
        window?.makeFirstResponder(terminalView)
        super.mouseDown(with: event)
    }
}
