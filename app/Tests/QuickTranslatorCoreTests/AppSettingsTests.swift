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
}
