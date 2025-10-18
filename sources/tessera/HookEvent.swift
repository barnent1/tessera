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

    func sendRandomEvent() {
        let event = generateRandomEvent()
        sendEvent(event)
    }

    private func generateRandomEvent() -> [String: Any] {
        let app = apps.randomElement()!
        let sessionId = "session-\(Int.random(in: 100...999))"
        let eventType = eventTypes.randomElement()!

        var payload: [String: Any] = [:]

        if eventType == "PreToolUse" || eventType == "PostToolUse" {
            payload["tool_name"] = tools.randomElement()!
            payload["tool_input"] = ["command": "ls -la"]
        } else if eventType == "UserPromptSubmit" {
            payload["prompt"] = "This is a test prompt message from the fake event generator"
        }

        return [
            "source_app": app,
            "session_id": sessionId,
            "hook_event_type": eventType,
            "payload": payload,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
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
