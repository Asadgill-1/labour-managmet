"use client";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useMemo } from "react";
import { CountBars, MonthBars, showMonth } from "@/components/charts";
import { Shell } from "@/components/Shell";
import { Fresh, Region } from "@/components/ui";
import { ago, dubaiDay, rangeOf, showTime, type RangeKey } from "@/lib/dates";
import { showFils, signedFils } from "@/lib/money";
import type { AccountRow, AuditRow, Overview, Settings } from "@/lib/types";
import { useRpc } from "@/lib/use-rpc";
import { readQuery, writeQuery } from "@/lib/url";
import { actionWord, coversWord, months, planShort } from "@/lib/words";

const defaults = { r: "30d", from: "", to: "", test: false, compare: true };
const ranges: { key: RangeKey; label: string }[] = [
  { key: "aaj", label: "Aaj" },
  { key: "7d", label: "7 din" },
  { key: "30d", label: "30 din" },
  { key: "3m", label: "3 mahine" },
  { key: "12m", label: "12 mahine" },
  { key: "apni", label: "Apni tareekh" },
];

export default function OverviewPage() {
  return <Shell><Suspense><OverviewBody /></Suspense></Shell>;
}

function delta(now: number, before: number, money: boolean): string {
  const d = now - before;
  if (d === 0) return "pichhle jitna";
  const n = money ? showFils(Math.abs(d)) : String(Math.abs(d));
  return `${d > 0 ? "+" : "-"}${n} pichhle se`;
}

