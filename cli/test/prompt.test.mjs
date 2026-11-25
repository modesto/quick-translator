import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { buildPrompt, claudeCodeEnv, stylesFor } from "../dist/translate.js";

describe("buildPrompt", () => {
  it("defaults to Spanish as your language and English as the target", () => {
    assert.match(buildPrompt("hola", { count: 4 }), /Target language: English if the text is in Spanish; otherwise Spanish\./);
  });

  it("uses the configured language pair", () => {
    const prompt = buildPrompt("hola", { count: 4, languagePair: { mine: "Spanish", target: "French" } });
    assert.match(prompt, /Target language: French if the text is in Spanish; otherwise Spanish\./);
  });

  it("lets an explicit target language override the pair", () => {
    const prompt = buildPrompt("hola", { count: 4, targetLanguage: "German", languagePair: { mine: "Spanish", target: "French" } });
    assert.match(prompt, /Target language: German\./);
    assert.doesNotMatch(prompt, /French/);
  });

  it("includes the number of variants and the text", () => {
    const prompt = buildPrompt("línea 1\nlínea 2", { count: 3 });
    assert.match(prompt, /Number of variants: 3\./);
    assert.match(prompt, /<text>\nlínea 1\nlínea 2\n<\/text>/);
  });
});

describe("stylesFor", () => {
  it("always asks for the same four styles, in order, by default", () => {
    assert.deepEqual(stylesFor(4), ["Literal", "Natural", "Formal", "Conciso"]);
  });

  it("takes the first styles when fewer variants are requested", () => {
    assert.deepEqual(stylesFor(2), ["Literal", "Natural"]);
  });

  it("lists only the fixed styles when more variants are requested", () => {
    assert.deepEqual(stylesFor(6), ["Literal", "Natural", "Formal", "Conciso"]);
  });

  it("is sent in the prompt", () => {
    assert.match(buildPrompt("hola", { count: 4 }), /Styles: Literal, Natural, Formal, Conciso\./);
  });
});

describe("claudeCodeEnv", () => {
  it("keeps the environment, names the client and hides the other providers' keys", () => {
    const env = claudeCodeEnv({ PATH: "/bin", HOME: "/Users/me", QT_ANTHROPIC_API_KEY: "sk", QT_DEEPL_AUTH_KEY: "k" });
    assert.deepEqual(env, { PATH: "/bin", HOME: "/Users/me", CLAUDE_AGENT_SDK_CLIENT_APP: "quick-translate/0.1.0" });
  });
});
