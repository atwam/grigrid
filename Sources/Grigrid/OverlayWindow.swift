import AppKit
import GrigridCore

/// Borderless, transparent, click-through panel covering one screen's visibleFrame.
/// Draws a faint dim, the grid, and the current selection. Never becomes key.
final class OverlayWindow {
    private let panel: NSPanel
    private let gridView = OverlayView()

    init() {
        panel = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = gridView
    }

    var isVisible: Bool { panel.isVisible }

    /// Shows (or moves) the overlay on `screen`, covering its visibleFrame.
    func show(on screen: NSScreen, columns: Int, rows: Int, gap: Int) {
        let frame = screen.visibleFrame
        if panel.frame != frame {
            panel.setFrame(frame, display: false)
        }
        gridView.configure(screenFrame: frame, columns: columns, rows: rows, gap: CGFloat(gap))
        panel.orderFrontRegardless()
    }

    /// Updates the highlighted rect (AppKit screen coordinates). Redraws only on change.
    func update(selection: CGRect) {
        gridView.setSelection(selection)
    }

    func hide() {
        panel.orderOut(nil)
        gridView.setSelection(nil)
    }
}

private final class OverlayView: NSView {
    private var screenFrame: CGRect = .zero
    private var columns = 1
    private var rows = 1
    private var gap: CGFloat = 0
    /// Selection in screen coordinates.
    private var selection: CGRect?

    override var isOpaque: Bool { false }

    func configure(screenFrame: CGRect, columns: Int, rows: Int, gap: CGFloat) {
        guard screenFrame != self.screenFrame || columns != self.columns
                || rows != self.rows || gap != self.gap else { return }
        self.screenFrame = screenFrame
        self.columns = columns
        self.rows = rows
        self.gap = gap
        needsDisplay = true
    }

    func setSelection(_ rect: CGRect?) {
        guard rect != selection else { return }
        selection = rect
        needsDisplay = true
    }

    /// Screen coordinates → view coordinates (the panel covers `screenFrame`).
    private func local(_ r: CGRect) -> CGRect {
        r.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        bounds.fill(using: .copy)

        NSColor.black.withAlphaComponent(0.12).setFill()
        bounds.fill(using: .sourceOver)

        // Grid
        let lineColor = NSColor.white.withAlphaComponent(0.45)
        lineColor.setStroke()
        if gap > 0 {
            for c in 0..<columns {
                for r in 0..<rows {
                    let cell = Geometry.rect(of: GridCell(col: c, row: r), in: screenFrame,
                                             columns: columns, rows: rows, gap: gap)
                    let path = NSBezierPath(rect: local(cell).insetBy(dx: 0.5, dy: 0.5))
                    path.lineWidth = 1
                    path.stroke()
                }
            }
        } else {
            let path = NSBezierPath()
            path.lineWidth = 1
            let size = Geometry.cellSize(in: screenFrame, columns: columns, rows: rows, gap: 0)
            for c in 1..<max(columns, 1) {
                let x = (CGFloat(c) * size.width).rounded() + 0.5
                path.move(to: CGPoint(x: x, y: 0))
                path.line(to: CGPoint(x: x, y: bounds.height))
            }
            for r in 1..<max(rows, 1) {
                let y = (bounds.height - CGFloat(r) * size.height).rounded() + 0.5
                path.move(to: CGPoint(x: 0, y: y))
                path.line(to: CGPoint(x: bounds.width, y: y))
            }
            path.stroke()
        }

        // Selection
        if let sel = selection {
            let rect = local(sel).insetBy(dx: 1, dy: 1)
            let accent = NSColor.controlAccentColor
            accent.withAlphaComponent(0.35).setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            path.fill()
            accent.withAlphaComponent(0.9).setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }
}
