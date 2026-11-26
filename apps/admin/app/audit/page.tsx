"use client";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useMemo } from "react";
import { Shell } from "@/components/Shell";
import { Fresh, Region } from "@/components/ui";
import { downloadCsv } from "@/lib/csv";
import { dubaiDay, rangeOf, showTime, type RangeKey } from "@/lib/dates";
import { showFils } from "@/lib/money";
import type { AuditRow } from "@/lib/types";
import { useRpc } from "@/lib/use-rpc";
import { readQuery, writeQuery } from "@/lib/url";
import { actionWord, moneyActions } from "@/lib/words";

const defaults = { r: "30d", q: "", who: "", group: "" };
const ranges = [{ key: "7d", label: "7 din" }, { key: "30d", label: "30 din" }, { key: "3m", label: "3 mahine" }, { key: "12m", label: "12 mahine" }];

export default function AuditPage() {
  return <Shell><Suspense><Audit /></Suspense></Shell>;
}

// The before and after of a change, short: the fields that say what changed.
const keys = ["state", "kind", "plan", "days", "from", "what", "cap", "until", "told", "name", "is_test", "amount_fils", "field", "value", "on_date", "starts_at_utc", "ends_at_utc", "revoked_at_utc", "lifted_at_utc", "credit_days", "cut_at"];
function brief(v: unknown): string {
  if (v === null || v === undefined) return "-";
  if (Array.isArray(v)) return `${v.length} cheezein`;
  if (typeof v !== "object") return String(v);
  const o = v as Record<string, unknown>;
  const parts = keys.filter((k) => o[k] !== undefined && o[k] !== null).map((k) => `${k}: ${k === "amount_fils" && typeof o[k] === "number" ? showFils(o[k] as number) : String(o[k]).slice(0, 40)}`);
  return parts.length ? parts.slice(0, 4).join(", ") : JSON.stringify(o).slice(0, 80);
}

function Audit() {
  const router = useRouter();
  const path = usePathname();
  const q = readQuery(useSearchParams(), defaults);
  const set = (next: Partial<typeof defaults>) => router.replace(path + writeQuery({ ...q, ...next }, defaults), { scroll: false });
  const range = useMemo(() => rangeOf(q.r as RangeKey), [q.r]);
  const load = useRpc<AuditRow[]>("admin_audit", { p_from: range.from, p_to: range.to });

  return (
    <main className="sheet-page">
      <div className="cap page">
        <div className="section-head"><h1 className="page-title">Audit log</h1><Fresh at={load.fetchedAt} /></div>
        <p className="src">Dashboard par har kaam: kis ne, kab, kis account par, kyun, aur pehle kya tha. Ye log na badla ja sakta hai na mitaya, account mitne ke baad bhi rehta hai (ADMIN-03, D-082 (5)).</p>
        <Region load={load} lines={8} isEmpty={(rows) => rows.length === 0} empty={{ title: "Is waqt mein koi kaam nahin hua", body: "Slip ka faisla, din dena ya account rokna yahan likha jata hai." }}>
          {(rows) => {
            const text = q.q.trim().toLowerCase();
            const shown = rows.filter((r) =>
              (!q.who || r.actor_email === q.who) &&
              (!q.group || (q.group === "paise") === moneyActions.has(r.action)) &&
              (!text || r.reason.toLowerCase().includes(text) || (r.tenant_name ?? "").toLowerCase().includes(text) || (actionWord[r.action] ?? r.action).toLowerCase().includes(text)));
            const who = [...new Set(rows.map((r) => r.actor_email).filter(Boolean))] as string[];
            return (
              <>
                <div className="filters" role="group" aria-label="Filters">
                  <input type="search" aria-label="Account, kaam ya wajah" placeholder="Account, kaam ya wajah" defaultValue={q.q} onChange={(e) => set({ q: e.target.value })} />
                  <select aria-label="Kis ne" value={q.who} onChange={(e) => set({ who: e.target.value })}>
                    <option value="">Kis ne: sab</option>{who.map((w) => <option key={w}>{w}</option>)}
                  </select>
                  <select aria-label="Kaam" value={q.group} onChange={(e) => set({ group: e.target.value })}>
                    <option value="">Kaam: sab</option><option value="paise">Paise wale</option><option value="account">Account wale</option>
                  </select>
                  <select aria-label="Waqt" value={q.r} onChange={(e) => set({ r: e.target.value })}>
                    {ranges.map((r) => <option key={r.key} value={r.key}>Waqt: {r.label}</option>)}
                  </select>
                  <span className="spacer" />
                  <button type="button" className="chip" onClick={() => downloadCsv(`audit-${dubaiDay(new Date())}.csv`, [
                    ["Waqt (UTC)", "Kis ne", "Kaam", "Account", "Tenant id", "Wajah", "Pehle", "Baad"],
                    ...shown.map((r) => [r.at_utc, r.actor_email ?? r.actor_id, actionWord[r.action] ?? r.action, r.tenant_name ?? "", r.tenant_id ?? "", r.reason, JSON.stringify(r.before), JSON.stringify(r.after)]),
                  ])}>CSV nikalein</button>
                </div>
                {shown.length === 0 ? <div className="empty"><b>Is filter mein kuch nahin</b><p>Filter badlein.</p></div> : (
                  <div className="table-wrap">
                    <table>
                      <thead><tr><th>Waqt</th><th>Kis ne</th><th>Kaam</th><th>Account</th><th>Wajah</th><th>Pehle</th><th>Baad</th></tr></thead>
                      <tbody>
                        {shown.map((r) => (
                          <tr key={r.id}>
                            <td>{showTime(r.at_utc)}</td>
                            <td>{r.actor_email ?? "-"}<span className="sub">MFA ke sath</span></td>
                            <td>{actionWord[r.action] ?? r.action}</td>
                            <td>{r.tenant_id ? <Link href={`/account/?id=${r.tenant_id}`}>{r.tenant_name ?? "mita hua account"}</Link> : "-"}</td>
                            <td className="wrap">{r.reason}</td>
                            <td className="wrap">{brief(r.before)}</td>
                            <td className="wrap">{brief(r.after)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
                <p className="src">{shown.length} kaam dikh rahe hain. Ek dafa mein zyada se zyada 5,000; is se purane ke liye waqt chhota karein.</p>
              </>
            );
          }}
        </Region>
      </div>
    </main>
  );
}
