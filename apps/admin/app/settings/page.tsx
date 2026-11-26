"use client";
import Link from "next/link";
import { useState } from "react";
import { showMonth } from "@/components/charts";
import { Shell } from "@/components/Shell";
import { ActionDialog, Fresh, Region } from "@/components/ui";
import { rpc } from "@/lib/cloud";
import { dubaiDay, showDate } from "@/lib/dates";
import { readAed, showFils } from "@/lib/money";
import type { Settings } from "@/lib/types";
import { useRpc } from "@/lib/use-rpc";

export default function SettingsPage() {
  return <Shell><SettingsBody /></Shell>;
}

const be = (n: number | null) => (n === null ? "be-had" : String(n));

function SettingsBody() {
  const load = useRpc<Settings>("admin_settings", {});
  const [open, setOpen] = useState<"bank" | "cost" | null>(null);
  return (
    <main className="sheet-page">
      <div className="cap page">
        <div className="section-head"><h1 className="page-title">Settings</h1><Fresh at={load.fetchedAt} /></div>
        <Region load={load} lines={8}>
          {(s) => (
            <>
              <div className="grid2 even">
                <section>
                  <div className="section-head"><h2>Dashboard ke log</h2><span>kirdar aur MFA</span></div>
                  <table>
                    <thead><tr><th>Kaun</th><th>Kirdar</th><th>MFA</th><th>Kab se</th></tr></thead>
                    <tbody>
                      {s.admins.map((a) => <tr key={a.user_id}><td>{a.email}</td><td>Malik</td><td className={a.totp ? "ok" : "bad"}>{a.totp ? "On" : "Nahin"}</td><td>{showDate(a.added_at)}</td></tr>)}
                      <tr><td className="soon">Baad mein</td><td>Finance, Support</td><td>-</td><td>jab kisi aur ko login chahiye (ADMIN-08)</td></tr>
                    </tbody>
                  </table>
                  <p className="src">Naya log sirf SQL editor se judta hai (RUNBOOK); dashboard kisi ko admin nahin bana sakta. MFA ke baghair koi andar nahin.</p>
                </section>
                <section>
                  <div className="section-head"><h2>Customers ko kya dikhta hai</h2><span>{s.platform.updated_at_utc ? `badla ${showDate(s.platform.updated_at_utc)}` : ""}</span></div>
                  <ul className="checks">
                    <li><span>Bank</span><span>{s.platform.bank_name ?? <span className="bad">likha nahin</span>}</span></li>
                    <li><span>Account number</span><span>{s.platform.account_number ? `aakhri hindse ${s.platform.account_number.slice(-4)}` : <span className="bad">likha nahin</span>}</span></li>
                    <li><span>IBAN</span><span>{s.platform.iban ? `aakhri hindse ${s.platform.iban.slice(-4)}` : <span className="bad">likha nahin</span>}</span></li>
                    <li><span>Account ka naam</span><span>{s.platform.account_holder ?? <span className="bad">likha nahin</span>}</span></li>
                    <li><span>Support ka rabta</span><span>{s.platform.support_contact ? "set hai" : <span className="bad">likha nahin</span>}</span></li>
                    <li><span>Trial</span><span>{s.platform.trial_days} din</span></li>
                  </ul>
                  <div className="actions"><button type="button" onClick={() => setOpen("bank")}>Badlein</button></div>
                  <p className="src">Ye app ke plan safhe par customer ko dikhte hain. Aap khud likhein; git mein kabhi nahin (AI-05).</p>
                </section>
              </div>

              <div className="section-head"><h2>Plans aur qeematein</h2><span>sirf dekhne ke liye; qeemat badalna naya version hai (D-074)</span></div>
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Plan</th><th>Version</th><th className="num">Mahana (AED)</th><th className="num">Add-on (AED)</th><th className="num">Labour</th><th className="num">Clients</th><th className="num">Manager</th><th className="num">Backup din</th><th>Bikta hai</th></tr></thead>
                  <tbody>
                    {s.plans.map((p) => (
                      <tr key={`${p.code}-${p.version}`}>
                        <td>{p.name}</td><td>{p.version}</td><td className="num">{showFils(p.price_fils)}</td><td className="num">{showFils(p.addon_price_fils)}</td>
                        <td className="num">{be(p.max_workers)}</td><td className="num">{be(p.max_clients)}</td><td className="num">{be(p.max_managers)}</td><td className="num">{p.backup_keep_days}</td><td>{p.on_sale ? "Haan" : "Nahin"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div className="grid2 even">
                <section id="costs">
                  <div className="section-head"><h2>Platform ke kharche</h2><span>Overview par aap ke apne nafe ke liye (MET-04)</span></div>
                  {s.costs.length === 0 ? <div className="empty"><b>Koi kharcha likha nahin</b><p>Supabase, domain, email service, Play account: jo kharcha likhenge, Overview us mahine ki kamai se ghatayega.</p></div> : (
                    <table>
                      <thead><tr><th>Mahina</th><th>Kya</th><th className="num">AED</th></tr></thead>
                      <tbody>{s.costs.map((c) => <tr key={c.id}><td>{showMonth(c.month)}</td><td>{c.item}{c.note ? <span className="sub">{c.note}</span> : null}</td><td className="num">{showFils(c.amount_fils)}</td></tr>)}</tbody>
                    </table>
                  )}
                  <div className="actions"><button type="button" className="primary" onClick={() => setOpen("cost")}>Kharcha likhein</button></div>
                </section>
                <section>
                  <div className="section-head"><h2>Test accounts</h2><span>{s.test_accounts.length} hisaab se bahar</span></div>
                  {s.test_accounts.length === 0 ? <p className="src">Koi nahin. Account ke Account tab se test bana sakte hain.</p> : (
                    <ul className="ledger">{s.test_accounts.map((t) => <li key={t.tenant_id}><span className="what"><Link href={`/account/?id=${t.tenant_id}&tab=account`}>{t.name}</Link></span></li>)}</ul>
                  )}
                </section>
              </div>
              {open === "bank" ? <BankDialog s={s} close={() => setOpen(null)} done={load.reload} /> : null}
              {open === "cost" ? <CostDialog close={() => setOpen(null)} done={load.reload} /> : null}
            </>
          )}
        </Region>
      </div>
    </main>
  );
}

function BankDialog({ s, close, done }: { s: Settings; close: () => void; done: () => void }) {
  const [f, setF] = useState({
    bank: s.platform.bank_name ?? "", number: s.platform.account_number ?? "", iban: s.platform.iban ?? "",
    holder: s.platform.account_holder ?? "", support: s.platform.support_contact ?? "",
  });
  const field = (k: keyof typeof f, label: string) => <label>{label}<input autoComplete="off" value={f[k]} onChange={(e) => setF({ ...f, [k]: e.target.value })} /></label>;
  return (
    <ActionDialog open onClose={close} onDone={done} title="Bank aur support" submit="Rakhein"
      run={(why) => rpc("admin_save_settings", { p_bank_name: f.bank, p_account_number: f.number, p_iban: f.iban, p_account_holder: f.holder, p_support_contact: f.support, p_reason: why }).then((r) => r.error)}>
      {field("bank", "Bank ka naam")}{field("holder", "Account kis naam par")}{field("number", "Account number")}{field("iban", "IBAN")}{field("support", "Support ka rabta, jaise WhatsApp number")}
      <p className="field-note">Customer inhi mein paise bhejte hain: dobara parh kar rakhein. Khali chhorne par app wo cheez nahin dikhati.</p>
    </ActionDialog>
  );
}

function CostDialog({ close, done }: { close: () => void; done: () => void }) {
  const [month, setMonth] = useState(dubaiDay(new Date()).slice(0, 7));
  const [item, setItem] = useState("");
  const [amount, setAmount] = useState("");
  const [note, setNote] = useState("");
  return (
    <ActionDialog open onClose={close} onDone={done} reason={false} title="Kharcha likhein" submit="Likhein"
      run={async () => {
        const fils = readAed(amount);
        if (!item.trim()) return "Kya kharcha hai, likhein.";
        if (fils === null) return "Raqam AED mein likhein, jaise 92.00.";
        return (await rpc("admin_add_cost", { p_month: `${month}-01`, p_item: item, p_amount_fils: fils, p_note: note || null })).error;
      }}>
      <label>Mahina<input type="month" value={month} onChange={(e) => setMonth(e.target.value)} required /></label>
      <label>Kya<input value={item} maxLength={100} onChange={(e) => setItem(e.target.value)} placeholder="Supabase Pro" required /></label>
      <label>Kitna (AED)<input inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} required /></label>
      <label>Note<input value={note} onChange={(e) => setNote(e.target.value)} /></label>
      <p className="field-note">Kharcha audit log mein jata hai aur badla nahin jata, is liye likhne se pehle raqam dekh lein.</p>
    </ActionDialog>
  );
}
