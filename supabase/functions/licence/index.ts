// The licence function (T21a, D-074, BILL-03). GET gives the public half of the signing key, making the pair on its
// first run, so nobody ever types or sees the private half. POST, with the user's session, asks Postgres as that user
// what this phone's licence says (`licence_facts`, which checks membership and the phone), then signs it.
import { createClient } from "npm:@supabase/supabase-js@2";
import { makeKeyPair, signLicence, type StoredKey } from "./sign.ts";

const url = Deno.env.get("SUPABASE_URL")!;
// ponytail: the server's own key from the legacy variable; read the new secret key instead if the project drops legacy
// keys, checked when it goes live.
const server = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

const refusals: Record<string, string> = {
  "not a member of this company": "not_member",
  "this phone is not registered": "not_registered",
  "this device was revoked": "phone_off",
  "another phone is on": "other_phone",
  "counts out of range": "bad_request",
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

async function signingKey(): Promise<StoredKey> {
  const kept = await server.rpc("licence_signing_key");
  if (kept.error) throw kept.error;
  if (kept.data) return kept.data as StoredKey;
  const made = await server.rpc("licence_signing_key_keep", { p_key: await makeKeyPair() });
  if (made.error) throw made.error;
  return made.data as StoredKey;
}

Deno.serve(async (req) => {
  try {
    if (req.method === "GET") return reply({ public_key: (await signingKey()).public_raw });
    if (req.method !== "POST") return reply({ error: "bad_request" }, 405);
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return reply({ error: "sign_in" }, 401);
    const body = await req.json().catch(() => null);
    const { tenant_id, device_id, active_workers, active_clients } = body ?? {};
    if (!uuid.test(String(tenant_id)) || !uuid.test(String(device_id)) ||
      !Number.isInteger(active_workers) || !Number.isInteger(active_clients)) {
      return reply({ error: "bad_request" }, 400);
    }
    // As the user: the app's own publishable key with the user's session, so Postgres takes the user from the session.
    const asUser = createClient(url, req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false },
    });
    const facts = await asUser.rpc("licence_facts", {
      p_tenant_id: tenant_id,
      p_device_id: device_id,
      p_active_workers: active_workers,
      p_active_clients: active_clients,
    });
    if (facts.error) {
      const refusal = refusals[facts.error.message];
      if (refusal) return reply({ error: refusal }, refusal === "bad_request" ? 400 : 403);
      if (facts.error.code?.startsWith("PGRST3")) return reply({ error: "sign_in" }, 401);
      console.error(facts.error.code, facts.error.message);
      return reply({ error: "server" }, 500);
    }
    return reply(await signLicence(facts.data, await signingKey()));
  } catch (e) {
    console.error(e);
    return reply({ error: "server" }, 500);
  }
});
