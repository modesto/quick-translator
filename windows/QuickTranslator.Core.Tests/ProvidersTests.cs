using QuickTranslator.Core;

namespace QuickTranslator.Core.Tests;

public class ProvidersTests
{
    [Fact]
    public void MatchesTheCliProviderIds()
    {
        Assert.Equal(["claude-code", "claude-api", "openai", "deepl"], TranslationProviders.All.Select(kind => kind.RawValue()));
        Assert.Equal(TranslationProviderKind.OpenAI, TranslationProviders.FromRawValue("openai"));
        Assert.Null(TranslationProviders.FromRawValue("gemini"));
    }

    [Fact]
    public void OnlyTheRemoteProvidersNeedAKeyEachInItsOwnVariable()
    {
        Assert.Null(TranslationProviderKind.ClaudeCode.KeyAccount());
        Assert.Equal("QT_ANTHROPIC_API_KEY", TranslationProviderKind.ClaudeApi.KeyEnvironmentVariable());
        Assert.Equal("QT_OPENAI_API_KEY", TranslationProviderKind.OpenAI.KeyEnvironmentVariable());
        Assert.Equal("QT_DEEPL_AUTH_KEY", TranslationProviderKind.DeepL.KeyEnvironmentVariable());
        var accounts = TranslationProviders.All.Select(kind => kind.KeyAccount()).OfType<string>().ToList();
        Assert.Equal(accounts.Count, accounts.Distinct().Count());
    }

    [Fact]
    public void NeverUsesAnthropicApiKeyWhichWouldSwitchClaudeCodeToApiBilling()
    {
        Assert.All(TranslationProviders.All, kind => Assert.NotEqual("ANTHROPIC_API_KEY", kind.KeyEnvironmentVariable()));
    }

    [Fact]
    public void LinksToThePageWhereEachKeyIsRequested()
    {
        Assert.Null(TranslationProviderKind.ClaudeCode.KeyPage(UILanguage.Es));
        Assert.Equal("https://www.deepl.com/pro-api", TranslationProviderKind.DeepL.KeyPage(UILanguage.Es)?.Url);
        Assert.Equal("https://platform.claude.com/settings/keys", TranslationProviderKind.ClaudeApi.KeyPage(UILanguage.Es)?.Url);
        Assert.Equal("https://platform.openai.com/api-keys", TranslationProviderKind.OpenAI.KeyPage(UILanguage.Es)?.Url);
        Assert.All(TranslationProviders.All, kind => Assert.Equal(kind.KeyAccount() is not null, kind.KeyPage(UILanguage.En) is not null));
    }

    [Fact]
    public void OffersTheCurrentModelsWithTheFastestFirst()
    {
        Assert.Equal(["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5"], ModelOption.Claude.Select(o => o.Id));
        Assert.Equal("Claude Haiku 5.5", ModelOption.Claude[0].DisplayName);
        Assert.Equal(["GPT-6 Luna", "GPT-6.1 Terra", "GPT-6.2 Sol"], ModelOption.OpenAI.Select(o => o.DisplayName));
        Assert.Equal("fastest", ModelOption.Claude[0].NoteText(UILanguage.En));
        Assert.Equal("la más rápida y barata", ModelOption.OpenAI[0].NoteText(UILanguage.Es));
    }

    [Fact]
    public void FallsBackToTheFirstOptionForUnknownIds()
    {
        Assert.Equal("gpt-6.1-terra", ModelOption.Validated("gpt-6.1-terra", ModelOption.OpenAI));
        Assert.Equal("gpt-6-luna", ModelOption.Validated("gpt-4o", ModelOption.OpenAI));
        Assert.Equal("claude-haiku-5-5", ModelOption.Validated(null, ModelOption.Claude));
    }

    [Fact]
    public void StartsTheServerWithTheChosenProviderAndModels()
    {
        Assert.Equal(
            ["C:\\x\\cli.js", "--server", "--provider", "openai", "--api-model", "claude-sonnet-5-5", "--openai-model", "gpt-6.1-terra"],
            ServerLaunch.Arguments("C:\\x\\cli.js", TranslationProviderKind.OpenAI, "claude-sonnet-5-5", "gpt-6.1-terra"));
    }

    [Fact]
    public void PassesACompatibleBaseUrlOnlyWhenItIsNotOpenAIs()
    {
        var custom = ServerLaunch.Arguments("cli.js", TranslationProviderKind.OpenAI, "m", "llama3.2", "http://localhost:11434/v1");
        Assert.Equal(["--openai-base-url", "http://localhost:11434/v1"], custom.TakeLast(2));
        var official = ServerLaunch.Arguments("cli.js", TranslationProviderKind.OpenAI, "m", "gpt-6-luna", OpenAIBaseUrl.Default);
        Assert.DoesNotContain("--openai-base-url", official);
    }

