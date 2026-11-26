"use client";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Fragment, Suspense, useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { Shell } from "@/components/Shell";
import { Fresh, Region, Tag } from "@/components/ui";
import { SlipThumb } from "@/components/account/tabs";
import { slipChecks } from "@/lib/checks";
import { rpc } from "@/lib/cloud";
import { creditFor } from "@/lib/credit";
import { downloadCsv } from "@/lib/csv";
import { ago, daysLeft, dubaiDay, showDate, showTime } from "@/lib/dates";
import { readAed, showFils } from "@/lib/money";
import { slipLink } from "@/lib/periods";
import { checkCode, codeIsFresh } from "@/lib/session";
import type { Account, AccountRow, Plan, Settings, SlipFull } from "@/lib/types";
import { useRpc, type Load } from "@/lib/use-rpc";
import { readQuery, writeQuery } from "@/lib/url";
import { cloudSays, coversWord, months, planShort, slipStateTag, slipStateWord } from "@/lib/words";

const defaults = { tab: "intezar", slip: "", month: "", state: "", q: "" };
type Query = typeof defaults;
const tabs = [
  { key: "intezar", label: "Intezar" },
  { key: "sab", label: "Sab subscriptions" },
  { key: "khata", label: "Paison ka khata" },
  { key: "refund", label: "Refund" },
  { key: "tajdeed", label: "Tajdeed is hafte" },
];
// The banks customers in the UAE most often pay from; anything else is typed.
const banks = ["Emirates NBD", "ADCB", "FAB", "Dubai Islamic Bank", "Mashreq", "Emirates Islamic", "RAKBANK", "CBD", "ADIB", "Ajman Bank"];

export default function SubscriptionsPage() {
  return <Shell><Suspense><Subscriptions /></Suspense></Shell>;
}

function Subscriptions() {
  const router = useRouter();
  const path = usePathname();
  const q = readQuery(useSearchParams(), defaults);
  const set = (next: Partial<Query>) => router.replace(path + writeQuery({ ...q, ...next }, defaults), { scroll: false });
  // ponytail: every slip at once and the browser filters; ask by month past a few thousand slips.
  const until = useMemo(() => new Date(Date.now() + 86_400_000).toISOString(), []);
  const all = useRpc<SlipFull[]>("admin_slips", { p_from: "2026-01-01T00:00:00Z", p_to: until });
  const accounts = useRpc<AccountRow[]>("admin_accounts", { p_include_test: true }, q.tab !== "tajdeed");
  const settings = useRpc<Settings>("admin_settings", {});
  const waiting = (all.data ?? []).filter((s) => s.state === "waiting").sort((a, b) => a.submitted_at_utc.localeCompare(b.submitted_at_utc));
  // A slip opened from the Overview may be any tab's; a waiting one opens in the queue.
  const tab = q.slip && q.tab === "intezar" && all.data && !waiting.some((s) => s.id === q.slip) ? "sab" : q.tab;

  return (
    <main className="sheet-page">
      <div className="cap page">
        <div className="section-head"><h1 className="page-title">Subscriptions</h1><Fresh at={all.fetchedAt} /></div>
        <nav className="views" aria-label="Subscriptions">
          {tabs.map((t) => (
            <button key={t.key} type="button" aria-current={tab === t.key ? "page" : undefined} onClick={() => set({ tab: t.key, slip: "" })}>
              {t.label}{t.key === "intezar" && all.data ? <span className="count">{waiting.length}</span> : null}
            </button>
          ))}
        </nav>
        <Region load={all} lines={8}>
          {(slips) => (
            <>
              {tab === "intezar" ? <Queue waiting={waiting} slips={slips} plans={settings.data?.plans ?? []} chosen={q.slip} choose={(id) => set({ slip: id })} reload={all.reload} /> : null}
              {tab === "sab" ? <AllSlips slips={slips} q={q} set={set} /> : null}
              {tab === "khata" || tab === "refund" ? <Ledger slips={slips} q={q} set={set} refundsOnly={tab === "refund"} /> : null}
              {tab === "tajdeed" ? <Renewals load={accounts} /> : null}
            </>
          )}
        </Region>
      </div>
    </main>
  );
}

