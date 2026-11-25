import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  chatRequestBody,
  DEFAULT_OPENAI_BASE_URL,
  openAIEndpoint,
  OpenAITranslator,
  openAIErrorFromResponse,
  openAIRequestBody,
  reasoningEffort,
  resultFromChat,
  resultFromResponse,
} from "../dist/openai.js";

const RESULT = {
  sourceLanguage: "Spanish",
  targetLanguage: "English",
  variants: [{ label: "Natural", text: "See you tomorrow" }],
};

const REQUEST = { count: 4, languagePair: { mine: "Spanish", target: "English" } };

function completed(content) {
  return { status: "completed", output: [{ type: "reasoning" }, { type: "message", content }] };
}

function fakeFetch(reply) {
  const calls = [];
  const fetch = async (url, init) => {
    calls.push({ url, headers: init.headers, body: JSON.parse(init.body) });
    if (reply instanceof Error) throw reply;
    const { status = 200, json, text = "" } = reply;
    return { ok: status >= 200 && status < 300, status, json: async () => json, text: async () => text };
  };
  return { fetch, calls };
}

describe("OpenAI request", () => {
  it("skips reasoning on the models that allow it", () => {
    assert.equal(reasoningEffort("gpt-6-luna"), "none");
    assert.equal(reasoningEffort("gpt-6.1-terra"), "none");
    assert.equal(reasoningEffort("gpt-6.2-sol"), "low");
    assert.equal(reasoningEffort("gpt-6.2-astra"), "low");
  });

  it("asks for a strict JSON schema with the shared prompt and stores nothing", () => {
    const body = openAIRequestBody("gpt-6-luna", "hola", REQUEST);
    assert.equal(body.model, "gpt-6-luna");
    assert.equal(body.store, false);
    assert.match(body.instructions, /translation engine/);
    assert.match(body.input, /<text>\nhola/);
    assert.deepEqual(body.reasoning, { effort: "none" });
    assert.equal(body.text.format.type, "json_schema");
    assert.equal(body.text.format.strict, true);
    assert.equal(body.text.format.schema.additionalProperties, false);
    assert.deepEqual(body.text.format.schema.required, ["sourceLanguage", "targetLanguage", "variants"]);
  });
});

describe("OpenAI response", () => {
  it("reads the translation from the message output", () => {
    assert.deepEqual(resultFromResponse(completed([{ type: "output_text", text: JSON.stringify(RESULT) }])), RESULT);
  });

  it("reports a refusal", () => {
    assert.throws(
      () => resultFromResponse(completed([{ type: "refusal", refusal: "I can't help with that" }])),
      (error) => error.code === "refused",
    );
  });

  it("reports an incomplete response with its reason", () => {
    assert.throws(
      () => resultFromResponse({ status: "incomplete", incomplete_details: { reason: "max_output_tokens" }, output: [] }),
      (error) => error.code === "provider_error" && /max_output_tokens/.test(error.message),
    );
  });

  it("rejects invalid or unexpected JSON", () => {
    assert.throws(() => resultFromResponse(completed([{ type: "output_text", text: "{" }])), /invalid JSON/);
    assert.throws(() => resultFromResponse(completed([{ type: "output_text", text: '{"x":1}' }])), /unexpected result/);
  });

  it("maps HTTP errors to provider error codes", () => {
    assert.equal(openAIErrorFromResponse(401, "").code, "auth_failed");
    assert.equal(openAIErrorFromResponse(403, "").code, "auth_failed");
    assert.equal(openAIErrorFromResponse(429, '{"error":{"code":"insufficient_quota"}}').code, "quota_exceeded");
    assert.equal(openAIErrorFromResponse(429, '{"error":{"code":"rate_limit_exceeded"}}').code, "rate_limited");
    assert.equal(openAIErrorFromResponse(500, "oops").code, "provider_error");
  });
});

