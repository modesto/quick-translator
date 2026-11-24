import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseOptions } from "../dist/options.js";

describe("parseOptions", () => {
  it("uses the defaults when no flags are given", () => {
    const parsed = parseOptions([]);
    assert.equal(parsed.text, undefined);
    assert.equal(parsed.help, false);
    assert.equal(parsed.server, false);
    assert.equal(parsed.provider, "claude-code");
    assert.equal(parsed.apiModel, "claude-haiku-5-5");
    assert.deepEqual(parsed.options, {
      targetLanguage: undefined,
      languagePair: { mine: "Spanish", target: "English" },
      count: 4,
      model: "claude-haiku-5-5",
      effort: "low",
    });
  });

  it("joins positional arguments into the text", () => {
    assert.equal(parseOptions(["hola", "qué", "tal"]).text, "hola qué tal");
  });

  it("reads every flag in short and long form", () => {
    const parsed = parseOptions(["-t", "French", "--count", "2", "-m", "claude-opus-5-5", "--effort", "high", "-s"]);
    assert.equal(parsed.server, true);
    assert.deepEqual(parsed.options, {
      targetLanguage: "French",
      languagePair: { mine: "Spanish", target: "English" },
      count: 2,
      model: "claude-opus-5-5",
      effort: "high",
    });
  });

  for (const count of ["0", "9", "2.5", "abc", "3abc"]) {
    it(`rejects --count ${count}`, () => {
      assert.throws(() => parseOptions(["--count", count]), /--count must be an integer between 1 and 8/);
    });
  }

  it("accepts the count limits", () => {
    assert.equal(parseOptions(["-n", "1"]).options.count, 1);
    assert.equal(parseOptions(["-n", "8"]).options.count, 8);
  });

  it("reads the language pair", () => {
    assert.deepEqual(parseOptions(["--mine", "English", "--target", "French"]).options.languagePair, {
      mine: "English",
      target: "French",
    });
  });

  it("fills a missing side of the pair with its default", () => {
    assert.deepEqual(parseOptions(["--target", "French"]).options.languagePair, { mine: "Spanish", target: "French" });
  });

  it("rejects the same language on both sides", () => {
    assert.throws(() => parseOptions(["--target", "spanish"]), /must be different languages/);
  });

  it("reads the provider and the Claude API model", () => {
    const parsed = parseOptions(["-p", "claude-api", "--api-model", "claude-sonnet-5-5"]);
    assert.equal(parsed.provider, "claude-api");
    assert.equal(parsed.apiModel, "claude-sonnet-5-5");
    assert.equal(parseOptions(["--provider", "deepl"]).provider, "deepl");
  });

  it("rejects an unknown provider", () => {
    assert.throws(() => parseOptions(["--provider", "google"]), /--provider must be one of/);
  });

  it("rejects an unknown effort", () => {
    assert.throws(() => parseOptions(["--effort", "max"]), /Invalid effort: max/);
  });

  it("rejects unknown flags", () => {
    assert.throws(() => parseOptions(["--verbose"]));
  });
});
