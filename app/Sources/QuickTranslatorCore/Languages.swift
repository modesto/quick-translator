import Foundation
import NaturalLanguage

public enum Languages {
    public static func dominantLanguageCode(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage.map { Locale.Language(identifier: $0.rawValue).languageCode?.identifier ?? $0.rawValue }
    }

    public static func targetLanguageCode(forSource source: String) -> String {
        source == "es" ? "en" : "es"
    }

    public static func displayName(forCode code: String) -> String {
        Locale(identifier: "es").localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}
