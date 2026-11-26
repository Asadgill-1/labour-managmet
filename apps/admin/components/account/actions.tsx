"use client";
import { useState } from "react";
import { ActionDialog } from "@/components/ui";
import { syncBan } from "@/lib/admin-fn";
import { rpc } from "@/lib/cloud";
import { dubaiDay, showDate } from "@/lib/dates";
import { creditFor } from "@/lib/credit";
import { readAed, showFils } from "@/lib/money";
import { endOfDubaiDay, refundedOf } from "@/lib/periods";
import type { Account, Device, HoldRow, Override, Period, Plan } from "@/lib/types";
import { kindWord, limitWord, planShort, sourceWord } from "@/lib/words";

// Every action the owner takes on one account. Each writes its audit row in Postgres; the page reloads after it.
export type Ask =
  | { kind: "note" }
  | { kind: "days"; what: "plan" | "addon" | "trial" }
  | { kind: "override" }
  | { kind: "endOverride"; override: Override }
  | { kind: "revoke"; period: Period }
  | { kind: "money"; money: "refund" | "correction"; period?: Period }
  | { kind: "hold" }
  | { kind: "lift"; hold: HoldRow }
  | { kind: "claim" }
  | { kind: "test" }
  | { kind: "rename" }
  | { kind: "phone"; device: Device }
  | { kind: "ban" }
  | { kind: "changePlan"; plans: Plan[] };

const tomorrow = () => dubaiDay(new Date(Date.now() + 86_400_000));

export function AccountActions({ a, ask, close, done }: { a: Account; ask: Ask | null; close: () => void; done: () => void }) {
  const shared = { open: true, onClose: close, onDone: done };
  if (!ask) return null;
  switch (ask.kind) {
    case "note": return <NoteDialog a={a} {...shared} />;
    case "days": return <DaysDialog a={a} what={ask.what} {...shared} />;
    case "override": return <OverrideDialog a={a} {...shared} />;
    case "endOverride":
      return (
        <ActionDialog {...shared} title="Chhoot khatam karein" submit="Chhoot khatam karein"
          run={(why) => rpc("admin_end_override", { p_override: ask.override.id, p_reason: why }).then((r) => r.error)}>
          <p>{limitWord[ask.override.what]} ki had {ask.override.cap}, {showDate(ask.override.until_utc)} tak. Khatam karne par plan ki apni had wapas.</p>
        </ActionDialog>
      );
    case "revoke":
      return (
        <ActionDialog {...shared} danger title="Period wapas lein" submit="Wapas lein"
          run={(why) => rpc("admin_revoke_period", { p_period: ask.period.id, p_reason: why }).then((r) => r.error)}>
          <p>{kindWord[ask.period.kind]}, {planShort(ask.period.plan_code)}, {showDate(ask.period.starts_at_utc)} se {showDate(ask.period.ends_at_utc)}, {sourceWord[ask.period.source]}. Ye period kabhi gina nahin jayega; paise ka record aur audit log rehte hain.</p>
        </ActionDialog>
      );
    case "money": return <MoneyDialog a={a} money={ask.money} period={ask.period} {...shared} />;
    case "hold": return <HoldDialog a={a} {...shared} />;
    case "lift":
      return (
        <ActionDialog {...shared} needsCode title="Account kholein" submit="Kholein"
          run={async (why) => {
            const r = await rpc("admin_lift_hold", { p_hold: ask.hold.id, p_reason: why });
            if (r.error) return r.error;
            return ask.hold.kind === "block" ? banNote(await syncBan(a.tenant_id)) : null;
          }}>
          <p>{ask.hold.kind === "block" ? "Block" : "Suspend"} {showDate(ask.hold.created_at_utc)} se. Kholne par customer ka phone agle online check par nayi entry kar sakega{ask.hold.kind === "block" ? ", aur login phir khul jayega" : ""}.</p>
        </ActionDialog>
      );
    case "claim": return <ClaimDialog a={a} {...shared} />;
    case "test":
      return (
        <ActionDialog {...shared} title={a.is_test ? "Test account se hatayein" : "Test account banayein"} submit={a.is_test ? "Asli account" : "Test account"}
          run={(why) => rpc("admin_set_test", { p_tenant: a.tenant_id, p_is_test: !a.is_test, p_reason: why }).then((r) => r.error)}>
          <p>{a.is_test ? "Ye account phir har hisaab aur figure mein gina jayega." : "Test account kamai, MRR aur investors ke numbers mein nahin gina jata (MET-07)."}</p>
        </ActionDialog>
      );
    case "rename": return <RenameDialog a={a} {...shared} />;
    case "phone":
      return (
        <ActionDialog {...shared} danger={!ask.device.off_at} title={ask.device.off_at ? "Phone kholein" : "Phone band karein"} submit={ask.device.off_at ? "Kholein" : "Band karein"}
          run={(why) => rpc("admin_phone", { p_device_row: ask.device.id, p_off: !ask.device.off_at, p_reason: why }).then((r) => r.error)}>
          <p>{ask.device.label}, {ask.device.platform}, {ask.device.user_email ?? ""}. {ask.device.off_at ? "Ye phone phir licence le sakega." : "Ye phone agle check par ruk jayega; kitab phone par rehti hai (D-073)."}</p>
        </ActionDialog>
      );
    case "changePlan": return <ChangePlanDialog a={a} plans={ask.plans} {...shared} />;
    case "ban":
      return (
        <ActionDialog {...shared} reason={false} title="Login ko rok ke mutabiq karein" submit="Abhi karein"
          run={async () => banNote(await syncBan(a.tenant_id))}>
          <p>{a.hold?.kind === "block" ? "Account block hai: is ke logins band kiye jayenge, block khatam hone tak." : "Account block nahin: is ke logins khole jayenge."}</p>
        </ActionDialog>
      );
  }
}