function Queue({ waiting, slips, plans, chosen, choose, reload }: { waiting: SlipFull[]; slips: SlipFull[]; plans: Plan[]; chosen: string; choose: (id: string) => void; reload: () => void }) {
  const [files, setFiles] = useState<Record<string, boolean>>({});
  const asked = useRef(new Set<string>());
  // Whether each waiting slip's file arrived: a link can be made only for a file that is there. Asked once per slip.
  useEffect(() => {
    for (const s of waiting) {
      if (asked.current.has(s.id)) continue;
      asked.current.add(s.id);
      slipLink(s.file_path).then((l) => setFiles((f) => ({ ...f, [s.id]: l !== null })));
    }
  }, [waiting]);
  if (waiting.length === 0) {
    return <div className="empty"><b>Koi slip intezar mein nahin</b><p>Nayi slip aate hi yahan aur Overview par dikhegi.</p></div>;
  }
  const slip = waiting.find((s) => s.id === chosen) ?? waiting[0];
  const next = () => {
    const i = waiting.findIndex((s) => s.id === slip.id);
    choose(waiting[(i + 1) % waiting.length].id);
  };
  return (
    <div className="queue">
      <div className="queue-list" role="list" aria-label="Intezar wali slips">
        {waiting.map((s) => (
          <button key={s.id} type="button" role="listitem" className="qitem" aria-current={s.id === slip.id ? "true" : undefined} onClick={() => choose(s.id)}>
            <span className="l1"><span>{s.tenant_name}</span><span>{showFils(s.expected_fils)}</span></span>
            <span className={`l2${files[s.id] === false ? " late" : ""}`}>{files[s.id] === false ? "File nahin pohanchi, " : ""}{planShort(s.plan_code)}, {coversWord[s.covers]}, {months(s.months)}, {ago(s.submitted_at_utc)}</span>
          </button>
        ))}
      </div>
      <Review key={slip.id} slip={slip} slips={slips} plans={plans} arrived={files[slip.id] ?? null} onDecided={() => { reload(); next(); }} skip={next} />
    </div>
  );
}

