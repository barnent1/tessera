import Cocoa

class ObservabilityView: NSView {
    // MARK: - Properties
    private let webSocketClient = WebSocketClient()
    private let fakeEventGenerator = FakeEventGenerator()
    private var events: [HookEvent] = []
    private var filteredEvents: [HookEvent] = []

    // UI Components
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let headerView = NSView()
    private let livePulseChart = LivePulseChartView()
    private let filterPanel = NSView()
    private let connectionStatusView = NSView()
    private let connectionDot = NSView()
    private let connectionLabel = NSTextField(labelWithString: "Disconnected")
    private let eventCountLabel = NSTextField(labelWithString: "0")
    private let toggleFiltersButton = NSButton()
    private let autoScrollButton = NSButton()
    private let testEventButton = NSButton()

    // Filter controls
    private let sourceAppPopup = NSPopUpButton()
    private let sessionIdPopup = NSPopUpButton()
    private let eventTypePopup = NSPopUpButton()

    // State
    private var isConnected = false
    private var showFilters = false
    private var autoScrollEnabled = true
    private var currentFilters = (sourceApp: "", sessionId: "", eventType: "")
    private var expandedRows = Set<Int>() // Track which rows are expanded
    private var chatTranscriptWindow: ChatTranscriptWindow?

    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        setupWebSocket()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupWebSocket()
    }

    // MARK: - Setup
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0).cgColor

        setupHeader()
        setupLivePulseChart()
        setupFilterPanel()
        setupTableView()
        setupAutoScrollButton()
        setupTestEventButton()

        filterPanel.isHidden = !showFilters
    }

    private func setupHeader() {
        headerView.wantsLayer = true
        headerView.translatesAutoresizingMaskIntoConstraints = true // Use manual layout
        headerView.autoresizesSubviews = true

        // Add gradient as sublayer instead of replacing the layer
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0).cgColor,
            NSColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = headerView.bounds
        gradient.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        headerView.layer?.addSublayer(gradient)
        gradient.zPosition = -1 // Put gradient behind content

        addSubview(headerView)

        // Title
        let titleLabel = NSTextField(labelWithString: "Multi-Agent Observability")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        titleLabel.drawsBackground = false
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        headerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16)
        ])

        // Connection status
        connectionStatusView.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(connectionStatusView)

        connectionDot.wantsLayer = true
        connectionDot.layer?.cornerRadius = 6
        connectionDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        connectionDot.translatesAutoresizingMaskIntoConstraints = false
        connectionStatusView.addSubview(connectionDot)

        connectionLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        connectionLabel.textColor = .white
        connectionLabel.drawsBackground = false
        connectionLabel.translatesAutoresizingMaskIntoConstraints = false
        connectionStatusView.addSubview(connectionLabel)

        NSLayoutConstraint.activate([
            connectionDot.leadingAnchor.constraint(equalTo: connectionStatusView.leadingAnchor),
            connectionDot.centerYAnchor.constraint(equalTo: connectionStatusView.centerYAnchor),
            connectionDot.widthAnchor.constraint(equalToConstant: 12),
            connectionDot.heightAnchor.constraint(equalToConstant: 12),

            connectionLabel.leadingAnchor.constraint(equalTo: connectionDot.trailingAnchor, constant: 6),
            connectionLabel.trailingAnchor.constraint(equalTo: connectionStatusView.trailingAnchor),
            connectionLabel.centerYAnchor.constraint(equalTo: connectionStatusView.centerYAnchor)
        ])

        // Event count
        eventCountLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        eventCountLabel.textColor = .white
        eventCountLabel.drawsBackground = false
        eventCountLabel.wantsLayer = true
        eventCountLabel.layer?.backgroundColor = NSColor(white: 0, alpha: 0.3).cgColor
        eventCountLabel.layer?.cornerRadius = 12
        eventCountLabel.alignment = .center
        eventCountLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(eventCountLabel)

        // Toggle filters button
        toggleFiltersButton.title = "📊"
        toggleFiltersButton.font = NSFont.systemFont(ofSize: 20)
        toggleFiltersButton.bezelStyle = .regularSquare
        toggleFiltersButton.isBordered = false
        toggleFiltersButton.wantsLayer = true
        toggleFiltersButton.layer?.backgroundColor = NSColor(white: 1, alpha: 0.2).cgColor
        toggleFiltersButton.layer?.cornerRadius = 8
        toggleFiltersButton.target = self
        toggleFiltersButton.action = #selector(toggleFiltersClicked)
        toggleFiltersButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(toggleFiltersButton)

        NSLayoutConstraint.activate([
            connectionStatusView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            connectionStatusView.trailingAnchor.constraint(equalTo: eventCountLabel.leadingAnchor, constant: -16),

            eventCountLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            eventCountLabel.trailingAnchor.constraint(equalTo: toggleFiltersButton.leadingAnchor, constant: -8),
            eventCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            toggleFiltersButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            toggleFiltersButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            toggleFiltersButton.widthAnchor.constraint(equalToConstant: 44),
            toggleFiltersButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupLivePulseChart() {
        livePulseChart.translatesAutoresizingMaskIntoConstraints = true // Use manual layout
        addSubview(livePulseChart)
        // Don't use Auto Layout - we'll set frame manually in layout()

        // Set up callbacks
        livePulseChart.onToggleSessionTags = { [weak self] in
            // Toggle session tags visibility
            print("Toggle session tags clicked")
        }

        livePulseChart.onUniqueAppsChanged = { [weak self] appNames in
            self?.updateFilterOptions()
        }

        livePulseChart.onEventClicked = { [weak self] event in
            self?.scrollToEvent(event)
        }
    }

    private func setupFilterPanel() {
        filterPanel.wantsLayer = true
        filterPanel.translatesAutoresizingMaskIntoConstraints = true // Use manual layout
        filterPanel.layer?.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.13, alpha: 1.0).cgColor
        addSubview(filterPanel)

        let filterLabel = NSTextField(labelWithString: "Filters:")
        filterLabel.font = NSFont.boldSystemFont(ofSize: 12)
        filterLabel.textColor = NSColor(red: 0.6, green: 0.6, blue: 0.8, alpha: 1.0)
        filterLabel.drawsBackground = false
        filterLabel.translatesAutoresizingMaskIntoConstraints = false
        filterPanel.addSubview(filterLabel)

        // Setup popups
        sourceAppPopup.target = self
        sourceAppPopup.action = #selector(filterChanged)
        sourceAppPopup.translatesAutoresizingMaskIntoConstraints = false
        filterPanel.addSubview(sourceAppPopup)

        sessionIdPopup.target = self
        sessionIdPopup.action = #selector(filterChanged)
        sessionIdPopup.translatesAutoresizingMaskIntoConstraints = false
        filterPanel.addSubview(sessionIdPopup)

        eventTypePopup.target = self
        eventTypePopup.action = #selector(filterChanged)
        eventTypePopup.translatesAutoresizingMaskIntoConstraints = false
        filterPanel.addSubview(eventTypePopup)

        NSLayoutConstraint.activate([
            filterLabel.leadingAnchor.constraint(equalTo: filterPanel.leadingAnchor, constant: 16),
            filterLabel.centerYAnchor.constraint(equalTo: filterPanel.centerYAnchor),

            sourceAppPopup.leadingAnchor.constraint(equalTo: filterLabel.trailingAnchor, constant: 12),
            sourceAppPopup.centerYAnchor.constraint(equalTo: filterPanel.centerYAnchor),
            sourceAppPopup.widthAnchor.constraint(equalToConstant: 150),

            sessionIdPopup.leadingAnchor.constraint(equalTo: sourceAppPopup.trailingAnchor, constant: 8),
            sessionIdPopup.centerYAnchor.constraint(equalTo: filterPanel.centerYAnchor),
            sessionIdPopup.widthAnchor.constraint(equalToConstant: 150),

            eventTypePopup.leadingAnchor.constraint(equalTo: sessionIdPopup.trailingAnchor, constant: 8),
            eventTypePopup.centerYAnchor.constraint(equalTo: filterPanel.centerYAnchor),
            eventTypePopup.widthAnchor.constraint(equalToConstant: 150)
        ])

        updateFilterOptions()
    }

    private func setupTableView() {
        // Create columns
        let colorColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("color"))
        colorColumn.title = ""
        colorColumn.width = 12
        colorColumn.minWidth = 12
        colorColumn.maxWidth = 12

        let emojiColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("emoji"))
        emojiColumn.title = ""
        emojiColumn.width = 24
        emojiColumn.minWidth = 24
        emojiColumn.maxWidth = 24

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 80
        timeColumn.minWidth = 60

        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "App"
        appColumn.width = 120
        appColumn.minWidth = 80

        let eventColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("event"))
        eventColumn.title = "Event"
        eventColumn.width = 120
        eventColumn.minWidth = 80

        let detailsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("details"))
        detailsColumn.title = "Details"
        detailsColumn.width = 300

        let summaryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("summary"))
        summaryColumn.title = "Summary"
        summaryColumn.width = 200

        tableView.addTableColumn(colorColumn)
        tableView.addTableColumn(emojiColumn)
        tableView.addTableColumn(timeColumn)
        tableView.addTableColumn(appColumn)
        tableView.addTableColumn(eventColumn)
        tableView.addTableColumn(detailsColumn)
        tableView.addTableColumn(summaryColumn)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAutomaticRowHeights = false // We'll manage row heights manually
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.gridColor = NSColor(white: 1, alpha: 0.1)
        tableView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
        tableView.headerView?.wantsLayer = true
        tableView.headerView?.layer?.backgroundColor = NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).cgColor

        // Enable row selection and click handling
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.doubleAction = #selector(tableRowClicked)

        print("ObservabilityView: Table view setup complete, doubleAction set")

        scrollView.translatesAutoresizingMaskIntoConstraints = true // Use manual layout
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)
        addSubview(scrollView)
    }

    private func setupAutoScrollButton() {
        autoScrollButton.title = "⬇"
        autoScrollButton.font = NSFont.systemFont(ofSize: 20)
        autoScrollButton.bezelStyle = .regularSquare
        autoScrollButton.isBordered = true
        autoScrollButton.wantsLayer = true
        updateAutoScrollButtonStyle()
        autoScrollButton.target = self
        autoScrollButton.action = #selector(toggleAutoScroll)
        autoScrollButton.translatesAutoresizingMaskIntoConstraints = true // Use manual layout
        addSubview(autoScrollButton)
    }

    private func setupTestEventButton() {
        testEventButton.title = "🧪 Send Test Event"
        testEventButton.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        testEventButton.bezelStyle = .regularSquare
        testEventButton.isBordered = true
        testEventButton.wantsLayer = true
        testEventButton.layer?.backgroundColor = NSColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0).cgColor
        testEventButton.layer?.cornerRadius = 8
        testEventButton.contentTintColor = .white
        testEventButton.target = self
        testEventButton.action = #selector(sendTestEvent)
        testEventButton.translatesAutoresizingMaskIntoConstraints = true // Use manual layout
        addSubview(testEventButton)
    }

    override func layout() {
        super.layout()

        let headerHeight: CGFloat = 60
        let chartHeight: CGFloat = 130
        let filterHeight: CGFloat = showFilters ? 50 : 0
        let buttonSize: CGFloat = 50

        var currentY = bounds.height

        // Header at top
        let headerFrame = CGRect(x: 0, y: currentY - headerHeight, width: bounds.width, height: headerHeight)
        headerView.frame = headerFrame

        // Update gradient layer frame to match header
        if let gradientLayer = headerView.layer?.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = headerView.bounds
        }
        currentY -= headerHeight

        // Live pulse chart below header
        let chartFrame = CGRect(x: 0, y: currentY - chartHeight, width: bounds.width, height: chartHeight)
        if livePulseChart.frame != chartFrame {
            print("🔶 ObservabilityView setting livePulseChart frame from \(livePulseChart.frame) to \(chartFrame)")
            livePulseChart.frame = chartFrame
        }
        currentY -= chartHeight

        // Filter panel below chart (if visible)
        if showFilters {
            filterPanel.frame = CGRect(x: 0, y: currentY - filterHeight, width: bounds.width, height: filterHeight)
            currentY -= filterHeight
        }

        // Table view takes remaining space
        scrollView.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: currentY
        )

        autoScrollButton.frame = CGRect(
            x: bounds.width - buttonSize - 20,
            y: 20,
            width: buttonSize,
            height: buttonSize
        )

        testEventButton.frame = CGRect(
            x: 20,
            y: 20,
            width: 150,
            height: 36
        )
    }

    // MARK: - WebSocket Setup
    private func setupWebSocket() {
        webSocketClient.onEventReceived = { [weak self] event in
            self?.handleNewEvent(event)
        }

        webSocketClient.onConnectionStatusChanged = { [weak self] connected in
            self?.updateConnectionStatus(connected)
        }

        webSocketClient.connect()
    }

    // MARK: - Event Handling
    private func handleNewEvent(_ event: HookEvent) {
        events.insert(event, at: 0) // Add to beginning for newest-first
        applyFilters()
        updateEventCount()

        // Add to live pulse chart
        livePulseChart.addEvent(event)

        if autoScrollEnabled {
            scrollToTop()
        }
    }

    private func scrollToTop() {
        if filteredEvents.count > 0 {
            tableView.scrollRowToVisible(0)
        }
    }

    private func scrollToEvent(_ event: HookEvent) {
        // Find the event in filteredEvents
        if let index = filteredEvents.firstIndex(where: { $0.id == event.id && $0.timestamp == event.timestamp }) {
            print("📜 Scrolling to event at row \(index)")
            tableView.scrollRowToVisible(index)

            // Flash the row to highlight it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            }

            // Clear selection after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.tableView.deselectAll(nil)
            }
        } else {
            print("⚠️ Event not found in filtered events")
        }
    }

    private func updateConnectionStatus(_ connected: Bool) {
        isConnected = connected
        connectionLabel.stringValue = connected ? "Connected" : "Disconnected"
        connectionDot.layer?.backgroundColor = (connected ? NSColor.systemGreen : NSColor.systemRed).cgColor

        if connected {
            animateConnectionDot()
        }
    }

    private func animateConnectionDot() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.3
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        connectionDot.layer?.add(animation, forKey: "pulse")
    }

    private func updateEventCount() {
        eventCountLabel.stringValue = "\(events.count)"
    }

    private func applyFilters() {
        filteredEvents = events.filter { event in
            if !currentFilters.sourceApp.isEmpty && event.sourceApp != currentFilters.sourceApp {
                return false
            }
            if !currentFilters.sessionId.isEmpty && event.sessionId != currentFilters.sessionId {
                return false
            }
            if !currentFilters.eventType.isEmpty && event.hookEventType != currentFilters.eventType {
                return false
            }
            return true
        }
        tableView.reloadData()
    }

    private func updateFilterOptions() {
        // Source Apps
        sourceAppPopup.removeAllItems()
        sourceAppPopup.addItem(withTitle: "All Apps")
        let apps = Set(events.map { $0.sourceApp }).sorted()
        apps.forEach { sourceAppPopup.addItem(withTitle: $0) }

        // Sessions
        sessionIdPopup.removeAllItems()
        sessionIdPopup.addItem(withTitle: "All Sessions")
        let sessions = Set(events.map { $0.sessionId }).sorted()
        sessions.forEach { sessionIdPopup.addItem(withTitle: $0) }

        // Event Types
        eventTypePopup.removeAllItems()
        eventTypePopup.addItem(withTitle: "All Events")
        let types = Set(events.map { $0.hookEventType }).sorted()
        types.forEach { eventTypePopup.addItem(withTitle: $0) }
    }

    // MARK: - Actions
    @objc private func toggleFiltersClicked() {
        showFilters.toggle()
        filterPanel.isHidden = !showFilters
        needsLayout = true
    }

    @objc private func filterChanged() {
        currentFilters = (
            sourceApp: sourceAppPopup.indexOfSelectedItem == 0 ? "" : sourceAppPopup.titleOfSelectedItem ?? "",
            sessionId: sessionIdPopup.indexOfSelectedItem == 0 ? "" : sessionIdPopup.titleOfSelectedItem ?? "",
            eventType: eventTypePopup.indexOfSelectedItem == 0 ? "" : eventTypePopup.titleOfSelectedItem ?? ""
        )
        applyFilters()
    }

    @objc private func toggleAutoScroll() {
        autoScrollEnabled.toggle()
        updateAutoScrollButtonStyle()

        if autoScrollEnabled {
            scrollToTop()
        }
    }

    @objc private func sendTestEvent() {
        fakeEventGenerator.sendRandomEvent()

        // Visual feedback
        testEventButton.layer?.backgroundColor = NSColor(red: 0.1, green: 0.5, blue: 0.2, alpha: 1.0).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.testEventButton.layer?.backgroundColor = NSColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0).cgColor
        }
    }

    @objc private func tableRowClicked() {
        let row = tableView.clickedRow
        print("🖱️ Double-click detected on row: \(row)")

        guard row >= 0 && row < filteredEvents.count else {
            print("❌ Row \(row) is out of bounds (filteredEvents.count = \(filteredEvents.count))")
            return
        }

        // Toggle expansion state
        if expandedRows.contains(row) {
            print("📤 Collapsing row \(row)")
            expandedRows.remove(row)
        } else {
            print("📥 Expanding row \(row)")
            expandedRows.insert(row)
        }

        print("📊 Expanded rows: \(expandedRows)")

        // Reload the specific row with animation
        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))

        // Force layout update
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
    }

    private func updateAutoScrollButtonStyle() {
        if autoScrollEnabled {
            autoScrollButton.layer?.backgroundColor = NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0).cgColor
            autoScrollButton.contentTintColor = .white
        } else {
            autoScrollButton.layer?.backgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0).cgColor
            autoScrollButton.contentTintColor = NSColor(white: 0.6, alpha: 1.0)
        }
        autoScrollButton.layer?.cornerRadius = 25
    }
}

