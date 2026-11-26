"use client";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { AccountActions, type Ask } from "@/components/account/actions";
import { Backups, Khulasa, Money, Notes, Phones, Settings, Story } from "@/components/account/tabs";
import { Shell } from "@/components/Shell";
import { Fresh, Region, Tag } from "@/components/ui";
import { ago, showDate } from "@/lib/dates";
import { showFils } from "@/lib/money";
import type { Account, Settings as Platform } from "@/lib/types";
import { useRpc } from "@/lib/use-rpc";
import { planShort, stateTag, stateWord } from "@/lib/words";

const tabs = [
  { key: "khulasa", label: "Khulasa" },
  { key: "plan", label: "Plan aur paise" },
  { key: "phone", label: "Phone" },
  { key: "backup", label: "Backup" },
  { key: "timeline", label: "Timeline" },
  { key: "account", label: "Account" },
  { key: "notes", label: "Notes" },
] as const;

export default function AccountPage() {
  return <Shell><Suspense><AccountBody /></Suspense></Shell>;
}

function AccountBody() {
  const params = useSearchParams();
  const id = params.get("id") ?? "";
  const tab = tabs.find((t) => t.key === params.get("tab"))?.key ?? "khulasa";
  const ok = /^[0-9a-f-]{36}$/i.test(id);
  const load = useRpc<Account>("admin_account", { p_tenant: id }, !ok);
  const settings = useRpc<Platform>("admin_settings", {}, !ok);
  const [ask, setAsk] = useState<Ask | null>(null);

  if (!ok) {
    return <main className="sheet-page"><div className="cap page"><div className="empty"><b>Account chunein</b><p>Ye link kisi account ka nahin.</p><div className="actions"><Link className="btn" href="/accounts/">Accounts</Link></div></div></div></main>;
  }

  return (
    <main className="sheet-page">
      <div className="cap page">
        <Region load={load} lines={8}>
          {(a) => (
            <>
              <div className="crumbs"><Link href="/accounts/">Accounts</Link> / {a.name}</div>
              <div className="head">
                <div>
                  <h1>{a.name}</h1>
                  <div className="tags">
                    <Tag kind={stateTag[a.state]}>{stateWord[a.state]}{a.plan && a.state !== "held" ? `, ${planShort(a.plan)}` : ""}</Tag>
                    {a.is_test ? <Tag>Test account</Tag> : null}
                    {a.app_version ? <Tag kind="part">Version {a.app_version}</Tag> : null}
                    <Tag kind="part">{showDate(a.created_at)} se</Tag>
                  </div>
                </div>
                <div className="actions" style={{ marginTop: 0 }}>
                  <button type="button" onClick={() => setAsk({ kind: "note" })}>Note likhein</button>
                  <button type="button" onClick={() => setAsk({ kind: "days", what: "plan" })}>Muft din dein</button>
                  {a.hold ? <button type="button" onClick={() => setAsk({ kind: "lift", hold: a.holds.find((h) => h.id === a.hold!.id)! })}>Account kholein</button>
                    : <button type="button" className="danger" onClick={() => setAsk({ kind: "hold" })}>Account rokein</button>}
                </div>
              </div>
              <Status a={a} />
              <p className="src">Kitab ka khulasa (clients ka bill, labour ki tankhwah, nafa ya nuqsan) hissa 2 mein aayega, jab customer ki ijazat se kitab cloud par aayegi. <Fresh at={load.fetchedAt} /></p>
              <nav className="tabs" aria-label="Account ke hisse">
                {tabs.map((t) => (
                  <Link key={t.key} href={`/account/?id=${id}${t.key === "khulasa" ? "" : `&tab=${t.key}`}`} aria-current={tab === t.key ? "page" : undefined} scroll={false}>
                    {t.label}{t.key === "notes" && a.notes.length ? ` ${a.notes.length}` : ""}
                  </Link>
                ))}
              </nav>
              {tab === "khulasa" ? <Khulasa a={a} act={setAsk} /> : null}
              {tab === "plan" ? <Money a={a} act={setAsk} plans={settings.data?.plans ?? []} /> : null}
              {tab === "phone" ? <div style={{ marginTop: 16 }}><Phones a={a} act={setAsk} /></div> : null}
              {tab === "backup" ? <Backups a={a} act={setAsk} /> : null}
              {tab === "timeline" ? <div style={{ marginTop: 24 }}><Story events={a.story} /></div> : null}
              {tab === "account" ? <div style={{ marginTop: 16 }}><Settings a={a} act={setAsk} /></div> : null}
              {tab === "notes" ? <Notes a={a} act={setAsk} /> : null}
              <AccountActions a={a} ask={ask} close={() => setAsk(null)} done={load.reload} />
            </>
          )}
        </Region>
      </div>
    </main>
  );
}

function Status({ a }: { a: Account }) {
  const over = a.limits?.workers != null && (a.workers ?? 0) > a.limits.workers;
  const owners = a.members.filter((m) => !m.revoked_at && m.role === "owner").length;
  const managers = a.members.filter((m) => !m.revoked_at && m.role === "manager").length;
  const state = a.state === "held"
    ? <b className="bad">Ruka hua{a.hold?.until ? `, ${showDate(a.hold.until)} tak` : ""}</b>
    : a.state === "paid" || a.state === "trial" ? <b className="ok">Chal raha hai</b> : <b className="bad">{stateWord[a.state]}</b>;
  return (
    <div className="statusrow" role="list" aria-label="Account ki haalat">
      <div role="listitem"><span>Account</span>{state}<small>aakhri baar online {ago(a.last_seen)}</small></div>
      <div role="listitem"><span>Plan</span><b>{a.plan_name ?? "Koi nahin"}</b><small>{a.plan_ends_at ? `${showDate(a.plan_ends_at)} tak` : "-"}, diya kul AED {showFils(a.paid_fils)}</small></div>
      <div role="listitem"><span>Had</span><b className={over ? "bad" : undefined}>{a.workers ?? "-"} of {a.limits?.workers ?? "be-had"} labour</b><small>{a.clients ?? "-"} of {a.limits?.clients ?? "be-had"} clients</small></div>
      <div role="listitem"><span>Log</span><b>{owners} owner, {managers} manager</b><small>manager ki had {a.limits?.managers ?? "be-had"}</small></div>
      <div role="listitem"><span>Phone se aaya</span><b>{ago(a.reported_at)}</b><small>{a.phones_on} phone on{a.app_version ? `, version ${a.app_version}` : ""}</small></div>
    </div>
  );
}
