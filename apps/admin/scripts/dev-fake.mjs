// The site against the stand-in cloud, in one process, for looking at the pages on this computer (sample data only).
// Its own two settings win over anything in .env.local, so the live project is never reached from here.
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import "./fake-cloud.mjs";

const site = fileURLToPath(new URL("..", import.meta.url));
const next = spawn(process.execPath, ["node_modules/next/dist/bin/next", "dev", "-p", process.env.PORT ?? "3100"], {
  cwd: site,
  stdio: "inherit",
  env: { ...process.env, NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54399", NEXT_PUBLIC_SUPABASE_ANON_KEY: "sample-anon-key" },
});
next.on("exit", (code) => process.exit(code ?? 0));
