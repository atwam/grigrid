import XCTest
import CoreGraphics
@testable import GrigridCore

final class GeometryTests: XCTestCase {
    // A secondary-ish visible frame with a non-zero origin.
    let frame = CGRect(x: 100, y: 50, width: 1200, height: 800)

    func assertRect(_ a: CGRect, _ b: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.minX, b.minX, accuracy: 1e-9, "minX", file: file, line: line)
        XCTAssertEqual(a.minY, b.minY, accuracy: 1e-9, "minY", file: file, line: line)
        XCTAssertEqual(a.width, b.width, accuracy: 1e-9, "width", file: file, line: line)
        XCTAssertEqual(a.height, b.height, accuracy: 1e-9, "height", file: file, line: line)
    }

    // MARK: cellSize

    func testCellSizeNoGap() {
        let s = Geometry.cellSize(in: frame, columns: 6, rows: 4, gap: 0)
        XCTAssertEqual(s.width, 200)
        XCTAssertEqual(s.height, 200)
    }

    func testCellSizeWithGap() {
        let s = Geometry.cellSize(in: frame, columns: 6, rows: 4, gap: 10)
        XCTAssertEqual(s.width, (1200 - 70) / 6, accuracy: 1e-9)
        XCTAssertEqual(s.height, (800 - 50) / 4, accuracy: 1e-9)
    }

    func testCellSizeNeverNegative() {
        let s = Geometry.cellSize(in: CGRect(x: 0, y: 0, width: 50, height: 50), columns: 24, rows: 24, gap: 64)
        XCTAssertEqual(s, .zero)
    }

    // MARK: cell(at:)

    func testCellAtTopLeftAndBottomRight() {
        let tl = Geometry.cell(at: CGPoint(x: frame.minX + 1, y: frame.maxY - 1), in: frame, columns: 6, rows: 4)
        XCTAssertEqual(tl, GridCell(col: 0, row: 0))
        let br = Geometry.cell(at: CGPoint(x: frame.maxX - 1, y: frame.minY + 1), in: frame, columns: 6, rows: 4)
        XCTAssertEqual(br, GridCell(col: 5, row: 3))
    }

    func testCellAtInterior() {
        // x = 100 + 450 → col 2 (200..400 → col 1, 400..600 → col 2); y from top = 850 - 500 = 350 → row 1
        let c = Geometry.cell(at: CGPoint(x: 550, y: 500), in: frame, columns: 6, rows: 4)
        XCTAssertEqual(c, GridCell(col: 2, row: 1))
    }

    func testCellAtClampsOutside() {
        XCTAssertEqual(Geometry.cell(at: CGPoint(x: -1000, y: 5000), in: frame, columns: 6, rows: 4),
                       GridCell(col: 0, row: 0))
        XCTAssertEqual(Geometry.cell(at: CGPoint(x: 5000, y: -1000), in: frame, columns: 6, rows: 4),
                       GridCell(col: 5, row: 3))
        // Exactly on the max edge stays in the last cell.
        XCTAssertEqual(Geometry.cell(at: CGPoint(x: frame.maxX, y: frame.minY), in: frame, columns: 6, rows: 4),
                       GridCell(col: 5, row: 3))
    }

    func testCellAtWithGapUsesGapMidpoints() {
        // cols=2, gap=20, width 1200 → cell w = (1200-60)/2 = 570; col 0 spans x 120..690, gap 690..710.
        let f = frame
        let left = Geometry.cell(at: CGPoint(x: f.minX + 20 + 570 + 9, y: f.midY), in: f, columns: 2, rows: 1, gap: 20)
        let right = Geometry.cell(at: CGPoint(x: f.minX + 20 + 570 + 11, y: f.midY), in: f, columns: 2, rows: 1, gap: 20)
        XCTAssertEqual(left.col, 0)
        XCTAssertEqual(right.col, 1)
    }

    func testCellAtRoundTripsWithCellRect() {
        for gap in [CGFloat(0), 8, 30] {
            for col in 0..<6 {
                for row in 0..<4 {
                    let cell = GridCell(col: col, row: row)
                    let r = Geometry.rect(of: cell, in: frame, columns: 6, rows: 4, gap: gap)
                    let hit = Geometry.cell(at: CGPoint(x: r.midX, y: r.midY), in: frame, columns: 6, rows: 4, gap: gap)
                    XCTAssertEqual(hit, cell, "gap \(gap)")
                }
            }
        }
    }

    // MARK: rect(from:to:)

    func testSingleCellNoGap() {
        let r = Geometry.rect(of: GridCell(col: 0, row: 0), in: frame, columns: 6, rows: 4, gap: 0)
        assertRect(r, CGRect(x: 100, y: 650, width: 200, height: 200))
    }

    func testFullGridEqualsFrameInsetByGap() {
        let r = Geometry.rect(from: GridCell(col: 0, row: 0), to: GridCell(col: 5, row: 3),
                              in: frame, columns: 6, rows: 4, gap: 12)
        assertRect(r, frame.insetBy(dx: 12, dy: 12))
    }

    func testRangeAnyOrder() {
        let a = GridCell(col: 1, row: 2), b = GridCell(col: 3, row: 0)
        let r1 = Geometry.rect(from: a, to: b, in: frame, columns: 6, rows: 4, gap: 10)
        let r2 = Geometry.rect(from: b, to: a, in: frame, columns: 6, rows: 4, gap: 10)
        let r3 = Geometry.rect(from: GridCell(col: 1, row: 0), to: GridCell(col: 3, row: 2),
                               in: frame, columns: 6, rows: 4, gap: 10)
        assertRect(r1, r2)
        assertRect(r1, r3)
    }

    func testRangeWithGapIncludesInnerGaps() {
        let gap: CGFloat = 10
        let s = Geometry.cellSize(in: frame, columns: 6, rows: 4, gap: gap)
        let r = Geometry.rect(from: GridCell(col: 1, row: 1), to: GridCell(col: 2, row: 2),
                              in: frame, columns: 6, rows: 4, gap: gap)
        XCTAssertEqual(r.minX, frame.minX + gap + s.width + gap, accuracy: 1e-9)
        XCTAssertEqual(r.width, 2 * s.width + gap, accuracy: 1e-9)
        XCTAssertEqual(r.maxY, frame.maxY - gap - s.height - gap, accuracy: 1e-9)
        XCTAssertEqual(r.height, 2 * s.height + gap, accuracy: 1e-9)
    }

    func testRangeClampsOutOfBoundsCells() {
        let r = Geometry.rect(from: GridCell(col: -3, row: -3), to: GridCell(col: 99, row: 99),
                              in: frame, columns: 6, rows: 4, gap: 0)
        assertRect(r, frame)
    }

    func testBottomRightCell() {
        let r = Geometry.rect(of: GridCell(col: 5, row: 3), in: frame, columns: 6, rows: 4, gap: 0)
        assertRect(r, CGRect(x: 1100, y: 50, width: 200, height: 200))
    }

    // MARK: coordinate conversion

    func testFlipRect() {
        // Primary 1920x1080. AppKit rect at bottom-left 0,0 size 100x50 → CG y = 1080-0-50 = 1030.
        let cg = Geometry.appKitToCG(CGRect(x: 0, y: 0, width: 100, height: 50), primaryScreenHeight: 1080)
        assertRect(cg, CGRect(x: 0, y: 1030, width: 100, height: 50))
        let back = Geometry.cgToAppKit(cg, primaryScreenHeight: 1080)
        assertRect(back, CGRect(x: 0, y: 0, width: 100, height: 50))
    }

    func testFlipRectSecondaryScreenAbovePrimary() {
        // A screen above the primary has AppKit y >= 1080; in CG it has negative y.
        let appKit = CGRect(x: -200, y: 1080, width: 1440, height: 900)
        let cg = Geometry.appKitToCG(appKit, primaryScreenHeight: 1080)
        assertRect(cg, CGRect(x: -200, y: -900, width: 1440, height: 900))
    }

    func testFlipPoint() {
        let p = Geometry.cgToAppKit(CGPoint(x: 10, y: 0), primaryScreenHeight: 1080)
        XCTAssertEqual(p, CGPoint(x: 10, y: 1080))
        XCTAssertEqual(Geometry.appKitToCG(p, primaryScreenHeight: 1080), CGPoint(x: 10, y: 0))
    }
}
