import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var window: NSWindow!
    private var contentView: ContentView!
    var leftTerminals: [TerminalView] = []  // Made public for ContentView
    var rightTerminal: TerminalView?  // Made public for ContentView
    private var isRightFullscreen = false
    var splitRatio: CGFloat = 0.30  // Left panel width as percentage (default 30%)
    private var settingsWindow: SettingsWindow?
    private var aboutWindow: AboutWindowController?

    private enum Prefs {
        static let savedFrame = "LayoutControllerSavedFrame"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Tessera: app launched")

        // Controller window with bottom toolbar
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let defaultRect = NSRect(
            x: screen.visibleFrame.minX + 120,
            y: screen.visibleFrame.minY + 120,
            width: screen.visibleFrame.width * 0.72,
            height: screen.visibleFrame.height * 0.75
        )
        let restored = UserDefaults.standard.string(forKey: Prefs.savedFrame).flatMap(NSRectFromString)
        let frame = restored ?? defaultRect

        print("Tessera: creating window at \(frame)")

        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .resizable, .miniaturizable, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tessera"
        window.isReleasedWhenClosed = false
        window.level = .floating  // Make it float above other windows so we can see it
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        window.delegate = self
        applyWindowOpacity()  // Apply opacity from settings
        window.isOpaque = false
        window.hasShadow = true

        // Custom content view with click tracking
        contentView = ContentView(frame: NSRect(origin: .zero, size: frame.size))
        window.contentView = contentView
        contentView.delegate = self
        contentView.setupButtons()

        // Setup application menu with Quit option
        setupApplicationMenu()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        print("Tessera: window shown, isVisible=\(window.isVisible)")

        // Observe settings changes
        observeSettings()

        // Don't create any terminals on startup - user will add them
    }

    private func applyWindowOpacity() {
        let opacity = Settings.shared.windowOpacity
        window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
    }

    private func observeSettings() {
        NotificationCenter.default.addObserver(
            forName: Settings.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyWindowOpacity()
        }
    }

    private func setupApplicationMenu() {
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Tessera", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Tessera", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Actions

    @objc func addNewTerminal() {
        print("Tessera: adding new terminal (current count: \(leftTerminals.count))")

        // Check if we've reached max
        if leftTerminals.count >= 6 {
            print("Tessera: Maximum terminals reached (6)")
            return
        }

        let terminal = TerminalView(frame: .zero)

        // Always add to left panel
        leftTerminals.append(terminal)

        // Set terminal number (1-indexed for display)
        terminal.updateTerminalNumber(leftTerminals.count)

        // Add to view hierarchy - make sure it's visible
        contentView.addSubview(terminal)
        terminal.isHidden = false

        print("Tessera: added terminal #\(leftTerminals.count), frame will be set by relayout")

        // Relayout all terminals
        relayout()

        print("Tessera: relayout completed, leftTerminals.count = \(leftTerminals.count)")
    }

    @objc func toggleFullscreen() {
        guard let right = rightTerminal else {
            print("Tessera: No terminal selected for fullscreen")
            return
        }

        if isRightFullscreen {
            // Restore to layout
            isRightFullscreen = false
            for leftTerm in leftTerminals {
                if leftTerm !== right {
                    leftTerm.isHidden = false
                }
            }
            // Restore transparent backgrounds and show header
            applyWindowOpacity()
            right.setOpaqueBackground(false)
            right.setHeaderHidden(false)
            relayout()
        } else {
            // Make fullscreen - fill entire window except toolbar
            isRightFullscreen = true

            // Set solid black backgrounds for fullscreen and hide header
            window.backgroundColor = NSColor.black
            right.setOpaqueBackground(true)
            right.setHeaderHidden(true)

            let fullFrame = NSRect(
                x: 0,
                y: contentView.toolbarHeight,
                width: contentView.bounds.width,
                height: contentView.bounds.height - contentView.toolbarHeight
            )
            right.frame = fullFrame

            // Hide left panels (except the one shown on right, which is already repositioned)
            for leftTerm in leftTerminals {
                if leftTerm !== right {
                    leftTerm.isHidden = true
                }
            }

            contentView.needsDisplay = true
        }
    }

    func promoteLeftTerminal(at index: Int) {
        guard index < leftTerminals.count else {
            print("Tessera: cannot promote - index: \(index), left count: \(leftTerminals.count)")
            return
        }

        print("Tessera: promoting left terminal \(index) to right panel")

        let leftTerm = leftTerminals[index]

        // Hide the old right terminal if it exists
        if let oldRight = rightTerminal {
            oldRight.isHidden = true
        }

        // Show the selected left terminal in the right panel
        rightTerminal = leftTerm

        relayout()
    }

    @objc func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Prefs.savedFrame)
        UserDefaults.standard.synchronize()
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }

    @objc func showAbout() {
        if aboutWindow == nil {
            aboutWindow = AboutWindowController()
        }
        aboutWindow?.show()
    }

    // MARK: - Window delegate

    func windowDidEndLiveResize(_ notification: Notification) { relayout() }
    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidExitFullScreen(_ notification: Notification) { relayout() }
    func windowDidDeminiaturize(_ notification: Notification) { relayout() }

    // MARK: - Layout core

    func relayout() {
        guard !isRightFullscreen else {
            print("Tessera: skipping relayout - in fullscreen mode")
            return
        }

        print("Tessera: relayout started with \(leftTerminals.count) left terminals, rightTerminal = \(rightTerminal != nil ? "set" : "nil")")

        let container = contentView.bounds
        let layoutArea = NSRect(
            x: 0,
            y: contentView.toolbarHeight,
            width: container.width,
            height: container.height - contentView.toolbarHeight
        )

        let leftW = floor(layoutArea.width * splitRatio)
        let rightW = layoutArea.width - leftW

        print("Tessera: layoutArea = \(layoutArea), leftW = \(leftW), rightW = \(rightW)")

        // Position right panel (if one is selected)
        if let right = rightTerminal {
            let rightFrame = NSRect(
                x: leftW,
                y: layoutArea.minY,
                width: rightW,
                height: layoutArea.height
            )
            right.frame = rightFrame
            right.isHidden = false
            print("Tessera: positioned right terminal at \(rightFrame)")
        }

        // Position left panels (all terminals, but skip the one shown on right)
        var leftPanelFrames: [CGRect] = []

        if !leftTerminals.isEmpty {
            let n = leftTerminals.count
            let tileH = floor(layoutArea.height / CGFloat(n))

            print("Tessera: positioning \(n) left terminals, tileH = \(tileH)")

            for (i, terminal) in leftTerminals.enumerated() {
                let yPos = layoutArea.minY + CGFloat(n - i - 1) * tileH
                // Use tileH for all terminals for equal sizing
                let height = tileH

                let frame = NSRect(
                    x: 0,
                    y: yPos,
                    width: leftW,
                    height: height
                )

                print("Tessera: calculated frame for terminal \(i): \(frame)")

                // If this terminal is currently shown in the right panel,
                // still record its left frame for click detection but don't reposition it
                if let right = rightTerminal, terminal === right {
                    leftPanelFrames.append(frame)
                    print("Tessera: terminal \(i) is shown on right, just recording frame \(frame)")
                } else {
                    // Position this terminal in the left panel
                    terminal.frame = frame
                    terminal.isHidden = false
                    leftPanelFrames.append(frame)
                    print("Tessera: positioned left terminal \(i) at \(frame)")
                }
            }
        }

        // Update content view with panel info for click detection and drawing
        contentView.leftPanelFrames = leftPanelFrames
        contentView.needsDisplay = true

        print("Tessera: relayout complete, leftPanelFrames.count = \(leftPanelFrames.count)")
    }
}

