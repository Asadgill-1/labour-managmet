"use client";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { Shell } from "@/components/Shell";
import { Fresh, Region, Tag } from "@/components/ui";
import { downloadCsv } from "@/lib/csv";
import { ago, daysLeft, dubaiDay, showDate } from "@/lib/dates";
import { showFils } from "@/lib/money";
import type { AccountRow } from "@/lib/types";
import { useRpc } from "@/lib/use-rpc";
import { readQuery, writeQuery } from "@/lib/url";
import { planShort, stateTag, stateWord } from "@/lib/words";

const defaults = { view: "sab", q: "", plan: "", state: "", version: "", addon: "", sort: "created", dir: "desc", page: 1, per: 25, test: false };
type Query = typeof defaults;

const week = 7 * 86_400_000;
const over = (a: AccountRow) =>
  (a.limits?.workers != null && (a.workers ?? 0) > a.limits.workers) || (a.limits?.clients != null && (a.clients ?? 0) > a.limits.clients);
const offline = (a: AccountRow) => (a.state === "trial" || a.state === "paid") && (!a.last_seen || Date.now() - Date.parse(a.last_seen) > week);

// The saved views (D-081); "in loss" waits for the books in part 2.
const views: { key: string; label: string; keep: (a: AccountRow) => boolean }[] = [
  { key: "sab", label: "Sab", keep: () => true },
  { key: "trial", label: "Trial khatam hone wale", keep: (a) => a.state === "trial" && !!a.plan_ends_at && daysLeft(a.plan_ends_at) <= 5 },
  { key: "offline", label: "7 din se offline", keep: offline },
  { key: "over", label: "Had se upar", keep: over },
  { key: "slip", label: "Slip intezar mein", keep: (a) => a.slips_waiting > 0 },
  { key: "held", label: "Ruke hue", keep: (a) => a.state === "held" },
  { key: "ended", label: "Plan khatam", keep: (a) => a.state === "ended" },
];

const sorts: Record<string, (a: AccountRow) => string | number> = {
  name: (a) => a.name.toLowerCase(),
  state: (a) => a.state,
  ends: (a) => a.plan_ends_at ?? "",
  phones: (a) => a.phones_on,
  seen: (a) => a.last_seen ?? "",
  version: (a) => a.app_version ?? "",
  workers: (a) => a.workers ?? -1,
  clients: (a) => a.clients ?? -1,
  paid: (a) => a.paid_fils,
  created: (a) => a.created_at,
};

export default function AccountsPage() {
  return <Shell><Suspense><Accounts /></Suspense></Shell>;
}

function pick(rows: AccountRow[], q: Query) {
  const view = views.find((v) => v.key === q.view) ?? views[0];
  const text = q.q.trim().toLowerCase();
  const kept = rows.filter((a) =>
    view.keep(a) &&
    (!text || a.name.toLowerCase().includes(text) || (a.owner_email ?? "").toLowerCase().includes(text) || a.tenant_id.startsWith(text)) &&
    (!q.plan || a.plan === q.plan) &&
    (!q.state || a.state === q.state) &&
    (!q.version || (a.app_version ?? "") === q.version) &&
    (!q.addon || (q.addon === "hai") === !!a.addon_ends_at));
  const key = sorts[q.sort] ?? sorts.created;
  const sign = q.dir === "asc" ? 1 : -1;
  return kept.sort((x, y) => (key(x) < key(y) ? -sign : key(x) > key(y) ? sign : 0));
}

function stateText(a: AccountRow) {
  if (a.state === "held") return `${a.hold?.kind === "block" ? "Block" : "Suspend"}${a.hold?.until ? `, ${showDate(a.hold.until)} tak` : ""}`;
  if (a.state === "paid" || a.state === "trial") return `${planShort(a.plan)}${a.state === "paid" ? ", paid" : ""}${a.slips_waiting ? ", slip aayi" : ""}`;
  return stateWord[a.state];
}

