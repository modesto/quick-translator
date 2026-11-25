using System.Text.Json.Serialization;

namespace QuickTranslator.Core;

public static class Languages
{
    public static readonly IReadOnlyList<string> SupportedCodes =
    [
        "es", "en", "fr", "de", "it", "pt", "nl", "pl", "ru", "uk", "tr", "ar", "hi", "id", "ja", "ko", "th", "vi", "zh",
    ];

    // Names as written mid-sentence, in each UI language: es, en, fr, de, it, pt.
    private static readonly Dictionary<string, string[]> Names = new()
    {
        ["es"] = ["español", "Spanish", "espagnol", "Spanisch", "spagnolo", "espanhol"],
        ["en"] = ["inglés", "English", "anglais", "Englisch", "inglese", "inglês"],
        ["fr"] = ["francés", "French", "français", "Französisch", "francese", "francês"],
        ["de"] = ["alemán", "German", "allemand", "Deutsch", "tedesco", "alemão"],
        ["it"] = ["italiano", "Italian", "italien", "Italienisch", "italiano", "italiano"],
        ["pt"] = ["portugués", "Portuguese", "portugais", "Portugiesisch", "portoghese", "português"],
        ["nl"] = ["neerlandés", "Dutch", "néerlandais", "Niederländisch", "olandese", "neerlandês"],
        ["pl"] = ["polaco", "Polish", "polonais", "Polnisch", "polacco", "polaco"],
        ["ru"] = ["ruso", "Russian", "russe", "Russisch", "russo", "russo"],
        ["uk"] = ["ucraniano", "Ukrainian", "ukrainien", "Ukrainisch", "ucraino", "ucraniano"],
        ["tr"] = ["turco", "Turkish", "turc", "Türkisch", "turco", "turco"],
        ["ar"] = ["árabe", "Arabic", "arabe", "Arabisch", "arabo", "árabe"],
        ["hi"] = ["hindi", "Hindi", "hindi", "Hindi", "hindi", "hindi"],
        ["id"] = ["indonesio", "Indonesian", "indonésien", "Indonesisch", "indonesiano", "indonésio"],
        ["ja"] = ["japonés", "Japanese", "japonais", "Japanisch", "giapponese", "japonês"],
        ["ko"] = ["coreano", "Korean", "coréen", "Koreanisch", "coreano", "coreano"],
        ["th"] = ["tailandés", "Thai", "thaï", "Thailändisch", "thailandese", "tailandês"],
        ["vi"] = ["vietnamita", "Vietnamese", "vietnamien", "Vietnamesisch", "vietnamita", "vietnamita"],
        ["zh"] = ["chino", "Chinese", "chinois", "Chinesisch", "cinese", "chinês"],
    };

    /// The language name as written mid-sentence ("francés").
    public static string Name(string code, UILanguage language) =>
        Names.TryGetValue(code, out var names) ? names[(int)language] : code;

    public static string Name(string code) => Name(code, L10n.Language);

    /// The language name for lists ("Francés").
    public static string DisplayName(string code, UILanguage language)
    {
        var name = Name(code, language);
        return name.Length == 0 ? name : char.ToUpper(name[0], language.Culture()) + name[1..];
    }

    public static string DisplayName(string code) => DisplayName(code, L10n.Language);

    /// Turns the English names the server returns ("Spanish") into the UI language.
    public static string DisplayNameForEnglishName(string englishName, UILanguage language)
    {
        var wanted = englishName.Trim();
        var code = SupportedCodes.FirstOrDefault(code => string.Equals(EnglishName(code), wanted, StringComparison.OrdinalIgnoreCase));
        return code is null ? englishName : DisplayName(code, language);
    }

    public static string EnglishName(string code) => Name(code, UILanguage.En);

    /// The supported codes sorted by their display name in the UI language.
    public static IReadOnlyList<string> SortedCodes(UILanguage language)
    {
        var comparer = StringComparer.Create(language.Culture(), ignoreCase: true);
        return SupportedCodes.OrderBy(code => DisplayName(code, language), comparer).ToList();
    }
}

/// "Mine" and "target": text in "mine" goes to "target", anything else to "mine".
public sealed record LanguagePair(
    [property: JsonPropertyName("mine")] string Mine,
    [property: JsonPropertyName("target")] string Target)
{
    public static readonly LanguagePair Default = new("es", "en");

    [JsonIgnore]
    public bool IsValid =>
        Mine != Target && Languages.SupportedCodes.Contains(Mine) && Languages.SupportedCodes.Contains(Target);

    public LanguagePair WithMine(string code) => code == Target ? new(code, Mine) : this with { Mine = code };

    public LanguagePair WithTarget(string code) => code == Mine ? new(Target, code) : this with { Target = code };
}
