import AppKit
import ApplicationServices
import GrigridCore

/// The drag-title-bar + right-click grid gesture (see PLAN.md, "Gesture").
///
/// All methods run on the main thread (the event tap lives on the main run loop).
/// Points named `cg…` are CG/AX global coordinates; everything else is AppKit.
final class GestureController {
    enum Phase: Equatable {
        case idle
        /// Left button down on a title bar; nothing visible yet.
        case leftDown
        /// Right held: the anchor cell follows the cursor.
        case selectingStart
        /// Right released, left held: selection spans anchor ↔ cursor cell.
        case selectingEnd
        /// Escape pressed: ignore everything until left is released.
        case cancelled
    }

    private(set) var phase: Phase = .idle

    private let overlay = OverlayWindow()
    private var tap: EventTap?

    // Gesture state
    private var window: AXUIElement?
    private var columns = 1, rows = 1, gap = 0          // read once per gesture
    private var settingsRead = false
    private var screenFrame: CGRect = .zero             // frame of the target screen (for change detection)
    private var gridFrame: CGRect = .zero               // visibleFrame of the target screen
    private var anchor = GridCell(col: 0, row: 0)
    private var selection: CGRect?
    private var lastLocation: CGPoint = .zero           // AppKit

    /// True between a right-mouse-down we swallowed and its matching up.
    /// Kept independent of `phase` so the up is swallowed even after the gesture ended
    /// (e.g. left released while right is still held).
    private var swallowingRight = false

    private static let escapeKeyCode: Int64 = 53

    init() {}

    /// Installs the event tap. Returns false if it could not be created.
    func start() -> Bool {
        if tap != nil { return true }
        WindowAccess.configure()
        let tap = EventTap { [unowned self] type, event in
            self.handle(type: type, event: event)
        }
        tap.onReenabled = { [weak self] in self?.reconcileAfterTapDisabled() }
        guard tap.start() else { return false }
        self.tap = tap
        return true
    }

    // MARK: - Event handling

    /// Returns true to swallow the event.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .leftMouseDown:
            leftMouseDown(cgPoint: event.location)
            return false

        case .leftMouseUp:
            leftMouseUp(at: appKit(event.location))
            return false

        case .leftMouseDragged:
            mouseMoved(to: appKit(event.location))
            return false

        case .rightMouseDragged:
            mouseMoved(to: appKit(event.location))
            return swallowingRight

        case .rightMouseDown:
            return rightMouseDown(at: appKit(event.location))

        case .rightMouseUp:
            return rightMouseUp(at: appKit(event.location))

        case .keyDown:
            return keyDown(event)