    [Fact]
    public void PassesSavedKeysAndDropsStaleOrEmptyOnes()
    {
        var secrets = new InMemorySecretStore(new() { ["anthropic-api-key"] = " sk-ant-123 ", ["openai-api-key"] = "sk-proj", ["deepl-auth-key"] = "  " });
        var environment = new Dictionary<string, string?> { ["PATH"] = "C:\\bin", ["QT_DEEPL_AUTH_KEY"] = "stale" };

        ServerLaunch.ApplyKeys(environment, secrets);

        Assert.Equal(new Dictionary<string, string?> { ["PATH"] = "C:\\bin", ["QT_ANTHROPIC_API_KEY"] = "sk-ant-123", ["QT_OPENAI_API_KEY"] = "sk-proj" }, environment);
    }

    [Theory]
    [InlineData(ProviderErrorCode.MissingKey, "Falta la clave de DeepL. Añádela en Ajustes.")]
    [InlineData(ProviderErrorCode.AuthFailed, "DeepL ha rechazado la clave. Revísala en Ajustes.")]
    [InlineData(ProviderErrorCode.QuotaExceeded, "Se ha agotado la cuota de DeepL.")]
    [InlineData(ProviderErrorCode.Network, "No se ha podido conectar con DeepL.")]
    [InlineData(ProviderErrorCode.ProviderError, "DeepL ha fallado: boom")]
    public void ExplainsEachFailureWithTheProviderName(ProviderErrorCode code, string message)
    {
        Assert.Equal(message, code.Message(TranslationProviderKind.DeepL, "boom", UILanguage.Es));
    }

    [Fact]
    public void OffersTheSettingsOnlyForKeyProblems()
    {
        Assert.True(ProviderErrorCode.MissingKey.OpensSettings());
        Assert.True(ProviderErrorCode.AuthFailed.OpensSettings());
        Assert.False(ProviderErrorCode.QuotaExceeded.OpensSettings());
        Assert.True(TranslatorException.ForProvider(ProviderErrorCode.AuthFailed, TranslationProviderKind.ClaudeApi, "").OpensSettings);
        Assert.False(TranslatorException.ServerStopped().OpensSettings);
    }

    [Theory]
    [InlineData(0.42, "0,4 s"), InlineData(1.26, "1,3 s"), InlineData(12, "12,0 s"), InlineData(-1, "0,0 s")]
    public void FormatsSecondsWithOneDecimalAndTheLanguagesSeparator(double seconds, string text)
    {
        Assert.Equal(text, Elapsed.Format(TimeSpan.FromSeconds(seconds), UILanguage.Es));
    }

    [Fact]
    public void FormatsSecondsWithADotInEnglish()
    {
        Assert.Equal("0.4 s", Elapsed.Format(TimeSpan.FromSeconds(0.42), UILanguage.En));
    }
}

public class OpenAIBaseUrlTests
{
    [Theory]
    [InlineData(""), InlineData("   "), InlineData("\n"), InlineData("https://api.openai.com"), InlineData("https://api.openai.com/")]
    public void EmptyOrBareOpenAIMeansTheDefault(string input) => Assert.Equal("https://api.openai.com/v1", OpenAIBaseUrl.Normalized(input));

    [Theory]
    [InlineData("http://localhost:11434/v1/", "http://localhost:11434/v1")]
    [InlineData(" https://openrouter.ai/api/v1 ", "https://openrouter.ai/api/v1")]
    [InlineData("https://api.openai.com/v1", "https://api.openai.com/v1")]
    public void KeepsHttpAndHttpsUrlsWithoutTheTrailingSlash(string input, string expected) => Assert.Equal(expected, OpenAIBaseUrl.Normalized(input));

    [Theory]
    [InlineData("ftp://example.com"), InlineData("localhost:11434"), InlineData("not a url"), InlineData("https://")]
    public void RejectsAnythingThatIsNotAnHttpUrl(string input) => Assert.Null(OpenAIBaseUrl.Normalized(input));

    [Fact]
    public void TellsOpenAIFromCompatibleServers()
    {
        Assert.True(OpenAIBaseUrl.IsOfficial("https://api.openai.com/v1"));
        Assert.False(OpenAIBaseUrl.IsOfficial("http://localhost:11434/v1"));
    }

    [Fact]
    public void OpenAINeedsAKeyOnlyOnItsOwnServerAndACompatibleServerNeedsAModel()
    {
        Assert.False(ProviderSetup.IsReady(TranslationProviderKind.OpenAI, false, OpenAIBaseUrl.Default, "gpt-6-luna"));
        Assert.True(ProviderSetup.IsReady(TranslationProviderKind.OpenAI, true, OpenAIBaseUrl.Default, "gpt-6-luna"));
        Assert.True(ProviderSetup.IsReady(TranslationProviderKind.OpenAI, false, "http://localhost:11434/v1", "llama3.2"));
        Assert.False(ProviderSetup.IsReady(TranslationProviderKind.OpenAI, true, "http://localhost:11434/v1", " "));
        Assert.True(ProviderSetup.IsReady(TranslationProviderKind.ClaudeCode, false, OpenAIBaseUrl.Default, ""));
        Assert.False(ProviderSetup.IsReady(TranslationProviderKind.ClaudeApi, false, OpenAIBaseUrl.Default, ""));
        Assert.True(ProviderSetup.IsReady(TranslationProviderKind.DeepL, true, OpenAIBaseUrl.Default, ""));
    }
}
