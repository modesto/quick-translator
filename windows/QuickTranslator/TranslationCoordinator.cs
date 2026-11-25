using QuickTranslator.Core;
using static QuickTranslator.Native;

namespace QuickTranslator;

/// Reads the selection, asks the server, shows the popup and pastes the chosen translation.
internal sealed class TranslationCoordinator
{
    private readonly AppSettings settings;
    private readonly ServerTranslator translator;
    private readonly PopupWindow popup = new();
    private IntPtr targetWindow;
    private string currentText = "";
    private string? targetOverride;
    private bool reading;

    public TranslationCoordinator(AppSettings settings, ServerTranslator translator)
    {
        this.settings = settings;
        this.translator = translator;
        popup.Choose += text => _ = ApplyAsync(text);
        popup.Retry += Request;
        popup.SelectTarget += Retranslate;
        popup.OpenSettings += () =>
        {
            popup.Dismiss();
            OpenProviderSettings?.Invoke();
        };
        popup.Dismissed += translator.Cancel;
        translator.Start();
    }

    public event Action? OpenProviderSettings;

    /// Translates the selection in the window in front, or in the given one (the tray menu passes the last one).
    public async Task TranslateCurrentSelectionAsync(IntPtr? window = null)
    {
        if (reading) return;
        reading = true;
        try
        {
            var target = window ?? GetForegroundWindow();
            if (window is { } chosen && chosen != IntPtr.Zero)
            {
                SetForegroundWindow(chosen);
                await Task.Delay(150);
            }
            var selection = await SelectionReader.ReadAsync(target);
            if (selection is null)
            {
                Beep();
                return;
            }
            targetWindow = selection.Window;
            Start(selection.Text, selection.Anchor ?? SelectionReader.CursorAnchor());
        }
        finally
        {
            reading = false;
        }
    }

    private void Start(string text, PixelRect anchor)
    {
        translator.Cancel();
        currentText = text;
        targetOverride = null;
        popup.ShowLoading(text, anchor, settings.Provider);
        Request();
    }

    private void Retranslate(string? code)
    {
        if (code == targetOverride) return;
        targetOverride = code;
        popup.ShowTargetOverride(code);
        Request();
    }

    private void Request()
    {
        popup.ShowState(new ProviderState.Loading());
        translator.Translate(currentText, settings.LanguagePair, targetOverride, null, outcome =>
        {
            if (outcome.Translation is { } translation)
            {
                popup.ShowState(new ProviderState.Done(translation));
            }
            else
            {
                var error = outcome.Error;
                var opensSettings = error is TranslatorException { OpensSettings: true };
                popup.ShowState(new ProviderState.Failed(error?.Message ?? L10n.Strings.TranslationFailed, opensSettings));
            }
        });
    }

    private async Task ApplyAsync(string text)
    {
        popup.Dismiss();
        await TextReplacer.ReplaceSelectionAsync(text, targetWindow);
    }
}
