"use client";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useMemo } from "react";
import { MonthTable, SheetTable } from "@/components/account/book";
import { MonthBars, showMonth } from "@/components/charts";
import { Shell } from "@/components/Shell";
import { Fresh, Region } from "@/components/ui";
import { addMonth, addMonths } from "@/lib/book";
import { downloadCsv } from "@/lib/csv";
import { ago, dubaiDay } from "@/lib/dates";
import { showFils } from "@/lib/money";
import type { Business } from "@/lib/types";
import { useRpc } from "@/lib/use-rpc";
import { readQuery, writeQuery } from "@/lib/url";

const defaults = { r: "12m", from: "", to: "", test: false };
const ranges = [
  { key: "1m", label: "Is mahina", back: 0 },
  { key: "3m", label: "3 mahine", back: 2 },
  { key: "12m", label: "12 mahine", back: 11 },
  { key: "apni", label: "Apne mahine", back: 0 },
] as const;

export default function BusinessPage() {
  return <Shell><Suspense><BusinessBody /></Suspense></Shell>;
}

/** Every customer's books added up (mockup 5, MET-01): their business, kept apart from the platform's own income. */
function BusinessBody() {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  const q = readQuery(params, defaults);
  const set = (next: Partial<typeof defaults>) => router.replace(path + writeQuery({ ...q, ...next }, defaults), { scroll: false });
  const range = useMemo(() => {
    const now = dubaiDay(new Date()).slice(0, 7);
    if (q.r === "apni" && /^\d{4}-\d{2}$/.test(q.from) && /^\d{4}-\d{2}$/.test(q.to) && q.from <= q.to) return { from: q.from, to: q.to };
    const back = ranges.find((r) => r.key === q.r)?.back ?? 11;
    return { from: addMonth(now, -back), to: now };
  }, [q.r, q.from, q.to]);
  const load = useRpc<Business>("admin_business", { p_from: range.from, p_to: range.to, p_include_test: q.test });
  const span = range.from === range.to ? showMonth(range.from) : `${showMonth(range.from)} se ${showMonth(range.to)}`;

  return (
    <main className="sheet-page">
      <div className="range">
        <div className="cap">
          <div className="seg" role="group" aria-label="Waqt">
            {ranges.map((r) => <button key={r.key} type="button" aria-pressed={q.r === r.key} onClick={() => set({ r: r.key })}>{r.label}</button>)}
          </div>
          {q.r === "apni" ? (
            <>
              <label className="switch">Se<input type="month" value={q.from} onChange={(e) => set({ from: e.target.value })} /></label>
              <label className="switch">Tak<input type="month" value={q.to} onChange={(e) => set({ to: e.target.value })} /></label>
            </>
          ) : null}
          <label className="switch"><input type="checkbox" checked={!q.test} onChange={(e) => set({ test: !e.target.checked })} /> Test accounts chhupayein</label>
          <Fresh at={load.fetchedAt} note="Offline phone ka mahina adhoora ho sakta hai." />
        </div>
      </div>

      <Region load={load} lines={2}>
        {(b) => {
          const f = addMonths(b.months);
          return (
            <dl className="band">
              <div className="cap">
                <div className="fig"><dt>Kul labour</dt><dd>{b.workers}<small>{b.with_books} accounts mein, aaj</small></dd></div>
                <div className="fig"><dt>Customers ka bill</dt><dd>AED {showFils(f.bill)}<small>hazri se, VAT ke baghair</small></dd></div>
                <div className="fig"><dt>Invoices</dt><dd>{f.invoices}<small>AED {showFils(f.invoiced - f.credited)}, VAT ke baghair</small></dd></div>
                <div className="fig"><dt>Hazri ke din</dt><dd>{f.days.toLocaleString("en-US")}<small>{span}</small></dd></div>
                <div className="fig"><dt>Labour ki mazdoori</dt><dd>AED {showFils(f.wages)}<small>{span}</small></dd></div>
                <div className="fig"><dt>Andazan nafa</dt><dd>AED {showFils(f.estimate)}<small>sab accounts, audit shuda nahin</small></dd></div>
              </div>
            </dl>
          );
        }}
      </Region>

      <div className="cap page">
        <Region
          load={load}
          isEmpty={(b) => b.with_books === 0}
          empty={{ title: "Abhi kisi account ki kitab nahin aayi", body: "Jo customer app mein ijazat deta hai, us ki kitab us ka phone online hote hi yahan aati hai." }}
        >
          {(b) => {
            const inProfit = b.accounts.filter((a) => a.estimate > 0).length;
            const inLoss = b.accounts.filter((a) => a.estimate < 0).length;
            return (
              <>
                <p className="src">Ye customers ka business hai, aap ki kamai nahin; aap ki kamai Overview par hai. Har account ki apni &ldquo;Malik ki sheet&rdquo; ka jod, us ke phone ke data se.</p>
                <div className="grid2 even">
                  <section>
                    <div className="section-head"><h2>Customers ka bill, har mahina</h2><span>{span}, AED</span></div>
                    {b.months.length > 1 ? <MonthBars label="Har mahine sab customers ka kaam ka bill" rows={b.months.map((m) => ({ month: m.month, fils: m.bill }))} /> : null}
                    <MonthTable months={b.months} />
                    <p className="src">Zariya: har account ke mahine ka khulasa, phone se cloud par. Gehra bar abhi chalta mahina hai.</p>
                  </section>
                  <section>
                    <div className="section-head"><h2>Sab accounts ka nafa aur nuqsan</h2><span>{span}, AED</span></div>
                    <SheetTable months={b.months} />
                    <div className="section-head"><h2>Accounts</h2><span>{b.accounts_total} kul</span></div>
                    <table>
                      <tbody>
                        <tr><td>Ijazat di</td><td className="num">{b.consented}</td></tr>
                        <tr><td>Kitab cloud par aayi</td><td className="num">{b.with_books}</td></tr>
                        <tr><td>Nafa mein</td><td className="num">{inProfit}</td></tr>
                        <tr><td>Nuqsan mein</td><td className={`num${inLoss ? " late" : ""}`}>{inLoss}</td></tr>
                      </tbody>
                    </table>
                  </section>
                </div>

                <section>
                  <div className="section-head">
                    <h2>Sab se bare accounts</h2>
                    <span>{span}, bill ke hisaab se</span>
                    <button
                      type="button"
                      className="chip"
                      onClick={() => downloadCsv(`business-${range.from}-${range.to}.csv`, [
                        ["Account", "Labour", "Client companies", "Bill (AED)", "Mazdoori (AED)", "Andazan nafa (AED)", "Invoices (AED)", "Data aaya"],
                        ...b.accounts.map((a) => [a.name, String(a.workers), String(a.clients), showFils(a.bill), showFils(a.wages), showFils(a.estimate), showFils(a.invoiced), a.last_at ?? ""]),
                      ])}
                    >CSV nikalein</button>
                  </div>
                  <div className="table-wrap">
                    <table>
                      <thead><tr><th>Account</th><th className="num">Labour</th><th className="num">Companies</th><th className="num">Bill</th><th className="num">Mazdoori</th><th className="num">Andazan nafa</th><th>Data aaya</th></tr></thead>
                      <tbody>
                        {b.accounts.slice(0, 25).map((a) => (
                          <tr key={a.tenant_id}>
                            <td><Link href={`/account/?id=${a.tenant_id}`}>{a.name}</Link></td>
                            <td className="num">{a.workers}</td>
                            <td className="num">{a.clients}</td>
                            <td className="num">{showFils(a.bill)}</td>
                            <td className="num">{showFils(a.wages)}</td>
                            <td className={`num${a.estimate < 0 ? " late" : ""}`}>{showFils(a.estimate)}</td>
                            <td>{ago(a.last_at)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  <p className="src">Emirate ke hisaab se nahin: app mein company ka emirate likha nahin jata.</p>
                </section>
              </>
            );
          }}
        </Region>
      </div>
    </main>
  );
}
