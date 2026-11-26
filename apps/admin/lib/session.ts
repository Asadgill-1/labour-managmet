"use client";
import { cloud } from "./cloud";

// Holds, refunds, corrections and plan changes ask for the code again once the last one is about five minutes old;
// Postgres refuses them after 300 seconds, so the page asks a little before (D-081).
const freshFor = 270;
// The session ends after 12 hours with nothing done (D-081).
const idleLimitMs = 12 * 3_600_000;
const activeKey = "labour-admin-active";

type Amr = { method: string; timestamp: number };

function claims(token: string | undefined): { amr?: Amr[]; aal?: string; email?: string } {
  if (!token) return {};
  try {
    const part = token.split(".")[1].replaceAll("-", "+").replaceAll("_", "/");
    return JSON.parse(atob(part.padEnd(part.length + ((4 - (part.length % 4)) % 4), "=")));
  } catch {
    return {};
  }
}

/** True when the session's newest TOTP check is recent enough for a hold, a refund or a plan change. */
export async function codeIsFresh(): Promise<boolean> {
  const c = cloud();
  const token = (await c?.auth.getSession())?.data.session?.access_token;
  const newest = Math.max(0, ...(claims(token).amr ?? []).filter((a) => a.method === "totp").map((a) => a.timestamp));
  return newest > Date.now() / 1000 - freshFor;
}

/** The verified TOTP factor's id, if the admin has one. */
export async function totpFactor(): Promise<string | null> {
  const c = cloud();
  const { data } = (await c?.auth.mfa.listFactors()) ?? { data: null };
  return data?.totp.find((f) => f.status === "verified")?.id ?? null;
}

/** Checks a six-digit code against the admin's factor; the session then carries a fresh TOTP check. */
export async function checkCode(code: string): Promise<string | null> {
  const c = cloud();
  if (!c) return "settings missing";
  if (!/^\d{6}$/.test(code)) return "6 hindse likhein.";
  const factorId = await totpFactor();
  if (!factorId) return "Is login par MFA nahin laga. Dobara sign in karein.";
  const { error } = await c.auth.mfa.challengeAndVerify({ factorId, code });
  return error ? "Code ghalat hai ya purana ho gaya. Authenticator app mein naya code dekhein." : null;
}

export type Gate = "missing" | "out" | "code" | "in";

/** Where the session stands: no settings, signed out, password only, or password and code. */
export async function gate(): Promise<{ gate: Gate; email: string | null }> {
  const c = cloud();
  if (!c) return { gate: "missing", email: null };
  const { data } = await c.auth.getSession();
  if (!data.session) return { gate: "out", email: null };
  const last = Number(localStorage.getItem(activeKey) ?? Date.now());
  if (Date.now() - last > idleLimitMs) {
    await c.auth.signOut();
    return { gate: "out", email: null };
  }
  const level = await c.auth.mfa.getAuthenticatorAssuranceLevel();
  return { gate: level.data?.currentLevel === "aal2" ? "in" : "code", email: data.session.user.email ?? null };
}

/** Marks the admin as active now, at most once a minute. */
export function touch(): void {
  const last = Number(localStorage.getItem(activeKey) ?? 0);
  if (Date.now() - last > 60_000) localStorage.setItem(activeKey, String(Date.now()));
}

export async function signOut(): Promise<void> {
  await cloud()?.auth.signOut();
  localStorage.removeItem(activeKey);
}