function OverviewBody() {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  const q = readQuery(params, defaults);
  const set = (next: Partial<typeof defaults>) => router.replace(path + writeQuery({ ...q, ...next }, defaults), { scroll: false });
  // The range is worked out once per URL, so the page does not ask again every render.
  const range = useMemo(() => rangeOf(q.r as RangeKey, new Date(), q.from, q.to), [q.r, q.from, q.to]);
  const now = useRpc<Overview>("admin_overview", { p_from: range.from, p_to: range.to, p_include_test: q.test });
  const before = useRpc<Overview>("admin_overview", { p_from: range.before.from, p_to: range.before.to, p_include_test: q.test }, !q.compare);
  const accounts = useRpc<AccountRow[]>("admin_accounts", { p_include_test: q.test });
  const month = useMemo(() => rangeOf("30d"), []);
  const audit = useRpc<AuditRow[]>("admin_audit", { p_from: month.from, p_to: month.to });
  const settings = useRpc<Settings>("admin_settings", {});
  const b = q.compare ? before.data : null;

  return (
    <main className="sheet-page">
      <div className="range">
        <div className="cap">
          <div className="seg" role="group" aria-label="Waqt">
            {ranges.map((r) => <button key={r.key} type="button" aria-pressed={q.r === r.key} onClick={() => set({ r: r.key })}>{r.label}</button>)}
          </div>
          {q.r === "apni" ? (
            <>
              <label className="switch">Se<input type="date" value={q.from} onChange={(e) => set({ from: e.target.value })} /></label>
              <label className="switch">Tak<input type="date" value={q.to} onChange={(e) => set({ to: e.target.value })} /></label>
            </>
          ) : null}
          <label className="switch"><input type="checkbox" checked={q.compare} onChange={(e) => set({ compare: e.target.checked })} /> Pichhle itne hi waqt se muqabla</label>
          <label className="switch"><input type="checkbox" checked={!q.test} onChange={(e) => set({ test: !e.target.checked })} /> Test accounts chhupayein</label>
          <Fresh at={now.fetchedAt} note="Offline phones ka data der se aata hai." />
        </div>
      </div>

      <Region load={now} lines={2}>
        {(o) => (
          <dl className="band">
            <div className="cap">
              <div className="fig"><dt>Mahana kamai (MRR)</dt><dd>AED {showFils(o.mrr_fils)}<small>{b ? delta(o.mrr_fils, b.mrr_fils, true) : "aaj ke paid plans se"}</small></dd></div>
              <div className="fig"><dt>Bank mein aaye</dt><dd>AED {showFils(o.cash_fils)}<small>{b ? delta(o.cash_fils, b.cash_fils, true) : "is waqt mein, refund ghata kar"}</small></dd></div>
              <div className="fig"><dt>Paid accounts</dt><dd>{o.accounts.paying}<small>{o.accounts.held ? `${o.accounts.held} ruke hue` : `${o.accounts.ended} ka plan khatam`}</small></dd></div>
              <div className="fig"><dt>Trial par</dt><dd>{o.accounts.trial}<small>{o.today.trials_ending.length} agle 5 din mein khatam</small></dd></div>
              <div className="fig"><dt>Trial se paid</dt><dd>{o.trial_to_paid.started ? `${Math.round((o.trial_to_paid.paid / o.trial_to_paid.started) * 100)}%` : "-"}<small>is waqt shuru hue {o.trial_to_paid.started} trial mein se {o.trial_to_paid.paid}</small></dd></div>
              <div className="fig"><dt>Slips intezar mein</dt><dd>{o.slips_waiting}<small>{o.today.slips.filter((s) => !s.file_arrived).length} ki file nahin pohanchi</small></dd></div>
            </div>
          </dl>
        )}
      </Region>

      <div className="cap page">
        <Region load={now}>
          {(o) => (
            <>
              <div className="grid2">
                <section>
                  <div className="section-head"><h2>Aaj ke kaam</h2><span>{todayCount(o)} kaam</span></div>
                  <Today o={o} />
                </section>
                <section>
                  <div className="section-head"><h2>Plan kis ke paas</h2><span>aaj, {o.accounts.total} accounts</span></div>
                  <CountBars label="Har plan par kitne accounts" rows={planMix(o)} />
                  <p className="src">Cloud add-on: {o.addon_accounts} {o.addon_accounts === 1 ? "account" : "accounts"}. Zariya: har account ka aaj ka period.</p>
                </section>
              </div>

              <div className="grid2 even">
                <section>
                  <div className="section-head"><h2>Aap ki kamai, har mahina</h2><span>12 mahine, AED</span></div>
                  <MonthBars label="Har mahine bank mein aaye paise, refund ghata kar" rows={o.cash_by_month.map((m) => ({ month: m.month, fils: m.cash_fils }))} />
                  <p className="src">Zariya: accept ki hui slips, bank mein aane ki tareekh se, refund ghata kar. Gehra bar abhi chalta mahina hai.</p>
                </section>
                <section>
                  <div className="section-head"><h2>MRR ka hisaab, {showMonth(o.mrr_bridge.month)}</h2><span>AED</span></div>
                  <table>
                    <tbody>
                      <tr><td>Mahine ke shuru mein</td><td className="num">{showFils(o.mrr_bridge.opening)}</td></tr>
                      <tr><td>Naye accounts</td><td className="num">{signedFils(o.mrr_bridge.new)}</td></tr>
                      <tr><td>Bara plan ya add-on</td><td className="num">{signedFils(o.mrr_bridge.expansion)}</td></tr>
                      <tr><td>Wapas aaye</td><td className="num">{signedFils(o.mrr_bridge.reactivation)}</td></tr>
                      <tr><td>Chhota plan</td><td className={`num${o.mrr_bridge.contraction ? " late" : ""}`}>{signedFils(o.mrr_bridge.contraction, -1)}</td></tr>
                      <tr><td>Chhor gaye</td><td className={`num${o.mrr_bridge.churn ? " late" : ""}`}>{signedFils(o.mrr_bridge.churn, -1)}</td></tr>
                      <tr className="total-row"><td>{o.mrr_bridge.month === dubaiDay(new Date()).slice(0, 7) + "-01" ? "Abhi tak" : "Mahine ke aakhir mein"}</td><td className="num">{showFils(o.mrr_bridge.closing)}</td></tr>
                    </tbody>
                  </table>
                  <p className="src">Har paid account ka mahana plan aur add-on. Advance mein diye kai mahine ek mahine ki kamai nahin gine jate (MET-02).</p>
                </section>
              </div>

              <div className="grid2 even">
                <section>
                  <div className="section-head"><h2>Haal ki harkat</h2><span>sab accounts, 30 din</span></div>
                  <Region load={audit} isEmpty={() => recent(o, audit.data ?? [], accounts.data ?? []).length === 0} empty={{ title: "Koi harkat nahin", body: "Naya account, slip ya aap ka koi kaam yahan dikhega." }}>
                    {(rows) => (
                      <ul className="ledger">
                        {recent(o, rows, accounts.data ?? []).map((e, i) => <li key={i}><span className="what">{e.what}</span><span className="why">{e.why}</span></li>)}
                      </ul>
                    )}
                  </Region>
                </section>
                <section>
                  <div className="section-head"><h2>Aap ka apna nafa, {showMonth(o.mrr_bridge.month)}</h2><span>kamai minus platform ke kharche</span></div>
                  <OwnProfit o={o} settings={settings.data} />
                </section>
              </div>
            </>
          )}
        </Region>
      </div>
    </main>
  );
}

function todayCount(o: Overview) {
  return o.today.slips.length + o.today.over_limit.length + (o.today.trials_ending.length ? 1 : 0) + (o.today.offline.length ? 1 : 0);
}

