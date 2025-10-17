# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Tessera** (pronounced TESS-er-ah) is a native macOS application that provides a tiled terminal workspace using embedded terminal emulation. It features a split-screen layout with up to 6 terminals in a left column and a main panel on the right.

The name "Tessera" comes from the small tiles used in mosaics, reflecting the app's tiled terminal layout.

## Current Architecture

**IMPORTANT**: This application uses **embedded SwiftTerm terminals**, NOT external Alacritty windows via Accessibility API. The terminals run inside the app window.

### Core Design

- **SwiftTerm Integration**: Uses `LocalProcessTerminalView` from SwiftTerm library for embedded terminal emulation
- **Native AppKit**: Pure Swift/AppKit, no cross-platform frameworks
- **Floating Window**: Always-on-top window that floats above other applications
- **Interactive Layout**: Click or drag terminals from left column to promote them to main panel
- **Customizable**: Settings for fonts, colors, and opacity
- **Self-contained**: No external terminal app dependencies

## Building and Running

```bash
# Build the application
./build.sh

# Run the built app
open build/tessera.app
```

The build script uses Swift Package Manager to compile the source, then packages it into a .app bundle with Info.plist and icon.

## Architecture Components

### Source Files

```
sources/tessera/
├── main.swift              # App entry point (6 lines)
├── appdelegate.swift       # Main controller & layout engine (~650 lines)
├── TerminalView.swift      # Individual terminal panel (~235 lines)
├── Settings.swift          # Settings persistence (~108 lines)
├── SettingsWindow.swift    # Settings UI (~146 lines)
└── AboutWindow.swift       # About panel (~123 lines)
```

### AppDelegate (appdelegate.swift)

Main application controller managing:
- Floating NSWindow with custom ContentView
- Array of up to 6 TerminalView instances (left column)
- Single rightTerminal reference (currently displayed in main panel)
- Split ratio (default 30% left / 70% right, adjustable 15-85%)
- Settings observation and window opacity
- Fullscreen mode toggle

**Key Methods**:
- `addNewTerminal()` - Creates new TerminalView, adds to leftTerminals, triggers relayout
- `promoteLeftTerminal(at:)` - Shows selected left terminal in main panel
- `toggleFullscreen()` - Expands/contracts main panel terminal
- `relayout()` - Core layout algorithm (lines 233-310)

**Important State**:
- `leftTerminals: [TerminalView]` - Up to 6 terminals (line 7)
- `rightTerminal: TerminalView?` - Currently displayed main panel (line 8)
- `splitRatio: CGFloat` - Left/right width split, default 0.30 (line 10)
- `isRightFullscreen: Bool` - Fullscreen state (line 9)

### ContentView (appdelegate.swift, lines 313-652)

Custom NSView handling the workspace area:
- **Bottom toolbar** (44px): "+" button and "⤢ Fullscreen" button
- **Panel drawing**: Vertical divider between left/right, horizontal dividers between left terminals
- **Drag-and-drop**: Terminal headers can be dragged to main panel
- **Click-to-promote**: Click terminal header to instantly promote to main panel
- **Divider dragging**: Adjust split ratio by dragging vertical divider
- **Visual feedback**: Green highlight on main panel during drag, blue highlight on dragged terminal

**Mouse Event Flow**:
1. `mouseDown` - Detects clicks on divider or terminal headers
2. `mouseDragged` - Handles divider/terminal dragging with threshold (5px)
3. `mouseUp` - Completes drag (promotes terminal) or treats as click
4. `mouseMoved` - Updates cursor based on hover location

### TerminalView (TerminalView.swift)

