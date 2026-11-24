import Foundation

public enum SelectionText {
    public static func best(accessibility: String?, clipboardHTML: String?, clipboardPlain: String?) -> String? {
        let fromHTML = clipboardHTML.flatMap { containsEmojiMarkup($0) ? plainText(fromHTML: $0) : nil }
        let candidates = [fromHTML, clipboardPlain, accessibility]
        return candidates.lazy.compactMap { $0 }.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public static func plainText(fromHTML html: String) -> String? {
        var text = html
        text = replaceEmojiElements(in: text)
        text = replaceEmojiImages(in: text)
        text = replace(#"<br\s*/?>"#, in: text, with: "\n")
        text = replace(#"</(p|div|li|tr|h[1-6])\s*>"#, in: text, with: "\n")
        text = replace(#"<[^>]*>"#, in: text, with: "")
        text = decodeEntities(text)
        text = text.replacingOccurrences(of: "\u{2060}", with: "")
        text = text.trimmingCharacters(in: .newlines)
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    public static func containsEmojiMarkup(_ html: String) -> Bool {
        replaceEmojiImages(in: replaceEmojiElements(in: html)) != html
    }

    public static func isEmoji(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { character in
            character.unicodeScalars.contains { $0.properties.isEmojiPresentation }
                || (character.unicodeScalars.contains { $0.properties.isEmoji } && character.unicodeScalars.contains { $0.value == 0xFE0F })
        }
    }

    private static let emojiElement = try! NSRegularExpression(
        pattern: #"<([a-zA-Z][\w-]*)\b[^>]*itemtype\s*=\s*"[^"]*/Emoji"[^>]*>.*?</\1\s*>"#,
        options: [.dotMatchesLineSeparators, .caseInsensitive]
    )
    private static let itemScope = try! NSRegularExpression(pattern: #"itemscope\s*=\s*"([^"]*)""#, options: .caseInsensitive)
    private static let image = try! NSRegularExpression(pattern: #"<img\b[^>]*>"#, options: .caseInsensitive)
    private static let alt = try! NSRegularExpression(pattern: #"\balt\s*=\s*"([^"]*)""#, options: .caseInsensitive)

    private static func replaceEmojiElements(in html: String) -> String {
        transform(emojiElement, in: html) { element in
            guard let emoji = firstCapture(itemScope, in: element).map(decodeEntities), isEmoji(emoji) else { return element }
            return emoji
        }
    }

    private static func replaceEmojiImages(in html: String) -> String {
        transform(image, in: html) { tag in
            guard let text = firstCapture(alt, in: tag).map(decodeEntities), isEmoji(text) else { return tag }
            return text
        }
    }

    private static func transform(_ regex: NSRegularExpression, in string: String, using replacement: (String) -> String) -> String {
        let source = string as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: string, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += replacement(source.substring(with: match.range))
            cursor = match.range.location + match.range.length
        }
        result += source.substring(from: cursor)
        return result
    }

    private static func firstCapture(_ regex: NSRegularExpression, in string: String) -> String? {
        let source = string as NSString
        guard let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: source.length)),
              match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { return nil }
        return source.substring(with: match.range(at: 1))
    }

    private static func replace(_ pattern: String, in string: String, with template: String) -> String {
        string.replacingOccurrences(of: pattern, with: template, options: [.regularExpression, .caseInsensitive])
    }

    private static let namedEntities = ["&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": "\u{00A0}"]
    private static let numericEntity = try! NSRegularExpression(pattern: #"&#(x[0-9a-fA-F]+|[0-9]+);"#)

    private static func decodeEntities(_ string: String) -> String {
        var text = transform(numericEntity, in: string) { entity in
            let body = entity.dropFirst(2).dropLast()
            let value = body.first == "x" || body.first == "X" ? UInt32(body.dropFirst(), radix: 16) : UInt32(body)
            return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? entity
        }
        for (entity, character) in namedEntities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.replacingOccurrences(of: "&amp;", with: "&")
    }
}
