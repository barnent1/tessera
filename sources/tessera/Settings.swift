import Cocoa

class Settings {
    static let shared = Settings()

    private enum Keys {
        static let opacity = "windowOpacity"
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let foregroundColor = "foregroundColor"
        static let backgroundColor = "backgroundColor"
        static let cursorColor = "cursorColor"
    }

    // Notification for when settings change
    static let didChangeNotification = Notification.Name("SettingsDidChange")

    private init() {}

    // MARK: - Properties

    var windowOpacity: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.opacity)
            return value > 0 ? value : 0.85  // Default 85%
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.opacity)
            postChangeNotification()
        }
    }

    var fontName: String {
        get {
            UserDefaults.standard.string(forKey: Keys.fontName) ?? "Menlo"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.fontName)
            postChangeNotification()
        }
    }

    var fontSize: CGFloat {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.fontSize)
            return value > 0 ? CGFloat(value) : 12.0  // Default 12pt
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: Keys.fontSize)
            postChangeNotification()
        }
    }

    var foregroundColor: NSColor {
        get {
            if let data = UserDefaults.standard.data(forKey: Keys.foregroundColor),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return .green  // Default green
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: Keys.foregroundColor)
                postChangeNotification()
            }
        }
    }

    var backgroundColor: NSColor {
        get {
            if let data = UserDefaults.standard.data(forKey: Keys.backgroundColor),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return .black  // Default black
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: Keys.backgroundColor)
                postChangeNotification()
            }
        }
    }

    var cursorColor: NSColor {
        get {
            if let data = UserDefaults.standard.data(forKey: Keys.cursorColor),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return .green  // Default green
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: Keys.cursorColor)
                postChangeNotification()
            }
        }
    }

    // MARK: - Helper

    private func postChangeNotification() {
        NotificationCenter.default.post(name: Settings.didChangeNotification, object: nil)
    }
}
