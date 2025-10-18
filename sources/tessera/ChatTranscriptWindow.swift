import Cocoa

class ChatTranscriptWindow: NSWindow {
    // MARK: - Properties
    private let chat: [AnyCodable]
    private var filteredChat: [AnyCodable] = []
    private var searchQuery = ""
    private var activeFilters = Set<String>()
    private var expandedMessages = Set<Int>()

    // UI Components
    private let headerView = NSView()
    private let titleLabel = NSTextField(labelWithString: "💬 Chat Transcript")
    private let closeButton = NSButton()
    private let searchField = NSSearchField()
    private let searchButton = NSButton()
    private let copyAllButton = NSButton()
    private let filterStackView = NSStackView()
    private let resultsLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()

    // Filter buttons
    private let filterTypes: [(type: String, label: String, icon: String)] = [
        ("user", "User", "👤"),
        ("assistant", "Assistant", "🤖"),
        ("system", "System", "⚙️"),
        ("tool_use", "Tool Use", "🔧"),
        ("tool_result", "Tool Result", "✅"),
        ("Read", "Read", "📄"),
        ("Write", "Write", "✍️"),
        ("Edit", "Edit", "✏️"),
        ("Glob", "Glob", "🔎"),
    ]

    // MARK: - Initialization
    init(chat: [AnyCodable]) {
        self.chat = chat
        self.filteredChat = chat

        // Calculate window size (85% of screen)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowWidth = screenFrame.width * 0.85
        let windowHeight = screenFrame.height * 0.85
        let windowX = screenFrame.minX + (screenFrame.width - windowWidth) / 2
        let windowY = screenFrame.minY + (screenFrame.height - windowHeight) / 2

        let contentRect = NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)

        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupUI()
        updateFilteredChat()
    }

    // MARK: - Setup
    private func setupWindow() {
        title = "Chat Transcript"
        isReleasedWhenClosed = false
        level = .normal  // Normal window behavior
        backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 0.98)

        // Handle ESC key
        if contentView != nil {
            _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // ESC key
                    self?.close()
                    return nil
                }
                return event
            }
        }
    }

    private func setupUI() {
        guard let contentView = contentView else { return }

        // Header
        setupHeader()
        contentView.addSubview(headerView)

        // Scroll view with chat messages
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0)

        // Stack view for messages
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Wrap stack view in a flipped clip view for proper scrolling
        let clipView = NSClipView()
        clipView.documentView = stackView
        scrollView.contentView = clipView

        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 180),

            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func setupHeader() {
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).cgColor
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.font = NSFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.drawsBackground = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        // Close button
        closeButton.title = "✕"
        closeButton.font = NSFont.systemFont(ofSize: 20)
        closeButton.bezelStyle = .rounded
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        closeButton.layer?.cornerRadius = 8
        closeButton.contentTintColor = .white
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(closeButton)

        // Search field
        searchField.placeholderString = "Search transcript..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        headerView.addSubview(searchField)

        // Search button
        searchButton.title = "Search"
        searchButton.bezelStyle = .rounded
        searchButton.wantsLayer = true
        searchButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        searchButton.layer?.cornerRadius = 6
        searchButton.contentTintColor = .white
        searchButton.target = self
        searchButton.action = #selector(executeSearch)
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(searchButton)

        // Copy All button
        copyAllButton.title = "📋 Copy All"
        copyAllButton.bezelStyle = .rounded
        copyAllButton.wantsLayer = true
        copyAllButton.layer?.backgroundColor = NSColor.systemGray.cgColor
        copyAllButton.layer?.cornerRadius = 6
        copyAllButton.contentTintColor = .white
        copyAllButton.target = self
        copyAllButton.action = #selector(copyAllClicked)
        copyAllButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(copyAllButton)

        // Filter stack view
        filterStackView.orientation = .horizontal
        filterStackView.spacing = 8
        filterStackView.translatesAutoresizingMaskIntoConstraints = false
        filterStackView.wantsLayer = true
        filterStackView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor
        filterStackView.layer?.cornerRadius = 8
        filterStackView.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        headerView.addSubview(filterStackView)

        // Add filter buttons
        for filter in filterTypes {
            let button = NSButton()
            button.title = "\(filter.icon) \(filter.label)"
            button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            button.bezelStyle = .rounded
            button.wantsLayer = true
            button.layer?.cornerRadius = 12
            updateFilterButtonStyle(button, isActive: false)
            button.target = self
            button.action = #selector(filterButtonClicked(_:))
            button.identifier = NSUserInterfaceItemIdentifier(filter.type)
            filterStackView.addArrangedSubview(button)
        }

        // Clear filters button
        let clearButton = NSButton()
        clearButton.title = "Clear All"
        clearButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        clearButton.bezelStyle = .rounded
        clearButton.wantsLayer = true
        clearButton.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.3).cgColor
        clearButton.layer?.cornerRadius = 12
        clearButton.contentTintColor = NSColor.systemRed
        clearButton.target = self
        clearButton.action = #selector(clearFiltersClicked)
        filterStackView.addArrangedSubview(clearButton)

        // Results label
        resultsLabel.font = NSFont.systemFont(ofSize: 12)
        resultsLabel.textColor = NSColor(white: 0.6, alpha: 1.0)
        resultsLabel.drawsBackground = false
        resultsLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(resultsLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),

            closeButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 32),

            searchButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchButton.trailingAnchor.constraint(equalTo: copyAllButton.leadingAnchor, constant: -8),
            searchButton.widthAnchor.constraint(equalToConstant: 80),
            searchButton.heightAnchor.constraint(equalToConstant: 32),

            copyAllButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            copyAllButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            copyAllButton.widthAnchor.constraint(equalToConstant: 100),
            copyAllButton.heightAnchor.constraint(equalToConstant: 32),

            filterStackView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            filterStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            filterStackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            filterStackView.heightAnchor.constraint(equalToConstant: 44),

            resultsLabel.topAnchor.constraint(equalTo: filterStackView.bottomAnchor, constant: 8),
            resultsLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20)
        ])

        updateResultsLabel()
    }

    // MARK: - Actions
    @objc private func closeClicked() {
        close()
    }

    @objc private func searchFieldChanged() {
        searchQuery = searchField.stringValue
    }

    @objc private func executeSearch() {
        searchQuery = searchField.stringValue
        updateFilteredChat()
    }

    @objc private func filterButtonClicked(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue else { return }

        if activeFilters.contains(identifier) {
            activeFilters.remove(identifier)
            updateFilterButtonStyle(sender, isActive: false)
        } else {
            activeFilters.insert(identifier)
            updateFilterButtonStyle(sender, isActive: true)
        }

        updateFilteredChat()
    }

    @objc private func clearFiltersClicked() {
        searchQuery = ""
        searchField.stringValue = ""
        activeFilters.removeAll()

        // Update all filter button styles
        for case let button as NSButton in filterStackView.arrangedSubviews {
            if button.identifier != nil {
                updateFilterButtonStyle(button, isActive: false)
            }
        }

        updateFilteredChat()
    }

    @objc private func copyAllClicked() {
        // Convert chat to JSON and copy
        let jsonData = try? JSONSerialization.data(withJSONObject: chat.map { $0.value }, options: [.prettyPrinted, .sortedKeys])
        if let jsonString = jsonData.flatMap({ String(data: $0, encoding: .utf8) }) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)

            copyAllButton.title = "✅ Copied!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.copyAllButton.title = "📋 Copy All"
            }
        }
    }

    // MARK: - Filtering
    private func updateFilteredChat() {
        filteredChat = chat.filter { item in
            // Check search query
            if !searchQuery.isEmpty && !matchesSearch(item, query: searchQuery) {
                return false
            }

            // Check filters
            if !activeFilters.isEmpty && !matchesFilters(item) {
                return false
            }

            return true
        }

        rebuildChatView()
        updateResultsLabel()
    }

    private func matchesSearch(_ item: AnyCodable, query: String) -> Bool {
        let lowerQuery = query.lowercased()

        // Convert to dictionary for easier access
        guard let dict = item.value as? [String: Any] else { return false }

        // Search in type
        if let type = dict["type"] as? String, type.lowercased().contains(lowerQuery) {
            return true
        }

        // Search in role
        if let role = dict["role"] as? String, role.lowercased().contains(lowerQuery) {
            return true
        }

        // Search in content (string)
        if let content = dict["content"] as? String, content.lowercased().contains(lowerQuery) {
            return true
        }

        // Search in message content
        if let message = dict["message"] as? [String: Any] {
            if let role = message["role"] as? String, role.lowercased().contains(lowerQuery) {
                return true
            }

            if let content = message["content"] as? String, content.lowercased().contains(lowerQuery) {
                return true
            }

            if let contentArray = message["content"] as? [[String: Any]] {
                for content in contentArray {
                    if let text = content["text"] as? String, text.lowercased().contains(lowerQuery) {
                        return true
                    }
                    if let name = content["name"] as? String, name.lowercased().contains(lowerQuery) {
                        return true
                    }
                }
            }
        }

        return false
    }

    private func matchesFilters(_ item: AnyCodable) -> Bool {
        guard let dict = item.value as? [String: Any] else { return false }

        // Check type filter
        if let type = dict["type"] as? String, activeFilters.contains(type) {
            return true
        }

        // Check role filter
        if let role = dict["role"] as? String, activeFilters.contains(role) {
            return true
        }

        // Check for tool use in message content
        if let message = dict["message"] as? [String: Any],
           let contentArray = message["content"] as? [[String: Any]] {
            for content in contentArray {
                if let contentType = content["type"] as? String, activeFilters.contains(contentType) {
                    return true
                }
                if let name = content["name"] as? String, activeFilters.contains(name) {
                    return true
                }
            }
        }

        // Check for system messages with tool names
        if let type = dict["type"] as? String, type == "system",
           let content = dict["content"] as? String {
            for filter in activeFilters {
                if content.contains(filter) {
                    return true
                }
            }
        }

        return false
    }

    private func updateResultsLabel() {
        if !searchQuery.isEmpty || !activeFilters.isEmpty {
            var resultText = "Showing \(filteredChat.count) of \(chat.count) messages"
            if !searchQuery.isEmpty {
                resultText += " (searching for \"\(searchQuery)\")"
            }
            resultsLabel.stringValue = resultText
            resultsLabel.isHidden = false
        } else {
            resultsLabel.isHidden = true
        }
    }

    private func updateFilterButtonStyle(_ button: NSButton, isActive: Bool) {
        if isActive {
            button.layer?.backgroundColor = NSColor.systemBlue.cgColor
            button.contentTintColor = .white
        } else {
            button.layer?.backgroundColor = NSColor(white: 0.25, alpha: 1.0).cgColor
            button.contentTintColor = NSColor(white: 0.7, alpha: 1.0)
        }
    }

    // MARK: - Chat View Building
    private func rebuildChatView() {
        // Remove all existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Add message views for filtered chat
        for (index, item) in filteredChat.enumerated() {
            let messageView = createMessageView(for: item, index: index)
            stackView.addArrangedSubview(messageView)
            messageView.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -32).isActive = true
        }

        // Add empty state if no messages
        if filteredChat.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No messages match the current filters")
            emptyLabel.font = NSFont.systemFont(ofSize: 14)
            emptyLabel.textColor = NSColor(white: 0.5, alpha: 1.0)
            emptyLabel.drawsBackground = false
            emptyLabel.alignment = .center
            stackView.addArrangedSubview(emptyLabel)
        }
    }

    private func createMessageView(for item: AnyCodable, index: Int) -> NSView {
        guard let dict = item.value as? [String: Any] else {
            return NSView()
        }

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        // Determine message type and color
        var messageType = "unknown"
        var bgColor = NSColor(white: 0.2, alpha: 1.0)
        var roleText = "Unknown"

        if let type = dict["type"] as? String {
            messageType = type
            switch type {
            case "user":
                bgColor = NSColor.systemBlue.withAlphaComponent(0.3)
                roleText = "User"
            case "assistant":
                bgColor = NSColor(white: 0.25, alpha: 1.0)
                roleText = "Assistant"
            case "system":
                bgColor = NSColor.systemOrange.withAlphaComponent(0.3)
                roleText = "System"
            default:
                break
            }
        } else if let role = dict["role"] as? String {
            messageType = role
            roleText = role.capitalized
            bgColor = role == "user" ? NSColor.systemBlue.withAlphaComponent(0.3) : NSColor(white: 0.25, alpha: 1.0)
        }

        container.layer?.backgroundColor = bgColor.cgColor

        // Role badge
        let roleLabel = NSTextField(labelWithString: roleText)
        roleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        roleLabel.textColor = .white
        roleLabel.drawsBackground = true
        roleLabel.backgroundColor = messageType == "user" ? .systemBlue : (messageType == "system" ? .systemOrange : .systemGray)
        roleLabel.wantsLayer = true
        roleLabel.layer?.cornerRadius = 12
        roleLabel.alignment = .center
        roleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(roleLabel)

        // Content
        let contentLabel = NSTextField(wrappingLabelWithString: extractMessageContent(from: dict))
        contentLabel.font = NSFont.systemFont(ofSize: 12)
        contentLabel.textColor = .white
        contentLabel.drawsBackground = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentLabel)

        // Show Details button
        let detailsButton = NSButton()
        detailsButton.title = expandedMessages.contains(index) ? "Hide Details" : "Show Details"
        detailsButton.bezelStyle = .rounded
        detailsButton.font = NSFont.systemFont(ofSize: 10)
        detailsButton.wantsLayer = true
        detailsButton.layer?.backgroundColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        detailsButton.layer?.cornerRadius = 4
        detailsButton.contentTintColor = .white
        detailsButton.target = self
        detailsButton.action = #selector(toggleDetailsClicked(_:))
        detailsButton.tag = index
        detailsButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(detailsButton)

        // Copy button
        let copyButton = NSButton()
        copyButton.title = "📋"
        copyButton.bezelStyle = .rounded
        copyButton.font = NSFont.systemFont(ofSize: 10)
        copyButton.wantsLayer = true
        copyButton.layer?.backgroundColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        copyButton.layer?.cornerRadius = 4
        copyButton.contentTintColor = .white
        copyButton.target = self
        copyButton.action = #selector(copyMessageClicked(_:))
        copyButton.tag = index
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(copyButton)

        var constraints = [
            roleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            roleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            roleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            roleLabel.heightAnchor.constraint(equalToConstant: 24),

            contentLabel.topAnchor.constraint(equalTo: roleLabel.bottomAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            contentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            detailsButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            detailsButton.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -8),
            detailsButton.heightAnchor.constraint(equalToConstant: 24),

            copyButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            copyButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            copyButton.widthAnchor.constraint(equalToConstant: 32),
            copyButton.heightAnchor.constraint(equalToConstant: 24)
        ]

        // Expanded details view
        if expandedMessages.contains(index) {
            let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
            let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            let detailsScrollView = NSScrollView()
            detailsScrollView.translatesAutoresizingMaskIntoConstraints = false
            detailsScrollView.hasVerticalScroller = true
            detailsScrollView.autohidesScrollers = true
            detailsScrollView.borderType = .lineBorder
            detailsScrollView.wantsLayer = true
            detailsScrollView.layer?.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0).cgColor
            detailsScrollView.layer?.cornerRadius = 4

            let detailsTextView = NSTextView()
            detailsTextView.string = jsonString
            detailsTextView.isEditable = false
            detailsTextView.isSelectable = true
            detailsTextView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            detailsTextView.textColor = .white
            detailsTextView.backgroundColor = .clear
            detailsScrollView.documentView = detailsTextView

            container.addSubview(detailsScrollView)

            constraints.append(contentsOf: [
                detailsScrollView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 12),
                detailsScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                detailsScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                detailsScrollView.heightAnchor.constraint(equalToConstant: 200),
                detailsScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
            ])
        } else {
            constraints.append(
                contentLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
            )
        }

        NSLayoutConstraint.activate(constraints)

        return container
    }

    private func extractMessageContent(from dict: [String: Any]) -> String {
        // Try different content formats
        if let content = dict["content"] as? String {
            return cleanContent(content)
        }

        if let message = dict["message"] as? [String: Any] {
            if let content = message["content"] as? String {
                return cleanContent(content)
            }

            if let contentArray = message["content"] as? [[String: Any]] {
                var parts: [String] = []
                for content in contentArray {
                    if let text = content["text"] as? String {
                        parts.append(text)
                    } else if let type = content["type"] as? String, type == "tool_use" {
                        if let name = content["name"] as? String {
                            parts.append("🔧 Tool: \(name)")
                        }
                    }
                }
                return parts.joined(separator: "\n")
            }
        }

        return "(No content)"
    }

    private func cleanContent(_ content: String) -> String {
        // Remove ANSI codes and command tags
        return content
            .replacingOccurrences(of: #"\u001b\[[0-9;]*m"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<command-[^>]+>.*?</command-[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func toggleDetailsClicked(_ sender: NSButton) {
        let index = sender.tag
        if expandedMessages.contains(index) {
            expandedMessages.remove(index)
        } else {
            expandedMessages.insert(index)
        }
        rebuildChatView()
    }

    @objc private func copyMessageClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < filteredChat.count else { return }

        let item = filteredChat[index]
        if let dict = item.value as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)

            sender.title = "✅"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                sender.title = "📋"
            }
        }
    }
}
