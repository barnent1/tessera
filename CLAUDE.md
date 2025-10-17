# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**tessera** is a minimal macOS menu bar application that manages Alacritty terminal window layouts using a tiling system. It creates a "working pane" layout where one large terminal occupies the right side and multiple smaller terminals tile vertically on the left.

## Building and Running

```bash
# Build the application
./build.sh

# Run the built app
open build/tessera.app
```

The build script (`build.sh`) compiles the Swift source using `swiftc` with the Cocoa and ApplicationServices frameworks, then packages it into a .app bundle with the Info.plist.

### First Run Setup
On first run, the app requires Accessibility permissions: System Settings → Privacy & Security → Accessibility. Without this, the app cannot resize/move terminal windows.

## Architecture

### Single-File Design
The entire application logic is in `sources/tessera/appdelegate.swift`. This is intentional - the app is deliberately minimal.

### Core Components

**Menu Bar Integration**: The app runs as a menu bar utility (NSStatusItem) with no dock presence. The icon is a split-screen symbol.

**Controller Window**: A draggable/resizable window whose frame defines the layout boundary. Alacritty windows are tiled within this frame's `contentLayoutRect`. The window's position and size are persisted to UserDefaults.

**Layout Algorithm** (`applyLayout`):
1. Finds all non-minimized Alacritty windows via Accessibility API
2. Sorts by area (largest first)
3. The largest window becomes the "right pane" (70% width)
4. Next N windows (configurable 1-6, default 4) tile vertically in the "left column" (30% width)
5. Extra windows are minimized

### Accessibility API Usage

The app heavily uses macOS Accessibility APIs (AXUIElement) to:
- Enumerate Alacritty windows across all instances
- Get/set window position and size (kAXPositionAttribute, kAXSizeAttribute)
- Detect focused window (kAXFocusedUIElementAttribute)
- Minimize windows (kAXMinimizedAttribute)

Key helpers:
- `alacrittyWindows()` - filters for non-minimized Alacritty windows
- `focusedAlacrittyWindow()` - finds the currently focused Alacritty window
- `frame(of:)` / `setFrame(_:to:)` - read/write window geometry

### User Interactions

**Menu Actions**:
- "New Alacritty" - launches a new Alacritty instance and re-layouts after 0.4s delay
- "Left tiles: N" - changes how many terminals show in the left column
- "Promote Focused Left → Right" - swaps the focused left terminal with the right pane
- "Reapply Layout" - manually triggers layout (also happens on window resize/move)
- "Save Current Size & Position" - persists the controller window frame

**Window Delegate Hooks**: Layout is automatically reapplied on:
- `windowDidEndLiveResize` - after user resizes controller window
- `windowDidExitFullScreen` - after exiting fullscreen
- `windowDidDeminiaturize` - after un-minimizing

## Development Notes

### Modifying Layout Behavior
- Left/right split ratio: see `leftW` calculation in `applyLayout` (currently 30/70)
- Default left tile count: change `leftCount` initial value (line 9)
- Default controller window size: modify `defaultRect` calculation (lines 26-30)
- Sorting logic for "right pane" selection: modify sort in `applyLayout` (currently largest by area)

### Hardcoded Dependencies
- Requires Alacritty terminal (checks `localizedName == "Alacritty"`)
- Shells out to `/bin/zsh` for launching new instances
- Minimum macOS version: 13.0 (see Info.plist)

### Testing Layout Changes
After modifying layout logic, use "Reapply Layout" menu item or resize the controller window to trigger reflow without restarting the app.
