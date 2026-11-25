import Foundation

public enum LanguagePackStatus: Equatable, Sendable {
    case installed
    case downloadable
    case unsupported
}

public enum LanguagePackAdvice: Equatable, Sendable {
    case ready
    case needsDownload
    case unsupported

    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!

    public static func evaluate(_ statuses: [LanguagePackStatus]) -> LanguagePackAdvice {
        if statuses.contains(.unsupported) { return .unsupported }
        if statuses.contains(.downloadable) { return .needsDownload }
        return .ready
    }

    public struct Alert: Equatable, Sendable {
        public let title: String
        public let message: String
        public let offersSettings: Bool
    }

    public func alert(for pair: LanguagePair, language: UILanguage = L10n.language) -> Alert? {
        let strings = language.strings
        let mine = Languages.name(forCode: pair.mine, in: language)
        let target = Languages.name(forCode: pair.target, in: language)
        switch self {
        case .ready:
            return nil
        case .needsDownload:
            return Alert(
                title: strings.languageMissingTitle,
                message: strings.languageMissingMessage(mine, target),
                offersSettings: true
            )
        case .unsupported:
            return Alert(
                title: strings.pairUnsupportedTitle,
                message: strings.pairUnsupportedMessage(mine, target),
                offersSettings: false
            )
        }
    }
}

public enum AppleTranslatorError: LocalizedError, Equatable {
    case unknownLanguage
    case alreadyInTarget(String)
    case notInstalled(source: String, target: String)

    public var errorDescription: String? { message(in: L10n.language) }

    public func message(in language: UILanguage) -> String {
        let strings = language.strings
        switch self {
        case .unknownLanguage:
            return strings.unknownLanguage
        case .alreadyInTarget(let code):
            return strings.alreadyIn(Languages.name(forCode: code, in: language))
        case .notInstalled(let source, let target):
            return strings.notInstalled(Languages.displayName(forCode: source, in: language), Languages.displayName(forCode: target, in: language))
        }
    }

    public var offersLanguageDownload: Bool {
        if case .notInstalled = self { return true }
        return false
    }

    public static func offersLanguageDownload(_ error: Error) -> Bool {
        (error as? AppleTranslatorError)?.offersLanguageDownload ?? false
    }
}
