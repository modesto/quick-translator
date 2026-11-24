import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseOptions } from "../dist/options.js";

describe("parseOptions", () => {
  it("uses the defaults when no flags are given", () => {
    const parsed = parseOptions([]);
    assert.equal(parsed.text, undefined);
    assert.equal(parsed.help, false);
    assert.equal(parsed.server, false);
    assert.deepEqual(parsed.options, {
      targetLanguage: undefined,
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

  it("rejects an unknown effort", () => {
    assert.throws(() => parseOptions(["--effort", "max"]), /Invalid effort: max/);
  });

  it("rejects unknown flags", () => {
    assert.throws(() => parseOptions(["--verbose"]));
  });
});