const banNote = (failed: string | null) => (failed ? `Rok lag gayi, lekin login ka badlav nahin hua: ${failed} Account tab se dobara karein.` : null);

type Shared = { open: boolean; onClose: () => void; onDone: () => void };

function NoteDialog({ a, ...shared }: { a: Account } & Shared) {
  const [body, setBody] = useState("");
  return (
    <ActionDialog {...shared} reason={false} title="Note likhein" submit="Note rakhein"
      run={async () => (body.trim() ? (await rpc("admin_note", { p_tenant: a.tenant_id, p_body: body })).error : "Note khali hai.")}>
      <label>Sirf aap ke liye; badla ya mitaya nahin jata<textarea rows={4} maxLength={2000} value={body} onChange={(e) => setBody(e.target.value)} required /></label>
    </ActionDialog>
  );
}

function DaysDialog({ a, what, ...shared }: { a: Account; what: "plan" | "addon" | "trial" } & Shared) {
  const [days, setDays] = useState(what === "trial" ? "15" : "7");
  const [plan, setPlan] = useState("");
  const title = { plan: "Muft din dein", addon: "Cloud add-on ke din dein", trial: "Trial dobara dein" }[what];
  return (
    <ActionDialog {...shared} title={title} submit="Din dein"
      run={(why) => {
        const n = Number(days);
        if (!Number.isInteger(n) || n < 1 || n > 366) return Promise.resolve("from 1 to 366 days");
        return rpc("admin_give_days", {
          p_tenant: a.tenant_id, p_kind: what === "addon" ? "addon" : "plan", p_plan_code: what === "trial" ? "trial" : plan || null, p_days: n, p_reason: why,
        }).then((r) => r.error);
      }}>
      {what === "plan" ? (
        <label>Kaunsa plan
          <select value={plan} onChange={(e) => setPlan(e.target.value)}>
            <option value="">Jo plan pehle tha{a.plan && a.plan !== "trial" ? `, ${planShort(a.plan)}` : ""}</option>
            <option value="small">Small</option><option value="mid">Mid</option><option value="large">Large</option>
          </select>
        </label>
      ) : null}
      <label>Kitne din<input inputMode="numeric" value={days} onChange={(e) => setDays(e.target.value)} required /></label>
      <p className="field-note">Din chalte {what === "addon" ? "add-on" : "plan"} ke khatam hone ke baad se, ya abhi se agar koi nahin chal raha. Paise zero; kamai mein nahin gine jate.</p>
    </ActionDialog>
  );
}

