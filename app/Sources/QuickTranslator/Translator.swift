import Foundation
import QuickTranslatorCore

final class Translator {
    private let settings: AppSettings
    private let secrets: SecretStore
    private var process: Process?
    private var input: FileHandle?
    private let router = ServerResponseRouter()

    private var nodePath: String? { Bundle.main.object(forInfoDictionaryKey: "QTNodePath") as? String }
    private var cliPath: String? { Bundle.main.object(forInfoDictionaryKey: "QTCLIPath") as? String }

    init(settings: AppSettings, secrets: SecretStore) {
        self.settings = settings
        self.secrets = secrets
    }

    func start() {
        guard process == nil else { return }
        try? launchServer()
    }

    func restart() {
        stop()
        start()
    }

    func translate(
        _ text: String,
        languagePair: LanguagePair,
        targetOverride: String? = nil,
        provider: TranslationProviderKind? = nil,
        completion: @escaping ServerResponseRouter.Completion
    ) {
        let id = UUID().uuidString
        router.register(id: id, completion: completion)
        do {
            if process == nil { try launchServer() }
            let request = ServerRequest(id: id, text: text, languagePair: languagePair, targetOverride: targetOverride, provider: provider)
            try input?.write(contentsOf: request.encodedLine())
        } catch {
            router.fail(id: id, with: error)
        }
    }

    func cancel() {
        router.cancelCurrent()
    }

    private func stop() {
        guard let process else { return }
        self.process = nil
        input = nil
        process.terminationHandler = nil
        process.terminate()
        router.failAll(with: TranslatorError.serverStopped)
    }

    private func launchServer() throws {
        guard let nodePath, let cliPath,
              FileManager.default.isExecutableFile(atPath: nodePath),
              FileManager.default.fileExists(atPath: cliPath) else {
            throw TranslatorError.notConfigured
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = ServerLaunch.arguments(cliPath: cliPath, provider: settings.provider, apiModel: settings.claudeAPIModel)
        process.environment = ServerLaunch.environment(base: ProcessInfo.processInfo.environment, secrets: secrets)
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
