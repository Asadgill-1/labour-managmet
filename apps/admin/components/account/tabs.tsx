"use client";
import { Tag } from "@/components/ui";
import { ago, showDate, showTime } from "@/lib/dates";
import { showFils } from "@/lib/money";
import { coveringPlan, refundedOf, slipLink } from "@/lib/periods";
import type { Account, Plan, StoryEvent } from "@/lib/types";
import { coversWord, holdWord, kindWord, limitWord, months, planShort, roleWord, slipStateTag, slipStateWord, sourceWord, storyDetail, storyWord } from "@/lib/words";
import type { Ask } from "./actions";

type Props = { a: Account; act: (ask: Ask) => void };
const week = 7 * 86_400_000;

export function Khulasa({ a, act }: Props) {
  const owners = a.members.filter((m) => !m.revoked_at && m.role === "owner").length;
  const managers = a.members.filter((m) => !m.revoked_at && m.role === "manager").length;
  const lastBackup = a.backups[0];
  const over = a.limits?.workers != null && (a.workers ?? 0) > a.limits.workers;
  return (
    <div className="grid2">
      <section>
        <div className="section-head"><h2>Account</h2></div>
        <dl className="facts">
          <dt>Malik</dt><dd>{a.owner_email ?? "-"}, {a.email_confirmed ? "email confirm" : "email confirm baqi"}</dd>
          <dt>Bana</dt><dd>{showDate(a.created_at)}</dd>
          <dt>Tenant id</dt><dd>{a.tenant_id}</dd>
          <dt>Members</dt><dd>{owners} owner, {managers} manager</dd>
          <dt>Cloud backup</dt><dd>{lastBackup ? `Aakhri copy ${ago(lastBackup.finished_at)}` : "Koi copy nahin"}, {a.addon_ends_at ? `add-on ${showDate(a.addon_ends_at)} tak` : "add-on nahin"}</dd>
          <dt>Aap ka note</dt><dd>{a.notes[0]?.body ?? <button type="button" className="quiet" onClick={() => act({ kind: "note" })}>Note likhein</button>}</dd>
        </dl>
        <div className="section-head"><h2>Sehat</h2><span>aakhri 7 din</span></div>
        <ul className="checks">
          <li><span>Licence check</span><span className={a.last_seen && Date.now() - Date.parse(a.last_seen) < week ? "ok" : "bad"}>{ago(a.last_seen)}</span></li>
          <li><span>Backup cloud par</span><span className={lastBackup && Date.now() - Date.parse(lastBackup.finished_at) < week ? "ok" : "soon"}>{lastBackup ? ago(lastBackup.finished_at) : "koi nahin"}</span></li>
          <li><span>Plan ki had</span><span className={over ? "bad" : "ok"}>{a.workers ?? "-"} of {a.limits?.workers ?? "koi had nahin"} labour</span></li>
          <li><span>Crash aur errors</span><span className="soon">Hissa 3, app mukammal hone par</span></li>
        </ul>
      </section>
      <section>
        <div className="section-head"><h2>Account ki kahani</h2><span>naya upar</span></div>
        <Story events={a.story.slice(0, 10)} />
      </section>
    </div>
  );
}

export function Story({ events }: { events: StoryEvent[] }) {
  if (events.length === 0) return <div className="empty"><b>Abhi kuch nahin hua</b><p>Signup, company, trial, slips aur aap ke kaam yahan aayenge.</p></div>;
  return (
    <ol className="timeline">
      {events.map((e, i) => (
        <li key={i} className={e.what === "period_slip" || e.what === "slip_sent" || e.what.startsWith("admin_") ? "money" : undefined}>
          <div className="when">{showTime(e.at)}</div>
          <div className="ev">{storyWord(e.what)}</div>
          {e.detail ? <div className="more">{storyDetail(e.what, e.detail)}</div> : null}
        </li>
      ))}
    </ol>
  );
}

