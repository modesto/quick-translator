using System.Globalization;

namespace QuickTranslator.Core;

public enum UILanguage { Es, En, Fr, De, It, Pt }

public static class UILanguages
{
    public static IReadOnlyList<UILanguage> All { get; } = Enum.GetValues<UILanguage>();

    /// The app shows itself in "my" language when it has a translation, else in English.
    public static UILanguage ForLanguage(string code) =>
        All.FirstOrDefault(language => language.Code() == code, UILanguage.En);

    public static string Code(this UILanguage language) => language.ToString().ToLowerInvariant();

    public static CultureInfo Culture(this UILanguage language) => CultureInfo.GetCultureInfo(language.Code());

    public static UIStrings Strings(this UILanguage language) => language switch
    {
        UILanguage.Es => UIStrings.Es,
        UILanguage.En => UIStrings.En,
        UILanguage.Fr => UIStrings.Fr,
        UILanguage.De => UIStrings.De,
        UILanguage.It => UIStrings.It,
        UILanguage.Pt => UIStrings.Pt,
        _ => UIStrings.En,
    };
}

/// The current UI language. It is global: tests never change it and pass a UILanguage explicitly instead.
public static class L10n
{
    private static volatile int current = (int)UILanguage.Es;

    public static UILanguage Language
    {
        get => (UILanguage)current;
        set => current = (int)value;
    }

    public static UIStrings Strings => Language.Strings();
}
