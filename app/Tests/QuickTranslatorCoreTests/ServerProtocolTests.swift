import Foundation
import Testing
@testable import QuickTranslatorCore

private func data(_ string: String) -> Data { Data(string.utf8) }

private func strings(_ lines: [Data]) -> [String] { lines.map { String(decoding: $0, as: UTF8.self) } }

private final class Recorder {
    var results: [Result<ClaudeTranslation, Error>] = []

    var completion: ServerResponseRouter.Completion { { self.results.append($0) } }

    var successes: [ClaudeTranslation] { results.compactMap { try? $0.get() } }

    var errors: [TranslatorError] {
        results.compactMap { result in
            if case .failure(let error) = result { return error as? TranslatorError }
            return nil
        }
    }
}

private func responseLine(id: String, text: String) -> String {
    #"{"id":"\#(id)","model":"claude-haiku-5-5","result":{"sourceLanguage":"Spanish","targetLanguage":"English","variants":[{"label":"Natural","text":"\#(text)"}]}}"# + "\n"
}

@Suite("LineBuffer")
struct LineBufferTests {
    @Test("returns complete lines and keeps the remainder")
    func splitsLines() {
        var buffer = LineBuffer()
        #expect(strings(buffer.append(data("one\ntwo\nthr"))) == ["one", "two"])
        #expect(strings(buffer.append(data("ee\n"))) == ["three"])
    }

    @Test("joins a line that arrives in several chunks")
    func joinsChunks() {
        var buffer = LineBuffer()
        #expect(buffer.append(data("{\"id\":")).isEmpty)
        #expect(buffer.append(data("\"1\"")).isEmpty)
        #expect(strings(buffer.append(data("}\n"))) == [#"{"id":"1"}"#])
    }

    @Test("keeps multi-byte characters split across chunks")
    func splitsUTF8() {
        var buffer = LineBuffer()
        let bytes = Array("adiós\n".utf8)
        let cut = bytes.firstIndex(of: 0xC3)! + 1
        #expect(buffer.append(Data(bytes[..<cut])).isEmpty)
        #expect(strings(buffer.append(Data(bytes[cut...]))) == ["adiós"])
    }

    @Test("drops a partial line on reset")
    func reset() {
        var buffer = LineBuffer()
        _ = buffer.append(data("partial"))
        buffer.reset()
        #expect(strings(buffer.append(data("next\n"))) == ["next"])
    }
}

@Suite("ServerRequest")
struct ServerRequestTests {
    @Test("encodes one JSON object terminated by a newline")
    func encodesALine() throws {
        let line = try ServerRequest(id: "1", text: "línea 1\nlínea 2").encodedLine()
        #expect(line.last == 0x0A)
        #expect(line.dropLast().contains(0x0A) == false)
        let decoded = try JSONSerialization.jsonObject(with: line.dropLast()) as? [String: String]
        #expect(decoded == ["id": "1", "text": "línea 1\nlínea 2"])
    }
}

@Suite("ServerResponseRouter")
struct ServerResponseRouterTests {
    @Test("delivers a result with the model to its request")
    func deliversResult() {
        let router = ServerResponseRouter()
        let recorder = Recorder()
        router.register(id: "a", completion: recorder.completion)

        router.receive(data(responseLine(id: "a", text: "See you later")))

        #expect(recorder.successes == [ClaudeTranslation(
            result: TranslationResult(sourceLanguage: "Spanish", targetLanguage: "English", variants: [TranslationVariant(label: "Natural", text: "See you later")]),
            model: "claude-haiku-5-5"
        )])
        #expect(router.pendingCount == 0)
    }

    @Test("turns a server error into a failure")
    func deliversError() {
        let router = ServerResponseRouter()
        let recorder = Recorder()
        router.register(id: "a", completion: recorder.completion)

        router.receive(data(#"{"id":"a","error":"Translation failed: error_max_turns"}"# + "\n"))

        #expect(recorder.errors == [.failed("Translation failed: error_max_turns")])
    }

    @Test("handles a response split across chunks")
    func handlesChunks() {
        let router = ServerResponseRouter()
        let recorder = Recorder()
        router.register(id: "a", completion: recorder.completion)
        let line = Array(responseLine(id: "a", text: "Hi").utf8)

        router.receive(Data(line[..<20]))
        #expect(recorder.results.isEmpty)
        router.receive(Data(line[20...]))
        #expect(recorder.successes.count == 1)
    }

    @Test("ignores the ready message, invalid lines and unknown ids")
    func ignoresNoise() {
        let router = ServerResponseRouter()
        let recorder = Recorder()
        router.register(id: "a", completion: recorder.completion)

        router.receive(data(#"{"ready":true,"model":"claude-haiku-5-5"}"# + "\n"))
        router.receive(data("not json\n"))
        router.receive(data(#"{"id":null,"error":"Request must be a JSON object"}"# + "\n"))
        router.receive(data(responseLine(id: "unknown", text: "x")))

        #expect(recorder.results.isEmpty)
        #expect(router.pendingCount == 1)
    }

    @Test("drops the previous request when a new one starts")
    func newRequestCancelsThePrevious() {
        let router = ServerResponseRouter()
        let first = Recorder()
        let second = Recorder()
        router.register(id: "a", completion: first.completion)
        router.register(id: "b", completion: second.completion)

        router.receive(data(responseLine(id: "a", text: "late")))
        router.receive(data(responseLine(id: "b", text: "current")))

        #expect(first.results.isEmpty)
        #expect(second.successes.map(\.result.variants[0].text) == ["current"])
    }

    @Test("ignores the answer to a cancelled request")
    func cancel() {
        let router = ServerResponseRouter()
        let recorder = Recorder()
        router.register(id: "a", completion: recorder.completion)

        router.cancelCurrent()
        router.receive(data(responseLine(id: "a", text: "late")))

        #expect(recorder.results.isEmpty)
        #expect(router.pendingCount == 0)
    }

    @Test("completes a request only once when sending it fails")
    func failCompletesOnce() {
        let router = ServerResponseRouter()
        let recorder = Recorder()
        router.register(id: "a", completion: recorder.completion)

        router.fail(id: "a", with: TranslatorError.notConfigured)
        router.failAll(with: TranslatorError.serverStopped)
        router.receive(data(responseLine(id: "a", text: "late")))

        #expect(recorder.errors == [.notConfigured])
    }

    @Test("fails every pending request when the server stops and discards partial output")
    func failAll() {
        let router = ServerResponseRouter()
        let recorder = Recorder()
        router.register(id: "a", completion: recorder.completion)
        router.receive(data(#"{"id":"a","res"#))

        router.failAll(with: TranslatorError.serverStopped)
        #expect(recorder.errors == [.serverStopped])

        let next = Recorder()
        router.register(id: "b", completion: next.completion)
        router.receive(data(responseLine(id: "b", text: "fresh")))
        #expect(next.successes.count == 1)
    }
}
