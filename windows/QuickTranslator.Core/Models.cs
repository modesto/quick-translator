using System.Text.Json.Serialization;

namespace QuickTranslator.Core;

public sealed record TranslationVariant(
    [property: JsonPropertyName("label")] string Label,
    [property: JsonPropertyName("text")] string Text);

public sealed record TranslationResult(
    [property: JsonPropertyName("sourceLanguage")] string SourceLanguage,
    [property: JsonPropertyName("targetLanguage")] string TargetLanguage,
    [property: JsonPropertyName("variants")] IReadOnlyList<TranslationVariant> Variants)
{
    public bool Equals(TranslationResult? other) =>
        other is not null
        && SourceLanguage == other.SourceLanguage
        && TargetLanguage == other.TargetLanguage
        && Variants.SequenceEqual(other.Variants);

    public override int GetHashCode() => HashCode.Combine(SourceLanguage, TargetLanguage, Variants.Count);
}

public sealed record ProviderTranslation(
    TranslationResult Result,
    string? Model,
    TranslationProviderKind Provider = TranslationProviderKind.ClaudeCode,
    TimeSpan? Elapsed = null);

/// What the popup shows for the provider.
public abstract record ProviderState
{
    private ProviderState() { }

    public sealed record Loading : ProviderState;
    public sealed record Done(ProviderTranslation Translation) : ProviderState;
    public sealed record Failed(string Message, bool OffersSettings = false) : ProviderState;
}

public enum TranslatorErrorKind { NotConfigured, ServerStopped, Failed, Provider }

public sealed class TranslatorException : Exception, IEquatable<TranslatorException>
{
    private readonly string? detail;

    private TranslatorException(TranslatorErrorKind kind, string? detail, ProviderErrorCode? code = null, TranslationProviderKind provider = TranslationProviderKind.ClaudeCode)
    {
        Kind = kind;
        this.detail = detail;
        Code = code;
        Provider = provider;
    }

    public TranslatorErrorKind Kind { get; }
    public ProviderErrorCode? Code { get; }
    public TranslationProviderKind Provider { get; }
    public string Detail => detail ?? "";

    public static TranslatorException NotConfigured() => new(TranslatorErrorKind.NotConfigured, null);
    public static TranslatorException ServerStopped() => new(TranslatorErrorKind.ServerStopped, null);
    public static TranslatorException Failed(string message) => new(TranslatorErrorKind.Failed, message);
    public static TranslatorException ForProvider(ProviderErrorCode code, TranslationProviderKind provider, string detail) =>
        new(TranslatorErrorKind.Provider, detail, code, provider);

    public bool OpensSettings => Code?.OpensSettings() ?? false;

    public override string Message => MessageIn(L10n.Language);

    public string MessageIn(UILanguage language) => Kind switch
    {
        TranslatorErrorKind.NotConfigured => language.Strings().CliNotFound,
        TranslatorErrorKind.ServerStopped => language.Strings().ServerStopped,
        TranslatorErrorKind.Provider when Code is { } code => code.Message(Provider, Detail, language),
        _ => Detail,
    };

    public bool Equals(TranslatorException? other) =>
        other is not null && Kind == other.Kind && Code == other.Code && Provider == other.Provider && Detail == other.Detail;

    public override bool Equals(object? obj) => Equals(obj as TranslatorException);

    public override int GetHashCode() => HashCode.Combine(Kind, Code, Provider, Detail);

    public override string ToString() => $"{Kind} {Code} {Provider} {Detail}";
}

/// Keys 1… pick the variants in order.
public static class ChoiceKeys
{
    public const int First = 1;

    public static string? Text(int key, ProviderState state)
    {
        if (state is not ProviderState.Done done) return null;
        var index = key - First;
        var variants = done.Translation.Result.Variants;
        return index >= 0 && index < variants.Count ? variants[index].Text : null;
    }
}

public static class ModelName
{
    public static string DisplayName(string id)
    {
        var parts = id.Split('-');
        if (parts.Length >= 2 && parts[0] == "gpt")
            return string.Join(' ', new[] { $"GPT-{parts[1]}" }.Concat(parts.Skip(2).Select(Capitalize)));
        if (parts.Length < 2 || parts[0] != "claude") return id;
        var family = Capitalize(parts[1]);
        var version = string.Join('.', parts.Skip(2));
        return version.Length == 0 ? $"Claude {family}" : $"Claude {family} {version}";
    }

    private static string Capitalize(string word) =>
        word.Length == 0 ? word : char.ToUpperInvariant(word[0]) + word[1..].ToLowerInvariant();
}
