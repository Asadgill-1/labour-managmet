"use client";
import { cloud } from "./cloud";
import { cloudSays } from "./words";

/**
 * Makes Supabase Auth match the account's hold: a live block bans its users' logins until it ends, anything else
 * lets them in. The `admin` Edge Function checks the caller itself and only copies what Postgres says (D-083).
 */
export async function syncBan(tenant: string): Promise<string | null> {
  const c = cloud();
  if (!c) return "settings missing";
  const { data, error } = await c.functions.invoke("admin", { body: { action: "sync_ban", tenant_id: tenant } });
  if (error) {
    const said = await (error as { context?: Response }).context?.json?.().catch(() => null);
    return said?.error ? cloudSays(said.error) : "Login ka badlav nahin hua: admin function tak rabta nahin hua.";
  }
  return data?.ok ? null : "Login ka badlav nahin hua.";
}
