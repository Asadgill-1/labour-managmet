// What the admin function accepts and how a hold becomes an Auth ban (T22c, TC-221). `node:test`, so Deno runs it on
// CI and Node here.
import { test } from "node:test";
import assert from "node:assert/strict";
import { banPlan, parseAsk, untilLifted } from "./ban.ts";

const tenant = "eeeeeeee-0000-0000-0000-000000000001";
const now = new Date("2026-11-26T06:00:00Z");
const members = [
  { user_id: "u1", revoked_at: null },
  { user_id: "u2", revoked_at: "2026-11-20T00:00:00Z" },
  { user_id: "u3", revoked_at: null },
];

test("only a well formed sync_ban for one account is accepted", () => {
  assert.deepEqual(parseAsk({ action: "sync_ban", tenant_id: tenant }), { action: "sync_ban", tenant_id: tenant });
  for (const bad of [null, "x", {}, { action: "ban", tenant_id: tenant }, { action: "sync_ban", tenant_id: "not-an-id" }, { action: "sync_ban" }]) {
    assert.equal(parseAsk(bad), null, JSON.stringify(bad));
  }
});

test("a block with no end bans the present members until lifted", () => {
  assert.deepEqual(banPlan({ hold: { kind: "block", until: null }, members }, now), { duration: untilLifted, userIds: ["u1", "u3"] });
});

test("a block with an end bans until then, rounded up to the hour, and never for less than one", () => {
  assert.equal(banPlan({ hold: { kind: "block", until: "2026-11-28T06:30:00Z" }, members }, now).duration, "49h");
  assert.equal(banPlan({ hold: { kind: "block", until: "2026-11-26T06:00:01Z" }, members }, now).duration, "1h");
});

test("a suspend or no hold lets every member who was ever in the account sign in", () => {
  for (const hold of [null, { kind: "suspend", until: null }]) {
    assert.deepEqual(banPlan({ hold, members }, now), { duration: "none", userIds: ["u1", "u2", "u3"] });
  }
});
