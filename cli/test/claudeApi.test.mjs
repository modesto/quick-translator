import Anthropic from "@anthropic-ai/sdk";
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ClaudeApiTranslator, providerErrorFrom, requestParams } from "../dist/claudeApi.js";

const RESULT = {
  sourceLanguage: "Spanish",
  targetLanguage: "English",
  variants: [{ label: "Natural", text: "See you tomorrow" }],
};

function fakeClient(respond) {
  const calls = [];
  return {
    calls,
    beta: {
      messages: {
        async parse(params) {
          calls.push(params);
          return respond(params);
        },
      },
    },
  };
}

const REQUEST = { count: 4, languagePair: { mine: "Spanish", target: "French" } };

describe("requestParams", () => {
  it("sends the shared prompt with structured output and low effort", () => {
    const params = requestParams("claude-haiku-5-5", "hola", REQUEST);
    assert.equal(params.model, "claude-haiku-5-5");
    assert.match(params.system, /translation engine/);
    assert.match(params.messages[0].content, /Target language: French if the text is in Spanish; otherwise Spanish\./);
    assert.match(params.messages[0].content, /<text>\nhola\n<\/text>/);
    assert.equal(params.output_config.effort, "low");
    assert.equal(params.output_config.format.type, "json_schema");
  });

  it("turns thinking off on Haiku 5.5 for speed", () => {
    assert.deepEqual(requestParams("claude-haiku-5-5", "hola", REQUEST).thinking, { type: "disabled" });
  });

  it("leaves thinking alone on models that reject disabling it", () => {
    for (const model of ["claude-sonnet-5-5", "claude-opus-5-5"]) {
      assert.equal(requestParams(model, "hola", REQUEST).thinking, undefined);
    }
  });

  it("opts the models that support it into server-side refusal fallbacks", () => {
    for (const model of ["claude-sonnet-5-5", "claude-opus-5-5"]) {
      const params = requestParams(model, "hola", REQUEST);
      assert.deepEqual(params.betas, ["server-side-fallback-2026-07-01"]);
      assert.equal(params.fallbacks, "default");
    }
    assert.equal(requestParams("claude-haiku-5-5", "hola", REQUEST).fallbacks, undefined);
  });
});

describe("ClaudeApiTranslator", () => {
  it("returns the parsed translation", async () => {
    const client = fakeClient(() => ({ stop_reason: "end_turn", parsed_output: RESULT }));
    const translator = new ClaudeApiTranslator("claude-haiku-5-5", undefined, client);

    assert.deepEqual(await translator.translate("Nos vemos mañana", REQUEST), RESULT);
    assert.equal(client.calls.length, 1);
    assert.equal(translator.id, "claude-api");
    assert.equal(translator.model, "claude-haiku-5-5");
  });

  it("reports a refusal", async () => {
    const translator = new ClaudeApiTranslator("claude-haiku-5-5", undefined, fakeClient(() => ({ stop_reason: "refusal" })));
    await assert.rejects(translator.translate("x", REQUEST), (error) => error.code === "refused");
  });

  it("reports a missing or malformed structured output", async () => {
    const translator = new ClaudeApiTranslator(
      "claude-haiku-5-5",
      undefined,
      fakeClient(() => ({ stop_reason: "max_tokens", parsed_output: { variants: "nope" } })),
    );
    await assert.rejects(translator.translate("x", REQUEST), (error) => error.code === "provider_error" && /max_tokens/.test(error.message));
  });

  it("fails with missing_key when there is no key", async () => {
    const translator = new ClaudeApiTranslator("claude-haiku-5-5", undefined);
    await assert.rejects(translator.warmUp(), (error) => error.code === "missing_key");
    await assert.rejects(translator.translate("x", REQUEST), (error) => error.code === "missing_key");
  });

  it("maps SDK errors to provider error codes", async () => {
    const translator = new ClaudeApiTranslator(
      "claude-haiku-5-5",
      undefined,
      fakeClient(() => {
        throw new Anthropic.AuthenticationError(401, { type: "error" }, "invalid x-api-key", new Headers());
      }),
    );
    await assert.rejects(translator.translate("x", REQUEST), (error) => error.code === "auth_failed");
  });
});

describe("providerErrorFrom", () => {
  const cases = [
    [new Anthropic.AuthenticationError(401, {}, "bad key", new Headers()), "auth_failed"],
    [new Anthropic.PermissionDeniedError(403, {}, "denied", new Headers()), "auth_failed"],
    [new Anthropic.RateLimitError(429, {}, "slow down", new Headers()), "rate_limited"],
    [new Anthropic.APIConnectionError({ message: "offline" }), "network"],
    [new Anthropic.InternalServerError(500, {}, "boom", new Headers()), "provider_error"],
    [new Error("weird"), "provider_error"],
  ];

  for (const [error, code] of cases) {
    it(`maps ${error.constructor.name} to ${code}`, () => {
      assert.equal(providerErrorFrom(error).code, code);
    });
  }
});