function OverrideDialog({ a, ...shared }: { a: Account } & Shared) {
  const [what, setWhat] = useState<"workers" | "clients" | "managers">("workers");
  const [cap, setCap] = useState("");
  const [until, setUntil] = useState(tomorrow());
  return (
    <ActionDialog {...shared} title="Had mein chhoot" submit="Chhoot dein"
      run={(why) => {
        const n = Number(cap);
        if (!Number.isInteger(n) || n < 0) return Promise.resolve("Nayi had poora number likhein.");
        return rpc("admin_limit_override", { p_tenant: a.tenant_id, p_what: what, p_cap: n, p_until: endOfDubaiDay(until), p_reason: why }).then((r) => r.error);
      }}>
      <label>Kis cheez ki had
        <select value={what} onChange={(e) => setWhat(e.target.value as typeof what)}>
          <option value="workers">Active labour</option><option value="clients">Client companies</option><option value="managers">Managers</option>
        </select>
      </label>
      <label>Nayi had<input inputMode="numeric" value={cap} onChange={(e) => setCap(e.target.value)} required />
        <span className="field-note">Abhi plan ki had {a.limits?.[what] ?? "koi nahin"}. Chhoot sirf had barhati hai, kam nahin karti.</span>
      </label>
      <label>Kis din tak (us din ke aakhir tak)<input type="date" min={tomorrow()} value={until} onChange={(e) => setUntil(e.target.value)} required /></label>
    </ActionDialog>
  );
}

function MoneyDialog({ a, money, period, ...shared }: { a: Account; money: "refund" | "correction"; period?: Period } & Shared) {
  const paid = a.periods.filter((p) => p.source === "slip");
  const [id, setId] = useState(period?.id ?? paid[0]?.id ?? "");
  const [amount, setAmount] = useState("");
  const [field, setField] = useState("received_on");
  const [value, setValue] = useState("");
  const [reference, setReference] = useState("");
  const [onDate, setOnDate] = useState(dubaiDay(new Date()));
  const chosen = paid.find((p) => p.id === id);
  const left = chosen ? chosen.amount_fils - refundedOf(a.money_entries, chosen.id) : 0;
  if (paid.length === 0) {
    return (
      <ActionDialog {...shared} reason={false} title={money === "refund" ? "Refund likhein" : "Darusti likhein"} submit="Theek" run={async () => null}>
        <p>Is account ka koi paid period nahin, is liye refund ya darusti nahin.</p>
      </ActionDialog>
    );
  }
  return (
    <ActionDialog {...shared} needsCode title={money === "refund" ? "Refund likhein" : "Darusti likhein"} submit={money === "refund" ? "Refund likhein" : "Darusti likhein"}
      run={(why) => {
        let fils: number | null = null;
        let corrected = value.trim();
        if (money === "refund") {
          fils = readAed(amount);
          if (fils === null || fils <= 0) return Promise.resolve("Refund ki raqam AED mein likhein, jaise 199.00.");
        } else if (field === "amount_fils") {
          const f = readAed(value);
          if (f === null) return Promise.resolve("Sahi raqam AED mein likhein.");
          corrected = String(f);
        }
        return rpc("admin_money_entry", {
          p_tenant: a.tenant_id, p_kind: money, p_period: id, p_amount_fils: fils, p_field: money === "correction" ? field : null,
          p_value: money === "correction" ? corrected : null, p_reference: reference || null, p_on_date: onDate, p_reason: why,
        }).then((r) => r.error);
      }}>
      <label>Kaunsa period
        <select value={id} onChange={(e) => setId(e.target.value)}>
          {paid.map((p) => <option key={p.id} value={p.id}>{kindWord[p.kind]}, {planShort(p.plan_code)}, {showDate(p.starts_at_utc)}, AED {showFils(p.amount_fils)}, ref {p.bank_reference}</option>)}
        </select>
      </label>
      {money === "refund" ? (
        <>
          <label>Wapas kiye (AED)<input inputMode="decimal" autoComplete="off" value={amount} onChange={(e) => setAmount(e.target.value)} required />
            <span className="field-note">Zyada se zyada AED {showFils(left)}: aaye paise minus pichhle refund.</span>
          </label>
          <label>Refund ka bank reference<input autoComplete="off" value={reference} onChange={(e) => setReference(e.target.value)} /></label>
          <label>Kis din wapas kiye<input type="date" value={onDate} onChange={(e) => setOnDate(e.target.value)} required /></label>
          <p className="field-note">Period wahi rehta hai; refund ek nayi line hai aur us mahine ki kamai se ghatta hai.</p>
        </>
      ) : (
        <>
          <label>Kya ghalat likha tha
            <select value={field} onChange={(e) => setField(e.target.value)}>
              <option value="received_on">Bank mein aane ki tareekh</option>
              <option value="bank_reference">Bank reference</option>
              <option value="amount_fils">Aayi raqam</option>
              <option value="payer_bank">Bhejne wale ka bank</option>
              <option value="payer_last4">Bhejne wale account ke aakhri 4 hindse</option>
            </select>
          </label>
          <label>Sahi value{field === "amount_fils" ? " (AED)" : ""}<input type={field === "received_on" ? "date" : "text"} autoComplete="off" value={value} onChange={(e) => setValue(e.target.value)} required /></label>
          <label>Kis din pata chala<input type="date" value={onDate} onChange={(e) => setOnDate(e.target.value)} required /></label>
          <p className="field-note">Purani line nahin badalti; darusti ek nayi line hai jo sahi value batati hai (BILL-04).</p>
        </>
      )}
    </ActionDialog>
  );
}

