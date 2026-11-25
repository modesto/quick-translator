using System.Text;
using System.Text.Json;
using QuickTranslator.Core;

namespace QuickTranslator.Core.Tests;

internal sealed class Recorder
{
    public List<TranslationOutcome> Results { get; } = [];
    public Action<TranslationOutcome> Completion => Results.Add;
    public List<ProviderTranslation> Successes => Results.Where(r => r.Translation is not null).Select(r => r.Translation!).ToList();
    public List<TranslatorException> Errors => Results.Select(r => r.Error).OfType<TranslatorException>().ToList();
}

public class LineBufferTests
{
    private static byte[] Bytes(string text) => Encoding.UTF8.GetBytes(text);
    private static List<string> Strings(IReadOnlyList<byte[]> lines) => lines.Select(line => Encoding.UTF8.GetString(line)).ToList();

    [Fact]
    public void ReturnsCompleteLinesAndKeepsTheRemainder()
    {
        var buffer = new LineBuffer();
        Assert.Equal(["one", "two"], Strings(buffer.Append(Bytes("one\ntwo\nthr"))));
        Assert.Equal(["three"], Strings(buffer.Append(Bytes("ee\n"))));
    }

    [Fact]
    public void JoinsALineThatArrivesInSeveralChunks()
    {
        var buffer = new LineBuffer();
        Assert.Empty(buffer.Append(Bytes("{\"id\":")));
        Assert.Empty(buffer.Append(Bytes("\"1\"")));
        Assert.Equal(["{\"id\":\"1\"}"], Strings(buffer.Append(Bytes("}\n"))));
    }

    [Fact]
    public void KeepsMultiByteCharactersSplitAcrossChunks()
    {
        var buffer = new LineBuffer();
        var bytes = Bytes("adiós\n");
        var cut = Array.IndexOf(bytes, (byte)0xC3) + 1;
        Assert.Empty(buffer.Append(bytes.AsSpan(0, cut)));
        Assert.Equal(["adiós"], Strings(buffer.Append(bytes.AsSpan(cut))));
    }

    [Fact]
    public void DropsAPartialLineOnReset()
    {
        var buffer = new LineBuffer();
        buffer.Append(Bytes("partial"));
        buffer.Reset();
        Assert.Equal(["next"], Strings(buffer.Append(Bytes("next\n"))));
    }
}

public class ServerRequestTests
{
    private static Dictionary<string, string> Decode(byte[] line) =>
        JsonSerializer.Deserialize<Dictionary<string, string>>(line.AsSpan(0, line.Length - 1))!;

    [Fact]
    public void EncodesOneJsonObjectWithThePairInEnglishTerminatedByANewline()
    {
        var line = new ServerRequest("1", "línea 1\nlínea 2", new LanguagePair("es", "fr")).EncodedLine();
        Assert.Equal((byte)'\n', line[^1]);
        Assert.DoesNotContain((byte)'\n', line[..^1]);
        Assert.Equal(new Dictionary<string, string> { ["id"] = "1", ["text"] = "línea 1\nlínea 2", ["mine"] = "Spanish", ["target"] = "French" }, Decode(line));
    }

    [Fact]
    public void SendsAOneOffTargetAsToByEnglishName()
    {
        var decoded = Decode(new ServerRequest("1", "hola", LanguagePair.Default, targetOverride: "ja").EncodedLine());
        Assert.Equal("Japanese", decoded["to"]);
        Assert.Equal("Spanish", decoded["mine"]);
    }

    [Fact]
    public void OmitsToAndProviderWhenNotGiven()
    {
        var decoded = Decode(new ServerRequest("1", "hola", LanguagePair.Default).EncodedLine());
        Assert.False(decoded.ContainsKey("to"));
        Assert.False(decoded.ContainsKey("provider"));
    }

    [Fact]
    public void AsksTheServerForASpecificProvider()
    {
        var decoded = Decode(new ServerRequest("1", "hola", LanguagePair.Default, provider: TranslationProviderKind.DeepL).EncodedLine());
        Assert.Equal("deepl", decoded["provider"]);
    }
}

public class ServerResponseRouterTests
{
    private static byte[] Bytes(string text) => Encoding.UTF8.GetBytes(text);

    private static string ResponseLine(string id, string text) =>
        $$$"""{"id":"{{{id}}}","model":"claude-haiku-5-5","result":{"sourceLanguage":"Spanish","targetLanguage":"English","variants":[{"label":"Natural","text":"{{{text}}}"}]}}""" + "\n";

    [Fact]
    public void DeliversAResultWithTheModelToItsRequest()
    {
        var start = DateTimeOffset.UnixEpoch;
        var router = new ServerResponseRouter(() => start);
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);

        router.Receive(Bytes(ResponseLine("a", "See you later")));

