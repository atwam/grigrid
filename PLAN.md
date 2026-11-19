# Grigrid — PLAN

A minimal native macOS menu-bar grid window manager, modeled after WindowGrid (Windows).

## Goals / non-goals
- Pure Swift, AppKit (+ a tiny bit of SwiftUI for settings), no third-party dependencies.
- SwiftPM + Makefile build, no Xcode project. Target macOS 13+.
- Menu-bar only app (`LSUIElement = true`, no Dock icon).
- Non-goals: keyboard shortcuts, layouts/presets, per-app rules, animations.

## Settings (UserDefaults)
| Key | Type | Default | Range |
|---|---|---|---|
| `columns` | Int | 6 | 1–24 |
| `rows` | Int | 4 | 1–24 |
| `gap` | Int (pt) | 0 | 0–64 |
| launch at login | via `SMAppService.mainApp` (no stored key; read `status`) | off | |

Settings window: small SwiftUI form with 3 steppers and a "Start at login" toggle. Opened from the status-item menu.

## Menu-bar item
Status item (SF Symbol `square.grid.3x3`) with menu:
- "Accessibility: granted" / "Grant Accessibility Access…" (opens prompt / System Settings pane)
- "Settings…"
- "Quit Grigrid"

## Gesture (state machine)
States: `idle → leftDown(candidate window) → selectingStart → selectingEnd → apply | cancel`

1. **idle**: on `leftMouseDown`, hit-test with Accessibility (`AXUIElementCopyElementAtPosition` on the system-wide element) to find the window under the cursor. If the point is in the window's **title bar region** (top ~40 pt of the window frame, and the hit element is not an `AXButton`/`AXTextField`/similar control), remember the window as a *candidate* → `leftDown`. Event always passes through (normal drag).
2. **leftDown**: if `leftMouseUp` arrives → idle (plain drag, untouched). If `rightMouseDown` arrives → **swallow it** (return nil, so no context menu), show the overlay on the screen under the cursor → `selectingStart`.
3. **selectingStart** (right held): the highlighted cell follows the cursor (1×1 cell under cursor). On `rightMouseUp` (swallowed) → anchor = current cell → `selectingEnd`.
4. **selectingEnd** (right released, left still held): the highlight is the rectangle spanning anchor cell ↔ cell under cursor (cursor clamped to the anchor's screen). Pressing right again goes back to `selectingStart` (re-pick anchor), as in WindowGrid.
5. **apply**: on `leftMouseUp` in `selectingStart`/`selectingEnd` → let the event pass (ends the system drag), hide overlay, then set the window's frame via AX (`kAXPositionAttribute`, then `kAXSizeAttribute`, then position again — some apps clamp). Do it on the main queue right after mouse-up, and re-apply once ~50 ms later, because the system drag may still nudge the window.
6. **cancel**: `Escape` keyDown in any non-idle state after the right click → swallow it, hide overlay, ignore the rest of the gesture (state = `cancelled` until left up; the window stays where the user dragged it).

All matching right-button events (`rightMouseDown/Up/Dragged`) are swallowed while in a gesture.

## Geometry
- Grid uses `NSScreen.visibleFrame` (excludes menu bar & Dock) of the screen under the cursor when right is first pressed.
- Cell (c, r): column width = (visible.width − gap·(cols+1)) / cols, same for rows. A selection from cells (c0,r0)…(c1,r1) yields the union rect of those cells (inner gaps included in the span), with `gap` margins to the screen edges.
- Coordinate spaces: CGEvent/AX use top-left origin of the primary display; AppKit uses bottom-left. One helper, `Geometry.swift`, does conversions (`flipped(y) = primaryScreenHeight − y − h`). Pure functions, unit-testable.

## Overlay
- One borderless, transparent, non-activating `NSPanel` (level `.screenSaver`-ish, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`) sized to the target screen's `visibleFrame`.
- Draws: faint dimmed background, grid lines, the highlighted selection rect (accent color, semi-transparent fill + stroke).
- Redraw only when the selected cell rect changes.

## Event tap
- `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, …)` for left down/up/dragged, right down/up/dragged, keyDown.
- Handle `tapDisabledByTimeout` / `tapDisabledByUserInput` by re-enabling.
- Tap callback must be fast: the AX hit-test on left down is the only expensive call; keep it there.
- Requires Accessibility permission (`AXIsProcessTrustedWithOptions` with prompt). Poll trust every 2 s until granted, then install the tap.

## File layout
```
Package.swift
Makefile                  # build, app (bundle + ad-hoc codesign), run, clean, test
Resources/Info.plist      # LSUIElement, bundle id dev.grigrid.Grigrid, min OS 13
Sources/Grigrid/
  main.swift              # NSApplication bootstrap
  AppDelegate.swift       # status item, menu, permission flow, wires components
  Settings.swift          # UserDefaults-backed settings model (ObservableObject)
  SettingsView.swift      # SwiftUI form + window controller
  LaunchAtLogin.swift     # SMAppService wrapper
  Geometry.swift          # grid math & coordinate conversion (pure)
  EventTap.swift          # CGEventTap wrapper
  GestureController.swift # state machine
  WindowAccess.swift      # AX hit-test, title-bar detection, get/set frame
  OverlayWindow.swift     # overlay panel + view
Tests/GrigridTests/GeometryTests.swift
```

## Build / run
- `make app` → `build/Grigrid.app` (swift build -c release, copy binary + Info.plist, `codesign -s - --force`).
- `make run` → build app and `open` it.
- Note: ad-hoc signatures change on every build, so macOS may require re-granting Accessibility after rebuilds. `make app SIGN_ID="<identity>"` allows signing with a stable local certificate.

## Implementation phases (delegated)
1. **Scaffold**: Package, Makefile, Info.plist, main/AppDelegate, Settings, SettingsView, LaunchAtLogin, Geometry + tests. Builds and runs as a menu-bar app.
2. **Gesture**: EventTap, WindowAccess, GestureController, OverlayWindow; wire into AppDelegate.
3. **Review**: code review pass + manual test checklist (README).

## Manual test checklist
- Plain title-bar drag still works; right-click elsewhere still shows context menus.
- Left-drag title bar + right click → overlay on correct screen; anchor follows cursor while right held.
- Release right → rectangle grows from anchor; release left → window fills it (with gap).
- Escape cancels; no stray context menu appears.
- Changing rows/cols/gap applies to the next gesture; login item toggle works.
- Multi-monitor: grid on the screen under the cursor; secondary displays above/left of primary.
