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

struct ClaudeTranslation {
    let result: TranslationResult
    let model: String?
}

enum TranslatorError: LocalizedError {
    case notConfigured
    case serverStopped
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No se encuentra el CLI quick-translate (QTNodePath / QTCLIPath en Info.plist)."
        case .serverStopped:
            return "El proceso de traducción se ha detenido. Vuelve a intentarlo."
        case .failed(let message):
            return message
        }
    }
}

private struct ServerRequest: Encodable {
    let id: String
    let text: String
}

private struct ServerMessage: Decodable {
    let id: String?
    let model: String?
    let result: TranslationResult?
    let error: String?
}

final class Translator {
    typealias Completion = (Result<ClaudeTranslation, Error>) -> Void

    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var pending: [String: Completion] = [:]
    private var currentRequestID: String?

    private var nodePath: String? { Bundle.main.object(forInfoDictionaryKey: "QTNodePath") as? String }
    private var cliPath: String? { Bundle.main.object(forInfoDictionaryKey: "QTCLIPath") as? String }

    func start() {
        guard process == nil else { return }
        try? launchServer()
    }

    func translate(_ text: String, completion: @escaping Completion) {
        cancel()
        do {
            if process == nil { try launchServer() }
            let id = UUID().uuidString
            var line = try JSONEncoder().encode(ServerRequest(id: id, text: text))
            line.append(0x0A)
            pending[id] = completion
            currentRequestID = id
            try input?.write(contentsOf: line)
        } catch {
            completion(.failure(error))
        }
    }

    func cancel() {
        if let currentRequestID { pending[currentRequestID] = nil }
        currentRequestID = nil
    }

    private func launchServer() throws {
        guard let nodePath, let cliPath,
              FileManager.default.isExecutableFile(atPath: nodePath),
              FileManager.default.fileExists(atPath: cliPath) else {
            throw TranslatorError.notConfigured
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [cliPath, "--server"]
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async { self?.receive(data) }
        }
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async { self?.serverDidStop(finished) }
        }

        try process.run()
        self.process = process
        self.input = inputPipe.fileHandleForWriting
        buffer.removeAll()
    }

    private func receive(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            handle(line: Data(line))
        }
    }

    private func handle(line: Data) {
        guard let message = try? JSONDecoder().decode(ServerMessage.self, from: line),
              let id = message.id,
              let completion = pending.removeValue(forKey: id) else { return }
        if currentRequestID == id { currentRequestID = nil }
        if let result = message.result {
            completion(.success(ClaudeTranslation(result: result, model: message.model)))
        } else {
            completion(.failure(TranslatorError.failed(message.error ?? "La traducción falló.")))
        }
    }

    private func serverDidStop(_ finished: Process) {
        guard finished === process else { return }
        process = nil
        input = nil
        buffer.removeAll()
        let waiting = pending.values
        pending.removeAll()
        currentRequestID = nil
        waiting.forEach { $0(.failure(TranslatorError.serverStopped)) }
    }
}
