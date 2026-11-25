using QuickTranslator.Core;

namespace QuickTranslator.Core.Tests;

internal sealed class FakeHotKey(params Shortcut[] taken) : IHotKeyRegistering
{
    public Shortcut? Registered { get; private set; }
    public List<Shortcut> Attempts { get; } = [];

    public bool Register(Shortcut shortcut)
    {
        Attempts.Add(shortcut);
        Registered = null;
        if (taken.Contains(shortcut)) return false;
        Registered = shortcut;
        return true;
    }

    public void Unregister() => Registered = null;
}

public class ShortcutTests
{
    private const ShortcutModifiers Ctrl = ShortcutModifiers.Control;
    private const ShortcutModifiers Alt = ShortcutModifiers.Alt;

    [Fact]
    public void DefaultsToCtrlAltT()
    {
        Assert.Equal("Ctrl+Alt+T", Shortcut.Default.DisplayString(UILanguage.Es));
    }

    [Fact]
    public void ShowsModifiersInWindowsOrderAndLocalizesSpace()
    {
        var shortcut = new Shortcut(Shortcut.VkSpace, ShortcutModifiers.Win | ShortcutModifiers.Shift | Alt | Ctrl, "Espacio");
        Assert.Equal("Ctrl+Alt+Shift+Win+Espacio", shortcut.DisplayString(UILanguage.Es));
        Assert.Equal("Ctrl+Alt+Shift+Win+Space", shortcut.DisplayString(UILanguage.En));
    }

    [Theory]
    [InlineData(0x41u, null, "A"), InlineData(0x37u, null, "7"), InlineData(0x70u, null, "F1"), InlineData(0x87u, null, "F24")]
    [InlineData(0x0Du, null, "Enter"), InlineData(0x25u, null, "←"), InlineData(0x63u, null, "Num 3"), InlineData(0xC0u, "ñ", "Ñ")]
    [InlineData(0xBAu, " ", "#186"), InlineData(0x20u, null, "Space")]
    public void LabelsKeys(uint keyCode, string? characters, string label)
    {
        Assert.Equal(label, Shortcut.KeyLabel(keyCode, characters, UILanguage.En));
    }

    [Fact]
    public void RecognisesModifierKeys()
    {
        Assert.True(Shortcut.IsModifierKey(0x11));
        Assert.True(Shortcut.IsModifierKey(0xA4));
        Assert.True(Shortcut.IsModifierKey(0x5B));
        Assert.False(Shortcut.IsModifierKey(0x54));
    }

    [Theory]
    [InlineData(ShortcutModifiers.None), InlineData(ShortcutModifiers.Shift)]
    public void NeedsCtrlAltOrWin(ShortcutModifiers modifiers)
    {
        var error = ShortcutValidator.Validate(new Shortcut(0x54, modifiers, "T"), UILanguage.Es);
        Assert.Equal(ShortcutValidationErrorKind.NeedsModifier, error?.Kind);
        Assert.Equal("El atajo necesita al menos Ctrl, Alt o Win.", error?.Message(UILanguage.Es));
    }

    [Theory]
    [InlineData(Ctrl, 0x43u), InlineData(Ctrl, 0x56u), InlineData(Ctrl, 0x5Au), InlineData(Alt, 0x09u), InlineData(Alt, 0x73u), InlineData(Ctrl | Alt, 0x2Eu)]
    public void RejectsSystemAndEditingShortcuts(ShortcutModifiers modifiers, uint keyCode)
    {
        var shortcut = new Shortcut(keyCode, modifiers, "X");
        var error = ShortcutValidator.Validate(shortcut, UILanguage.En);
        Assert.Equal(ShortcutValidationErrorKind.Reserved, error?.Kind);
        Assert.StartsWith(shortcut.DisplayString(UILanguage.En), error?.Message(UILanguage.En));
    }

    [Theory]
    [InlineData(Ctrl | Alt, 0x54u), InlineData(Ctrl | ShortcutModifiers.Shift, 0x43u), InlineData(ShortcutModifiers.Win | Alt, 0x54u), InlineData(Alt, 0x54u)]
    public void AcceptsOtherShortcuts(ShortcutModifiers modifiers, uint keyCode)
    {
        Assert.Null(ShortcutValidator.Validate(new Shortcut(keyCode, modifiers, "X"), UILanguage.En));
    }
}

public class ShortcutManagerTests
{
    private static readonly Shortcut CtrlShiftK = new(0x4B, ShortcutModifiers.Control | ShortcutModifiers.Shift, "K");

    [Fact]
    public void ActivatesTheSavedShortcut()
    {
        var store = new InMemorySettingsStore();
        new AppSettings(store).Shortcut = CtrlShiftK;
        var hotKey = new FakeHotKey();
        var manager = new ShortcutManager(new AppSettings(store), hotKey);

        Assert.True(manager.Activate());
        Assert.Equal(CtrlShiftK, hotKey.Registered);
    }

    [Fact]
    public void ReportsWhenTheShortcutIsTakenAtLaunch()
    {
        var manager = new ShortcutManager(new AppSettings(new InMemorySettingsStore()), new FakeHotKey(Shortcut.Default));
        Assert.False(manager.Activate());
        Assert.False(manager.IsActive);
    }

    [Fact]
    public void ChangesRegistersAndPersistsANewShortcut()
    {
        var store = new InMemorySettingsStore();
        var hotKey = new FakeHotKey();
        var manager = new ShortcutManager(new AppSettings(store), hotKey);
        manager.Activate();

        Assert.Null(manager.Change(CtrlShiftK, UILanguage.En));
        Assert.Equal(CtrlShiftK, manager.Current);
        Assert.Equal(CtrlShiftK, hotKey.Registered);
        Assert.Equal(CtrlShiftK, new AppSettings(store).Shortcut);
    }

    [Fact]
    public void KeepsThePreviousShortcutWhenTheNewOneIsTaken()
    {
        var store = new InMemorySettingsStore();
        var hotKey = new FakeHotKey(CtrlShiftK);
        var manager = new ShortcutManager(new AppSettings(store), hotKey);
        manager.Activate();

        var error = manager.Change(CtrlShiftK, UILanguage.De);

        Assert.StartsWith("Ctrl+Shift+K ist nicht verfügbar", error?.Message(UILanguage.De));
        Assert.Equal(Shortcut.Default, manager.Current);
        Assert.Equal(Shortcut.Default, hotKey.Registered);
        Assert.True(manager.IsActive);
        Assert.Equal(Shortcut.Default, new AppSettings(store).Shortcut);
    }

    [Fact]
    public void RejectsAnInvalidShortcutWithoutTouchingTheRegistration()
    {
        var hotKey = new FakeHotKey();
        var manager = new ShortcutManager(new AppSettings(new InMemorySettingsStore()), hotKey);
        manager.Activate();

        var error = manager.Change(new Shortcut(0x43, ShortcutModifiers.Control, "C"), UILanguage.En);

        Assert.Equal(ShortcutValidationErrorKind.Reserved, error?.Invalid?.Kind);
        Assert.Single(hotKey.Attempts);
    }

    [Fact]
    public void PausesWhileRecordingAndResetsToTheDefault()
    {
        var store = new InMemorySettingsStore();
        var hotKey = new FakeHotKey();
        var manager = new ShortcutManager(new AppSettings(store), hotKey);
        manager.Change(CtrlShiftK, UILanguage.En);

        manager.Pause();
        Assert.False(manager.IsActive);
        Assert.Null(hotKey.Registered);

        Assert.Null(manager.Reset(UILanguage.En));
        Assert.Equal(Shortcut.Default, new AppSettings(store).Shortcut);
    }
}
