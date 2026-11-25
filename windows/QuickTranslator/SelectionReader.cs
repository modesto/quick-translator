using System.Diagnostics;
using System.Windows.Automation;
using QuickTranslator.Core;
using static QuickTranslator.Native;

namespace QuickTranslator;

/// A selection read from another app: its text, where it is on screen (pixels) and the window that holds it.
internal sealed record Selection(string Text, PixelRect? Anchor, IntPtr Window);

internal static class SelectionReader
{
    private static readonly TimeSpan CopyTimeout = TimeSpan.FromMilliseconds(800);
    private static readonly TimeSpan AnchorTimeout = TimeSpan.FromMilliseconds(400);

    /// Copies the selection with a simulated Ctrl+C and restores the clipboard afterwards.
    public static async Task<Selection?> ReadAsync(IntPtr window)
    {
        var anchor = Task.Run(() => FindAnchor(window));
        await Keyboard.WaitForModifiersReleaseAsync(TimeSpan.FromMilliseconds(800));

        var snapshot = ClipboardAccess.Snapshot.Take();
        var before = GetClipboardSequenceNumber();
        Keyboard.Copy();

        var clock = Stopwatch.StartNew();
        while (GetClipboardSequenceNumber() == before && clock.Elapsed < CopyTimeout) await Task.Delay(20);
        if (GetClipboardSequenceNumber() == before) return null;

        // Apps sometimes write the plain text first and the HTML a moment later.
        await Task.Delay(40);
        var (plain, html) = ClipboardAccess.ReadText();
        snapshot.Restore();

        var text = SelectionText.Best(html is null ? null : SelectionText.HtmlFragment(html), plain);
        if (text is null) return null;
        var found = await Task.WhenAny(anchor, Task.Delay(AnchorTimeout)) == anchor ? anchor.Result : null;
        return new Selection(text, found ?? CursorAnchor(), window);
    }

    private static PixelRect? FindAnchor(IntPtr window)
    {
        try
        {
            return AutomationSelectionRect() ?? CaretRect(window);
        }
        catch (Exception exception) when (exception is ElementNotAvailableException or InvalidOperationException or System.Runtime.InteropServices.COMException or ArgumentException)
        {
            return CaretRect(window);
        }
    }

    /// The bounds of the selected text, from UI Automation (Word, Edge, Chrome, most native controls).
    private static PixelRect? AutomationSelectionRect()
    {
        var element = AutomationElement.FocusedElement;
        if (element is null || !element.TryGetCurrentPattern(TextPattern.Pattern, out var pattern)) return null;
        var ranges = ((TextPattern)pattern).GetSelection();
        if (ranges.Length == 0) return null;
        var rects = ranges[0].GetBoundingRectangles().Where(rect => rect.Width > 0 || rect.Height > 0).ToList();
        if (rects.Count == 0) return null;
        var left = rects.Min(rect => rect.Left);
        var top = rects.Min(rect => rect.Top);
        return new PixelRect(left, top, rects.Max(rect => rect.Right) - left, rects.Max(rect => rect.Bottom) - top);
    }

    /// The text caret of classic Win32 controls.
    private static PixelRect? CaretRect(IntPtr window)
    {
        var thread = GetWindowThreadProcessId(window, out _);
        var info = new GUITHREADINFO { cbSize = System.Runtime.InteropServices.Marshal.SizeOf<GUITHREADINFO>() };
        if (thread == 0 || !GetGUIThreadInfo(thread, ref info) || info.hwndCaret == IntPtr.Zero) return null;
        var topLeft = new POINT { X = info.rcCaret.Left, Y = info.rcCaret.Top };
        if (!ClientToScreen(info.hwndCaret, ref topLeft)) return null;
        var height = info.rcCaret.Bottom - info.rcCaret.Top;
        return height <= 0 ? null : new PixelRect(topLeft.X, topLeft.Y, Math.Max(info.rcCaret.Right - info.rcCaret.Left, 1), height);
    }

    public static PixelRect CursorAnchor()
    {
        GetCursorPos(out var point);
        return new PixelRect(point.X, point.Y, 0, 0);
    }
}

internal static class TextReplacer
{
    /// Pastes the text into the window that had the selection, then restores the clipboard.
    public static async Task ReplaceSelectionAsync(string text, IntPtr window)
    {
        var snapshot = ClipboardAccess.Snapshot.Take();
        if (!ClipboardAccess.SetText(text)) return;
        if (window != IntPtr.Zero && IsWindow(window))
        {
            if (IsIconic(window)) ShowWindow(window, SW_RESTORE);
            SetForegroundWindow(window);
        }
        await Task.Delay(120);
        Keyboard.Paste();
        await Task.Delay(500);
        snapshot.Restore();
    }
}

/// Remembers the last window of another app that was in front, for "Translate selection" in the tray menu:
/// clicking the tray icon brings the taskbar to the front.
internal sealed class ForegroundTracker : IDisposable
{
    private readonly WinEventDelegate callback;
    private readonly IntPtr hook;
    private readonly uint ownProcess = (uint)Environment.ProcessId;

    public ForegroundTracker()
    {
        callback = OnForegroundChanged;
        hook = SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, IntPtr.Zero, callback, 0, 0, WINEVENT_OUTOFCONTEXT);
        OnForegroundChanged(IntPtr.Zero, 0, GetForegroundWindow(), 0, 0, 0, 0);
    }

    public IntPtr LastWindow { get; private set; }

    private void OnForegroundChanged(IntPtr hook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint thread, uint time)
    {
        if (hwnd == IntPtr.Zero) return;
        GetWindowThreadProcessId(hwnd, out var process);
        if (process == ownProcess || IsShell(hwnd)) return;
        LastWindow = hwnd;
    }

    private static bool IsShell(IntPtr hwnd)
    {
        var name = new System.Text.StringBuilder(64);
        _ = GetClassName(hwnd, name, name.Capacity);
        return name.ToString() is "Shell_TrayWnd" or "Shell_SecondaryTrayWnd" or "NotifyIconOverflowWindow" or "TopLevelWindowForOverflowXamlIsland" or "Windows.UI.Core.CoreWindow";
    }

    [System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
    private static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder name, int capacity);

    public void Dispose() => UnhookWinEvent(hook);
}