// MARK: - Custom Content View

class ContentView: NSView {
    weak var delegate: AppDelegate?
    var leftPanelFrames: [CGRect] = []
    private var toolbar: NSView!
    let toolbarHeight: CGFloat = 44
    private var isDraggingDivider = false
    private let dividerHitWidth: CGFloat = 8  // Wider hit area for easier grabbing

    // Drag-and-drop state
    private var isDraggingTerminal = false
    private var draggedTerminalIndex: Int?
    private var dragStartLocation: NSPoint = .zero
    private var currentDragLocation: NSPoint = .zero
    private let dragThreshold: CGFloat = 5.0  // Minimum distance to start drag

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupTrackingArea()
    }

    override var isOpaque: Bool { return false }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor  // Fully transparent, let window background show
        layer?.isOpaque = false

        // Bottom toolbar
        toolbar = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: toolbarHeight))
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.85).cgColor
        toolbar.autoresizingMask = [.width, .maxYMargin]
        addSubview(toolbar)
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let appDelegate = delegate else { return }

        let location = convert(event.locationInWindow, from: nil)
        let dividerX = bounds.width * appDelegate.splitRatio
        let dividerRect = NSRect(
            x: dividerX - dividerHitWidth / 2,
            y: toolbarHeight,
            width: dividerHitWidth,
            height: bounds.height - toolbarHeight
        )

        // Check divider first
        if dividerRect.contains(location) {
            NSCursor.resizeLeftRight.set()
            return
        }

        // Check if hovering over any terminal header
        let headerHeight: CGFloat = 24
        for (index, _) in appDelegate.leftTerminals.enumerated() {
            guard index < leftPanelFrames.count else { continue }

            let panelFrame = leftPanelFrames[index]
            let headerFrame = NSRect(
                x: panelFrame.origin.x,
                y: panelFrame.maxY - headerHeight,
                width: panelFrame.width,
                height: headerHeight
            )

            if headerFrame.contains(location) {
                NSCursor.openHand.set()
                return
            }
        }

        // Default cursor
        NSCursor.arrow.set()
    }

    func setupButtons() {
        // '+' button
        let addButton = NSButton(frame: NSRect(x: 10, y: 7, width: 30, height: 30))
        addButton.title = "+"
        addButton.bezelStyle = .rounded
        addButton.target = delegate
        addButton.action = #selector(AppDelegate.addNewTerminal)
        toolbar.addSubview(addButton)

        // Fullscreen toggle button
        let fullscreenButton = NSButton(frame: NSRect(x: 50, y: 7, width: 100, height: 30))
        fullscreenButton.title = "⤢ Fullscreen"
        fullscreenButton.bezelStyle = .rounded
        fullscreenButton.target = delegate
        fullscreenButton.action = #selector(AppDelegate.toggleFullscreen)
        toolbar.addSubview(fullscreenButton)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Don't call super.draw to avoid drawing any opaque background

        guard let appDelegate = delegate else { return }

        // Draw panel dividers with light gray
        let leftWidth = bounds.width * appDelegate.splitRatio

        // If dragging a terminal, highlight the right panel as drop zone
        if isDraggingTerminal {
            let rightPanelRect = NSRect(
                x: leftWidth,
                y: toolbarHeight,
                width: bounds.width - leftWidth,
                height: bounds.height - toolbarHeight
            )

            // Check if cursor is over right panel
            if rightPanelRect.contains(currentDragLocation) {
                // Highlight drop zone with green tint
                NSColor.green.withAlphaComponent(0.15).setFill()
                NSBezierPath(rect: rightPanelRect).fill()
            } else {
                // Show neutral drop zone
                NSColor.gray.withAlphaComponent(0.1).setFill()
                NSBezierPath(rect: rightPanelRect).fill()
            }
        }

        // Draw vertical divider between left and right panels
        NSColor.darkGray.setStroke()
        let verticalDivider = NSBezierPath()
        verticalDivider.move(to: NSPoint(x: leftWidth, y: toolbarHeight))
        verticalDivider.line(to: NSPoint(x: leftWidth, y: bounds.height))
        verticalDivider.lineWidth = 1
        verticalDivider.stroke()

        // Draw horizontal dividers for left panels
        for (index, frame) in leftPanelFrames.enumerated() {
            if index > 0 {
                // Draw horizontal divider
                NSColor.darkGray.setStroke()
                let divider = NSBezierPath()
                divider.move(to: NSPoint(x: 0, y: frame.maxY))
                divider.line(to: NSPoint(x: leftWidth, y: frame.maxY))
                divider.lineWidth = 1
                divider.stroke()
            }

            // Highlight panel being dragged
            if isDraggingTerminal, let dragIndex = draggedTerminalIndex, dragIndex == index {
                NSColor.blue.withAlphaComponent(0.2).setFill()
                NSBezierPath(rect: frame).fill()

                // Draw drag indicator
                let indicator = "⇢ Dragging..."
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: NSColor.white
                ]
                let attrStr = NSAttributedString(string: indicator, attributes: attrs)
                let textSize = attrStr.size()
                let textOrigin = NSPoint(
                    x: frame.midX - textSize.width / 2,
                    y: frame.midY - textSize.height / 2
                )
                attrStr.draw(at: textOrigin)
            }
            // Draw indicator for the terminal being shown on right
            else if let appDelegate = delegate,
               let rightTerminal = appDelegate.rightTerminal,
               index < appDelegate.leftTerminals.count,
               appDelegate.leftTerminals[index] === rightTerminal {
                // Draw a darker background for the selected panel slot
                NSColor.darkGray.withAlphaComponent(0.5).setFill()
                NSBezierPath(rect: frame).fill()

                // Draw "→" indicator
                let indicator = "→ Shown in main panel"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.lightGray
                ]
                let attrStr = NSAttributedString(string: indicator, attributes: attrs)
                let textSize = attrStr.size()
                let textOrigin = NSPoint(
                    x: frame.midX - textSize.width / 2,
                    y: frame.midY - textSize.height / 2
                )
                attrStr.draw(at: textOrigin)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        guard let appDelegate = delegate else { return }

        // Check if click is near the divider (for dragging to resize)
        let dividerX = bounds.width * appDelegate.splitRatio
        let dividerRect = NSRect(
            x: dividerX - dividerHitWidth / 2,
            y: toolbarHeight,
            width: dividerHitWidth,
            height: bounds.height - toolbarHeight
        )

        if dividerRect.contains(location) {
            isDraggingDivider = true
            return
        }

        // Check if click is in any left terminal header - record as potential drag
        for (index, terminal) in appDelegate.leftTerminals.enumerated() {
            guard index < leftPanelFrames.count else { continue }

            let panelFrame = leftPanelFrames[index]

            // Calculate header frame (top 24px of the terminal panel)
            let headerHeight: CGFloat = 24
            let headerFrame = NSRect(
                x: panelFrame.origin.x,
                y: panelFrame.maxY - headerHeight,
                width: panelFrame.width,
                height: headerHeight
            )

            if headerFrame.contains(location) {
                print("Tessera: potential drag/click on terminal \(index) header at \(location)")
                dragStartLocation = location
                draggedTerminalIndex = index
                // Don't promote yet - wait to see if user drags or just clicks
                return
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        guard let appDelegate = delegate else { return }

        // Handle divider dragging
        if isDraggingDivider {
            // Calculate new split ratio, constrained between 15% and 85%
            let newRatio = max(0.15, min(0.85, location.x / bounds.width))
            appDelegate.splitRatio = newRatio
            appDelegate.relayout()
            needsDisplay = true
            return
        }

        // Handle terminal dragging
        if let dragIndex = draggedTerminalIndex {
            // Check if we've exceeded the drag threshold
            let distance = hypot(location.x - dragStartLocation.x, location.y - dragStartLocation.y)

            if !isDraggingTerminal && distance > dragThreshold {
                // Start drag operation
                isDraggingTerminal = true
                NSCursor.closedHand.set()
                print("Tessera: drag started for terminal \(dragIndex)")
            }

            if isDraggingTerminal {
                // Update drag location and trigger redraw for visual feedback
                currentDragLocation = location
                needsDisplay = true
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        guard let appDelegate = delegate else { return }

        // Handle divider drag completion
        if isDraggingDivider {
            delegate?.saveFrame()
            isDraggingDivider = false
            return
        }

        // Handle terminal drag completion
        if let dragIndex = draggedTerminalIndex {
            if isDraggingTerminal {
                // Complete drag operation - check if dropped on right panel
                let leftWidth = bounds.width * appDelegate.splitRatio
                let rightPanelRect = NSRect(
                    x: leftWidth,
                    y: toolbarHeight,
                    width: bounds.width - leftWidth,
                    height: bounds.height - toolbarHeight
                )

                if rightPanelRect.contains(location) {
                    print("Tessera: drag completed - promoting terminal \(dragIndex) to right panel")
                    delegate?.promoteLeftTerminal(at: dragIndex)
                } else {
                    print("Tessera: drag cancelled - dropped outside right panel")
                }

                // Reset drag state and cursor
                isDraggingTerminal = false
                draggedTerminalIndex = nil
                NSCursor.arrow.set()
                needsDisplay = true
            } else {
                // No drag occurred (below threshold) - treat as click
                print("Tessera: click detected on terminal \(dragIndex) - promoting to right panel")
                delegate?.promoteLeftTerminal(at: dragIndex)
                draggedTerminalIndex = nil
            }
        }
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)

        // Update toolbar width
        var toolbarFrame = toolbar.frame
        toolbarFrame.size.width = bounds.width
        toolbar.frame = toolbarFrame
    }
}
