import Testing
@testable import QuickTranslatorCore

@Suite("EditMenu")
struct EditMenuTests {
    private var items: [MenuItemSpec] { EditMenu.sections(in: .es).flatMap { $0 } }

    @Test("gives text fields the standard editing shortcuts", arguments: [
        ("paste:", "v"), ("copy:", "c"), ("cut:", "x"), ("selectAll:", "a"), ("undo:", "z"),
    ])
    func standardShortcut(action: String, key: String) {
        let item = items.first { $0.action == action }
        #expect(item?.key == key)
        #expect(item?.modifiers == [.command])
    }

    @Test("redo is ⇧⌘Z")
    func redo() {
        #expect(items.first { $0.action == "redo:" }?.modifiers == [.command, .shift])
    }

    @Test("never repeats a shortcut")
    func uniqueShortcuts() {
        let shortcuts = items.map { "\($0.modifiers)\($0.key)" }
        #expect(Set(shortcuts).count == shortcuts.count)
    }
}