describe("OpenAITranslator", () => {
  it("needs a key", async () => {
    const translator = new OpenAITranslator("gpt-6-luna", undefined);
    await assert.rejects(translator.warmUp(), (error) => error.code === "missing_key");
    await assert.rejects(translator.translate("hola", REQUEST), (error) => error.code === "missing_key");
  });

  it("posts to the Responses API with the key as a bearer token", async () => {
    const { fetch, calls } = fakeFetch({ json: completed([{ type: "output_text", text: JSON.stringify(RESULT) }]) });
    const translator = new OpenAITranslator("gpt-6-luna", "sk-proj", { fetch });
    assert.deepEqual(await translator.translate("Nos vemos mañana", REQUEST), RESULT);
    assert.equal(calls[0].url, "https://api.openai.com/v1/responses");
    assert.equal(calls[0].headers.Authorization, "Bearer sk-proj");
    assert.equal(calls[0].body.model, "gpt-6-luna");
  });

  it("turns HTTP and network failures into provider errors", async () => {
    const rejected = new OpenAITranslator("gpt-6-luna", "bad", { fetch: fakeFetch({ status: 401, text: "invalid key" }).fetch });
    await assert.rejects(rejected.translate("hola", REQUEST), (error) => error.code === "auth_failed");
    const offline = new OpenAITranslator("gpt-6-luna", "sk", { fetch: fakeFetch(new TypeError("fetch failed")).fetch });
    await assert.rejects(offline.translate("hola", REQUEST), (error) => error.code === "network");
  });
});

function chatReply(content, finish_reason = "stop", refusal = null) {
  return { choices: [{ finish_reason, message: { content, refusal } }] };
}

describe("OpenAI-compatible base URL", () => {
  it("uses OpenAI's Responses API when the URL is empty or OpenAI's", () => {
    const official = { url: "https://api.openai.com/v1/responses", api: "responses", official: true };
    assert.deepEqual(openAIEndpoint(undefined), official);
    assert.deepEqual(openAIEndpoint("  "), official);
    assert.deepEqual(openAIEndpoint(DEFAULT_OPENAI_BASE_URL + "/"), official);
  });

  it("uses Chat Completions on any other server", () => {
    assert.deepEqual(openAIEndpoint("http://localhost:11434/v1"), {
      url: "http://localhost:11434/v1/chat/completions",
      api: "chat",
      official: false,
    });
    assert.equal(openAIEndpoint("https://openrouter.ai/api/v1/").url, "https://openrouter.ai/api/v1/chat/completions");
  });

  it("accepts a pasted full endpoint URL", () => {
    assert.equal(openAIEndpoint("https://api.groq.com/openai/v1/chat/completions").url, "https://api.groq.com/openai/v1/chat/completions");
    assert.equal(openAIEndpoint("https://api.openai.com/v1/responses").url, "https://api.openai.com/v1/responses");
  });

  it("rejects URLs that are not http or https", () => {
    assert.throws(() => openAIEndpoint("ftp://example.com/v1"), /Invalid OpenAI base URL/);
    assert.throws(() => openAIEndpoint("not a url"), /Invalid OpenAI base URL/);
  });

  it("builds a Chat Completions request with a strict JSON schema", () => {
    const body = chatRequestBody("llama3.2", "hola", REQUEST);
    assert.equal(body.model, "llama3.2");
    assert.equal(body.messages[0].role, "system");
    assert.match(body.messages[1].content, /<text>\nhola/);
    assert.equal(body.response_format.json_schema.strict, true);
    assert.equal(body.reasoning, undefined);
  });

  it("reads Chat Completions answers, also inside a code fence", () => {
    assert.deepEqual(resultFromChat(chatReply(JSON.stringify(RESULT))), RESULT);
    assert.deepEqual(resultFromChat(chatReply("```json\n" + JSON.stringify(RESULT) + "\n```")), RESULT);
    assert.throws(() => resultFromChat(chatReply(null, "stop", "No")), (error) => error.code === "refused");
    assert.throws(() => resultFromChat(chatReply("{", "length")), /length/);
    assert.throws(() => resultFromChat({ choices: [] }), /no choices/);
  });

  it("calls a compatible server without a key", async () => {
    const { fetch, calls } = fakeFetch({ json: chatReply(JSON.stringify(RESULT)) });
    const translator = new OpenAITranslator("llama3.2", undefined, { baseURL: "http://localhost:11434/v1", fetch });
    await translator.warmUp();
    assert.deepEqual(await translator.translate("hola", REQUEST), RESULT);
    assert.equal(calls[0].url, "http://localhost:11434/v1/chat/completions");
    assert.equal(calls[0].headers.Authorization, undefined);
  });

  it("sends the key to a compatible server when there is one", async () => {
    const { fetch, calls } = fakeFetch({ json: chatReply(JSON.stringify(RESULT)) });
    await new OpenAITranslator("m", "sk-or", { baseURL: "https://openrouter.ai/api/v1", fetch }).translate("hola", REQUEST);
    assert.equal(calls[0].headers.Authorization, "Bearer sk-or");
  });
});
