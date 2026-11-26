import { expect, test } from "vitest";
import { creditFor } from "../lib/credit";

const now = new Date("2026-11-16T00:00:00Z");
const day = 86_400_000;
const at = (days: number) => new Date(now.getTime() + days * day).toISOString();

test("the unused part of a paid period, priced at the new plan, as whole days", () => {
  // Small, AED 199 for 30 days, 15 days used: AED 99.50 left, which buys 10 days of Mid at AED 299 a month (AED 9.83 a day).
  const c = creditFor([{ source: "slip", amount_fils: 19900, starts_at_utc: at(-15), ends_at_utc: at(15) }], 29900, now);
  expect(c).toEqual({ fils: 9950, days: 10 });
});

test("a period not started yet counts whole; given days count day for day; a past one counts nothing", () => {
  const c = creditFor([
    { source: "slip", amount_fils: 19900, starts_at_utc: at(15), ends_at_utc: at(45) },
    { source: "grant", amount_fils: 0, starts_at_utc: at(45), ends_at_utc: at(52) },
    { source: "slip", amount_fils: 19900, starts_at_utc: at(-60), ends_at_utc: at(-30) },
  ], 19900, now);
  expect(c).toEqual({ fils: 19900, days: 30 + 7 });
});

test("no money left gives no days, and a free plan to move to gives the days as they are", () => {
  expect(creditFor([], 29900, now)).toEqual({ fils: 0, days: 0 });
  expect(creditFor([{ source: "slip", amount_fils: 19900, starts_at_utc: at(-15), ends_at_utc: at(15) }], 0, now)).toEqual({ fils: 9950, days: 15 });
});
