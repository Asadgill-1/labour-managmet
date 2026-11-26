import { describe, expect, test } from "vitest";
import { readAed, showFils, signedFils } from "../lib/money";

describe("fils as text (CALC-01)", () => {
  test("whole dirhams, fils and thousands", () => {
    expect(showFils(145500)).toBe("1,455.00");
    expect(showFils(18950)).toBe("189.50");
    expect(showFils(7)).toBe("0.07");
    expect(showFils(0)).toBe("0.00");
    expect(showFils(123456789)).toBe("1,234,567.89");
  });

  test("with AED, and a loss with a minus", () => {
    expect(showFils(19900, true)).toBe("AED 199.00");
    expect(showFils(-230000)).toBe("-2,300.00");
    expect(showFils(-5, true)).toBe("AED -0.05");
  });

  test("a value that is not a whole number of fils is refused, never rounded", () => {
    expect(() => showFils(1.5)).toThrow();
    expect(() => showFils(Number.NaN)).toThrow();
  });
});

describe("an amount typed in AED", () => {
  test("reads as whole fils", () => {
    expect(readAed("189")).toBe(18900);
    expect(readAed("189.5")).toBe(18950);
    expect(readAed("189.05")).toBe(18905);
    expect(readAed("1,455.00")).toBe(145500);
    expect(readAed(" 0.07 ")).toBe(7);
    expect(readAed("1234567")).toBe(123456700);
  });

  test("anything else is refused", () => {
    for (const bad of ["", " ", "12.345", "-5", "abc", "1,45", "1.2.3", "AED 5", "5e3", ".5", "Infinity", "99999999999999999"]) {
      expect(readAed(bad), bad).toBeNull();
    }
  });
});

describe("a change with its sign", () => {
  test("plus, minus, and none without a sign", () => {
    expect(signedFils(29900)).toBe("+299.00");
    expect(signedFils(19900, -1)).toBe("-199.00");
    expect(signedFils(0)).toBe("0.00");
    expect(signedFils(0, -1)).toBe("0.00");
  });
});
