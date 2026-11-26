// The admin function (T22c, D-082 (8), D-083): makes Supabase Auth match an account's hold, so a blocked account's
// users cannot sign in until the block ends or is lifted. It decides nothing: it asks Postgres, as the caller, for the
// account (`admin_account`, which refuses anyone but a platform admin with a TOTP code), and copies the live hold
// into each member's ban with the server's key, which only this function holds.
import { createClient } from "npm:@supabase/supabase-js@2";
import { banPlan, parseAsk, type AccountForBan } from "./ban.ts";

const url = Deno.env.get("SUPABASE_URL")!;
// ponytail: the server's own key from the legacy variable, as the licence function reads it; read the new secret key
// instead if the project drops legacy keys, checked when it goes live.
const server = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

// The dashboard runs on its own address; the caller's session, not the origin, is what is checked.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (req.method !== "POST") return reply({ error: "bad_request" }, 405);
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return reply({ error: "sign_in" }, 401);
    const ask = parseAsk(await req.json().catch(() => null));
    if (!ask) return reply({ error: "bad_request" }, 400);

    const asUser = createClient(url, req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false },
    });
    const account = await asUser.rpc("admin_account", { p_tenant: ask.tenant_id });
    if (account.error) {
      if (account.error.message === "admins only") return reply({ error: "admins_only" }, 403);
      if (account.error.message === "no such account") return reply({ error: "no_account" }, 404);
      if (account.error.code?.startsWith("PGRST3")) return reply({ error: "sign_in" }, 401);
      console.error(account.error.code, account.error.message);
      return reply({ error: "server" }, 500);
    }

    const plan = banPlan(account.data as AccountForBan, new Date());
    const failed: string[] = [];
    for (const id of plan.userIds) {
      const { error } = await server.auth.admin.updateUserById(id, { ban_duration: plan.duration });
      if (error) {
        console.error(id, error.message);
        failed.push(id);
      }
    }
    if (failed.length) return reply({ error: "ban_failed", failed: failed.length, of: plan.userIds.length }, 500);
    return reply({ ok: true, banned: plan.duration !== "none", users: plan.userIds.length });
  } catch (e) {
    console.error(e);
    return reply({ error: "server" }, 500);
  }
});