export function Money({ a, act, plans }: Props & { plans: Plan[] }) {
  const cur = coveringPlan(a.periods);
  const addon = a.periods.find((p) => p.kind === "addon" && !p.revoked_at_utc && p.starts_at_utc <= new Date().toISOString() && p.ends_at_utc > new Date().toISOString());
  const live = a.overrides.filter((o) => !o.ended_at_utc && Date.parse(o.until_utc) > Date.now());
  const paidTotal = a.periods.filter((p) => p.source === "slip").reduce((s, p) => s + p.amount_fils, 0);
  const refundTotal = a.money_entries.filter((m) => m.kind === "refund").reduce((s, m) => s + m.amount_fils, 0);
  return (
    <>
      <div className="grid2">
        <section>
          <div className="section-head"><h2>Abhi ka plan</h2>{cur ? <span>qeemat version {cur.plan_version}</span> : null}</div>
          <dl className="facts">
            <dt>Plan</dt><dd>{a.plan_name ?? "Koi plan nahin chal raha"}</dd>
            <dt>Chal raha</dt><dd>{cur ? `${showDate(cur.starts_at_utc)} se ${showDate(cur.ends_at_utc)}, ${sourceWord[cur.source].toLowerCase()}` : "-"}</dd>
            <dt>Aakhri din</dt><dd>{showDate(a.plan_ends_at)}{a.slips_waiting ? `, ${a.slips_waiting} slip intezar mein` : ""}</dd>
            <dt>Cloud add-on</dt><dd>{addon ? `${showDate(addon.ends_at_utc)} tak` : "Nahin"}</dd>
            <dt>Had</dt><dd>{a.limits ? `${a.limits.workers ?? "be-had"} labour, ${a.limits.clients ?? "be-had"} clients, ${a.limits.managers ?? "be-had"} manager` : "-"}</dd>
          </dl>
          <div className="section-head"><h2>Plan par kaam</h2></div>
          <div className="actions">
            <button type="button" onClick={() => act({ kind: "days", what: "plan" })}>Muft din dein</button>
            <button type="button" onClick={() => act({ kind: "days", what: "addon" })}>Add-on ke din dein</button>
            <button type="button" onClick={() => act({ kind: "changePlan", plans })} disabled={plans.length === 0}>Plan abhi se badlein</button>
            <button type="button" onClick={() => act({ kind: "override" })}>Had mein chhoot</button>
            <button type="button" onClick={() => act({ kind: "money", money: "refund" })}>Refund likhein</button>
            <button type="button" onClick={() => act({ kind: "money", money: "correction" })}>Darusti likhein</button>
          </div>
          <p className="src">Har kaam par wajah zaroori, aur har kaam audit log mein. Refund aur darusti par MFA code dobara.</p>
        </section>
        <section>
          <div className="section-head"><h2>Had mein chhoot</h2><span>{live.length ? `${live.length} chal rahi` : "koi nahin"}</span></div>
          {a.overrides.length === 0 ? <p className="src">Koi chhoot nahin di gayi.</p> : (
            <ul className="ledger">
              {a.overrides.map((o) => {
                const on = !o.ended_at_utc && Date.parse(o.until_utc) > Date.now();
                return (
                  <li key={o.id}>
                    <span className="what">{limitWord[o.what]}: {o.cap}</span>
                    <span className="why">{on ? `${showDate(o.until_utc)} tak` : o.ended_at_utc ? `khatam ki ${showDate(o.ended_at_utc)}` : `khatam hui ${showDate(o.until_utc)}`}; {o.reason}</span>
                    {on ? <span className="act"><button type="button" className="chip" onClick={() => act({ kind: "endOverride", override: o })}>Khatam karein</button></span> : null}
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      </div>

      <div className="section-head"><h2>Paison ka khata</h2><span>naya upar; koi line badli nahin jati (BILL-04)</span></div>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Slip</th><th>Kya</th><th>Period</th><th>Kaise</th><th>Bank reference</th><th>Bank mein</th><th>Haalat</th><th className="num">Aaya</th><th className="num">Wapas</th><th /></tr></thead>
          <tbody>
            {a.periods.map((p) => {
              const slip = a.slips.find((s) => s.id === p.slip_id);
              const back = refundedOf(a.money_entries, p.id);
              return (
                <tr key={p.id}>
                  <td>{slip ? <SlipThumb path={slip.file_path} /> : "-"}</td>
                  <td>{kindWord[p.kind]}, {planShort(p.plan_code)}<span className="sub">{p.anchor_months ? months(p.anchor_months) : ""}</span></td>
                  <td>{p.cut_at && p.cut_at <= p.starts_at_utc
                    ? <>Chala hi nahin<span className="sub">{showDate(p.starts_at_utc)} se {showDate(p.ends_at_utc)} tha, {showDate(p.cut_at)} ko khatam</span></>
                    : <>{showDate(p.starts_at_utc)} se {showDate(p.cut_at ?? p.ends_at_utc)}{p.cut_at ? <span className="sub">pehle {showDate(p.ends_at_utc)} tak tha</span> : null}</>}</td>
                  <td>{sourceWord[p.source]}{p.note ? <span className="sub">{p.note}</span> : null}</td>
                  <td>{p.bank_reference ?? "-"}</td>
                  <td>{p.received_on ? showDate(p.received_on) : "-"}</td>
                  <td>{p.revoked_at_utc ? <Tag kind="over">Wapas liya</Tag> : p.cut_at ? <Tag kind="wait">Pehle khatam</Tag> : <Tag kind="paid">Theek</Tag>}{p.revoke_reason ? <span className="sub">{p.revoke_reason}</span> : null}</td>
                  <td className="num">{showFils(p.amount_fils)}</td>
                  <td className="num">{showFils(back)}</td>
                  <td>{p.revoked_at_utc ? null : <button type="button" className="chip" onClick={() => act({ kind: "revoke", period: p })}>Wapas lein</button>}</td>
                </tr>
              );
            })}
            {a.money_entries.map((m) => (
              <tr key={m.id}>
                <td>-</td>
                <td>{m.kind === "refund" ? "Refund" : "Darusti"}</td>
                <td>{showDate(m.on_date)}</td>
                <td>Aap ne likha<span className="sub">{showTime(m.created_at_utc)}</span></td>
                <td>{m.reference ?? "-"}</td>
                <td>-</td>
                <td className="wrap">{m.kind === "correction" ? `${m.field}: ${m.field === "amount_fils" ? showFils(Number(m.value)) : m.value}` : ""}<span className="sub">{m.reason}</span></td>
                <td className="num">0.00</td>
                <td className="num">{showFils(m.amount_fils)}</td>
                <td />
              </tr>
            ))}
            <tr className="total-row"><td colSpan={7}>Kul</td><td className="num">{showFils(paidTotal)}</td><td className="num">{showFils(refundTotal)}</td><td /></tr>
          </tbody>
        </table>
      </div>

      <div className="section-head"><h2>Slips</h2><span>{a.slips.length}</span></div>
      {a.slips.length === 0 ? <p className="src">Is account ne abhi koi slip nahin bheji.</p> : (
        <div className="table-wrap">
          <table>
            <thead><tr><th>Slip</th><th>Bheji</th><th>Kya</th><th className="num">Aani thi</th><th>Bhejne wala bank</th><th>Haalat</th></tr></thead>
            <tbody>
              {a.slips.map((s) => (
                <tr key={s.id}>
                  <td><SlipThumb path={s.file_path} /></td>
                  <td>{showTime(s.submitted_at_utc)}</td>
                  <td>{planShort(s.plan_code)}, {coversWord[s.covers]}<span className="sub">{months(s.months)}, version {s.plan_version}</span></td>
                  <td className="num">{showFils(s.expected_fils)}</td>
                  <td>{s.payer_bank ?? "-"}{s.payer_last4 ? <span className="sub">account aakhri {s.payer_last4}</span> : null}</td>
                  <td><Tag kind={slipStateTag[s.state]}>{slipStateWord[s.state]}</Tag>{s.refuse_reason ? <span className="sub">{s.refuse_reason}</span> : null}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

/** A slip's file opens by a 60-second link, made only when asked. */
export function SlipThumb({ path }: { path: string }) {
  const kind = path.split(".").pop()?.toUpperCase() ?? "";
  return (
    <button type="button" className="thumb" aria-label={`Slip ki file kholein, ${kind}`} onClick={async () => {
      const link = await slipLink(path);
      if (link) window.open(link, "_blank", "noopener");
      else alert("Slip ki file nahin mili: shayad upload poora nahin hua.");
    }}>{kind}</button>
  );
}

export function Phones({ a, act }: Props) {
  if (a.devices.length === 0) return <div className="empty"><b>Koi phone nahin juda</b><p>Customer ke pehli dafa login karte hi phone yahan aayega.</p></div>;
  return (
    <div className="table-wrap">
      <table>
        <thead><tr><th>Phone</th><th>Kis ka</th><th>Version</th><th>Juda</th><th>Aakhri baar online</th><th>Haalat</th><th /></tr></thead>
        <tbody>
          {a.devices.map((d) => (
            <tr key={d.id}>
              <td>{d.label}<span className="sub">{d.platform}</span></td>
              <td>{d.user_email ?? "-"}</td>
              <td>{d.app_version ?? "-"}</td>
              <td>{showDate(d.since)}</td>
              <td className={d.last_seen && Date.now() - Date.parse(d.last_seen) > week ? "late" : undefined}>{ago(d.last_seen)}</td>
              <td>{d.off_at ? <Tag kind="over">Band, {showDate(d.off_at)} se</Tag> : <Tag kind="paid">On</Tag>}</td>
              <td><button type="button" className="chip" onClick={() => act({ kind: "phone", device: d })}>{d.off_at ? "Kholein" : "Band karein"}</button></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function Backups({ a }: Props) {
  const addons = a.periods.filter((p) => p.kind === "addon");
  return (
    <div className="grid2 even">
      <section>
        <div className="section-head"><h2>Cloud par copies</h2><span>{a.backups.length}</span></div>
        {a.backups.length === 0 ? <p className="src">Koi copy nahin. App har din aur har badi tabdeeli par copy bhejti hai (T20d).</p> : (
          <table>
            <thead><tr><th>Kab</th><th className="num">Size</th><th>Kab tak rakhi jayegi</th></tr></thead>
            <tbody>{a.backups.map((b) => <tr key={b.id}><td>{showTime(b.finished_at)}</td><td className="num">{(b.size_bytes / 1_048_576).toFixed(1)} MB</td><td>{b.keep_until ? showDate(b.keep_until) : "aakhri copy, rehti hai"}</td></tr>)}</tbody>
          </table>
        )}
        <p className="src">Copy band hai: sirf customer ka backup password ya aap ki offline recovery key se khulti hai (D-072).</p>
      </section>
      <section>
        <div className="section-head"><h2>Cloud add-on ke periods</h2><span>{addons.length}</span></div>
        {addons.length === 0 ? <p className="src">Add-on kabhi nahin liya.</p> : (
          <ul className="ledger">{addons.map((p) => <li key={p.id}><span className="what">{showDate(p.starts_at_utc)} se {showDate(p.ends_at_utc)}</span><span className="why">{sourceWord[p.source]}, AED {showFils(p.amount_fils)}{p.revoked_at_utc ? ", wapas liya" : ""}</span></li>)}</ul>
        )}
      </section>
    </div>
  );
}

export function Settings({ a, act }: Props) {
  const blocked = a.hold?.kind === "block";
  const users = a.members.filter((m) => !m.revoked_at);
  const loginOff = users.filter((m) => m.banned_until && Date.parse(m.banned_until) > Date.now()).length;
  const known = users.some((m) => m.banned_until !== undefined);
  return (
    <>
      {known && blocked && loginOff < users.length ? (
        <div className="banner" role="alert"><b>Account block hai, lekin {users.length - loginOff} login abhi khule hain.</b>Login band karne ka kaam poora nahin hua.<div><button type="button" onClick={() => act({ kind: "ban" })}>Login band karein</button></div></div>
      ) : null}
      {known && !blocked && loginOff > 0 ? (
        <div className="banner" role="alert"><b>Account block nahin, lekin {loginOff} login band hain.</b><div><button type="button" onClick={() => act({ kind: "ban" })}>Login kholein</button></div></div>
      ) : null}
      <div className="table-wrap">
        <table>
          <thead><tr><th>Cheez</th><th>Abhi</th><th>Kya kar sakte hain</th><th /></tr></thead>
          <tbody>
            <tr>
              <td>Rok</td>
              <td className="wrap">{a.hold ? `${holdWord[a.hold.kind]}${a.hold.until ? `, ${showDate(a.hold.until)} tak` : ", jab tak khola na jaye"}: “${a.hold.told}”` : "Account chal raha hai"}{known && blocked && loginOff === users.length ? <span className="sub">Login band</span> : null}</td>
              <td className="wrap">Arzi suspend, suspend ya block. Kitab customer ke paas khuli rehti hai, sirf nayi entry band.</td>
              <td>{a.hold ? <button type="button" className="chip" onClick={() => act({ kind: "lift", hold: a.holds.find((h) => h.id === a.hold!.id)! })}>Kholein</button> : <button type="button" className="chip" onClick={() => act({ kind: "hold" })}>Rokein</button>}</td>
            </tr>
            <tr>
              <td>Company ka naam</td><td>{a.name}</td><td className="wrap">Spelling theek karna</td>
              <td><button type="button" className="chip" onClick={() => act({ kind: "rename" })}>Badlein</button></td>
            </tr>
            <tr>
              <td>Login email</td><td>{a.owner_email ?? "-"}{a.email_confirmed ? ", confirm" : ""}</td>
              <td className="wrap">Naya email, purane aur naye dono par code. Email bhejne ki service (T19d) ke baad.</td>
              <td><button type="button" className="chip" disabled>Abhi nahin</button></td>
            </tr>
            <tr>
              <td>Members</td>
              <td className="wrap">{users.map((m) => `${m.email ?? m.user_id} (${roleWord[m.role] ?? m.role})`).join(", ") || "-"}</td>
              <td className="wrap">Dekhna; manager hatana app se, owner ki taraf se</td><td />
            </tr>
            <tr>
              <td>Trial</td><td>{a.periods.some((p) => p.source === "trial") ? "Istemal ho chuka" : "Abhi nahin liya"}</td>
              <td className="wrap">Trial claim azad karna, ya trial dobara dena</td>
              <td><span className="actions" style={{ marginTop: 0 }}><button type="button" className="chip" onClick={() => act({ kind: "claim" })}>Claim azad</button><button type="button" className="chip" onClick={() => act({ kind: "days", what: "trial" })}>Trial dein</button></span></td>
            </tr>
            <tr>
              <td>Test account</td><td>{a.is_test ? "Haan" : "Nahin"}</td><td className="wrap">Hisaab aur investors ke numbers se bahar rakhna</td>
              <td><button type="button" className="chip" onClick={() => act({ kind: "test" })}>Badlein</button></td>
            </tr>
            <tr>
              <td>Account mitana</td><td>-</td><td className="wrap">Customer app se khud mita sakta hai; likhi darkhwast par web se mitana T26 mein (D-067)</td>
              <td><button type="button" className="chip" disabled>Abhi nahin</button></td>
            </tr>
          </tbody>
        </table>
      </div>
      {a.holds.length ? (
        <>
          <div className="section-head"><h2>Pichhli rokein</h2><span>{a.holds.length}</span></div>
          <ul className="ledger">
            {a.holds.map((h) => (
              <li key={h.id}>
                <span className="what">{holdWord[h.kind]}, {showTime(h.created_at_utc)}{h.until_utc ? `, ${showDate(h.until_utc)} tak` : ""}</span>
                <span className="why">“{h.told}”{h.note ? `; note: ${h.note}` : ""}{h.lifted_at_utc ? `; khola ${showTime(h.lifted_at_utc)}: ${h.lift_reason}` : ""}</span>
              </li>
            ))}
          </ul>
        </>
      ) : null}
    </>
  );
}

export function Notes({ a, act }: Props) {
  return (
    <>
      <div className="actions"><button type="button" className="primary" onClick={() => act({ kind: "note" })}>Note likhein</button></div>
      {a.notes.length === 0 ? <div className="empty"><b>Koi note nahin</b><p>Is account ke baare mein jo yaad rakhna ho, yahan likhein. Note badla ya mitaya nahin jata.</p></div> : (
        <ul className="ledger" style={{ marginTop: 16 }}>
          {a.notes.map((n) => <li key={n.id}><span className="what" style={{ whiteSpace: "pre-wrap" }}>{n.body}</span><span className="why">{showTime(n.at_utc)}</span></li>)}
        </ul>
      )}
    </>
  );
}
