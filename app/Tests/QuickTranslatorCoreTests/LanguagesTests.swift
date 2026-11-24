import Testing
@testable import QuickTranslatorCore

@Suite("Languages")
struct LanguagesTests {
    @Test("Spanish goes to English and anything else to Spanish", arguments: [
        ("es", "en"),
        ("en", "es"),
        ("fr", "es"),
        ("de", "es"),
    ])
    func targetLanguage(source: String, target: String) {
        #expect(Languages.targetLanguageCode(forSource: source) == target)
    }

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
}
