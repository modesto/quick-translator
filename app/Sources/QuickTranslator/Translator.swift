import Foundation
import QuickTranslatorCore

final class Translator {
    private var process: Process?
    private var input: FileHandle?
    private let router = ServerResponseRouter()

    private var nodePath: String? { Bundle.main.object(forInfoDictionaryKey: "QTNodePath") as? String }
    private var cliPath: String? { Bundle.main.object(forInfoDictionaryKey: "QTCLIPath") as? String }

    func start() {
        guard process == nil else { return }
        try? launchServer()
    }

    func translate(_ text: String, completion: @escaping ServerResponseRouter.Completion) {
        let id = UUID().uuidString
        router.register(id: id, completion: completion)
        do {
            if process == nil { try launchServer() }
            try input?.write(contentsOf: ServerRequest(id: id, text: text).encodedLine())
        } catch {
            router.fail(id: id, with: error)
        }
    }

    func cancel() {
        router.cancelCurrent()
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
            DispatchQueue.main.async { self?.router.receive(data) }
        }
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async { self?.serverDidStop(finished) }
        }

        try process.run()
        self.process = process
        self.input = inputPipe.fileHandleForWriting
    }

    private func serverDidStop(_ finished: Process) {
        guard finished === process else { return }
        process = nil
        input = nil
        router.failAll(with: TranslatorError.serverStopped)
    }
}
