# Tessera - Tiled Terminal Application Specification

## Overview

**Tessera** (pronounced TESS-er-ah) is a native macOS application that provides an embedded tiled terminal workspace. It creates a split-screen layout with multiple terminal panels in a single floating window, allowing users to work with up to 6 terminals simultaneously.

The name "Tessera" comes from the small tiles used in mosaics, reflecting the application's tiled terminal layout.

## Project Goals

1. **Embedded terminal experience** - Provide fully integrated terminals within a single application window
2. **Efficient workspace layout** - Use an adjustable split between left column and main panel for optimal focus
3. **Interactive terminal management** - Allow quick switching between terminals via click or drag-and-drop
4. **Minimal, transparent design** - Stay out of the user's way with a clean, floating interface
5. **Customizable appearance** - Support user preferences for fonts, colors, and transparency
6. **Persistent configuration** - Remember window position, size, and settings across sessions

## Visual Design

```
┌─────────────────────────────────────────────────────────────┐
│ Tessera                                                  ⊙ ⊖ ⊗│ ← Title bar
├──────────┬──────────────────────────────────────────────────┤
│ ⋮⋮   #1  │                                                  │
│          │                                                  │
│          │                                                  │
├──────────┤                                                  │
│ ⋮⋮   #2  │                                                  │
│          │         Main Terminal Panel                     │
│          │         (Right - 70% width default)              │
├──────────┤                                                  │
│ ⋮⋮   #3  │                                                  │
│          │                                                  │
│          │                                                  │
├──────────┤                                                  │
│ ⋮⋮   #4  │                                                  │
│          │                                                  │
│          │                                                  │
├──────────┴──────────────────────────────────────────────────┤
│  [+]  [⤢ Fullscreen]                                        │ ← Bottom toolbar
└─────────────────────────────────────────────────────────────┘

Left column: 30% width default - displays up to 6 terminals with draggable headers
Right panel: 70% width default - displays the currently selected main terminal
Adjustable split: Drag vertical divider to adjust ratio (15%-85%)
```

## Core Features

### 1. Embedded Terminal Panels

**Terminal Emulation**
- Uses SwiftTerm library for embedded terminal emulation
- Each terminal runs `/bin/zsh -l` (login shell) with full environment
- Supports 256 colors (`TERM=xterm-256color`)
- Supports true color (`COLORTERM=truecolor`)
- Full ANSI escape sequence support
- UTF-8 unicode support

