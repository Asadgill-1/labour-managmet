// A list's filters, sort, page and range live in the URL, so a view can be bookmarked or sent (D-081).

type Value = string | number | boolean;

export function readQuery<T extends Record<string, Value>>(params: URLSearchParams, defaults: T): T {
  const out: Record<string, Value> = { ...defaults };
  for (const [key, fallback] of Object.entries(defaults)) {
    const raw = params.get(key);
    if (raw === null) continue;
    if (typeof fallback === "number") {
      const n = Number(raw);
      if (Number.isSafeInteger(n) && n > 0) out[key] = n;
    } else if (typeof fallback === "boolean") {
      if (raw === "1" || raw === "0") out[key] = raw === "1";
    } else {
      out[key] = raw;
    }
  }
  return out as T;
}

export function writeQuery<T extends Record<string, Value>>(state: T, defaults: T): string {
  const params = new URLSearchParams();
  for (const key of Object.keys(defaults)) {
    const v = state[key];
    if (v === defaults[key]) continue;
    params.set(key, typeof v === "boolean" ? (v ? "1" : "0") : String(v));
  }
  const text = params.toString();
  return text ? `?${text}` : "";
}
