"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { rpc } from "./cloud";

export type Load<T> = {
  data: T | null;
  error: string | null;
  loading: boolean;
  /** When the data shown was fetched; kept from the last good fetch when a later one fails. */
  fetchedAt: Date | null;
  reload: () => void;
};

/** Reads an admin_ function; a failed reload keeps the last data and its time, so the page can say how old it is. */
export function useRpc<T>(name: string, args: Record<string, unknown>, skip = false): Load<T> {
  const [state, setState] = useState<Omit<Load<T>, "reload">>({ data: null, error: null, loading: !skip, fetchedAt: null });
  const [token, setToken] = useState(0);
  const key = JSON.stringify(args);
  const latest = useRef(0);

  useEffect(() => {
    if (skip) return;
    const ask = ++latest.current;
    setState((s) => ({ ...s, loading: true }));
    rpc<T>(name, JSON.parse(key)).then((r) => {
      if (ask !== latest.current) return;
      setState((s) => r.error === null
        ? { data: r.data, error: null, loading: false, fetchedAt: new Date() }
        : { ...s, error: r.error, loading: false });
    });
  }, [name, key, token, skip]);

  const reload = useCallback(() => setToken((t) => t + 1), []);
  return { ...state, reload };
}
