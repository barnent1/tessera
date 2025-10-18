import Foundation

// MARK: - HookEvent Data Models
struct HookEvent: Codable, Identifiable {
    let id: Int?
    let sourceApp: String
    let sessionId: String
    let hookEventType: String
    let payload: [String: AnyCodable]
    let chat: [AnyCodable]?
    let summary: String?
    let timestamp: Int?

    var displayTimestamp: String {
        guard let ts = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    var emoji: String {
        switch hookEventType {
        case "PreToolUse": return "🔧"
        case "PostToolUse": return "✅"
        case "Notification": return "🔔"
        case "Stop": return "🛑"
        case "SubagentStop": return "👥"
        case "PreCompact": return "📦"
        case "UserPromptSubmit": return "💬"
        case "SessionStart": return "🚀"
        case "SessionEnd": return "🏁"
        default: return "📋"
        }
    }

    var displayText: String {
        if hookEventType == "UserPromptSubmit" {
            if let prompt = payload["prompt"]?.value as? String {
                let truncated = prompt.prefix(100)
                return "Prompt: \"\(truncated)\(prompt.count > 100 ? "..." : "")\""
            }
        }

        if let toolName = payload["tool_name"]?.value as? String {
            return "Tool: \(toolName)"
        }

        if let summary = summary, !summary.isEmpty {
            return summary
        }

        return hookEventType
    }

    enum CodingKeys: String, CodingKey {
        case id, payload, chat, summary, timestamp
        case sourceApp = "source_app"
        case sessionId = "session_id"
        case hookEventType = "hook_event_type"
    }
}

// MARK: - AnyCodable for flexible JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - WebSocket Message
struct WebSocketMessage: Codable {
    let type: String
    let data: WebSocketData

    enum WebSocketData: Codable {
        case single(HookEvent)
        case multiple([HookEvent])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let single = try? container.decode(HookEvent.self) {
                self = .single(single)
            } else if let multiple = try? container.decode([HookEvent].self) {
                self = .multiple(multiple)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid data format")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .single(let event):
                try container.encode(event)
            case .multiple(let events):
                try container.encode(events)
            }
        }
    }
}

// MARK: - Fake Event Generator for Testing
class FakeEventGenerator {
    private let serverURL = "http://localhost:4000/events"
    private let apps = ["tessera", "test-app", "demo-agent", "cc-hooks-observability"]
    private let eventTypes = ["PreToolUse", "PostToolUse", "UserPromptSubmit", "Notification", "Stop", "SessionStart", "SessionEnd"]
    private let tools = ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
    private var eventCounter = 0

    func sendRandomEvent() {
        let event = generateRandomEvent()
        sendEvent(event)
    }

