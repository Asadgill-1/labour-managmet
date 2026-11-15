// What the app may ask the backup function, and how a refusal from Postgres reads to the app (T20d-a, D-076). No
// I/O, so Deno runs it on the cloud and Node or Deno test it.

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isId = (v: unknown): v is string => typeof v === "string" && uuid.test(v);

// The Postgres function to call, `backup_<action>`, with its arguments.
export type Ask =
  | {
    action: "start";
    args: { p_tenant_id: string; p_device_id: string; p_size_bytes: number; p_operation_id: string; p_replace: boolean };
  }
  | { action: "finish"; args: { p_tenant_id: string; p_operation_id: string } }
  | { action: "download"; args: { p_tenant_id: string; p_device_id: string; p_backup_id: string } };

// Null for anything that is not one of the three requests, whole and well formed.
export function parseAsk(body: unknown): Ask | null {
  if (typeof body !== "object" || body === null) return null;
  const b = body as Record<string, unknown>;
  if (!isId(b.tenant_id)) return null;
  if (b.action === "start") {
    if (!isId(b.device_id) || !isId(b.operation_id)) return null;
    if (!Number.isSafeInteger(b.size_bytes) || (b.size_bytes as number) < 1) return null;
    if (b.replace !== undefined && typeof b.replace !== "boolean") return null;
    return {
      action: "start",
      args: {
        p_tenant_id: b.tenant_id,
        p_device_id: b.device_id,
        p_size_bytes: b.size_bytes as number,
        p_operation_id: b.operation_id,
        p_replace: b.replace === true,
      },
    };
  }
  if (b.action === "finish") {
    if (!isId(b.operation_id)) return null;
    return { action: "finish", args: { p_tenant_id: b.tenant_id, p_operation_id: b.operation_id } };
  }
  if (b.action === "download") {
    if (!isId(b.device_id) || !isId(b.backup_id)) return null;
    return {
      action: "download",
      args: { p_tenant_id: b.tenant_id, p_device_id: b.device_id, p_backup_id: b.backup_id },
    };
  }
  return null;
}

// Each refusal the Postgres functions raise, as the word the app reads and the HTTP status.
const refusals: Record<string, [string, number]> = {
  "only the company's owner keeps the cloud copy": ["not_owner", 403],
  "this phone is not registered": ["not_registered", 403],
  "this device was revoked": ["phone_off", 403],
  "another phone is on": ["other_phone", 403],
  "the cloud copy is from another phone": ["other_phone_copy", 403],
  "the add-on is needed": ["addon_needed", 403],
  "the copy is too large": ["too_large", 400],
  "the copy's size is needed": ["bad_request", 400],
  "operation id already used": ["bad_request", 400],
  "too many copies today": ["too_many", 429],
  "no such copy": ["no_copy", 404],
  "the file has not arrived": ["not_arrived", 409],
};

// Null when the message is not a refusal the app knows, so the caller answers with a server error.
export function refusalOf(message: string | undefined): { error: string; status: number } | null {
  const found = message === undefined ? undefined : refusals[message];
  return found ? { error: found[0], status: found[1] } : null;
}
