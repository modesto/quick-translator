using System.Globalization;

namespace QuickTranslator.Core;

public enum TranslationProviderKind { ClaudeCode, ClaudeApi, OpenAI, DeepL }

public sealed record KeyPage(string Title, string Url);

public static class TranslationProviders
{
    public static IReadOnlyList<TranslationProviderKind> All { get; } = Enum.GetValues<TranslationProviderKind>();

    /// The id the CLI uses.
    public static string RawValue(this TranslationProviderKind kind) => kind switch
    {
        TranslationProviderKind.ClaudeCode => "claude-code",
        TranslationProviderKind.ClaudeApi => "claude-api",
        TranslationProviderKind.OpenAI => "openai",
        TranslationProviderKind.DeepL => "deepl",
        _ => throw new ArgumentOutOfRangeException(nameof(kind)),
    };

    public static TranslationProviderKind? FromRawValue(string? value) =>
        All.Cast<TranslationProviderKind?>().FirstOrDefault(kind => kind!.Value.RawValue() == value);

    public static string DisplayName(this TranslationProviderKind kind) => kind switch
    {
        TranslationProviderKind.ClaudeCode => "Claude Code",
        TranslationProviderKind.ClaudeApi => "Claude API",
        TranslationProviderKind.OpenAI => "OpenAI",
        TranslationProviderKind.DeepL => "DeepL",
        _ => kind.ToString(),
    };

    public static string? KeyAccount(this TranslationProviderKind kind) => kind switch
    {
        TranslationProviderKind.ClaudeApi => "anthropic-api-key",
        TranslationProviderKind.OpenAI => "openai-api-key",
        TranslationProviderKind.DeepL => "deepl-auth-key",
        _ => null,
    };

    /// Never ANTHROPIC_API_KEY: the Claude Code subprocess would switch from the user's login to API billing.
    public static string? KeyEnvironmentVariable(this TranslationProviderKind kind) => kind switch
    {
        TranslationProviderKind.ClaudeApi => "QT_ANTHROPIC_API_KEY",
        TranslationProviderKind.OpenAI => "QT_OPENAI_API_KEY",
        TranslationProviderKind.DeepL => "QT_DEEPL_AUTH_KEY",
        _ => null,
    };

    public static KeyPage? KeyPage(this TranslationProviderKind kind, UILanguage language)
    {
        var strings = language.Strings();
        return kind switch
        {
            TranslationProviderKind.ClaudeApi => new(strings.CreateKeyAt("platform.claude.com"), "https://platform.claude.com/settings/keys"),
            TranslationProviderKind.OpenAI => new(strings.CreateKeyAt("platform.openai.com"), "https://platform.openai.com/api-keys"),
            TranslationProviderKind.DeepL => new(strings.GetDeepLKey, "https://www.deepl.com/pro-api"),
            _ => null,
        };
    }

    public static bool ShowsModelName(this TranslationProviderKind kind) => kind != TranslationProviderKind.DeepL;
}

public enum ModelNote { Fastest, FastestCheapest, MoreQuality, BestQuality }

public sealed record ModelOption(string Id, ModelNote Note)
{
    public string DisplayName => ModelName.DisplayName(Id);

    public string NoteText(UILanguage language)
    {
        var strings = language.Strings();
        return Note switch
        {
            ModelNote.Fastest => strings.Fastest,
            ModelNote.FastestCheapest => strings.FastestCheapest,
            ModelNote.MoreQuality => strings.MoreQuality,
            _ => strings.BestQuality,
        };
    }

    public static readonly IReadOnlyList<ModelOption> Claude =
    [
        new("claude-haiku-5-5", ModelNote.Fastest),
        new("claude-sonnet-5-5", ModelNote.MoreQuality),
        new("claude-opus-5-5", ModelNote.BestQuality),
    ];

    public static readonly IReadOnlyList<ModelOption> OpenAI =
    [
        new("gpt-6-luna", ModelNote.FastestCheapest),
        new("gpt-6.1-terra", ModelNote.MoreQuality),
        new("gpt-6.2-sol", ModelNote.BestQuality),
    ];

    public static string Validated(string? id, IReadOnlyList<ModelOption> options) =>
        options.FirstOrDefault(option => option.Id == id)?.Id ?? options[0].Id;
}

public static class OpenAIBaseUrl
{
    public const string Default = "https://api.openai.com/v1";

