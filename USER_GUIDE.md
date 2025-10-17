# Tessera User Guide

Welcome to Tessera! This guide will help you get started and make the most of your tiled terminal workspace.

## Table of Contents

1. [First Time Setup](#first-time-setup)
2. [Basic Workflow](#basic-workflow)
3. [Adding Terminals](#adding-terminals)
4. [Switching Between Terminals](#switching-between-terminals)
5. [Adjusting Your Layout](#adjusting-your-layout)
6. [Fullscreen Mode](#fullscreen-mode)
7. [Customizing Appearance](#customizing-appearance)
8. [Tips and Tricks](#tips-and-tricks)
9. [Keyboard Shortcuts](#keyboard-shortcuts)
10. [Troubleshooting](#troubleshooting)

## First Time Setup

### Building Tessera

1. Open Terminal and navigate to the tessera directory:
   ```bash
   cd /path/to/tessera
   ```

2. Run the build script:
   ```bash
   ./build.sh
   ```

3. Launch Tessera:
   ```bash
   open build/tessera.app
   ```

### First Launch

When you first launch Tessera, you'll see a floating window with a bottom toolbar. The window will be empty - this is normal! You need to add your first terminal.

## Basic Workflow

Tessera is designed for a simple workflow:

1. **Add terminals** to the left column (up to 6)
2. **Click or drag** any left terminal to display it in the main panel on the right
3. **Work** in the large main panel while keeping other terminals visible in the left column
4. **Switch** between terminals by clicking or dragging

Think of the left column as your "workspace tabs" and the right panel as your "active workspace."

## Adding Terminals

To add a new terminal:

1. Click the **"+"** button in the bottom toolbar
2. A new terminal appears in the left column
3. The terminal is numbered (#1, #2, etc.) for easy identification

You can add up to 6 terminals. If you try to add more, nothing will happen (you've reached the maximum).

## Switching Between Terminals

There are two ways to switch which terminal is displayed in the main panel:

### Method 1: Click (Fast)

1. Simply click on the header (top bar) of any terminal in the left column
2. That terminal instantly appears in the main panel
3. The left column shows "→ Shown in main panel" where that terminal is located

### Method 2: Drag and Drop (Visual)

1. Click and hold on the header of any terminal in the left column
2. Drag your cursor toward the right panel
3. The right panel highlights:
   - **Green**: Valid drop zone (release to promote this terminal)
   - **Gray**: Neutral indicator showing drag in progress
4. Release the mouse button over the right panel
5. The terminal appears in the main panel

**Tip**: If you change your mind while dragging, just release outside the right panel to cancel.

## Adjusting Your Layout

### Resizing the Window

- **Drag corners or edges** to resize the entire Tessera window
- All terminals automatically adjust to fill the new space
- Your window size is remembered when you close and reopen Tessera

### Adjusting Left/Right Split

The default split is 30% left column / 70% right panel. To adjust:

1. Move your cursor to the **vertical divider** between left and right panels
2. Your cursor changes to ↔ (resize arrows)
3. Click and drag left or right
4. The split adjusts anywhere from 15% to 85%

**Use cases**:
- More left width: When you want to see more text in left terminals
- More right width: When you need maximum space in the main panel

### Moving the Window

- Drag the window title bar to reposition
- Window position is saved automatically

## Fullscreen Mode

Fullscreen mode hides the left column and expands the current main panel terminal to fill the entire window.

To toggle fullscreen:

1. Click the **"⤢ Fullscreen"** button in the bottom toolbar
2. The main panel expands, left terminals hide
3. Terminal header disappears
4. Background becomes solid black for maximum focus
5. Click **"⤢ Fullscreen"** again to restore normal layout

**Great for**: Focused coding sessions, reading logs, or working with a single task that needs your full attention.

## Customizing Appearance

### Opening Settings

1. Click **Tessera** in the menu bar
2. Select **Settings...** (or press ⌘,)
3. The Settings window appears (it floats on top)

### Available Settings

**Window Opacity**
- Drag the slider from 50% to 100%
- Lower values = more transparent
- Higher values = more opaque
- Changes apply instantly
- Default: 85%

**Font**
- Choose from 6 monospace fonts:
  - Menlo (default, macOS system monospace)
  - Monaco (classic Mac monospace)
  - SF Mono (Apple's modern monospace)
  - Courier New
  - Courier
  - Andale Mono
- Changes apply to all terminals immediately

**Font Size**
- Drag the slider from 8pt to 24pt
- Default: 12pt
- Good ranges:
  - 10-12pt: Standard comfortable reading
  - 14-16pt: Larger for presentations or visibility
  - 8-10pt: Compact for fitting more text

**Font Color**
- Click the color well to open the color picker
- Choose any color for your text
- Default: Green (classic terminal style)

**Close Button**
- Click **Close** or press Enter to close settings
- All settings are saved automatically

## Tips and Tricks

### Organizing Your Workspace

**Strategy 1: Project-based**
- Terminal 1: Main project directory
- Terminal 2: Git commands
- Terminal 3: Test runner
- Terminal 4: Server logs
- Terminal 5: Database queries
- Terminal 6: Documentation/notes

**Strategy 2: Environment-based**
- Terminal 1: Production monitoring
- Terminal 2: Staging environment
- Terminal 3: Development server
- Terminal 4: Local tests

**Strategy 3: Task-based**
- Terminal 1: Code editing (vim/nano)
- Terminal 2: Build/compile
- Terminal 3: File navigation
- Terminal 4: Package management

### Working Efficiently

1. **Keep frequently-used terminals at the top** of the left column for easier access

2. **Use the terminal number** (#1, #2, etc.) to mentally map your workspace

3. **Adjust opacity** lower when you want to see through to other apps behind Tessera

4. **Use fullscreen** when you need to focus on a single terminal without distractions

5. **Resize the split** based on your current task:
   - Wide right panel for coding
   - Balanced split for monitoring multiple terminals

### Quick Navigation

Since Tessera's window floats above others:
- Press ⌘-Tab to bring Tessera to focus from any other app
- Tessera appears immediately since it's already visible

## Keyboard Shortcuts

**Application**
- ⌘Q: Quit Tessera
- ⌘,: Open Settings

**Within Each Terminal**
- All standard terminal keyboard shortcuts work (⌃C, ⌃D, etc.)
- Tab completion, command history (↑/↓), etc. all function normally

**Note**: There are no keyboard shortcuts for switching between terminals - use click or drag instead.

## Troubleshooting

### Terminal won't respond to keyboard input

**Solution**: Click inside the terminal area (not the header) to give it keyboard focus.

### Can't drag terminals

**Problem**: You might be clicking in the terminal content area instead of the header.

**Solution**: Click on the top 24 pixels of the terminal where you see "⋮⋮" and the terminal number.

### Terminals look empty or frozen

**Solution**:
1. Try typing in the terminal - it might just be at the prompt
2. Press Enter to see if it responds
3. If still frozen, the shell process may have stopped - you'll need to restart Tessera

### Window is too transparent

**Solution**:
1. Open Settings (⌘,)
2. Increase Window Opacity slider to 100%

### Font is too small/large

**Solution**:
1. Open Settings (⌘,)
2. Adjust Font Size slider to your preference (8-24pt)

### Can't add more terminals

**Reason**: You've reached the maximum of 6 terminals.

**Solution**: Tessera supports up to 6 terminals in the left column. If you need more, consider organizing your work differently or using tmux/screen within a terminal.

### Text color is hard to read

**Solution**:
1. Open Settings (⌘,)
2. Click the Font Color well
3. Choose a color with better contrast against black

### Window disappeared

**Solution**:
- Check if Tessera is still running (look in the menu bar)
- The window might be minimized - click the Tessera menu and select About or Settings to bring focus back
- Quit and relaunch Tessera

### Build fails with "Command Line Tools not found"

**Solution**:
```bash
xcode-select --install
```
Follow the prompts to install Xcode Command Line Tools, then try building again.

## Advanced Usage

### Shell Initialization

Each terminal runs `/bin/zsh -l` (login shell), which means:
- Your `~/.zshrc` and `~/.zprofile` are loaded
- All your aliases, functions, and customizations work
- Environment variables are set as normal

### Terminal Features

Tessera terminals support:
- 256 colors (`TERM=xterm-256color`)
- True color / 24-bit color (`COLORTERM=truecolor`)
- Full ANSI escape sequences
- UTF-8 unicode characters
- Proper PTY emulation

This means tools like vim, less, htop, tmux, and others work as expected.

### What Doesn't Work

- Graphical/GUI programs (Tessera is terminal-only)
- Apps that require specific terminal emulators (e.g., iTerm2 features)
- Desktop notifications from within terminals
- Click-to-open URLs (copy-paste works though)

## Getting Help

If you encounter issues not covered in this guide:

1. Check the main README.md for technical details
2. Review TECHNICAL.md for architecture information
3. Open an issue on GitHub with details about your problem

## About Tessera

Tessera (TESS-er-ah) is created by Glen Barnhardt. The name comes from the small tiles used in mosaics, reflecting the app's tiled terminal layout.

Version 1.0 - 2025
