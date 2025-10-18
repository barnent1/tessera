import Cocoa

class ColorManager {
    static let shared = ColorManager()

    private var appColors: [String: NSColor] = [:]
    private var sessionColors: [String: NSColor] = [:]

    private let colorPalette: [NSColor] = [
        NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),   // Blue
        NSColor(red: 0.9, green: 0.4, blue: 0.6, alpha: 1.0),   // Pink
        NSColor(red: 0.4, green: 0.8, blue: 0.5, alpha: 1.0),   // Green
        NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),   // Orange
        NSColor(red: 0.7, green: 0.4, blue: 0.9, alpha: 1.0),   // Purple
        NSColor(red: 0.3, green: 0.8, blue: 0.9, alpha: 1.0),   // Cyan
        NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),   // Yellow
        NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),   // Red
    ]

    private var nextAppColorIndex = 0
    private var nextSessionColorIndex = 0

    func colorForApp(_ appName: String) -> NSColor {
        if let color = appColors[appName] {
            return color
        }

        let color = colorPalette[nextAppColorIndex % colorPalette.count]
        appColors[appName] = color
        nextAppColorIndex += 1
        return color
    }

    func colorForSession(_ sessionId: String) -> NSColor {
        if let color = sessionColors[sessionId] {
            return color
        }

        let color = colorPalette[nextSessionColorIndex % colorPalette.count]
        sessionColors[sessionId] = color
        nextSessionColorIndex += 1
        return color
    }

    func gradientColorsForApp(_ appName: String) -> (NSColor, NSColor) {
        let baseColor = colorForApp(appName)
        let lighterColor = baseColor.blended(withFraction: 0.3, of: .white) ?? baseColor
        return (baseColor, lighterColor)
    }

    func gradientColorsForSession(_ sessionId: String) -> (NSColor, NSColor) {
        let baseColor = colorForSession(sessionId)
        let lighterColor = baseColor.blended(withFraction: 0.3, of: .white) ?? baseColor
        return (baseColor, lighterColor)
    }

    func colorForEventType(_ eventType: String) -> NSColor {
        // Fixed colors for specific event types
        switch eventType {
        case "PreToolUse":
            return NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)   // Blue
        case "PostToolUse":
            return NSColor(red: 0.4, green: 0.8, blue: 0.5, alpha: 1.0)   // Green
        case "Notification":
            return NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)   // Yellow
        case "Stop":
            return NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)   // Red
        case "SubagentStop":
            return NSColor(red: 0.7, green: 0.4, blue: 0.9, alpha: 1.0)   // Purple
        case "PreCompact":
            return NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)   // Orange
        case "UserPromptSubmit":
            return NSColor(red: 0.9, green: 0.4, blue: 0.6, alpha: 1.0)   // Pink
        case "SessionStart":
            return NSColor(red: 0.3, green: 0.8, blue: 0.9, alpha: 1.0)   // Cyan
        case "SessionEnd":
            return NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)   // Gray
        default:
            return NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)   // Default gray
        }
    }
}
