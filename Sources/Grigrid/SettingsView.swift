import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Stepper(value: $settings.columns, in: Settings.columnsRange) {
                Text("Columns: \(settings.columns)")
            }
            Stepper(value: $settings.rows, in: Settings.rowsRange) {
                Text("Rows: \(settings.rows)")
            }
            Stepper(value: $settings.gap, in: Settings.gapRange) {
                Text("Gap: \(settings.gap) pt")
            }
            Toggle("Start at login", isOn: Binding(
                get: { launchAtLogin },
                set: { launchAtLogin = LaunchAtLogin.setEnabled($0) }
            ))
        }
        .padding(20)
        .frame(width: 280)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

/// Owns the single settings window; reuses it if already open.
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: .shared))
            let w = NSWindow(contentViewController: hosting)
            w.title = "Grigrid Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
