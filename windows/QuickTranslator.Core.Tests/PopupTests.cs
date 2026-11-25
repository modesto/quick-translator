using QuickTranslator.Core;

namespace QuickTranslator.Core.Tests;

public class PopupPlacementTests
{
    private static readonly ScreenArea Primary = new(new PixelRect(0, 0, 1920, 1080), new PixelRect(0, 0, 1920, 1032));
    private static readonly ScreenArea Right = new(new PixelRect(1920, -200, 2560, 1440), new PixelRect(1920, -200, 2560, 1392));
    private static readonly PixelSize Size = new(440, 300);

    [Fact]
    public void GoesBelowTheSelectionWhenItFits()
    {
        var origin = PopupPlacement.Origin(Size, new PixelRect(200, 100, 300, 20), [Primary]);
        Assert.Equal(new PixelPoint(200, 120 + PopupPlacement.Gap), origin);
    }

    [Fact]
    public void FlipsAboveASelectionNearTheBottomOfTheScreen()
    {
        var origin = PopupPlacement.Origin(Size, new PixelRect(200, 900, 300, 20), [Primary]);
        Assert.Equal(new PixelPoint(200, 900 - PopupPlacement.Gap - 300), origin);
    }

    [Fact]
    public void PinsToTheTopWhenItFitsNeitherBelowNorAbove()
    {
        var origin = PopupPlacement.Origin(new PixelSize(440, 700), new PixelRect(200, 400, 300, 200), [Primary]);
        Assert.Equal(PopupPlacement.Margin, origin.Y);
    }

    [Fact]
    public void StaysInsideTheRightAndLeftEdges()
    {
        Assert.Equal(1920 - PopupPlacement.Margin - 440, PopupPlacement.Origin(Size, new PixelRect(1800, 100, 50, 20), [Primary]).X);
        Assert.Equal(PopupPlacement.Margin, PopupPlacement.Origin(Size, new PixelRect(0, 100, 50, 20), [Primary]).X);
    }

    [Fact]
    public void UsesTheScreenThatHoldsTheSelection()
    {
        var origin = PopupPlacement.Origin(Size, new PixelRect(4400, -100, 50, 20), [Primary, Right]);
        Assert.Equal(new PixelPoint(1920 + 2560 - PopupPlacement.Margin - 440, -80 + PopupPlacement.Gap), origin);
    }

    [Fact]
    public void FallsBackToThePrimaryScreenWhenTheSelectionIsOffEveryScreen()
    {
        var origin = PopupPlacement.Origin(Size, new PixelRect(9000, 100, 50, 20), [Right, Primary], Primary);
        Assert.Equal(1920 - PopupPlacement.Margin - 440, origin.X);
    }

    [Fact]
    public void TreatsAZeroSizeAnchorSuchAsTheMousePositionLikeASelection()
    {
        Assert.Equal(new PixelPoint(700, 500 + PopupPlacement.Gap), PopupPlacement.Origin(Size, new PixelRect(700, 500, 0, 0), [Primary]));
    }

    [Fact]
    public void FlipsAboveASelectionJustAboveTheTaskbarWithoutCrossingIt()
    {
        var origin = PopupPlacement.Origin(new PixelSize(440, 420), new PixelRect(300, 1000, 400, 24), [Primary]);
        Assert.Equal(1000 - PopupPlacement.Gap - 420, origin.Y);
        Assert.True(origin.Y + 420 <= Primary.WorkArea.Bottom);
    }

    [Fact]
    public void ClampKeepsAMovedPopupThatFitsWhereItIs()
    {
        Assert.Equal(new PixelPoint(500, 300), PopupPlacement.Clamp(new PixelPoint(500, 300), Size, [Primary]));
    }

    [Fact]
    public void ClampPullsAPopupThatGrewPastTheBottomBackAboveTheTaskbar()
    {
        var origin = PopupPlacement.Clamp(new PixelPoint(500, 900), Size, [Primary]);
        Assert.Equal(new PixelPoint(500, 1032 - PopupPlacement.Margin - 300), origin);
    }

    [Fact]
    public void ClampKeepsItInsideTheSidesAndPinsATooTallPopupToTheTop()
    {
        Assert.Equal(1920 - PopupPlacement.Margin - 440, PopupPlacement.Clamp(new PixelPoint(1700, 100), Size, [Primary]).X);
        Assert.Equal(PopupPlacement.Margin, PopupPlacement.Clamp(new PixelPoint(-50, 100), Size, [Primary]).X);
        Assert.Equal(PopupPlacement.Margin, PopupPlacement.Clamp(new PixelPoint(100, 100), new PixelSize(440, 2000), [Primary]).Y);
    }

