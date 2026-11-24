import Foundation

struct TranslationVariant: Decodable, Identifiable {
    let label: String
    let text: String
    var id: String { label + text }
}

struct TranslationResult: Decodable {
    let sourceLanguage: String
    let targetLanguage: String
    let variants: [TranslationVariant]
}

enum TranslatorError: LocalizedError {
    case notConfigured
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No se encuentra el CLI quick-translate (QTNodePath / QTCLIPath en Info.plist)."
        case .failed(let message):
            return message
        }
    }
}

final class Translator {
    private var process: Process?

    private var nodePath: String? { Bundle.main.object(forInfoDictionaryKey: "QTNodePath") as? String }
    private var cliPath: String? { Bundle.main.object(forInfoDictionaryKey: "QTCLIPath") as? String }

    func translate(_ text: String, completion: @escaping (Result<TranslationResult, Error>) -> Void) {
        cancel()
        guard let nodePath, let cliPath,
              FileManager.default.isExecutableFile(atPath: nodePath),
              FileManager.default.fileExists(atPath: cliPath) else {
            completion(.failure(TranslatorError.notConfigured))
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [cliPath]
        let input = Pipe()
        let output = Pipe()
        let errorOutput = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput

        process.terminationHandler = { [weak self] finished in
            let stdout = output.fileHandleForReading.readDataToEndOfFile()
            let stderr = errorOutput.fileHandleForReading.readDataToEndOfFile()
            let result = Self.parse(status: finished.terminationStatus, reason: finished.terminationReason, stdout: stdout, stderr: stderr)
            DispatchQueue.main.async {
                guard self?.process === finished else { return }
                self?.process = nil
                completion(result)
            }
        }

        do {
            try process.run()
        } catch {
            completion(.failure(error))
            return
        }
        self.process = process
        input.fileHandleForWriting.write(Data(text.utf8))
        try? input.fileHandleForWriting.close()
    }

    func cancel() {
        guard let process else { return }
        self.process = nil
        if process.isRunning { process.terminate() }
    }

    private static func parse(status: Int32, reason: Process.TerminationReason, stdout: Data, stderr: Data) -> Result<TranslationResult, Error> {
        if status == 0, let result = try? JSONDecoder().decode(TranslationResult.self, from: stdout) {
            return .success(result)
        }
        let message = (try? JSONDecoder().decode([String: String].self, from: stderr))?["error"]
            ?? String(data: stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failure(TranslatorError.failed(message?.isEmpty == false ? message! : "La traducción falló (código \(status))."))
    }
}
