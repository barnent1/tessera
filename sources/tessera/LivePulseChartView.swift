import Cocoa

class LivePulseChartView: NSView {
    // MARK: - Data structures
    struct ChartDataPoint {
        let timestamp: Date
        var count: Int
        var eventTypes: [String: Int] = [:]
        var sessions: [String: Int] = [:]
        var events: [HookEvent] = []

        mutating func addEvent(_ event: HookEvent) {
            count += 1
            eventTypes[event.hookEventType, default: 0] += 1
            sessions[event.sessionId, default: 0] += 1
            events.append(event)
        }
    }

    enum TimeRange: String, CaseIterable {
        case oneMin = "1m"
        case threeMin = "3m"
        case fiveMin = "5m"

        var seconds: TimeInterval {
            switch self {
            case .oneMin: return 60
            case .threeMin: return 180
            case .fiveMin: return 300
            }
        }

        var bucketCount: Int { return 60 }
        var bucketInterval: TimeInterval { return seconds / TimeInterval(bucketCount) }
    }

    // MARK: - Properties
    private var dataPoints: [ChartDataPoint] = []
    private var currentTimeRange: TimeRange = .oneMin
    private var displayTimer: Timer?
    private var animationTimer: Timer?

    // UI Components
    private let headerView = NSView()
    private let titleLabel = NSTextField(labelWithString: "📊 Live Activity Pulse")
    private let agentCountButton = NSButton()
    private let timeRangeSegmented = NSSegmentedControl()
    private let canvasView = ChartCanvasView()
    private let tooltipView = NSTextField(labelWithString: "")

    // State
    private var uniqueAppNames = Set<String>()
    private var showingTooltip = false
    private var tooltipTimer: Timer?
    private var isMouseInChart = false
    private var frozenTime: Date?

