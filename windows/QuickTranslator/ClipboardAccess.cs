using System.Runtime.InteropServices;
using System.Windows;

namespace QuickTranslator;

/// The clipboard, with retries: another app often holds it open for a moment right after copying.
internal static class ClipboardAccess
{
    public sealed class Snapshot
    {
        private readonly List<(string Format, object Data)> entries = [];

        public static Snapshot Take()
        {
            var snapshot = new Snapshot();
            var data = Retry(Clipboard.GetDataObject);
            if (data is null) return snapshot;
            foreach (var format in Retry(() => data.GetFormats(false)) ?? [])
            {
                try
                {
                    if (data.GetData(format, false) is { } value) snapshot.entries.Add((format, value));
                }
                catch (Exception exception) when (exception is COMException or OutOfMemoryException or ExternalException)
                {
                    // Some formats are rendered on demand by their owner and can't be read; they are not restored.
                }
            }
            return snapshot;
        }

        public void Restore()
        {
            if (entries.Count == 0)
            {
                Retry(() => { Clipboard.Clear(); return true; });
                return;
            }
            var data = new DataObject();
            foreach (var (format, value) in entries) data.SetData(format, value, false);
            Retry(() => { Clipboard.SetDataObject(data, copy: true); return true; });
        }
    }

    public static (string? Plain, string? Html) ReadText()
    {
        var plain = Retry(() => Clipboard.ContainsText(TextDataFormat.UnicodeText) ? Clipboard.GetText(TextDataFormat.UnicodeText) : null);
        var html = Retry(() => Clipboard.ContainsText(TextDataFormat.Html) ? Clipboard.GetText(TextDataFormat.Html) : null);
        return (plain, html);
    }

    public static bool SetText(string text) => Retry(() => { Clipboard.SetDataObject(new DataObject(DataFormats.UnicodeText, text), copy: true); return true; });

    private static T? Retry<T>(Func<T?> action)
    {
        for (var attempt = 0; ; attempt++)
        {
            try { return action(); }
            catch (Exception exception) when (exception is COMException or ExternalException && attempt < 10)
            {
                Thread.Sleep(20);
            }
            catch (Exception exception) when (exception is COMException or ExternalException)
            {
                return default;
            }
        }
    }
}
