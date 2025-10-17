# Tessera - Terminal Window Manager Specification

## Overview

**Tessera** is a macOS application that manages Alacritty terminal windows in a tiled layout with a left sidebar and main panel design. It provides an elegant interface for working with multiple terminal sessions simultaneously.

## Project Goals

1. **Simplify terminal window management** - Automatically arrange multiple Alacritty terminal windows in a predictable, organized layout
2. **Maximize screen real estate** - Use a 30/70 split between sidebar and main panel for optimal focus
3. **Enable quick context switching** - Allow users to quickly switch between terminal sessions with a single click
4. **Minimize UI chrome** - Keep the interface transparent and minimal to stay out of the way
5. **Persist layout preferences** - Remember window size and position across sessions

## Visual Design

```
┌─────────────────────────────────────────────────────────────┐
│ Tessera                                                  ⊙ ⊖ ⊗│ ← Title bar
├──────────┬──────────────────────────────────────────────────┤
│          │                                                  │
│  Term 1  │                                                  │
│          │                                                  │
├──────────┤                                                  │
│          │                                                  │
│  Term 2  │          Main Terminal Panel                    │
│          │          (Right - 70% width)                     │
├──────────┤                                                  │
│          │                                                  │
│  Term 3  │                                                  │
│          │                                                  │
├──────────┤                                                  │
│          │                                                  │
│  Term 4  │                                                  │
│          │                                                  │
├──────────┴──────────────────────────────────────────────────┤
│  [+]  [⤢ Fullscreen]                                        │ ← Bottom toolbar
└─────────────────────────────────────────────────────────────┘

Left sidebar: 30% width - displays up to 4 terminal windows
Right panel: 70% width - displays the main/focused terminal
```

## Core Features

### 1. Window Layout Management

**Left Sidebar (30% width)**
- Displays up to 4 terminal windows stacked vertically
- Each terminal is evenly sized within the sidebar
- Blue borders and subtle highlighting show panel boundaries
- Click any sidebar terminal to promote it to the main panel

**Right Panel (70% width)**
- Displays the primary/focused terminal window
- Largest terminal by default, or most recently promoted terminal
- Provides maximum space for active work

**Auto-positioning**
- Tessera uses macOS Accessibility API to position Alacritty windows
- The Tessera window acts as a transparent overlay that defines the layout boundary
- Alacritty windows are automatically positioned within the Tessera frame
- Layout updates automatically when:
  - New Alacritty windows are launched
  - Tessera window is resized or moved
  - Windows are promoted from left to right

### 2. User Controls

**Bottom Toolbar**
- **"+" Button**: Launches a new Alacritty window
  - Opens a new Alacritty instance via `open -n -a Alacritty`
  - Automatically adds it to the layout after 0.5s delay

- **"⤢ Fullscreen" Button**: Toggles the right panel to fullscreen
  - First click: Expands right panel terminal to fill entire screen
  - Second click: Restores normal split layout

**Click Interactions**
- Click any left sidebar panel to swap it with the right panel
- Visual feedback: Blue borders and highlight overlays on panels
- Console logging for debugging click detection

**Application Menu (Tessera → ...)**
- "About Tessera": Shows standard about panel
- "Quit Tessera" (⌘Q): Terminates the application

### 3. Window Management

**Terminal Selection Logic**
- On layout: Sort all Alacritty windows by area (width × height)
- Largest window → Right panel
- Next 4 windows → Left sidebar (top to bottom)
- Additional windows → Minimized (kept in dock)

**Panel Promotion**
- Click a left sidebar panel → Swap positions with right panel
- Preserves terminal state and content
- Immediate visual feedback

**Auto-discovery**
- Timer (every 0.3s) monitors for new Alacritty windows
- Automatically incorporates new windows into layout
- No manual refresh needed

### 4. Persistence

**Window Frame**
- Saves Tessera window position and size to UserDefaults
- Key: `LayoutControllerSavedFrame`
- Restores on next launch
- Auto-saves on window move

**Default Frame**
- Centered on main screen
- 72% of screen width
- 75% of screen height
- Offset by 120pt from screen edges

## Technical Architecture

### Technologies
- **Language**: Swift
- **Frameworks**: Cocoa, ApplicationServices
- **Build**: Swift compiler (swiftc) via shell script
- **Target**: macOS 13.0+

### Key Components

**AppDelegate (appdelegate.swift)**
- Main application controller
- Manages window lifecycle
- Implements layout algorithm
- Handles user interactions
- Monitors Alacritty windows via timer

