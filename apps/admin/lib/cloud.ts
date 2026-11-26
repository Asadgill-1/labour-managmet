"use client";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

// The site holds only the project's public URL and anon key (D-081). Every read and write goes through an admin_
// function, which checks the admin row and the TOTP code in Postgres, never here.
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

let client: SupabaseClient | null = null;

/** The client, or null when `.env.local` has no URL or key yet. */
export function cloud(): SupabaseClient | null {
  if (!url || !key) return null;
  client ??= createClient(url, key, { auth: { persistSession: true, storageKey: "labour-admin-session", autoRefreshToken: true } });
  return client;
}

export type Result<T> = { data: T; error: null } | { data: null; error: string };

/** Calls an admin_ function and gives back its data or the cloud's message. */
export async function rpc<T>(name: string, args: Record<string, unknown> = {}): Promise<Result<T>> {
  const c = cloud();
  if (!c) return { data: null, error: "settings missing" };
  try {
    const { data, error } = await c.rpc(name, args);
    if (error) return { data: null, error: error.message };
    return { data: data as T, error: null };
  } catch (e) {
    return { data: null, error: e instanceof Error ? e.message : String(e) };
  }
}
