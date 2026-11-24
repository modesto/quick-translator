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

    public func alert(for pair: LanguagePair) -> Alert? {
        let mine = Languages.displayName(forCode: pair.mine)
        let target = Languages.displayName(forCode: pair.target)
        switch self {
        case .ready:
            return nil
        case .needsDownload:
            return Alert(
                title: "Falta descargar un idioma",
                message: "Apple Translation necesita los idiomas \(mine) y \(target) descargados en el Mac. Hasta entonces solo traducirá Claude.\n\nEn Idioma y región, pulsa \"Idiomas de traducción…\" y descarga los que falten.",
                offersSettings: true
            )
        case .unsupported:
            return Alert(
                title: "Apple Translation no admite este par",
                message: "Apple Translation no traduce entre \(mine) y \(target). Para este par solo traducirá Claude.",
                offersSettings: false
            )
        }
    }
}

public enum AppleTranslatorError: LocalizedError, Equatable {
    case unknownLanguage
    case alreadyInTarget(String)
    case notInstalled(source: String, target: String)

    public var errorDescription: String? {
        switch self {
        case .unknownLanguage:
            return "No se ha podido detectar el idioma."
        case .alreadyInTarget(let code):
            return "El texto ya está en \(Languages.displayName(forCode: code))."
        case .notInstalled(let source, let target):
            let sourceName = Languages.displayName(forCode: source)
            let targetName = Languages.displayName(forCode: target)
            return "Falta descargar \(sourceName) → \(targetName) para traducir en el Mac."
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
