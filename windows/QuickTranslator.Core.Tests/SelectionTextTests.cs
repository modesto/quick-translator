using QuickTranslator.Core;

namespace QuickTranslator.Core.Tests;

public class SelectionTextTests
{
    private const string TeamsHtml = """<meta charset='utf-8'><span data-teams="true">si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis """ + "\u2060" + """<readonly contenteditable="false" title="Sweat grinning" itemid="sweatgrinning" itemtype="http://schema.skype.com/Emoji" itemscope="😅" aria-label="Sweat grinning" data-announcement="Sweat grinning emoji"><img style="margin:0px 1px;" src="https://statics.teams.cdn.office.net/x/50_f.png?v=v30" alt="Sweat grinning" draggable="false" width="20px" height="20px" aria-label="Sweat grinning"></readonly>?</span>""";

    [Fact]
    public void RecoversTeamsEmojiFromTheCopiedHtml()
    {
        Assert.Equal("si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis 😅?", SelectionText.PlainTextFromHtml(TeamsHtml));
    }

    [Fact]
    public void PrefersTheCopiedHtmlOverThePlainTextTeamsGives()
    {
        var text = SelectionText.Best(TeamsHtml, "si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis \n\nSweat grinning\n\n?");
        Assert.Equal("si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis 😅?", text);
    }

    [Fact]
    public void IgnoresHtmlWithoutEmojiMarkupSoItsSourceWhitespaceNeverLeaksIn()
    {
        const string html = "<div>\n    <span>Hola equipo</span>\n</div>";
        Assert.False(SelectionText.ContainsEmojiMarkup(html));
        Assert.Equal("Hola equipo", SelectionText.Best(html, "Hola equipo"));
    }

    [Fact]
    public void DetectsTeamsEmojiElementsAndEmojiImagesAsEmojiMarkup()
    {
        Assert.True(SelectionText.ContainsEmojiMarkup(TeamsHtml));
        Assert.True(SelectionText.ContainsEmojiMarkup("""<img alt="🚀" src="x.png">"""));
        Assert.False(SelectionText.ContainsEmojiMarkup("""<img alt="logo" src="x.png">"""));
    }

    [Fact]
    public void FallsBackToThePlainText()
    {
        Assert.Equal("plain", SelectionText.Best(null, "plain"));
        Assert.Equal("plain", SelectionText.Best("<span> </span>", "plain"));
        Assert.Null(SelectionText.Best(null, "  "));
        Assert.Null(SelectionText.Best(null, null));
    }

    [Fact]
    public void UsesTheAltTextOfImagesThatAreEmojiAndDropsOtherImages()
    {
        Assert.Equal("Listo 🚀 ya", SelectionText.PlainTextFromHtml("""Listo <img class="emoji" alt="🚀" src="x.png"> <img alt="logo" src="logo.png">ya"""));
    }

    [Fact]
    public void KeepsTheNameWhenAnEmojiElementHasNoEmojiInItemscope()
    {
        Assert.Equal("a x b", SelectionText.PlainTextFromHtml("""a <span itemtype="http://schema.skype.com/Emoji" itemscope="">x</span> b"""));
    }

    [Fact]
    public void TurnsLineBreaksAndBlocksIntoNewLines()
    {
        Assert.Equal("Hola\nequipo\nadiós\nuno\ndos", SelectionText.PlainTextFromHtml("<div>Hola<br>equipo</div><div>adiós</div><p>uno</p><p>dos</p>"));
    }

    [Fact]
    public void DecodesHtmlEntities()
    {
        Assert.Equal("a & b <c> \"d\" 'e' 😀 🚀 &lt;", SelectionText.PlainTextFromHtml("a &amp; b &lt;c&gt; &quot;d&quot; &#39;e&#39; &#128512; &#x1F680; &amp;lt;"));
    }

    [Fact]
    public void ReturnsNothingForHtmlWithoutText()
    {
        Assert.Null(SelectionText.PlainTextFromHtml("<meta charset='utf-8'><span></span>"));
    }

    [Theory]
    [InlineData("😅"), InlineData("👍"), InlineData("❤️"), InlineData("👨‍👩‍👧"), InlineData("🇪🇸"), InlineData("👍🏽"), InlineData("🚀🎉"), InlineData("⚡"), InlineData("☺️")]
    public void RecognisesEmojiIncludingComposedOnes(string text) => Assert.True(SelectionText.IsEmoji(text));

    [Theory]
    [InlineData("Sweat grinning"), InlineData(""), InlineData("1"), InlineData("#"), InlineData("©"), InlineData("a😅"), InlineData("→")]
    public void DoesNotTreatTextDigitsOrSymbolsAsEmoji(string text) => Assert.False(SelectionText.IsEmoji(text));

    [Fact]
    public void ExtractsTheFragmentFromWindowsHtmlFormat()
    {
        const string clipboard = "Version:0.9\r\nStartHTML:0000000105\r\nEndHTML:0000000199\r\nStartFragment:0000000141\r\nEndFragment:0000000163\r\n<html><body>\r\n<!--StartFragment-->Hola <b>equipo</b><!--EndFragment-->\r\n</body>\r\n</html>";
        Assert.Equal("Hola <b>equipo</b>", SelectionText.HtmlFragment(clipboard));
    }

    [Fact]
    public void KeepsHtmlWithoutFragmentMarkersFromTheFirstTag()
    {
        Assert.Equal("<span>hola</span>", SelectionText.HtmlFragment("Version:0.9\r\n<span>hola</span>"));
    }
}