**ContentView (Custom NSView)**
- Transparent overlay with bottom toolbar
- Draws panel dividers and highlights
- Handles mouse click detection for panel promotion
- Renders visual feedback (borders, fills)

**Accessibility API Integration**
- Uses AXUIElement to find Alacritty windows
- Reads/writes window position (kAXPositionAttribute)
- Reads/writes window size (kAXSizeAttribute)
- Sets minimized state (kAXMinimizedAttribute)
- Filters out minimized windows from layout

### Layout Algorithm

1. **Discover Alacritty Windows**
   - Query all running Alacritty app instances
   - Get AXUIElement for each window
   - Filter out minimized windows

2. **Sort by Size**
   - Calculate area (width × height) for each window
   - Sort descending (largest first)

3. **Assign to Panels**
   - First window → Right panel (70% width, full height)
   - Next 1-4 windows → Left sidebar (30% width, divided vertically)
   - Extra windows → Minimize

4. **Position Windows**
   - Calculate frames relative to Tessera window bounds
   - Apply coordinates via Accessibility API
   - Account for title bar height (28pt) and toolbar (44pt)

5. **Visual Feedback**
   - Update ContentView with panel frame coordinates
   - Draw borders and highlights
   - Enable click detection

### Coordinate System

**Screen Coordinates (Accessibility API)**
- Origin: Bottom-left of primary screen
- Used for positioning Alacritty windows

**Window Coordinates (ContentView)**
- Origin: Bottom-left of Tessera window
- Used for click detection and drawing

**Conversion**
- `window.convertPoint(fromScreen:)` - Screen → Window coords
- Required for matching panel frames to click locations

## User Workflow

### First Run Setup

1. **Build and Launch**
   ```bash
   ./build.sh
   open build/tessera.app
   ```

2. **Grant Accessibility Permissions**
   - macOS prompts for Accessibility permission
   - Go to: System Settings → Privacy & Security → Accessibility
   - Enable Tessera
   - Without this, Tessera cannot control Alacritty windows

3. **Position Tessera Window**
   - Drag Tessera window to desired location
   - Resize to preferred dimensions
   - Position is automatically saved

### Daily Usage

1. **Launch Tessera**
   - Tessera window appears in saved position
   - Displays semi-transparent overlay

2. **Add Terminals**
   - Click "+" button to launch new Alacritty windows
   - Each new terminal automatically appears in the layout
   - First terminal → Right panel
   - Additional terminals → Left sidebar

3. **Switch Context**
   - Click any left sidebar panel to bring it to focus
   - Clicked panel swaps with current right panel
   - Instant switch, no window management needed

4. **Focus Mode**
   - Click "⤢ Fullscreen" to maximize right panel
   - Terminal fills entire screen for distraction-free work
   - Click again to restore split view

5. **Quit**
   - Use Tessera → Quit Tessera (⌘Q)
   - Alacritty windows remain open but revert to normal behavior

## Configuration Options

### Current Settings (Hardcoded)

- **Left panel count**: 4 windows maximum
- **Split ratio**: 30% left / 70% right
- **Window level**: Floating (above terminals)
- **Transparency**: 15% for main window, 95% for toolbar
- **Monitor interval**: 0.3 seconds
- **Terminal app**: Alacritty only

### Future Enhancements

Potential configuration options to add:
- Adjustable split ratio (slider)
- Variable left panel count (1-6)
- Support for other terminal apps (iTerm2, Terminal.app)
- Configurable hotkeys
- Per-project layouts
- Theme/color customization
- Monitor interval adjustment

## Visual Design Details

### Colors

**Panel Dividers**
- Color: System blue at 60% opacity
- Width: 2pt
- Style: Solid line

**Panel Highlights**
- Fill: System blue at 8% opacity
- Border: System blue at 40% opacity
- Border width: 1.5pt

**Window Background**
- Main area: Window background color at 15% opacity
- Toolbar: Control background color at 95% opacity

### Layout Spacing

- **Title bar height**: 28pt (macOS standard)
- **Bottom toolbar height**: 44pt
- **Button spacing**: 10pt from left edge, 40pt between buttons
- **Button size**: 30×30pt ("+"), 100×30pt ("Fullscreen")
- **Panel gaps**: None (panels touch at dividers)

## Error Handling & Edge Cases

### No Alacritty Windows
- Tessera window remains visible
- Toolbar functional
- Click "+" to launch first terminal

### Single Alacritty Window
- Appears in right panel only
- Left sidebar empty
- Still clickable to add more terminals

### More Than 5 Windows
- First window → Right panel
- Next 4 → Left sidebar
- Extras → Minimized to dock
- Can be un-minimized manually and will be incorporated

