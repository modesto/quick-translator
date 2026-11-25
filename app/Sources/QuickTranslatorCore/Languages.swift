import Foundation
import NaturalLanguage

public enum Languages {
    public static let supportedCodes = [
        "es", "en", "fr", "de", "it", "pt", "nl", "pl", "ru", "uk", "tr", "ar", "hi", "id", "ja", "ko", "th", "vi", "zh",
    ]

    public static func dominantLanguageCode(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage.map { Locale.Language(identifier: $0.rawValue).languageCode?.identifier ?? $0.rawValue }
    }

    public static func displayName(forCode code: String, in language: UILanguage = L10n.language) -> String {
        name(forCode: code, in: language).capitalized(with: language.locale)
    }

    public static func name(forCode code: String, in language: UILanguage = L10n.language) -> String {
        language.locale.localizedString(forLanguageCode: code) ?? code
    }

    public static func displayName(forEnglishName englishName: String, in language: UILanguage = L10n.language) -> String {
        let wanted = englishName.trimmingCharacters(in: .whitespaces).lowercased()
        guard let code = supportedCodes.first(where: { self.englishName(forCode: $0).lowercased() == wanted }) else { return englishName }
        return displayName(forCode: code, in: language)
    }

    public static func englishName(forCode code: String) -> String {
        Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
    }
}

public struct LanguagePair: Codable, Equatable, Sendable {
    public let mine: String
    public let target: String

    public static let `default` = LanguagePair(mine: "es", target: "en")

    public init(mine: String, target: String) {
        self.mine = mine
        self.target = target
    }

    public var isValid: Bool {
        mine != target && Languages.supportedCodes.contains(mine) && Languages.supportedCodes.contains(target)
    }

    public func targetCode(forSource source: String) -> String {
        source == mine ? target : mine
    }

    public func targetCode(forSource source: String, override: String?) -> String? {
        guard let override else { return targetCode(forSource: source) }
        return override == source ? nil : override
    }

    public func withMine(_ code: String) -> LanguagePair {
        code == target ? LanguagePair(mine: code, target: mine) : LanguagePair(mine: code, target: target)
    }

    public func withTarget(_ code: String) -> LanguagePair {
        code == mine ? LanguagePair(mine: target, target: code) : LanguagePair(mine: mine, target: code)
    }
}
