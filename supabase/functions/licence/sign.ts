// Ed25519 licences (T21a, D-074, BILL-03): the key pair, signing and checking. No I/O, so Deno runs it on the cloud
// and Node or Deno test it. The signature covers the payload's exact bytes, which travel as they were signed.

export type StoredKey = { private_pkcs8: string; public_raw: string };
export type SignedLicence = { payload: string; sig: string };

const ed25519 = { name: "Ed25519" } as const;

function toBase64(bytes: Uint8Array): string {
  let text = "";
  for (const b of bytes) text += String.fromCharCode(b);
  return btoa(text);
}

function fromBase64(text: string) {
  return Uint8Array.from(atob(text), (c) => c.charCodeAt(0));
}

export function toBase64Url(bytes: Uint8Array): string {
  return toBase64(bytes).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

export function fromBase64Url(text: string) {
  const b64 = text.replaceAll("-", "+").replaceAll("_", "/");
  return fromBase64(b64 + "=".repeat((4 - (b64.length % 4)) % 4));
}

// A new pair: the private half as PKCS #8 and the public half as its 32 raw bytes, both base64.
export async function makeKeyPair(): Promise<StoredKey> {
  const pair = (await crypto.subtle.generateKey(ed25519, true, ["sign", "verify"])) as CryptoKeyPair;
  const privateKey = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const publicKey = new Uint8Array(await crypto.subtle.exportKey("raw", pair.publicKey));
  return { private_pkcs8: toBase64(privateKey), public_raw: toBase64(publicKey) };
}

// The facts as UTF-8 JSON, and the signature over those bytes, both base64url without padding.
export async function signLicence(facts: unknown, key: StoredKey): Promise<SignedLicence> {
  const bytes = new TextEncoder().encode(JSON.stringify(facts));
  const privateKey = await crypto.subtle.importKey("pkcs8", fromBase64(key.private_pkcs8), ed25519, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign(ed25519, privateKey, bytes));
  return { payload: toBase64Url(bytes), sig: toBase64Url(sig) };
}

// What the app does with the public half: true only for the payload's own signature.
export async function verifyLicence(licence: SignedLicence, publicRaw: string): Promise<boolean> {
  const publicKey = await crypto.subtle.importKey("raw", fromBase64(publicRaw), ed25519, false, ["verify"]);
  return crypto.subtle.verify(ed25519, publicKey, fromBase64Url(licence.sig), fromBase64Url(licence.payload));
}
