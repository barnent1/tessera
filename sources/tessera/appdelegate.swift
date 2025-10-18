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

    // Observability panel
    var isShowingObservability = false
    private var observabilityView: ObservabilityView?

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

    func closeTerminal(_ terminal: TerminalView) {
        print("Tessera: closing terminal")

        // If this is the right terminal, clear it and mark as not main
        if terminal === rightTerminal {
            terminal.isMainTerminal = false
            rightTerminal?.removeFromSuperview()
            rightTerminal = nil
        }

        // Remove from left terminals array
        if let index = leftTerminals.firstIndex(where: { $0 === terminal }) {
            leftTerminals.remove(at: index)
            terminal.removeFromSuperview()

            // Update terminal numbers
            for (idx, term) in leftTerminals.enumerated() {
                term.updateTerminalNumber(idx + 1)
            }

            // Just relayout - don't auto-promote anything
            relayout()
        }

        print("Tessera: terminal closed, remaining count: \(leftTerminals.count)")
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

    @objc func toggleObservability() {
        isShowingObservability.toggle()

        if isShowingObservability {
            // Hide terminals and show observability panel
            for terminal in leftTerminals {
                terminal.isHidden = true
            }
            rightTerminal?.isHidden = true

            // Create observability view if needed
            if observabilityView == nil {
                observabilityView = ObservabilityView(frame: .zero)
                contentView.addSubview(observabilityView!)
            }

            // Position observability view
            let frame = NSRect(
                x: 0,
                y: contentView.toolbarHeight,
                width: contentView.bounds.width,
                height: contentView.bounds.height - contentView.toolbarHeight
            )
            observabilityView?.frame = frame
            observabilityView?.isHidden = false
            observabilityView?.needsLayout = true
            observabilityView?.layout()

        } else {
            // Hide observability panel and show terminals
            observabilityView?.isHidden = true

            for terminal in leftTerminals {
                terminal.isHidden = false
            }
            rightTerminal?.isHidden = false

            relayout()
        }

        // Update the button icon
        contentView.updateObservabilityIcon(isShowingObservability: isShowingObservability)
        contentView.needsDisplay = true
    }

    func promoteLeftTerminal(at index: Int) {
        guard index < leftTerminals.count else {
            print("Tessera: cannot promote - index: \(index), left count: \(leftTerminals.count)")
            return
        }

        print("Tessera: promoting left terminal \(index) to right panel")

        let leftTerm = leftTerminals[index]

        // Hide the old right terminal if it exists and mark as not main
        if let oldRight = rightTerminal {
            oldRight.isHidden = true
            oldRight.isMainTerminal = false
        }

        // Show the selected left terminal in the right panel and mark as main
        rightTerminal = leftTerm
        leftTerm.isMainTerminal = true

        relayout()
    }

    func returnTerminalToLeft(_ terminal: TerminalView) {
        // Only process if this is the current right terminal
        guard terminal === rightTerminal else { return }

        print("Tessera: returning terminal to left panel")

        // Mark as not main terminal anymore
        terminal.isMainTerminal = false

        // Clear right terminal - don't promote anything else
        rightTerminal = nil

        // Make sure the terminal is visible (it will show in left panel)
        terminal.isHidden = false

        // Relayout to show all terminals in left panel only
        relayout()
    }

    func reorderTerminal(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < leftTerminals.count else { return }
        guard destinationIndex <= leftTerminals.count else { return }

        print("Tessera: reordering terminal from index \(sourceIndex) to \(destinationIndex)")

        // Remove terminal from source position
        let terminal = leftTerminals.remove(at: sourceIndex)

        // Calculate adjusted insertion index
        // If moving down (sourceIndex < destinationIndex), the removal shifts indices
        let adjustedDestination = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex

        // Insert at destination
        leftTerminals.insert(terminal, at: adjustedDestination)

        // Update terminal numbers
        for (idx, term) in leftTerminals.enumerated() {
            term.updateTerminalNumber(idx + 1)
        }

        // Relayout to update positions
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
    private var observabilityButton: NSButton!

    // Drag-and-drop state
    private var isDraggingTerminal = false
    private var draggedTerminalIndex: Int?
    private var dragStartLocation: NSPoint = .zero
    private var currentDragLocation: NSPoint = .zero
    private let dragThreshold: CGFloat = 5.0  // Minimum distance to start drag

    // Reordering state
    private var dropInsertionIndex: Int?  // Index where terminal would be inserted if dropped

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
        // '+' button - larger size
        let addButton = NSButton(frame: NSRect(x: 10, y: 5, width: 34, height: 34))
        addButton.title = ""
        addButton.bezelStyle = .rounded
        addButton.image = NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Add Terminal")
        addButton.contentTintColor = NSColor.systemGreen
        addButton.target = delegate
        addButton.action = #selector(AppDelegate.addNewTerminal)
        toolbar.addSubview(addButton)

        // Fullscreen toggle button - icon only
        let fullscreenButton = NSButton(frame: NSRect(x: 52, y: 5, width: 34, height: 34))
        fullscreenButton.title = ""
        fullscreenButton.bezelStyle = .rounded
        fullscreenButton.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Toggle Fullscreen")
        fullscreenButton.contentTintColor = NSColor.systemBlue
        fullscreenButton.target = delegate
        fullscreenButton.action = #selector(AppDelegate.toggleFullscreen)
        toolbar.addSubview(fullscreenButton)

        // Observability toggle button
        observabilityButton = NSButton(frame: NSRect(x: 94, y: 5, width: 34, height: 34))
        observabilityButton.title = ""
        observabilityButton.bezelStyle = .rounded
        observabilityButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Toggle Observability")
        observabilityButton.contentTintColor = NSColor.systemOrange
        observabilityButton.target = delegate
        observabilityButton.action = #selector(AppDelegate.toggleObservability)
        toolbar.addSubview(observabilityButton)
    }

    func updateObservabilityIcon(isShowingObservability: Bool) {
        if isShowingObservability {
            observabilityButton.image = NSImage(systemSymbolName: "tv.fill", accessibilityDescription: "Show Terminals")
        } else {
            observabilityButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Show Observability")
        }
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
                let indicator = "⇢ Reordering..."
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

        // Draw insertion line indicator when reordering
        if isDraggingTerminal, let insertIndex = dropInsertionIndex, let dragIndex = draggedTerminalIndex {
            // Don't draw if inserting at same position or adjacent position (no-op)
            if insertIndex != dragIndex && insertIndex != dragIndex + 1 {
                // Calculate Y position for insertion line
                let insertY: CGFloat
                if insertIndex == 0 {
                    // Insert at top
                    insertY = leftPanelFrames.first?.maxY ?? toolbarHeight
                } else if insertIndex >= leftPanelFrames.count {
                    // Insert at bottom
                    insertY = leftPanelFrames.last?.minY ?? toolbarHeight
                } else {
                    // Insert between terminals
                    insertY = leftPanelFrames[insertIndex - 1].minY
                }

                // Draw thick green insertion line
                NSColor.systemGreen.setStroke()
                let insertionLine = NSBezierPath()
                insertionLine.move(to: NSPoint(x: 0, y: insertY))
                insertionLine.line(to: NSPoint(x: leftWidth, y: insertY))
                insertionLine.lineWidth = 3
                insertionLine.stroke()

                // Draw arrow indicators at the ends
                let arrowSize: CGFloat = 6
                for x in [arrowSize, leftWidth - arrowSize] {
                    let arrowPath = NSBezierPath()
                    arrowPath.move(to: NSPoint(x: x - arrowSize, y: insertY - arrowSize))
                    arrowPath.line(to: NSPoint(x: x, y: insertY))
                    arrowPath.line(to: NSPoint(x: x - arrowSize, y: insertY + arrowSize))
                    NSColor.systemGreen.setFill()
                    arrowPath.fill()
                }
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

                // Calculate insertion index if dragging over left panel
                let leftWidth = bounds.width * appDelegate.splitRatio
                if location.x < leftWidth {
                    // Dragging in left panel - calculate insertion position
                    dropInsertionIndex = calculateInsertionIndex(at: location)
                } else {
                    // Dragging over right panel or elsewhere
                    dropInsertionIndex = nil
                }

                needsDisplay = true
            }
        }
    }

    // Calculate where a terminal would be inserted if dropped at this location
    private func calculateInsertionIndex(at location: NSPoint) -> Int? {
        guard let appDelegate = delegate else { return nil }
        guard !leftPanelFrames.isEmpty else { return nil }

        // Find which slot the cursor is closest to
        for (index, frame) in leftPanelFrames.enumerated() {
            let frameMidY = frame.midY

            if index == 0 {
                // Check if above first terminal
                if location.y > frame.maxY {
                    return 0
                }
            }

            // Check if between this terminal and the next
            if index < leftPanelFrames.count - 1 {
                let nextFrame = leftPanelFrames[index + 1]
                let dividerY = frame.minY  // Divider is at the bottom of current frame

                // If cursor is near this divider, insert after current terminal
                if location.y <= frame.maxY && location.y >= nextFrame.minY {
                    return index + 1
                }
            } else {
                // Last terminal - check if below it
                if location.y < frame.minY {
                    return leftPanelFrames.count
                }
            }
        }

        return nil
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
                // Check if reordering in left panel
                if let insertIndex = dropInsertionIndex {
                    // Dropped in left panel for reordering
                    if insertIndex != dragIndex && insertIndex != dragIndex + 1 {
                        print("Tessera: reordering terminal from \(dragIndex) to \(insertIndex)")
                        delegate?.reorderTerminal(from: dragIndex, to: insertIndex)
                    } else {
                        print("Tessera: drop at same position - no reorder needed")
                    }
                } else {
                    // Check if dropped on right panel
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
                        print("Tessera: drag cancelled - dropped outside valid area")
                    }
                }

                // Reset drag state and cursor
                isDraggingTerminal = false
                draggedTerminalIndex = nil
                dropInsertionIndex = nil
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

