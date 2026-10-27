import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let inverter = ScrollInverter()
    private let defaults = UserDefaults.standard
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["enabled": true])
        inverter.isEnabled = defaults.bool(forKey: "enabled")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "ScrollFix")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        registerLoginItemOnFirstLaunch()
        startWhenTrusted()
        updateIcon()
    }

    // Opens at login by default; the menu toggle can turn it off afterwards.
    private func registerLoginItemOnFirstLaunch() {
        guard !defaults.bool(forKey: "didRegisterLoginItem") else { return }
        try? SMAppService.mainApp.register()
        defaults.set(true, forKey: "didRegisterLoginItem")
    }

    private func startWhenTrusted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options), inverter.start() { return }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted(), self.inverter.start() else { return }
            timer.invalidate()
            self.updateIcon()
        }
    }

    private func updateIcon() {
        statusItem.button?.appearsDisabled = !inverter.isInverting
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let enabled = NSMenuItem(title: "Invert Mouse Scrolling", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.state = inverter.isEnabled ? .on : .off
        menu.addItem(enabled)

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        if !inverter.isRunning {
            menu.addItem(NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ScrollFix", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        updateIcon()
    }

    private func statusText() -> String {
        if !inverter.isRunning { return "Waiting for Accessibility permission" }
        if !inverter.isEnabled { return "Paused" }
        if !inverter.naturalScrolling { return "Natural scrolling is off: nothing to invert" }
        return "Mouse scrolling inverted"
    }

    @objc private func toggleEnabled() {
        inverter.isEnabled.toggle()
        defaults.set(inverter.isEnabled, forKey: "enabled")
        updateIcon()
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try? service.unregister()
        } else {
            try? service.register()
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
