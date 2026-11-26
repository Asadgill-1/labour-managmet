// Money is whole fils everywhere (CALC-01). These two are the only places it becomes text or comes from text.

export function showFils(fils: number, aed = false): string {
  if (!Number.isSafeInteger(fils)) throw new Error(`not a whole number of fils: ${fils}`);
  const abs = Math.abs(fils);
  const whole = Math.floor(abs / 100).toLocaleString("en-US");
  const text = `${fils < 0 ? "-" : ""}${whole}.${String(abs % 100).padStart(2, "0")}`;
  return aed ? `AED ${text}` : text;
}

const typed = /^(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?$/;

/** An amount typed in AED, as fils; null for anything that is not a non-negative amount with at most two decimals. */
export function readAed(text: string): number | null {
  const m = typed.exec(text.trim());
  if (!m) return null;
  const fils = Number(m[1].replaceAll(",", "")) * 100 + Number((m[2] ?? "").padEnd(2, "0"));
  return Number.isSafeInteger(fils) && fils <= 1e15 ? fils : null;
}

/** A change with its sign: `+299.00`, `-199.00`, or `0.00` for none. */
export const signedFils = (fils: number, sign: 1 | -1 = 1) => (fils === 0 ? "0.00" : `${sign > 0 ? "+" : "-"}${showFils(Math.abs(fils))}`);
