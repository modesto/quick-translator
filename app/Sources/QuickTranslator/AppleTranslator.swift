import Foundation
import NaturalLanguage
import Translation

struct AppleTranslation {
    let text: String
    let sourceLanguage: String
    let targetLanguage: String
}

enum AppleTranslatorError: LocalizedError {
    case unknownLanguage
    case notInstalled(String, String)

    var errorDescription: String? {
        switch self {
        case .unknownLanguage:
            return "No se ha podido detectar el idioma."
        case .notInstalled(let source, let target):
            return "Idiomas \(source) → \(target) no descargados (Ajustes > General > Idioma y región > Idiomas de traducción)."
        }
    }
}

@MainActor
final class AppleTranslator {
    private var sessions: [String: TranslationSession] = [:]
    private var currentTask: Task<Void, Never>?

    func warmUp() {
        Task {
            _ = try? await session(from: "es", to: "en").translate("Hola")
            _ = try? await session(from: "en", to: "es").translate("Hello")
        }
    }

    func translate(_ text: String, completion: @escaping (Result<AppleTranslation, Error>) -> Void) {
        cancel()
        currentTask = Task {
            let result: Result<AppleTranslation, Error>
            do {
                result = .success(try await translate(text))
            } catch {
                result = .failure(error)
            }
            guard !Task.isCancelled else { return }
            completion(result)
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func translate(_ text: String) async throws -> AppleTranslation {
        guard let source = Self.detectLanguage(of: text) else { throw AppleTranslatorError.unknownLanguage }
        let target = source == "es" ? "en" : "es"
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
        guard status == .installed else {
            throw AppleTranslatorError.notInstalled(Self.displayName(source), Self.displayName(target))
        }
        let response = try await session(from: source, to: target).translate(text)
        return AppleTranslation(text: response.targetText, sourceLanguage: Self.displayName(source), targetLanguage: Self.displayName(target))
    }

    private func session(from source: String, to target: String) -> TranslationSession {
        let key = "\(source)>\(target)"
        if let session = sessions[key] { return session }
        let session = TranslationSession(installedSource: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
        sessions[key] = session
        return session
    }

    private static func detectLanguage(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage.map { Locale.Language(identifier: $0.rawValue).languageCode?.identifier ?? $0.rawValue }
    }

    private static func displayName(_ code: String) -> String {
        Locale(identifier: "es").localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}
