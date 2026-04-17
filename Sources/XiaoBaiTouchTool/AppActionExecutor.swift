import Foundation
import AppKit
import CoreServices

class AppActionExecutor {
    func execute(mapping: GestureMapping) {
        if mapping.action.isSystemAction {
            executeSystem(action: mapping.action)
        } else {
            executeApp(mapping: mapping)
        }
    }

    // MARK: - App actions

    private func executeApp(mapping: GestureMapping) {
        let bundleID = mapping.appBundleID
        switch mapping.action {
        case .openOrActivate:
            openOrActivate(bundleID: bundleID, appPath: mapping.appPath)
        case .hide:
            hide(bundleID: bundleID)
        case .toggle:
            toggle(bundleID: bundleID, appPath: mapping.appPath)
        default:
            break
        }
    }

    private func runningApp(bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
    }

    private func openOrActivate(bundleID: String, appPath: String) {
        if let app = runningApp(bundleID: bundleID) {
            app.activate(options: .activateIgnoringOtherApps)
            if app.isHidden { app.unhide() }
        } else {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: appPath),
                configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }

    private func hide(bundleID: String) {
        runningApp(bundleID: bundleID)?.hide()
    }

    private func toggle(bundleID: String, appPath: String) {
        if let app = runningApp(bundleID: bundleID) {
            if app.isHidden || !app.isActive {
                app.unhide()
                app.activate(options: .activateIgnoringOtherApps)
            } else {
                app.hide()
            }
        } else {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: appPath),
                configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }

    // MARK: - System actions

    private func executeSystem(action: AppAction) {
        switch action {
        case .lockScreen:
            lockScreen()
        case .sleep:
            sendAppleScript("tell application \"System Events\" to sleep")
        case .shutdown:
            sendAppleScript("tell application \"System Events\" to shut down")
        case .restart:
            sendAppleScript("tell application \"System Events\" to restart")
        case .eject:
            sendAppleScript("""
                tell application "Finder"
                    eject (every disk whose ejectable is true)
                end tell
                """)
        case .showDesktop:
            sendKeyEvent(keyCode: 103, flags: [])  // F11 / Show Desktop
        case .showLaunchpad:
            sendKeyEvent(keyCode: 131, flags: [])  // F4 / Launchpad
        case .missionControl:
            sendKeyEvent(keyCode: 160, flags: [])  // F3 / Mission Control
        case .screenshot:
            sendKeyEvent(keyCode: 20, flags: [.maskShift, .maskCommand])  // Cmd+Shift+3
        case .screenshotArea:
            sendKeyEvent(keyCode: 21, flags: [.maskShift, .maskCommand])  // Cmd+Shift+4
        case .screenshotWindow:
            sendKeyEvent(keyCode: 21, flags: [.maskShift, .maskCommand, .maskAlternate])
        case .screenBrightnessUp:
            sendMediaKey(keyCode: NX_KEYTYPE_BRIGHTNESS_UP)
        case .screenBrightnessDown:
            sendMediaKey(keyCode: NX_KEYTYPE_BRIGHTNESS_DOWN)
        case .volumeUp:
            sendMediaKey(keyCode: NX_KEYTYPE_SOUND_UP)
        case .volumeDown:
            sendMediaKey(keyCode: NX_KEYTYPE_SOUND_DOWN)
        case .volumeMute:
            sendMediaKey(keyCode: NX_KEYTYPE_MUTE)
        case .mediaPlayPause:
            sendMediaKey(keyCode: NX_KEYTYPE_PLAY)
        case .mediaNext:
            sendMediaKey(keyCode: NX_KEYTYPE_NEXT)
        case .mediaPrevious:
            sendMediaKey(keyCode: NX_KEYTYPE_PREVIOUS)
        default:
            break
        }
    }

    private func lockScreen() {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["displaysleepnow"]
        try? task.run()
    }

    private func sendAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }

    private func sendKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags   = flags
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }

    private func sendMediaKey(keyCode: Int32) {
        func event(down: Bool) -> CGEvent? {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((keyCode << 16) | (down ? 0xa00 : 0xb00))
            return CGEvent(source: nil).flatMap { _ in
                NSEvent.otherEvent(
                    with: .systemDefined,
                    location: .zero,
                    modifierFlags: flags,
                    timestamp: 0,
                    windowNumber: 0,
                    context: nil,
                    subtype: 8,
                    data1: data1,
                    data2: -1
                )?.cgEvent
            }
        }
        event(down: true)?.post(tap: .cgSessionEventTap)
        event(down: false)?.post(tap: .cgSessionEventTap)
    }
}
