import Foundation
import Testing
@testable import QuickTranslatorCore

private func data(_ string: String) -> Data { Data(string.utf8) }

@Suite("TranslationProviderKind")
struct TranslationProviderKindTests {
    @Test("matches the CLI provider ids")
    func rawValues() {
        #expect(TranslationProviderKind.allCases.map(\.rawValue) == ["claude-code", "claude-api", "deepl"])
    }

    @Test("only the remote providers need a key, each in its own variable")
    func keys() {
        #expect(TranslationProviderKind.claudeCode.keyAccount == nil)
        #expect(TranslationProviderKind.claudeAPI.keyEnvironmentVariable == "QT_ANTHROPIC_API_KEY")
        #expect(TranslationProviderKind.deepL.keyEnvironmentVariable == "QT_DEEPL_AUTH_KEY")
        #expect(TranslationProviderKind.claudeAPI.keyAccount != TranslationProviderKind.deepL.keyAccount)
    }

    @Test("links to the page where each key is requested")
    func keyPages() {
        #expect(TranslationProviderKind.claudeCode.keyPage == nil)
        #expect(TranslationProviderKind.deepL.keyPage?.url.absoluteString == "https://www.deepl.com/pro-api")
        #expect(TranslationProviderKind.claudeAPI.keyPage?.url.absoluteString == "https://platform.claude.com/settings/keys")
        for kind in TranslationProviderKind.allCases {
            #expect((kind.keyPage != nil) == (kind.keyAccount != nil))
        }
    }

    @Test("never uses ANTHROPIC_API_KEY, which would switch Claude Code to API billing")
    func avoidsClaudeCodeVariables() {
        for kind in TranslationProviderKind.allCases {
            #expect(kind.keyEnvironmentVariable != "ANTHROPIC_API_KEY")
        }
    }
}

@Suite("ClaudeModelOption")
struct ClaudeModelOptionTests {
    @Test("offers the current Claude models with Haiku first")
    func options() {
        #expect(ClaudeModelOption.all.map(\.id) == ["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5"])
        #expect(ClaudeModelOption.default.displayName == "Claude Haiku 5.5")
    }
}

@Suite("ServerLaunch")
struct ServerLaunchTests {
    @Test("starts the server with the chosen provider and Claude API model")
    func arguments() {
        #expect(ServerLaunch.arguments(cliPath: "/x/cli.js", provider: .deepL, apiModel: "claude-sonnet-5-5")
            == ["/x/cli.js", "--server", "--provider", "deepl", "--api-model", "claude-sonnet-5-5"])
    }

    @Test("passes saved keys and drops stale or empty ones")
    func environment() {
        let secrets = InMemorySecretStore(["anthropic-api-key": "  sk-ant-123 \n", "deepl-auth-key": " "])
        let environment = ServerLaunch.environment(
            base: ["PATH": "/bin", "QT_DEEPL_AUTH_KEY": "old"],
            secrets: secrets
        )
        #expect(environment == ["PATH": "/bin", "QT_ANTHROPIC_API_KEY": "sk-ant-123"])
    }
}

@Suite("ProviderErrorCode")
struct ProviderErrorCodeTests {
    @Test("explains each failure in Spanish with the provider name", arguments: [
        (ProviderErrorCode.missingKey, "Falta la clave de DeepL. Añádela en Ajustes."),
        (.authFailed, "DeepL ha rechazado la clave. Revísala en Ajustes."),
        (.quotaExceeded, "Se ha agotado la cuota de DeepL."),
        (.rateLimited, "Demasiadas peticiones a DeepL. Espera un momento."),
        (.unsupportedLanguage, "DeepL no admite este idioma."),
        (.network, "No se ha podido conectar con DeepL."),
        (.providerError, "DeepL ha fallado: boom"),
    ])
    func messages(code: ProviderErrorCode, message: String) {
        #expect(code.message(provider: .deepL, detail: "boom") == message)
    }

    @Test("offers the settings only for key problems")
    func opensSettings() {
        #expect(ProviderErrorCode.missingKey.opensSettings)
        #expect(ProviderErrorCode.authFailed.opensSettings)
        #expect(ProviderErrorCode.quotaExceeded.opensSettings == false)
        #expect(TranslatorError.provider(.authFailed, .claudeAPI, "").opensSettings)
        #expect(TranslatorError.serverStopped.opensSettings == false)
    }
}

@Suite("Elapsed")
struct ElapsedTests {
    @Test("formats seconds with one decimal and a Spanish comma", arguments: [
        (0.0, "0,0 s"), (0.42, "0,4 s"), (2.86, "2,9 s"), (12.0, "12,0 s"), (-1.0, "0,0 s"),
    ])
    func format(seconds: Double, text: String) {
        #expect(Elapsed.format(seconds) == text)
    }
}

@Suite("Provider responses")
struct ProviderResponseTests {
    @Test("keeps the provider and measures the time to the answer")
    func providerAndElapsed() {
        var clock = Date(timeIntervalSince1970: 0)
        let router = ServerResponseRouter(now: { clock })
        var received: ClaudeTranslation?
        router.register(id: "a") { received = try? $0.get() }

        clock = clock.addingTimeInterval(1.25)
        router.receive(data(#"{"id":"a","provider":"deepl","model":"deepl","result":{"sourceLanguage":"Spanish","targetLanguage":"English","variants":[{"label":"DeepL","text":"Hi"}]}}"# + "\n"))

        #expect(received?.provider == .deepL)
        #expect(received?.elapsed == 1.25)
    }

    @Test("turns a coded server error into a provider error")
    func codedError() {
        let router = ServerResponseRouter()
        var failure: TranslatorError?
        router.register(id: "a") { result in
            if case .failure(let error) = result { failure = error as? TranslatorError }
        }

        router.receive(data(#"{"id":"a","provider":"claude-api","error":"bad key","code":"auth_failed"}"# + "\n"))

        #expect(failure == .provider(.authFailed, .claudeAPI, "bad key"))
        #expect(failure?.errorDescription == "Claude API ha rechazado la clave. Revísala en Ajustes.")
    }

    @Test("keeps uncoded errors and unknown codes as plain failures")
    func uncodedError() {
        let router = ServerResponseRouter()
        var failures: [TranslatorError] = []
        router.register(id: "a") { if case .failure(let e) = $0 { failures.append(e as! TranslatorError) } }
        router.receive(data(#"{"id":"a","error":"boom","code":"brand_new"}"# + "\n"))
        #expect(failures == [.failed("boom")])
    }

    @Test("asks the server for a specific provider")
    func requestProvider() throws {
        let line = try ServerRequest(id: "1", text: "hola", languagePair: .default, provider: .deepL).encodedLine()
        let decoded = try JSONSerialization.jsonObject(with: line.dropLast()) as? [String: String]
        #expect(decoded?["provider"] == "deepl")
    }
}