**Terminal Headers (24px)**
- Drag handle icon (⋮⋮) on left
- Terminal number (#1-#6) on right
- Click to instantly promote to main panel
- Drag to main panel with visual feedback

**Visual Design**
- Transparent backgrounds (window opacity applies to all terminals)
- 1px dark gray borders between terminals
- Configurable fonts and colors via Settings

### 2. Window Layout Management

**Left Column (Default 30% width)**
- Displays up to 6 terminals stacked vertically
- Each terminal evenly sized within the column
- Terminal headers show drag handle and number
- Terminals can be clicked or dragged to promote
- Shows "→ Shown in main panel" indicator for promoted terminal

**Main Panel (Default 70% width)**
- Displays currently selected terminal in large view
- Initially empty until first terminal is added
- User selects which terminal to display via click or drag
- Full terminal functionality with maximum workspace

**Adjustable Split**
- Drag vertical divider between columns to adjust split ratio
- Constrained between 15% and 85%
- Cursor changes to ↔ when hovering over divider
- Layout updates instantly during drag

**Automatic Layout**
- All terminals resize automatically when:
  - Window is resized
  - Split ratio is adjusted
  - Terminals are added or removed
  - Fullscreen mode is toggled

### 3. User Interactions

**Adding Terminals**
- Click "+" button in bottom toolbar
- Creates new TerminalView with SwiftTerm terminal
- Adds to left column (maximum 6 terminals)
- Assigns terminal number (#1-#6)
- Layout recalculates automatically

**Promoting Terminals (Two Methods)**

*Method 1: Click*
- Click any terminal header in left column
- Terminal instantly appears in main panel
- Previous main panel terminal remains in left column

*Method 2: Drag and Drop*
- Click and hold on terminal header
- Drag toward main panel (minimum 5px movement to start drag)
- Visual feedback:
  - Dragged terminal shows blue highlight and "⇢ Dragging..." text
  - Main panel shows green highlight when cursor is over it
  - Cursor changes to closed hand during drag
- Release over main panel to complete promotion
- Release elsewhere to cancel

**Fullscreen Mode**
- Click "⤢ Fullscreen" button in toolbar
- Main panel terminal expands to fill entire window (except toolbar)
- Left column terminals are hidden
- Terminal header is hidden
- Background becomes solid black for focus
- Click "⤢ Fullscreen" again to restore normal layout

**Application Menu (Tessera → ...)**
- "About Tessera": Shows custom About panel with icon, version, author
- "Settings..." (⌘,): Opens Settings panel for customization
- "Quit Tessera" (⌘Q): Terminates the application

### 4. Customization

**Settings Panel** (400×240, floating)

*Window Opacity*
- Slider from 50% to 100%
- Default: 85%
- Applies to window background, terminals are transparent

*Font Selection*
- Popup menu with 6 monospace fonts:
  - Menlo (default)
  - Monaco
  - SF Mono
  - Courier New
  - Courier
  - Andale Mono

*Font Size*
- Slider with tick marks from 8pt to 24pt
- Default: 12pt
- Live label shows current size

*Font Color*
- Color well for selecting text color
- Default: Green (classic terminal style)

*All changes apply instantly* to all terminals via NotificationCenter

### 5. Persistence

**Window Frame**
- Position and size saved to UserDefaults on move/resize
- Key: `LayoutControllerSavedFrame`
- Restored on next launch
- Default: Centered, 72% width × 75% height of screen

**Settings**
- All settings saved to UserDefaults automatically
- Restored on launch
- No configuration files needed

## Technical Architecture

### Technologies

- **Language**: Swift 5.9+
- **UI Framework**: AppKit (native macOS)
- **Terminal Library**: SwiftTerm 1.0+
- **Build System**: Swift Package Manager
- **Target**: macOS 13.0 (Ventura) or later

### Key Components

**AppDelegate** (`sources/tessera/appdelegate.swift`, ~650 lines)
- Main application controller
- Manages floating NSWindow with ContentView
- Tracks leftTerminals array (up to 6 TerminalView instances)
- Tracks rightTerminal reference (currently displayed)
- Implements layout algorithm
- Handles fullscreen mode
- Observes settings changes

**ContentView** (nested in appdelegate.swift, ~340 lines)
- Custom NSView for workspace area
- Renders bottom toolbar with buttons
- Draws panel dividers (vertical and horizontal)
- Handles mouse events for clicks and drags
- Provides visual feedback during interactions
- Manages split divider dragging

**TerminalView** (`sources/tessera/TerminalView.swift`, ~235 lines)
- Individual terminal panel
- Embeds SwiftTerm's `LocalProcessTerminalView`
- 24px draggable header with icon and number
- Transparent background to show window opacity
- Forwards header mouse events for drag detection
- Observes and applies settings changes

**Settings** (`sources/tessera/Settings.swift`, ~108 lines)
- Singleton settings manager
- UserDefaults persistence
- NotificationCenter for change notifications
- Computed properties for all settings

**SettingsWindow** (`sources/tessera/SettingsWindow.swift`, ~146 lines)
- Floating settings UI
- Controls for all customization options
- Instant application of changes

**AboutWindowController** (`sources/tessera/AboutWindow.swift`, ~123 lines)
- Custom About panel
- Displays app icon, version, author, description

### Layout Algorithm

Located in `AppDelegate.relayout()` (appdelegate.swift:233-310):

**Inputs:**
- `leftTerminals: [TerminalView]` (array of terminal instances)
- `rightTerminal: TerminalView?` (currently promoted terminal)
- `splitRatio: CGFloat` (0.15-0.85)
- `window.contentView.bounds` (available space)
- `toolbarHeight: CGFloat = 44` (bottom toolbar)

**Process:**
1. Calculate layout area (window bounds minus toolbar)
2. Calculate left width: `layoutArea.width × splitRatio`
3. Calculate right width: `layoutArea.width - leftWidth`
4. Position right terminal (if exists):
   - x: leftWidth
   - y: toolbarHeight
   - width: rightWidth
   - height: layoutArea.height
5. Position each left terminal:
   - Divide left column height evenly: `tileHeight = layoutArea.height / terminalCount`
   - Stack from bottom to top: `y = layoutArea.minY + (n - i - 1) × tileHeight`
   - If terminal is currently shown on right, don't reposition (it's in main panel)
6. Store left panel frames for click detection

**Triggers:**
- `addNewTerminal()` - After adding a terminal
- `promoteLeftTerminal(at:)` - After promoting a terminal
- `toggleFullscreen()` - When exiting fullscreen
- `windowDidEndLiveResize(_:)` - After window resize
- `windowDidMove(_:)` - After window move (also saves frame)
- `windowDidExitFullScreen(_:)` - After exiting macOS fullscreen
- `windowDidDeminiaturize(_:)` - After un-minimizing window
- Split divider drag completion

### Event Handling

**Drag-and-Drop Flow:**

1. **Detection Phase** (ContentView.mouseDown):
   - Detects click location in window coordinates
   - Checks if click is on vertical divider → set `isDraggingDivider`
   - Checks if click is on any left terminal header → record `draggedTerminalIndex`
   - Records `dragStartLocation` but doesn't promote yet (wait to see if it's a drag)

