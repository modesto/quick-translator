using System.ComponentModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using QuickTranslator.Core;

namespace QuickTranslator;

public enum SettingsTab { General, Provider }

/// Settings: the shortcut, the language pair, startup, and the translation provider with its key and model.
public partial class SettingsWindow : Window
{
    private readonly AppSettings settings;
    private readonly ISecretStore secrets;
    private readonly ShortcutManager shortcuts;
    private readonly Action restartServer;
    private readonly Action<string, LanguagePair, TranslationProviderKind, Action<TranslationOutcome>> test;
    private bool updating;
    private bool recording;
    private int testGeneration;

    internal SettingsWindow(
        AppSettings settings,
        ISecretStore secrets,
        ShortcutManager shortcuts,
        Action restartServer,
        Action<string, LanguagePair, TranslationProviderKind, Action<TranslationOutcome>> test)
    {
        this.settings = settings;
        this.secrets = secrets;
        this.shortcuts = shortcuts;
        this.restartServer = restartServer;
        this.test = test;
        InitializeComponent();
        PreviewKeyDown += OnRecordKey;
        Closing += OnClosingWindow;
        Refresh();
    }

    /// Fires after the shortcut changes, so the tray menu can show it.
    public event Action? ShortcutChanged;

    /// Fires after "my" language changes, so the rest of the app can switch its UI language.
    public event Action? LanguagePairChanged;

    public void Present(SettingsTab tab)
    {
        Refresh();
        Tabs.SelectedIndex = tab == SettingsTab.Provider ? 1 : 0;
        if (!IsVisible) Show();
        if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal;
        Activate();
        Topmost = true;
        Topmost = false;
        Focus();
    }

    /// Writes every text in the UI language and loads the current settings.
    public void Refresh()
    {
        updating = true;
        var language = L10n.Language;
        var strings = language.Strings();
        Title = strings.SettingsTitle;
        GeneralTab.Header = strings.GeneralTab;
        ProviderTab.Header = strings.ProviderTab;

        ShortcutTitle.Text = strings.ShortcutSection;
        RecordButton.Content = recording ? strings.Cancel : strings.RecordShortcut;
        ResetButton.Content = strings.Reset;
        ResetButton.ToolTip = strings.ResetHelp(Shortcut.Default.DisplayString(language));
        ShowShortcut();

        LanguagesTitle.Text = strings.LanguagesSection;
        MyLanguageLabel.Text = strings.MyLanguage;
        TargetLanguageLabel.Text = strings.TargetLanguage;
        LanguagesFooter.Text = strings.LanguagesFooter;
        FillLanguages(MyLanguage, settings.LanguagePair.Mine, language);
        FillLanguages(TargetLanguage, settings.LanguagePair.Target, language);

        StartupTitle.Text = strings.StartupSection;
        OpenAtLogin.Content = strings.OpenAtLogin;
        OpenAtLogin.IsChecked = StartupRegistration.IsEnabled;

        ProviderLabel.Text = strings.Provider;
        ProviderPicker.ItemsSource = TranslationProviders.All.Select(kind => new Choice<TranslationProviderKind>(kind, kind.DisplayName())).ToList();
        ProviderPicker.SelectedIndex = TranslationProviders.All.ToList().IndexOf(settings.Provider);
        BaseUrl.Text = settings.OpenAIBaseUrl;
        OpenAIModel.Text = settings.OpenAIModel;
        KeyBox.Password = "";
        updating = false;
        ShowProvider();
    }

    private void ShowShortcut()
    {
        ShortcutText.Text = recording ? "…" : shortcuts.Current.DisplayString(L10n.Language);
        ShortcutBox.SetResourceReference(Border.BorderBrushProperty, recording ? "AccentFillColorDefaultBrush" : "ControlStrokeColorDefaultBrush");
        ResetButton.IsEnabled = !recording && shortcuts.Current != Shortcut.Default;
        RecordButton.Content = recording ? L10n.Strings.Cancel : L10n.Strings.RecordShortcut;
    }

    private void ShowShortcutMessage(string? message, bool isError)
    {
        ShortcutMessage.Text = message ?? "";
        ShortcutMessage.Visibility = message is null ? Visibility.Collapsed : Visibility.Visible;
        if (isError) ShortcutMessage.SetResourceReference(TextBlock.ForegroundProperty, "SystemFillColorCriticalBrush");
        else ShortcutMessage.SetResourceReference(TextBlock.ForegroundProperty, "TextFillColorSecondaryBrush");
    }

    private static void FillLanguages(ComboBox box, string selected, UILanguage language)
    {
        var choices = Languages.SortedCodes(language).Select(code => new Choice<string>(code, Languages.DisplayName(code, language))).ToList();
        box.ItemsSource = choices;
        box.SelectedIndex = choices.FindIndex(choice => choice.Value == selected);
    }

