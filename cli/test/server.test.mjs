import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseRequest, serve } from "../dist/server.js";

const SETTINGS = { model: "claude-haiku-5-5", defaultCount: 4 };

function resultFor(text) {
  return { sourceLanguage: "Spanish", targetLanguage: "English", variants: [{ label: "Natural", text: `EN:${text}` }] };
}

function fakeTranslator({ warmUp = () => Promise.resolve(), translate } = {}) {
  const calls = [];
  return {
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

async function* linesOf(...lines) {
  for (const line of lines) yield line;
}

async function run(translator, ...lines) {
  const sent = [];
  await serve(translator, linesOf(...lines), (message) => sent.push(message), SETTINGS);
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
    });
  });

  it("keeps the optional target language and count", () => {
    assert.deepEqual(parseRequest('{"id":"1","text":"hola","to":"French","count":2}'), {
      id: "1",
      text: "hola",
      to: "French",
      count: 2,
      languagePair: undefined,
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
  };

  for (const [name, [line, expected]] of Object.entries(invalid)) {
    it(`rejects ${name}`, () => {
      assert.throws(() => parseRequest(line), expected);
    });
  }
});

describe("serve", () => {
  it("answers each request with its id, the model and the result", async () => {
    const translator = fakeTranslator();
    const sent = await run(translator, '{"id":"a","text":"hola"}', '{"id":"b","text":"adiós"}');

    assert.deepEqual(
      responses(sent).sort((x, y) => x.id.localeCompare(y.id)),
      [
        { id: "a", model: "claude-haiku-5-5", result: resultFor("hola") },
        { id: "b", model: "claude-haiku-5-5", result: resultFor("adiós") },
      ],
    );
  });

  it("passes the target language and uses the default count when none is given", async () => {
    const translator = fakeTranslator();
    await run(translator, '{"id":"a","text":"hola","to":"French"}', '{"id":"b","text":"hola","count":2}');

    assert.deepEqual(translator.calls.map((call) => call.request), [
      { targetLanguage: "French", count: 4, languagePair: undefined },
      { targetLanguage: undefined, count: 2, languagePair: undefined },
    ]);
  });

  it("uses the request's language pair, or the server default when it has none", async () => {
    const translator = fakeTranslator();
    const defaultLanguagePair = { mine: "Spanish", target: "German" };
    await serve(
      translator,
      linesOf('{"id":"a","text":"hola","mine":"Spanish","target":"French"}', '{"id":"b","text":"hola"}'),
      () => {},
      { ...SETTINGS, defaultLanguagePair },
    );

    assert.deepEqual(
      translator.calls.map((call) => call.request.languagePair),
      [{ mine: "Spanish", target: "French" }, defaultLanguagePair],
    );
  });

  it("reports a translation failure under the request id", async () => {
    const translator = fakeTranslator({
      translate: () => Promise.reject(new Error("Translation failed: error_max_turns")),
    });
    const sent = await run(translator, '{"id":"a","text":"hola"}');

    assert.deepEqual(responses(sent), [{ id: "a", error: "Translation failed: error_max_turns" }]);
  });

  it("reports an invalid line with a null id and keeps serving", async () => {
    const translator = fakeTranslator();
    const sent = await run(translator, "not json", '{"id":"a","text":"hola"}');

    const [invalid, valid] = responses(sent);
    assert.equal(invalid.id, null);
    assert.match(invalid.error, /JSON/);
    assert.equal(valid.id, "a");
    assert.equal(translator.calls.length, 1);
  });

  it("ignores blank lines", async () => {
    const translator = fakeTranslator();
    const sent = await run(translator, "", "   ", '{"id":"a","text":"hola"}');

    assert.equal(responses(sent).length, 1);
    assert.equal(translator.calls.length, 1);
  });

  it("announces when the warm process is ready", async () => {
    const sent = await run(fakeTranslator());
    assert.deepEqual(sent, [{ ready: true, model: "claude-haiku-5-5" }]);
  });

  it("announces a warm-up failure", async () => {
    const sent = await run(fakeTranslator({ warmUp: () => Promise.reject(new Error("not logged in")) }));
    assert.deepEqual(sent, [{ ready: false, error: "not logged in" }]);
  });

  it("finishes in-flight translations before closing when the input ends", async () => {
    let release;
    const gate = new Promise((resolve) => {
      release = resolve;
    });
    const translator = fakeTranslator({ translate: async (text) => (await gate, resultFor(text)) });
    const sent = [];

    const serving = serve(translator, linesOf('{"id":"slow","text":"hola"}'), (message) => sent.push(message), SETTINGS);
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(translator.closed, false);

    release();
    await serving;
    assert.equal(translator.closed, true);
    assert.deepEqual(responses(sent), [{ id: "slow", model: "claude-haiku-5-5", result: resultFor("hola") }]);
  });
});
