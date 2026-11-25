using System.Runtime.InteropServices;
using static QuickTranslator.Native;

namespace QuickTranslator;

/// Simulated key presses for copying and pasting in the app that has the selection.
internal static class Keyboard
{
    private static readonly ushort[] Modifiers = [VK_CONTROL, VK_MENU, VK_SHIFT, VK_LWIN, VK_RWIN];

    /// The hotkey fires while its modifiers are still down; a Ctrl+C sent then would arrive as Ctrl+Alt+C.
    public static async Task WaitForModifiersReleaseAsync(TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (Modifiers.Any(IsDown) && DateTime.UtcNow < deadline) await Task.Delay(15);
        var stillDown = Modifiers.Where(IsDown).ToArray();
        if (stillDown.Length > 0) Send(stillDown.Select(key => Key(key, up: true)).ToArray());
    }

    public static void Copy() => PressWithControl('C');

    public static void Paste() => PressWithControl('V');

    private static void PressWithControl(char key) => Send(
    [
        Key(VK_CONTROL, up: false),
        Key(key, up: false),
        Key(key, up: true),
        Key(VK_CONTROL, up: true),
    ]);

    private static bool IsDown(ushort key) => (GetAsyncKeyState(key) & 0x8000) != 0;

    private static INPUT Key(ushort key, bool up) => new()
    {
        type = INPUT_KEYBOARD,
        u = new InputUnion { ki = new KEYBDINPUT { wVk = key, dwFlags = up ? KEYEVENTF_KEYUP : 0 } },
    };

    private static void Send(INPUT[] inputs) => SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
}
