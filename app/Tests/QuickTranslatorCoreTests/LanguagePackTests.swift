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
        let alert = try #require(LanguagePackAdvice.needsDownload.alert(for: LanguagePair(mine: "es", target: "ja"), language: .es))
        #expect(alert.offersSettings)
        #expect(alert.message.contains("español"))
        #expect(alert.message.contains("japonés"))
        #expect(alert.message.contains("Idiomas de traducción"))
    }

    @Test("the unsupported alert does not offer the settings")
    func unsupportedAlert() throws {
        let alert = try #require(LanguagePackAdvice.unsupported.alert(for: LanguagePair(mine: "es", target: "vi"), language: .es))
        #expect(alert.offersSettings == false)
        #expect(alert.message.contains("vietnamita"))
    }

    @Test("opens Language & Region in System Settings")
    func settingsURL() {
        #expect(LanguagePackAdvice.settingsURL.absoluteString == "x-apple.systempreferences:com.apple.Localization-Settings.extension")
    }
}

@Suite("AppleTranslatorError")
struct AppleTranslatorErrorTests {
    @Test("a missing language offers the download and names both languages")
    func notInstalled() {
        let error = AppleTranslatorError.notInstalled(source: "es", target: "hi")
        #expect(error.offersLanguageDownload)
        #expect(error.errorDescription == "Falta descargar Español → Hindi para traducir en el Mac.")
    }

    @Test("text already in the one-off target says so and offers no download")
    func alreadyInTarget() {
        let error = AppleTranslatorError.alreadyInTarget("fr")
        #expect(error.message(in: .es) == "El texto ya está en francés.")
        #expect(error.offersLanguageDownload == false)
    }

    @Test("other failures do not offer the download")
    func otherErrors() {
        #expect(AppleTranslatorError.unknownLanguage.offersLanguageDownload == false)
        #expect(AppleTranslatorError.offersLanguageDownload(TranslatorError.serverStopped) == false)
        #expect(AppleTranslatorError.offersLanguageDownload(AppleTranslatorError.notInstalled(source: "es", target: "fr")))
    }
}
