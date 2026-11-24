import Foundation

public struct ServerRequest: Encodable, Equatable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    public func encodedLine() throws -> Data {
        var line = try JSONEncoder().encode(self)
        line.append(0x0A)
        return line
    }
}

public struct ServerMessage: Decodable, Equatable {
    public let id: String?
    public let model: String?
    public let result: TranslationResult?
    public let error: String?
}

public struct LineBuffer {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            lines.append(Data(buffer[buffer.startIndex..<newline]))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }

    public mutating func reset() {
        buffer.removeAll()
    }
}

public final class ServerResponseRouter {
    public typealias Completion = (Result<ClaudeTranslation, Error>) -> Void

    private var lines = LineBuffer()
    private var pending: [String: Completion] = [:]
    private var currentRequestID: String?

    public init() {}

    public var pendingCount: Int { pending.count }

    public func register(id: String, completion: @escaping Completion) {
        cancelCurrent()
        pending[id] = completion
        currentRequestID = id
    }

    public func cancelCurrent() {
        if let currentRequestID { pending[currentRequestID] = nil }
        currentRequestID = nil
    }

    public func fail(id: String, with error: Error) {
        complete(id: id, with: .failure(error))
    }

    public func failAll(with error: Error) {
        lines.reset()
        let waiting = pending.values
        pending.removeAll()
        currentRequestID = nil
        waiting.forEach { $0(.failure(error)) }
    }

    public func receive(_ data: Data) {
        for line in lines.append(data) {
            route(line)
        }
    }

    private func route(_ line: Data) {
        guard let message = try? JSONDecoder().decode(ServerMessage.self, from: line), let id = message.id else { return }
        if let result = message.result {
            complete(id: id, with: .success(ClaudeTranslation(result: result, model: message.model)))
        } else {
            complete(id: id, with: .failure(TranslatorError.failed(message.error ?? "La traducción falló.")))
        }
    }

    private func complete(id: String, with result: Result<ClaudeTranslation, Error>) {
        guard let completion = pending.removeValue(forKey: id) else { return }
        if currentRequestID == id { currentRequestID = nil }
        completion(result)
    }
}
