import CoreGraphics
import Foundation

/// Thin wrapper around an active `CGEventTap` on the main run loop.
///
/// The handler runs synchronously on the main thread for every tapped event and
/// returns `true` to swallow the event or `false` to pass it through unchanged.
/// It must be fast: the system disables slow taps (`tapDisabledByTimeout`).
final class EventTap {
    typealias Handler = (CGEventType, CGEvent) -> Bool

    private let handler: Handler
    /// Called (on main) after the tap was disabled by the system and re-enabled.
    /// Events may have been missed while it was off, so callers should reconcile state.
    var onReenabled: (() -> Void)?

    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    deinit { stop() }

    static let eventMask: CGEventMask = {
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .keyDown,
        ]
        return types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    }()

    /// Creates the tap and adds it to the main run loop. Returns false if the
    /// tap could not be created (usually: Accessibility permission not effective yet).
    @discardableResult
    func start() -> Bool {
        if port != nil { return true }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
            return tap.handle(type: type, event: event)
        }

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        return true
    }

    func stop() {
        if let port = port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source = source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        port = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port = port {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            NSLog("Grigrid: event tap was disabled (%@), re-enabled",
                  type == .tapDisabledByTimeout ? "timeout" : "user input")
            onReenabled?()
            return Unmanaged.passUnretained(event)
        default:
            return handler(type, event) ? nil : Unmanaged.passUnretained(event)
        }
    }
}