    private func generateRandomEvent() -> [String: Any] {
        eventCounter += 1
        let app = apps.randomElement()!
        let sessionId = "session-\(Int.random(in: 100...999))"
        let eventType = eventTypes.randomElement()!

        var payload: [String: Any] = [:]
        var chat: [[String: Any]]? = nil
        var summary: String? = nil

        if eventType == "PreToolUse" {
            let tool = tools.randomElement()!
            payload["tool_name"] = tool

            if tool == "Bash" {
                payload["tool_input"] = ["command": "ls -la /tmp"]
                summary = "Listing directory contents"
            } else if tool == "Read" {
                payload["tool_input"] = ["file_path": "/Users/test/project/main.swift"]
                summary = "Reading source file"
            } else if tool == "Write" {
                payload["tool_input"] = [
                    "file_path": "/Users/test/project/output.txt",
                    "content": "Test content"
                ]
                summary = "Writing to file"
            } else {
                payload["tool_input"] = ["pattern": "*.swift"]
                summary = "Searching for files"
            }

            // Add chat transcript for some events
            if eventCounter % 2 == 0 {
                chat = generateSampleChat(toolName: tool)
            }

        } else if eventType == "PostToolUse" {
            let tool = tools.randomElement()!
            payload["tool_name"] = tool
            payload["tool_output"] = ["result": "Operation completed successfully"]
            summary = "Tool execution completed"

            // Add chat transcript
            if eventCounter % 2 == 1 {
                chat = generateSampleChat(toolName: tool)
            }

        } else if eventType == "UserPromptSubmit" {
            let prompts = [
                "Read the main.swift file and explain what it does",
                "Create a new function to handle user input",
                "Search for all Swift files in the project",
                "Fix the compilation error in the AppDelegate",
                "Add error handling to the network request"
            ]
            payload["prompt"] = prompts.randomElement()!
            summary = "User submitted new request"

            // Always include chat for UserPromptSubmit
            chat = generateConversationChat()

        } else if eventType == "SessionStart" {
            payload["source"] = "startup"
            summary = "New session started"
        } else if eventType == "Notification" {
            payload["message"] = "Processing completed"
            summary = "System notification"
        }

        var result: [String: Any] = [
            "source_app": app,
            "session_id": sessionId,
            "hook_event_type": eventType,
            "payload": payload,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        if let chat = chat {
            result["chat"] = chat
        }

        if let summary = summary {
            result["summary"] = summary
        }

        return result
    }

    private func generateSampleChat(toolName: String) -> [[String: Any]] {
        return [
            [
                "type": "user",
                "message": [
                    "role": "user",
                    "content": "Please use the \(toolName) tool to help with this task"
                ],
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            [
                "type": "assistant",
                "message": [
                    "role": "assistant",
                    "content": [
                        [
                            "type": "text",
                            "text": "I'll use the \(toolName) tool to help you with that."
                        ],
                        [
                            "type": "tool_use",
                            "name": toolName,
                            "input": ["command": "test command"]
                        ]
                    ]
                ],
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            [
                "type": "system",
                "content": "PreToolUse:\(toolName) - Tool execution started",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        ]
    }

    private func generateConversationChat() -> [[String: Any]] {
        return [
            [
                "type": "user",
                "message": [
                    "role": "user",
                    "content": "I need help implementing a new feature for the app"
                ],
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-120))
            ],
            [
                "type": "assistant",
                "message": [
                    "role": "assistant",
                    "content": [
                        [
                            "type": "text",
                            "text": "I'd be happy to help! Let me first read the current codebase to understand the structure."
                        ],
                        [
                            "type": "tool_use",
                            "name": "Read",
                            "input": ["file_path": "/Users/test/project/main.swift"]
                        ]
                    ]
                ],
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-110))
            ],
            [
                "type": "system",
                "content": "PreToolUse:Read - Reading file main.swift",
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-100))
            ],
            [
                "type": "system",
                "content": "PostToolUse:Read - File read successfully (245 lines)",
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-95))
            ],
            [
                "type": "assistant",
                "message": [
                    "role": "assistant",
                    "content": [
                        [
                            "type": "text",
                            "text": "I've reviewed the code. Now I'll create a new function to implement the feature you requested."
                        ],
                        [
                            "type": "tool_use",
                            "name": "Write",
                            "input": [
                                "file_path": "/Users/test/project/NewFeature.swift",
                                "content": "func newFeature() {\n    // Implementation\n}"
                            ]
                        ]
                    ]
                ],
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-90))
            ],
            [
                "type": "user",
                "message": [
                    "role": "user",
                    "content": "Great! Can you also add error handling?"
                ],
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
            ],
            [
                "type": "assistant",
                "message": [
                    "role": "assistant",
                    "content": [
                        [
                            "type": "text",
                            "text": "Absolutely! Let me update the file with proper error handling."
                        ],
                        [
                            "type": "tool_use",
                            "name": "Edit",
                            "input": [
                                "file_path": "/Users/test/project/NewFeature.swift",
                                "old_string": "func newFeature() {\n    // Implementation\n}",
                                "new_string": "func newFeature() throws {\n    do {\n        // Implementation\n    } catch {\n        throw FeatureError.failed\n    }\n}"
                            ]
                        ]
                    ]
                ],
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-50))
            ],
            [
                "type": "system",
                "content": "PreToolUse:Edit - Editing file NewFeature.swift",
                "timestamp": ISO8601DateFormatter().string(from: Date().addingTimeInterval(-40))
            ]
        ]
    }

    private func sendEvent(_ event: [String: Any]) {
        guard let url = URL(string: serverURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: event)

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending fake event: \(error)")
                } else {
                    print("✅ Sent fake event: \(event["hook_event_type"] ?? "unknown")")
                }
            }
            task.resume()
        } catch {
            print("Error serializing event: \(error)")
        }
    }
}
