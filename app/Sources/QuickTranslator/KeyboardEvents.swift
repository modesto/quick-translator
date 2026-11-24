import AppKit
import Carbon.HIToolbox

enum KeyboardEvents {
    static func pressCommand(_ keyCode: Int) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    static func copy() { pressCommand(kVK_ANSI_C) }
    static func paste() { pressCommand(kVK_ANSI_V) }
}

struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard = .general) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var entries: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { entries[type] = data }
            }
            return entries
        }
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let restored = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}
