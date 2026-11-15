// The backup function (T20d-a, D-072, D-075, D-076). The app has no access to the stored copies. It asks here, with
// the user's session; Postgres, asked as that user, decides (`backup_start`, `backup_finish`, `backup_download`); and
// only then does the server hand out a one-time upload link or a 60-second download link. After each finished
// upload it removes from storage the files whose time has come, since SQL cannot remove a stored file.
import { createClient } from "npm:@supabase/supabase-js@2";
import { parseAsk, refusalOf } from "./request.ts";

const url = Deno.env.get("SUPABASE_URL")!;
// ponytail: the server's own key from the legacy variable, as the licence function reads it.
const server = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const files = server.storage.from("backups");

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

// Copies that left a company's list, and a deleted account's copy after its 60 days. A file already gone is no
// error, and a failure leaves the list as it was for the next upload to try again.
async function removeDue(): Promise<void> {
  const due = await server.rpc("backup_removals_due");
  if (due.error) throw due.error;
  const paths = due.data as string[];
  if (paths.length === 0) return;
  const gone = await files.remove(paths);
  if (gone.error) throw gone.error;
  const done = await server.rpc("backup_removals_done", { p_paths: paths });
  if (done.error) throw done.error;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return reply({ error: "bad_request" }, 405);
    const auth = req.headers.get("Authorization");
    if (!auth?.startsWith("Bearer ")) return reply({ error: "sign_in" }, 401);
    const ask = parseAsk(await req.json().catch(() => null));
    if (!ask) return reply({ error: "bad_request" }, 400);
    // As the user: the app's own publishable key with the user's session, so Postgres takes the user from the session.
    const asUser = createClient(url, req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
      auth: { persistSession: false },
    });
    const said = await asUser.rpc(`backup_${ask.action}`, ask.args);
    if (said.error) {
      const refusal = refusalOf(said.error.message);
      if (refusal) return reply({ error: refusal.error }, refusal.status);
      if (said.error.code?.startsWith("PGRST3")) return reply({ error: "sign_in" }, 401);
      console.error(said.error.code, said.error.message);
      return reply({ error: "server" }, 500);
    }
    if (ask.action === "start") {
      const { path, arrived } = said.data as { path: string; arrived: boolean };
      // A retry after the upload went through: nothing to send again, the app goes on to finish.
      if (arrived) return reply({ path, token: null });
      const link = await files.createSignedUploadUrl(path);
      if (link.error) throw link.error;
      return reply({ path, token: link.data.token });
    }
    if (ask.action === "finish") {
      await removeDue().catch((e) => console.error("removals", e));
      return reply({ finished_at: said.data });
    }
    const link = await files.createSignedUrl(said.data as string, 60);
    if (link.error) throw link.error;
    return reply({ url: link.data.signedUrl });
  } catch (e) {
    console.error(e);
    return reply({ error: "server" }, 500);
  }
});
