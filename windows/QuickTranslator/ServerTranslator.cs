using System.Diagnostics;
using System.IO;
using System.Windows.Threading;
using QuickTranslator.Core;

namespace QuickTranslator;

/// Runs the CLI in --server mode and talks to it with newline-delimited JSON over stdin/stdout.
internal sealed class ServerTranslator(AppSettings settings, ISecretStore secrets, Dispatcher dispatcher) : IDisposable
{
    private readonly ServerResponseRouter router = new();
    private Process? process;

    public void Start()
    {
        if (process is not null) return;
        try { Launch(); }
        catch (Exception exception) when (exception is TranslatorException or IOException or System.ComponentModel.Win32Exception) { }
    }

    public void Restart()
    {
        Stop();
        Start();
    }

    public void Translate(string text, LanguagePair languagePair, string? targetOverride, TranslationProviderKind? provider, Action<TranslationOutcome> completion)
    {
        var id = Guid.NewGuid().ToString();
        router.Register(id, completion);
        try
        {
            if (process is null) Launch();
            var line = new ServerRequest(id, text, languagePair, targetOverride, provider).EncodedLine();
            var input = process!.StandardInput.BaseStream;
            input.Write(line);
            input.Flush();
        }
        catch (Exception exception) when (exception is TranslatorException or IOException or InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            router.Fail(id, exception as TranslatorException ?? TranslatorException.ServerStopped());
        }
    }

    public void Cancel() => router.CancelCurrent();

    public void Dispose() => Stop();

    private void Stop()
    {
        if (process is not { } running) return;
        process = null;
        running.EnableRaisingEvents = false;
        try { running.Kill(entireProcessTree: true); }
        catch (Exception exception) when (exception is InvalidOperationException or System.ComponentModel.Win32Exception) { }
        running.Dispose();
        router.FailAll(TranslatorException.ServerStopped());
    }

    private static ServerPaths? Paths()
    {
        var file = Path.Combine(AppContext.BaseDirectory, ServerPaths.FileName);
        return File.Exists(file) ? ServerPaths.Parse(File.ReadAllText(file)) : null;
    }

    private void Launch()
    {
        if (Paths() is not { } paths || !File.Exists(paths.NodePath) || !File.Exists(paths.CliPath))
            throw TranslatorException.NotConfigured();

        var info = new ProcessStartInfo(paths.NodePath)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardInputEncoding = new System.Text.UTF8Encoding(false),
            WorkingDirectory = Path.GetDirectoryName(paths.CliPath)!,
        };
        foreach (var argument in ServerLaunch.Arguments(paths.CliPath, settings.Provider, settings.ClaudeApiModel, settings.OpenAIModel, settings.OpenAIBaseUrl))
            info.ArgumentList.Add(argument);
        ServerLaunch.ApplyKeys(info.Environment, secrets);

        var started = new Process { StartInfo = info, EnableRaisingEvents = true };
        started.Exited += (_, _) => dispatcher.BeginInvoke(() => ServerDidStop(started));
        started.ErrorDataReceived += (_, _) => { };
        started.Start();
        ChildProcessJob.Add(started);
        started.BeginErrorReadLine();
        process = started;
        _ = ReadOutputAsync(started);
    }

    private async Task ReadOutputAsync(Process running)
    {
        var buffer = new byte[16 * 1024];
        var output = running.StandardOutput.BaseStream;
        try
        {
            int read;
            while ((read = await output.ReadAsync(buffer)) > 0)
            {
                var chunk = buffer.AsSpan(0, read).ToArray();
                await dispatcher.InvokeAsync(() => { if (process == running) router.Receive(chunk); });
            }
        }
        catch (Exception exception) when (exception is IOException or ObjectDisposedException or InvalidOperationException) { }
    }

    private void ServerDidStop(Process finished)
    {
        if (finished != process) return;
        process = null;
        finished.Dispose();
        router.FailAll(TranslatorException.ServerStopped());
    }
}
