"use client";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useMemo } from "react";
import { MonthBars, showMonth } from "@/components/charts";
import { Region } from "@/components/ui";
import { addMonth, addMonths, bookLists, cellText, sheetLines, sortRows, type BookRow, type MonthSummary } from "@/lib/book";
import { downloadCsv } from "@/lib/csv";
import { ago, dubaiDay, showDate } from "@/lib/dates";
import { showFils } from "@/lib/money";
import type { AccountBook, StoryEvent } from "@/lib/types";
import { useRpc, type Load } from "@/lib/use-rpc";

const ranges = [
  { key: "month", label: "Is mahina" },
  { key: "last", label: "Pichhla mahina" },
  { key: "3m", label: "3 mahine" },
  { key: "all", label: "Shuru se" },
] as const;
type RangeKey = (typeof ranges)[number]["key"];

/** The months [key] covers, `YYYY-MM`, up to the Dubai month now; "all" starts at the books' first month. */
function monthsOf(key: RangeKey, months: MonthSummary[]): { from: string; to: string } {
  const now = dubaiDay(new Date()).slice(0, 7);
  switch (key) {
    case "last":
      return { from: addMonth(now, -1), to: addMonth(now, -1) };
    case "3m":
      return { from: addMonth(now, -2), to: now };
    case "all":
      return { from: months[0]?.month ?? now, to: now };
    default:
      return { from: now, to: now };
  }
}

const rangeText = (r: { from: string; to: string }) => (r.from === r.to ? showMonth(r.from) : `${showMonth(r.from)} se ${showMonth(r.to)}`);

/** The firsts the books show (MET-05's funnel), for the account's story. */
export function bookStory(book: AccountBook | null): StoryEvent[] {
  if (!book) return [];
  const out: StoryEvent[] = [];
  if (book.consent_at) out.push({ at: book.consent_at, what: "consent", detail: book.consent_version ? `wording ${book.consent_version}` : null });
  if (book.firsts?.worker) out.push({ at: book.firsts.worker, what: "first_worker", detail: null });
  if (book.firsts?.attendance) out.push({ at: book.firsts.attendance, what: "first_attendance", detail: null });
  if (book.firsts?.invoice) out.push({ at: book.firsts.invoice, what: "first_invoice", detail: null });
  return out;
}

