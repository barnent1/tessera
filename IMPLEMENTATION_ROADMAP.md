# Tessera Implementation Roadmap
## Evolution to Multi-Project Orchestration Platform

**Last Updated:** 2025-10-18
**Status:** Planning Phase
**Current Version:** Main (drag-and-drop terminal reordering)

---

## 🎯 Vision

Transform Tessera from a terminal multiplexer into a voice-controlled, multi-agent development workspace with real-time observability.

**Target Architecture:**
- **Left Panel:** 6 project slots (not just terminals)
- **Main Panel:** Toggle between Terminal View ↔ Observability Dashboard
- **Observability:** Real-time event stream, activity charts, drill-down capabilities
- **Voice Control:** (Future) OpenAI Realtime API integration for orchestration
- **Sandboxing:** Container isolation per project

---

## 📋 Implementation Philosophy

**Small, Testable Increments:**
- Each step is independently testable
- Can commit after each step
- Easy to rollback if something breaks
- Build confidence progressively

**Each Step Includes:**
- ✅ Clear goal statement
- ✅ Specific code changes
- ✅ Test criteria
- ✅ Time estimate

---

## Phase 1: Settings - Project Directory Selection

### **Step 1.1: Add Settings UI for Project Directory**
**Goal:** Add a directory picker to settings window

**Changes:**
- `Settings.swift`: Add `projectsDirectory` property with UserDefaults persistence
- `SettingsWindow.swift`: Add "Choose Projects Directory" button with label showing current path
- Default value: `~/Projects`

**Test Criteria:**
- [ ] Open Settings → See new "Projects Directory" section
- [ ] Click "Choose" → File picker opens
- [ ] Select directory → Path updates and persists
- [ ] Restart app → Setting remembered

**Est Time:** 15-20 minutes

---

### **Step 1.2: Add "Open Project" Button to Toolbar**
**Goal:** Add button next to "+" button (placeholder, no functionality yet)

**Changes:**
- `appdelegate.swift` `setupButtons()`: Add new button between "+" and fullscreen
- Icon: 📁 folder icon (SF Symbol: `folder.fill`)
- Action: `@objc func openProject()` - prints "Open Project clicked" for now

**Test Criteria:**
- [ ] See new folder icon button in toolbar
- [ ] Click → Console log "Open Project clicked" appears
- [ ] Button positioned correctly between + and fullscreen

**Est Time:** 10 minutes

---

## Phase 2: Observability Panel Infrastructure

### **Step 2.1: Create Empty Observability View**
**Goal:** New Swift file with minimal NSView for observability

**Changes:**
- Create `sources/tessera/ObservabilityView.swift`
- Empty NSView subclass
- Placeholder: "Observability Dashboard Coming Soon" centered text
- Background: Dark gray with border for visibility

