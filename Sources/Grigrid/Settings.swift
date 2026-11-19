import Foundation
import Combine

/// UserDefaults-backed settings. Values are clamped and persisted on every change.
/// Read synchronously (e.g. `Settings.shared.columns`) at gesture start.
final class Settings: ObservableObject {
    static let shared = Settings()

    enum Key {
        static let columns = "columns"
        static let rows = "rows"
        static let gap = "gap"
    }

    static let columnsRange = 1...24
    static let rowsRange = 1...24
    static let gapRange = 0...64

    private let defaults: UserDefaults

    // Computed properties with explicit objectWillChange instead of `@Published` +
    // `didSet`: clamping by assigning inside a @Published property's didSet re-enters
    // the observer and recursed until the stack overflowed.
    private var storedColumns: Int
    private var storedRows: Int
    private var storedGap: Int

    var columns: Int {
        get { storedColumns }
        set { set(&storedColumns, newValue, Self.columnsRange, Key.columns) }
    }
    var rows: Int {
        get { storedRows }
        set { set(&storedRows, newValue, Self.rowsRange, Key.rows) }
    }
    var gap: Int {
        get { storedGap }
        set { set(&storedGap, newValue, Self.gapRange, Key.gap) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.columns: 6, Key.rows: 4, Key.gap: 0])
        storedColumns = Self.clamp(defaults.integer(forKey: Key.columns), Self.columnsRange)
        storedRows = Self.clamp(defaults.integer(forKey: Key.rows), Self.rowsRange)
        storedGap = Self.clamp(defaults.integer(forKey: Key.gap), Self.gapRange)
    }

    private func set(_ storage: inout Int, _ value: Int, _ range: ClosedRange<Int>, _ key: String) {
        let clamped = Self.clamp(value, range)
        objectWillChange.send()
        storage = clamped
        defaults.set(clamped, forKey: key)
    }

    private static func clamp(_ v: Int, _ r: ClosedRange<Int>) -> Int {
        min(max(v, r.lowerBound), r.upperBound)
    }
}
