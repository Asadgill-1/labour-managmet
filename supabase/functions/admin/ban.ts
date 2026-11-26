// What the admin function may be asked, and what a block means for the account's logins (T22c, D-082 (8), D-083).
// No I/O, so Deno runs it on the cloud and Node or Deno test it.

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Ask = { action: "sync_ban"; tenant_id: string };

// Null for anything that is not the one request, whole and well formed.
export function parseAsk(body: unknown): Ask | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  if (b.action !== "sync_ban" || typeof b.tenant_id !== "string" || !uuid.test(b.tenant_id)) return null;
  return { action: "sync_ban", tenant_id: b.tenant_id };
}

// The parts of `admin_account` this needs.
export type AccountForBan = {
  hold: { kind: string; until: string | null } | null;
  members: { user_id: string; revoked_at: string | null }[];
};

// About a hundred years: Supabase Auth's way of saying "until lifted".
export const untilLifted = "876000h";

/**
 * Supabase Auth copies the hold: a live block bans the account's present members until the block ends, rounded up to
 * the hour; anything else lets every member who was ever in the account sign in, so no ban outlives its block.
 */
export function banPlan(account: AccountForBan, now: Date): { duration: string; userIds: string[] } {
  if (account.hold?.kind !== "block") {
    return { duration: "none", userIds: account.members.map((m) => m.user_id) };
  }
  const until = account.hold.until ? Date.parse(account.hold.until) : null;
  const duration = until === null ? untilLifted : `${Math.max(1, Math.ceil((until - now.getTime()) / 3_600_000))}h`;
  return { duration, userIds: account.members.filter((m) => m.revoked_at === null).map((m) => m.user_id) };
}