        var expected = new ProviderTranslation(
            new TranslationResult("Spanish", "English", [new TranslationVariant("Natural", "See you later")]),
            "claude-haiku-5-5", TranslationProviderKind.ClaudeCode, TimeSpan.Zero);
        Assert.Equal([expected], recorder.Successes);
        Assert.Equal(0, router.PendingCount);
    }

    [Fact]
    public void KeepsTheProviderAndMeasuresTheTimeToTheAnswer()
    {
        var now = DateTimeOffset.UnixEpoch;
        var router = new ServerResponseRouter(() => now);
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);
        now = now.AddSeconds(1.25);

        router.Receive(Bytes("""{"id":"a","provider":"deepl","model":"deepl","result":{"sourceLanguage":"Spanish","targetLanguage":"English","variants":[]}}""" + "\n"));

        Assert.Equal(TranslationProviderKind.DeepL, recorder.Successes[0].Provider);
        Assert.Equal(TimeSpan.FromSeconds(1.25), recorder.Successes[0].Elapsed);
    }

    [Fact]
    public void TurnsAServerErrorIntoAFailure()
    {
        var router = new ServerResponseRouter();
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);

        router.Receive(Bytes("""{"id":"a","error":"Translation failed: error_max_turns"}""" + "\n"));

        Assert.Equal([TranslatorException.Failed("Translation failed: error_max_turns")], recorder.Errors);
    }

    [Fact]
    public void TurnsACodedServerErrorIntoAProviderError()
    {
        var router = new ServerResponseRouter();
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);

        router.Receive(Bytes("""{"id":"a","provider":"claude-api","error":"bad key","code":"auth_failed"}""" + "\n"));

        var failure = Assert.Single(recorder.Errors);
        Assert.Equal(TranslatorException.ForProvider(ProviderErrorCode.AuthFailed, TranslationProviderKind.ClaudeApi, "bad key"), failure);
        Assert.Equal("Claude API ha rechazado la clave. Revísala en Ajustes.", failure.MessageIn(UILanguage.Es));
    }

    [Fact]
    public void KeepsUnknownCodesAsPlainFailures()
    {
        var router = new ServerResponseRouter();
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);

        router.Receive(Bytes("""{"id":"a","error":"boom","code":"weird"}""" + "\n"));

        Assert.Equal([TranslatorException.Failed("boom")], recorder.Errors);
    }

    [Fact]
    public void HandlesAResponseSplitAcrossChunks()
    {
        var router = new ServerResponseRouter();
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);
        var line = Bytes(ResponseLine("a", "Hi"));

        router.Receive(line.AsSpan(0, 20));
        Assert.Empty(recorder.Results);
        router.Receive(line.AsSpan(20));
        Assert.Single(recorder.Successes);
    }

    [Fact]
    public void IgnoresTheReadyMessageInvalidLinesAndUnknownIds()
    {
        var router = new ServerResponseRouter();
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);

        router.Receive(Bytes("""{"ready":true,"model":"claude-haiku-5-5"}""" + "\n"));
        router.Receive(Bytes("not json\n"));
        router.Receive(Bytes("""{"id":null,"error":"Request must be a JSON object"}""" + "\n"));
        router.Receive(Bytes(ResponseLine("unknown", "x")));

        Assert.Empty(recorder.Results);
        Assert.Equal(1, router.PendingCount);
    }

    [Fact]
    public void DropsThePreviousRequestWhenANewOneStarts()
    {
        var router = new ServerResponseRouter();
        var first = new Recorder();
        var second = new Recorder();
        router.Register("a", first.Completion);
        router.Register("b", second.Completion);

        router.Receive(Bytes(ResponseLine("a", "late")));
        router.Receive(Bytes(ResponseLine("b", "current")));

        Assert.Empty(first.Results);
        Assert.Equal(["current"], second.Successes.Select(s => s.Result.Variants[0].Text));
    }

    [Fact]
    public void IgnoresTheAnswerToACancelledRequest()
    {
        var router = new ServerResponseRouter();
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);

        router.CancelCurrent();
        router.Receive(Bytes(ResponseLine("a", "late")));

        Assert.Empty(recorder.Results);
        Assert.Equal(0, router.PendingCount);
    }

    [Fact]
    public void CompletesARequestOnlyOnceWhenSendingItFails()
    {
        var router = new ServerResponseRouter();
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);

        router.Fail("a", TranslatorException.NotConfigured());
        router.FailAll(TranslatorException.ServerStopped());
        router.Receive(Bytes(ResponseLine("a", "late")));

        Assert.Equal([TranslatorException.NotConfigured()], recorder.Errors);
    }

    [Fact]
    public void FailsEveryPendingRequestWhenTheServerStopsAndDiscardsPartialOutput()
    {
        var router = new ServerResponseRouter();
        var recorder = new Recorder();
        router.Register("a", recorder.Completion);
        router.Receive(Bytes("""{"id":"a","res"""));

        router.FailAll(TranslatorException.ServerStopped());
        Assert.Equal([TranslatorException.ServerStopped()], recorder.Errors);

        var next = new Recorder();
        router.Register("b", next.Completion);
        router.Receive(Bytes(ResponseLine("b", "fresh")));
        Assert.Single(next.Successes);
    }
}
