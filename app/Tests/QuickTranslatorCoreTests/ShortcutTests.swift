import Carbon.HIToolbox
import Foundation
import Testing
@testable import QuickTranslatorCore

@Suite("Shortcut")
struct ShortcutTests {
    @Test("the default is ⌥⌘T")
    func defaultShortcut() {
        #expect(Shortcut.default.displayString == "⌥⌘T")
        #expect(Shortcut.default.keyCode == UInt32(kVK_ANSI_T))
    }

    @Test("lists modifiers in the macOS order ⌃⌥⇧⌘")
    func modifierOrder() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: [.command, .shift, .option, .control], key: "K")
        #expect(shortcut.displayString == "⌃⌥⇧⌘K")
    }

    @Test("converts modifiers to Carbon flags")
    func carbonModifiers() {
        #expect(Shortcut.default.carbonModifiers == UInt32(cmdKey | optionKey))
        let all = Shortcut(keyCode: 0, modifiers: [.command, .option, .control, .shift], key: "A")
        #expect(all.carbonModifiers == UInt32(cmdKey | optionKey | controlKey | shiftKey))
    }

    @Test("labels keys from the typed character or a fixed name", arguments: [
        (UInt32(kVK_ANSI_T), "t", "T"),
        (UInt32(kVK_ANSI_Semicolon), "ñ", "Ñ"),
        (UInt32(kVK_Space), " ", "Espacio"),
        (UInt32(kVK_Return), "\r", "↩"),
        (UInt32(kVK_F5), "", "F5"),
        (UInt32(kVK_LeftArrow), "", "←"),
        (UInt32(200), nil, "#200"),
    ])
    func keyLabels(keyCode: UInt32, characters: String?, label: String) {
        #expect(Shortcut.keyLabel(keyCode: keyCode, characters: characters) == label)
    }

    @Test("gives a menu key equivalent only for single characters")
    func menuKeyEquivalent() {
        #expect(Shortcut.default.menuKeyEquivalent == "t")
        #expect(Shortcut(keyCode: UInt32(kVK_F5), modifiers: [.command], characters: "").menuKeyEquivalent == nil)
        #expect(Shortcut(keyCode: UInt32(kVK_Space), modifiers: [.option], characters: " ").menuKeyEquivalent == nil)
    }

    @Test("round-trips through JSON")
    func codable() throws {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_L), modifiers: [.control, .option], key: "L")
        let decoded = try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(shortcut))
        #expect(decoded == shortcut)
    }
}

@Suite("ShortcutValidator")
struct ShortcutValidatorTests {
    @Test("accepts shortcuts with ⌘, ⌥ or ⌃", arguments: [
        Shortcut.default,
        Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: [.control, .option], key: "T"),
        Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: [.command, .shift], key: "T"),
        Shortcut(keyCode: UInt32(kVK_F5), modifiers: [.option], key: "F5"),
        Shortcut(keyCode: UInt32(kVK_ANSI_Q), modifiers: [.command, .option], key: "Q"),
    ])
    func accepts(shortcut: Shortcut) {
        #expect(ShortcutValidator.validate(shortcut) == .success(shortcut))
    }

    @Test("rejects keys without ⌘, ⌥ or ⌃", arguments: [
        Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: [], key: "T"),
        Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: [.shift], key: "T"),
    ])
    func needsModifier(shortcut: Shortcut) {
        #expect(ShortcutValidator.validate(shortcut) == .failure(.needsModifier))
    }

    @Test("rejects common ⌘ shortcuts", arguments: [kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_Z, kVK_Space, kVK_Tab])
    func reserved(keyCode: Int) {
        let shortcut = Shortcut(keyCode: UInt32(keyCode), modifiers: [.command], characters: "x")
        #expect(ShortcutValidator.validate(shortcut) == .failure(.reserved(shortcut.displayString)))
    }
}

