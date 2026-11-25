using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using QuickTranslator.Core;
using static QuickTranslator.Native;

namespace QuickTranslator;

/// The translation popup: the original text, the provider's variants with "Use N" buttons, and a one-off target menu.
public partial class PopupWindow : Window
{
    private const double ShadowMargin = 8;
    private ProviderState state = new ProviderState.Loading();
    private TranslationProviderKind provider;
    private string? targetOverride;
    private PixelRect anchor;

    public PopupWindow()
    {
        InitializeComponent();
        SizeChanged += (_, _) => Place();
        DpiChanged += (_, _) => Place();
        Deactivated += (_, _) => Dismiss();
        PreviewKeyDown += OnKey;
    }

    public event Action<string>? Choose;
    public event Action? Retry;
    public event Action<string?>? SelectTarget;
    public event Action? OpenSettings;
    public event Action? Dismissed;

    public void ShowLoading(string original, PixelRect anchor, TranslationProviderKind provider)
    {
        this.anchor = anchor;
        this.provider = provider;
        targetOverride = null;
        state = new ProviderState.Loading();
        Original.Text = original.ReplaceLineEndings(" ");
        Render();
        if (!IsVisible)
        {
            Left = -32000;
            Top = -32000;
            Show();
        }
        Activate();
        Place();
    }

    public void ShowState(ProviderState state)
    {
        this.state = state;
        Render();
    }

    public void ShowTargetOverride(string? code)
    {
        targetOverride = code;
        Render();
    }

    public void Dismiss()
    {
        if (!IsVisible) return;
        Hide();
        Dismissed?.Invoke();
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        e.Cancel = true;
        Dismiss();
    }

    private void Render()
    {
        var language = L10n.Language;
        var strings = language.Strings();
        CloseButton.ToolTip = strings.Close;
        TargetBadge.Text = PopupText.TargetBadge(targetOverride);
        TargetBadge.Visibility = targetOverride is null ? Visibility.Collapsed : Visibility.Visible;
        TargetButton.ToolTip = PopupText.TargetHelp(targetOverride, language);
        ProviderTitle.Text = PopupText.Title(state, provider);
        ProviderSubtitle.Text = PopupText.Subtitle(state, language);
        ElapsedText.Text = PopupText.ElapsedText(state, language) ?? "";
        ElapsedText.ToolTip = strings.ResponseTime;
        LoadingText.Text = strings.Translating;
        SettingsButton.Content = strings.SettingsEllipsis;
        RetryButton.Content = strings.Retry;

        LoadingPanel.Visibility = state is ProviderState.Loading ? Visibility.Visible : Visibility.Collapsed;
        FailurePanel.Visibility = state is ProviderState.Failed ? Visibility.Visible : Visibility.Collapsed;
        if (state is ProviderState.Failed failed)
        {
            FailureMessage.Text = failed.Message;
            SettingsButton.Visibility = failed.OffersSettings ? Visibility.Visible : Visibility.Collapsed;
        }

        VariantsPanel.Children.Clear();
        if (state is ProviderState.Done done)
        {
            var variants = done.Translation.Result.Variants;
            for (var index = 0; index < variants.Count; index++)
                VariantsPanel.Children.Add(VariantRow(ChoiceKeys.First + index, variants[index], strings));
        }
    }

    private UIElement VariantRow(int key, TranslationVariant variant, UIStrings strings)
    {
        var grid = new Grid { Margin = new Thickness(0, 0, 0, 8) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var texts = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        if (!string.IsNullOrWhiteSpace(variant.Label))
        {
            var label = new TextBlock { Text = variant.Label, FontSize = 11, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 2) };
            label.SetResourceReference(TextBlock.ForegroundProperty, "TextFillColorSecondaryBrush");
            texts.Children.Add(label);
        }
        texts.Children.Add(new TextBlock { Text = variant.Text, TextWrapping = TextWrapping.Wrap });
        grid.Children.Add(texts);

        var use = new Button
        {
            Content = strings.Use(key.ToString()),
            ToolTip = strings.UseHelp(key.ToString()),
            Padding = new Thickness(10, 3, 10, 3),
            Margin = new Thickness(10, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
        };
        if (key == ChoiceKeys.First) use.SetResourceReference(StyleProperty, "AccentButtonStyle");
        use.Click += (_, _) => Choose?.Invoke(variant.Text);
        Grid.SetColumn(use, 1);
        grid.Children.Add(use);
        return grid;
    }

    private void OnKey(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            Dismiss();
            e.Handled = true;
            return;
        }
        var number = e.Key switch
        {
            >= Key.D1 and <= Key.D9 => e.Key - Key.D0,
            >= Key.NumPad1 and <= Key.NumPad9 => e.Key - Key.NumPad0,
            _ => 0,
        };
        if (number > 0 && ChoiceKeys.Text(number, state) is { } text)
        {
            e.Handled = true;
            Choose?.Invoke(text);
        }
    }

    private void OnTargetClick(object sender, RoutedEventArgs e)
    {
        var language = L10n.Language;
        var menu = new ContextMenu { PlacementTarget = TargetButton, Placement = System.Windows.Controls.Primitives.PlacementMode.Bottom };
        var configured = new MenuItem { Header = language.Strings().ConfiguredLanguages, IsEnabled = targetOverride is not null };
        configured.Click += (_, _) => SelectTarget?.Invoke(null);
        menu.Items.Add(configured);
        menu.Items.Add(new Separator());
        foreach (var code in Languages.SortedCodes(language))
        {
            var item = new MenuItem { Header = Languages.DisplayName(code, language), IsCheckable = true, IsChecked = code == targetOverride };
            item.Click += (_, _) => SelectTarget?.Invoke(code);
            menu.Items.Add(item);
        }
        menu.IsOpen = true;
    }

    private void OnCloseClick(object sender, RoutedEventArgs e) => Dismiss();

    private void OnRetryClick(object sender, RoutedEventArgs e) => Retry?.Invoke();

    private void OnSettingsClick(object sender, RoutedEventArgs e) => OpenSettings?.Invoke();

    private void OnDrag(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed && e.OriginalSource is Border) DragMove();
    }

    /// Positions the card (the window minus its shadow margin) next to the selection, in physical pixels.
    private void Place()
    {
        if (!IsVisible) return;
        var handle = new WindowInteropHelper(this).Handle;
        if (handle == IntPtr.Zero || !GetWindowRect(handle, out var rect)) return;

        var targetScale = ScaleAt(anchor.X + anchor.Width / 2, anchor.Y + anchor.Height / 2);
        var currentScale = VisualTreeHelper.GetDpi(this).DpiScaleX;
        var factor = targetScale / currentScale;
        var margin = ShadowMargin * targetScale;
        var card = new PixelSize((rect.Right - rect.Left) * factor - 2 * margin, (rect.Bottom - rect.Top) * factor - 2 * margin);

        var screens = System.Windows.Forms.Screen.AllScreens.Select(Area).ToList();
        var primary = System.Windows.Forms.Screen.PrimaryScreen is { } main ? Area(main) : null;
        var origin = PopupPlacement.Origin(card, anchor, screens, primary, targetScale);
        SetWindowPos(handle, IntPtr.Zero, (int)Math.Round(origin.X - margin), (int)Math.Round(origin.Y - margin), 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    }

    private static ScreenArea Area(System.Windows.Forms.Screen screen) => new(
        new PixelRect(screen.Bounds.X, screen.Bounds.Y, screen.Bounds.Width, screen.Bounds.Height),
        new PixelRect(screen.WorkingArea.X, screen.WorkingArea.Y, screen.WorkingArea.Width, screen.WorkingArea.Height));
}
