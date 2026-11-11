// The licence signature (T21a, TC-178): good, tampered, another key. `node:test`, so Deno runs it on CI and Node here.
import { test } from "node:test";
import assert from "node:assert/strict";
import { fromBase64Url, makeKeyPair, signLicence, toBase64Url, verifyLicence } from "./sign.ts";

const facts = {
  v: 1,
  iss: "labour-app",
  tenant_id: "eeeeeeee-0000-0000-0000-000000000001",
  state: "paid",
  plan: "small",
  limits: { workers: 15, clients: 5, managers: 1, devices: 1 },
};

test("a signed licence checks out with its public half", async () => {
  const key = await makeKeyPair();
  assert.equal(await verifyLicence(await signLicence(facts, key), key.public_raw), true);
});

test("one changed byte of the payload fails", async () => {
  const key = await makeKeyPair();
  const licence = await signLicence(facts, key);
  const bytes = fromBase64Url(licence.payload);
  bytes[bytes.length - 3] ^= 1;
  assert.equal(await verifyLicence({ ...licence, payload: toBase64Url(bytes) }, key.public_raw), false);
});

test("another key's public half fails", async () => {
  const licence = await signLicence(facts, await makeKeyPair());
  assert.equal(await verifyLicence(licence, (await makeKeyPair()).public_raw), false);
});

test("the payload is the facts' own JSON", async () => {
  const licence = await signLicence(facts, await makeKeyPair());
  assert.deepEqual(JSON.parse(new TextDecoder().decode(fromBase64Url(licence.payload))), facts);
});

test("the public half is 32 bytes", async () => {
  assert.equal(atob((await makeKeyPair()).public_raw).length, 32);
});
