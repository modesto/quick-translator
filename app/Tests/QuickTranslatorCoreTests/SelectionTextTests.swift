import Testing
@testable import QuickTranslatorCore

@Suite("SelectionText")
struct SelectionTextTests {
    static let teamsHTML = """
    <meta charset='utf-8'><span data-teams="true">si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis \u{2060}<readonly contenteditable="false" title="Sweat grinning" itemid="sweatgrinning" itemtype="http://schema.skype.com/Emoji" itemscope="😅" aria-label="Sweat grinning" data-announcement="Sweat grinning emoji"><img style="margin:0px 1px;overflow:hidden;position:relative;top:-1px;vertical-align:bottom;" src="https://statics.teams.cdn.office.net/evergreen-assets/personal-expressions/v2/assets/emoticons/sweatgrinning/default/50_f.png?v=v30" alt="Sweat grinning" draggable="false" width="20px" height="20px" aria-label="Sweat grinning" blockindent="1px"></readonly>?</span>
    """

    @Test("recovers Teams emoji from the copied HTML")
    func teamsEmoji() {
        #expect(SelectionText.plainText(fromHTML: Self.teamsHTML) == "si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis 😅?")
    }

    @Test("prefers the copied HTML over the plain text and the accessibility text Teams gives")
    func prefersHTML() {
        let text = SelectionText.best(
            accessibility: "si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis ?",
            clipboardHTML: Self.teamsHTML,
            clipboardPlain: "si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis \n\nSweat grinning\n\n?"
        )
        #expect(text == "si yo quiero traducir esto, como 👍 o ❤️ funciona con emojis 😅?")
    }

    @Test("ignores HTML without emoji markup so its source whitespace never leaks in")
    func plainHTMLIsIgnored() {
        let html = "<div>\n    <span>Hola equipo</span>\n</div>"
        #expect(SelectionText.containsEmojiMarkup(html) == false)
        #expect(SelectionText.best(accessibility: "Hola equipo", clipboardHTML: html, clipboardPlain: "Hola equipo") == "Hola equipo")
    }

    @Test("detects Teams emoji elements and emoji images as emoji markup")
    func detectsEmojiMarkup() {
        #expect(SelectionText.containsEmojiMarkup(Self.teamsHTML))
        #expect(SelectionText.containsEmojiMarkup(#"<img alt="🚀" src="x.png">"#))
        #expect(SelectionText.containsEmojiMarkup(#"<img alt="logo" src="x.png">"#) == false)
    }

    @Test("falls back to the plain text, then to the accessibility text")
    func fallbacks() {
        #expect(SelectionText.best(accessibility: "ax", clipboardHTML: nil, clipboardPlain: "plain") == "plain")
        #expect(SelectionText.best(accessibility: "ax", clipboardHTML: "<span> </span>", clipboardPlain: nil) == "ax")
        #expect(SelectionText.best(accessibility: "ax", clipboardHTML: nil, clipboardPlain: "  ") == "ax")
        #expect(SelectionText.best(accessibility: nil, clipboardHTML: nil, clipboardPlain: nil) == nil)
    }

    @Test("uses the alt text of images that are emoji and drops other images")
    func emojiImages() {
        let html = #"Listo <img class="emoji" alt="🚀" src="x.png"> <img alt="logo" src="logo.png">ya"#
        #expect(SelectionText.plainText(fromHTML: html) == "Listo 🚀 ya")
    }

    @Test("keeps the name when an emoji element has no emoji in itemscope")
    func emojiElementWithoutEmoji() {
        let html = #"a <span itemtype="http://schema.skype.com/Emoji" itemscope="">x</span> b"#
        #expect(SelectionText.plainText(fromHTML: html) == "a x b")
    }

    @Test("turns line breaks and blocks into new lines")
    func lineBreaks() {
        let html = "<div>Hola<br>equipo</div><div>adiós</div><p>uno</p><p>dos</p>"
        #expect(SelectionText.plainText(fromHTML: html) == "Hola\nequipo\nadiós\nuno\ndos")
    }

    @Test("decodes HTML entities")
    func entities() {
        let html = "a &amp; b &lt;c&gt; &quot;d&quot; &#39;e&#39; &#128512; &#x1F680; &amp;lt;"
        #expect(SelectionText.plainText(fromHTML: html) == "a & b <c> \"d\" 'e' 😀 🚀 &lt;")
    }

    @Test("returns nothing for HTML without text")
    func empty() {
        #expect(SelectionText.plainText(fromHTML: "<meta charset='utf-8'><span></span>") == nil)
    }

    @Test("recognises emoji, including composed ones", arguments: ["😅", "👍", "❤️", "👨‍👩‍👧", "🇪🇸", "👍🏽", "🚀🎉"])
    func emoji(text: String) {
        #expect(SelectionText.isEmoji(text))
    }

    @Test("does not treat text, digits or symbols as emoji", arguments: ["Sweat grinning", "", "1", "#", "©", "a😅"])
    func notEmoji(text: String) {
        #expect(SelectionText.isEmoji(text) == false)
    }
}
