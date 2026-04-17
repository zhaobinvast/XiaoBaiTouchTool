import AppKit

// Use AppKit's NSApplicationMain directly via AppDelegate
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // No dock icon (LSUIElement behavior)
app.run()
