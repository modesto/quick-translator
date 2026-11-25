namespace QuickTranslator.Core;

/// A rectangle in screen pixels, with y growing downwards as in Win32.
public readonly record struct PixelRect(double X, double Y, double Width, double Height)
{
    public double Left => X;
    public double Top => Y;
    public double Right => X + Width;
    public double Bottom => Y + Height;

    public bool Contains(double x, double y) => x >= Left && x < Right && y >= Top && y < Bottom;
}

public readonly record struct PixelPoint(double X, double Y);

public readonly record struct PixelSize(double Width, double Height);

/// A monitor: its full bounds and its work area (without the taskbar).
public sealed record ScreenArea(PixelRect Bounds, PixelRect WorkArea);

public static class PopupPlacement
{
    public const double Margin = 8;
    public const double Gap = 6;
    private static readonly PixelRect FallbackWorkArea = new(0, 0, 1920, 1040);

    /// Below the selection when it fits, else above, else pinned to the top, always inside the work area.
    /// Margin and gap are in device-independent units; scale converts them to the monitor's pixels.
    public static PixelPoint Origin(PixelSize size, PixelRect anchor, IReadOnlyList<ScreenArea> screens, ScreenArea? primary = null, double scale = 1)
    {
        var margin = Margin * scale;
        var gap = Gap * scale;
        var centerX = anchor.X + anchor.Width / 2;
        var centerY = anchor.Y + anchor.Height / 2;
        var screen = screens.FirstOrDefault(screen => screen.Bounds.Contains(centerX, centerY)) ?? primary ?? screens.FirstOrDefault();
        var work = screen?.WorkArea ?? FallbackWorkArea;

        var spaceBelow = work.Bottom - anchor.Bottom - margin - gap;
        var spaceAbove = anchor.Top - work.Top - margin - gap;
        double y;
        if (size.Height <= spaceBelow) y = anchor.Bottom + gap;
        else if (size.Height <= spaceAbove) y = anchor.Top - gap - size.Height;
        else y = work.Top + margin;

        var x = Math.Min(Math.Max(anchor.Left, work.Left + margin), work.Right - margin - size.Width);
        return new PixelPoint(Math.Max(x, work.Left + margin), Math.Max(y, work.Top + margin));
    }

    /// Keeps a popup the user moved inside the work area of the monitor that holds most of it, for example when it
    /// grows after the translation arrives. Too tall a popup is pinned to the top.
    public static PixelPoint Clamp(PixelPoint origin, PixelSize size, IReadOnlyList<ScreenArea> screens, ScreenArea? primary = null, double scale = 1)
    {
        var margin = Margin * scale;
        var centerX = origin.X + size.Width / 2;
        var centerY = origin.Y + size.Height / 2;
        var screen = screens.FirstOrDefault(screen => screen.Bounds.Contains(centerX, centerY))
            ?? screens.FirstOrDefault(screen => screen.Bounds.Contains(origin.X, origin.Y))
            ?? primary ?? screens.FirstOrDefault();
        var work = screen?.WorkArea ?? FallbackWorkArea;
        var x = Math.Max(Math.Min(origin.X, work.Right - margin - size.Width), work.Left + margin);
        var y = Math.Max(Math.Min(origin.Y, work.Bottom - margin - size.Height), work.Top + margin);
        return new PixelPoint(x, y);
    }
}
