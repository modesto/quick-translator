import Foundation
import Testing
@testable import QuickTranslatorCore

@Suite("AppSettings")
struct AppSettingsTests {
    private static func freshDefaults() -> UserDefaults {
        let name = "QuickTranslatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("translates with Claude automatically by default")
    func defaultsToAutomatic() {
        #expect(AppSettings(defaults: Self.freshDefaults()).automaticClaude)
    }

    @Test("remembers the choice across instances")
    func persists() {
        let defaults = Self.freshDefaults()
        AppSettings(defaults: defaults).automaticClaude = false
        #expect(AppSettings(defaults: defaults).automaticClaude == false)

        AppSettings(defaults: defaults).automaticClaude = true
        #expect(AppSettings(defaults: defaults).automaticClaude)
    }

    @Test("uses ⌥⌘T until another shortcut is saved")
    func defaultShortcut() {
        #expect(AppSettings(defaults: Self.freshDefaults()).shortcut == .default)
    }

    @Test("remembers the shortcut across instances")
    func persistsShortcut() {
        let defaults = Self.freshDefaults()
        let shortcut = Shortcut(keyCode: 37, modifiers: [.control, .option], key: "L")
        AppSettings(defaults: defaults).shortcut = shortcut
        #expect(AppSettings(defaults: defaults).shortcut == shortcut)
    }

    @Test("falls back to ⌥⌘T when the saved shortcut is corrupt or invalid")
    func ignoresBadShortcut() throws {
        let defaults = Self.freshDefaults()
        defaults.set(Data("not json".utf8), forKey: AppSettings.shortcutKey)
        #expect(AppSettings(defaults: defaults).shortcut == .default)

        let invalid = Shortcut(keyCode: 17, modifiers: [], key: "T")
        defaults.set(try JSONEncoder().encode(invalid), forKey: AppSettings.shortcutKey)
        #expect(AppSettings(defaults: defaults).shortcut == .default)
    }
}
