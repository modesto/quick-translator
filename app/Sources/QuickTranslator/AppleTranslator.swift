import Foundation
import QuickTranslatorCore
import Translation

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
        guard let source = Languages.dominantLanguageCode(of: text) else { throw AppleTranslatorError.unknownLanguage }
        let target = Languages.targetLanguageCode(forSource: source)
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
        guard status == .installed else {
            throw AppleTranslatorError.notInstalled(Languages.displayName(forCode: source), Languages.displayName(forCode: target))
        }
        let response = try await session(from: source, to: target).translate(text)
        return AppleTranslation(
            text: response.targetText,
            sourceLanguage: Languages.displayName(forCode: source),
            targetLanguage: Languages.displayName(forCode: target)
        )
    }

    private func session(from source: String, to target: String) -> TranslationSession {
        let key = "\(source)>\(target)"
        if let session = sessions[key] { return session }
        let session = TranslationSession(installedSource: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
        sessions[key] = session
        return session
    }
}
