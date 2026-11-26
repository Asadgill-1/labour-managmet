import { cloud } from "./cloud";
import { dubaiMidnight } from "./dates";
import type { MoneyEntry, Period } from "./types";

/** The plan period covering a moment, as the licence picks it: a paid or given plan before the trial, a slip first. */
export function coveringPlan(periods: Period[], at = new Date()): Period | null {
  const t = at.toISOString();
  return periods
    .filter((p) => p.kind === "plan" && !p.revoked_at_utc && p.starts_at_utc <= t && (p.cut_at ?? p.ends_at_utc) > t)
    .sort((a, b) =>
      Number(b.plan_code !== "trial") - Number(a.plan_code !== "trial") ||
      Number(b.source === "slip") - Number(a.source === "slip") ||
      b.ends_at_utc.localeCompare(a.ends_at_utc))[0] ?? null;
}

export const refundedOf = (entries: MoneyEntry[], period: string) =>
  entries.filter((m) => m.kind === "refund" && m.subscription_id === period).reduce((s, m) => s + m.amount_fils, 0);

/** "Until 29 Nov" means through that Dubai day: the moment the next day starts. */
export const endOfDubaiDay = (day: string) => new Date(dubaiMidnight(day).getTime() + 86_400_000).toISOString();

/** A 60-second link to a slip's file, which only an admin's session may open (T22a). Null when the file never came. */
export async function slipLink(path: string): Promise<string | null> {
  const c = cloud();
  if (!c) return null;
  const { data, error } = await c.storage.from("payment-slips").createSignedUrl(path, 60);
  return error ? null : data.signedUrl;
}
