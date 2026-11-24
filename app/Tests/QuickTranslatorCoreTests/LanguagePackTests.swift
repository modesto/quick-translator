import Testing
@testable import QuickTranslatorCore

@Suite("LanguagePackAdvice")
struct LanguagePackAdviceTests {
    @Test("needs nothing when both directions are installed")
    func ready() {
        #expect(LanguagePackAdvice.evaluate([.installed, .installed]) == .ready)
        #expect(LanguagePackAdvice.ready.alert(for: .default) == nil)
    }

    @Test("asks to download when any direction is missing", arguments: [
        [LanguagePackStatus.downloadable, .installed],
        [.installed, .downloadable],
        [.downloadable, .downloadable],
    ])
    func needsDownload(statuses: [LanguagePackStatus]) {
        #expect(LanguagePackAdvice.evaluate(statuses) == .needsDownload)
    }

    @Test("reports an unsupported pair even if the other direction could be downloaded", arguments: [
        [LanguagePackStatus.unsupported, .installed],
        [.downloadable, .unsupported],
    ])
    func unsupported(statuses: [LanguagePackStatus]) {
        #expect(LanguagePackAdvice.evaluate(statuses) == .unsupported)
    }

    @Test("the download alert names both languages and offers the settings")
    func downloadAlert() throws {
        let alert = try #require(LanguagePackAdvice.needsDownload.alert(for: LanguagePair(mine: "es", target: "ja")))
        #expect(alert.offersSettings)
        #expect(alert.message.contains("Español"))
        #expect(alert.message.contains("Japonés"))
        #expect(alert.message.contains("Idiomas de traducción"))
    }

    @Test("the unsupported alert does not offer the settings")
    func unsupportedAlert() throws {
        let alert = try #require(LanguagePackAdvice.unsupported.alert(for: LanguagePair(mine: "es", target: "vi")))
        #expect(alert.offersSettings == false)
        #expect(alert.message.contains("Vietnamita"))
    }

    @Test("opens Language & Region in System Settings")
    func settingsURL() {
        #expect(LanguagePackAdvice.settingsURL.absoluteString == "x-apple.systempreferences:com.apple.Localization-Settings.extension")
    }
}