2. **Drag Phase** (ContentView.mouseDragged):
   - If dragging divider: Calculate new split ratio, apply, trigger relayout
   - If dragging terminal:
     - Calculate distance from start location
     - If distance > 5px and not yet dragging: Start drag operation
       - Set `isDraggingTerminal = true`
       - Change cursor to closed hand
       - Trigger redraw for visual feedback
     - Update `currentDragLocation` for hover detection
     - ContentView.draw renders:
       - Blue highlight + "⇢ Dragging..." on dragged terminal
       - Green highlight on main panel if cursor is over it

3. **Completion Phase** (ContentView.mouseUp):
   - If was dragging divider: Save window frame, reset state
   - If was dragging terminal:
     - Check if `currentDragLocation` is inside main panel rect
     - If yes: Call `delegate.promoteLeftTerminal(at: draggedTerminalIndex)`
     - If no: Cancel drag (no action)
   - Else (click, no drag):
     - Call `delegate.promoteLeftTerminal(at: draggedTerminalIndex)` immediately
   - Reset state: `isDraggingTerminal = false`, cursor to arrow, trigger redraw

**Cursor Management** (ContentView.mouseMoved):
- Over divider: `NSCursor.resizeLeftRight`
- Over terminal header: `NSCursor.openHand`
- During drag: `NSCursor.closedHand` (set in mouseDragged)
- Default: `NSCursor.arrow`

### Settings Notification Flow

Example: User changes font size in Settings panel

1. User drags font size slider
2. `fontSizeChanged()` action fires in SettingsWindow
3. Updates `Settings.shared.fontSize = newValue`
4. Settings setter saves to UserDefaults and calls `postChangeNotification()`
5. NotificationCenter posts `Settings.didChangeNotification`
6. AppDelegate receives notification, updates window opacity
7. All TerminalView instances receive notification, call `applySettings()`
8. Each TerminalView updates its SwiftTerm font: `terminalView.font = newFont`
9. SwiftTerm redraws with new font

All settings changes propagate instantly to all terminals.

## Build System

