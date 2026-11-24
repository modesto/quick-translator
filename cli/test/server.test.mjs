import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ProviderError } from "../dist/providers.js";
import { defaultProviderFactory, parseRequest, ProviderRegistry, serve } from "../dist/server.js";

const SETTINGS = { defaultProvider: "claude-code", defaultCount: 4 };

function resultFor(text) {
  return { sourceLanguage: "Spanish", targetLanguage: "English", variants: [{ label: "Natural", text: `EN:${text}` }] };
}

function fakeProvider({ id = "claude-code", model = "claude-haiku-5-5", warmUp = () => Promise.resolve(), translate } = {}) {
  const calls = [];
  return {
    id,
    model,
    calls,
    closed: false,
    warmUp,
    async translate(text, request) {
      calls.push({ text, request });
      return translate ? translate(text, request) : resultFor(text);
    },
    async close() {
      this.closed = true;
    },
  };
}

function registryOf(...providers) {
  const byId = new Map(providers.map((provider) => [provider.id, provider]));
  const created = [];
  const registry = new ProviderRegistry((id) => {
    created.push(id);
    const provider = byId.get(id);
    if (!provider) throw new Error(`no fake for ${id}`);
    return provider;
  });
  return { registry, created };
}

async function* linesOf(...lines) {
  for (const line of lines) yield line;
}

async function run(provider, ...lines) {
  const sent = [];
  await serve(registryOf(provider).registry, linesOf(...lines), (message) => sent.push(message), SETTINGS);
  await new Promise((resolve) => setImmediate(resolve));
  return sent;
}

function responses(sent) {
  return sent.filter((message) => !("ready" in message));
}

describe("parseRequest", () => {
  it("parses a minimal request", () => {
    assert.deepEqual(parseRequest('{"id":"1","text":"hola"}'), {
      id: "1",
      text: "hola",
      to: undefined,
      count: undefined,
      languagePair: undefined,
      provider: undefined,
    });
  });

  it("keeps the optional target language, count and provider", () => {
    assert.deepEqual(parseRequest('{"id":"1","text":"hola","to":"French","count":2,"provider":"deepl"}'), {
      id: "1",
      text: "hola",
      to: "French",
      count: 2,
      languagePair: undefined,
      provider: "deepl",
    });
  });

  it("reads the language pair", () => {
    assert.deepEqual(parseRequest('{"id":"1","text":"hola","mine":" Spanish ","target":"French"}').languagePair, {
      mine: "Spanish",
      target: "French",
    });
  });

  const invalid = {
    "invalid JSON": ["{", SyntaxError],
    "a JSON array": ['["hola"]', /must be a JSON object/],
    "a JSON string": ['"hola"', /must be a JSON object/],
    "a numeric id": ['{"id":1,"text":"hola"}', /string 'id'/],
    "a missing text": ['{"id":"1"}', /non-empty 'text'/],
    "a blank text": ['{"id":"1","text":"   "}', /non-empty 'text'/],
    "a zero count": ['{"id":"1","text":"hola","count":0}', /'count' must be an integer between 1 and 8/],
    "a fractional count": ['{"id":"1","text":"hola","count":1.5}', /'count'/],
    "a string count": ['{"id":"1","text":"hola","count":"2"}', /'count'/],
    "only mine": ['{"id":"1","text":"hola","mine":"Spanish"}', /given together/],
    "only target": ['{"id":"1","text":"hola","target":"French"}', /given together/],
    "an empty target": ['{"id":"1","text":"hola","mine":"Spanish","target":" "}', /given together/],
    "the same language twice": ['{"id":"1","text":"hola","mine":"Spanish","target":"spanish"}', /different languages/],
    "an unknown provider": ['{"id":"1","text":"hola","provider":"google"}', /'provider' must be one of claude-code, claude-api, deepl/],
  };

  for (const [name, [line, expected]] of Object.entries(invalid)) {
    it(`rejects ${name}`, () => {
      assert.throws(() => parseRequest(line), expected);
    });
  }
});

