// What the backup function accepts and how it words a refusal (T20d-a, TC-193). `node:test`, so Deno runs it on CI
// and Node here.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseAsk, refusalOf } from "./request.ts";

const tenant = "eeeeeeee-0000-0000-0000-000000000001";
const phone = "dddddddd-0000-0000-0000-00000000000a";
const operation = "cccccccc-0000-0000-0000-000000000001";

test("a start names the company, the phone, the size and the operation", () => {
  assert.deepEqual(
    parseAsk({ action: "start", tenant_id: tenant, device_id: phone, size_bytes: 1200, operation_id: operation }),
    {
      action: "start",
      args: { p_tenant_id: tenant, p_device_id: phone, p_size_bytes: 1200, p_operation_id: operation, p_replace: false },
    },
  );
});

test("replacing another phone's copy is said outright, never assumed", () => {
  const ask = { action: "start", tenant_id: tenant, device_id: phone, size_bytes: 1, operation_id: operation };
  const kept = parseAsk({ ...ask, replace: true });
  assert.equal(kept?.action === "start" && kept.args.p_replace, true);
  assert.equal(parseAsk({ ...ask, replace: "yes" }), null);
});

test("a size that is not a whole number above zero is refused", () => {
  const ask = { action: "start", tenant_id: tenant, device_id: phone, operation_id: operation };
  for (const size_bytes of [0, -5, 1.5, "1200", null, undefined, Number.MAX_VALUE]) {
    assert.equal(parseAsk({ ...ask, size_bytes }), null);
  }
});

test("a finish and a download carry only their own ids", () => {
  assert.deepEqual(parseAsk({ action: "finish", tenant_id: tenant, operation_id: operation, extra: 1 }), {
    action: "finish",
    args: { p_tenant_id: tenant, p_operation_id: operation },
  });
  assert.deepEqual(parseAsk({ action: "download", tenant_id: tenant, device_id: phone, backup_id: operation }), {
    action: "download",
    args: { p_tenant_id: tenant, p_device_id: phone, p_backup_id: operation },
  });
});

test("anything else is not a request", () => {
  for (const body of [null, "start", [], {}, { action: "sweep", tenant_id: tenant }]) {
    assert.equal(parseAsk(body), null);
  }
  assert.equal(parseAsk({ action: "finish", tenant_id: "not-an-id", operation_id: operation }), null);
  assert.equal(parseAsk({ action: "download", tenant_id: tenant, device_id: phone, backup_id: "../other" }), null);
});

test("a refusal reads as its own word and status", () => {
  assert.deepEqual(refusalOf("the add-on is needed"), { error: "addon_needed", status: 403 });
  assert.deepEqual(refusalOf("the cloud copy is from another phone"), { error: "other_phone_copy", status: 403 });
  assert.deepEqual(refusalOf("only the company's owner keeps the cloud copy"), { error: "not_owner", status: 403 });
  assert.deepEqual(refusalOf("the file has not arrived"), { error: "not_arrived", status: 409 });
  assert.deepEqual(refusalOf("too many copies today"), { error: "too_many", status: 429 });
});

test("an unknown message is no refusal, so no detail leaks", () => {
  assert.equal(refusalOf('relation "private.backup_removals" does not exist'), null);
  assert.equal(refusalOf(undefined), null);
});
