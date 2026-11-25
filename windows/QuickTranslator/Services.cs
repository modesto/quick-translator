using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Interop;
using Microsoft.Win32;
using QuickTranslator.Core;
using static QuickTranslator.Native;

namespace QuickTranslator;

/// A global hotkey on a message-only window.
internal sealed class HotKeyService : IHotKeyRegistering, IDisposable
{
    private const int Id = 1;
    private readonly HwndSource source;
    private bool registered;

    public HotKeyService()
    {
        source = new HwndSource(new HwndSourceParameters("QuickTranslatorHotKey") { ParentWindow = new IntPtr(-3), WindowStyle = 0 });
        source.AddHook(WndProc);
    }

    public event Action? Pressed;

    public bool Register(Shortcut shortcut)
    {
        Unregister();
        registered = RegisterHotKey(source.Handle, Id, (uint)shortcut.Modifiers | MOD_NOREPEAT, shortcut.KeyCode);
        return registered;
    }

    public void Unregister()
    {
        if (registered) UnregisterHotKey(source.Handle, Id);
        registered = false;
    }

    private IntPtr WndProc(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == WM_HOTKEY && wParam.ToInt32() == Id)
        {
            handled = true;
            Pressed?.Invoke();
        }
        return IntPtr.Zero;
    }

    public void Dispose()
    {
        Unregister();
        source.Dispose();
    }
}

/// Provider keys in Windows Credential Manager, as generic credentials named QuickTranslator/<account>.
internal sealed class CredentialSecretStore : ISecretStore
{
    private static string Target(string account) => $"QuickTranslator/{account}";

    public string? Secret(string account)
    {
        if (!CredRead(Target(account), CRED_TYPE_GENERIC, 0, out var pointer)) return null;
        try
        {
            var credential = Marshal.PtrToStructure<CREDENTIAL>(pointer);
            if (credential.CredentialBlobSize == 0) return null;
            var bytes = new byte[credential.CredentialBlobSize];
            Marshal.Copy(credential.CredentialBlob, bytes, 0, bytes.Length);
            return Encoding.Unicode.GetString(bytes);
        }
        finally
        {
            CredFree(pointer);
        }
    }

    public void SetSecret(string? value, string account)
    {
        if (string.IsNullOrEmpty(value))
        {
            CredDelete(Target(account), CRED_TYPE_GENERIC, 0);
            return;
        }
        var bytes = Encoding.Unicode.GetBytes(value);
        var blob = Marshal.AllocHGlobal(bytes.Length);
        try
        {
            Marshal.Copy(bytes, 0, blob, bytes.Length);
            var credential = new CREDENTIAL
            {
                Type = CRED_TYPE_GENERIC,
                TargetName = Target(account),
                CredentialBlobSize = (uint)bytes.Length,
                CredentialBlob = blob,
                Persist = CRED_PERSIST_LOCAL_MACHINE,
                UserName = "Quick Translator",
            };
            CredWrite(ref credential, 0);
        }
        finally
        {
            Marshal.FreeHGlobal(blob);
        }
    }
}

/// "Open when I sign in to Windows", as a value under HKCU\...\Run.
internal static class StartupRegistration
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "QuickTranslator";

    private static string Command => $"\"{Environment.ProcessPath}\"";

    public static bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey);
            return string.Equals(key?.GetValue(ValueName) as string, Command, StringComparison.OrdinalIgnoreCase);
        }
        set
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKey);
            if (value) key.SetValue(ValueName, Command);
            else key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
    }
}

/// Kills the CLI server and its Claude Code subprocess when the app exits, even if it crashes.
internal static class ChildProcessJob
{
    private static readonly Lazy<IntPtr> Job = new(() =>
    {
        var job = CreateJobObject(IntPtr.Zero, null);
        var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION
        {
            BasicLimitInformation = new JOBOBJECT_BASIC_LIMIT_INFORMATION { LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE },
        };
        SetInformationJobObject(job, JobObjectExtendedLimitInformation, ref info, (uint)Marshal.SizeOf<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>());
        return job;
    });

    public static void Add(System.Diagnostics.Process process) => AssignProcessToJobObject(Job.Value, process.Handle);
}
