using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace QuickTranslator.Core;

/// Picks the text of a copied selection. Web apps (Teams, Slack…) draw some emoji as images, so the copied
/// HTML is preferred when it has emoji markup; else the copied plain text.
public static partial class SelectionText
{
    public static string? Best(string? clipboardHtml, string? clipboardPlain)
    {
        var fromHtml = clipboardHtml is not null && ContainsEmojiMarkup(clipboardHtml) ? PlainTextFromHtml(clipboardHtml) : null;
        return new[] { fromHtml, clipboardPlain }.FirstOrDefault(text => !string.IsNullOrWhiteSpace(text));
    }

    /// The selection inside Windows' "HTML Format" clipboard data, which wraps it in a header and a full document.
    public static string HtmlFragment(string clipboardHtml)
    {
        const string start = "<!--StartFragment-->";
        const string end = "<!--EndFragment-->";
        var from = clipboardHtml.IndexOf(start, StringComparison.OrdinalIgnoreCase);
        var to = clipboardHtml.IndexOf(end, StringComparison.OrdinalIgnoreCase);
        if (from >= 0 && to > from) return clipboardHtml.Substring(from + start.Length, to - from - start.Length);
        var html = clipboardHtml.IndexOf('<');
        return html >= 0 ? clipboardHtml[html..] : clipboardHtml;
    }

    public static string? PlainTextFromHtml(string html)
    {
        var text = ReplaceEmojiElements(html);
        text = ReplaceEmojiImages(text);
        text = LineBreak().Replace(text, "\n");
        text = BlockEnd().Replace(text, "\n");
        text = Tag().Replace(text, "");
        text = DecodeEntities(text);
        text = text.Replace("⁠", "").Replace("\r\n", "\n").Trim('\n', '\r');
        return string.IsNullOrWhiteSpace(text) ? null : text;
    }

    public static bool ContainsEmojiMarkup(string html) => ReplaceEmojiImages(ReplaceEmojiElements(html)) != html;

    public static bool IsEmoji(string text)
    {
        var trimmed = text.Trim();
        if (trimmed.Length == 0) return false;
        var elements = StringInfo.GetTextElementEnumerator(trimmed);
        while (elements.MoveNext())
        {
            var runes = elements.GetTextElement().EnumerateRunes().Select(rune => rune.Value).ToList();
            var presentation = runes.Any(IsEmojiPresentation);
            var withSelector = runes.Contains(0xFE0F) && runes.Any(IsEmojiCapable);
            if (!presentation && !withSelector) return false;
        }
        return true;
    }

    // .NET has no Unicode emoji properties; these ranges cover the emoji that default to emoji presentation.
    private static bool IsEmojiPresentation(int value) =>
        value >= 0x10000 ? IsSupplementaryEmojiPresentation(value) : BmpEmojiPresentation.Contains(value);

    private static bool IsSupplementaryEmojiPresentation(int value) =>
        value is 0x1F004 or 0x1F0CF or 0x1F18E or (>= 0x1F191 and <= 0x1F19A) or (>= 0x1F1E6 and <= 0x1F1FF)
            or 0x1F201 or 0x1F21A or 0x1F22F or (>= 0x1F232 and <= 0x1F236) or (>= 0x1F238 and <= 0x1F23A) or 0x1F250 or 0x1F251
            or (>= 0x1F300 and <= 0x1F64F) or (>= 0x1F680 and <= 0x1F6FF) or (>= 0x1F7E0 and <= 0x1F7EB)
            or (>= 0x1F90C and <= 0x1F9FF) or (>= 0x1FA70 and <= 0x1FAFF);