// MARK: - NSTableViewDataSource
extension ObservabilityView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredEvents.count
    }
}

// MARK: - NSTableViewDelegate
extension ObservabilityView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let isExpanded = expandedRows.contains(row)
        let height: CGFloat = isExpanded ? 250 : 32
        if isExpanded {
            print("📏 Row \(row) height: \(height) (EXPANDED)")
        }
        return height
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredEvents.count else { return nil }
        let event = filteredEvents[row]
        let isExpanded = expandedRows.contains(row)

        // If expanded, show expanded view in the details column (spans most of the width)
        if isExpanded && tableColumn?.identifier.rawValue == "details" {
            print("🎨 Creating expanded content view for row \(row) in 'details' column")
            return createExpandedContentView(for: event, row: row)
        }

        let cell = NSTextField(labelWithString: "")
        cell.drawsBackground = false
        cell.isBezeled = false
        cell.font = NSFont.systemFont(ofSize: 11)
        cell.textColor = .white
        cell.lineBreakMode = .byTruncatingTail

        switch tableColumn?.identifier.rawValue {
        case "color":
            // Return a custom view with colored square
            let colorView = NSView(frame: NSRect(x: 0, y: 0, width: 12, height: 32))
            colorView.wantsLayer = true
            let squareSize: CGFloat = 8
            let squareY = (32 - squareSize) / 2
            let squareRect = NSRect(x: 2, y: squareY, width: squareSize, height: squareSize)
            let squareLayer = CALayer()
            squareLayer.frame = squareRect
            squareLayer.backgroundColor = ColorManager.shared.colorForEventType(event.hookEventType).cgColor
            colorView.layer?.addSublayer(squareLayer)
            return colorView

        case "emoji":
            if isExpanded { return NSView() } // Hide in expanded mode
            cell.stringValue = event.emoji
            cell.font = NSFont.systemFont(ofSize: 14)
            cell.alignment = .center

        case "time":
            if isExpanded { return NSView() }
            cell.stringValue = event.displayTimestamp
            cell.textColor = NSColor(white: 0.7, alpha: 1.0)

        case "app":
            if isExpanded { return NSView() }
            cell.stringValue = event.sourceApp
            let appColor = ColorManager.shared.colorForApp(event.sourceApp)
            cell.textColor = appColor
            cell.font = NSFont.boldSystemFont(ofSize: 11)

        case "event":
            if isExpanded { return NSView() }
            cell.stringValue = event.hookEventType
            cell.textColor = NSColor(red: 0.6, green: 0.6, blue: 0.8, alpha: 1.0)

        case "details":
            // Already handled above if expanded
            cell.stringValue = event.displayText
            cell.textColor = .white

        case "summary":
            if isExpanded { return NSView() }
            cell.stringValue = event.summary ?? ""
            cell.textColor = NSColor(white: 0.6, alpha: 1.0)
            cell.font = NSFont.systemFont(ofSize: 10)

        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let isExpanded = expandedRows.contains(row)
        let rowView = CustomTableRowView()
        rowView.isExpanded = isExpanded

        if row < filteredEvents.count {
            let event = filteredEvents[row]
            rowView.appColor = ColorManager.shared.colorForApp(event.sourceApp)
            rowView.sessionColor = ColorManager.shared.colorForSession(event.sessionId)
        }
        return rowView
    }

    private func createExpandedContentView(for event: HookEvent, row: Int) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        // Payload section
        let payloadLabel = NSTextField(labelWithString: "📦 Payload")
        payloadLabel.font = NSFont.boldSystemFont(ofSize: 12)
        payloadLabel.textColor = NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0)
        payloadLabel.drawsBackground = false
        payloadLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(payloadLabel)

        // Format payload as JSON
        let payloadDict = event.payload.mapValues { $0.value }
        let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict, options: [.prettyPrinted, .sortedKeys])
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        // Payload text view
        let payloadScrollView = NSScrollView()
        payloadScrollView.translatesAutoresizingMaskIntoConstraints = false
        payloadScrollView.hasVerticalScroller = true
        payloadScrollView.autohidesScrollers = true
        payloadScrollView.borderType = .lineBorder
        payloadScrollView.wantsLayer = true
        payloadScrollView.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0).cgColor
        payloadScrollView.layer?.borderColor = NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 0.3).cgColor
        payloadScrollView.layer?.borderWidth = 1
        payloadScrollView.layer?.cornerRadius = 4

        let payloadTextView = NSTextView()
        payloadTextView.string = jsonString
        payloadTextView.isEditable = false
        payloadTextView.isSelectable = true
        payloadTextView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        payloadTextView.textColor = .white
        payloadTextView.backgroundColor = .clear
        payloadScrollView.documentView = payloadTextView

        container.addSubview(payloadScrollView)

        // Copy button
        let copyButton = NSButton()
        copyButton.title = "📋 Copy"
        copyButton.bezelStyle = .rounded
        copyButton.font = NSFont.boldSystemFont(ofSize: 11)
        copyButton.wantsLayer = true
        copyButton.layer?.backgroundColor = NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0).cgColor
        copyButton.layer?.cornerRadius = 4
        copyButton.contentTintColor = .white
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.target = self
        copyButton.action = #selector(copyPayloadClicked(_:))
        copyButton.tag = row
        container.addSubview(copyButton)

        // Chat transcript button (if chat exists)
        if let chat = event.chat, !chat.isEmpty {
            let chatButton = NSButton()
            chatButton.title = "💬 View Chat (\(chat.count) messages)"
            chatButton.bezelStyle = .rounded
            chatButton.font = NSFont.boldSystemFont(ofSize: 11)
            chatButton.wantsLayer = true
            chatButton.layer?.backgroundColor = NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0).cgColor
            chatButton.layer?.cornerRadius = 4
            chatButton.contentTintColor = .white
            chatButton.translatesAutoresizingMaskIntoConstraints = false
            chatButton.target = self
            chatButton.action = #selector(viewChatTranscriptClicked(_:))
            chatButton.tag = row
            container.addSubview(chatButton)

            NSLayoutConstraint.activate([
                chatButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                chatButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
                chatButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
                chatButton.heightAnchor.constraint(equalToConstant: 28)
            ])
        }

        NSLayoutConstraint.activate([
            payloadLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            payloadLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),

            payloadScrollView.topAnchor.constraint(equalTo: payloadLabel.bottomAnchor, constant: 6),
            payloadScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            payloadScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            payloadScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -45),

            copyButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            copyButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            copyButton.widthAnchor.constraint(equalToConstant: 100),
            copyButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        return container
    }

    @objc private func copyPayloadClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < filteredEvents.count else { return }
        let event = filteredEvents[row]

        // Format payload as JSON and copy to clipboard
        let payloadDict = event.payload.mapValues { $0.value }
        if let jsonData = try? JSONSerialization.data(withJSONObject: payloadDict, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)

            // Visual feedback
            sender.title = "✅ Copied!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                sender.title = "📋 Copy"
            }
        }
    }

    @objc private func viewChatTranscriptClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < filteredEvents.count else { return }
        let event = filteredEvents[row]

        guard let chat = event.chat else { return }

        // Create and show chat transcript window
        chatTranscriptWindow = ChatTranscriptWindow(chat: chat)
        chatTranscriptWindow?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Custom Row View with Color Borders
class CustomTableRowView: NSTableRowView {
    var appColor: NSColor = .clear
    var sessionColor: NSColor = .clear
    var isExpanded: Bool = false

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)

        // Dark background with highlight if expanded
        if isExpanded {
            NSColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0).setFill()
        } else {
            NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).setFill()
        }
        dirtyRect.fill()

        // Ring border for expanded rows
        if isExpanded {
            let borderPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
            borderPath.lineWidth = 2
            NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0).setStroke()
            borderPath.stroke()
        }
    }
}
