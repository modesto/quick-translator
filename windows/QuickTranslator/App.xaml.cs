using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows;
using Microsoft.Win32;
using QuickTranslator.Core;
using Forms = System.Windows.Forms;

namespace QuickTranslator;

/// A tray app: no main window, a notification-area icon with a menu, a global hotkey and the CLI server.
public partial class App : Application
{
    private Mutex? instance;
    private AppSettings settings = null!;
    private HotKeyService hotKey = null!;
    private ShortcutManager shortcuts = null!;
    private ServerTranslator translator = null!;
    private TranslationCoordinator coordinator = null!;
    private ForegroundTracker foreground = null!;
    private SettingsWindow settingsWindow = null!;
    private Forms.NotifyIcon tray = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        instance = new Mutex(initiallyOwned: true, @"Local\QuickTranslator", out var isFirst);
        if (!isFirst)
        {
            Shutdown();
            return;
        }

        settings = new AppSettings(new JsonFileSettingsStore(JsonFileSettingsStore.DefaultPath));
        L10n.Language = UILanguages.ForLanguage(settings.LanguagePair.Mine);
        var secrets = new CredentialSecretStore();
        translator = new ServerTranslator(settings, secrets, Dispatcher);
        coordinator = new TranslationCoordinator(settings, translator);
        foreground = new ForegroundTracker();
        hotKey = new HotKeyService();
        hotKey.Pressed += () => _ = coordinator.TranslateCurrentSelectionAsync();
        shortcuts = new ShortcutManager(settings, hotKey);

        settingsWindow = new SettingsWindow(settings, secrets, shortcuts, translator.Restart,
            (text, pair, provider, completion) => translator.Translate(text, pair, null, provider, completion));
        settingsWindow.ShortcutChanged += RebuildTrayMenu;
        settingsWindow.LanguagePairChanged += RebuildTrayMenu;
        coordinator.OpenProviderSettings += () => settingsWindow.Present(SettingsTab.Provider);

        SetUpTray();
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
        if (!shortcuts.Activate())
        {
            Native.Beep();
            settingsWindow.Present(SettingsTab.General);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
        if (tray is not null)
        {
            tray.Visible = false;
            tray.Dispose();
        }
        hotKey?.Dispose();
        foreground?.Dispose();
        translator?.Dispose();
        instance?.Dispose();
        base.OnExit(e);
    }

    private void SetUpTray()
    {
        tray = new Forms.NotifyIcon { Text = "Quick Translator", Icon = TrayIcon.Create(), Visible = true };
        tray.MouseClick += (_, e) =>
        {
            if (e.Button == Forms.MouseButtons.Left) settingsWindow.Present(SettingsTab.General);
        };
        RebuildTrayMenu();
    }

    private void RebuildTrayMenu()
    {
        var strings = L10n.Strings;
        var menu = new Forms.ContextMenuStrip();
        var translate = new Forms.ToolStripMenuItem(strings.TranslateSelection)
        {
            ShortcutKeyDisplayString = shortcuts.Current.DisplayString(L10n.Language),
            Font = new Font(Forms.SystemInformation.MenuFont, System.Drawing.FontStyle.Bold),
        };
        translate.Click += (_, _) => _ = coordinator.TranslateCurrentSelectionAsync(foreground.LastWindow);
        menu.Items.Add(translate);
        menu.Items.Add(strings.SettingsEllipsis, null, (_, _) => settingsWindow.Present(SettingsTab.General));
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(strings.Quit, null, (_, _) => Shutdown());
        var previous = tray.ContextMenuStrip;
        tray.ContextMenuStrip = menu;
        previous?.Dispose();
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (e.Category == UserPreferenceCategory.General) Dispatcher.BeginInvoke(() => tray.Icon = TrayIcon.Create());
    }
}

/// The tray icon: the "characters" glyph from the system icon font, white on a dark taskbar and black on a light one.
internal static class TrayIcon
{
    public static Icon Create()
    {
        var size = Forms.SystemInformation.SmallIconSize.Width;
        using var bitmap = new Bitmap(size, size);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            graphics.Clear(System.Drawing.Color.Transparent);
            using var brush = new SolidBrush(TaskbarIsLight() ? System.Drawing.Color.Black : System.Drawing.Color.White);
            var family = new[] { "Segoe Fluent Icons", "Segoe MDL2 Assets" }
                .FirstOrDefault(name => FontFamily.Families.Any(f => f.Name == name));
            // Icon fonts carry large ascents, so DrawString shifts and clips the glyph; fit its outline to the icon instead.
            using var path = new GraphicsPath();
            using var fontFamily = new FontFamily(family ?? "Segoe UI");
            path.AddString(family is null ? "T" : "", fontFamily, (int)System.Drawing.FontStyle.Regular, size, PointF.Empty, StringFormat.GenericTypographic);
            var bounds = path.GetBounds();
            var scale = size * 0.94f / Math.Max(bounds.Width, bounds.Height);
            using var matrix = new Matrix();
            matrix.Translate(size / 2f, size / 2f);
            matrix.Scale(scale, scale);
            matrix.Translate(-(bounds.X + bounds.Width / 2), -(bounds.Y + bounds.Height / 2));
            path.Transform(matrix);
            graphics.FillPath(brush, path);
        }
        return Icon.FromHandle(bitmap.GetHicon());
    }

    private static bool TaskbarIsLight()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("SystemUsesLightTheme") is int value && value == 1;
    }
}
