// What a plan changed from now leaves unused, as a suggestion the owner may change (D-083). Whole fils, whole days.

type Run = { source: string; amount_fils: number; starts_at_utc: string; ends_at_utc: string };
const dayMs = 86_400_000;

/**
 * The money of the paid periods not yet used, and the days it buys on the new plan at its monthly price (a month taken
 * as 365/12 days); given days carry over day for day. Rounded down, so a suggestion never gives more than was paid.
 */
export function creditFor(periods: Run[], newMonthlyFils: number, now = new Date()): { fils: number; days: number } {
  let fils = 0;
  let given = 0;
  for (const p of periods) {
    const start = Date.parse(p.starts_at_utc);
    const end = Date.parse(p.ends_at_utc);
    const left = end - Math.max(start, now.getTime());
    if (left <= 0 || end <= start) continue;
    if (p.source === "slip") fils += Math.floor((p.amount_fils * left) / (end - start));
    else if (p.source === "grant") given += Math.floor(left / dayMs);
  }
  const bought = newMonthlyFils > 0
    ? Math.floor((fils * 365) / (newMonthlyFils * 12))
    : Math.floor(periods.filter((p) => p.source === "slip").reduce((s, p) => s + Math.max(0, Date.parse(p.ends_at_utc) - Math.max(Date.parse(p.starts_at_utc), now.getTime())), 0) / dayMs);
  return { fils, days: bought + given };
}
