# Tessera

> _Pronounced: TESS-er-ah_

A beautiful and minimalist macOS terminal tiling application with embedded terminal emulation. Tessera provides an elegant split-screen layout with multiple terminal panels in a single floating window.

## What is Tessera?

Tessera is a native macOS application that creates a tiled terminal workspace using embedded terminal emulators. It features a unique layout with a left column of smaller terminal panels (up to 6) and a main panel on the right. The name "Tessera" comes from the small tiles used in mosaics, reflecting the app's tiled terminal layout.

## Features

### Terminal Layout
- **Split-screen design**: Left column (30% width by default) with multiple stacked terminals, and a main panel (70% width) on the right
- **Adjustable split**: Drag the divider between left and right panels to adjust the split ratio (15%-85%)
- **Up to 6 terminals**: Add up to 6 terminals in the left column using the "+" button
- **Floating window**: The application window floats above other windows for easy access

### Interactive Controls
- **Click-to-promote**: Click any left terminal's header to instantly display it in the main panel
- **Drag-and-drop**: Drag a terminal's header from the left column to the main panel to promote it
- **Visual feedback**: The main panel highlights green when hovering during a drag operation
- **Fullscreen mode**: Expand the current main panel terminal to fill the entire window (hiding left panels)

### Customization
- **Font selection**: Choose from Menlo, Monaco, SF Mono, Courier New, Courier, or Andale Mono
- **Font size**: Adjustable from 8pt to 24pt
- **Color customization**: Configure foreground (text) and cursor colors
- **Window opacity**: Adjust transparency from 50% to 100%
- **Persistent settings**: All preferences are saved automatically

### Design
- **Minimal violet line art icon**: A laser-cut mosaic design representing the tiled layout
- **Dark theme**: Semi-transparent black background with customizable opacity
- **Terminal headers**: Each terminal has a draggable header with a drag handle icon (⋮⋮) and terminal number
- **Bottom toolbar**: Access to add terminals and toggle fullscreen mode

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (for building from source)

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/tessera.git
cd tessera
```

2. Run the build script:
```bash
./build.sh
```

3. Launch the application:
```bash
open build/tessera.app
```

The build script will:
- Compile the Swift source using Swift Package Manager
- Create the app bundle structure
- Copy the icon and Info.plist
- Generate a ready-to-run `.app` bundle in the `build/` directory

## Usage

### Getting Started

1. Launch Tessera - a floating window will appear on your screen
2. Click the "+" button in the bottom toolbar to add your first terminal
3. Continue adding terminals (up to 6) as needed
4. Click any terminal's header in the left column to promote it to the main panel
5. Alternatively, drag a terminal's header to the right panel to promote it

### Controls

**Adding Terminals**:
- Click the "+" button in the bottom toolbar
- Each new terminal appears in the left column

**Promoting Terminals**:
- **Click**: Click a left terminal's header to instantly show it in the main panel
- **Drag**: Drag a terminal's header and drop it on the right panel
- The promoted terminal remains in the left column but is displayed on the right

**Fullscreen Mode**:
- Click the "⤢ Fullscreen" button to expand the current main panel terminal
- Click again to restore the normal layout
- In fullscreen, the terminal header is hidden and the background becomes solid black

**Adjusting Split Ratio**:
- Hover over the vertical divider between left and right panels (cursor changes to ↔)
- Click and drag left or right to adjust the split ratio

**Window Management**:
- Resize the window as needed - terminals automatically adjust to fill the space
- Move the window - position is saved automatically

### Settings

Access settings from the **Tessera** menu → **Settings...**:

- **Window Opacity**: Adjust transparency (default 85%)
- **Font**: Select your preferred monospace font
- **Font Size**: Adjust size from 8pt to 24pt (default 12pt)
- **Font Color**: Choose text color (default green)

All settings apply instantly to all terminals and are persisted between sessions.

### Menu

**Tessera** menu:
- **About Tessera**: View app information, version, and icon
- **Settings...**: Open the settings panel (⌘,)
- **Quit Tessera**: Exit the application (⌘Q)

## Architecture

### Core Components

**SwiftTerm Integration**: Tessera uses the [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) library for terminal emulation. Each terminal panel runs a local `/bin/zsh` shell process with full terminal capabilities.

**Terminal Panels** (`TerminalView.swift`):
- Embedded `LocalProcessTerminalView` from SwiftTerm
- 24px draggable header with terminal number and drag handle icon
- Transparent background with configurable colors
- Mouse event forwarding for drag-and-drop functionality

**Application Controller** (`appdelegate.swift`):
- Manages up to 6 terminal instances in the left column
- Tracks which terminal is displayed in the main panel
- Handles layout calculations and window management
- Persists window frame and settings

**Custom Content View** (`ContentView.swift`):
- Detects clicks and drags on terminal headers
- Manages divider dragging for split ratio adjustment
- Renders visual feedback during drag operations
- Draws dividers between terminal panels

**Settings Management** (`Settings.swift`):
- Centralized settings storage using `UserDefaults`
- Notification-based updates to all terminals
- Persistent configuration across app launches

### Layout Algorithm

The layout algorithm in `relayout()` (appdelegate.swift:233-310):

1. Calculates available layout area (excluding bottom toolbar)
2. Splits width based on `splitRatio` (default 30% left, 70% right)
3. Positions the main panel terminal on the right (if one is selected)
4. Divides left column height evenly among all terminals
5. Positions each left terminal in its calculated frame
6. Stores frame information for click/drag detection

## Project Structure

```
tessera/
├── sources/
│   ├── tessera/
│   │   ├── main.swift              # App entry point
│   │   ├── appdelegate.swift       # Main controller & layout logic
│   │   ├── TerminalView.swift      # Individual terminal panel
│   │   ├── Settings.swift          # Settings management
│   │   ├── SettingsWindow.swift    # Settings UI
│   │   └── AboutWindow.swift       # About panel
│   └── resources/
│       └── AppIcon.icns            # App icon
├── Package.swift                    # Swift Package Manager config
├── info.plist                       # App bundle configuration
├── build.sh                         # Build script
├── generate_icon.swift              # Icon generation script
└── README.md                        # This file
```

## Development

### Building

```bash
# Build the app
./build.sh