function Review({ slip, slips, plans, arrived, onDecided, skip }: { slip: SlipFull; slips: SlipFull[]; plans: Plan[]; arrived: boolean | null; onDecided: () => void; skip: () => void }) {
  const [link, setLink] = useState<string | null>(null);
  const [amount, setAmount] = useState("");
  const [bank, setBank] = useState("");
  const [otherBank, setOtherBank] = useState("");
  const [last4, setLast4] = useState("");
  const [reference, setReference] = useState("");
  const [received, setReceived] = useState(dubaiDay(new Date()));
  const [startNow, setStartNow] = useState(false);
  const [credit, setCredit] = useState("0");
  const [note, setNote] = useState("");
  const [refusing, setRefusing] = useState(false);
  const [why, setWhy] = useState("");
  const [askCode, setAskCode] = useState(false);
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const account = useRpc<Account>("admin_account", { p_tenant: slip.tenant_id });

  useEffect(() => { if (arrived) slipLink(slip.file_path).then(setLink); }, [arrived, slip.file_path]);
  useEffect(() => { if (startNow) codeIsFresh().then((f) => setAskCode(!f)); }, [startNow]);
  useEffect(() => {
    if (arrived !== false) return;
    setRefusing(true);
    setWhy((w) => w || "Slip ki file nahin pohanchi. App se nayi slip bhejein.");
  }, [arrived]);

  const seen = useMemo(() => new Set(slips.flatMap((s) => s.periods.map((p) => (p.bank_reference ?? "").trim().toUpperCase())).filter(Boolean)), [slips]);
  const typed = readAed(amount);
  const checks = slipChecks({ file_arrived: arrived, expected_fils: slip.expected_fils }, typed, reference, seen);
  const earlier = slips.filter((s) => s.tenant_id === slip.tenant_id && s.id !== slip.id);
  const pdf = slip.file_path.endsWith(".pdf");
  // What starting now leaves unused of the running plan, priced at the slip's plan (D-083).
  const running = (account.data?.periods ?? []).filter((p) => p.kind === "plan" && !p.revoked_at_utc && p.plan_code !== "trial" && (p.cut_at ?? p.ends_at_utc) > new Date().toISOString());
  const monthly = plans.find((p) => p.code === slip.plan_code && p.version === slip.plan_version)?.price_fils ?? 0;
  const suggestion = creditFor(running.map((p) => ({ ...p, ends_at_utc: p.cut_at ?? p.ends_at_utc })), monthly, new Date());

  async function accept(e: FormEvent) {
    e.preventDefault();
    const payerBank = bank === "Doosra" ? otherBank.trim() : bank;
    if (typed === null || typed <= 0) return setError("Bank mein aayi raqam AED mein likhein, jaise 199.00.");
    if (!reference.trim()) return setError("Bank reference likhein.");
    if (last4 && !/^\d{4}$/.test(last4)) return setError("Aakhri 4 hindse, sirf numbers.");
    const days = Number(credit);
    if (startNow && (!Number.isInteger(days) || days < 0 || days > 366)) return setError("Credit ke din 0 se 366 tak.");
    setBusy(true);
    setError(null);
    if (startNow && askCode) {
      const wrong = await checkCode(code.trim());
      if (wrong) { setBusy(false); return setError(wrong); }
    }
    const r = await rpc("admin_accept_slip", {
      p_slip: slip.id, p_amount_fils: typed, p_bank_reference: reference.trim(), p_received_on: received, p_payer_bank: payerBank || null,
      p_payer_last4: last4 || null, p_note: note.trim() || null, p_start_now: startNow, p_credit_days: startNow ? days : 0,
    });
    setBusy(false);
    if (r.error) return setError(cloudSays(r.error));
    onDecided();
  }

  async function refuse(e: FormEvent) {
    e.preventDefault();
    if (why.trim().length < 3) return setError("Customer ko wajah likhein, kam az kam 3 harf.");
    setBusy(true);
    const r = await rpc("admin_refuse_slip", { p_slip: slip.id, p_reason: why.trim() });
    setBusy(false);
    if (r.error) return setError(cloudSays(r.error));
    onDecided();
  }

  return (
    <div className="review">
      <div>
        <div className={`slot${link ? " has-file" : ""}`}>
          {link ? (pdf ? <object data={link} type="application/pdf" aria-label="Slip ki PDF" width="100%" height="100%"><a href={link} target="_blank" rel="noopener">PDF kholein</a></object>
            : <a href={link} target="_blank" rel="noopener" aria-label="Slip ki tasveer bari kholein"><img src={link} alt={`${slip.tenant_name} ki slip`} /></a>)
            : arrived === false ? "File nahin pohanchi: upload beech mein ruk gaya. Refuse karein; customer nayi slip bhejega." : "Slip ki file aa rahi hai."}
        </div>
        {link ? <p className="src">Tasveer par click se bari khulti hai. Link 60 second ka hai; dobara kholne par naya banta hai.</p> : null}
      </div>
      <div>
        <h2>{slip.tenant_name}</h2>
        <dl className="facts" style={{ marginTop: 12 }}>
          <dt>Plan</dt><dd>{slip.plan_name}, {months(slip.months)}, qeemat version {slip.plan_version}</dd>
          <dt>Kya cover</dt><dd>{coversWord[slip.covers]}</dd>
          <dt>Aani chahiye</dt><dd>AED {showFils(slip.expected_fils)}</dd>
          <dt>Kis ne bheji</dt><dd>{slip.sender_email ?? "-"}{slip.sender_role ? `, ${slip.sender_role}` : ""}</dd>
          <dt>Kab</dt><dd>{showTime(slip.submitted_at_utc)}</dd>
          <dt>Pichhli slips</dt><dd>{earlier.length ? earlier.map((s) => `${slipStateWord[s.state]} ${showDate(s.submitted_at_utc)}`).join(", ") : "Koi nahin, pehli dafa"}</dd>
          <dt>Account</dt><dd><Link href={`/account/?id=${slip.tenant_id}&tab=plan`}>Plan aur paise dekhein</Link></dd>
        </dl>
        <ul className="autocheck" aria-label="Khud jaanch">
          {checks.map((c, i) => <li key={i}><span className={c.ok === null ? "soon" : c.ok ? "ok" : "bad"}>{c.ok === null ? "Baqi" : c.ok ? "Theek" : "Dekhein"}</span>{c.text}</li>)}
        </ul>
        {refusing ? (
          <form onSubmit={refuse}>
            <label>Customer ko app mein ye wajah dikhegi<textarea rows={2} maxLength={300} value={why} onChange={(e) => setWhy(e.target.value)} placeholder="Raqam bank mein nahin aayi" required /></label>
            {error ? <p className="field-warn" role="alert">{error}</p> : null}
            <div className="actions">
              <button type="submit" className="danger" disabled={busy} aria-busy={busy}>Refuse karein</button>
              <button type="button" className="quiet" onClick={() => { setRefusing(false); setError(null); }}>Wapas</button>
            </div>
          </form>
        ) : (
          <form onSubmit={accept}>
            <p className="hint">Pehle apne bank mein raqam dekhein. Sirf screenshot saboot nahin.</p>
            <label>Bank mein kitni aayi (AED)<input inputMode="decimal" autoComplete="off" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder={`aani thi ${showFils(slip.expected_fils)}`} required /></label>
            <label>Bhejne wale ka bank
              <select value={bank} onChange={(e) => setBank(e.target.value)}>
                <option value="">Pata nahin</option>
                {banks.map((b) => <option key={b}>{b}</option>)}
                <option value="Doosra">Doosra</option>
              </select>
            </label>
            {bank === "Doosra" ? <label>Bank ka naam<input value={otherBank} maxLength={100} onChange={(e) => setOtherBank(e.target.value)} /></label> : null}
            <label>Bhejne wale account ke aakhri 4 hindse<input inputMode="numeric" maxLength={4} autoComplete="off" value={last4} onChange={(e) => setLast4(e.target.value)} />
              <span className="field-note">Poora number nahin rakha jata; wo slip ki tasveer mein hai (D-081).</span>
            </label>
            <label>Bank reference<input autoComplete="off" value={reference} onChange={(e) => setReference(e.target.value)} placeholder="FT..." required /></label>
            <label>Kis din bank mein aayi<input type="date" value={received} onChange={(e) => setReceived(e.target.value)} required /></label>
            {slip.covers !== "addon" ? (
              <fieldset className="choices">
                <legend>Plan kab se</legend>
                <label className="choice"><input type="radio" name="start" checked={!startNow} onChange={() => setStartNow(false)} /><span><b>Chalte plan ke baad</b><span>Paid plan chal raha ho to us ke khatam hone par, warna abhi se.</span></span></label>
                <label className="choice"><input type="radio" name="start" checked={startNow} onChange={() => { setStartNow(true); setCredit(String(suggestion.days)); }} /><span><b>Abhi se</b><span>Chalta paid plan abhi khatam; bacha hua hissa naye plan par din ban kar.</span></span></label>
              </fieldset>
            ) : null}
            {startNow ? (
              <label>Bache hue hisse ke din, naye plan ke baad
                <input inputMode="numeric" value={credit} onChange={(e) => setCredit(e.target.value)} />
                <span className="field-note">Tajweez: {suggestion.days} din (bacha AED {showFils(suggestion.fils)}). 0 likhein to koi credit nahin.</span>
              </label>
            ) : null}
            {startNow && askCode ? <label>MFA code dobara<input inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={code} onChange={(e) => setCode(e.target.value)} placeholder="6 hindse" required /></label> : null}
            <label>Note, sirf aap ke liye<textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} /></label>
            {error ? <p className="field-warn" role="alert">{error}</p> : null}
            <div className="actions">
              <button type="submit" className="primary" disabled={busy || arrived === false} aria-busy={busy}>{busy ? "Ho raha hai" : "Accept karein"}</button>
              <button type="button" onClick={() => { setRefusing(true); setError(null); }}>Refuse karein</button>
              <button type="button" className="quiet" onClick={skip}>Chhorein, agli</button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}

const monthOf = (d: string) => d.slice(0, 7);
const monthLabel = (m: string) => new Intl.DateTimeFormat("en-GB", { month: "short", year: "numeric", timeZone: "UTC" }).format(new Date(`${m}-01T00:00:00Z`));

function AllSlips({ slips, q, set }: { slips: SlipFull[]; q: Query; set: (n: Partial<Query>) => void }) {
  const monthsSeen = [...new Set(slips.map((s) => monthOf(dubaiDay(s.submitted_at_utc))))].sort().reverse();
  const text = q.q.trim().toLowerCase();
  const shown = slips.filter((s) =>
    (!q.month || monthOf(dubaiDay(s.submitted_at_utc)) === q.month) && (!q.state || s.state === q.state) &&
    (!text || s.tenant_name.toLowerCase().includes(text) || (s.sender_email ?? "").toLowerCase().includes(text) ||
      s.periods.some((p) => (p.bank_reference ?? "").toLowerCase().includes(text)) || (s.payer_last4 ?? "") === text));
  const got = (s: SlipFull) => s.periods.reduce((t, p) => t + p.amount_fils, 0);
  const open = slips.find((s) => s.id === q.slip);
  return (
    <>
      <div className="filters" role="group" aria-label="Filters">
        <input type="search" aria-label="Account, email, reference ya aakhri 4 hindse" placeholder="Account, email, reference ya aakhri 4 hindse" defaultValue={q.q} onChange={(e) => set({ q: e.target.value })} />
        <select aria-label="Mahina" value={q.month} onChange={(e) => set({ month: e.target.value })}>
          <option value="">Waqt: sab</option>
          {monthsSeen.map((m) => <option key={m} value={m}>{monthLabel(m)}</option>)}
        </select>
        <select aria-label="Haalat" value={q.state} onChange={(e) => set({ state: e.target.value })}>
          <option value="">Haalat: sab</option>
          <option value="waiting">Intezar</option><option value="accepted">Accept</option><option value="refused">Refuse</option>
        </select>
        <span className="spacer" />
        <button type="button" className="chip" onClick={() => downloadCsv(`slips-${dubaiDay(new Date())}.csv`, slipRows(shown))}>CSV nikalein</button>
      </div>
      {shown.length === 0 ? <div className="empty"><b>Is filter mein koi slip nahin</b><p>Waqt ya haalat badlein.</p></div> : (
        <div className="table-wrap">
          <table>
            <thead><tr><th>Slip</th><th>Account</th><th>Kis ne bheji</th><th>Subscription</th><th>Period</th><th className="num">Aani thi</th><th className="num">Aayi</th><th>Bhejne wala bank</th><th>Reference</th><th>Bank mein</th><th>Haalat</th><th>Faisla</th></tr></thead>
            <tbody>
              {shown.map((s) => {
                const plan = s.periods.find((p) => p.kind === "plan") ?? s.periods[0];
                const differs = s.state === "accepted" && got(s) !== s.expected_fils;
                return (
                  <tr key={s.id} className={`open-row${s.id === q.slip ? " chosen" : ""}`} onClick={() => set({ slip: s.id })}>
                    <td onClick={(e) => e.stopPropagation()}><SlipThumb path={s.file_path} /></td>
                    <td><Link href={`/account/?id=${s.tenant_id}`} onClick={(e) => e.stopPropagation()}>{s.tenant_name}</Link></td>
                    <td>{s.sender_email ?? "-"}<span className="sub">{s.sender_role ?? ""}</span></td>
                    <td>{planShort(s.plan_code)}, {coversWord[s.covers]}<span className="sub">{months(s.months)}, version {s.plan_version}</span></td>
                    <td>{plan ? `${showDate(plan.starts_at_utc)} se ${showDate(plan.ends_at_utc)}` : "-"}</td>
                    <td className="num">{showFils(s.expected_fils)}</td>
                    <td className={`num${differs ? " late" : ""}`}>{s.state === "accepted" ? showFils(got(s)) : "-"}</td>
                    <td>{s.payer_bank ?? "-"}{s.payer_last4 ? <span className="sub">account aakhri {s.payer_last4}</span> : null}</td>
                    <td>{plan?.bank_reference ?? "-"}</td>
                    <td>{plan?.received_on ? showDate(plan.received_on) : "-"}</td>
                    <td><Tag kind={slipStateTag[s.state]}>{slipStateWord[s.state]}</Tag></td>
                    <td className="wrap">{s.decided_at_utc ? showTime(s.decided_at_utc) : "-"}{s.refuse_reason ? <span className="sub">{s.refuse_reason}</span> : null}</td>
                  </tr>
                );
              })}
              <tr className="total-row">
                <td colSpan={5}>{shown.length} slips</td>
                <td className="num">{showFils(shown.reduce((t, s) => t + s.expected_fils, 0))}</td>
                <td className="num">{showFils(shown.filter((s) => s.state === "accepted").reduce((t, s) => t + got(s), 0))}</td>
                <td colSpan={5}>{(["accepted", "waiting", "refused"] as const).map((k) => `${shown.filter((s) => s.state === k).length} ${slipStateWord[k].toLowerCase()}`).join(", ")}</td>
              </tr>
            </tbody>
          </table>
        </div>
      )}
      {open ? <SlipOpen s={open} /> : <p className="src">Kisi line par click se poori slip khulti hai. Bhejne wale ka poora account number nahin rakha jata, sirf bank aur aakhri 4 hindse.</p>}
    </>
  );
}

function SlipOpen({ s }: { s: SlipFull }) {
  const [link, setLink] = useState<string | null | undefined>(undefined);
  useEffect(() => { setLink(undefined); slipLink(s.file_path).then(setLink); }, [s.file_path]);
  const plan = s.periods.find((p) => p.kind === "plan") ?? s.periods[0];
  return (
    <div className="grid2" style={{ marginTop: 8 }}>
      <section>
        <div className="section-head"><h2>{s.tenant_name}, {showDate(s.submitted_at_utc)}</h2><span><Tag kind={slipStateTag[s.state]}>{slipStateWord[s.state]}</Tag></span></div>
        <dl className="facts">
          <dt>Kis ne bheji</dt><dd>{s.sender_email ?? "-"}{s.sender_role ? `, ${s.sender_role}` : ""}</dd>
          <dt>Subscription</dt><dd>{s.plan_name}, {coversWord[s.covers]}, {months(s.months)}, qeemat version {s.plan_version}</dd>
          {s.periods.map((p) => <Fragment key={p.id}><dt>Period, {p.kind === "plan" ? "plan" : "add-on"}</dt><dd>{showDate(p.starts_at_utc)} se {showDate(p.ends_at_utc)}, AED {showFils(p.amount_fils)}{p.revoked_at_utc ? `, wapas liya: ${p.revoke_reason}` : ""}</dd></Fragment>)}
          <dt>Aani thi</dt><dd>AED {showFils(s.expected_fils)}</dd>
          <dt>Bank mein</dt><dd>{plan?.received_on ? showDate(plan.received_on) : "-"}, reference {plan?.bank_reference ?? "-"}</dd>
          <dt>Bhejne wala</dt><dd>{s.payer_bank ?? "-"}{s.payer_last4 ? `, account aakhri ${s.payer_last4}` : ""}</dd>
          <dt>Faisla</dt><dd>{s.decided_at_utc ? `${slipStateWord[s.state]}, ${showTime(s.decided_at_utc)}` : "Intezar"}{s.refuse_reason ? `: ${s.refuse_reason}` : ""}</dd>
          {plan?.note ? <><dt>Aap ka note</dt><dd>{plan.note}</dd></> : null}
          {s.money_entries.map((m) => <Fragment key={m.id}><dt>{m.kind === "refund" ? "Refund" : "Darusti"}, {showDate(m.on_date)}</dt><dd>{m.kind === "refund" ? `AED ${showFils(m.amount_fils)}` : `${m.field}: ${m.value}`}; {m.reason}</dd></Fragment>)}
        </dl>
        <div className="actions">
          {link ? <a className="btn" href={link} target="_blank" rel="noopener">Slip download</a> : null}
          <Link className="btn" href={`/account/?id=${s.tenant_id}&tab=plan`}>Refund ya darusti</Link>
        </div>
      </section>
      <section>
        <div className="section-head"><h2>Slip ki file</h2></div>
        <div className={`slot${link ? " has-file" : ""}`} style={{ aspectRatio: "auto", minHeight: 320 }}>
          {link ? (s.file_path.endsWith(".pdf") ? <object data={link} type="application/pdf" aria-label="Slip ki PDF" width="100%" height="480"><a href={link}>PDF kholein</a></object> : <img src={link} alt={`${s.tenant_name} ki slip`} />)
            : link === null ? "File nahin mili." : "File aa rahi hai."}
        </div>
      </section>
    </div>
  );
}

function slipRows(slips: SlipFull[]): string[][] {
  return [
    ["Account", "Bheji", "Kis ne", "Plan", "Kya cover", "Mahine", "Aani thi (AED)", "Aayi (AED)", "Bank", "Aakhri 4", "Reference", "Bank mein", "Haalat", "Faisla", "Wajah"],
    ...slips.map((s) => {
      const plan = s.periods.find((p) => p.kind === "plan") ?? s.periods[0];
      return [s.tenant_name, dubaiDay(s.submitted_at_utc), s.sender_email ?? "", planShort(s.plan_code), coversWord[s.covers], String(s.months), showFils(s.expected_fils),
        s.state === "accepted" ? showFils(s.periods.reduce((t, p) => t + p.amount_fils, 0)) : "", s.payer_bank ?? "", s.payer_last4 ?? "", plan?.bank_reference ?? "",
        plan?.received_on ?? "", slipStateWord[s.state], s.decided_at_utc ? dubaiDay(s.decided_at_utc) : "", s.refuse_reason ?? ""];
    }),
  ];
}

type Line = { day: string; tenant: string; tenantId: string; what: string; reference: string; inFils: number; outFils: number; note: string };

// For the accountant: every payment that reached the bank, every refund and every correction, newest first.
function Ledger({ slips, q, set, refundsOnly }: { slips: SlipFull[]; q: Query; set: (n: Partial<Query>) => void; refundsOnly: boolean }) {
  const lines: Line[] = [];
  for (const s of slips) {
    if (!refundsOnly) {
      for (const p of s.periods.filter((x) => x.source === "slip")) {
        lines.push({ day: p.received_on ?? dubaiDay(p.created_at_utc), tenant: s.tenant_name, tenantId: s.tenant_id, what: `${p.kind === "plan" ? "Plan" : "Add-on"}, ${planShort(p.plan_code)}, ${months(s.months)}`, reference: p.bank_reference ?? "", inFils: p.amount_fils, outFils: 0, note: p.revoked_at_utc ? `wapas liya: ${p.revoke_reason}` : "" });
      }
    }
    for (const m of s.money_entries.filter((x) => !refundsOnly || x.kind === "refund")) {
      lines.push({ day: m.on_date, tenant: s.tenant_name, tenantId: s.tenant_id, what: m.kind === "refund" ? "Refund" : `Darusti: ${m.field} ab ${m.field === "amount_fils" ? showFils(Number(m.value)) : m.value}`, reference: m.reference ?? "", inFils: 0, outFils: m.amount_fils, note: m.reason });
    }
  }
  const monthsSeen = [...new Set(lines.map((l) => monthOf(l.day)))].sort().reverse();
  const shown = lines.filter((l) => !q.month || monthOf(l.day) === q.month).sort((a, b) => b.day.localeCompare(a.day));
  const totalIn = shown.reduce((t, l) => t + l.inFils, 0);
  const totalOut = shown.reduce((t, l) => t + l.outFils, 0);
  return (
    <>
      <div className="filters" role="group" aria-label="Filters">
        <select aria-label="Mahina" value={q.month} onChange={(e) => set({ month: e.target.value })}>
          <option value="">Waqt: sab</option>
          {monthsSeen.map((m) => <option key={m} value={m}>{monthLabel(m)}</option>)}
        </select>
        <span className="spacer" />
        <button type="button" className="chip" onClick={() => downloadCsv(`${refundsOnly ? "refunds" : "khata"}-${q.month || "sab"}.csv`, [
          ["Tareekh", "Account", "Kya", "Reference", "Aaya (AED)", "Wapas (AED)", "Note"],
          ...shown.map((l) => [l.day, l.tenant, l.what, l.reference, showFils(l.inFils), showFils(l.outFils), l.note]),
        ])}>CSV nikalein, Excel ke liye</button>
      </div>
      {shown.length === 0 ? <div className="empty"><b>{refundsOnly ? "Koi refund nahin" : "Khata khali hai"}</b><p>{refundsOnly ? "Refund account ke Plan aur paise tab se likha jata hai." : "Accept hui slip ki raqam yahan aati hai."}</p></div> : (
        <div className="table-wrap">
          <table>
            <thead><tr><th>Tareekh</th><th>Account</th><th>Kya</th><th>Reference</th><th className="num">Aaya</th><th className="num">Wapas</th><th>Note</th></tr></thead>
            <tbody>
              {shown.map((l, i) => (
                <tr key={i}>
                  <td>{showDate(l.day)}</td><td><Link href={`/account/?id=${l.tenantId}&tab=plan`}>{l.tenant}</Link></td><td className="wrap">{l.what}</td><td>{l.reference || "-"}</td>
                  <td className="num">{showFils(l.inFils)}</td><td className={`num${l.outFils ? " late" : ""}`}>{showFils(l.outFils)}</td><td className="wrap">{l.note}</td>
                </tr>
              ))}
              <tr className="total-row"><td colSpan={4}>Kul, {shown.length} lines; khalis AED {showFils(totalIn - totalOut)}</td><td className="num">{showFils(totalIn)}</td><td className="num">{showFils(totalOut)}</td><td /></tr>
            </tbody>
          </table>
        </div>
      )}
      <p className="src">Aaya bank mein aane ki tareekh se, refund jis din wapas kiya. Darusti purani line nahin badalti, sirf sahi value batati hai (BILL-04).</p>
    </>
  );
}

function Renewals({ load }: { load: Load<AccountRow[]> }) {
  return (
    <Region load={load} isEmpty={(rows) => due(rows).length === 0} empty={{ title: "Is hafte koi tajdeed nahin", body: "Jis paid account ka plan 7 din mein khatam ho aur slip na aayi ho, yahan aayega." }}>
      {(rows) => (
        <ul className="ledger" style={{ marginTop: 16 }}>
          {due(rows).map((a) => (
            <li key={a.tenant_id}>
              <span className="what">{a.name}</span>
              <span className="why">{planShort(a.plan)}, {showDate(a.plan_ends_at)} ko khatam, {daysLeft(a.plan_ends_at!)} din; {a.owner_email ?? ""}</span>
              <span className="act"><Link className="btn" href={`/account/?id=${a.tenant_id}&tab=plan`}>Account</Link></span>
            </li>
          ))}
        </ul>
      )}
    </Region>
  );
}

const due = (rows: AccountRow[]) =>
  rows.filter((a) => a.state === "paid" && a.slips_waiting === 0 && a.plan_ends_at && daysLeft(a.plan_ends_at) <= 7)
    .sort((x, y) => (x.plan_ends_at ?? "").localeCompare(y.plan_ends_at ?? ""));