describe("serve", () => {
  it("answers each request with its id, provider, model and result", async () => {
    const sent = await run(fakeProvider(), '{"id":"a","text":"hola"}', '{"id":"b","text":"adiós"}');

    assert.deepEqual(
      responses(sent).sort((x, y) => x.id.localeCompare(y.id)),
      [
        { id: "a", provider: "claude-code", model: "claude-haiku-5-5", result: resultFor("hola") },
        { id: "b", provider: "claude-code", model: "claude-haiku-5-5", result: resultFor("adiós") },
      ],
    );
  });

  it("passes the target language and uses the default count when none is given", async () => {
    const provider = fakeProvider();
    await run(provider, '{"id":"a","text":"hola","to":"French"}', '{"id":"b","text":"hola","count":2}');

    assert.deepEqual(provider.calls.map((call) => call.request), [
      { targetLanguage: "French", count: 4, languagePair: undefined },
      { targetLanguage: undefined, count: 2, languagePair: undefined },
    ]);
  });

  it("uses the request's language pair, or the server default when it has none", async () => {
    const provider = fakeProvider();
    const defaultLanguagePair = { mine: "Spanish", target: "German" };
    await serve(
      registryOf(provider).registry,
      linesOf('{"id":"a","text":"hola","mine":"Spanish","target":"French"}', '{"id":"b","text":"hola"}'),
      () => {},
      { ...SETTINGS, defaultLanguagePair },
    );

    assert.deepEqual(
      provider.calls.map((call) => call.request.languagePair),
      [{ mine: "Spanish", target: "French" }, defaultLanguagePair],
    );
  });

  it("routes each request to its provider and warms only the default one", async () => {
    const claudeCode = fakeProvider();
    let deeplWarmed = false;
    const deepl = fakeProvider({ id: "deepl", model: "deepl", warmUp: async () => (deeplWarmed = true) });
    const { registry, created } = registryOf(claudeCode, deepl);
    const sent = [];

    await serve(registry, linesOf('{"id":"a","text":"hola","provider":"deepl"}', '{"id":"b","text":"hola"}'), (m) => sent.push(m), SETTINGS);
    await new Promise((resolve) => setImmediate(resolve));

    assert.equal(deepl.calls.length, 1);
    assert.equal(claudeCode.calls.length, 1);
    assert.equal(deeplWarmed, false);
    assert.deepEqual(created, ["claude-code", "deepl"]);
    assert.deepEqual(
      responses(sent).map((m) => [m.id, m.provider, m.model]).sort(),
      [
        ["a", "deepl", "deepl"],
        ["b", "claude-code", "claude-haiku-5-5"],
      ],
    );
  });

  it("creates each provider once and closes them all at the end", async () => {
    const deepl = fakeProvider({ id: "deepl", model: "deepl" });
    const { registry, created } = registryOf(fakeProvider(), deepl);

    await serve(registry, linesOf('{"id":"a","text":"x","provider":"deepl"}', '{"id":"b","text":"y","provider":"deepl"}'), () => {}, SETTINGS);

    assert.deepEqual(created, ["claude-code", "deepl"]);
    assert.equal(deepl.closed, true);
  });

  it("reports a translation failure under the request id", async () => {
    const provider = fakeProvider({ translate: () => Promise.reject(new Error("Translation failed: error_max_turns")) });
    const sent = await run(provider, '{"id":"a","text":"hola"}');

    assert.deepEqual(responses(sent), [{ id: "a", error: "Translation failed: error_max_turns", provider: "claude-code" }]);
  });

  it("adds the provider error code so the app can explain it", async () => {
    const provider = fakeProvider({ translate: () => Promise.reject(new ProviderError("quota_exceeded", "quota")) });
    const sent = await run(provider, '{"id":"a","text":"hola"}');

    assert.deepEqual(responses(sent), [{ id: "a", error: "quota", code: "quota_exceeded", provider: "claude-code" }]);
  });

  it("reports an invalid line with a null id and keeps serving", async () => {
    const provider = fakeProvider();
    const sent = await run(provider, "not json", '{"id":"a","text":"hola"}');

    const [invalid, valid] = responses(sent);
    assert.equal(invalid.id, null);
    assert.match(invalid.error, /JSON/);
    assert.equal(valid.id, "a");
    assert.equal(provider.calls.length, 1);
  });

  it("ignores blank lines", async () => {
    const provider = fakeProvider();
    const sent = await run(provider, "", "   ", '{"id":"a","text":"hola"}');

    assert.equal(responses(sent).length, 1);
    assert.equal(provider.calls.length, 1);
  });

  it("announces when the default provider is ready", async () => {
    const sent = await run(fakeProvider());
    assert.deepEqual(sent, [{ ready: true, provider: "claude-code", model: "claude-haiku-5-5" }]);
  });

  it("announces a warm-up failure with its code", async () => {
    const sent = await run(fakeProvider({ warmUp: () => Promise.reject(new ProviderError("missing_key", "no key")) }));
    assert.deepEqual(sent, [{ ready: false, provider: "claude-code", error: "no key", code: "missing_key" }]);
  });

  it("finishes in-flight translations before closing when the input ends", async () => {
    let release;
    const gate = new Promise((resolve) => {
      release = resolve;
    });
    const provider = fakeProvider({ translate: async (text) => (await gate, resultFor(text)) });
    const sent = [];

    const serving = serve(registryOf(provider).registry, linesOf('{"id":"slow","text":"hola"}'), (m) => sent.push(m), SETTINGS);
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(provider.closed, false);

    release();
    await serving;
    assert.equal(provider.closed, true);
    assert.deepEqual(responses(sent), [{ id: "slow", provider: "claude-code", model: "claude-haiku-5-5", result: resultFor("hola") }]);
  });
});

describe("defaultProviderFactory", () => {
  const engine = { model: "claude-haiku-5-5", effort: "low" };

  it("builds each provider with its model", () => {
    const factory = defaultProviderFactory(engine, "claude-sonnet-5-5", {});
    assert.equal(factory("claude-code").model, "claude-haiku-5-5");
    assert.equal(factory("claude-api").model, "claude-sonnet-5-5");
    assert.equal(factory("deepl").model, "deepl");
  });

  it("reports a missing key when the environment has none", async () => {
    const factory = defaultProviderFactory(engine, "claude-haiku-5-5", { QT_ANTHROPIC_API_KEY: "  ", QT_DEEPL_AUTH_KEY: "" });
    await assert.rejects(factory("claude-api").warmUp(), (error) => error.code === "missing_key");
    await assert.rejects(factory("deepl").warmUp(), (error) => error.code === "missing_key");
  });

  it("reads the keys from the QT_ variables", async () => {
    const factory = defaultProviderFactory(engine, "claude-haiku-5-5", { QT_ANTHROPIC_API_KEY: "sk-test", QT_DEEPL_AUTH_KEY: "k:fx" });
    await factory("claude-api").warmUp();
    await factory("deepl").warmUp();
  });
});
