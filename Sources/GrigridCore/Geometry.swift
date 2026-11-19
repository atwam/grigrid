import CoreGraphics

/// A cell in the grid. `col` 0 is the leftmost column, `row` 0 is the TOP row.
public struct GridCell: Equatable, Hashable, CustomStringConvertible {
    public var col: Int
    public var row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }

    public var description: String { "(\(col),\(row))" }
}

/// Grid math and coordinate conversion. Pure functions, no AppKit.
///
/// Grid functions work in AppKit screen coordinates (origin bottom-left, y up),
/// i.e. the space of `NSScreen.visibleFrame` and `NSEvent.mouseLocation`.
/// Row 0 is the top row of the visible frame.
public enum Geometry {

    /// Size of one cell: (visible − gap·(n+1)) / n per axis, never negative.
    public static func cellSize(in frame: CGRect, columns: Int, rows: Int, gap: CGFloat) -> CGSize {
        let cols = max(1, columns), rws = max(1, rows)
        let w = (frame.width - gap * CGFloat(cols + 1)) / CGFloat(cols)
        let h = (frame.height - gap * CGFloat(rws + 1)) / CGFloat(rws)
        return CGSize(width: max(0, w), height: max(0, h))
    }

    /// The cell under `point` (AppKit coords) in `frame`, clamped to the grid.
    /// Cell boundaries for hit-testing lie in the middle of the gaps, so every
    /// point maps to exactly one cell.
    public static func cell(at point: CGPoint, in frame: CGRect,
                            columns: Int, rows: Int, gap: CGFloat = 0) -> GridCell {
        let cols = max(1, columns), rws = max(1, rows)
        let pitchX = (frame.width - gap) / CGFloat(cols)     // cell width + gap
        let pitchY = (frame.height - gap) / CGFloat(rws)
        let dx = point.x - frame.minX - gap / 2
        let dyFromTop = frame.maxY - point.y - gap / 2
        let c = pitchX > 0 ? Int((dx / pitchX).rounded(.down)) : 0
        let r = pitchY > 0 ? Int((dyFromTop / pitchY).rounded(.down)) : 0
        return GridCell(col: clamp(c, 0, cols - 1), row: clamp(r, 0, rws - 1))
    }

    /// Union rect (AppKit coords) of the cells spanning `a`…`b` (any order),
    /// inner gaps included, with `gap` margins to the frame edges.
    /// Cell indices are clamped to the grid.
    public static func rect(from a: GridCell, to b: GridCell, in frame: CGRect,
                            columns: Int, rows: Int, gap: CGFloat) -> CGRect {
        let cols = max(1, columns), rws = max(1, rows)
        let size = cellSize(in: frame, columns: cols, rows: rws, gap: gap)
        let c0 = clamp(min(a.col, b.col), 0, cols - 1)
        let c1 = clamp(max(a.col, b.col), 0, cols - 1)
        let r0 = clamp(min(a.row, b.row), 0, rws - 1)   // top-most row
        let r1 = clamp(max(a.row, b.row), 0, rws - 1)   // bottom-most row

        let x = frame.minX + gap + CGFloat(c0) * (size.width + gap)
        let width = CGFloat(c1 - c0 + 1) * size.width + CGFloat(c1 - c0) * gap
        let top = frame.maxY - gap - CGFloat(r0) * (size.height + gap)
        let height = CGFloat(r1 - r0 + 1) * size.height + CGFloat(r1 - r0) * gap
        return CGRect(x: x, y: top - height, width: width, height: height)
    }

    /// Rect of a single cell.
    public static func rect(of cell: GridCell, in frame: CGRect,
                            columns: Int, rows: Int, gap: CGFloat) -> CGRect {
        rect(from: cell, to: cell, in: frame, columns: columns, rows: rows, gap: gap)
    }

    // MARK: - Coordinate conversion
    // AppKit: origin bottom-left of the primary screen, y up.
    // CG/AX:  origin top-left of the primary screen, y down.
    // The transform is its own inverse, so the same functions convert both ways.

    /// Flip a rect between AppKit and CG/AX coordinates: y' = H − y − h.
    public static func flipped(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.minY - rect.height,
               width: rect.width, height: rect.height)
    }

    /// Flip a point between AppKit and CG/AX coordinates: y' = H − y.
    public static func flipped(_ point: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// AppKit rect → CG/AX rect (top-left origin), e.g. for `kAXPositionAttribute`.
    public static func appKitToCG(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        flipped(rect, primaryScreenHeight: primaryScreenHeight)
    }

    /// CG/AX rect → AppKit rect.
    public static func cgToAppKit(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        flipped(rect, primaryScreenHeight: primaryScreenHeight)
    }

    /// AppKit point → CG/AX point.
    public static func appKitToCG(_ point: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        flipped(point, primaryScreenHeight: primaryScreenHeight)
    }

    /// CG/AX point (e.g. `CGEvent.location`) → AppKit point.
    public static func cgToAppKit(_ point: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        flipped(point, primaryScreenHeight: primaryScreenHeight)
    }

    private static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int {
        min(max(v, lo), hi)
    }
}