    // Callbacks
    var onToggleSessionTags: (() -> Void)?
    var onUniqueAppsChanged: (([String]) -> Void)?
    var onEventClicked: ((HookEvent) -> Void)?

    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        startUpdateTimer()
        print("LivePulseChartView initialized with frame: \(frameRect)")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        startUpdateTimer()
        print("LivePulseChartView initialized from coder")
    }

    deinit {
        stopTimers()
    }

    // MARK: - Setup
    private func setupUI() {
        wantsLayer = true
        autoresizesSubviews = true

        // Gradient background - add as sublayer instead of replacing layer
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor(red: 0.1, green: 0.1, blue: 0.13, alpha: 1.0).cgColor,
            NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = bounds
        gradient.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        gradient.zPosition = -1
        layer?.addSublayer(gradient)

        addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false

        setupTitle()
        setupAgentCountButton()
        setupTimeRangeSelector()
        setupCanvas()
        setupTooltip()

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupTitle() {
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 1.0)
        titleLabel.drawsBackground = false
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }

    private func setupAgentCountButton() {
        agentCountButton.title = "👥 0"
        agentCountButton.font = NSFont.boldSystemFont(ofSize: 12)
        agentCountButton.bezelStyle = .rounded
        agentCountButton.wantsLayer = true
        agentCountButton.layer?.backgroundColor = NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).cgColor
        agentCountButton.layer?.borderWidth = 1
        agentCountButton.layer?.borderColor = NSColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1.0).cgColor
        agentCountButton.layer?.cornerRadius = 6
        agentCountButton.contentTintColor = .white
        agentCountButton.target = self
        agentCountButton.action = #selector(agentCountClicked)
        agentCountButton.isHidden = true
        agentCountButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(agentCountButton)

        NSLayoutConstraint.activate([
            agentCountButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 12),
            agentCountButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            agentCountButton.heightAnchor.constraint(equalToConstant: 28),
            agentCountButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }

    private func setupTimeRangeSelector() {
        timeRangeSegmented.segmentCount = 3
        timeRangeSegmented.setLabel("1m", forSegment: 0)
        timeRangeSegmented.setLabel("3m", forSegment: 1)
        timeRangeSegmented.setLabel("5m", forSegment: 2)
        timeRangeSegmented.selectedSegment = 0
        timeRangeSegmented.segmentStyle = .rounded
        timeRangeSegmented.target = self
        timeRangeSegmented.action = #selector(timeRangeChanged)
        timeRangeSegmented.translatesAutoresizingMaskIntoConstraints = false

        // Style the segmented control
        if let cell = timeRangeSegmented.cell as? NSSegmentedCell {
            cell.trackingMode = .selectOne
        }

        headerView.addSubview(timeRangeSegmented)

        NSLayoutConstraint.activate([
            timeRangeSegmented.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            timeRangeSegmented.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            timeRangeSegmented.widthAnchor.constraint(equalToConstant: 140),
            timeRangeSegmented.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func setupCanvas() {
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.chartView = self
        canvasView.wantsLayer = true
        addSubview(canvasView)

        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 28),
            canvasView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            canvasView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            canvasView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    private func setupTooltip() {
        tooltipView.font = NSFont.boldSystemFont(ofSize: 11)
        tooltipView.textColor = .white
        tooltipView.drawsBackground = true
        tooltipView.backgroundColor = NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 0.95)
        tooltipView.isBezeled = false
        tooltipView.isEditable = false
        tooltipView.wantsLayer = true
        tooltipView.layer?.cornerRadius = 6
        tooltipView.layer?.borderWidth = 1
        tooltipView.layer?.borderColor = NSColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1.0).cgColor
        tooltipView.isHidden = true
        tooltipView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tooltipView)
    }

    // MARK: - Data Management
    func addEvent(_ event: HookEvent) {
        let now = Date()
        let bucketInterval = currentTimeRange.bucketInterval

        // Round timestamp to nearest bucket
        let eventTime = event.timestamp.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000.0) } ?? now
        let bucketTime = Date(timeIntervalSince1970: floor(eventTime.timeIntervalSince1970 / bucketInterval) * bucketInterval)

        // Find or create bucket
        if let index = dataPoints.firstIndex(where: { abs($0.timestamp.timeIntervalSince(bucketTime)) < 0.1 }) {
            dataPoints[index].addEvent(event)
        } else {
            var newPoint = ChartDataPoint(timestamp: bucketTime, count: 0)
            newPoint.addEvent(event)
            dataPoints.append(newPoint)
        }

        // Track unique apps
        uniqueAppNames.insert(event.sourceApp)
        updateAgentCount()

        // Trigger pulse animation
        canvasView.triggerPulse(at: canvasView.bounds.width - 20)

        // Clean old data
        cleanOldData()
        canvasView.needsDisplay = true
    }

    private func cleanOldData() {
        let cutoffTime = Date().addingTimeInterval(-currentTimeRange.seconds - 5) // Add 5 second buffer
        dataPoints.removeAll { $0.timestamp < cutoffTime }
        print("Cleaned old data, remaining points: \(dataPoints.count)")
    }

    private func updateAgentCount() {
        let count = uniqueAppNames.count
        agentCountButton.title = "👥 \(count)"
        agentCountButton.isHidden = count < 2

        onUniqueAppsChanged?(Array(uniqueAppNames).sorted())
    }

    func getChartData() -> [ChartDataPoint] {
        // Create full set of buckets for smooth animation
        // Use frozen time when mouse is in chart to prevent scrolling
        let now = isMouseInChart ? (frozenTime ?? Date()) : Date()
        let bucketInterval = currentTimeRange.bucketInterval
        let bucketCount = currentTimeRange.bucketCount

        var buckets: [ChartDataPoint] = []

        for i in 0..<bucketCount {
            let timestamp = now.addingTimeInterval(-TimeInterval(bucketCount - i - 1) * bucketInterval)

            // Find matching data point
            if let existingPoint = dataPoints.first(where: { abs($0.timestamp.timeIntervalSince(timestamp)) < bucketInterval / 2 }) {
                buckets.append(existingPoint)
            } else {
                buckets.append(ChartDataPoint(timestamp: timestamp, count: 0))
            }
        }

        // Debug: show how many non-zero buckets we have
        let activeCount = buckets.filter { $0.count > 0 }.count
        if activeCount > 0 {
            print("Chart data: \(activeCount)/\(buckets.count) buckets have data")
        }

        return buckets
    }

    // MARK: - Timer Management
    private func startUpdateTimer() {
        // Update display at 30 FPS
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.canvasView.needsDisplay = true
        }

        // Clean old data every second
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.cleanOldData()
        }
    }

    private func stopTimers() {
        displayTimer?.invalidate()
        animationTimer?.invalidate()
        tooltipTimer?.invalidate()
    }

    // MARK: - Actions
    @objc private func timeRangeChanged() {
        switch timeRangeSegmented.selectedSegment {
        case 0: currentTimeRange = .oneMin
        case 1: currentTimeRange = .threeMin
        case 2: currentTimeRange = .fiveMin
        default: break
        }

        cleanOldData()
        canvasView.needsDisplay = true
    }

    @objc private func agentCountClicked() {
        onToggleSessionTags?()
    }

    // MARK: - Tooltip
    func showTooltip(text: String, at point: NSPoint) {
        print("💬 Showing tooltip: '\(text)' at point: \(point)")
        tooltipView.stringValue = text
        tooltipView.sizeToFit()

        var tooltipFrame = tooltipView.frame
        tooltipFrame.size.width += 16
        tooltipFrame.size.height += 8
        tooltipFrame.origin = NSPoint(
            x: min(point.x, bounds.width - tooltipFrame.width - 10),
            y: point.y + 20
        )
        print("💬 Tooltip frame: \(tooltipFrame)")
        tooltipView.frame = tooltipFrame
        tooltipView.isHidden = false

        // Auto-hide after 2 seconds
        tooltipTimer?.invalidate()
        tooltipTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hideTooltip()
        }
    }

    func hideTooltip() {
        print("💬 Hiding tooltip")
        tooltipView.isHidden = true
    }

    override func layout() {
        super.layout()

        // Update gradient layer frame
        if let sublayers = layer?.sublayers {
            for sublayer in sublayers {
                if let gradient = sublayer as? CAGradientLayer {
                    gradient.frame = bounds
                    break
                }
            }
        }

        print("🔷 LivePulseChartView layout called, bounds: \(bounds), frame: \(frame)")
    }

    // MARK: - Mouse Interaction
    func freezeTimeline() {
        isMouseInChart = true
        frozenTime = Date()
        print("Timeline frozen at \(frozenTime!)")
    }

    func unfreezeTimeline() {
        isMouseInChart = false
        frozenTime = nil
        print("Timeline unfrozen")
    }
}