# Build with Swift Package Manager directly
swift build -c release

# Run the built app
open build/tessera.app
```

### Regenerating the Icon

The app icon is programmatically generated using Core Graphics:

```bash
swift generate_icon.swift
```

This generates `sources/resources/AppIcon.icns` with all required icon sizes (16x16 through 1024x1024) featuring the violet line art mosaic design.

### Modifying Layout Behavior

Key parameters in `appdelegate.swift`:

- **Default split ratio**: Line 10 - `var splitRatio: CGFloat = 0.30`
- **Maximum terminals**: Line 110 - `if leftTerminals.count >= 6`
- **Window opacity**: `Settings.swift:25` - Default 0.85 (85%)
- **Terminal header height**: `TerminalView.swift:7` - `let headerHeight: CGFloat = 24`

### Dependencies

- **SwiftTerm** (v1.0.0+): Terminal emulation library by Miguel de Icaza
  - Provides `LocalProcessTerminalView` for embedded terminal functionality
  - Handles PTY communication, text rendering, and ANSI escape sequences

## Technical Details

### Terminal Emulation

Each terminal runs `/bin/zsh -l` (login shell) with:
- `TERM=xterm-256color` for 256-color support
- `COLORTERM=truecolor` for 24-bit color support
- Full environment variable inheritance
- PTY (pseudo-terminal) for proper terminal interaction

### Mouse Event Handling

The event handling chain for drag-and-drop (TerminalView.swift:126-161):

1. `mouseDown` in terminal checks if click is in header area
2. If in header, event is forwarded to `ContentView` via `nextResponder`
3. `ContentView` records potential drag start
4. On `mouseDragged`, checks if drag threshold (5px) exceeded
5. Shows visual feedback (cursor change, highlighting) during drag
6. On `mouseUp`, checks if dropped on right panel and promotes terminal

### Window Management

- Window level: `.floating` - appears above other windows
- Window frame: Persisted to `UserDefaults` on move/resize
- Content area: Automatically adjusted for window size changes
- Toolbar height: 44px (bottom) - excluded from terminal layout area

## License

Copyright (c) 2025 Glen Barnhardt

## Credits

**Development Team:**
- **Glen Barnhardt** - Creator and lead developer
- **Claude Code** - AI-assisted development and architecture

**Built with:**
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza
- Swift and AppKit (Apple)
- Core Graphics for icon generation

## Contributing

This is a personal project, but suggestions and bug reports are welcome. Please open an issue on GitHub.

## Changelog

### Version 1.0 (2025)
- Initial release
- Embedded terminal emulation with SwiftTerm
- Split-screen layout with adjustable divider
- Drag-and-drop terminal promotion
- Click-to-promote functionality
- Fullscreen mode for main panel
- Customizable fonts, colors, and opacity
- Violet line art icon
- Settings persistence
- About panel