    private void ShowProvider()
    {
        updating = true;
        var language = L10n.Language;
        var strings = language.Strings();
        var kind = settings.Provider;
        var official = OpenAIBaseUrl.IsOfficial(settings.OpenAIBaseUrl);

        ProviderTitle.Text = kind.DisplayName();
        ClaudeCodeDetails.Text = strings.ClaudeCodeDetails;
        ClaudeCodeDetails.Visibility = Show(kind == TranslationProviderKind.ClaudeCode);

        BaseUrlPanel.Visibility = Show(kind == TranslationProviderKind.OpenAI);
        BaseUrlLabel.Text = strings.ApiURL;
        SaveBaseUrl.Content = strings.Save;
        ShowBaseUrlHelp(invalid: false);
        UpdateSaveBaseUrl();

        KeyPanel.Visibility = Show(kind.KeyAccount() is not null);
        var hasKey = HasKey(kind);
        KeyPlaceholder.Text = hasKey ? strings.KeySaved : kind switch
        {
            TranslationProviderKind.ClaudeApi => "sk-ant-…",
            TranslationProviderKind.OpenAI => "sk-…",
            _ => "xxxxxxxx-…:fx",
        };
        UpdateKeyPlaceholder();
        SaveKey.Content = strings.Save;
        RemoveKey.Content = strings.Remove;
        RemoveKey.Visibility = Show(hasKey);
        SaveKey.IsEnabled = KeyBox.Password.Trim().Length > 0;
        KeyHelp.Text = kind switch
        {
            TranslationProviderKind.ClaudeApi => strings.BilledSeparately,
            TranslationProviderKind.OpenAI => official ? strings.BilledByUsage : strings.KeyOptional,
            _ => strings.DeepLHelp,
        };
        var page = kind.KeyPage(language);
        KeyLinkText.Text = page?.Title ?? "";
        KeyLink.Tag = page?.Url;

        ClaudeModelPanel.Visibility = Show(kind == TranslationProviderKind.ClaudeApi);
        ClaudeModelLabel.Text = strings.Model;
        ClaudeModel.ItemsSource = ModelOption.Claude.Select(option => new Choice<string>(option.Id, $"{option.DisplayName} — {option.NoteText(language)}")).ToList();
        ClaudeModel.SelectedIndex = ModelOption.Claude.ToList().FindIndex(option => option.Id == settings.ClaudeApiModel);

        OpenAIModelPanel.Visibility = Show(kind == TranslationProviderKind.OpenAI);
        OpenAIModelLabel.Text = strings.Model;
        OpenAIModelPlaceholder.Text = strings.ModelPlaceholder;
        OpenAIModelMenu.ToolTip = strings.OpenAIModelsHelp;
        SaveOpenAIModel.Content = strings.Save;
        UpdateOpenAIModelControls();

        TestButton.Content = strings.Test;
        UpdateTestButton();
        updating = false;
    }

    private static Visibility Show(bool visible) => visible ? Visibility.Visible : Visibility.Collapsed;

    private bool HasKey(TranslationProviderKind kind) =>
        kind.KeyAccount() is { } account && !string.IsNullOrEmpty(secrets.Secret(account));

    private void UpdateTestButton() =>
        TestButton.IsEnabled = TestProgress.Visibility != Visibility.Visible
            && ProviderSetup.IsReady(settings.Provider, HasKey(settings.Provider), settings.OpenAIBaseUrl, settings.OpenAIModel);

    private void ResetTest()
    {
        testGeneration++;
        TestProgress.Visibility = Visibility.Collapsed;
        TestResult.Visibility = Visibility.Collapsed;
    }

    // Shortcut

    private void OnRecordClick(object sender, RoutedEventArgs e)
    {
        if (recording) StopRecording();
        else StartRecording();
    }

    private void StartRecording()
    {
        shortcuts.Pause();
        recording = true;
        ShowShortcut();
        ShowShortcutMessage(L10n.Strings.PressNewShortcut, isError: false);
    }

    private void StopRecording()
    {
        if (!recording) return;
        recording = false;
        if (!shortcuts.IsActive) shortcuts.Activate();
        ShowShortcut();
        ShowShortcutMessage(null, isError: false);
    }

    private void OnRecordKey(object sender, KeyEventArgs e)
    {
        if (!recording) return;
        e.Handled = true;
        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        var modifiers = CurrentModifiers();
        if (key == Key.Escape && modifiers == ShortcutModifiers.None)
        {
            StopRecording();
            return;
        }
        var keyCode = (uint)KeyInterop.VirtualKeyFromKey(key);
        if (keyCode == 0 || Shortcut.IsModifierKey(keyCode)) return;

        var character = (char)(Native.MapVirtualKeyW(keyCode, Native.MAPVK_VK_TO_CHAR) & 0x7FFF);
        var shortcut = Shortcut.Create(keyCode, modifiers, character == 0 ? null : character.ToString(), L10n.Language);
        if (ShortcutValidator.Validate(shortcut, L10n.Language) is { } invalid)
        {
            ShowShortcutMessage(invalid.Message(L10n.Language), isError: true);
            return;
        }
        recording = false;
        Apply(shortcut);
    }