private final class FakeHotKey: HotKeyRegistering {
    var unavailable: Set<String> = []
    private(set) var registered: Shortcut?
    private(set) var registrations: [Shortcut] = []

    func register(_ shortcut: Shortcut) -> Bool {
        registrations.append(shortcut)
        guard !unavailable.contains(shortcut.displayString) else {
            registered = nil
            return false
        }
        registered = shortcut
        return true
    }

    func unregister() {
        registered = nil
    }
}

@Suite("ShortcutManager")
struct ShortcutManagerTests {
    private static func freshSettings() -> AppSettings {
        let name = "QuickTranslatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AppSettings(defaults: defaults)
    }

    private static let controlOptionL = Shortcut(keyCode: UInt32(kVK_ANSI_L), modifiers: [.control, .option], key: "L")

    @Test("registers the saved shortcut on activation")
    func activatesSavedShortcut() {
        let settings = Self.freshSettings()
        settings.shortcut = Self.controlOptionL
        let hotKey = FakeHotKey()
        let manager = ShortcutManager(settings: settings, hotKey: hotKey)

        #expect(manager.activate())
        #expect(hotKey.registered == Self.controlOptionL)
        #expect(manager.isActive)
    }

    @Test("reports when the shortcut cannot be registered at launch")
    func activationFails() {
        let hotKey = FakeHotKey()
        hotKey.unavailable = ["⌥⌘T"]
        let manager = ShortcutManager(settings: Self.freshSettings(), hotKey: hotKey)

        #expect(manager.activate() == false)
        #expect(manager.isActive == false)
    }

    @Test("registers, saves and reports a new shortcut")
    func changes() {
        let settings = Self.freshSettings()
        let hotKey = FakeHotKey()
        let manager = ShortcutManager(settings: settings, hotKey: hotKey)
        manager.activate()

        #expect(manager.change(to: Self.controlOptionL) == .success(Self.controlOptionL))
        #expect(manager.current == Self.controlOptionL)
        #expect(hotKey.registered == Self.controlOptionL)
        #expect(settings.shortcut == Self.controlOptionL)
    }

    @Test("rejects an invalid shortcut without touching the registered one")
    func rejectsInvalid() {
        let settings = Self.freshSettings()
        let hotKey = FakeHotKey()
        let manager = ShortcutManager(settings: settings, hotKey: hotKey)
        manager.activate()
        let plainT = Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: [], key: "T")

        #expect(manager.change(to: plainT) == .failure(.invalid(.needsModifier)))
        #expect(hotKey.registrations == [.default])
        #expect(manager.current == .default)
        #expect(settings.shortcut == .default)
    }

    @Test("keeps the previous shortcut when the system refuses the new one")
    func fallsBackWhenUnavailable() {
        let settings = Self.freshSettings()
        let hotKey = FakeHotKey()
        hotKey.unavailable = ["⌃⌥L"]
        let manager = ShortcutManager(settings: settings, hotKey: hotKey)
        manager.activate()

        #expect(manager.change(to: Self.controlOptionL) == .failure(.unavailable("⌃⌥L")))
        #expect(hotKey.registered == .default)
        #expect(manager.current == .default)
        #expect(manager.isActive)
        #expect(settings.shortcut == .default)
    }

    @Test("pausing frees the shortcut so it can be recorded")
    func pause() {
        let hotKey = FakeHotKey()
        let manager = ShortcutManager(settings: Self.freshSettings(), hotKey: hotKey)
        manager.activate()

        manager.pause()
        #expect(hotKey.registered == nil)
        #expect(manager.isActive == false)
    }

    @Test("reset goes back to ⌥⌘T")
    func reset() {
        let settings = Self.freshSettings()
        settings.shortcut = Self.controlOptionL
        let hotKey = FakeHotKey()
        let manager = ShortcutManager(settings: settings, hotKey: hotKey)
        manager.activate()

        #expect(manager.reset() == .success(.default))
        #expect(settings.shortcut == .default)
        #expect(hotKey.registered == .default)
    }
}
