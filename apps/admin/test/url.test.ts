import { describe, expect, test } from "vitest";
import { readQuery, writeQuery } from "../lib/url";

const defaults = { view: "sab", q: "", per: 25, page: 1, test: false };

describe("a list's filters in the URL", () => {
  test("missing or broken values take the default", () => {
    expect(readQuery(new URLSearchParams(""), defaults)).toEqual(defaults);
    expect(readQuery(new URLSearchParams("per=abc&page=-2&test=maybe"), defaults)).toEqual(defaults);
  });

  test("values read back as their own type", () => {
    expect(readQuery(new URLSearchParams("view=offline&q=gulf%20star&per=50&page=3&test=1"), defaults)).toEqual({
      view: "offline", q: "gulf star", per: 50, page: 3, test: true,
    });
  });

  test("only what differs from the default is written, so a view can be sent as a short link", () => {
    expect(writeQuery(defaults, defaults)).toBe("");
    expect(writeQuery({ ...defaults, q: "gulf star", per: 50, test: true }, defaults)).toBe("?q=gulf+star&per=50&test=1");
  });

  test("a round trip keeps everything", () => {
    const state = { view: "held", q: "x&y", per: 100, page: 2, test: true };
    expect(readQuery(new URLSearchParams(writeQuery(state, defaults)), defaults)).toEqual(state);
  });
});
