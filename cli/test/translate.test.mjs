import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { isTranslationResult } from "../dist/translate.js";

const valid = {
  sourceLanguage: "Spanish",
  targetLanguage: "English",
  variants: [
    { label: "Natural", text: "See you later" },
    { label: "Formal", text: "I will see you later" },
  ],
};

describe("isTranslationResult", () => {
  it("accepts a well-formed result", () => {
    assert.equal(isTranslationResult(valid), true);
  });

  it("accepts a result with no variants", () => {
    assert.equal(isTranslationResult({ ...valid, variants: [] }), true);
  });

  const invalid = {
    null: null,
    string: "See you later",
    "missing sourceLanguage": { targetLanguage: "English", variants: [] },
    "missing targetLanguage": { sourceLanguage: "Spanish", variants: [] },
    "variants not an array": { ...valid, variants: { label: "Natural", text: "x" } },
    "variant without text": { ...valid, variants: [{ label: "Natural" }] },
    "variant with numeric label": { ...valid, variants: [{ label: 1, text: "x" }] },
    "null variant": { ...valid, variants: [null] },
  };

  for (const [name, value] of Object.entries(invalid)) {
    it(`rejects ${name}`, () => {
      assert.equal(isTranslationResult(value), false);
    });
  }
});