        default:
            return false
        }
    }

    private func leftMouseDown(cgPoint: CGPoint) {
        // A new left-down while not idle means we missed a left-up: start over.
        if phase != .idle { reset() }
        // Clicks on our own windows (status menu, Settings): skip the AX hit-test, which would
        // message this process while its main thread is blocked here in the tap callback.
        let number = NSWindow.windowNumber(at: appKit(cgPoint), belowWindowWithWindowNumber: 0)
        if NSApp.window(withWindowNumber: number) != nil { return }
        if let w = WindowAccess.titleBarWindow(at: cgPoint) {
            window = w
            phase = .leftDown
        }
    }

    private func leftMouseUp(at point: CGPoint) {
        switch phase {
        case .selectingStart, .selectingEnd:
            mouseMoved(to: point)
            applyAndFinish()
        case .leftDown, .cancelled, .idle:
            reset()
        }
    }

    private func rightMouseDown(at point: CGPoint) -> Bool {
        switch phase {
        case .idle:
            swallowingRight = false          // a fresh down: any pending up was missed
            return false                     // ordinary right click / context menu
        case .leftDown:
            readSettings()
            phase = .selectingStart
            swallowingRight = true
            updateStart(at: point)
            return true
        case .selectingEnd:
            phase = .selectingStart          // re-pick the anchor
            swallowingRight = true
            updateStart(at: point)
            return true
        case .selectingStart, .cancelled:
            swallowingRight = true
            return true
        }
    }

    private func rightMouseUp(at point: CGPoint) -> Bool {
        guard swallowingRight else { return false }   // its down was passed through
        swallowingRight = false
        if phase == .selectingStart {
            updateStart(at: point)
            phase = .selectingEnd
        }
        return true
    }

    private func mouseMoved(to point: CGPoint) {
        switch phase {
        case .selectingStart: updateStart(at: point)
        case .selectingEnd: updateEnd(at: point)
        default: break
        }
    }

    private func keyDown(_ event: CGEvent) -> Bool {
        guard event.getIntegerValueField(.keyboardEventKeycode) == Self.escapeKeyCode else { return false }
        switch phase {
        case .selectingStart, .selectingEnd:
            overlay.hide()
            selection = nil
            phase = .cancelled
            return true
        case .cancelled:
            return true                      // swallow key repeats too
        case .idle, .leftDown:
            return false
        }
    }

    // MARK: - Selection

    private func readSettings() {
        guard !settingsRead else { return }
        let s = Settings.shared
        columns = s.columns
        rows = s.rows
        gap = s.gap
        settingsRead = true
    }

    /// selectingStart: the anchor is the cell under the cursor, on the screen under the cursor.
    private func updateStart(at point: CGPoint) {
        lastLocation = point
        let screen = Self.screen(containing: point)
        if let screen = screen, screen.frame != screenFrame || !overlay.isVisible {
            screenFrame = screen.frame
            gridFrame = screen.visibleFrame
            selection = nil
            overlay.show(on: screen, columns: columns, rows: rows, gap: gap)
        }
        guard gridFrame.width > 0, gridFrame.height > 0 else { return }
        anchor = Geometry.cell(at: point, in: gridFrame, columns: columns, rows: rows, gap: CGFloat(gap))
        setSelection(Geometry.rect(of: anchor, in: gridFrame, columns: columns, rows: rows, gap: CGFloat(gap)))
    }

    /// selectingEnd: span anchor ↔ cursor cell; `cell(at:)` clamps to the anchor's screen.
    private func updateEnd(at point: CGPoint) {
        lastLocation = point
        guard gridFrame.width > 0, gridFrame.height > 0 else { return }
        let current = Geometry.cell(at: point, in: gridFrame, columns: columns, rows: rows, gap: CGFloat(gap))
        setSelection(Geometry.rect(from: anchor, to: current, in: gridFrame,
                                   columns: columns, rows: rows, gap: CGFloat(gap)))
    }

    private func setSelection(_ rect: CGRect) {
        guard rect != selection else { return }
        selection = rect
        overlay.update(selection: rect)
    }

    // MARK: - Finish

    private func applyAndFinish() {
        let target = selection
        let win = window
        reset()
        // A large gap with many rows/cols can leave zero-sized cells; don't shrink the window to nothing.
        guard let rect = target, rect.width >= 1, rect.height >= 1,
              let win = win, let primary = NSScreen.screens.first else { return }
        let cgRect = Geometry.appKitToCG(rect, primaryScreenHeight: primary.frame.height)
        // Let the mouse-up reach the app first (ends the system drag), then set the frame,
        // and once more shortly after because the drag may still nudge the window.
        DispatchQueue.main.async {
            WindowAccess.setFrame(cgRect, of: win)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WindowAccess.setFrame(cgRect, of: win)
        }
    }

    /// Back to idle. Does not touch `swallowingRight`: a right-up still pending
    /// for a swallowed right-down must also be swallowed.
    private func reset() {
        if overlay.isVisible { overlay.hide() }
        phase = .idle
        window = nil
        selection = nil
        settingsRead = false
        screenFrame = .zero
        gridFrame = .zero
    }

    /// The tap was off for a while, so ups may have been missed. Re-sync with the
    /// actual button state.
    private func reconcileAfterTapDisabled() {
        let leftDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        let rightDown = CGEventSource.buttonState(.combinedSessionState, button: .right)

        if !rightDown {
            swallowingRight = false
            if phase == .selectingStart { phase = .selectingEnd }
        }
        if !leftDown {
            switch phase {
            case .selectingStart, .selectingEnd:
                // The user released over the selection they were looking at: apply it.
                applyAndFinish()
            case .leftDown, .cancelled:
                reset()
            case .idle:
                break
            }
        }
    }

    // MARK: - Helpers

    private func appKit(_ cgPoint: CGPoint) -> CGPoint {
        let h = NSScreen.screens.first?.frame.height ?? 0
        return Geometry.cgToAppKit(cgPoint, primaryScreenHeight: h)
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        if let s = screens.first(where: { NSMouseInRect(point, $0.frame, false) }) { return s }
        // On an edge/gap between displays: pick the nearest screen.
        return screens.min(by: { distance(point, $0.frame) < distance(point, $1.frame) })
    }

    private static func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return dx * dx + dy * dy
    }
}
