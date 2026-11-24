import Foundation

public struct ServerRequest: Encodable, Equatable {
    public let id: String
    public let text: String
    public let mine: String
    public let target: String
    public let to: String?
    public let provider: String?

    public init(id: String, text: String, languagePair: LanguagePair, targetOverride: String? = nil, provider: TranslationProviderKind? = nil) {
        self.id = id
        self.text = text
        self.provider = provider?.rawValue
        mine = Languages.englishName(forCode: languagePair.mine)
        target = Languages.englishName(forCode: languagePair.target)
        to = targetOverride.map(Languages.englishName(forCode:))
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
    public let provider: String?
    public let result: TranslationResult?
    public let error: String?
    public let code: String?

    var providerKind: TranslationProviderKind {
        provider.flatMap(TranslationProviderKind.init(rawValue:)) ?? .claudeCode
    }
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
    private var startedAt: [String: Date] = [:]
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    public var pendingCount: Int { pending.count }

    public func register(id: String, completion: @escaping Completion) {
        cancelCurrent()
        pending[id] = completion
        startedAt[id] = now()
        currentRequestID = id
    }

    public func cancelCurrent() {
        if let currentRequestID {
            pending[currentRequestID] = nil
            startedAt[currentRequestID] = nil
        }
        currentRequestID = nil
    }

    public func fail(id: String, with error: Error) {
        complete(id: id, with: .failure(error))
    }

    public func failAll(with error: Error) {
        lines.reset()
        let waiting = pending.values
        pending.removeAll()
        startedAt.removeAll()
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
        let elapsed = startedAt[id].map { now().timeIntervalSince($0) }
        if let result = message.result {
            complete(id: id, with: .success(ClaudeTranslation(result: result, model: message.model, provider: message.providerKind, elapsed: elapsed)))
        } else if let code = message.code.flatMap(ProviderErrorCode.init(rawValue:)) {
            complete(id: id, with: .failure(TranslatorError.provider(code, message.providerKind, message.error ?? "")))
        } else {
            complete(id: id, with: .failure(TranslatorError.failed(message.error ?? "La traducción falló.")))
        }
    }

    private func complete(id: String, with result: Result<ClaudeTranslation, Error>) {
        startedAt[id] = nil
        guard let completion = pending.removeValue(forKey: id) else { return }
        if currentRequestID == id { currentRequestID = nil }
        completion(result)
    }
}