/** The account's first tab (mockup 2a): its business from its own books, as "Malik ki sheet" works it out. */
export function BookSummary({ load }: { load: Load<AccountBook> }) {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  const key = (ranges.find((r) => r.key === params.get("r"))?.key ?? "month") as RangeKey;
  const choose = (next: RangeKey) => {
    const q = new URLSearchParams(params.toString());
    if (next === "month") q.delete("r");
    else q.set("r", next);
    router.replace(`${path}?${q.toString()}`, { scroll: false });
  };
  return (
    <Region load={load} lines={6}>
      {(book) => {
        if (!book.consent_at) {
          return <div className="empty"><b>Ijazat abhi nahin di</b><p>Customer ne app mein kitab cloud par bhejne ki ijazat nahin di, is liye us ka hisaab yahan nahin aata. App khulte hi ijazat ka safha dikhati hai.</p></div>;
        }
        if (book.records === 0) {
          return <div className="empty"><b>Kitab abhi nahin aayi</b><p>Ijazat {showDate(book.consent_at)} ko di. Phone online hote hi kitab yahan aayegi.</p></div>;
        }
        const range = monthsOf(key, book.months);
        const shown = book.months.filter((m) => m.month >= range.from && m.month <= range.to);
        const f = addMonths(shown);
        return (
          <>
            <div className="range-row">
              <div className="seg" role="group" aria-label="Waqt">
                {ranges.map((r) => <button key={r.key} type="button" aria-pressed={key === r.key} onClick={() => choose(r.key)}>{r.label}</button>)}
              </div>
              <p className="src">{rangeText(range)}. Data {ago(book.last_at)} aaya. Ijazat {showDate(book.consent_at)} ko di, wording {book.consent_version}.</p>
            </div>
            <dl className="figs">
              <div className="fig"><dt>Kaam ka bill</dt><dd>AED {showFils(f.bill)}<small>hazri se, VAT ke baghair</small></dd></div>
              <div className="fig"><dt>Invoices</dt><dd>{f.invoices}<small>AED {showFils(f.invoiced - f.credited)}, VAT ke baghair, credit note ghata kar</small></dd></div>
              <div className="fig"><dt>Labour ki mazdoori</dt><dd>AED {showFils(f.wages)}<small>{f.days} hazri ke din</small></dd></div>
              <div className="fig"><dt>Andazan nafa</dt><dd className={f.estimate < 0 ? "late" : undefined}>AED {showFils(f.estimate)}<small>audit shuda nahin</small></dd></div>
              <div className="fig"><dt>Active labour</dt><dd>{book.counts?.workers ?? 0}<small>aaj</small></dd></div>
              <div className="fig"><dt>Client companies</dt><dd>{book.counts?.clients ?? 0}<small>{book.counts?.sites ?? 0} sites</small></dd></div>
            </dl>
            <div className="grid2 even">
              <section>
                <div className="section-head"><h2>Nafa aur nuqsan</h2><span>{rangeText(range)}, AED</span></div>
                <SheetTable months={shown} />
                <p className="src">Wahi hisaab jo customer ki app mein &ldquo;Malik ki sheet&rdquo; banati hai, us ke phone ke data se. VAT bill mein nahin; advance aur visa ke paise kharcha nahin, kyun ke worker wapas karta hai.</p>
              </section>
              <section>
                <div className="section-head"><h2>Har mahina</h2><span>AED</span></div>
                {shown.length > 1 ? <MonthBars label="Har mahine kaam ka bill" rows={shown.map((m) => ({ month: m.month, fils: m.bill }))} /> : null}
                <MonthTable months={shown} />
              </section>
            </div>
          </>
        );
      }}
    </Region>
  );
}

/** "Malik ki sheet" added up over [months]. */
export function SheetTable({ months }: { months: MonthSummary[] }) {
  return (
    <table className="lines">
      <tbody>
        {sheetLines(addMonths(months)).map((l) => (
          <tr key={l.label} className={l.total ? "total-row" : undefined}><td>{l.label}</td><td className={`num${l.fils < 0 && l.total ? " late" : ""}`}>{showFils(l.fils)}</td></tr>
        ))}
      </tbody>
    </table>
  );
}

export function MonthTable({ months }: { months: MonthSummary[] }) {
  if (!months.length) return <p className="src">Is waqt ka koi mahina nahin aaya.</p>;
  return (
    <div className="table-wrap">
    <table>
      <thead><tr><th>Mahina</th><th className="num">Bill</th><th className="num">Mazdoori</th><th className="num">Nafa ya nuqsan</th></tr></thead>
      <tbody>
        {months.map((m) => (
          <tr key={m.month}>
            <td>{showMonth(m.month)}</td>
            <td className="num">{showFils(m.bill)}</td>
            <td className="num">{showFils(m.wages)}</td>
            <td className={`num${m.estimate < 0 ? " late" : ""}`}>{m.estimate < 0 ? "Nuqsan " : "Nafa "}{showFils(Math.abs(m.estimate))}</td>
          </tr>
        ))}
      </tbody>
    </table>
    </div>
  );
}

const pageSize = 50;

