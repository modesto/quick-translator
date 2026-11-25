import Foundation
import Testing
@testable import QuickTranslatorCore

private func data(_ string: String) -> Data { Data(string.utf8) }

@Suite("TranslationProviderKind")
struct TranslationProviderKindTests {
    @Test("matches the CLI provider ids")
    func rawValues() {
        #expect(TranslationProviderKind.allCases.map(\.rawValue) == ["claude-code", "claude-api", "openai", "deepl"])
    }

    @Test("only the remote providers need a key, each in its own variable")
    func keys() {
        #expect(TranslationProviderKind.claudeCode.keyAccount == nil)
        #expect(TranslationProviderKind.claudeAPI.keyEnvironmentVariable == "QT_ANTHROPIC_API_KEY")
        #expect(TranslationProviderKind.openAI.keyEnvironmentVariable == "QT_OPENAI_API_KEY")
        #expect(TranslationProviderKind.deepL.keyEnvironmentVariable == "QT_DEEPL_AUTH_KEY")
        let accounts = TranslationProviderKind.allCases.compactMap(\.keyAccount)
        #expect(Set(accounts).count == accounts.count)
        #expect(TranslationProviderKind.claudeAPI.keyAccount != TranslationProviderKind.deepL.keyAccount)
    }

    @Test("links to the page where each key is requested")
    func keyPages() {
        #expect(TranslationProviderKind.claudeCode.keyPage == nil)
        #expect(TranslationProviderKind.deepL.keyPage?.url.absoluteString == "https://www.deepl.com/pro-api")
        #expect(TranslationProviderKind.claudeAPI.keyPage?.url.absoluteString == "https://platform.claude.com/settings/keys")
        #expect(TranslationProviderKind.openAI.keyPage?.url.absoluteString == "https://platform.openai.com/api-keys")
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

@Suite("ModelOption")
struct ModelOptionTests {
    @Test("offers the current Claude models with Haiku first")
    func options() {
        #expect(ModelOption.claude.map(\.id) == ["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5"])
        #expect(ModelOption.claude[0].displayName == "Claude Haiku 5.5")
    }

    @Test("offers the OpenAI models with the fastest first")
    func openAIOptions() {
        #expect(ModelOption.openAI.map(\.id) == ["gpt-6-luna", "gpt-6.1-terra", "gpt-6.2-sol"])
        #expect(ModelOption.openAI.map(\.displayName) == ["GPT-6 Luna", "GPT-6.1 Terra", "GPT-6.2 Sol"])
    }

    @Test("falls back to the first option for unknown ids")
    func validated() {
        #expect(ModelOption.validated("gpt-6.1-terra", in: ModelOption.openAI) == "gpt-6.1-terra")
        #expect(ModelOption.validated("gpt-4o", in: ModelOption.openAI) == "gpt-6-luna")
        #expect(ModelOption.validated(nil, in: ModelOption.openAI) == "gpt-6-luna")
        #expect(ModelOption.validated(nil, in: ModelOption.claude) == "claude-haiku-5-5")
    }
}

@Suite("ServerLaunch")
struct ServerLaunchTests {
    @Test("starts the server with the chosen provider and Claude API model")
    func arguments() {
        #expect(ServerLaunch.arguments(cliPath: "/x/cli.js", provider: .openAI, claudeAPIModel: "claude-sonnet-5-5", openAIModel: "gpt-6.1-terra")
            == ["/x/cli.js", "--server", "--provider", "openai", "--api-model", "claude-sonnet-5-5", "--openai-model", "gpt-6.1-terra"])
    }

    @Test("passes a compatible base URL only when it is not OpenAI's")
    func baseURLArgument() {
        let custom = ServerLaunch.arguments(cliPath: "/x", provider: .openAI, claudeAPIModel: "c", openAIModel: "llama3.2", openAIBaseURL: "http://localhost:11434/v1")
        #expect(custom.suffix(2) == ["--openai-base-url", "http://localhost:11434/v1"])
        let official = ServerLaunch.arguments(cliPath: "/x", provider: .openAI, claudeAPIModel: "c", openAIModel: "gpt-6-luna", openAIBaseURL: OpenAIBaseURL.default)
        #expect(!official.contains("--openai-base-url"))
    }

    @Test("passes saved keys and drops stale or empty ones")
    func environment() {
        let secrets = InMemorySecretStore(["anthropic-api-key": "  sk-ant-123 \n", "openai-api-key": "sk-proj", "deepl-auth-key": " "])
        let environment = ServerLaunch.environment(
            base: ["PATH": "/bin", "QT_DEEPL_AUTH_KEY": "old"],
            secrets: secrets
        )
        #expect(environment == ["PATH": "/bin", "QT_ANTHROPIC_API_KEY": "sk-ant-123", "QT_OPENAI_API_KEY": "sk-proj"])
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

@Suite("OpenAIBaseURL")
struct OpenAIBaseURLTests {
    @Test("empty means OpenAI", arguments: ["", "   ", "\n"])
    func empty(input: String) {
        #expect(OpenAIBaseURL.normalized(input) == "https://api.openai.com/v1")
    }

    @Test("keeps http and https URLs without the trailing slash", arguments: [
        ("http://localhost:11434/v1/", "http://localhost:11434/v1"),
        (" https://openrouter.ai/api/v1 ", "https://openrouter.ai/api/v1"),
    ])
    func valid(input: String, expected: String) {
        #expect(OpenAIBaseURL.normalized(input) == expected)
    }

    @Test("rejects anything that is not an http(s) URL", arguments: ["ftp://example.com", "localhost:11434", "not a url", "https://"])
    func invalid(input: String) {
        #expect(OpenAIBaseURL.normalized(input) == nil)
    }

    @Test("tells OpenAI from compatible servers")
    func official() {
        #expect(OpenAIBaseURL.isOfficial("https://api.openai.com/v1"))
        #expect(!OpenAIBaseURL.isOfficial("http://localhost:11434/v1"))
    }
}

@Suite("ProviderSetup")
struct ProviderSetupTests {
    @Test("OpenAI needs a key only on OpenAI's own server")
    func openAIKey() {
        #expect(!ProviderSetup.isReady(.openAI, hasKey: false, openAIBaseURL: OpenAIBaseURL.default))
        #expect(ProviderSetup.isReady(.openAI, hasKey: true, openAIBaseURL: OpenAIBaseURL.default))
        #expect(ProviderSetup.isReady(.openAI, hasKey: false, openAIBaseURL: "http://localhost:11434/v1"))
    }

    @Test("the other providers")
    func others() {
        #expect(ProviderSetup.isReady(.claudeCode, hasKey: false, openAIBaseURL: OpenAIBaseURL.default))
        #expect(!ProviderSetup.isReady(.claudeAPI, hasKey: false, openAIBaseURL: "http://localhost/v1"))
        #expect(ProviderSetup.isReady(.deepL, hasKey: true, openAIBaseURL: OpenAIBaseURL.default))
    }
}
