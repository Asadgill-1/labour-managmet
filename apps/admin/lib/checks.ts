import { showFils } from "./money";

export type Check = { ok: boolean | null; text: string };

/** What the dashboard checks on a waiting slip by itself: the file, the amount and the bank reference (D-081). */
export function slipChecks(
  slip: { file_arrived: boolean | null; expected_fils: number },
  typedFils: number | null,
  reference: string,
  seen: Set<string>,
): Check[] {
  const file: Check = slip.file_arrived === null
    ? { ok: null, text: "File dekh rahe hain" }
    : slip.file_arrived
      ? { ok: true, text: "File poori pohanchi" }
      : { ok: false, text: "File nahin pohanchi: refuse karein, customer nayi slip bhejega" };
  const due = slip.expected_fils;
  const amount: Check = typedFils === null
    ? { ok: null, text: `Bank mein aayi raqam likhein; aani thi ${showFils(due, true)}` }
    : typedFils === due
      ? { ok: true, text: `Raqam poori: ${showFils(due, true)}` }
      : {
        ok: false,
        text: `${showFils(Math.abs(due - typedFils), true)} ${typedFils < due ? "kam" : "zyada"} aaye: aani thi ${showFils(due, true)}. Phir bhi accept ho sakti hai, note likhein.`,
      };
  const ref = reference.trim().toUpperCase();
  const used: Check = !ref
    ? { ok: null, text: "Bank reference likhte hi purane references se milaya jayega" }
    : seen.has(ref)
      ? { ok: false, text: "Ye bank reference pehle kisi slip par likha ja chuka hai" }
      : { ok: true, text: "Bank reference naya hai" };
  return [file, amount, used];
}