Individual terminal panel with:
- **SwiftTerm terminal**: `LocalProcessTerminalView` running `/bin/zsh -l`
- **24px header**: Draggable with "⋮⋮" icon and terminal number (#1-#6)
- **Transparent background**: Uses window background, configurable opacity
- **Event forwarding**: Header clicks forwarded to ContentView for drag detection
- **Settings integration**: Observes Settings.didChangeNotification for live updates

**Initialization**: Creates UI → applies settings → starts shell → observes settings

**Shell Configuration**:
- Executable: `/bin/zsh` with `-l` (login shell)
- Environment: `TERM=xterm-256color`, `COLORTERM=truecolor`
- Full terminal capabilities: 256 colors, unicode, ANSI escape sequences

### Settings (Settings.swift)

Singleton settings manager with UserDefaults persistence:
- `windowOpacity: Double` (0.5-1.0, default 0.85)
- `fontName: String` (default "Menlo")
- `fontSize: CGFloat` (default 12.0)
- `foregroundColor: NSColor` (default green)
- `backgroundColor: NSColor` (default black)
- `cursorColor: NSColor` (default green)

**Pattern**: Computed properties with get/set backed by UserDefaults. Setter posts `Settings.didChangeNotification` to notify observers.

### SettingsWindow (SettingsWindow.swift)

Floating settings panel (400×240) with controls:
- Opacity slider (50%-100%)
- Font popup (Menlo, Monaco, SF Mono, Courier New, Courier, Andale Mono)
- Font size slider with tick marks (8pt-24pt)
- Font color well

All changes apply instantly by modifying `Settings.shared`.

### AboutWindow (AboutWindow.swift)

Custom About panel (480×420, floating) showing:
- App icon (128×128, loads AppIcon.icns)
- App name ("Tessera" in 26pt bold)
- Version (from CFBundleShortVersionString)
- Author ("by Glen Barnhardt")
- Description (wrapping text)

## Layout Algorithm (relayout)

Located in `appdelegate.swift:233-310`.

**Input**:
- `leftTerminals` array
- `rightTerminal` reference
- `splitRatio` (0.15-0.85)
- Window bounds

**Process**:
1. Calculate layout area (excluding 44px bottom toolbar)
2. Split width: `leftW = width × splitRatio`, `rightW = width - leftW`
3. Position right terminal: `(x: leftW, y: toolbarTop, width: rightW, height: fullHeight)`
4. Position left terminals: Divide left column height evenly among all terminals
5. Store leftPanelFrames for click detection

**Triggers**:
- Adding a terminal
- Promoting a terminal
- Window resize/move
- Exiting fullscreen
- Divider drag completion

## Development Workflow

### Quick Iteration
```bash
# Edit code
vim sources/tessera/appdelegate.swift

# Rebuild and launch
./build.sh && open build/tessera.app
```

### Debugging
Use print statements (app logs to Console.app):
```swift
print("Tessera: relayout started with \(leftTerminals.count) left terminals")
```

### Testing Layout
1. Build and launch
2. Add 6 terminals with "+" button
3. Test: click headers, drag headers, resize window, adjust divider, fullscreen

### Regenerating Icon
```bash
swift generate_icon.swift
./build.sh
```

Icon is violet line art mosaic (laser-cut style) with dark background.

## Key Implementation Details

### Terminal Embedding

Terminals are embedded using SwiftTerm's `LocalProcessTerminalView`:

```swift
let terminalView = LocalProcessTerminalView(frame: terminalFrame)
terminalView.startProcess(
    executable: "/bin/zsh",
    args: ["-l"],
    environment: getEnvironment()
)
```

Terminals are **real subviews** of the window, not external processes positioned via Accessibility API.

### Transparent Backgrounds

TerminalView uses transparent layer backgrounds to let the window background show through:

```swift
terminalView.layer?.backgroundColor = NSColor.clear.cgColor
terminalView.nativeBackgroundColor = NSColor.clear
```

Window opacity is applied at the window level (appdelegate.swift:70-73).

### Header Event Forwarding

Terminal headers need to forward mouse events to ContentView for drag detection:

```swift
// In TerminalView.mouseDown
if headerView.frame.contains(location) {
    isForwardingMouseEvents = true
    nextResponder?.mouseDown(with: event)
    return
}
```

DraggableHeaderView (nested class) forwards all mouse events to `superview?.superview` (ContentView).

## Modifying Layout Behavior

### Changing Split Ratio Default
Line 10 in appdelegate.swift:
```swift
var splitRatio: CGFloat = 0.35  // Change from 0.30 to 35%
```

### Changing Maximum Terminal Count
Line 110 in appdelegate.swift:
```swift
if leftTerminals.count >= 8 {  // Change from 6 to 8
```

### Changing Terminal Shell
Line 111 in TerminalView.swift:
```swift
terminalView.startProcess(executable: "/bin/bash", args: ["--login"], environment: getEnvironment())
```

## Dependencies

### SwiftTerm (1.0.0+)
- Repository: https://github.com/migueldeicaza/SwiftTerm
- Provides: `LocalProcessTerminalView` with PTY support
- Features: Font configuration, color customization, ANSI escape sequences, unicode support

Specified in Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
]
```

## Development Team

Tessera is developed by:
- **Glen Barnhardt** - Creator and lead developer
- **Claude Code** - AI-assisted development and architecture

## Documentation

- **README.md**: General overview and user guide
- **USER_GUIDE.md**: Detailed end-user documentation
- **TECHNICAL.md**: Deep technical documentation and architecture
- **SPECIFICATION.md**: Original design specification
- **CLAUDE.md**: This file - AI assistant guidance
