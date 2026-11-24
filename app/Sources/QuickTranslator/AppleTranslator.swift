import Foundation
import QuickTranslatorCore
import Translation

@MainActor
final class AppleTranslator {
    private var sessions: [String: TranslationSession] = [:]
    private var currentTask: Task<Void, Never>?

    func warmUp(_ pair: LanguagePair) {
        Task {
            _ = try? await session(from: pair.mine, to: pair.target).translate("Hola")
            _ = try? await session(from: pair.target, to: pair.mine).translate("Hello")
        }
    }

    func translate(
        _ text: String,
        languagePair: LanguagePair,
        targetOverride: String? = nil,
        completion: @escaping (Result<AppleTranslation, Error>) -> Void
    ) {
        cancel()
        currentTask = Task {
            let result: Result<AppleTranslation, Error>
            do {
                result = .success(try await translate(text, languagePair: languagePair, targetOverride: targetOverride))
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

    func languagePackAdvice(for pair: LanguagePair) async -> LanguagePackAdvice {
        let availability = LanguageAvailability()
        let mine = Locale.Language(identifier: pair.mine)
        let target = Locale.Language(identifier: pair.target)
        let statuses = [
            await availability.status(from: mine, to: target),
            await availability.status(from: target, to: mine),
        ]
        return LanguagePackAdvice.evaluate(statuses.map(Self.packStatus))
    }

    private static func packStatus(_ status: LanguageAvailability.Status) -> LanguagePackStatus {
        switch status {
        case .installed: return .installed
        case .supported: return .downloadable
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    private func translate(_ text: String, languagePair: LanguagePair, targetOverride: String?) async throws -> AppleTranslation {
        guard let source = Languages.dominantLanguageCode(of: text) else { throw AppleTranslatorError.unknownLanguage }
        guard let target = languagePair.targetCode(forSource: source, override: targetOverride) else {
            throw AppleTranslatorError.alreadyInTarget(source)
        }
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target))
        guard status == .installed else {
            throw AppleTranslatorError.notInstalled(source: source, target: target)
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
