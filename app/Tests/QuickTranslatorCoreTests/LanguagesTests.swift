import Testing
@testable import QuickTranslatorCore

@Suite("Languages")
struct LanguagesTests {
    @Test("detects the language of common sentences", arguments: [
        ("Oye, ¿te viene bien que lo veamos mañana a primera hora?", "es"),
        ("Please send me the report by Friday.", "en"),
        ("Merci beaucoup pour votre aide, à demain.", "fr"),
    ])
    func detectsLanguage(text: String, code: String) {
        #expect(Languages.dominantLanguageCode(of: text) == code)
    }

    @Test("detects nothing in text without words")
    func nothingToDetect() {
        #expect(Languages.dominantLanguageCode(of: "") == nil)
    }

    @Test("names languages in Spanish", arguments: [("es", "Español"), ("en", "Inglés"), ("fr", "Francés")])
    func displayName(code: String, name: String) {
        #expect(Languages.displayName(forCode: code) == name)
    }

    @Test("names languages in English for Claude", arguments: [("es", "Spanish"), ("en", "English"), ("fr", "French"), ("zh", "Chinese")])
    func englishName(code: String, name: String) {
        #expect(Languages.englishName(forCode: code) == name)
    }

    @Test("every supported language has a Spanish and an English name")
    func supportedLanguagesHaveNames() {
        for code in Languages.supportedCodes {
            #expect(Languages.displayName(forCode: code) != code)
            #expect(Languages.englishName(forCode: code) != code)
        }
        #expect(Set(Languages.supportedCodes).count == Languages.supportedCodes.count)
    }
}

@Suite("LanguagePair")
struct LanguagePairTests {
    @Test("defaults to Spanish as your language and English as the target")
    func defaultPair() {
        #expect(LanguagePair.default == LanguagePair(mine: "es", target: "en"))
    }

    @Test("sends your language to the target and every other language to yours", arguments: [
        ("es", "fr"),
        ("fr", "es"),
        ("en", "es"),
        ("de", "es"),
    ])
    func targetCode(source: String, target: String) {
        #expect(LanguagePair(mine: "es", target: "fr").targetCode(forSource: source) == target)
    }

    @Test("a one-off target replaces the pair rule", arguments: [
        ("es", "fr", "fr"),
        ("en", "fr", "fr"),
        ("de", "ja", "ja"),
    ])
    func overrideTarget(source: String, override: String, target: String) {
        #expect(LanguagePair.default.targetCode(forSource: source, override: override) == target)
    }

    @Test("a one-off target equal to the text's language has nothing to translate")
    func overrideSameLanguage() {
        #expect(LanguagePair.default.targetCode(forSource: "fr", override: "fr") == nil)
    }

    @Test("without a one-off target the pair rule applies")
    func noOverride() {
        #expect(LanguagePair.default.targetCode(forSource: "es", override: nil) == "en")
        #expect(LanguagePair.default.targetCode(forSource: "fr", override: nil) == "es")
    }

    @Test("changing one side keeps the other")
    func changeOneSide() {
        let pair = LanguagePair(mine: "es", target: "en")
        #expect(pair.withTarget("fr") == LanguagePair(mine: "es", target: "fr"))
        #expect(pair.withMine("ca") == LanguagePair(mine: "ca", target: "en"))
    }

    @Test("choosing the other side's language swaps them")
    func swaps() {
        let pair = LanguagePair(mine: "es", target: "en")
        #expect(pair.withTarget("es") == LanguagePair(mine: "en", target: "es"))
        #expect(pair.withMine("en") == LanguagePair(mine: "en", target: "es"))
    }

    @Test("is valid only with two different supported languages", arguments: [
        (LanguagePair(mine: "es", target: "en"), true),
        (LanguagePair(mine: "es", target: "es"), false),
        (LanguagePair(mine: "es", target: "xx"), false),
        (LanguagePair(mine: "", target: "en"), false),
    ])
    func validity(pair: LanguagePair, valid: Bool) {
        #expect(pair.isValid == valid)
    }
}
