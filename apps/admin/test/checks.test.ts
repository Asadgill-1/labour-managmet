import { expect, test } from "vitest";
import { slipChecks } from "../lib/checks";

const seen = new Set(["FT2611180311"]);

test("a slip whose file arrived, the amount due and a new reference all pass", () => {
  const c = slipChecks({ file_arrived: true, expected_fils: 19900 }, 19900, " ft2611220099 ", seen);
  expect(c.map((x) => x.ok)).toEqual([true, true, true]);
});

test("a file that never arrived, less money and a reference used before are each said", () => {
  const c = slipChecks({ file_arrived: false, expected_fils: 19900 }, 18900, "ft2611180311", seen);
  expect(c.map((x) => x.ok)).toEqual([false, false, false]);
  expect(c[0].text).toContain("File nahin pohanchi");
  expect(c[1].text).toBe("AED 10.00 kam aaye: aani thi AED 199.00. Phir bhi accept ho sakti hai, note likhein.");
  expect(c[2].text).toContain("pehle");
});

test("more money than due, and nothing typed yet", () => {
  expect(slipChecks({ file_arrived: null, expected_fils: 19900 }, 20900, "", seen).map((x) => x.ok)).toEqual([null, false, null]);
  expect(slipChecks({ file_arrived: true, expected_fils: 19900 }, null, "", seen)[1].ok).toBeNull();
});
