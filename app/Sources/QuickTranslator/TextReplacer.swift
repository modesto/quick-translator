import AppKit

enum TextReplacer {
    static func replaceSelection(with text: String, in application: NSRunningApplication?) {
        if let application, application != NSWorkspace.shared.frontmostApplication {
            application.activate()
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            KeyboardEvents.paste()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                snapshot.restore(to: pasteboard)
            }
        }
    }
}
