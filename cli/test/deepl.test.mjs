import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { deeplEndpoint, deeplLanguage, DeepLTranslator, englishName, errorFromResponse, supportsFormality } from "../dist/deepl.js";

function fakeFetch(respond) {
  const calls = [];
  const fetch = async (url, init) => {
    const body = JSON.parse(init.body);
    calls.push({ url, headers: init.headers, body });
    const reply = respond(body);
    if (reply instanceof Error) throw reply;
    const { status = 200, json, text = "" } = reply;
    return { ok: status >= 200 && status < 300, status, json: async () => json, text: async () => text };
  };
  return { fetch, calls };
}

function translated(text, detected) {
  return { json: { translations: [{ text, detected_source_language: detected }] } };
}

const PAIR = { count: 4, languagePair: { mine: "Spanish", target: "English" } };

describe("DeepL helpers", () => {
  it("uses the free endpoint for keys ending in :fx", () => {
    assert.equal(deeplEndpoint("abc:fx"), "https://api-free.deepl.com/v2/translate");
    assert.equal(deeplEndpoint("abc"), "https://api.deepl.com/v2/translate");
  });

  it("maps English language names to DeepL codes", () => {
    assert.deepEqual(deeplLanguage("English"), { source: "EN", target: "EN-US" });
    assert.deepEqual(deeplLanguage(" portuguese "), { source: "PT", target: "PT-PT" });
    assert.deepEqual(deeplLanguage("Chinese"), { source: "ZH", target: "ZH-HANS" });
    assert.throws(() => deeplLanguage("Klingon"), (error) => error.code === "unsupported_language");
  });

  it("maps DeepL codes back to English names", () => {
    assert.equal(englishName("ES"), "Spanish");
    assert.equal(englishName("en-us"), "English");
    assert.equal(englishName("XX"), "XX");
  });

  it("knows which targets accept a formality", () => {
    assert.equal(supportsFormality("ES"), true);
    assert.equal(supportsFormality("PT-PT"), true);
    assert.equal(supportsFormality("EN-US"), false);
    assert.equal(supportsFormality("ZH-HANS"), false);
  });

  const errors = [
    [403, "", "auth_failed"],
    [456, "", "quota_exceeded"],
    [429, "", "rate_limited"],
    [400, "Value for 'target_lang' not supported.", "unsupported_language"],
    [400, "Bad request", "provider_error"],
    [500, "oops", "provider_error"],
  ];
  for (const [status, body, code] of errors) {
    it(`maps HTTP ${status} ${body ? `"${body}" ` : ""}to ${code}`, () => {
      assert.equal(errorFromResponse(status, body).code, code);
    });
  }
});

describe("DeepLTranslator", () => {
  it("sends the key, text and target, and returns one variant for targets without formality", async () => {
    const { fetch, calls } = fakeFetch(() => translated("See you tomorrow", "ES"));
    const result = await new DeepLTranslator("key:fx", fetch).translate("Nos vemos mañana", PAIR);

    assert.deepEqual(result, { sourceLanguage: "Spanish", targetLanguage: "English", variants: [{ label: "DeepL", text: "See you tomorrow" }] });
    assert.equal(calls.length, 1);
    assert.equal(calls[0].url, "https://api-free.deepl.com/v2/translate");
    assert.equal(calls[0].headers.Authorization, "DeepL-Auth-Key key:fx");
    assert.deepEqual(calls[0].body, { text: ["Nos vemos mañana"], target_lang: "EN-US", preserve_formatting: true });
  });

  it("asks for a formal and an informal version when the target supports it", async () => {
    const { fetch, calls } = fakeFetch((body) => translated(body.formality === "prefer_more" ? "Nous nous verrons demain" : "On se voit demain", "ES"));
    const result = await new DeepLTranslator("key", fetch).translate("Nos vemos mañana", { count: 4, languagePair: { mine: "Spanish", target: "French" } });

    assert.deepEqual(result.variants, [
      { label: "Formal", text: "Nous nous verrons demain" },
      { label: "Informal", text: "On se voit demain" },
    ]);
    assert.deepEqual(calls.map((call) => call.body.formality).sort(), ["prefer_less", "prefer_more"]);
  });

  it("shows a single version when formal and informal are the same", async () => {
    const { fetch } = fakeFetch(() => translated("Nos vemos mañana", "EN"));
    const result = await new DeepLTranslator("key", fetch).translate("See you tomorrow", PAIR);
    assert.deepEqual(result.variants, [{ label: "DeepL", text: "Nos vemos mañana" }]);
  });

  it("translates text that is not in your language into yours", async () => {
    const { fetch, calls } = fakeFetch((body) =>
      body.target_lang === "EN-US" ? translated("Thank you very much", "EN") : translated(body.formality === "prefer_more" ? "Muchísimas gracias" : "Muchas gracias", "EN"),
    );
    const result = await new DeepLTranslator("key", fetch).translate("Thanks a lot", PAIR);

    assert.equal(calls[0].body.target_lang, "EN-US");
    assert.ok(calls.slice(1).every((call) => call.body.target_lang === "ES"));
    assert.deepEqual(result, {
      sourceLanguage: "English",
      targetLanguage: "Spanish",
      variants: [
        { label: "Formal", text: "Muchísimas gracias" },
        { label: "Informal", text: "Muchas gracias" },
      ],
    });
  });

  it("uses a one-off target as is, without the pair rule", async () => {
    const { fetch, calls } = fakeFetch(() => translated("明日会いましょう", "EN"));
    const result = await new DeepLTranslator("key", fetch).translate("See you tomorrow", { ...PAIR, targetLanguage: "Japanese" });

    assert.ok(calls.every((call) => call.body.target_lang === "JA"));
    assert.equal(result.targetLanguage, "Japanese");
    assert.equal(calls.length, 2);
  });

  it("reports HTTP errors with their code", async () => {
    const { fetch } = fakeFetch(() => ({ status: 456, text: "Quota exceeded" }));
    await assert.rejects(new DeepLTranslator("key", fetch).translate("hola", PAIR), (error) => error.code === "quota_exceeded");
  });

  it("reports network failures", async () => {
    const { fetch } = fakeFetch(() => new TypeError("fetch failed"));
    await assert.rejects(new DeepLTranslator("key", fetch).translate("hola", PAIR), (error) => error.code === "network");
  });

  it("reports an unexpected response body", async () => {
    const { fetch } = fakeFetch(() => ({ json: { translations: [] } }));
    await assert.rejects(new DeepLTranslator("key", fetch).translate("hola", PAIR), (error) => error.code === "provider_error");
  });

  it("fails with missing_key when there is no key", async () => {
    await assert.rejects(new DeepLTranslator(undefined).translate("hola", PAIR), (error) => error.code === "missing_key");
  });
});
