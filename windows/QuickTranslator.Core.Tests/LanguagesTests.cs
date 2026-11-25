using QuickTranslator.Core;

namespace QuickTranslator.Core.Tests;

public class LanguagesTests
{
    [Theory]
    [InlineData("es", "Spanish"), InlineData("en", "English"), InlineData("fr", "French"), InlineData("zh", "Chinese"), InlineData("ja", "Japanese")]
    public void NamesLanguagesInEnglishForTheServer(string code, string name) => Assert.Equal(name, Languages.EnglishName(code));

    [Fact]
    public void EverySupportedLanguageHasANameInEveryUILanguage()
    {
        foreach (var language in UILanguages.All)
        foreach (var code in Languages.SupportedCodes)
            Assert.NotEqual(code, Languages.Name(code, language));
        Assert.Equal(Languages.SupportedCodes.Count, Languages.SupportedCodes.Distinct().Count());
    }

    [Theory]
    [InlineData(UILanguage.Es, "Inglés"), InlineData(UILanguage.En, "English"), InlineData(UILanguage.Fr, "Anglais"),
     InlineData(UILanguage.De, "Englisch"), InlineData(UILanguage.It, "Inglese"), InlineData(UILanguage.Pt, "Inglês")]
    public void NamesLanguagesInTheAppLanguage(UILanguage language, string name) => Assert.Equal(name, Languages.DisplayName("en", language));

    [Fact]
    public void WritesNamesMidSentenceInLowercaseWhereTheLanguageDoes()
    {
        Assert.Equal("francés", Languages.Name("fr", UILanguage.Es));
        Assert.Equal("Französisch", Languages.Name("fr", UILanguage.De));
    }

    [Fact]
    public void TurnsTheEnglishNamesTheServerReturnsIntoTheAppLanguage()
    {
        Assert.Equal("Spanish", Languages.DisplayNameForEnglishName("Spanish", UILanguage.En));
        Assert.Equal("Espagnol", Languages.DisplayNameForEnglishName("spanish", UILanguage.Fr));
        Assert.Equal("Klingon", Languages.DisplayNameForEnglishName("Klingon", UILanguage.Es));
    }

    [Fact]
    public void SortsLanguagesByTheirNameInTheAppLanguageIgnoringAccents()
    {
        var sorted = Languages.SortedCodes(UILanguage.Es);
        Assert.Equal("de", sorted[0]);
        Assert.Equal("ar", sorted[1]);
        Assert.Equal(Languages.SupportedCodes.Count, sorted.Count);
    }
}

public class LanguagePairTests
{
    [Fact]
    public void DefaultsToSpanishAsYourLanguageAndEnglishAsTheTarget() =>
        Assert.Equal(new LanguagePair("es", "en"), LanguagePair.Default);

    [Fact]
    public void ChangingOneSideKeepsTheOther()
    {
        var pair = LanguagePair.Default;
        Assert.Equal(new LanguagePair("es", "fr"), pair.WithTarget("fr"));
        Assert.Equal(new LanguagePair("ca", "en"), pair.WithMine("ca"));
    }

    [Fact]
    public void ChoosingTheOtherSidesLanguageSwapsThem()
    {
        var pair = LanguagePair.Default;
        Assert.Equal(new LanguagePair("en", "es"), pair.WithTarget("es"));
        Assert.Equal(new LanguagePair("en", "es"), pair.WithMine("en"));
    }

    [Theory]
    [InlineData("es", "en", true), InlineData("es", "es", false), InlineData("es", "xx", false), InlineData("ca", "en", false)]
    public void IsValidOnlyWithTwoDifferentSupportedLanguages(string mine, string target, bool valid) =>
        Assert.Equal(valid, new LanguagePair(mine, target).IsValid);
}

public class LocalizationTests
{
    [Theory]
    [InlineData("es", UILanguage.Es), InlineData("en", UILanguage.En), InlineData("fr", UILanguage.Fr), InlineData("de", UILanguage.De),
     InlineData("it", UILanguage.It), InlineData("pt", UILanguage.Pt), InlineData("ja", UILanguage.En), InlineData("zh", UILanguage.En)]
    public void ShowsTheAppInMyLanguageWhenItHasATranslationElseInEnglish(string code, UILanguage expected) =>
        Assert.Equal(expected, UILanguages.ForLanguage(code));

    public static TheoryData<UILanguage> AllLanguages => [.. UILanguages.All];

    [Theory]
    [MemberData(nameof(AllLanguages))]
    public void EveryLanguageHasEveryText(UILanguage language)
    {
        var strings = language.Strings();
        foreach (var property in typeof(UIStrings).GetProperties())
        {
            var value = property.GetValue(strings);
            Assert.NotNull(value);
            if (value is string text) Assert.False(string.IsNullOrWhiteSpace(text), $"{language} {property.Name}");
        }
        Assert.Contains("boom", strings.ProviderFailed("OpenAI", "boom"));
        Assert.Contains("OpenAI", strings.ProviderFailed("OpenAI", "boom"));
        Assert.Contains("Ctrl+K", strings.ShortcutChanged("Ctrl+K"));
    }

    [Theory]
    [MemberData(nameof(AllLanguages))]
    public void HasNoMacOnlyWording(UILanguage language)
    {
        foreach (var property in typeof(UIStrings).GetProperties())
        {
            var value = property.GetValue(language.Strings());
            var text = value switch
            {
                string plain => plain,
                Func<string, string> one => one("X"),
                Func<string, string, string> two => two("X", "Y"),
                _ => "",
            };
            Assert.DoesNotContain("⌘", text);
            Assert.DoesNotContain("Info.plist", text);
            Assert.DoesNotContain(" Mac", text);
        }
    }

    [Theory]
    [InlineData(UILanguage.En), InlineData(UILanguage.Fr), InlineData(UILanguage.De), InlineData(UILanguage.It), InlineData(UILanguage.Pt)]
    public void EachLanguageIsActuallyTranslated(UILanguage language)
    {
        var strings = language.Strings();
        Assert.NotEqual(UIStrings.Es.TranslateSelection, strings.TranslateSelection);
        Assert.NotEqual(UIStrings.Es.LanguagesFooter, strings.LanguagesFooter);
        Assert.NotEqual(UIStrings.Es.TestSentence, strings.TestSentence);
        Assert.NotEqual(UIStrings.Es.OpenAtLogin, strings.OpenAtLogin);
    }

    [Fact]
    public void ExplainsErrorsInTheAppLanguage()
    {
        Assert.Equal("The DeepL key is missing. Add it in Settings.", ProviderErrorCode.MissingKey.Message(TranslationProviderKind.DeepL, "", UILanguage.En));
        Assert.Equal("Le processus de traduction s’est arrêté. Réessayez.", TranslatorException.ServerStopped().MessageIn(UILanguage.Fr));
        Assert.Equal("boom", TranslatorException.Failed("boom").MessageIn(UILanguage.En));
        Assert.Contains("paths.json", TranslatorException.NotConfigured().MessageIn(UILanguage.Es));
    }
}