// MARK: - Chart Canvas View
class ChartCanvasView: NSView {
    weak var chartView: LivePulseChartView?

    private var pulseX: CGFloat = 0
    private var pulseRadius: CGFloat = 0
    private var pulseOpacity: CGFloat = 0
    private var isPulsing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        print("🎨 ChartCanvasView init with frame: \(frameRect)")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        print("🎨 ChartCanvasView init from coder")
    }

    override func layout() {
        super.layout()
        print("📐 ChartCanvasView layout, bounds: \(bounds)")
        updateTrackingAreas()
    }

    func triggerPulse(at x: CGFloat) {
        pulseX = x
        pulseRadius = 0
        pulseOpacity = 0.8
        isPulsing = true

        // Animate pulse
        animatePulse()
    }

    private func animatePulse() {
        guard isPulsing else { return }

        pulseRadius += 2
        pulseOpacity -= 0.02

        if pulseOpacity > 0 {
            needsDisplay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
                self?.animatePulse()
            }
        } else {
            isPulsing = false
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext,
              let chartView = chartView else { return }

        let data = chartView.getChartData()

        // Draw background grid
        drawGrid(in: ctx)

        // Draw time labels
        drawTimeLabels(in: ctx)

        // Draw bars
        drawBars(data, in: ctx)

        // Draw pulse effect
        if isPulsing {
            drawPulse(in: ctx)
        }
    }

    private func drawGrid(in ctx: CGContext) {
        let chartBottom: CGFloat = bounds.height - 5  // At the very bottom
        let lineHeight = (bounds.height - 25) * 1.25  // 25% taller

        // Horizontal baseline at bottom
        ctx.setStrokeColor(NSColor(white: 1, alpha: 0.3).cgColor)
        ctx.setLineWidth(1)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: chartBottom))
        ctx.addLine(to: CGPoint(x: bounds.width, y: chartBottom))
        ctx.strokePath()

        // Vertical lines - one for each time position, going UP from bottom
        let data = chartView?.getChartData() ?? []
        if !data.isEmpty {
            let spacing = bounds.width / CGFloat(data.count)

            ctx.setStrokeColor(NSColor(white: 1, alpha: 0.1).cgColor)
            ctx.setLineWidth(1)
            ctx.beginPath()
            for index in 0..<data.count {
                let centerX = CGFloat(index) * spacing + spacing / 2
                ctx.move(to: CGPoint(x: centerX, y: chartBottom))
                ctx.addLine(to: CGPoint(x: centerX, y: chartBottom + lineHeight))
            }
            ctx.strokePath()
        }
    }

    private func drawTimeLabels(in ctx: CGContext) {
        let labels = ["now", "-30s", "-1m"]
        let positions: [CGFloat] = [0.95, 0.5, 0.05]

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor(white: 0.5, alpha: 1.0)
        ]

        for (label, position) in zip(labels, positions) {
            let x = bounds.width * position
            let text = NSAttributedString(string: label, attributes: attributes)
            let textSize = text.size()
            text.draw(at: NSPoint(x: x - textSize.width / 2, y: 2))
        }
    }

    private func drawBars(_ data: [LivePulseChartView.ChartDataPoint], in ctx: CGContext) {
        guard !data.isEmpty else { return }

        let chartBottom: CGFloat = bounds.height - 5  // At the very bottom
        let lineHeight = (bounds.height - 25) * 1.25  // 25% taller
        let barWidth: CGFloat = 2  // Thin vertical line
        let spacing = bounds.width / CGFloat(data.count)

        for (index, point) in data.enumerated() {
            let centerX = CGFloat(index) * spacing + spacing / 2

            if point.count > 0 {
                // Get dominant event type
                guard let (eventType, _) = point.eventTypes.max(by: { $0.value < $1.value }) else { continue }

                let eventColor = ColorManager.shared.colorForEventType(eventType)
                let emoji = emojiForEventType(eventType)

                // Draw thin vertical colored line going UP from bottom
                let lineRect = CGRect(x: centerX - barWidth / 2, y: chartBottom, width: barWidth, height: lineHeight)
                ctx.setFillColor(eventColor.cgColor)
                ctx.fill(lineRect)

                // Draw gray rounded square background with icon, centered on vertical line
                let iconSize: CGFloat = 25
                let iconX = centerX - iconSize / 2
                let iconY = chartBottom + (lineHeight / 2) - (iconSize / 2)  // Centered vertically on line

                // Gray rounded rectangle background
                let bgRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
                let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4)
                NSColor(white: 0.3, alpha: 0.9).setFill()
                bgPath.fill()

                // Draw emoji centered in the square (smaller font)
                let fontSize: CGFloat = 12
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .foregroundColor: NSColor.white
                ]
                let text = NSAttributedString(string: emoji, attributes: attributes)
                let textSize = text.size()
                let textX = iconX + (iconSize - textSize.width) / 2
                let textY = iconY + (iconSize - textSize.height) / 2
                text.draw(at: NSPoint(x: textX, y: textY))
            }
        }
    }

    private func drawPulse(in ctx: CGContext) {
        let centerY = bounds.height / 2
        let color = NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: pulseOpacity)

        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(3)
        ctx.addArc(
            center: CGPoint(x: pulseX, y: centerY),
            radius: pulseRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )
        ctx.strokePath()
    }

    private func emojiForEventType(_ type: String) -> String {
        switch type {
        case "PreToolUse": return "🔧"
        case "PostToolUse": return "✅"
        case "Notification": return "🔔"
        case "Stop": return "🛑"
        case "SubagentStop": return "👥"
        case "PreCompact": return "📦"
        case "UserPromptSubmit": return "💬"
        case "SessionStart": return "🚀"
        case "SessionEnd": return "🏁"
        default: return "❓"
        }
    }

    private func formatEventTypeLabel(_ eventTypes: [String: Int]) -> String {
        // Sort by count descending and take top 3
        let sortedEntries = eventTypes.sorted { $0.value > $1.value }.prefix(3)

        return sortedEntries.map { (type, count) in
            let emoji = emojiForEventType(type)
            return count > 1 ? "\(emoji)×\(count)" : emoji
        }.joined()
    }

    override func mouseEntered(with event: NSEvent) {
        print("⚡️ Mouse ENTERED chart canvas at bounds: \(bounds)")
        chartView?.freezeTimeline()
        updateTooltip(for: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateTooltip(for: event)
    }

    override func mouseExited(with event: NSEvent) {
        print("⚡️ Mouse EXITED chart canvas")
        chartView?.unfreezeTimeline()
        chartView?.hideTooltip()
    }

    override func mouseDown(with event: NSEvent) {
        guard let chartView = chartView else { return }

        let location = convert(event.locationInWindow, from: nil)
        let data = chartView.getChartData()

        guard !data.isEmpty else { return }

        let totalBarWidth: CGFloat = 8
        let barGap: CGFloat = 2
        let totalWidth = CGFloat(data.count) * (totalBarWidth + barGap)
        let startX = bounds.width - totalWidth - 10

        // Find which bar was clicked
        for (index, point) in data.enumerated() {
            let x = startX + CGFloat(index) * (totalBarWidth + barGap)
            let barRect = CGRect(x: x, y: 25, width: totalBarWidth, height: bounds.height - 30)

            if barRect.contains(location) && point.count > 0 {
                // Found the clicked bar with events
                if let firstEvent = point.events.first {
                    print("📍 Clicked on bar with \(point.count) events, jumping to first event")
                    chartView.onEventClicked?(firstEvent)
                }
                break
            }
        }
    }

    private func updateTooltip(for event: NSEvent) {
        guard let chartView = chartView else {
            print("⚠️ updateTooltip: chartView is nil")
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let data = chartView.getChartData()

        print("🔍 updateTooltip called, location: \(location), data count: \(data.count)")

        guard !data.isEmpty else {
            print("🔍 No data, hiding tooltip")
            return
        }

        let barWidth = bounds.width / CGFloat(data.count)
        let index = Int(location.x / barWidth)

        guard index >= 0 && index < data.count else {
            chartView.hideTooltip()
            return
        }

        let point = data[index]
        if point.count > 0 {
            let eventTypesText = point.eventTypes.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            let text = "\(point.count) events (\(eventTypesText))"
            chartView.showTooltip(text: text, at: location)
        } else {
            chartView.hideTooltip()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        print("🔧 Updating tracking areas for ChartCanvasView, bounds: \(bounds)")

        trackingAreas.forEach { removeTrackingArea($0) }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)

        print("✅ Added tracking area: \(trackingArea)")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            print("🪟 ChartCanvasView moved to window, updating tracking areas")
            updateTrackingAreas()
        }
    }
}
