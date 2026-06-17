import AppKit

let application = NSApplication.shared
let delegate = DockWindowPreviewApp()
application.delegate = delegate
application.run()
