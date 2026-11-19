import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let accessibilityItem = NSMenuItem()
    private let settingsWindow = SettingsWindowController()
    private var trustTimer: Timer?
    private var gestureEngineStarted = false
    private lazy var gestureController = GestureController()
    private let gestureStatusItem = NSMenuItem()
    private var tapFailureLogged = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        refreshTrust()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshTrust()
        }
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "Grigrid")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        gestureStatusItem.title = "Gesture unavailable: event tap could not be created"
        gestureStatusItem.isEnabled = false
        gestureStatusItem.isHidden = true
        menu.addItem(gestureStatusItem)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Grigrid", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshTrust()
    }

    // MARK: - Accessibility permission

    private func refreshTrust() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            accessibilityItem.title = "Accessibility: granted"
            accessibilityItem.action = nil
            accessibilityItem.isEnabled = false
            if !gestureEngineStarted {
                // Retried on every trust poll until the tap is created.
                gestureEngineStarted = startGestureEngine()
            }
        } else {
            accessibilityItem.title = "Grant Accessibility Access…"
            accessibilityItem.action = #selector(requestAccessibility)
            accessibilityItem.isEnabled = true
        }
    }

    @objc private func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Gesture engine

    /// Called on the main thread when Accessibility trust is observed, until it succeeds.
    /// Installs the event tap. Tap creation can fail right after trust is granted;
    /// the 2 s trust poll retries, and the menu shows the failure meanwhile.
    private func startGestureEngine() -> Bool {
        let ok = gestureController.start()
        gestureStatusItem.isHidden = ok
        if !ok && !tapFailureLogged {
            tapFailureLogged = true
            NSLog("Grigrid: failed to create the event tap; will retry")
        }
        return ok
    }

    // MARK: - Actions

    @objc private func openSettings() {
        settingsWindow.show()
    }
}
