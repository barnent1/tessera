# Tessera Technical Documentation

Developer and architecture documentation for Tessera.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Layout Engine](#layout-engine)
4. [Event Handling](#event-handling)
5. [Settings System](#settings-system)
6. [Build System](#build-system)
7. [Dependencies](#dependencies)
8. [Extending Tessera](#extending-tessera)
9. [Code Style](#code-style)
10. [Development Workflow](#development-workflow)

## Architecture Overview

Tessera is a native macOS application built with Swift and AppKit. It uses the SwiftTerm library for embedded terminal emulation.

### Design Philosophy

1. **Minimal**: Single-purpose application focused on terminal tiling
2. **Native**: Pure AppKit, no cross-platform frameworks
3. **Embedded**: Terminals run within the app, no external dependencies
4. **Floating**: Always-accessible window that floats above other applications
5. **Self-contained**: No external configuration files or databases

### Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: AppKit (macOS native)
- **Terminal Emulation**: SwiftTerm 1.0+
- **Build System**: Swift Package Manager
- **Minimum macOS**: 13.0 (Ventura)

### Application Structure

```
AppDelegate (NSApplicationDelegate)
  ├─ NSWindow (floating, resizable)
  │   └─ ContentView (custom NSView)
  │       ├─ Toolbar (44px bottom bar)
  │       └─ Terminal Layout Area
  │           ├─ LeftTerminal[0..5] (TerminalView)
  │           └─ RightTerminal (TerminalView)
  ├─ SettingsWindow (NSWindow)
  └─ AboutWindowController (NSWindowController)
```

## Core Components

### 1. AppDelegate (appdelegate.swift)

**Responsibilities**:
- Application lifecycle management
- Window creation and configuration
- Terminal instance management
- Layout coordination
- Settings observation

**Key Properties**:
```swift
private var window: NSWindow!                    // Main floating window
private var contentView: ContentView!            // Custom content view
var leftTerminals: [TerminalView] = []           // Left column terminals (max 6)
var rightTerminal: TerminalView?                 // Currently displayed main panel
var splitRatio: CGFloat = 0.30                   // Left/right split (30%/70%)
private var settingsWindow: SettingsWindow?      // Settings panel
private var aboutWindow: AboutWindowController?  // About panel
private var isRightFullscreen = false            // Fullscreen state
```

**Key Methods**:

`applicationDidFinishLaunching(_:)` (Line 18-68)
- Creates and configures main window
- Restores saved window frame from UserDefaults
- Sets up application menu
- Observes settings changes

`addNewTerminal()` (Line 106-133)
- Creates new TerminalView instance
- Adds to leftTerminals array (max 6)
- Assigns terminal number for display
- Triggers relayout

`promoteLeftTerminal(at:)` (Line 182-201)
- Hides old right terminal
- Sets selected left terminal as new right terminal
- Triggers relayout

`toggleFullscreen()` (Line 135-180)
- Expands/contracts right terminal to fill window
- Hides/shows left terminals
- Toggles opaque background for fullscreen
- Hides/shows terminal headers

`relayout()` (Line 233-310)
- Core layout algorithm (see Layout Engine section)

### 2. ContentView (appdelegate.swift, line 313-652)

Custom NSView that handles the main workspace area.

**Responsibilities**:
- Drawing panel dividers
- Detecting and handling mouse interactions
- Managing drag-and-drop operations
- Providing visual feedback during interactions

**Key Properties**:
```swift
weak var delegate: AppDelegate?                  // Reference to app delegate
var leftPanelFrames: [CGRect] = []              // Calculated frames for click detection
let toolbarHeight: CGFloat = 44                  // Bottom toolbar height
private var isDraggingDivider = false           // Split divider drag state
private var isDraggingTerminal = false          // Terminal drag state
private var draggedTerminalIndex: Int?          // Which terminal is being dragged
private let dragThreshold: CGFloat = 5.0        // Minimum distance to start drag
```

**Mouse Event Flow**:

1. `mouseDown(with:)` (Line 520-562)
   - Detects clicks on divider or terminal headers
   - Records drag start location

2. `mouseDragged(with:)` (Line 564-597)
   - Handles divider dragging (adjusts split ratio)
   - Handles terminal dragging (shows visual feedback)
   - Checks drag threshold before starting drag operation

3. `mouseUp(with:)` (Line 599-642)
   - Completes divider drag (saves frame)
   - Completes terminal drag (promotes if dropped on right panel)
   - Treats sub-threshold drags as clicks

4. `mouseMoved(with:)` (Line 367-406)
   - Updates cursor based on hover location
   - Shows resize cursor over divider
   - Shows open hand cursor over terminal headers

**Drawing** (`draw(_:)` at line 426-518):
- Draws vertical divider between left and right panels
- Draws horizontal dividers between left terminals
- Highlights right panel during drag (green if valid drop zone)
- Shows "→ Shown in main panel" indicator for promoted terminal
- Shows "⇢ Dragging..." indicator during drag

### 3. TerminalView (TerminalView.swift)

Individual terminal panel with embedded SwiftTerm terminal.

**Structure**:
```swift
class TerminalView: NSView {
    private var terminalView: LocalProcessTerminalView!  // SwiftTerm instance
    private var headerView: NSView!                       // 24px draggable header
    let headerHeight: CGFloat = 24
    var terminalNumber: Int = 0                          // Display number (#1-#6)
}
```

**Initialization Flow** (lines 10-24):
1. Create view structure
2. Apply settings from Settings.shared
3. Start shell process (/bin/zsh -l)
4. Observe settings changes

**UI Structure** (`setupUI()` at line 28-77):
```
TerminalView (parent)
 ├─ terminalView (LocalProcessTerminalView)  [fills area below header]
 └─ headerView (DraggableHeaderView)         [24px top bar]
     ├─ dragIcon ("⋮⋮")                      [left side]
     └─ numberLabel ("#N")                   [right side]
```

**SwiftTerm Configuration** (`applySettings()` at line 79-97):
```swift
terminalView.nativeBackgroundColor = NSColor.clear  // Transparent
terminalView.nativeForegroundColor = settings.foregroundColor
terminalView.font = NSFont(name: settings.fontName, size: settings.fontSize)
terminalView.caretColor = settings.cursorColor
```

**Shell Process** (`startShell()` at line 109-112):
```swift
terminalView.startProcess(
    executable: "/bin/zsh",
    args: ["-l"],  // Login shell
    environment: getEnvironment()
)
```

**Environment Setup** (`getEnvironment()` at line 114-120):
- `TERM=xterm-256color` - 256 color support
- `COLORTERM=truecolor` - 24-bit color support
- Inherits all parent process environment variables

**Mouse Event Forwarding** (lines 126-161):
- Header clicks forwarded to ContentView for drag detection
- Terminal area clicks make terminal first responder for keyboard input
- Maintains `isForwardingMouseEvents` state to track event flow

**Fullscreen Support**:
- `setOpaqueBackground(_:)` (line 173-184): Toggles transparent/solid black background
- `setHeaderHidden(_:)` (line 187-198): Shows/hides header and adjusts terminal frame

### 4. Settings (Settings.swift)

Singleton settings manager using UserDefaults for persistence.

**Design Pattern**: Singleton with computed properties backed by UserDefaults

```swift
class Settings {
    static let shared = Settings()  // Singleton instance
    static let didChangeNotification = Notification.Name("SettingsDidChange")

    var windowOpacity: Double { get set }      // 0.5-1.0, default 0.85
    var fontName: String { get set }           // Default "Menlo"
    var fontSize: CGFloat { get set }          // Default 12.0
    var foregroundColor: NSColor { get set }   // Default green
    var backgroundColor: NSColor { get set }   // Default black
    var cursorColor: NSColor { get set }       // Default green
}
```

**Property Pattern** (example from lines 22-31):
```swift
var windowOpacity: Double {
    get {
        let value = UserDefaults.standard.double(forKey: Keys.opacity)
        return value > 0 ? value : 0.85  // Default if not set
    }
    set {
        UserDefaults.standard.set(newValue, forKey: Keys.opacity)
        postChangeNotification()  // Notify observers
    }
}
```

**Notification Flow**:
1. Setting changes via setter
2. Value saved to UserDefaults
3. `postChangeNotification()` posts `Settings.didChangeNotification`
4. Observers (AppDelegate, TerminalView) receive notification
5. Observers apply new settings

**Color Serialization** (lines 54-100):
- Uses `NSKeyedArchiver` for encoding NSColor to Data
- Uses `NSKeyedUnarchiver` for decoding Data to NSColor
- Fallback to defaults if decoding fails

### 5. SettingsWindow (SettingsWindow.swift)

Floating settings panel with live controls.

**Controls**:
- `NSSlider` for opacity (0.5-1.0)
- `NSPopUpButton` for font selection
- `NSSlider` with tick marks for font size (8-24pt)
- `NSColorWell` for foreground color
- `NSButton` for close action

**Real-time Updates**:
All controls directly modify `Settings.shared`, which triggers notifications that update all terminals instantly.

### 6. AboutWindowController (AboutWindow.swift)

Custom About panel showing app info.

**Window Configuration** (lines 8-25):
```swift
NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
    styleMask: [.titled, .closable],
    backing: .buffered,
    defer: false
)
window.level = .floating  // Appears on top
```

**Content Layout** (lines 32-95):
- App icon: 128x128 at top (loads AppIcon.icns)
- App name: "Tessera" in 26pt bold
- Version: From CFBundleShortVersionString
- Author: "by Glen Barnhardt"
- Description: Wrapping text field explaining the app

## Layout Engine

The layout algorithm in `relayout()` (appdelegate.swift:233-310).

### Layout Algorithm

**Input State**:
- `leftTerminals: [TerminalView]` - Array of terminal views
- `rightTerminal: TerminalView?` - Currently promoted terminal
- `splitRatio: CGFloat` - Left/right width ratio
- `contentView.bounds` - Available window space

**Layout Area Calculation** (lines 242-247):
```swift
let container = contentView.bounds
let layoutArea = NSRect(
    x: 0,
    y: toolbarHeight,  // 44px bottom toolbar
    width: container.width,
    height: container.height - toolbarHeight
)
```

**Width Split** (lines 249-250):
```swift
let leftW = floor(layoutArea.width * splitRatio)  // Default 30%
let rightW = layoutArea.width - leftW              // Remaining 70%
```

**Right Panel Positioning** (lines 255-265):
```swift
if let right = rightTerminal {
    let rightFrame = NSRect(
        x: leftW,              // Start after left column
        y: layoutArea.minY,    // Bottom of layout area
        width: rightW,         // 70% of width
        height: layoutArea.height  // Full height
    )
    right.frame = rightFrame
    right.isHidden = false
}
```

**Left Column Positioning** (lines 267-303):

For each terminal in `leftTerminals`:

1. Calculate tile height: `tileH = layoutArea.height / terminalCount`
2. Calculate Y position: `yPos = layoutArea.minY + (n - i - 1) * tileH` (bottom to top)
3. Calculate frame: `(x: 0, y: yPos, width: leftW, height: tileH)`
4. If terminal is currently shown on right:
   - Record frame but don't reposition (it's in right panel)
5. Else:
   - Set frame and make visible

**Frame Storage** (line 306):
```swift
contentView.leftPanelFrames = leftPanelFrames  // For click detection
```

### Layout Triggers

`relayout()` is called by:
- `addNewTerminal()` - After adding a terminal
- `promoteLeftTerminal(at:)` - After promoting a terminal
- `toggleFullscreen()` - When exiting fullscreen
- `windowDidEndLiveResize(_:)` - After window resize
- `windowDidExitFullScreen(_:)` - After exiting macOS fullscreen
- `windowDidDeminiaturize(_:)` - After un-minimizing window
- Split divider drag completion

## Event Handling

### Drag-and-Drop Architecture

**Three-phase process**:

1. **Detection Phase** (mouseDown):
   - ContentView detects click on terminal header
   - Records `dragStartLocation` and `draggedTerminalIndex`
   - Does NOT promote yet (wait to see if it's a drag)

2. **Drag Phase** (mouseDragged):
   - Calculates distance from start location
   - If distance > 5px: Start drag operation
     - Set `isDraggingTerminal = true`
     - Change cursor to closed hand
     - Trigger redraw for visual feedback
   - Update `currentDragLocation` for hover detection
   - ContentView draws:
     - Blue highlight on dragged terminal
     - Green highlight on right panel if cursor over it
     - "⇢ Dragging..." text on dragged terminal

3. **Completion Phase** (mouseUp):
   - If `isDraggingTerminal` is true (drag occurred):
     - Check if `location` is inside right panel rect
     - If yes: Call `delegate?.promoteLeftTerminal(at: index)`
     - If no: Cancel drag (no action)
   - Else (click, no drag):
     - Call `delegate?.promoteLeftTerminal(at: index)` immediately
   - Reset state: `isDraggingTerminal = false`, cursor to arrow

### Click Detection

ContentView maintains `leftPanelFrames: [CGRect]` array matching `leftTerminals` array.

In `mouseDown`:
```swift
for (index, terminal) in appDelegate.leftTerminals.enumerated() {
    let panelFrame = leftPanelFrames[index]
    let headerFrame = NSRect(
        x: panelFrame.x,
        y: panelFrame.maxY - 24,  // Top 24px
        width: panelFrame.width,
        height: 24
    )
    if headerFrame.contains(location) {
        // Record potential drag
        dragStartLocation = location
        draggedTerminalIndex = index
        return
    }
}
```

### Divider Dragging

**Hit Detection** (mouseMoved and mouseDown):
```swift
let dividerX = bounds.width * splitRatio
let dividerRect = NSRect(
    x: dividerX - 4,  // 8px wide hit area (4px each side)
    y: toolbarHeight,
    width: 8,
    height: bounds.height - toolbarHeight
)
```

**Drag Handling** (mouseDragged):
```swift
if isDraggingDivider {
    let newRatio = location.x / bounds.width
    appDelegate.splitRatio = max(0.15, min(0.85, newRatio))  // Constrain 15-85%
    appDelegate.relayout()
}
```

### Cursor Management

ContentView updates cursor in `mouseMoved`:
- Over divider: `NSCursor.resizeLeftRight`
- Over terminal header: `NSCursor.openHand`
- During drag: `NSCursor.closedHand` (set in mouseDragged)
- Default: `NSCursor.arrow`

## Settings System

### Architecture

**Singleton Pattern**: Single source of truth for all settings

**Persistence**: UserDefaults for automatic persistence across app launches

**Observation**: NotificationCenter for reactive updates

### Notification Flow Example

**User changes font size**:

1. User drags font size slider in SettingsWindow
2. `fontSizeChanged()` action fires (SettingsWindow.swift:133)
3. Updates `Settings.shared.fontSize = newValue`
4. Settings setter calls `postChangeNotification()` (Settings.swift:49-50)
5. NotificationCenter posts `Settings.didChangeNotification`
6. AppDelegate receives notification, calls `applyWindowOpacity()` (appdelegate.swift:75-83)
7. All TerminalViews receive notification, call `applySettings()` (TerminalView.swift:99-107)
8. Each terminal updates its font: `terminalView.font = newFont` (TerminalView.swift:90-91)
9. SwiftTerm redraws with new font

### UserDefaults Keys

Private enum in Settings.swift (lines 6-13):
```swift
private enum Keys {
    static let opacity = "windowOpacity"
    static let fontName = "fontName"
    static let fontSize = "fontSize"
    static let foregroundColor = "foregroundColor"
    static let backgroundColor = "backgroundColor"
    static let cursorColor = "cursorColor"
}
```

### Window Frame Persistence

Separate from Settings, managed by AppDelegate (lines 14-16, 29, 203-206):
```swift
private enum Prefs {
    static let savedFrame = "LayoutControllerSavedFrame"
}

// Restore on launch
let restored = UserDefaults.standard.string(forKey: Prefs.savedFrame)
    .flatMap(NSRectFromString)

// Save on move/resize
func saveFrame() {
    UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: Prefs.savedFrame)
}
```

## Build System

### Swift Package Manager

**Package.swift** configuration:
```swift
let package = Package(
    name: "Tessera",
    platforms: [.macOS(.v13)],  // Minimum macOS 13.0
    products: [
        .executable(name: "tessera", targets: ["Tessera"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Tessera",
            dependencies: ["SwiftTerm"],
            path: "sources/tessera"
        )
    ]
)
```

### Build Script (build.sh)

**Steps**:
1. Run `swift build -c release` (Swift Package Manager)
2. Create app bundle structure: `build/tessera.app/Contents/{MacOS,Resources}`
3. Copy binary: `.build/release/Tessera` → `Contents/MacOS/tessera`
4. Copy Info.plist: `info.plist` → `Contents/Info.plist`
5. Copy icon: `sources/resources/AppIcon.icns` → `Contents/Resources/`

**Output**: `build/tessera.app` - Complete .app bundle ready to launch

### Icon Generation (generate_icon.swift)

**Purpose**: Programmatically generate app icon using Core Graphics

**Process**:
1. For each size (16, 32, 64, 128, 256, 512, 1024):
   - Create CGContext of size × size
   - Draw dark background (RGB: 0.08, 0.08, 0.1)
   - Draw violet lines (RGB: 0.6, 0.3, 0.9) with 1.5% width
   - Draw mosaic pattern:
     - Outer border rectangle
     - Vertical divider at 24% (left/right split)
     - 3 horizontal dividers in left column (4 tiles)
   - Export as PNG
   - Export as PNG @2x (except 1024)
2. Run `iconutil -c icns` to convert iconset to .icns
3. Clean up temporary iconset directory

**Result**: `sources/resources/AppIcon.icns` with all required sizes

## Dependencies

### SwiftTerm

**Repository**: https://github.com/migueldeicaza/SwiftTerm

**Version**: 1.0.0+

**Usage**:
```swift
import SwiftTerm

let terminalView = LocalProcessTerminalView(frame: frameRect)
terminalView.startProcess(executable: "/bin/zsh", args: ["-l"], environment: env)
```

**Features Used**:
- `LocalProcessTerminalView` - Embedded terminal with PTY
- Font configuration (`font`, `nativeForegroundColor`, etc.)
- Cursor color configuration (`caretColor`)
- Background transparency support
- Full ANSI escape sequence support
- UTF-8 unicode support

**License**: MIT

## Extending Tessera

### Adding New Settings

1. Add property to `Settings.swift`:
```swift
var newSetting: Type {
    get {
        let value = UserDefaults.standard.object(forKey: Keys.newSetting) as? Type
        return value ?? defaultValue
    }
    set {
        UserDefaults.standard.set(newValue, forKey: Keys.newSetting)
        postChangeNotification()
    }
}
```

2. Add UI control to `SettingsWindow.swift`:
```swift
// In setupUI()
let control = NSSlider(...)
control.target = self
control.action = #selector(newSettingChanged)

// Add action handler
@objc private func newSettingChanged() {
    Settings.shared.newSetting = control.value
}
```

3. Apply setting in relevant components:
```swift
// In observeSettings() callback
private func applySettings() {
    let newValue = Settings.shared.newSetting
    // Apply to UI/state
}
```

### Adding Keyboard Shortcuts

Add to `setupApplicationMenu()` in AppDelegate:
```swift
let item = NSMenuItem(
    title: "Action",
    action: #selector(actionMethod),
    keyEquivalent: "k"  // ⌘K
)
item.keyEquivalentModifierMask = [.command, .shift]  // ⌘⇧K
appMenu.addItem(item)
```

### Changing Maximum Terminal Count

In `appdelegate.swift:110`:
```swift
if leftTerminals.count >= 8 {  // Change from 6 to 8
    print("Tessera: Maximum terminals reached (8)")
    return
}
```

### Customizing Terminal Shell

In `TerminalView.swift:111`:
```swift
terminalView.startProcess(
    executable: "/bin/bash",  // Change from /bin/zsh
    args: ["--login"],        // Change args
    environment: getEnvironment()
)
```

### Adding Menu Items

In `setupApplicationMenu()` (appdelegate.swift:85-102):
```swift
appMenu.addItem(NSMenuItem.separator())
appMenu.addItem(NSMenuItem(
    title: "New Action",
    action: #selector(newAction),
    keyEquivalent: "n"
))

// Add method
@objc func newAction() {
    // Implementation
}
```

## Code Style

### Naming Conventions

- **Classes**: PascalCase (e.g., `AppDelegate`, `TerminalView`)
- **Methods**: camelCase (e.g., `addNewTerminal()`, `relayout()`)
- **Properties**: camelCase (e.g., `leftTerminals`, `splitRatio`)
- **Constants**: PascalCase for enum cases (e.g., `Keys.opacity`)

### Access Control

- **private**: Internal implementation details (e.g., `private var isRightFullscreen`)
- **internal** (default): Component-level API
- **public**: Explicit public API (minimal use)

### Comments

- Brief comments for non-obvious logic
- Print statements for debugging state transitions
- No header comments (code should be self-documenting)

### Code Organization

Files organized by component:
- One primary class per file
- Related helper classes in same file (e.g., `DraggableHeaderView` in TerminalView.swift)
- MARK comments for logical sections (e.g., `// MARK: - Actions`)

## Development Workflow

### Quick Development Cycle

```bash
# 1. Make code changes
vim sources/tessera/appdelegate.swift

# 2. Rebuild
./build.sh

# 3. Run
open build/tessera.app

# Or combine 2-3:
./build.sh && open build/tessera.app
```

### Debugging

**Print Debugging**:
The code uses print statements extensively for state tracking:
```swift
print("Tessera: relayout started with \(leftTerminals.count) left terminals")
```

Enable Console.app to see output from GUI apps.

**Xcode Debugging**:
```bash
swift build -c debug
lldb .build/debug/Tessera
```

### Testing Layout Changes

After modifying `relayout()`:
1. Build and launch app
2. Add terminals using "+" button
3. Test scenarios:
   - Resize window
   - Change split ratio
   - Add/remove terminals
   - Promote terminals
   - Toggle fullscreen

No need to restart app - most changes apply on next relayout.

### Testing Settings Changes

After modifying Settings:
1. Build and launch app
2. Open Settings panel
3. Modify setting
4. Verify change applies to all terminals instantly
5. Restart app to verify persistence

### Icon Iteration

```bash
# 1. Modify generate_icon.swift
vim generate_icon.swift

# 2. Regenerate icon
swift generate_icon.swift

# 3. Rebuild app
./build.sh

# 4. Clear icon cache and launch
rm -rf ~/Library/Caches/com.apple.iconservices.store
killall Dock
open build/tessera.app
```

### Performance Profiling

Use Instruments for performance analysis:
```bash
# Build release version
swift build -c release

# Profile with Instruments
open -a Instruments
# Select Time Profiler or Allocations
# Target: build/tessera.app/Contents/MacOS/tessera
```

## Development Team

Tessera is developed by:
- **Glen Barnhardt** - Creator and lead developer
- **Claude Code** - AI-assisted development and architecture

Built with:
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza
- Swift and AppKit (Apple)
- Core Graphics for icon generation

## Project History

### Version 1.0 (2025)

**Initial Release Features**:
- Embedded terminal emulation with SwiftTerm
- Split-screen layout with adjustable divider
- Up to 6 terminals in left column
- Drag-and-drop terminal promotion
- Click-to-promote functionality
- Fullscreen mode
- Settings panel with customization options
- Violet line art icon
- Floating window that stays on top
- Persistent settings and window frame

**Original Prototype**:
The first version used Alacritty terminal with macOS Accessibility API to position external windows. This was replaced with embedded SwiftTerm terminals for better integration and user experience.

## Future Considerations

Potential future enhancements (not currently planned):

- **Keyboard shortcuts** for terminal switching
- **Terminal tabs** within each panel
- **Custom color schemes** (full theme support)
- **Split right panel** horizontally
- **Terminal session restoration** on app restart
- **Export/import settings**
- **Per-terminal shell configuration**
- **Terminal search** functionality
- **Copy mode** for text selection across screens

## Contributing

This is a personal project by Glen Barnhardt with assistance from Claude Code. Suggestions and bug reports are welcome via GitHub issues.

For code contributions:
1. Open an issue to discuss the change
2. Fork the repository
3. Create a feature branch
4. Submit a pull request with clear description

## License

Copyright (c) 2025 Glen Barnhardt

## Additional Resources

- **README.md**: General project documentation
- **USER_GUIDE.md**: End-user documentation
- **CLAUDE.md**: AI assistant guidance for code work
- **SPECIFICATION.md**: Original design specification
