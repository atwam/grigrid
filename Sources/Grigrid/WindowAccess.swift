import ApplicationServices
import AppKit

/// Accessibility helpers: hit-testing, title-bar detection, window frame get/set.
/// All frames/points here are in CG/AX coordinates (top-left origin of the primary display).
enum WindowAccess {
    private static let systemWide = AXUIElementCreateSystemWide()

    /// Height of the region at the top of a window treated as its title bar.
    static let titleBarHeight: CGFloat = 40

    /// Roles of controls that live in title bars/toolbars and must keep working normally.
    private static let controlRoles: Set<String> = [
        kAXButtonRole, kAXTextFieldRole, "AXSearchField", kAXPopUpButtonRole,
        kAXMenuButtonRole, kAXCheckBoxRole, kAXSliderRole, kAXComboBoxRole,
    ]

    private static let ownPid = getpid()

    /// Sets a global (system-wide) AX messaging timeout so a hung app cannot
    /// stall the event tap callback. Call once before using the other helpers.
    static func configure() {
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
    }

    /// Returns the movable window whose title bar is under `point` (CG coords),
    /// or nil if the point is not on a title bar (or is on a title-bar control).
    static func titleBarWindow(at point: CGPoint) -> AXUIElement? {
        var hitRef: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hitRef) == .success,
              let hit = hitRef else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(hit, &pid) == .success, pid != ownPid else { return nil }

        let hitRole = role(of: hit)
        if let r = hitRole, controlRoles.contains(r) { return nil }

        guard let window = enclosingWindow(of: hit, hitRole: hitRole),
              let frame = frame(of: window) else { return nil }

        let inTitleBar = point.x >= frame.minX && point.x <= frame.maxX
            && point.y >= frame.minY && point.y <= frame.minY + titleBarHeight
        guard inTitleBar else { return nil }

        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &settable) == .success,
              settable.boolValue else { return nil }
        return window
    }

    /// The window's frame in CG/AX coordinates.
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let posValue = axValue(window, kAXPositionAttribute),
              let sizeValue = axValue(window, kAXSizeAttribute) else { return nil }
        var pos = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(posValue, .cgPoint, &pos),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: pos, size: size)
    }

    /// Sets the window frame (CG/AX coordinates): position, size, then position again,
    /// because some apps clamp the size against the current position.
    static func setFrame(_ rect: CGRect, of window: AXUIElement) {
        var pos = rect.origin
        var size = rect.size
        guard let posValue = AXValueCreate(.cgPoint, &pos),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
    }

    // MARK: - Private

    private static func enclosingWindow(of element: AXUIElement, hitRole: String?) -> AXUIElement? {
        if hitRole == kAXWindowRole { return element }
        if let w = elementAttribute(element, kAXWindowAttribute), role(of: w) == kAXWindowRole { return w }
        var current = element
        for _ in 0..<32 {
            guard let parent = elementAttribute(current, kAXParentAttribute) else { return nil }
            let r = role(of: parent)
            if r == kAXWindowRole { return parent }
            if r == kAXApplicationRole { return nil }
            current = parent
        }
        return nil
    }

    private static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(v, to: AXUIElement.self)
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        return unsafeBitCast(v, to: AXValue.self)
    }
}
