using System.Text.Json;
using System.Text.Json.Serialization;

namespace QuickTranslator.Core;

/// The texts in the popup's provider header.
public static class PopupText
{
    public static string Title(ProviderState state, TranslationProviderKind provider)
    {
        if (state is ProviderState.Done { Translation: var translation } && translation.Provider.ShowsModelName() && translation.Model is { } model)
            return $"{translation.Provider.DisplayName()} · {ModelName.DisplayName(model)}";
        return provider.DisplayName();
    }

    public static string Subtitle(ProviderState state, UILanguage language) => state is ProviderState.Done { Translation.Result: var result }
        ? $"{Languages.DisplayNameForEnglishName(result.SourceLanguage, language)} → {Languages.DisplayNameForEnglishName(result.TargetLanguage, language)}"
        : "";

    public static string? ElapsedText(ProviderState state, UILanguage language) =>
        state is ProviderState.Done { Translation.Elapsed: { } elapsed } ? Elapsed.Format(elapsed, language) : null;

    /// The one-off target indicator next to the globe ("JA"), or nothing for the configured pair.
    public static string TargetBadge(string? targetOverride) => targetOverride?.ToUpperInvariant() ?? "";

    public static string TargetHelp(string? targetOverride, UILanguage language) => targetOverride is null
        ? language.Strings().TranslateOnceHelp
        : language.Strings().TranslatingOnceTo(Languages.Name(targetOverride, language));
}

/// Where the app finds Node and the CLI: paths.json next to the executable, written by the build script.
public sealed record ServerPaths(
    [property: JsonPropertyName("nodePath")] string NodePath,
    [property: JsonPropertyName("cliPath")] string CliPath)
{
    public const string FileName = "paths.json";

    public static ServerPaths? Parse(string json)
    {
        try
        {
            var paths = JsonSerializer.Deserialize<ServerPaths>(json);
            return string.IsNullOrWhiteSpace(paths?.NodePath) || string.IsNullOrWhiteSpace(paths.CliPath) ? null : paths;
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
