// The words the pages share. The menu is English, everything else Roman Urdu (D-081 (9)).
import { showDate } from "./dates";
import { showFils } from "./money";
import type { AccountState, Slip } from "./types";

export const menu = [
  { href: "/", label: "Overview" },
  { href: "/accounts/", label: "Accounts" },
  { href: "/subscriptions/", label: "Subscriptions" },
  { href: "/audit/", label: "Audit log" },
  { href: "/settings/", label: "Settings" },
] as const;

export const stateWord: Record<AccountState, string> = {
  paid: "Paid",
  trial: "Trial",
  held: "Ruka hua",
  ended: "Plan khatam",
  none: "Plan kabhi nahin",
};
export const stateTag: Record<AccountState, string> = { paid: "paid", trial: "trial", held: "held", ended: "ended", none: "" };

export const planWord: Record<string, string> = { trial: "Trial", small: "Small", mid: "Mid", large: "Large" };
export const planShort = (code: string | null | undefined) => (code ? planWord[code] ?? code : "-");

export const coversWord: Record<Slip["covers"], string> = {
  plan: "sirf plan",
  plan_addon: "plan aur cloud add-on",
  addon: "sirf cloud add-on",
};
export const slipStateWord: Record<Slip["state"], string> = { waiting: "Intezar", accepted: "Accept", refused: "Refuse" };
export const slipStateTag: Record<Slip["state"], string> = { waiting: "wait", accepted: "paid", refused: "over" };

export const sourceWord: Record<string, string> = { trial: "Trial", slip: "Slip se", grant: "Aap ne diya" };
export const kindWord: Record<string, string> = { plan: "Plan", addon: "Cloud add-on" };
export const holdWord: Record<string, string> = { suspend: "Suspend", block: "Block" };
export const limitWord: Record<string, string> = { workers: "Active labour", clients: "Client companies", managers: "Managers" };
export const roleWord: Record<string, string> = { owner: "owner", manager: "manager" };

export const months = (n: number) => `${n} ${n === 1 ? "mahina" : "mahine"}`;

// The owner's actions as the audit log and the account's story name them.
export const actionWord: Record<string, string> = {
  accept_slip: "Slip accept",
  refuse_slip: "Slip refuse",
  revoke_period: "Period wapas liya",
  give_days: "Din diye",
  limit_override: "Had mein chhoot",
  end_override: "Chhoot khatam",
  refund: "Refund",
  correction: "Darusti",
  hold: "Account roka",
  lift_hold: "Account khola",
  free_trial_claim: "Trial claim azad",
  set_test: "Test account",
  rename: "Naam badla",
  note: "Note",
  phone_off: "Phone band",
  phone_on: "Phone khola",
  add_cost: "Kharcha likha",
  save_settings: "Settings badli",
  change_plan: "Plan badla",
};
export const moneyActions = new Set(["accept_slip", "refuse_slip", "revoke_period", "give_days", "refund", "correction", "change_plan", "add_cost"]);

export function storyWord(what: string): string {
  const fixed: Record<string, string> = {
    account_made: "Account bana",
    email_confirmed: "Email confirm hua",
    company_made: "Company bani",
    period_trial: "Trial shuru",
    period_slip: "Paid period bana",
    period_grant: "Aap ne din diye",
    slip_sent: "Slip bheji",
    phone_added: "Phone juda",
    phone_off: "Phone band hua",
  };
  if (fixed[what]) return fixed[what];
  if (what.startsWith("admin_")) return `Aap: ${actionWord[what.slice(6)] ?? what.slice(6)}`;
  return what;
}

/** The story's detail as the cloud writes it (`plan mid 2026-11-18 2026-12-18`, `mid 1 29900`), in words. */
export function storyDetail(what: string, detail: string | null): string | null {
  if (!detail) return null;
  const p = detail.split(" ");
  if (what.startsWith("period_") && p.length === 4) return `${kindWord[p[0]] ?? p[0]}, ${planShort(p[1])}, ${showDate(p[2])} se ${showDate(p[3])}`;
  if (what === "slip_sent" && p.length === 3 && /^\d+$/.test(p[1]) && /^\d+$/.test(p[2])) return `${planShort(p[0])}, ${months(Number(p[1]))}, AED ${showFils(Number(p[2]))}`;
  return detail;
}

// What the cloud says, in the owner's words. Anything unknown is shown as the cloud wrote it.
const cloudWords: Record<string, string> = {
  "admins only": "Ye kaam sirf platform ke malik ka hai, MFA code ke sath. Dobara sign in karein.",
  "type the code again": "Is kaam ke liye MFA code dobara likhein.",
  "say why": "Wajah likhein, kam az kam 3 harf.",
  "no such slip": "Ye slip nahin mili.",
  "this slip was decided already": "Is slip ka faisla pehle ho chuka hai.",
  "the amount received, the bank reference and the date received are needed": "Bank mein aayi raqam, bank reference aur tareekh zaroori hain.",
  "more than was paid": "Refund aaye hue paison se zyada nahin ho sakta.",
  "the end is in the past": "Khatam hone ki tareekh guzar chuki hai.",
  "this account is held already": "Ye account pehle se ruka hua hai.",
  "no trial claim for this email": "Is email ka koi trial claim nahin mila.",
  "the phone is that way already": "Phone pehle se isi haal mein hai.",
  "from 1 to 366 days": "Din 1 se 366 tak.",
  "say which plan": "Plan chunein.",
  "no such plan": "Ye plan nahin hai.",
  "no such account": "Ye account nahin mila.",
  "no such period": "Ye period nahin mila.",
  "no live hold with this id": "Ye rok ab lagi hui nahin.",
  "no live override with this id": "Ye chhoot ab lagi hui nahin.",
  "say what is corrected and to what": "Kya theek hua aur sahi value kya hai, dono likhein.",
  "a range from a start to an end": "Shuru aur aakhir ki tareekh theek chunein.",
  "from 0 to 366 days": "Credit ke din 0 se 366 tak.",
  "the add-on alone starts with its own period": "Sirf add-on ki slip apne period se chalti hai; use abhi se shuru nahin kiya jata.",
  // What the admin function answers (T22c).
  admins_only: "Ye kaam sirf platform ke malik ka hai, MFA code ke sath. Dobara sign in karein.",
  sign_in: "Session khatam ho gaya. Dobara sign in karein.",
  no_account: "Ye account nahin mila.",
  ban_failed: "Supabase ne kuch logins nahin badle. Thori der baad dobara koshish karein.",
  "Failed to fetch": "Cloud se rabta nahin hua. Internet dekh kar dobara koshish karein.",
};

export function cloudSays(message: string | undefined | null): string {
  if (!message) return "Cloud ne koi wajah nahin batayi.";
  return cloudWords[message] ?? message;
}
