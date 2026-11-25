import Testing
@testable import QuickTranslatorCore

private let apple = AppleTranslation(text: "See you later", sourceLanguage: "Español", targetLanguage: "Inglés")
private let claude = ClaudeTranslation(
    result: TranslationResult(
        sourceLanguage: "Spanish",
        targetLanguage: "English",
        variants: [
            TranslationVariant(label: "Natural", text: "Catch you later"),
            TranslationVariant(label: "Formal", text: "I will see you later"),
        ]
    ),
    model: "claude-haiku-5-5"
)

@Suite("ChoiceKeys")
struct ChoiceKeysTests {
    @Test("key 1 picks Apple and keys 2… pick Claude's variants in order")
    func mapsKeys() {
        #expect(ChoiceKeys.text(forKey: 1, apple: .done(apple), claude: .done(claude)) == "See you later")
        #expect(ChoiceKeys.text(forKey: 2, apple: .done(apple), claude: .done(claude)) == "Catch you later")
        #expect(ChoiceKeys.text(forKey: 3, apple: .done(apple), claude: .done(claude)) == "I will see you later")
    }

    @Test("Claude keys keep their numbers when Apple failed")
    func claudeKeysWithoutApple() {
        #expect(ChoiceKeys.text(forKey: 1, apple: .failed("x"), claude: .done(claude)) == nil)
        #expect(ChoiceKeys.text(forKey: 2, apple: .failed("x"), claude: .done(claude)) == "Catch you later")
    }

    @Test("keys do nothing while a provider has no result", arguments: [
        ProviderState<ClaudeTranslation>.idle, .loading, .failed("error"),
    ])
    func noResult(claudeState: ProviderState<ClaudeTranslation>) {
        #expect(ChoiceKeys.text(forKey: 2, apple: .loading, claude: claudeState) == nil)
        #expect(ChoiceKeys.text(forKey: 1, apple: .loading, claude: claudeState) == nil)
    }

    @Test("keys beyond the variants or below 1 do nothing", arguments: [0, 4, 9, -1])
    func outOfRange(key: Int) {
        #expect(ChoiceKeys.text(forKey: key, apple: .done(apple), claude: .done(claude)) == nil)
    }
}

@Suite("ModelName")
struct ModelNameTests {
    @Test("formats Claude model ids", arguments: [
        ("claude-haiku-5-5", "Claude Haiku 5.5"),
        ("claude-opus-5-5", "Claude Opus 5.5"),
        ("claude-sonnet-5", "Claude Sonnet 5"),
        ("claude-fable-5-2", "Claude Fable 5.2"),
        ("claude-haiku", "Claude Haiku"),
    ])
    func formats(id: String, expected: String) {
        #expect(ModelName.displayName(forModel: id) == expected)
    }

    @Test("formats OpenAI model ids", arguments: [
        ("gpt-6-luna", "GPT-6 Luna"),
        ("gpt-6.1-terra", "GPT-6.1 Terra"),
        ("gpt-6.2-sol", "GPT-6.2 Sol"),
    ])
    func formatsOpenAI(id: String, expected: String) {
        #expect(ModelName.displayName(forModel: id) == expected)
    }

    @Test("leaves other ids untouched", arguments: ["claude", "my-model"])
    func passthrough(id: String) {
        #expect(ModelName.displayName(forModel: id) == id)
    }
}

@Suite("TranslatorError")
struct TranslatorErrorTests {
    @Test("shows the server's message for a failed translation")
    func failedMessage() {
        #expect(TranslatorError.failed("boom").errorDescription == "boom")
    }
}