**Test Criteria:**
- [ ] Build succeeds
- [ ] File compiles without errors
- [ ] View not visible yet (that's next step)

**Est Time:** 10 minutes

---

### **Step 2.2: Add Toggle State to AppDelegate**
**Goal:** Track which view (Terminal vs Observability) is active

**Changes:**
- `appdelegate.swift`: Add enum:
  ```swift
  enum MainPanelView {
      case terminal
      case observability
  }
  ```
- Add property: `var mainPanelView: MainPanelView = .terminal`
- Add method: `@objc func toggleMainView()` - switches state, logs change

**Test Criteria:**
- [ ] Build succeeds
- [ ] Can call `toggleMainView()` in code
- [ ] Console logs show state changes

**Est Time:** 10 minutes

---

### **Step 2.3: Add Toggle Icon to Toolbar**
**Goal:** Button to switch between views

**Changes:**
- `setupButtons()`: Add toggle button
- Icon: 📊 for observability (`chart.bar.fill`), ▶️ for terminal (`play.fill`)
- Action calls `toggleMainView()`
- Icon dynamically changes based on `mainPanelView` state

**Test Criteria:**
- [ ] See toggle icon in toolbar (shows 📊 initially)
- [ ] Click → Icon switches to ▶️
- [ ] Click again → Icon switches back to 📊
- [ ] Console logs show state changes

**Est Time:** 15 minutes

---

### **Step 2.4: Wire Toggle to Show/Hide Views**
**Goal:** Actually switch the main panel content

**Changes:**
- `appdelegate.swift`: Modify `relayout()` or create new method
- When `mainPanelView == .observability`:
  - Hide `rightTerminal` (terminal view)
  - Show `observabilityView` in main panel
- When `mainPanelView == .terminal`:
  - Show `rightTerminal`
  - Hide `observabilityView`

**Test Criteria:**
- [ ] Click toggle → Main panel shows "Coming Soon" placeholder
- [ ] Click again → Back to terminals
- [ ] Smooth transition (no flickering)
- [ ] Layout adjusts correctly

**Est Time:** 20-25 minutes

---

## Phase 3: Project Management & Containers

### **Step 3.1: Create Project Data Model**
**Goal:** Swift struct for Project

**Changes:**
- Create `sources/tessera/Project.swift`
- Define struct:
  ```swift
  struct Project: Codable, Identifiable {
      var id: UUID
      var name: String
      var workingDirectory: URL
      var createdAt: Date
      var claudeSessionId: String?
      var isActive: Bool
  }
  ```

**Test Criteria:**
- [ ] Build succeeds
- [ ] Can create `Project` instances in code
- [ ] Properties accessible

**Est Time:** 10 minutes

---

### **Step 3.2: Add Project Storage**
**Goal:** Persist projects to JSON file

**Changes:**
- Create `sources/tessera/ProjectManager.swift`
- Singleton class with methods:
  - `func loadProjects() -> [Project]`
  - `func saveProjects(_ projects: [Project])`
  - `func addProject(_ project: Project)`
  - `func removeProject(id: UUID)`
- Storage location: `~/Library/Application Support/Tessera/projects.json`

**Test Criteria:**
- [ ] Create project programmatically → File created on disk
- [ ] Restart app → Projects loaded from file
- [ ] Can add/remove projects
- [ ] JSON format is valid

**Est Time:** 20 minutes

---

### **Step 3.3: Implement "Open Project" Flow**
**Goal:** File picker → Create project → Add to left panel

**Changes:**
- Implement `openProject()` in `appdelegate.swift`:
  - Open `NSOpenPanel` starting at `Settings.shared.projectsDirectory`
  - Configure for directory selection only
  - On selection: Create `Project` with directory name as project name
  - Call `ProjectManager.shared.addProject()`
  - Add to `leftTerminals` array (reuse existing slot logic)

**Test Criteria:**
- [ ] Click "Open Project" → File picker opens at projects directory
- [ ] Can only select directories (not files)
- [ ] Select directory → New slot appears in left panel
- [ ] Project persisted (survives app restart)

**Est Time:** 25-30 minutes

---

### **Step 3.4: Display Project Info in Left Panel**
**Goal:** Show project name + path instead of "Terminal #"

**Changes:**
- Modify `TerminalView.swift`:
  - Add `var project: Project?` property
  - Modify header to show project info when project is set:
    - Top line: Project name (bold)
    - Bottom line: Truncated path (gray, smaller font)
  - Add visual indicator (folder icon)

**Test Criteria:**
- [ ] Opened projects show name + path in header
- [ ] Regular terminals still show "Terminal #"
- [ ] Visual distinction clear (icon, layout)
- [ ] Path truncates properly if too long

**Est Time:** 20 minutes

---

### **Step 3.5: Launch Claude in Project Directory**
**Goal:** When project opens, start Claude in that directory

**Changes:**
- Add method `startClaudeInProject(_ project: Project)` in TerminalView
- Use existing `LocalProcessTerminalView.startProcess()`
- Set working directory to `project.workingDirectory.path`
- Command: `/bin/zsh -l -c "cd <project-dir> && claude code"`

**Test Criteria:**
- [ ] Open project → Terminal shows project directory prompt
- [ ] Run `pwd` → Shows project directory path
- [ ] Run `ls` → Shows project files
- [ ] Claude launches successfully

**Est Time:** 20-25 minutes

---

### **Step 3.6: Add Container Isolation (Basic)**
**Goal:** Restrict Claude to project directory only

**Changes:**
- When launching Claude, add environment restriction
- Use `--dangerously-skip-permissions` flag (as planned)
- Log attempts to access parent directories
- Future: Add actual sandboxing (Phase II)

**Test Criteria:**
- [ ] Claude can read/write files in project directory
- [ ] Claude operations limited to project tree
- [ ] Console logs any access attempts outside project
- [ ] No crashes or hangs

**Est Time:** 30-35 minutes

---

## Phase 4: Observability System

### **Step 4.1: Setup Embedded HTTP Server**
**Goal:** HTTP server listening on localhost:4000

**Changes:**
- Add package dependency (choose one):
  - Option A: [Swifter](https://github.com/httpswift/swifter) (lightweight)
  - Option B: [Vapor](https://vapor.codes/) (full-featured)
- Create `sources/tessera/ObservabilityServer.swift`
- Start server in `applicationDidFinishLaunching()`
- Endpoint: `POST /events` (just returns 200 OK for now)

**Test Criteria:**
- [ ] Server starts when app launches
- [ ] `curl -X POST http://localhost:4000/events` → 200 OK
- [ ] Console shows "Server started on port 4000"
- [ ] Server stops cleanly when app quits

**Est Time:** 30 minutes

---

### **Step 4.2: Define Event Data Model**
**Goal:** Swift struct matching hook event structure

**Changes:**
- Create `sources/tessera/HookEvent.swift`
- Define struct:
  ```swift
  struct HookEvent: Codable, Identifiable {
      var id: UUID
      var sourceApp: String      // project name
      var sessionId: String       // Claude session ID
      var hookEventType: String   // PreToolUse, PostToolUse, etc.
      var timestamp: Date
      var payload: [String: AnyCodable]  // JSON data
      var summary: String?
  }
  ```
- Add `AnyCodable` wrapper for dynamic JSON

**Test Criteria:**
- [ ] Can decode sample JSON from hook scripts
- [ ] Can encode back to JSON
- [ ] All fields accessible
- [ ] Timestamp formats correctly

**Est Time:** 15 minutes

---

### **Step 4.3: Store Events in Memory**
**Goal:** Array to hold events, no persistence yet

**Changes:**
- `ObservabilityServer.swift`: Add `var events: [HookEvent] = []`
- POST /events endpoint:
  - Parse JSON body as `HookEvent`
  - Append to `events` array
  - Return 201 Created
- GET /events endpoint:
  - Return all events as JSON array

**Test Criteria:**
- [ ] POST event → Stored in array
- [ ] GET /events → Returns events as JSON
- [ ] Multiple events accumulate
- [ ] Invalid JSON → 400 Bad Request

**Est Time:** 20 minutes

---

### **Step 4.4: Copy Hook Scripts to Project**
**Goal:** Auto-setup hooks when opening project

**Changes:**
- Bundle `.claude/` directory in app bundle:
  - Copy from claude-code-hooks-multi-agent-observability repo
  - Add to Xcode project as resource folder
- When opening project (in `openProject()`):
  - Check if `<project>/.claude/` exists
  - If not, copy hooks from bundle
  - Update `settings.json` with project name as `source-app`

**Test Criteria:**
- [ ] Open new project → `.claude/` directory created
- [ ] `send_event.py` and other hook scripts present
- [ ] `settings.json` has correct project name in `--source-app` flag
- [ ] Hooks executable (proper permissions)

**Est Time:** 25-30 minutes

---

### **Step 4.5: Test Hook → Server Communication**
**Goal:** Verify events flow from Claude to Tessera

**Changes:**
- Open project with hooks configured
- Run Claude command (e.g., "read the README")
- Monitor server logs

**Test Criteria:**
- [ ] Claude executes tool → PreToolUse event received
- [ ] Server logs show event details
- [ ] GET /events returns the event
- [ ] Event has correct `sourceApp` (project name)

**Est Time:** 15 minutes (mostly testing)

---

### **Step 4.6: Display Event Count in Observability View**
**Goal:** Show "X events received" in placeholder

**Changes:**
- `ObservabilityView.swift`: Add timer to poll server
- Fetch event count from server (or get notified via callback)
- Update label: "Observability Dashboard - 42 events"

**Test Criteria:**
- [ ] Switch to observability view → Shows current count
- [ ] Generate events in Claude → Counter updates
- [ ] Real-time updates (within 1-2 seconds)

**Est Time:** 20 minutes

---

### **Step 4.7: Create Basic Event List View**
**Goal:** Scrollable list showing events

**Changes:**
- Replace placeholder in `ObservabilityView`
- Add `NSTableView` with columns:
  - Timestamp
  - Event Type
  - Source App (project)
  - Summary (if available)
- Data source from server
- Auto-scroll to bottom

**Test Criteria:**
- [ ] Events appear in list as table rows
- [ ] Scrollable when many events
- [ ] Auto-scrolls to bottom for new events
- [ ] Timestamps formatted nicely (HH:MM:SS)

**Est Time:** 30-35 minutes

---

### **Step 4.8: Add Event Type Icons/Emojis**
**Goal:** Visual indicators for event types

**Changes:**
- Create emoji mapping:
  - PreToolUse: 🔧
  - PostToolUse: ✅
  - UserPromptSubmit: 💬
  - Notification: 🔔
  - Stop: 🛑
  - SubagentStop: 👥
  - SessionStart: 🚀
  - SessionEnd: 🏁
- Add emoji column to table (or prefix to event type)

**Test Criteria:**
- [ ] Events display correct emoji
- [ ] Easy to scan visually by event type
- [ ] Emoji renders properly on macOS

**Est Time:** 15 minutes

---

### **Step 4.9: Add Color Coding by Project**
**Goal:** Each project gets a unique color

**Changes:**
- Create `ColorManager.swift`:
  - Assigns consistent color to each `sourceApp` (project)
  - Colors: Use HSL with golden ratio for distribution
  - Store mapping in memory
- Add colored left border to table rows (3-5px width)

**Test Criteria:**
- [ ] Events from same project have same color
- [ ] Different projects have different colors
- [ ] Colors are visually distinct
- [ ] Color persists across app restarts

**Est Time:** 25 minutes

---

### **Step 4.10: Add Session Color (Second Border)**
**Goal:** Second color for session ID

**Changes:**
- Extend `ColorManager` to assign colors to session IDs
- Add second border inside first (2-3px width)
- Visual layout: Project color (outer) | Session color (inner) | Event content

**Test Criteria:**
- [ ] Two-color border visible on each row
- [ ] Sessions within same project distinguishable
- [ ] Colors don't clash

**Est Time:** 20 minutes

---

### **Step 4.11: Add Filter Controls**
**Goal:** Filter by project, session, event type

**Changes:**
- Add filter panel above event list
- Controls:
  - Project dropdown (shows all source apps)
  - Session dropdown (shows all sessions)
  - Event Type multi-select (checkboxes)
  - "Clear Filters" button
- Apply filters to table data

**Test Criteria:**
- [ ] Select project → Only that project's events show
- [ ] Select event type → Only that type shows
- [ ] Multiple filters combine (AND logic)
- [ ] Clear filters → All events return

**Est Time:** 35-40 minutes

---

### **Step 4.12: Implement Click Event → Open Terminal**
**Goal:** Click event row → Switch to terminal view + open project

**Changes:**
- Make table rows clickable
- On row click:
  1. Extract `sourceApp` from event
  2. Find project in `leftTerminals`
  3. Call `toggleMainView()` to switch to terminal view
  4. Call `promoteLeftTerminal()` to show project in main panel

**Test Criteria:**
- [ ] Click event row → Switches to terminal view
- [ ] Correct project promoted to main panel
- [ ] Visual feedback on click (row highlight)

**Est Time:** 25 minutes

---

### **Step 4.13: Create Live Pulse Chart (Canvas)**
**Goal:** Basic bar chart showing activity over time

**Changes:**
- Create `sources/tessera/LivePulseChart.swift`
- Custom view using `Core Graphics` (CGContext)
- Time buckets: 1-minute intervals (60 buckets = 1 hour)
- Bar height proportional to event count in bucket
- Monochrome for now (no colors)
- Update every second

**Test Criteria:**
- [ ] Chart renders in observability view
- [ ] Bars represent activity correctly
- [ ] Updates in real-time as events arrive
- [ ] X-axis shows time labels
- [ ] Y-axis shows count labels

**Est Time:** 45-50 minutes (canvas rendering is complex)

---

### **Step 4.14: Add Color/Emoji to Chart Bars**
**Goal:** Chart bars colored by project, emojis for event types

**Changes:**
- Color bars using project colors (from ColorManager)
- If multiple projects in bucket, use gradient or stacked bars
- Draw emoji on bars for event types (small, semi-transparent)
- Tooltip on hover:
  - Shows time range
  - Event count breakdown by type
  - Project names

**Test Criteria:**
- [ ] Bars are color-coded by project
- [ ] Emojis visible on bars (if space allows)
- [ ] Hover shows detailed tooltip
- [ ] Tooltip positioned correctly

**Est Time:** 35-40 minutes

---

### **Step 4.15: Add Time Range Selector (1m/3m/5m)**
**Goal:** Buttons to switch chart time window

**Changes:**
- Add button group above chart: "1m" "3m" "5m"
- Selected button highlighted
- Chart aggregates data based on selection:
  - 1m: 60 buckets × 1 second each
  - 3m: 60 buckets × 3 seconds each
  - 5m: 60 buckets × 5 seconds each
- Chart updates when selection changes

**Test Criteria:**
- [ ] Click "3m" → Chart shows 3-minute window
- [ ] Click "1m" → Chart zooms to 1-minute window
- [ ] Data aggregates correctly for each range
- [ ] Button states update (active/inactive)

**Est Time:** 25-30 minutes

---

## 📊 Summary

**Total Steps:** 30 incremental pieces
**Total Estimated Time:** 10-14 hours of focused implementation

### Breakdown by Phase:
- **Phase 1 (Settings):** 2 steps, ~30 min
- **Phase 2 (Toggle):** 4 steps, ~60 min
- **Phase 3 (Projects):** 6 steps, ~2.5 hrs
- **Phase 4 (Observability):** 15 steps, ~7 hrs
- **Buffer/Polish:** ~1.5 hrs

---

## 🚀 Suggested Session Plan

### **Session 1: Foundation (Steps 1.1-2.4)**
- Settings for project directory
- Toggle infrastructure
- Empty observability view
- **Deliverable:** Can toggle between terminal and placeholder view

### **Session 2: Project Management (Steps 3.1-3.4)**
- Project data model
- Project storage/persistence
- Open project flow
- Display projects in left panel
- **Deliverable:** Can open projects and see them listed

### **Session 3: Claude Integration (Steps 3.5-3.6)**
- Launch Claude in project directory
- Basic container isolation
- **Deliverable:** Claude runs in project context

### **Session 4: Event Pipeline (Steps 4.1-4.5)**
- HTTP server setup
- Event data model
- Hook script integration
- Test event flow
- **Deliverable:** Events flow from Claude to Tessera

### **Session 5: Event Display (Steps 4.6-4.10)**
- Event count display
- Event list view
- Icons and colors
- Session colors
- **Deliverable:** Can see colorful event timeline

### **Session 6: Advanced Features (Steps 4.11-4.15)**
- Filtering controls
- Click to navigate
- Live pulse chart
- Chart enhancements
- **Deliverable:** Full observability dashboard

---

## 🔄 After Each Step

1. **Test thoroughly** using criteria listed
2. **Commit to git** with descriptive message
3. **Update this document** - check off completed items
4. **Take a break** if needed

---

## 📝 Progress Tracking

### Phase 1: Settings
- [ ] Step 1.1: Add Settings UI for Project Directory
- [ ] Step 1.2: Add "Open Project" Button to Toolbar

### Phase 2: Observability Panel
- [ ] Step 2.1: Create Empty Observability View
- [ ] Step 2.2: Add Toggle State to AppDelegate
- [ ] Step 2.3: Add Toggle Icon to Toolbar
- [ ] Step 2.4: Wire Toggle to Show/Hide Views

### Phase 3: Project Management
- [ ] Step 3.1: Create Project Data Model
- [ ] Step 3.2: Add Project Storage
- [ ] Step 3.3: Implement "Open Project" Flow
- [ ] Step 3.4: Display Project Info in Left Panel
- [ ] Step 3.5: Launch Claude in Project Directory
- [ ] Step 3.6: Add Container Isolation (Basic)

### Phase 4: Observability System
- [ ] Step 4.1: Setup Embedded HTTP Server
- [ ] Step 4.2: Define Event Data Model
- [ ] Step 4.3: Store Events in Memory
- [ ] Step 4.4: Copy Hook Scripts to Project
- [ ] Step 4.5: Test Hook → Server Communication
- [ ] Step 4.6: Display Event Count
- [ ] Step 4.7: Create Basic Event List View
- [ ] Step 4.8: Add Event Type Icons/Emojis
- [ ] Step 4.9: Add Color Coding by Project
- [ ] Step 4.10: Add Session Color (Second Border)
- [ ] Step 4.11: Add Filter Controls
- [ ] Step 4.12: Implement Click Event → Open Terminal
- [ ] Step 4.13: Create Live Pulse Chart (Canvas)
- [ ] Step 4.14: Add Color/Emoji to Chart Bars
- [ ] Step 4.15: Add Time Range Selector (1m/3m/5m)

---

## 🎯 Future Phases (Beyond This Roadmap)

### Phase 5: Voice Integration
- Python service for OpenAI Realtime API
- Swift wrapper for lifecycle management
- Voice command dispatch
- Transcription display in observability

### Phase 6: Advanced Sandbox
- Full container isolation (docker-style)
- Network restrictions
- Resource limits (CPU/memory)
- Security audit

### Phase 7: Multi-Agent Orchestration
- Agent registry system
- Cross-project coordination
- Automated workflows
- Agent templates

---

## 📚 Reference Repositories

**Observability Dashboard:**
- https://github.com/disler/claude-code-hooks-multi-agent-observability
- Vue 3 + TypeScript + Bun server
- Hook scripts in Python
- SQLite + WebSocket architecture

**Big Three Super Agent:**
- https://github.com/disler/big-3-super-agent
- Voice orchestration with OpenAI Realtime API
- Multi-agent management (Claude + Gemini)
- Python-based

---

## ✅ Completion Criteria

**Minimum Viable Product (MVP):**
- ✅ Can open multiple projects in left panel
- ✅ Can toggle to observability view
- ✅ Events flow from Claude to observability server
- ✅ Event timeline displays with colors
- ✅ Live pulse chart shows activity
- ✅ Can click event to open project terminal

**Success Metrics:**
- No crashes during normal use
- Events appear within 1-2 seconds
- UI responsive with 1000+ events
- Colors are visually distinct
- Navigation is intuitive

---

**Document Version:** 1.0
**Created:** 2025-10-18
**Next Review:** After Phase 1 completion