    /// Empty means OpenAI itself; anything else must be an http(s) URL.
    public static string? Normalized(string input)
    {
        var trimmed = input.Trim().TrimEnd('/');
        if (trimmed.Length == 0) return Default;
        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var url)
            || (url.Scheme != Uri.UriSchemeHttp && url.Scheme != Uri.UriSchemeHttps)
            || string.IsNullOrEmpty(url.Host)) return null;
        if (IsOfficial(trimmed) && url.AbsolutePath == "/") return Default;
        return trimmed;
    }

    public static bool IsOfficial(string url) =>
        Uri.TryCreate(url, UriKind.Absolute, out var parsed) && parsed.Host.Equals("api.openai.com", StringComparison.OrdinalIgnoreCase);
}

public static class ProviderSetup
{
    public static bool IsReady(TranslationProviderKind provider, bool hasKey, string openAIBaseUrl, string openAIModel) => provider switch
    {
        TranslationProviderKind.ClaudeCode => true,
        TranslationProviderKind.OpenAI => OpenAIBaseUrl.IsOfficial(openAIBaseUrl) ? hasKey : openAIModel.Trim().Length > 0,
        _ => hasKey,
    };
}

public interface ISecretStore
{
    string? Secret(string account);
    void SetSecret(string? value, string account);
}

public sealed class InMemorySecretStore(Dictionary<string, string>? values = null) : ISecretStore
{
    private readonly Dictionary<string, string> values = values ?? [];

    public string? Secret(string account) => values.GetValueOrDefault(account);

    public void SetSecret(string? value, string account)
    {
        if (value is null) values.Remove(account);
        else values[account] = value;
    }
}

public static class ServerLaunch
{
    public static IReadOnlyList<string> Arguments(string cliPath, TranslationProviderKind provider, string claudeApiModel, string openAIModel, string openAIBaseUrl = OpenAIBaseUrl.Default)
    {
        var arguments = new List<string> { cliPath, "--server", "--provider", provider.RawValue(), "--api-model", claudeApiModel, "--openai-model", openAIModel };
        if (openAIBaseUrl != OpenAIBaseUrl.Default) arguments.AddRange(["--openai-base-url", openAIBaseUrl]);
        return arguments;
    }

    /// Passes the saved keys as QT_ variables and drops stale or empty ones.
    public static void ApplyKeys(IDictionary<string, string?> environment, ISecretStore secrets)
    {
        foreach (var provider in TranslationProviders.All)
        {
            if (provider.KeyEnvironmentVariable() is not { } variable) continue;
            var key = provider.KeyAccount() is { } account ? secrets.Secret(account)?.Trim() : null;
            if (string.IsNullOrEmpty(key)) environment.Remove(variable);
            else environment[variable] = key;
        }
    }
}

public enum ProviderErrorCode { MissingKey, AuthFailed, QuotaExceeded, RateLimited, UnsupportedLanguage, Refused, Network, ProviderError }

public static class ProviderErrorCodes
{
    private static readonly Dictionary<string, ProviderErrorCode> RawValues = new()
    {
        ["missing_key"] = ProviderErrorCode.MissingKey,
        ["auth_failed"] = ProviderErrorCode.AuthFailed,
        ["quota_exceeded"] = ProviderErrorCode.QuotaExceeded,
        ["rate_limited"] = ProviderErrorCode.RateLimited,
        ["unsupported_language"] = ProviderErrorCode.UnsupportedLanguage,
        ["refused"] = ProviderErrorCode.Refused,
        ["network"] = ProviderErrorCode.Network,
        ["provider_error"] = ProviderErrorCode.ProviderError,
    };

    public static ProviderErrorCode? FromRawValue(string? value) =>
        value is not null && RawValues.TryGetValue(value, out var code) ? code : null;

    public static bool OpensSettings(this ProviderErrorCode code) =>
        code is ProviderErrorCode.MissingKey or ProviderErrorCode.AuthFailed;

    public static string Message(this ProviderErrorCode code, TranslationProviderKind provider, string detail, UILanguage language)
    {
        var name = provider.DisplayName();
        var strings = language.Strings();
        return code switch
        {
            ProviderErrorCode.MissingKey => strings.MissingKey(name),
            ProviderErrorCode.AuthFailed => strings.AuthFailed(name),
            ProviderErrorCode.QuotaExceeded => strings.QuotaExceeded(name),
            ProviderErrorCode.RateLimited => strings.RateLimited(name),
            ProviderErrorCode.UnsupportedLanguage => strings.UnsupportedLanguage(name),
            ProviderErrorCode.Refused => strings.Refused(name),
            ProviderErrorCode.Network => strings.Network(name),
            _ => strings.ProviderFailed(name, detail),
        };
    }
}

public static class Elapsed
{
    public static string Format(TimeSpan elapsed, UILanguage language)
    {
        var seconds = Math.Max(elapsed.TotalSeconds, 0);
        return seconds.ToString("0.0", language.Culture()) + " s";
    }
}