    private static readonly HashSet<int> BmpEmojiPresentation =
    [
        0x231A, 0x231B, 0x23E9, 0x23EA, 0x23EB, 0x23EC, 0x23F0, 0x23F3, 0x25FD, 0x25FE, 0x2614, 0x2615,
        0x2648, 0x2649, 0x264A, 0x264B, 0x264C, 0x264D, 0x264E, 0x264F, 0x2650, 0x2651, 0x2652, 0x2653,
        0x267F, 0x2693, 0x26A1, 0x26AA, 0x26AB, 0x26BD, 0x26BE, 0x26C4, 0x26C5, 0x26CE, 0x26D4, 0x26EA,
        0x26F2, 0x26F3, 0x26F5, 0x26FA, 0x26FD, 0x2705, 0x270A, 0x270B, 0x2728, 0x274C, 0x274E, 0x2753,
        0x2754, 0x2755, 0x2757, 0x2795, 0x2796, 0x2797, 0x27B0, 0x27BF, 0x2B1B, 0x2B1C, 0x2B50, 0x2B55,
    ];

    // Characters that become emoji with U+FE0F (❤️, ☺️…): symbols and dingbats, but not digits, # or ©.
    private static bool IsEmojiCapable(int value) =>
        value is >= 0x2000 and <= 0x2BFF or >= 0x1F000 and <= 0x1FAFF or 0x3030 or 0x303D or 0x3297 or 0x3299;

    private static string ReplaceEmojiElements(string html) =>
        EmojiElement().Replace(html, match =>
        {
            var scope = ItemScope().Match(match.Value);
            if (!scope.Success) return match.Value;
            var emoji = DecodeEntities(scope.Groups[1].Value);
            return IsEmoji(emoji) ? emoji : match.Value;
        });

    private static string ReplaceEmojiImages(string html) =>
        Image().Replace(html, match =>
        {
            var alt = Alt().Match(match.Value);
            if (!alt.Success) return match.Value;
            var text = DecodeEntities(alt.Groups[1].Value);
            return IsEmoji(text) ? text : match.Value;
        });

    private static readonly (string Entity, string Text)[] NamedEntities =
        [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " ")];

    private static string DecodeEntities(string text)
    {
        var decoded = NumericEntity().Replace(text, match =>
        {
            var body = match.Groups[1].Value;
            var parsed = body[0] is 'x' or 'X'
                ? int.TryParse(body[1..], NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var hex) ? hex : -1
                : int.TryParse(body, NumberStyles.None, CultureInfo.InvariantCulture, out var dec) ? dec : -1;
            return Rune.IsValid(parsed) ? new Rune(parsed).ToString() : match.Value;
        });
        foreach (var (entity, character) in NamedEntities) decoded = decoded.Replace(entity, character);
        return decoded.Replace("&amp;", "&");
    }

    [GeneratedRegex("""<([a-zA-Z][\w-]*)\b[^>]*itemtype\s*=\s*"[^"]*/Emoji"[^>]*>.*?</\1\s*>""", RegexOptions.Singleline | RegexOptions.IgnoreCase)]
    private static partial Regex EmojiElement();

    [GeneratedRegex("""itemscope\s*=\s*"([^"]*)" """, RegexOptions.IgnoreCase | RegexOptions.IgnorePatternWhitespace)]
    private static partial Regex ItemScope();

    [GeneratedRegex(@"<img\b[^>]*>", RegexOptions.IgnoreCase)]
    private static partial Regex Image();

    [GeneratedRegex("""\balt\s*=\s*"([^"]*)" """, RegexOptions.IgnoreCase | RegexOptions.IgnorePatternWhitespace)]
    private static partial Regex Alt();

    [GeneratedRegex(@"<br\s*/?>", RegexOptions.IgnoreCase)]
    private static partial Regex LineBreak();

    [GeneratedRegex(@"</(p|div|li|tr|h[1-6])\s*>", RegexOptions.IgnoreCase)]
    private static partial Regex BlockEnd();

    [GeneratedRegex(@"<[^>]*>")]
    private static partial Regex Tag();

    [GeneratedRegex(@"&#(x[0-9a-fA-F]+|[0-9]+);")]
    private static partial Regex NumericEntity();
}
