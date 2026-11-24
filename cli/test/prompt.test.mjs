import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { buildPrompt } from "../dist/translate.js";

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
