import AppKit
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp`. No stored key: state comes from `status`.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers/unregisters the login item. Shows an NSAlert on failure.
    /// Returns the resulting enabled state.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                // Registered but blocked in System Settings: the toggle would silently
                // snap back off, so send the user to where they can allow it.
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = enabled ? "Couldn’t enable Start at Login" : "Couldn’t disable Start at Login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        return isEnabled
    }
}
