"use client";
import { useEffect, useRef, useState, type FormEvent, type ReactNode } from "react";
import { ago, showTime } from "@/lib/dates";
import { codeIsFresh, checkCode } from "@/lib/session";
import type { Load } from "@/lib/use-rpc";
import { cloudSays } from "@/lib/words";

/** A region's four states: loading in the content's shape, empty with what fills it, error with the last good data. */
export function Region<T>(props: {
  load: Load<T>;
  isEmpty?: (data: T) => boolean;
  empty?: { title: string; body: string; action?: ReactNode };
  lines?: number;
  children: (data: T) => ReactNode;
}) {
  const { load, isEmpty, empty, lines = 4, children } = props;
  if (load.data === null && load.loading) {
    return (
      <div aria-busy="true" aria-label="Aa raha hai">
        {Array.from({ length: lines }, (_, i) => <span key={i} className={`skel ${["w80", "w60", "w80", "w40"][i % 4]}`} />)}
      </div>
    );
  }
  const failed = load.error ? (
    <div className="banner" role="alert">
      <b>Cloud se rabta nahin hua</b>
      {cloudSays(load.error)}
      {load.fetchedAt ? ` ${showTime(load.fetchedAt)} ka data dikh raha hai.` : ""}
      <div><button type="button" onClick={load.reload}>Dobara koshish</button></div>
    </div>
  ) : null;
  if (load.data === null) return failed;
  if (isEmpty?.(load.data) && empty) {
    return (
      <>
        {failed}
        <div className="empty"><b>{empty.title}</b><p>{empty.body}</p>{empty.action ? <div className="actions">{empty.action}</div> : null}</div>
      </>
    );
  }
  return <>{failed}{children(load.data)}</>;
}

/** When the page's data was fetched, as every number must say (ADMIN-01). */
export function Fresh({ at, note }: { at: Date | null; note?: string }) {
  return <span className="fresh">{at ? `Cloud se, ${ago(at)} tak.` : "Cloud se aa raha hai."}{note ? ` ${note}` : ""}</span>;
}

export function Tag({ kind, children }: { kind?: string; children: ReactNode }) {
  return <span className={`tag ${kind ?? ""}`}>{children}</span>;
}

/**
 * An action the owner takes: its fields, a reason for the audit log when it needs one, the TOTP code again when the
 * last one is old and the action asks for it. A failure keeps the form filled and says what the cloud said.
 */
export function ActionDialog(props: {
  title: string;
  open: boolean;
  onClose: () => void;
  submit: string;
  danger?: boolean;
  reason?: string | false;
  needsCode?: boolean;
  children?: ReactNode;
  run: (reason: string) => Promise<string | null>;
  onDone: () => void;
}) {
  const { title, open, onClose, submit, danger, reason = "Wajah, audit log mein jayegi", needsCode, children, run, onDone } = props;
  const ref = useRef<HTMLDialogElement>(null);
  const [why, setWhy] = useState("");
  const [code, setCode] = useState("");
  const [askCode, setAskCode] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) {
      setError(null);
      setCode("");
      d.showModal();
      if (needsCode) codeIsFresh().then((fresh) => setAskCode(!fresh));
    }
    if (!open && d.open) d.close();
  }, [open, needsCode]);

  async function go(e: FormEvent) {
    e.preventDefault();
    if (reason && why.trim().length < 3) return setError("Wajah likhein, kam az kam 3 harf.");
    setBusy(true);
    setError(null);
    if (needsCode && askCode) {
      const wrong = await checkCode(code.trim());
      if (wrong) {
        setBusy(false);
        return setError(wrong);
      }
      setAskCode(false);
    }
    const failed = await run(why.trim());
    setBusy(false);
    if (failed) return setError(cloudSays(failed));
    setWhy("");
    onDone();
    onClose();
  }

  return (
    <dialog ref={ref} onClose={onClose} aria-labelledby="dialog-title">
      <div className="dialog-head"><h2 id="dialog-title">{title}</h2></div>
      <div className="dialog-body">
        <form onSubmit={go}>
          {children}
          {reason ? (
            <label>{reason}<input name="reason" value={why} onChange={(e) => setWhy(e.target.value)} maxLength={500} required minLength={3} /></label>
          ) : null}
          {needsCode && askCode ? (
            <label>MFA code dobara, authenticator app se
              <input name="code" value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" autoComplete="one-time-code" maxLength={6} placeholder="6 hindse" required />
            </label>
          ) : null}
          {error ? <p className="field-warn" role="alert">{error}</p> : null}
          <div className="actions">
            <button type="submit" className={danger ? "danger" : "primary"} disabled={busy} aria-busy={busy}>{busy ? "Ho raha hai" : submit}</button>
            <button type="button" className="quiet" onClick={onClose}>Rehne dein</button>
          </div>
        </form>
      </div>
    </dialog>
  );
}
