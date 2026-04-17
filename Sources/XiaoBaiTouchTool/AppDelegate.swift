import AppKit
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    let store = MappingStore.shared
    let gestureMonitor = GestureMonitor()
    let executor = AppActionExecutor()
    var isEnabled = true
    var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        enableLoginItemIfFirstLaunch()
        setupStatusItem()
        setupGestureMonitor()
        checkAccessibilityPermission()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            // Try to load icon.png from bundle resources
            if let iconPath = Bundle.main.path(forResource: "icon", ofType: "png"),
               let iconImage = NSImage(contentsOfFile: iconPath) {
                // Resize to fit menu bar (typically 18x18 or 22x22)
                iconImage.size = NSSize(width: 25.2, height: 25.2)
                button.image = iconImage
            } else {
                // Fallback to system symbol
                button.image = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "XiaoBaiTouchTool")
            }
        }
        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        let statusTitle = isEnabled ? "已启用 ✓" : "已禁用"
        let item = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(
            title: isEnabled ? "禁用手势监听" : "启用手势监听",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let launchItem = NSMenuItem(
            title: "开机自启动",
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = isLoginItemEnabled ? .on : .off
        menu.addItem(launchItem)

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    @objc func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled {
            gestureMonitor.start()
        } else {
            gestureMonitor.stop()
        }
        updateMenu()
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(store: store)
            let hosting = NSHostingView(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "XiaoBaiTouchTool 设置"
            window.contentView = hosting
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupGestureMonitor() {
        gestureMonitor.onGesture = { [weak self] gesture in
            guard let self = self, self.isEnabled else { return }
            let matches = self.store.mappings.filter { $0.gesture == gesture }
            for mapping in matches {
                self.executor.execute(mapping: mapping)
            }
        }
    }

    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            gestureMonitor.start()
        } else {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.gestureMonitor.start()
                }
            }
        }
    }

    // MARK: - Login Item

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func enableLoginItemIfFirstLaunch() {
        let key = "hasSetupLoginItem"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            try? SMAppService.mainApp.register()
        }
    }

    @objc func toggleLoginItem() {
        if isLoginItemEnabled {
            try? SMAppService.mainApp.unregister()
        } else {
            try? SMAppService.mainApp.register()
        }
        updateMenu()
    }
}
