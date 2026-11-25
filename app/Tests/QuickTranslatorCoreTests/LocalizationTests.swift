import Foundation
import Testing
@testable import QuickTranslatorCore

@Suite("Localization")
struct LocalizationTests {
    @Test("shows the app in my language when it has a translation, else in English", arguments: [
        ("es", UILanguage.es), ("en", .en), ("fr", .fr), ("de", .de), ("it", .it), ("pt", .pt), ("ja", .en), ("zh", .en),
    ])
    func uiLanguage(code: String, expected: UILanguage) {
        #expect(UILanguage.forLanguage(code) == expected)
    }

    @Test("every language has every text", arguments: UILanguage.allCases)
    func complete(language: UILanguage) {
        for child in Mirror(reflecting: language.strings).children {
            if let text = child.value as? String {
                #expect(!text.isEmpty, "\(language) \(child.label ?? "")")
            }
        }
        let strings = language.strings
        #expect(strings.translateWith("DeepL").contains("DeepL"))
        #expect(strings.providerFailed("OpenAI", "boom").contains("boom"))
        #expect(strings.languageMissingMessage("A1", "B2").contains("A1"))
        #expect(strings.languageMissingMessage("A1", "B2").contains("B2"))
        #expect(strings.notInstalled("A1", "B2").contains("B2"))
    }

    @Test("each language is actually translated", arguments: UILanguage.allCases.filter { $0 != .es })
    func translated(language: UILanguage) {
        let strings = language.strings
        let spanish = UIStrings.es
        #expect(strings.translateSelection != spanish.translateSelection)
        #expect(strings.languagesFooter != spanish.languagesFooter)
        #expect(strings.testSentence != spanish.testSentence)
    }

    @Test("names languages in the app language", arguments: [
        (UILanguage.es, "Inglés"), (.en, "English"), (.fr, "Anglais"), (.de, "Englisch"), (.it, "Inglese"), (.pt, "Inglês"),
    ])
    func languageNames(language: UILanguage, name: String) {
        #expect(Languages.displayName(forCode: "en", in: language) == name)
    }

    @Test("turns the English names Claude returns into the app language")
    func fromEnglishName() {
        #expect(Languages.displayName(forEnglishName: "Spanish", in: .en) == "Spanish")
        #expect(Languages.displayName(forEnglishName: "spanish", in: .fr) == "Espagnol")
        #expect(Languages.displayName(forEnglishName: "Klingon", in: .es) == "Klingon")
    }

    @Test("formats times with the app language's decimal separator")
    func elapsed() {
        #expect(Elapsed.format(0.42, in: .es) == "0,4 s")
        #expect(Elapsed.format(0.42, in: .en) == "0.4 s")
    }

    @Test("explains provider errors in the app language")
    func providerErrors() {
        #expect(ProviderErrorCode.missingKey.message(provider: .deepL, detail: "", in: .en) == "The DeepL key is missing. Add it in Settings.")
        #expect(TranslatorError.serverStopped.message(in: .fr) == "Le processus de traduction s’est arrêté. Réessayez.")
        #expect(AppleTranslatorError.alreadyInTarget("en").message(in: .en) == "The text is already in English.")
        #expect(ShortcutChangeError.unavailable("⌥⌘T").message(in: .de).hasPrefix("⌥⌘T ist nicht verfügbar"))
    }

    @Test("writes the language pack alert in the app language, with language names mid-sentence")
    func languagePackAlert() {
        let alert = LanguagePackAdvice.unsupported.alert(for: LanguagePair(mine: "es", target: "fr"), language: .en)
        #expect(alert?.title == "Apple Translation doesn’t support this pair")
        #expect(alert?.message.contains("between Spanish and French") == true)
        let spanish = LanguagePackAdvice.needsDownload.alert(for: LanguagePair(mine: "es", target: "fr"), language: .es)
        #expect(spanish?.message.contains("los idiomas español y francés") == true)
    }

    @Test("translates the Edit menu and the model notes")
    func menusAndNotes() {
        #expect(EditMenu.title(in: .en) == "Edit")
        #expect(EditMenu.sections(in: .en).flatMap { $0 }.first { $0.action == "paste:" }?.title == "Paste")
        #expect(ModelOption.claude[0].kind.text(in: .en) == "fastest")
        #expect(ModelOption.openAI[0].kind.text(in: .es) == "la más rápida y barata")
    }
}