/** The Kitab tab: the account's records by type, searched and paged, with CSV. Read only (D-081 Calls 2). */
export function Kitab({ tenant, name, consented }: { tenant: string; name: string; consented: boolean }) {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  const list = bookLists.find((l) => l.entity === params.get("k")) ?? bookLists[0];
  const search = params.get("q") ?? "";
  const page = Math.max(1, Number(params.get("p")) || 1);
  const set = (next: Record<string, string | null>) => {
    const q = new URLSearchParams(params.toString());
    for (const [k, v] of Object.entries(next)) {
      if (v === null || v === "") q.delete(k);
      else q.set(k, v);
    }
    router.replace(`${path}?${q.toString()}`, { scroll: false });
  };
  const rows = useRpc<BookRow[]>("admin_book", { p_tenant: tenant, p_entity: list.entity }, !consented);
  const needsWorkers = list.columns.some((c) => c.kind === "worker");
  const needsClients = list.columns.some((c) => c.kind === "client");
  const workers = useRpc<BookRow[]>("admin_book", { p_tenant: tenant, p_entity: "workers" }, !consented || !needsWorkers);
  const clients = useRpc<BookRow[]>("admin_book", { p_tenant: tenant, p_entity: "clients" }, !consented || !needsClients);
  const names = useMemo(
    () => ({
      workers: new Map((workers.data ?? []).map((w) => [w.id, String(w.data.name ?? w.id)])),
      clients: new Map((clients.data ?? []).map((c) => [c.id, String(c.data.name ?? c.id)])),
    }),
    [workers.data, clients.data],
  );

  if (!consented) return <div className="empty" style={{ marginTop: 16 }}><b>Ijazat abhi nahin di</b><p>Customer ki ijazat ke baad us ki kitab yahan aayegi.</p></div>;

  return (
    <div style={{ marginTop: 16 }}>
      <div className="range-row">
        <div className="seg" role="group" aria-label="Kitab ka hissa">
          {bookLists.map((l) => <button key={l.entity} type="button" aria-pressed={l.entity === list.entity} onClick={() => set({ k: l.entity === bookLists[0].entity ? null : l.entity, p: null, q: null })}>{l.label}</button>)}
        </div>
      </div>
      <Region
        load={rows}
        isEmpty={(r) => r.length === 0}
        empty={{ title: `${list.label} abhi nahin`, body: "Customer ke phone se is hisse ka koi record cloud par nahin aaya." }}
      >
        {(all) => {
          const live = sortRows(list.columns, all.filter((r) => list.live?.(r.data) ?? true));
          const text = (r: BookRow) => list.columns.map((c) => cellText(c, r.data, names, showFils));
          const needle = search.trim().toLowerCase();
          const found = needle ? live.filter((r) => text(r).some((t) => t.toLowerCase().includes(needle))) : live;
          const pages = Math.max(1, Math.ceil(found.length / pageSize));
          const at = Math.min(page, pages);
          const shown = found.slice((at - 1) * pageSize, at * pageSize);
          return (
            <>
              <div className="filters" role="group" aria-label="Filters">
                <input type="search" aria-label="Dhoondein" placeholder="Dhoondein" value={search} onChange={(e) => set({ q: e.target.value, p: null })} />
                <span className="spacer" />
                <span className="src">{found.length} {found.length === 1 ? "record" : "records"}</span>
                <button type="button" className="chip" onClick={() => downloadCsv(`${name}-${list.entity}.csv`, [list.columns.map((c) => c.label), ...found.map(text)])}>CSV nikalein</button>
              </div>
              <div className="table-wrap">
                <table>
                  <thead><tr>{list.columns.map((c) => <th key={c.key} className={c.kind === "fils" || c.kind === "minutes" ? "num" : undefined}>{c.label}</th>)}</tr></thead>
                  <tbody>
                    {shown.map((r) => (
                      <tr key={r.id}>{list.columns.map((c, i) => <td key={c.key} className={c.kind === "fils" || c.kind === "minutes" ? "num" : undefined}>{text(r)[i]}</td>)}</tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {pages > 1 ? (
                <div className="pager">
                  <button type="button" className="chip" disabled={at <= 1} onClick={() => set({ p: at - 1 <= 1 ? null : String(at - 1) })}>Pichhla</button>
                  <span>Safha {at} of {pages}</span>
                  <button type="button" className="chip" disabled={at >= pages} onClick={() => set({ p: String(at + 1) })}>Agla</button>
                </div>
              ) : null}
              <p className="src">Customer ke phone se aaya, sirf parhne ke liye. Galti theek karna customer ki ijazat se hoga (hissa 4).</p>
            </>
          );
        }}
      </Region>
    </div>
  );
}