function HoldDialog({ a, ...shared }: { a: Account } & Shared) {
  const [kind, setKind] = useState<"arzi" | "suspend" | "block">("arzi");
  const [until, setUntil] = useState(dubaiDay(new Date(Date.now() + 3 * 86_400_000)));
  const [told, setTold] = useState("");
  const [note, setNote] = useState("");
  return (
    <ActionDialog {...shared} needsCode danger title={`${a.name} ko rokein`} submit={kind === "block" ? "Block karein" : "Suspend karein"}
      run={async (why) => {
        if (!told.trim()) return "Customer ko kya likha aaye, ye likhein.";
        const r = await rpc("admin_hold", {
          p_tenant: a.tenant_id, p_kind: kind === "block" ? "block" : "suspend", p_until: kind === "arzi" ? endOfDubaiDay(until) : null,
          p_told: told, p_note: note || null, p_reason: why,
        });
        if (r.error) return r.error;
        return kind === "block" ? banNote(await syncBan(a.tenant_id)) : null;
      }}>
      <fieldset className="choices">
        <legend>Kis tarah</legend>
        <label className="choice"><input type="radio" name="hold" checked={kind === "arzi"} onChange={() => setKind("arzi")} /><span><b>Arzi suspend</b><span>Chuni tareekh tak, phir khud khul jata hai.</span></span></label>
        <label className="choice"><input type="radio" name="hold" checked={kind === "suspend"} onChange={() => setKind("suspend")} /><span><b>Suspend</b><span>Jab tak aap khud na kholein.</span></span></label>
        <label className="choice"><input type="radio" name="hold" checked={kind === "block"} onChange={() => setKind("block")} /><span><b>Block</b><span>Suspend ke sath naya phone aur login bhi band. Dhoke ya ghalat istemal ke liye.</span></span></label>
      </fieldset>
      {kind === "arzi" ? <label>Kis din tak (us din ke aakhir tak)<input type="date" min={tomorrow()} value={until} onChange={(e) => setUntil(e.target.value)} required /></label> : null}
      <label>Customer ko app mein kya likha aaye<textarea rows={2} maxLength={300} value={told} onChange={(e) => setTold(e.target.value)} placeholder="Aap ki slip ka masla hai. Support se rabta karein." required /></label>
      <label>Aap ka note, sirf aap ke liye<input value={note} onChange={(e) => setNote(e.target.value)} /></label>
      <p className="field-note">Customer apni kitab dekh, chhap aur export kar sakta hai; sirf nayi entry band hoti hai. Phone agle online check par rukta hai, offline phone zyada se zyada 7 din mein (D-074).</p>
    </ActionDialog>
  );
}

