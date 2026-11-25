using System.Text.Json;
using System.Text.Json.Serialization;

namespace QuickTranslator.Core;

/// One request to the CLI server. Language names go in English; "to" forces a one-off target.
public sealed record ServerRequest
{
    public ServerRequest(string id, string text, LanguagePair languagePair, string? targetOverride = null, TranslationProviderKind? provider = null)
    {
        Id = id;
        Text = text;
        Mine = Languages.EnglishName(languagePair.Mine);
        Target = Languages.EnglishName(languagePair.Target);
        To = targetOverride is null ? null : Languages.EnglishName(targetOverride);
        Provider = provider?.RawValue();
    }

    [JsonPropertyName("id")] public string Id { get; }
    [JsonPropertyName("text")] public string Text { get; }
    [JsonPropertyName("mine")] public string Mine { get; }
    [JsonPropertyName("target")] public string Target { get; }

    [JsonPropertyName("to"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? To { get; }

    [JsonPropertyName("provider"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Provider { get; }

    /// UTF-8 JSON terminated by a newline; newlines inside the text are escaped.
    public byte[] EncodedLine() => [.. JsonSerializer.SerializeToUtf8Bytes(this), (byte)'\n'];
}

public sealed record ServerMessage(
    [property: JsonPropertyName("id")] string? Id,
    [property: JsonPropertyName("model")] string? Model,
    [property: JsonPropertyName("provider")] string? Provider,
    [property: JsonPropertyName("result")] TranslationResult? Result,
    [property: JsonPropertyName("error")] string? Error,
    [property: JsonPropertyName("code")] string? Code)
{
    public TranslationProviderKind ProviderKind => TranslationProviders.FromRawValue(Provider) ?? TranslationProviderKind.ClaudeCode;
}

/// Splits a byte stream into newline-terminated lines, keeping multi-byte characters split across chunks.
public sealed class LineBuffer
{
    private readonly List<byte> buffer = [];

    public IReadOnlyList<byte[]> Append(ReadOnlySpan<byte> data)
    {
        buffer.AddRange(data);
        var lines = new List<byte[]>();
        int newline;
        while ((newline = buffer.IndexOf((byte)'\n')) >= 0)
        {
            lines.Add(buffer.GetRange(0, newline).ToArray());
            buffer.RemoveRange(0, newline + 1);
        }
        return lines;
    }

    public void Reset() => buffer.Clear();
}

public sealed record TranslationOutcome(ProviderTranslation? Translation, Exception? Error)
{
    public static TranslationOutcome Success(ProviderTranslation translation) => new(translation, null);
    public static TranslationOutcome Failure(Exception error) => new(null, error);
}

/// Matches server answers to requests. Only the current request is live: a new one, or a cancel, drops it.
public sealed class ServerResponseRouter(Func<DateTimeOffset>? now = null)
{
    private readonly Func<DateTimeOffset> now = now ?? (() => DateTimeOffset.UtcNow);
    private readonly LineBuffer lines = new();
    private readonly Dictionary<string, Action<TranslationOutcome>> pending = [];
    private readonly Dictionary<string, DateTimeOffset> startedAt = [];
    private string? currentRequestId;

    public int PendingCount => pending.Count;

    public void Register(string id, Action<TranslationOutcome> completion)
    {
        CancelCurrent();
        pending[id] = completion;
        startedAt[id] = now();
        currentRequestId = id;
    }

    public void CancelCurrent()
    {
        if (currentRequestId is { } id)
        {
            pending.Remove(id);
            startedAt.Remove(id);
        }
        currentRequestId = null;
    }

    public void Fail(string id, Exception error) => Complete(id, TranslationOutcome.Failure(error));

    public void FailAll(Exception error)
    {
        lines.Reset();
        var waiting = pending.Values.ToList();
        pending.Clear();
        startedAt.Clear();
        currentRequestId = null;
        foreach (var completion in waiting) completion(TranslationOutcome.Failure(error));
    }

    public void Receive(ReadOnlySpan<byte> data)
    {
        foreach (var line in lines.Append(data)) Route(line);
    }

    private void Route(byte[] line)
    {
        ServerMessage? message;
        try { message = JsonSerializer.Deserialize<ServerMessage>(line); }
        catch (JsonException) { return; }
        if (message?.Id is not { } id) return;

        TimeSpan? elapsed = startedAt.TryGetValue(id, out var started) ? now() - started : null;
        if (message.Result is { } result)
        {
            Complete(id, TranslationOutcome.Success(new ProviderTranslation(result, message.Model, message.ProviderKind, elapsed)));
        }
        else if (ProviderErrorCodes.FromRawValue(message.Code) is { } code)
        {
            Complete(id, TranslationOutcome.Failure(TranslatorException.ForProvider(code, message.ProviderKind, message.Error ?? "")));
        }
        else
        {
            Complete(id, TranslationOutcome.Failure(TranslatorException.Failed(message.Error ?? L10n.Strings.TranslationFailed)));
        }
    }

    private void Complete(string id, TranslationOutcome outcome)
    {
        startedAt.Remove(id);
        if (!pending.Remove(id, out var completion)) return;
        if (currentRequestId == id) currentRequestId = null;
        completion(outcome);
    }
}
