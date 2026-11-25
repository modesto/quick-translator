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

    @Test("uses Spanish → English until another pair is saved")
    func defaultLanguagePair() {
        #expect(AppSettings(defaults: Self.freshDefaults()).languagePair == .default)
    }

    @Test("remembers the language pair across instances")
    func persistsLanguagePair() {
        let defaults = Self.freshDefaults()
        AppSettings(defaults: defaults).languagePair = LanguagePair(mine: "es", target: "fr")
        #expect(AppSettings(defaults: defaults).languagePair == LanguagePair(mine: "es", target: "fr"))
    }

    @Test("falls back to the default pair when the saved one is corrupt or invalid")
    func ignoresBadLanguagePair() throws {
        let defaults = Self.freshDefaults()
        defaults.set(Data("{".utf8), forKey: AppSettings.languagePairKey)
        #expect(AppSettings(defaults: defaults).languagePair == .default)

        defaults.set(try JSONEncoder().encode(LanguagePair(mine: "es", target: "es")), forKey: AppSettings.languagePairKey)
        #expect(AppSettings(defaults: defaults).languagePair == .default)
    }

    @Test("uses Claude Code and Haiku 5.5 until something else is chosen")
    func providerDefaults() {
        let settings = AppSettings(defaults: Self.freshDefaults())
        #expect(settings.provider == .claudeCode)
        #expect(settings.claudeAPIModel == "claude-haiku-5-5")
        #expect(settings.openAIModel == "gpt-6-luna")
    }

    @Test("remembers the provider and the Claude API model")
    func persistsProvider() {
        let defaults = Self.freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.provider = .deepL
        settings.claudeAPIModel = "claude-sonnet-5-5"
        #expect(AppSettings(defaults: defaults).provider == .deepL)
        #expect(AppSettings(defaults: defaults).claudeAPIModel == "claude-sonnet-5-5")
    }

    @Test("remembers the OpenAI provider and model")
    func persistsOpenAI() {
        let defaults = Self.freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.provider = .openAI
        settings.openAIModel = "gpt-6.2-sol"
        #expect(AppSettings(defaults: defaults).provider == .openAI)
        #expect(AppSettings(defaults: defaults).openAIModel == "gpt-6.2-sol")
    }

    @Test("accepts any OpenAI-compatible model name, but not an empty one")
    func openAIModelIsFree() {
        let defaults = Self.freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.openAIModel = " llama3.2 "
        #expect(AppSettings(defaults: defaults).openAIModel == "llama3.2")
        settings.openAIModel = "  "
        #expect(AppSettings(defaults: defaults).openAIModel == "gpt-6-luna")
    }

    @Test("uses OpenAI's URL by default and when the field is left empty")
    func openAIBaseURL() {
        let defaults = Self.freshDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(settings.openAIBaseURL == "https://api.openai.com/v1")
        settings.openAIBaseURL = "http://localhost:11434/v1/"
        #expect(AppSettings(defaults: defaults).openAIBaseURL == "http://localhost:11434/v1")
        settings.openAIBaseURL = ""
        #expect(AppSettings(defaults: defaults).openAIBaseURL == "https://api.openai.com/v1")
        #expect(defaults.object(forKey: AppSettings.openAIBaseURLKey) == nil)
        defaults.set("ftp://x", forKey: AppSettings.openAIBaseURLKey)
        #expect(AppSettings(defaults: defaults).openAIBaseURL == "https://api.openai.com/v1")
    }

    @Test("ignores an unknown provider or model")
    func ignoresUnknownProvider() {
        let defaults = Self.freshDefaults()
        defaults.set("google", forKey: AppSettings.providerKey)
        defaults.set("gpt-5", forKey: AppSettings.claudeAPIModelKey)
        #expect(AppSettings(defaults: defaults).provider == .claudeCode)
        #expect(AppSettings(defaults: defaults).claudeAPIModel == "claude-haiku-5-5")
    }
}
