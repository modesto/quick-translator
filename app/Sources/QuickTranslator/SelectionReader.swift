import AppKit
import ApplicationServices
import QuickTranslatorCore

struct Selection {
    let text: String
    let screenRect: NSRect?
}

enum SelectionReader {
    static func read(completion: @escaping (Selection?) -> Void) {
        let element = focusedElement()
        let accessible = element.flatMap(readViaAccessibility)
        if let accessible, let element, !isWebContent(element) {
            completion(accessible)
            return
        }
        readViaCopy { copied in
            let text = SelectionText.best(
                accessibility: accessible?.text,
                clipboardHTML: copied?.html,
                clipboardPlain: copied?.plain
            )
            completion(text.map { Selection(text: $0, screenRect: accessible?.screenRect) })
        }
    }

    private static func isWebContent(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<40 {
            guard let node = current else { return false }
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(node, kAXRoleAttribute as CFString, &role) == .success,
               role as? String == "AXWebArea" {
                return true
            }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(node, kAXParentAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { return false }
            current = (parent as! AXUIElement)
        }
        return false
    }

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        return (focused as! AXUIElement)
    }

    private static func readViaAccessibility(_ element: AXUIElement) -> Selection? {
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

    private struct CopiedSelection {
        let plain: String?
        let html: String?
    }

    private static func readViaCopy(completion: @escaping (CopiedSelection?) -> Void) {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let initialChangeCount = pasteboard.changeCount
        KeyboardEvents.copy()

        let deadline = Date().addingTimeInterval(0.6)
        func poll() {
            if pasteboard.changeCount != initialChangeCount {
                let copied = CopiedSelection(plain: pasteboard.string(forType: .string), html: pasteboard.string(forType: .html))
                snapshot.restore(to: pasteboard)
                completion(copied)
            } else if Date() < deadline {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: poll)
            } else {
                completion(nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: poll)
    }
}