    [Fact]
    public void ClampUsesTheMonitorThePopupWasMovedTo()
    {
        var origin = PopupPlacement.Clamp(new PixelPoint(3000, 1100), Size, [Primary, Right], Primary, scale: 2);
        Assert.Equal(new PixelPoint(3000, -200 + 1392 - PopupPlacement.Margin * 2 - 300), origin);
    }

    [Fact]
    public void ScalesTheMarginAndGapToTheMonitor()
    {
        var origin = PopupPlacement.Origin(Size, new PixelRect(0, 100, 50, 20), [Primary], scale: 1.5);
        Assert.Equal(new PixelPoint(PopupPlacement.Margin * 1.5, 120 + PopupPlacement.Gap * 1.5), origin);
    }
}

public class PopupTextTests
{
    private static readonly ProviderTranslation Translation = new(
        new TranslationResult("Spanish", "English", [new("Natural", "See you later"), new("Casual", "Catch you later"), new("Formal", "I will see you later")]),
        "claude-sonnet-5-5", TranslationProviderKind.ClaudeApi, TimeSpan.FromSeconds(1.04));

    [Fact]
    public void KeysPickTheVariantsInOrder()
    {
        var done = new ProviderState.Done(Translation);
        Assert.Equal("See you later", ChoiceKeys.Text(1, done));
        Assert.Equal("I will see you later", ChoiceKeys.Text(3, done));
    }

    [Theory]
    [InlineData(0), InlineData(4), InlineData(-1)]
    public void KeysBeyondTheVariantsOrBelowOneDoNothing(int key) => Assert.Null(ChoiceKeys.Text(key, new ProviderState.Done(Translation)));

    [Fact]
    public void KeysDoNothingWhileThereIsNoResult()
    {
        Assert.Null(ChoiceKeys.Text(1, new ProviderState.Loading()));
        Assert.Null(ChoiceKeys.Text(1, new ProviderState.Failed("x")));
    }

    [Fact]
    public void ShowsTheModelLanguagesAndTimeOfTheAnswer()
    {
        var done = new ProviderState.Done(Translation);
        Assert.Equal("Claude API · Claude Sonnet 5.5", PopupText.Title(done, TranslationProviderKind.ClaudeCode));
        Assert.Equal("Español → Inglés", PopupText.Subtitle(done, UILanguage.Es));
        Assert.Equal("1,0 s", PopupText.ElapsedText(done, UILanguage.Es));
    }

    [Fact]
    public void ShowsOnlyTheProviderNameWhileLoadingAndForDeepL()
    {
        Assert.Equal("OpenAI", PopupText.Title(new ProviderState.Loading(), TranslationProviderKind.OpenAI));
        Assert.Equal("", PopupText.Subtitle(new ProviderState.Loading(), UILanguage.Es));
        Assert.Null(PopupText.ElapsedText(new ProviderState.Loading(), UILanguage.Es));
        var deepL = new ProviderState.Done(Translation with { Provider = TranslationProviderKind.DeepL, Model = "deepl" });
        Assert.Equal("DeepL", PopupText.Title(deepL, TranslationProviderKind.DeepL));
    }

    [Fact]
    public void DescribesTheOneOffTarget()
    {
        Assert.Equal("", PopupText.TargetBadge(null));
        Assert.Equal("JA", PopupText.TargetBadge("ja"));
        Assert.Equal("Traducir a otro idioma solo esta vez", PopupText.TargetHelp(null, UILanguage.Es));
        Assert.Equal("Traduciendo a japonés solo esta vez", PopupText.TargetHelp("ja", UILanguage.Es));
    }

    [Theory]
    [InlineData("claude-haiku-5-5", "Claude Haiku 5.5"), InlineData("claude-opus-5", "Claude Opus 5"), InlineData("claude-sonnet", "Claude Sonnet")]
    [InlineData("gpt-6-luna", "GPT-6 Luna"), InlineData("gpt-6.2-sol", "GPT-6.2 Sol"), InlineData("claude", "claude"), InlineData("my-model", "my-model")]
    public void FormatsModelIds(string id, string expected) => Assert.Equal(expected, ModelName.DisplayName(id));
}
