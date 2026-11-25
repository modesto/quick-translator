using System.Text.Json.Serialization;

namespace QuickTranslator.Core;

/// Values match the Win32 RegisterHotKey MOD_ flags.
[Flags]
public enum ShortcutModifiers
{
    None = 0,
    Alt = 0x1,
    Control = 0x2,
    Shift = 0x4,
    Win = 0x8,
}

/// A global shortcut: a Win32 virtual-key code, its modifiers and the label shown for the key.
public sealed record Shortcut(
    [property: JsonPropertyName("keyCode")] uint KeyCode,
    [property: JsonPropertyName("modifiers")] ShortcutModifiers Modifiers,
    [property: JsonPropertyName("key")] string Key)
{
    public const uint VkSpace = 0x20;

    public static readonly Shortcut Default = new(0x54, ShortcutModifiers.Control | ShortcutModifiers.Alt, "T");

    public static Shortcut Create(uint keyCode, ShortcutModifiers modifiers, string? characters, UILanguage language) =>
        new(keyCode, modifiers, KeyLabel(keyCode, characters, language));

    public string DisplayString(UILanguage language)
    {
        var parts = new List<string>();
        if (Modifiers.HasFlag(ShortcutModifiers.Control)) parts.Add("Ctrl");
        if (Modifiers.HasFlag(ShortcutModifiers.Alt)) parts.Add("Alt");
        if (Modifiers.HasFlag(ShortcutModifiers.Shift)) parts.Add("Shift");
        if (Modifiers.HasFlag(ShortcutModifiers.Win)) parts.Add("Win");
        parts.Add(KeyCode == VkSpace ? language.Strings().SpaceKey : Key);
        return string.Join('+', parts);
    }

    public string DisplayString() => DisplayString(L10n.Language);

    /// Whether the key is a modifier on its own, which a recorder must wait past.
    public static bool IsModifierKey(uint keyCode) =>
        keyCode is 0x10 or 0x11 or 0x12 or 0x5B or 0x5C or (>= 0xA0 and <= 0xA5);

    public static string KeyLabel(uint keyCode, string? characters, UILanguage language)
    {
        if (keyCode == VkSpace) return language.Strings().SpaceKey;
        if (keyCode is >= 0x30 and <= 0x39 or >= 0x41 and <= 0x5A) return ((char)keyCode).ToString();
        if (keyCode is >= 0x70 and <= 0x87) return $"F{keyCode - 0x6F}";
        if (keyCode is >= 0x60 and <= 0x69) return $"Num {keyCode - 0x60}";
        if (SpecialKeys.TryGetValue(keyCode, out var special)) return special;
        var trimmed = (characters ?? "").Trim();
        return trimmed.Length == 0 ? $"#{keyCode}" : trimmed.ToUpper(language.Culture());
    }

    private static readonly Dictionary<uint, string> SpecialKeys = new()
    {
        [0x08] = "Backspace",
        [0x09] = "Tab",
        [0x0D] = "Enter",
        [0x1B] = "Esc",
        [0x21] = "PgUp",
        [0x22] = "PgDn",
        [0x23] = "End",
        [0x24] = "Home",
        [0x25] = "←",
        [0x26] = "↑",
        [0x27] = "→",
        [0x28] = "↓",
        [0x2D] = "Ins",
        [0x2E] = "Del",
        [0x6A] = "Num *",
        [0x6B] = "Num +",
        [0x6D] = "Num -",
        [0x6E] = "Num .",
        [0x6F] = "Num /",
    };
}

public enum ShortcutValidationErrorKind { NeedsModifier, Reserved }

public sealed record ShortcutValidationError(ShortcutValidationErrorKind Kind, string Shortcut = "")
{
    public string Message(UILanguage language) => Kind == ShortcutValidationErrorKind.NeedsModifier
        ? language.Strings().ShortcutNeedsModifier
        : language.Strings().ShortcutReserved(Shortcut);
}

public static class ShortcutValidator
{
    private const ShortcutModifiers Ctrl = ShortcutModifiers.Control;
    private const ShortcutModifiers Alt = ShortcutModifiers.Alt;

    // System and editing shortcuts that must keep working in every app.
    private static readonly HashSet<(ShortcutModifiers, uint)> Reserved =
    [
        (Ctrl, 'C'), (Ctrl, 'V'), (Ctrl, 'X'), (Ctrl, 'Z'), (Ctrl, 'Y'), (Ctrl, 'A'), (Ctrl, 'S'), (Ctrl, 'W'),
        (Ctrl, 0x09), (Ctrl, 0x1B), (Ctrl, 0x73),
        (Alt, 0x09), (Alt, 0x1B), (Alt, 0x20), (Alt, 0x73),
        (Ctrl | Alt, 0x2E), (Ctrl | ShortcutModifiers.Shift, 0x1B),
    ];

    /// Returns null when the shortcut is valid.
    public static ShortcutValidationError? Validate(Shortcut shortcut, UILanguage language)
    {
        if ((shortcut.Modifiers & (ShortcutModifiers.Control | ShortcutModifiers.Alt | ShortcutModifiers.Win)) == 0)
            return new(ShortcutValidationErrorKind.NeedsModifier);
        if (Reserved.Contains((shortcut.Modifiers, shortcut.KeyCode)))
            return new(ShortcutValidationErrorKind.Reserved, shortcut.DisplayString(language));
        return null;
    }
}

public interface IHotKeyRegistering
{
    bool Register(Shortcut shortcut);
    void Unregister();
}

public sealed record ShortcutChangeError(ShortcutValidationError? Invalid, string? Unavailable = null)
{
    public string Message(UILanguage language) =>
        Invalid?.Message(language) ?? language.Strings().ShortcutUnavailable(Unavailable ?? "");
}

/// Registers the saved shortcut, falls back to the previous one when a new one is taken, and persists changes.
public sealed class ShortcutManager(AppSettings settings, IHotKeyRegistering hotKey)
{
    public Shortcut Current { get; private set; } = settings.Shortcut;
    public bool IsActive { get; private set; }

    public bool Activate()
    {
        IsActive = hotKey.Register(Current);
        return IsActive;
    }

    public void Pause()
    {
        hotKey.Unregister();
        IsActive = false;
    }

    /// Returns null on success.
    public ShortcutChangeError? Change(Shortcut shortcut, UILanguage language)
    {
        if (ShortcutValidator.Validate(shortcut, language) is { } invalid) return new(invalid);
        if (!hotKey.Register(shortcut))
        {
            Activate();
            return new(null, shortcut.DisplayString(language));
        }
        Current = shortcut;
        IsActive = true;
        settings.Shortcut = shortcut;
        return null;
    }

    public ShortcutChangeError? Reset(UILanguage language) => Change(Shortcut.Default, language);
}