### Swift Package Manager

**Package.swift Configuration:**
```swift
let package = Package(
    name: "Tessera",
    platforms: [.macOS(.v13)],
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

**Process:**
1. Run `swift build -c release` (Swift Package Manager)
2. Create app bundle structure: `build/tessera.app/Contents/{MacOS,Resources}`
3. Copy binary: `.build/release/Tessera` → `Contents/MacOS/tessera`
4. Copy Info.plist: `info.plist` → `Contents/Info.plist`
5. Copy icon: `sources/resources/AppIcon.icns` → `Contents/Resources/`

**Output:** `build/tessera.app` - Complete .app bundle ready to launch

**Usage:**
```bash
./build.sh
open build/tessera.app
```

### Icon Generation

**generate_icon.swift** creates the violet line art mosaic icon:

1. For each size (16, 32, 64, 128, 256, 512, 1024):
   - Create CGContext of size × size
   - Fill dark background (RGB: 0.08, 0.08, 0.1)
   - Draw violet lines (RGB: 0.6, 0.3, 0.9) with 1.5% width
   - Draw mosaic pattern:
     - Outer border rectangle (10% padding)
     - Vertical divider at 24% (representing left/right split)
     - 3 horizontal dividers in left column (creating 4 tiles)
   - Export as PNG at standard and @2x resolutions

2. Run `iconutil -c icns` to convert iconset to .icns format

3. Clean up temporary iconset directory

**Result:** `sources/resources/AppIcon.icns` with all required sizes

**Regenerate:**
```bash
swift generate_icon.swift
./build.sh
```

## User Workflow

### First Run Setup

1. **Build Tessera**
   ```bash
   ./build.sh
   ```

2. **Launch Tessera**
   ```bash
   open build/tessera.app
   ```

3. **Position Window**
   - Drag Tessera window to desired location
   - Resize to preferred dimensions
   - Position is automatically saved to UserDefaults

### Daily Usage

1. **Launch Tessera**
   - Window appears in saved position
   - Displays floating semi-transparent window

2. **Add Terminals**
   - Click "+" button to add new terminal
   - Each terminal appears in left column
   - Maximum 6 terminals

3. **Work with Terminals**
   - Click any terminal header in left column to promote to main panel
   - Or drag terminal header to main panel for promotion
   - Use fullscreen mode for focused work
   - Adjust split ratio by dragging divider

4. **Customize Appearance**
   - Open Settings (Tessera → Settings... or ⌘,)
   - Adjust opacity, font, size, colors
   - Changes apply instantly

5. **Quit**
   - Tessera → Quit Tessera (⌘Q)
   - Settings and window position saved automatically

## Configuration Options

### Current Settings

**Configurable via UI:**
- Window opacity: 50%-100% (default 85%)
- Font: 6 monospace fonts (default Menlo)
- Font size: 8pt-24pt (default 12pt)
- Font color: Any color (default green)
- Split ratio: 15%-85% via drag (default 30%/70%)

**Hardcoded (Changeable in Code):**
- Maximum terminals: 6 (appdelegate.swift:110)
- Terminal shell: `/bin/zsh -l` (TerminalView.swift:111)
- Toolbar height: 44px (appdelegate.swift:319)
- Header height: 24px (TerminalView.swift:7)
- Drag threshold: 5px (appdelegate.swift:328)

### Potential Future Enhancements

- Keyboard shortcuts for terminal switching
- Per-terminal shell configuration
- Terminal session restoration on app restart
- Custom color schemes / full themes
- Split right panel horizontally
- Export/import settings
- Terminal tabs within panels

## Known Limitations

1. **Terminal Count**: Maximum 6 terminals (easily increased in code)

2. **No Session Persistence**: Terminal sessions are not saved between app launches

3. **Shell Hardcoded**: All terminals run `/bin/zsh -l` (easily changed in TerminalView.swift)

4. **No Keyboard Shortcuts**: Terminal switching is mouse/trackpad only

5. **Single Window**: Only one Tessera window per app instance

## Design Rationale

### Why Embedded Terminals?

**Original Prototype** used Alacritty terminal with macOS Accessibility API to position external windows. This was replaced with embedded SwiftTerm terminals for:

- **Better integration**: Terminals are true app components, not external processes
- **No permission requirements**: No Accessibility permissions needed
- **Single window**: Simpler window management
- **Unified appearance**: Consistent styling via single window opacity
- **Reliable layout**: No issues with external windows being moved manually
- **Self-contained**: No dependency on external terminal app

### Why SwiftTerm?

SwiftTerm provides:
- Native Swift implementation
- Full terminal emulation (VT100/xterm)
- PTY support for proper process handling
- Customizable fonts, colors, cursor
- Active development and maintenance
- MIT license

### Why Floating Window?

- **Always accessible**: Window floats above other apps for easy access
- **Non-intrusive**: Transparent design stays out of the way
- **Focus mode ready**: Can be moved off-screen when not needed
- **Multi-app workflow**: See terminal while working in other apps

## Testing Checklist

### Basic Functionality
- [ ] App launches without errors
- [ ] Window appears in correct position
- [ ] "+" button creates new terminal
- [ ] Multiple terminals tile correctly in left column
- [ ] Click terminal header promotes to main panel
- [ ] Drag terminal header to main panel works
- [ ] Fullscreen button expands/restores main panel
- [ ] Settings panel opens and saves changes
- [ ] About panel displays correctly
- [ ] Quit menu item terminates app

### Interactive Features
- [ ] Drag vertical divider adjusts split ratio
- [ ] Cursor changes appropriately on hover
- [ ] Visual feedback during terminal drag
- [ ] Green highlight on main panel during drag hover
- [ ] Blue highlight on dragged terminal
- [ ] Cancel drag by releasing outside main panel

### Settings
- [ ] Opacity change applies instantly
- [ ] Font change applies to all terminals
- [ ] Font size change applies to all terminals
- [ ] Color change applies to all terminals
- [ ] Settings persist after restart

### Edge Cases
- [ ] Launch with no terminals (window empty)
- [ ] Add 6 terminals (maximum)
- [ ] Try to add 7th terminal (should do nothing)
- [ ] Resize window → terminals reposition correctly
- [ ] Move window → position saved correctly
- [ ] Minimize and restore window
- [ ] Enter/exit macOS fullscreen
- [ ] Close Settings panel
- [ ] Close About panel

## Development Team

Tessera is developed by:
- **Glen Barnhardt** - Creator and lead developer
- **Claude Code** - AI-assisted development and architecture

Built with:
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza
- Swift and AppKit (Apple)
- Core Graphics for icon generation

## Documentation

- **README.md**: General overview and user guide
- **USER_GUIDE.md**: Detailed end-user documentation
- **TECHNICAL.md**: Deep technical documentation and architecture
- **SPECIFICATION.md**: This document - design specification
- **CLAUDE.md**: AI assistant guidance for code work

## Version History

### Version 1.0 (2025)

**Initial Release Features:**
- Embedded terminal emulation with SwiftTerm
- Split-screen layout with adjustable divider (15%-85%)
- Up to 6 terminals in left column
- Drag-and-drop terminal promotion with visual feedback
- Click-to-promote instant switching
- Fullscreen mode for focused work
- Settings panel: opacity, fonts, colors
- Violet line art mosaic icon
- Custom About panel
- Floating window that stays on top
- Persistent settings and window frame via UserDefaults

## Conclusion

Tessera provides an elegant, self-contained solution for working with multiple terminal sessions on macOS. By embedding terminal emulation within a single floating window and providing intuitive interactions (click, drag-and-drop, adjustable layout), it creates an efficient workspace for developers and power users. The focus on native AppKit integration, customization options, and minimal design makes it a lightweight yet powerful terminal management tool.
