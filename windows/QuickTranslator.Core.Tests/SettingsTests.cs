using QuickTranslator.Core;

namespace QuickTranslator.Core.Tests;

public class AppSettingsTests
{
    [Fact]
    public void UsesCtrlAltTUntilAnotherShortcutIsSaved()
    {
        Assert.Equal(Shortcut.Default, new AppSettings(new InMemorySettingsStore()).Shortcut);
    }

    [Fact]
    public void RemembersTheShortcutAcrossInstances()
    {
        var store = new InMemorySettingsStore();
        var shortcut = new Shortcut(0x4B, ShortcutModifiers.Control | ShortcutModifiers.Shift, "K");
        new AppSettings(store).Shortcut = shortcut;
        Assert.Equal(shortcut, new AppSettings(store).Shortcut);
    }

    [Theory]
    [InlineData("not json"), InlineData("""{"keyCode":84,"modifiers":0,"key":"T"}"""), InlineData("""{"keyCode":67,"modifiers":2,"key":"C"}""")]
    public void FallsBackToCtrlAltTWhenTheSavedShortcutIsCorruptOrInvalid(string json)
    {
        var store = new InMemorySettingsStore();
        store.Set(AppSettings.ShortcutKey, json);
        Assert.Equal(Shortcut.Default, new AppSettings(store).Shortcut);
    }

    [Fact]
    public void RemembersTheLanguagePairAndFallsBackWhenItIsInvalid()
    {
        var store = new InMemorySettingsStore();
        Assert.Equal(LanguagePair.Default, new AppSettings(store).LanguagePair);
        new AppSettings(store).LanguagePair = new LanguagePair("es", "fr");
        Assert.Equal(new LanguagePair("es", "fr"), new AppSettings(store).LanguagePair);
        store.Set(AppSettings.LanguagePairKey, """{"mine":"es","target":"es"}""");
        Assert.Equal(LanguagePair.Default, new AppSettings(store).LanguagePair);
        store.Set(AppSettings.LanguagePairKey, "{");
        Assert.Equal(LanguagePair.Default, new AppSettings(store).LanguagePair);
    }

    [Fact]
    public void UsesClaudeCodeAndHaikuUntilSomethingElseIsChosen()
    {
        var settings = new AppSettings(new InMemorySettingsStore());
        Assert.Equal(TranslationProviderKind.ClaudeCode, settings.Provider);
        Assert.Equal("claude-haiku-5-5", settings.ClaudeApiModel);
        Assert.Equal("gpt-6-luna", settings.OpenAIModel);
    }

    [Fact]
    public void RemembersTheProviderAndModelsAndIgnoresUnknownOnes()
    {
        var store = new InMemorySettingsStore();
        var settings = new AppSettings(store) { Provider = TranslationProviderKind.DeepL, ClaudeApiModel = "claude-sonnet-5-5" };
        Assert.Equal(TranslationProviderKind.DeepL, new AppSettings(store).Provider);
        Assert.Equal("claude-sonnet-5-5", new AppSettings(store).ClaudeApiModel);
        store.Set(AppSettings.ProviderKey, "gemini");
        store.Set(AppSettings.ClaudeApiModelKey, "claude-2");
        Assert.Equal(TranslationProviderKind.ClaudeCode, new AppSettings(store).Provider);
        Assert.Equal("claude-haiku-5-5", new AppSettings(store).ClaudeApiModel);
        Assert.NotNull(settings);
    }

    [Fact]
    public void KeepsOneModelForOpenAIAndAnotherForTheCompatibleServer()
    {
        var store = new InMemorySettingsStore();
        var settings = new AppSettings(store) { OpenAIModel = "gpt-6.1-terra" };
        settings.OpenAIBaseUrl = "http://localhost:11434/v1";
        Assert.Equal("", settings.OpenAIModel);
        settings.OpenAIModel = " llama3.2 ";
        Assert.Equal("llama3.2", new AppSettings(store).OpenAIModel);
        settings.OpenAIBaseUrl = "";
        Assert.Equal("gpt-6.1-terra", new AppSettings(store).OpenAIModel);
    }

    [Fact]
    public void UsesOpenAIsUrlByDefaultAndWhenTheFieldIsLeftEmpty()
    {
        var store = new InMemorySettingsStore();
        var settings = new AppSettings(store);
        Assert.Equal("https://api.openai.com/v1", settings.OpenAIBaseUrl);
        settings.OpenAIBaseUrl = "http://localhost:11434/v1/";
        Assert.Equal("http://localhost:11434/v1", new AppSettings(store).OpenAIBaseUrl);
        settings.OpenAIBaseUrl = " ";
        Assert.Equal("https://api.openai.com/v1", new AppSettings(store).OpenAIBaseUrl);
        Assert.Null(store.Get(AppSettings.OpenAIBaseUrlKey));
    }

    [Fact]
    public void JsonFileStorePersistsAcrossInstancesAndSurvivesACorruptFile()
    {
        var directory = Path.Combine(Path.GetTempPath(), "qt-tests-" + Guid.NewGuid());
        var path = Path.Combine(directory, "settings.json");
        try
        {
            new JsonFileSettingsStore(path).Set("a", "1");
            Assert.Equal("1", new JsonFileSettingsStore(path).Get("a"));
            var store = new JsonFileSettingsStore(path);
            store.Set("a", null);
            Assert.Null(new JsonFileSettingsStore(path).Get("a"));
            File.WriteAllText(path, "{ broken");
            Assert.Null(new JsonFileSettingsStore(path).Get("a"));
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public void ReadsTheServerPathsWrittenByTheBuildScript()
    {
        Assert.Equal(new ServerPaths("C:\\node\\node.exe", "C:\\repo\\cli\\dist\\cli.js"),
            ServerPaths.Parse("""{"nodePath":"C:\\node\\node.exe","cliPath":"C:\\repo\\cli\\dist\\cli.js"}"""));
        Assert.Null(ServerPaths.Parse("""{"nodePath":""}"""));
        Assert.Null(ServerPaths.Parse("nope"));
    }
}