    private static ShortcutModifiers CurrentModifiers()
    {
        var modifiers = ShortcutModifiers.None;
        var keys = System.Windows.Input.Keyboard.Modifiers;
        if (keys.HasFlag(ModifierKeys.Control)) modifiers |= ShortcutModifiers.Control;
        if (keys.HasFlag(ModifierKeys.Alt)) modifiers |= ShortcutModifiers.Alt;
        if (keys.HasFlag(ModifierKeys.Shift)) modifiers |= ShortcutModifiers.Shift;
        if (keys.HasFlag(ModifierKeys.Windows)) modifiers |= ShortcutModifiers.Win;
        return modifiers;
    }

    private void Apply(Shortcut shortcut)
    {
        var language = L10n.Language;
        var error = shortcuts.Change(shortcut, language);
        ShowShortcut();
        if (error is null)
        {
            ShowShortcutMessage(language.Strings().ShortcutChanged(shortcut.DisplayString(language)), isError: false);
            ShortcutChanged?.Invoke();
        }
        else
        {
            ShowShortcutMessage(error.Message(language), isError: true);
        }
    }

    private void OnResetClick(object sender, RoutedEventArgs e) => Apply(Shortcut.Default);

    // Languages

    private void OnMineChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!updating && MyLanguage.SelectedItem is Choice<string> choice) UpdatePair(settings.LanguagePair.WithMine(choice.Value));
    }

    private void OnTargetChanged(object sender, SelectionChangedEventArgs e)
    {
        if (!updating && TargetLanguage.SelectedItem is Choice<string> choice) UpdatePair(settings.LanguagePair.WithTarget(choice.Value));
    }

    private void UpdatePair(LanguagePair pair)
    {
        if (pair == settings.LanguagePair) return;
        settings.LanguagePair = pair;
        var language = UILanguages.ForLanguage(pair.Mine);
        if (language != L10n.Language) L10n.Language = language;
        Dispatcher.BeginInvoke(Refresh);
        LanguagePairChanged?.Invoke();
    }

    private void OnOpenAtLoginClick(object sender, RoutedEventArgs e) => StartupRegistration.IsEnabled = OpenAtLogin.IsChecked == true;

    // Provider

    private void OnProviderChanged(object sender, SelectionChangedEventArgs e)
    {
        if (updating || ProviderPicker.SelectedItem is not Choice<TranslationProviderKind> choice || choice.Value == settings.Provider) return;
        settings.Provider = choice.Value;
        KeyBox.Password = "";
        ResetTest();
        restartServer();
        ShowProvider();
    }

    private void OnClaudeModelChanged(object sender, SelectionChangedEventArgs e)
    {
        if (updating || ClaudeModel.SelectedItem is not Choice<string> choice || choice.Value == settings.ClaudeApiModel) return;
        settings.ClaudeApiModel = choice.Value;
        ResetTest();
        restartServer();
    }

    private void OnBaseUrlChanged(object sender, TextChangedEventArgs e)
    {
        if (updating) return;
        UpdateSaveBaseUrl();
        ShowBaseUrlHelp(invalid: false);
    }

    private void UpdateSaveBaseUrl() => SaveBaseUrl.IsEnabled = OpenAIBaseUrl.Normalized(BaseUrl.Text) != settings.OpenAIBaseUrl;

    private void ShowBaseUrlHelp(bool invalid)
    {
        var strings = L10n.Strings;
        BaseUrlHelp.Text = invalid ? strings.InvalidURL : OpenAIBaseUrl.IsOfficial(settings.OpenAIBaseUrl) ? strings.OfficialURLHelp : strings.CompatibleURLHelp;
        BaseUrlHelp.SetResourceReference(TextBlock.ForegroundProperty, invalid ? "SystemFillColorCriticalBrush" : "TextFillColorSecondaryBrush");
    }

    private void OnBaseUrlKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) SaveBaseUrlDraft();
    }

    private void OnSaveBaseUrlClick(object sender, RoutedEventArgs e) => SaveBaseUrlDraft();

    private void SaveBaseUrlDraft()
    {
        if (OpenAIBaseUrl.Normalized(BaseUrl.Text) is not { } normalized)
        {
            ShowBaseUrlHelp(invalid: true);
            return;
        }
        updating = true;
        BaseUrl.Text = normalized;
        updating = false;
        if (normalized == settings.OpenAIBaseUrl)
        {
            UpdateSaveBaseUrl();
            return;
        }
        settings.OpenAIBaseUrl = normalized;
        OpenAIModel.Text = settings.OpenAIModel;
        ResetTest();
        restartServer();
        ShowProvider();
    }

    private void OnOpenAIModelChanged(object sender, TextChangedEventArgs e)
    {
        if (!updating) UpdateOpenAIModelControls();
    }

    private void UpdateOpenAIModelControls()
    {
        OpenAIModelPlaceholder.Visibility = Show(OpenAIModel.Text.Length == 0);
        SaveOpenAIModel.IsEnabled = OpenAIModel.Text.Trim() != settings.OpenAIModel;
    }

    private void OnOpenAIModelKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) SelectOpenAIModel(OpenAIModel.Text);
    }

    private void OnSaveOpenAIModelClick(object sender, RoutedEventArgs e) => SelectOpenAIModel(OpenAIModel.Text);

    private void OnOpenAIModelMenuClick(object sender, RoutedEventArgs e)
    {
        var menu = new ContextMenu { PlacementTarget = OpenAIModelMenu, Placement = System.Windows.Controls.Primitives.PlacementMode.Bottom };
        foreach (var option in ModelOption.OpenAI)
        {
            var item = new MenuItem { Header = $"{option.DisplayName} — {option.NoteText(L10n.Language)}" };
            item.Click += (_, _) => SelectOpenAIModel(option.Id);
            menu.Items.Add(item);
        }
        menu.IsOpen = true;
    }

    private void SelectOpenAIModel(string id)
    {
        id = id.Trim();
        updating = true;
        OpenAIModel.Text = id.Length == 0 ? settings.OpenAIModel : id;
        updating = false;
        if (id.Length > 0 && id != settings.OpenAIModel)
        {
            settings.OpenAIModel = id;
            ResetTest();
            restartServer();
        }
        UpdateOpenAIModelControls();
        UpdateTestButton();
    }

    private void OnKeyChanged(object sender, RoutedEventArgs e)
    {
        UpdateKeyPlaceholder();
        SaveKey.IsEnabled = KeyBox.Password.Trim().Length > 0;
    }

    private void UpdateKeyPlaceholder() => KeyPlaceholder.Visibility = Show(KeyBox.Password.Length == 0);

    private void OnKeyBoxKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) SaveKeyDraft();
    }

    private void OnSaveKeyClick(object sender, RoutedEventArgs e) => SaveKeyDraft();

    private void SaveKeyDraft()
    {
        if (settings.Provider.KeyAccount() is not { } account) return;
        var value = KeyBox.Password.Trim();
        if (value.Length == 0) return;
        secrets.SetSecret(value, account);
        KeyBox.Password = "";
        ResetTest();
        restartServer();
        ShowProvider();
    }

    private void OnRemoveKeyClick(object sender, RoutedEventArgs e)
    {
        if (settings.Provider.KeyAccount() is not { } account) return;
        secrets.SetSecret(null, account);
        ResetTest();
        restartServer();
        ShowProvider();
    }

    private void OnKeyLinkClick(object sender, RoutedEventArgs e)
    {
        if (KeyLink.Tag is string url) Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
    }

    private void OnTestClick(object sender, RoutedEventArgs e)
    {
        var kind = settings.Provider;
        var generation = ++testGeneration;
        TestProgress.Visibility = Visibility.Visible;
        TestResult.Visibility = Visibility.Collapsed;
        UpdateTestButton();
        test(L10n.Strings.TestSentence, settings.LanguagePair, kind, outcome =>
        {
            if (generation != testGeneration || kind != settings.Provider) return;
            TestProgress.Visibility = Visibility.Collapsed;
            TestResult.Visibility = Visibility.Visible;
            if (outcome.Translation is { } translation)
            {
                var first = translation.Result.Variants.FirstOrDefault()?.Text ?? "";
                var time = translation.Elapsed is { } elapsed ? Elapsed.Format(elapsed, L10n.Language) : "";
                TestResult.Text = $"✓ {time} · «{first}»";
                TestResult.SetResourceReference(TextBlock.ForegroundProperty, "SystemFillColorSuccessBrush");
            }
            else
            {
                TestResult.Text = "⚠ " + (outcome.Error?.Message ?? L10n.Strings.TranslationFailed);
                TestResult.SetResourceReference(TextBlock.ForegroundProperty, "SystemFillColorCriticalBrush");
            }
            UpdateTestButton();
        });
    }

    private void OnClosingWindow(object? sender, CancelEventArgs e)
    {
        e.Cancel = true;
        StopRecording();
        ShowShortcutMessage(null, isError: false);
        Hide();
    }
}

internal sealed record Choice<T>(T Value, string Title)
{
    public override string ToString() => Title;
}