function Today({ o }: { o: Overview }) {
  if (todayCount(o) === 0) {
    return <div className="empty"><b>Aaj koi kaam nahin</b><p>Nayi slip, had se upar account, khatam hota trial ya offline account yahan aayega.</p></div>;
  }
  const names = (rows: AccountRow[]) => rows.slice(0, 4).map((r) => r.name).join(", ") + (rows.length > 4 ? `, aur ${rows.length - 4}` : "");
  return (
    <ul className="ledger">
      {o.today.slips.map((s) => (
        <li key={s.id}>
          <span className="what">{s.name} ki slip{s.file_arrived ? "" : ", file nahin pohanchi"}</span>
          <span className={`why${s.file_arrived ? "" : " late"}`}>{planShort(s.plan)}, {coversWord[s.covers]}, {months(s.months)}, AED {showFils(s.expected_fils)}, {ago(s.sent_at)}</span>
          <span className="act"><Link className={`btn${s.id === o.today.slips.find((x) => x.file_arrived)?.id ? " primary" : ""}`} href={`/subscriptions/?slip=${s.id}`}>{s.file_arrived ? "Slip dekhein" : "Refuse karein"}</Link></span>
        </li>
      ))}
      {o.today.over_limit.map((a) => (
        <li key={a.tenant_id}>
          <span className="what">{a.name} plan ki had se upar</span>
          <span className="why">{a.workers} active labour, {planShort(a.plan)} ki had {a.limits?.workers ?? "-"}; {a.clients} clients, had {a.limits?.clients ?? "-"}</span>
          <span className="act"><Link className="btn" href={`/account/?id=${a.tenant_id}`}>Account</Link></span>
        </li>
      ))}
      {o.today.trials_ending.length ? (
        <li>
          <span className="what">{o.today.trials_ending.length} trial 5 din mein khatam</span>
          <span className="why">{names(o.today.trials_ending)}</span>
          <span className="act"><Link className="btn" href="/accounts/?view=trial">List</Link></span>
        </li>
      ) : null}
      {o.today.offline.length ? (
        <li>
          <span className="what">{o.today.offline.length} accounts 7 din se offline</span>
          <span className="why">{o.today.offline.slice(0, 4).map((r) => `${r.name} ${ago(r.last_seen)}`).join(", ")}</span>
          <span className="act"><Link className="btn" href="/accounts/?view=offline">List</Link></span>
        </li>
      ) : null}
    </ul>
  );
}

function planMix(o: Overview) {
  const names: Record<string, string> = { trial: "Trial", small: "Small Company Plan", mid: "Mid Size Company Plan", large: "Large Size Company Plan", ended: "Plan khatam", held: "Ruke hue", none: "Plan kabhi nahin" };
  const order = ["trial", "small", "mid", "large", "held", "ended", "none"];
  const keys = [...order.filter((k) => k in o.plan_mix), ...Object.keys(o.plan_mix).filter((k) => !order.includes(k))];
  return keys.map((k) => ({ name: names[k] ?? k, n: o.plan_mix[k] }));
}

// The newest happenings across accounts: accounts made, slips sent and the owner's own actions.
function recent(o: Overview, audit: AuditRow[], accounts: AccountRow[]) {
  const since = Date.now() - 30 * 86_400_000;
  const rows = [
    ...accounts.filter((a) => Date.parse(a.created_at) > since).map((a) => ({ at: a.created_at, what: `${a.name} ka account bana`, why: `${showTime(a.created_at)}, ${a.email_confirmed ? "email confirm" : "email confirm baqi"}` })),
    ...o.today.slips.map((s) => ({ at: s.sent_at, what: `${s.name} ne slip bheji`, why: `${showTime(s.sent_at)}, AED ${showFils(s.expected_fils)}` })),
    ...audit.map((a) => ({ at: a.at_utc, what: `Aap: ${actionWord[a.action] ?? a.action}${a.tenant_name ? `, ${a.tenant_name}` : ""}`, why: `${showTime(a.at_utc)}, ${a.reason}` })),
  ];
  return rows.sort((x, y) => y.at.localeCompare(x.at)).slice(0, 8);
}

function OwnProfit({ o, settings }: { o: Overview; settings: Settings | null }) {
  const month = o.mrr_bridge.month;
  const cash = o.cash_by_month.find((m) => m.month === month)?.cash_fils ?? 0;
  const costs = settings?.costs.filter((c) => c.month === month) ?? [];
  return (
    <>
      <table>
        <tbody>
          <tr><td>Subscriptions se aaye</td><td className="num">{showFils(cash)}</td></tr>
          {costs.map((c) => <tr key={c.id}><td>{c.item}{c.note ? <span className="sub">{c.note}</span> : null}</td><td className="num">{signedFils(c.amount_fils, -1)}</td></tr>)}
          {settings && costs.length === 0 ? <tr><td>Platform ke kharche</td><td className="num soon">likha nahin</td></tr> : null}
          <tr className="total-row"><td>Nafa, jitne kharche likhe hain</td><td className="num">{showFils(cash - o.costs_fils)}</td></tr>
        </tbody>
      </table>
      <p className="src">Jo kharcha likha nahin, wo is mein nahin; sab likhne tak ise asal nafa na kahein (MET-04).</p>
      <div className="actions"><Link className="btn" href="/settings/#costs">Kharcha likhein</Link></div>
    </>
  );
}
