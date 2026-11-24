import AppKit
import ApplicationServices
import QuickTranslatorCore

struct Selection {
    let text: String
    let screenRect: NSRect?
}

enum SelectionReader {
    static func read(completion: @escaping (Selection?) -> Void) {
        if let selection = readViaAccessibility() {
            completion(selection)
            return
        }
        readViaCopy(completion: completion)
    }

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        return (focused as! AXUIElement)
    }

    private static func readViaAccessibility() -> Selection? {
        guard let element = focusedElement() else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String, !text.isEmpty else { return nil }
        return Selection(text: text, screenRect: selectionRect(of: element))
    }

    private static func selectionRect(of element: AXUIElement) -> NSRect? {
        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
              let range else { return nil }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &boundsValue) == .success,
              let boundsValue, CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect), rect.width > 0 || rect.height > 0 else { return nil }
        return PopupPlacement.cocoaRect(fromAccessibility: rect, primaryScreenHeight: NSScreen.screens.first?.frame.height ?? 0)
    }

    private static func readViaCopy(completion: @escaping (Selection?) -> Void) {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let initialChangeCount = pasteboard.changeCount
        KeyboardEvents.copy()

        let deadline = Date().addingTimeInterval(0.6)
        func poll() {
            if pasteboard.changeCount != initialChangeCount {
                let text = pasteboard.string(forType: .string)
                snapshot.restore(to: pasteboard)
                completion(text.flatMap { $0.isEmpty ? nil : Selection(text: $0, screenRect: nil) })
            } else if Date() < deadline {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: poll)
            } else {
                completion(nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: poll)
    }
}
