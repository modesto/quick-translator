using System.Text.Json;

namespace QuickTranslator.Core;

public interface ISettingsStore
{
    string? Get(string key);
    void Set(string key, string? value);
}

public sealed class InMemorySettingsStore : ISettingsStore
{
    private readonly Dictionary<string, string> values = [];

    public string? Get(string key) => values.GetValueOrDefault(key);

    public void Set(string key, string? value)
    {
        if (value is null) values.Remove(key);
        else values[key] = value;
    }
}

/// Settings in a JSON object of strings, written atomically on every change.
public sealed class JsonFileSettingsStore : ISettingsStore
{
    private readonly string path;
    private readonly Dictionary<string, string> values;
    private readonly Lock gate = new();

    public JsonFileSettingsStore(string path)
    {
        this.path = path;
        values = Load(path);
    }

    public static string DefaultPath =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "QuickTranslator", "settings.json");

    public string? Get(string key)
    {
        lock (gate) return values.GetValueOrDefault(key);
    }

    public void Set(string key, string? value)
    {
        lock (gate)
        {
            if (value is null) values.Remove(key);
            else values[key] = value;
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var temporary = path + ".tmp";
            File.WriteAllText(temporary, JsonSerializer.Serialize(values, new JsonSerializerOptions { WriteIndented = true }));
            File.Move(temporary, path, overwrite: true);
        }
    }

    private static Dictionary<string, string> Load(string path)
    {
        try
        {
            return File.Exists(path) ? JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(path)) ?? [] : [];
        }
        catch (Exception exception) when (exception is JsonException or IOException or UnauthorizedAccessException)
        {
            return [];
        }
    }
}

public sealed class AppSettings(ISettingsStore store)
{
    public const string ShortcutKey = "translateShortcut";
    public const string LanguagePairKey = "languagePair";
    public const string ProviderKey = "translationProvider";
    public const string ClaudeApiModelKey = "claudeAPIModel";
    public const string OpenAIModelKey = "openAIModel";
    public const string OpenAIBaseUrlKey = "openAIBaseURL";
    public const string CompatibleModelKey = "openAICompatibleModel";

    public TranslationProviderKind Provider
    {
        get => TranslationProviders.FromRawValue(store.Get(ProviderKey)) ?? TranslationProviderKind.ClaudeCode;
        set => store.Set(ProviderKey, value.RawValue());
    }

    public string ClaudeApiModel
    {
        get => ModelOption.Validated(store.Get(ClaudeApiModelKey), ModelOption.Claude);
        set => store.Set(ClaudeApiModelKey, value);
    }

    /// One model for OpenAI and another for the compatible server; OpenAI falls back to its first model.
    public string OpenAIModel
    {
        get
        {
            var official = Core.OpenAIBaseUrl.IsOfficial(OpenAIBaseUrl);
            var stored = store.Get(official ? OpenAIModelKey : CompatibleModelKey)?.Trim() ?? "";
            return stored.Length == 0 && official ? ModelOption.OpenAI[0].Id : stored;
        }
        set => store.Set(Core.OpenAIBaseUrl.IsOfficial(OpenAIBaseUrl) ? OpenAIModelKey : CompatibleModelKey, value.Trim());
    }

    public string OpenAIBaseUrl
    {
        get => store.Get(OpenAIBaseUrlKey) is { } stored ? Core.OpenAIBaseUrl.Normalized(stored) ?? Core.OpenAIBaseUrl.Default : Core.OpenAIBaseUrl.Default;
        set
        {
            var normalized = Core.OpenAIBaseUrl.Normalized(value) ?? Core.OpenAIBaseUrl.Default;
            store.Set(OpenAIBaseUrlKey, normalized == Core.OpenAIBaseUrl.Default ? null : normalized);
        }
    }

    public Shortcut Shortcut
    {
        get
        {
            var shortcut = Decode<Shortcut>(store.Get(ShortcutKey));
            return shortcut is not null && shortcut.Key is not null && ShortcutValidator.Validate(shortcut, UILanguage.En) is null
                ? shortcut
                : Shortcut.Default;
        }
        set => store.Set(ShortcutKey, JsonSerializer.Serialize(value));
    }

    public LanguagePair LanguagePair
    {
        get => Decode<LanguagePair>(store.Get(LanguagePairKey)) is { Mine: not null, Target: not null, IsValid: true } pair ? pair : LanguagePair.Default;
        set => store.Set(LanguagePairKey, JsonSerializer.Serialize(value));
    }

    private static T? Decode<T>(string? json) where T : class
    {
        if (json is null) return null;
        try { return JsonSerializer.Deserialize<T>(json); }
        catch (JsonException) { return null; }
    }
}