### Tessera Window Moved/Resized
- Triggers immediate relayout
- All terminals reposition to fit new bounds
- Maintains split ratio

### Alacritty Not Installed
- "+" button fails silently
- No error message (current implementation)
- Future: Add error dialog

### Accessibility Denied
- Terminals won't reposition
- App still runs but is non-functional
- Future: Add permission check and prompt

## Build and Deployment

### Build Requirements
- macOS 13.0 or later
- Xcode Command Line Tools
- Swift compiler

### Build Process
```bash
./build.sh
```

**Build script actions:**
1. Creates build directory structure
2. Compiles Swift sources (main.swift, appdelegate.swift)
3. Links Cocoa and ApplicationServices frameworks
4. Copies Info.plist to bundle
5. Produces build/tessera.app

### Distribution
- Current: Local build only
- No code signing (Gatekeeper warnings expected)
- Right-click → Open to bypass security warning
- Future: Code sign for distribution

## Known Limitations

1. **Terminal App**: Only supports Alacritty
   - Hardcoded check for `localizedName == "Alacritty"`
   - Other terminals ignored

2. **Window Embedding**: Alacritty windows are NOT truly embedded
   - Windows are positioned via Accessibility API
   - They remain separate windows, just positioned by Tessera
   - Can be manually moved (will reposition on next layout cycle)

3. **Multi-Monitor**: Uses main screen only
   - Doesn't handle multiple displays intelligently
   - All windows positioned on primary screen

4. **No Persistence**: Terminal sessions not preserved
   - Quit Tessera → terminals revert to normal windows
   - No session restoration on relaunch

5. **Fixed Layout**: 30/70 split is hardcoded
   - No UI to adjust split ratio
   - Must edit source code to change

## Future Development Roadmap

### Phase 1: Core Improvements
- [ ] Add permission check and user-friendly error messages
- [ ] Support for multiple terminal applications
- [ ] Configurable split ratio via UI slider
- [ ] Keyboard shortcuts for panel switching
- [ ] Better visual feedback for active panel

### Phase 2: Advanced Features
- [ ] Session persistence (restore terminals on relaunch)
- [ ] Named layouts (save/load different arrangements)
- [ ] Multi-monitor support
- [ ] Drag-and-drop panel reordering
- [ ] Terminal tabs within panels

### Phase 3: Polish
- [ ] Code signing for distribution
- [ ] Preferences window
- [ ] Custom themes/appearance
- [ ] Animations for panel transitions
- [ ] Documentation and help system

## Testing Checklist

### Basic Functionality
- [ ] App launches without errors
- [ ] Tessera window appears in correct position
- [ ] "+" button launches Alacritty
- [ ] New Alacritty appears in left sidebar
- [ ] Multiple Alacritty windows tile correctly
- [ ] Click left panel → swaps with right panel
- [ ] Fullscreen button expands/restores right panel
- [ ] Quit menu item terminates app

### Edge Cases
- [ ] Launch with no Alacritty windows
- [ ] Launch with 1 Alacritty window
- [ ] Launch with 10+ Alacritty windows
- [ ] Resize Tessera window → terminals reposition
- [ ] Move Tessera window → terminals follow
- [ ] Manually resize Alacritty → corrected on next cycle
- [ ] Minimize Alacritty manually → removed from layout
- [ ] Close Alacritty → removed from layout

### Permissions
- [ ] Accessibility permission requested on first run
- [ ] App non-functional without permissions
- [ ] App functions correctly after granting permissions

## Code Maintenance

### Code Style
- Swift standard naming conventions
- Mark comments for organization (// MARK: -)
- Descriptive variable names
- Console logging for debugging (print statements)

### Key Files
- `sources/tessera/main.swift` - Entry point
- `sources/tessera/appdelegate.swift` - Main app logic (400+ lines)
- `info.plist` - Bundle configuration
- `build.sh` - Build automation
- `CLAUDE.md` - AI assistant guidance
- `SPECIFICATION.md` - This document

### Modification Guidelines
- Test locally before committing
- Update CLAUDE.md if architecture changes
- Keep single-file philosophy (appdelegate.swift)
- Maintain compatibility with macOS 13.0+
- Document any new dependencies

## Conclusion

Tessera provides a lightweight, elegant solution for managing multiple terminal windows on macOS. By leveraging the Accessibility API and a transparent overlay design, it stays out of the user's way while providing powerful window management capabilities. The focused feature set and minimal UI make it ideal for developers and power users who work with multiple terminal sessions daily.
