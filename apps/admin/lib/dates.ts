// Every date the owner reads is in Dubai time; the cloud keeps UTC.

const zone = "Asia/Dubai";
const day = new Intl.DateTimeFormat("en-GB", { timeZone: zone, day: "numeric", month: "short", year: "numeric" });
const dayTime = new Intl.DateTimeFormat("en-GB", { timeZone: zone, day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
const clock = new Intl.DateTimeFormat("en-GB", { timeZone: zone, hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
const iso = new Intl.DateTimeFormat("en-CA", { timeZone: zone, year: "numeric", month: "2-digit", day: "2-digit" });
const dayMs = 86_400_000;
// Dubai keeps one offset all year.
const offsetMs = 4 * 3_600_000;

type When = string | Date | null | undefined;
const at = (w: When) => (w instanceof Date ? w : new Date(w as string));

/** `23 Nov 2026`, or `-` for none. */
export const showDate = (w: When) => (w ? day.format(at(w)) : "-");

/** `22 Nov, 10:42`, or `-` for none. */
export const showTime = (w: When) => (w ? dayTime.format(at(w)).replace(" at ", ", ") : "-");

/** The Dubai calendar day, `2026-11-26`. */
export const dubaiDay = (w: string | Date) => iso.format(at(w));

/** How long ago by the Dubai calendar: `aaj 09:15`, `kal 21:40`, `5 din pehle` (ADMIN-05). */
export function ago(w: When, now = new Date()): string {
  if (!w) return "kabhi nahin";
  const t = at(w);
  const days = Math.round((Date.parse(dubaiDay(now)) - Date.parse(dubaiDay(t))) / dayMs);
  if (days < 0) return showTime(t);
  if (days === 0) return `aaj ${clock.format(t)}`;
  if (days === 1) return `kal ${clock.format(t)}`;
  return `${days} din pehle`;
}

/** Whole days until a moment, rounded up; negative once past. */
export const daysLeft = (w: string | Date, now = new Date()) => Math.ceil((at(w).getTime() - now.getTime()) / dayMs);

/** The start of a Dubai calendar day `YYYY-MM-DD`, in UTC. */
export const dubaiMidnight = (d: string) => new Date(Date.parse(`${d}T00:00:00Z`) - offsetMs);

export type RangeKey = "aaj" | "7d" | "30d" | "3m" | "12m" | "apni";
export type Range = { from: string; to: string; before: { from: string; to: string } };

const back: Record<Exclude<RangeKey, "aaj" | "apni">, number> = { "7d": 7, "30d": 30, "3m": 91, "12m": 365 };

/** The Overview's range and the one before it, of the same length, for the comparison. */
export function rangeOf(key: RangeKey, now = new Date(), first = "", last = ""): Range {
  let from: Date;
  let to = now;
  if (key === "aaj") {
    from = dubaiMidnight(dubaiDay(now));
  } else if (key === "apni" && /^\d{4}-\d{2}-\d{2}$/.test(first) && /^\d{4}-\d{2}-\d{2}$/.test(last) && first <= last) {
    from = dubaiMidnight(first);
    to = new Date(dubaiMidnight(last).getTime() + dayMs - 1);
  } else {
    from = new Date(now.getTime() - (key in back ? back[key as keyof typeof back] : 30) * dayMs);
  }
  const length = to.getTime() - from.getTime();
  return {
    from: from.toISOString(),
    to: to.toISOString(),
    before: { from: new Date(from.getTime() - length).toISOString(), to: from.toISOString() },
  };
}