function Accounts() {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  const q = readQuery(params, defaults);
  const set = (next: Partial<Query>) => router.replace(path + writeQuery({ ...q, page: 1, ...next }, defaults), { scroll: false });
  const load = useRpc<AccountRow[]>("admin_accounts", { p_include_test: q.test });

  const head = (key: string, label: string, num = false) => (
    <th className={num ? "num" : undefined} aria-sort={q.sort === key ? (q.dir === "asc" ? "ascending" : "descending") : "none"}>
      <button type="button" className="sort" onClick={() => set({ sort: key, dir: q.sort === key && q.dir === "desc" ? "asc" : "desc", page: q.page })}>
        {label}{q.sort === key ? (q.dir === "asc" ? " ↑" : " ↓") : ""}
      </button>
    </th>
  );

  return (
    <main className="sheet-page">
      <div className="cap page">
        <div className="section-head"><h1 className="page-title">Accounts</h1><Fresh at={load.fetchedAt} /></div>
        <Region load={load} lines={8} isEmpty={(rows) => rows.length === 0} empty={{ title: "Abhi koi account nahin", body: "App se pehla signup hote hi yahan aayega." }}>
          {(rows) => {
            const shown = pick(rows, q);
            const pages = Math.max(1, Math.ceil(shown.length / q.per));
            const page = Math.min(q.page, pages);
            const slice = shown.slice((page - 1) * q.per, page * q.per);
            const versions = [...new Set(rows.map((a) => a.app_version).filter(Boolean))].sort() as string[];
            const plans = [...new Set(rows.map((a) => a.plan).filter(Boolean))] as string[];
            return (
              <>
                <nav className="views" aria-label="Saved views">
                  {views.map((v) => (
                    <button key={v.key} type="button" aria-current={q.view === v.key ? "page" : undefined} onClick={() => set({ view: v.key })}>
                      {v.label}<span className="count">{rows.filter(v.keep).length}</span>
                    </button>
                  ))}
                </nav>
                <div className="filters" role="group" aria-label="Filters">
                  <input type="search" aria-label="Account, email ya tenant id" placeholder="Account, email ya tenant id" defaultValue={q.q} onChange={(e) => set({ q: e.target.value })} />
                  <select aria-label="Plan" value={q.plan} onChange={(e) => set({ plan: e.target.value })}>
                    <option value="">Plan: sab</option>
                    {plans.map((p) => <option key={p} value={p}>{planShort(p)}</option>)}
                  </select>
                  <select aria-label="Haalat" value={q.state} onChange={(e) => set({ state: e.target.value })}>
                    <option value="">Haalat: sab</option>
                    {Object.entries(stateWord).map(([k, w]) => <option key={k} value={k}>{w}</option>)}
                  </select>
                  <select aria-label="Version" value={q.version} onChange={(e) => set({ version: e.target.value })}>
                    <option value="">Version: sab</option>
                    {versions.map((v) => <option key={v} value={v}>{v}</option>)}
                  </select>
                  <select aria-label="Cloud add-on" value={q.addon} onChange={(e) => set({ addon: e.target.value })}>
                    <option value="">Add-on: sab</option>
                    <option value="hai">Add-on hai</option>
                    <option value="nahin">Add-on nahin</option>
                  </select>
                  <label className="switch"><input type="checkbox" checked={q.test} onChange={(e) => set({ test: e.target.checked })} /> Test accounts bhi</label>
                  <span className="spacer" />
                  <button type="button" className="chip" onClick={() => downloadCsv(`accounts-${dubaiDay(new Date())}.csv`, csvRows(shown))}>CSV nikalein</button>
                </div>
                {shown.length === 0 ? (
                  <div className="empty"><b>Is filter mein koi account nahin</b><p>Filter badlein ya sab dekhein.</p><div className="actions"><button type="button" onClick={() => router.replace(path)}>Sab dikhayein</button></div></div>
                ) : (
                  <div className="table-wrap">
                    <table>
                      <thead><tr>
                        {head("name", "Account")}{head("state", "Haalat")}{head("ends", "Plan khatam")}{head("phones", "Phone", true)}
                        {head("seen", "Aakhri baar online")}{head("version", "Version")}{head("workers", "Labour", true)}{head("clients", "Clients", true)}{head("paid", "Diya kul", true)}
                      </tr></thead>
                      <tbody>
                        {slice.map((a) => (
                          <tr key={a.tenant_id}>
                            <td><Link href={`/account/?id=${a.tenant_id}`}>{a.name}</Link>{a.is_test ? <> <Tag>test</Tag></> : null}<span className="sub">{a.owner_email ?? "owner nahin"}, {showDate(a.created_at)}</span></td>
                            <td><Tag kind={over(a) ? "over" : stateTag[a.state]}>{stateText(a)}{over(a) ? ", had se upar" : ""}</Tag></td>
                            <td>{showDate(a.plan_ends_at)}</td>
                            <td className="num">{a.phones_on}</td>
                            <td className={offline(a) ? "late" : undefined}>{ago(a.last_seen)}</td>
                            <td>{a.app_version ?? "-"}</td>
                            <td className={`num${a.limits?.workers != null && (a.workers ?? 0) > a.limits.workers ? " late" : ""}`}>{a.workers ?? "-"}{a.limits?.workers != null ? <span className="sub">had {a.limits.workers}</span> : null}</td>
                            <td className="num">{a.clients ?? "-"}</td>
                            <td className="num">{showFils(a.paid_fils)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
                <div className="pager">
                  <span>{shown.length ? `${(page - 1) * q.per + 1} se ${Math.min(page * q.per, shown.length)}, kul ${shown.length} is filter mein` : "0"}</span>
                  <label className="switch">Har safhe par
                    <select aria-label="Har safhe par kitne" value={q.per} onChange={(e) => set({ per: Number(e.target.value) })}>
                      {[25, 50, 100].map((n) => <option key={n} value={n}>{n}</option>)}
                    </select>
                  </label>
                  <button type="button" className="chip" disabled={page <= 1} onClick={() => set({ page: page - 1 })}>Pichhla</button>
                  <button type="button" className="chip" disabled={page >= pages} onClick={() => set({ page: page + 1 })}>Agla</button>
                </div>
                <p className="src">Labour aur clients har phone ke aakhri licence check se. Aakhri baar online wo waqt hai jab phone ne cloud se baat ki; offline phone ka data der se aata hai.</p>
              </>
            );
          }}
        </Region>
      </div>
    </main>
  );
}

function csvRows(rows: AccountRow[]): string[][] {
  return [
    ["Account", "Tenant id", "Owner email", "Signup", "Haalat", "Plan", "Plan khatam", "Add-on tak", "Phone", "Aakhri baar online", "Version", "Labour", "Labour ki had", "Clients", "Slips intezar", "Diya kul (AED)", "Test"],
    ...rows.map((a) => [
      a.name, a.tenant_id, a.owner_email ?? "", dubaiDay(a.created_at), stateWord[a.state], planShort(a.plan), a.plan_ends_at ? dubaiDay(a.plan_ends_at) : "",
      a.addon_ends_at ? dubaiDay(a.addon_ends_at) : "", String(a.phones_on), a.last_seen ? dubaiDay(a.last_seen) : "", a.app_version ?? "",
      String(a.workers ?? ""), String(a.limits?.workers ?? ""), String(a.clients ?? ""), String(a.slips_waiting), showFils(a.paid_fils), a.is_test ? "haan" : "",
    ]),
  ];
}