function ClaimDialog({ a, ...shared }: { a: Account } & Shared) {
  const [email, setEmail] = useState(a.owner_email ?? "");
  return (
    <ActionDialog {...shared} title="Trial claim azad karein" submit="Azad karein"
      run={(why) => rpc<number>("admin_free_trial_claim", { p_email: email, p_reason: why }).then((r) => r.error)}>
      <label>Kis email ka claim<input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
      <p className="field-note">Is email ka claim aur us ke sath ke phone claims hatte hain; us email ya phone par nayi company phir trial le sakti hai (D-082 (3)).</p>
    </ActionDialog>
  );
}

function RenameDialog({ a, ...shared }: { a: Account } & Shared) {
  const [name, setName] = useState(a.name);
  return (
    <ActionDialog {...shared} title="Company ka naam theek karein" submit="Naam rakhein"
      run={(why) => rpc("admin_rename", { p_tenant: a.tenant_id, p_name: name, p_reason: why }).then((r) => r.error)}>
      <label>Naya naam<input value={name} maxLength={100} onChange={(e) => setName(e.target.value)} required /></label>
    </ActionDialog>
  );
}

// Another plan from now, with no money: the running plan ends now and the new one is given for the days the owner
// chooses; the suggestion is what was left of the old plan, priced at the new one (D-083).
function ChangePlanDialog({ a, plans, ...shared }: { a: Account; plans: Plan[] } & Shared) {
  const onSale = plans.filter((p) => p.on_sale && p.code !== "trial");
  const [code, setCode] = useState(onSale.find((p) => p.code !== a.plan)?.code ?? onSale[0]?.code ?? "");
  const price = onSale.find((p) => p.code === code)?.price_fils ?? 0;
  const now = new Date().toISOString();
  const running = a.periods.filter((p) => p.kind === "plan" && p.plan_code !== "trial" && !p.revoked_at_utc && (p.cut_at ?? p.ends_at_utc) > now)
    .map((p) => ({ ...p, ends_at_utc: p.cut_at ?? p.ends_at_utc }));
  const suggestion = creditFor(running, price);
  const [days, setDays] = useState(String(Math.max(1, suggestion.days)));
  return (
    <ActionDialog {...shared} needsCode title="Plan abhi se badlein" submit="Plan badlein"
      run={(why) => {
        const n = Number(days);
        if (!Number.isInteger(n) || n < 1 || n > 366) return Promise.resolve("from 1 to 366 days");
        return rpc("admin_change_plan", { p_tenant: a.tenant_id, p_plan_code: code, p_days: n, p_reason: why }).then((r) => r.error);
      }}>
      <label>Naya plan
        <select value={code} onChange={(e) => { setCode(e.target.value); setDays(String(Math.max(1, creditFor(running, onSale.find((p) => p.code === e.target.value)?.price_fils ?? 0).days))); }}>
          {onSale.map((p) => <option key={p.code} value={p.code}>{p.name}, AED {showFils(p.price_fils)} mahana</option>)}
        </select>
      </label>
      <label>Naye plan ke din
        <input inputMode="numeric" value={days} onChange={(e) => setDays(e.target.value)} required />
        <span className="field-note">Tajweez {suggestion.days} din: chalte plan ka bacha hissa AED {showFils(suggestion.fils)}{running.some((p) => p.source === "grant") ? ", aur diye hue din" : ""}. Customer naya plan le kar slip bheje to us ki slip ko Subscriptions mein "Abhi se" accept karein.</span>
      </label>
      <p className="field-note">Chalta plan abhi khatam hota hai, us ki line wahi rehti hai; naya plan in dinon ke liye muft diya jata hai. Agli slip in dinon ke baad se chalegi.</p>
    </ActionDialog>
  );
}
