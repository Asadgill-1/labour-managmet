import { describe, expect, test } from "vitest";
import { ago, daysLeft, dubaiDay, rangeOf, showDate, showTime } from "../lib/dates";

// 2026-11-26 10:00 in Dubai, UTC+4.
const now = new Date("2026-11-26T06:00:00Z");

describe("dates in Dubai time", () => {
  test("a day and a time", () => {
    expect(showDate("2026-11-22T20:30:00Z")).toBe("23 Nov 2026");
    expect(showTime("2026-11-22T06:42:00Z")).toBe("22 Nov, 10:42");
    expect(showDate(null)).toBe("-");
    expect(dubaiDay("2026-11-25T20:00:00Z")).toBe("2026-11-26");
  });

  test("how long ago, by the Dubai calendar day (ADMIN-05)", () => {
    expect(ago("2026-11-26T05:15:00Z", now)).toBe("aaj 09:15");
    expect(ago("2026-11-25T17:40:00Z", now)).toBe("kal 21:40");
    expect(ago("2026-11-21T06:00:00Z", now)).toBe("5 din pehle");
    expect(ago(null, now)).toBe("kabhi nahin");
  });

  test("days left, rounded up", () => {
    expect(daysLeft("2026-11-27T06:00:00Z", now)).toBe(1);
    expect(daysLeft("2026-11-27T07:00:00Z", now)).toBe(2);
    expect(daysLeft("2026-11-25T06:00:00Z", now)).toBe(-1);
  });
});

describe("the ranges the Overview offers", () => {
  test("today starts at Dubai midnight; the previous range is as long and ends where it starts", () => {
    const r = rangeOf("aaj", now);
    expect(r.from).toBe("2026-11-25T20:00:00.000Z");
    expect(r.to).toBe(now.toISOString());
    expect(r.before.to).toBe(r.from);
    expect(r.before.from).toBe("2026-11-25T10:00:00.000Z");
  });

  test("30 days back from now, and a custom range from the start of its first day to the end of its last", () => {
    expect(rangeOf("30d", now).from).toBe("2026-10-27T06:00:00.000Z");
    const c = rangeOf("apni", now, "2026-11-01", "2026-11-10");
    expect(c.from).toBe("2026-10-31T20:00:00.000Z");
    expect(c.to).toBe("2026-11-10T19:59:59.999Z");
    expect(c.before.to).toBe(c.from);
  });

  test("a custom range with its days swapped or missing falls back to 30 days", () => {
    expect(rangeOf("apni", now, "2026-11-10", "2026-11-01").from).toBe(rangeOf("30d", now).from);
    expect(rangeOf("apni", now, "", "").from).toBe(rangeOf("30d", now).from);
  });
});
