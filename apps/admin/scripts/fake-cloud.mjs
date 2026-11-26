// A stand-in for the cloud, for running the dashboard on this computer: Supabase's auth, the admin_ functions, the
// slips' storage and the admin function, with sample accounts. Every name, email and number here is sample data. Dev
// only; it is not part of the build. Run `node scripts/fake-cloud.mjs`, then start the site with
// NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54399 and any NEXT_PUBLIC_SUPABASE_ANON_KEY. Any password signs in; any
// six digits pass the code step except 000000.
import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

const port = Number(process.env.FAKE_CLOUD_PORT ?? 54399);
const day = 86_400_000;
const now = () => Date.now();
const iso = (ms) => new Date(ms).toISOString();
const ago = (days, hours = 0) => iso(now() - days * day - hours * 3_600_000);
const ahead = (days) => iso(now() + days * day);
const dateOnly = (ms) => iso(ms).slice(0, 10);
const owner = "d0000000-0000-4000-8000-000000000001";
let factorVerified = process.env.FAKE_ENROLLED !== "0";
let lastTotp = 0;

const plans = [
  { code: "trial", version: 1, name: "Trial period", price_fils: 0, addon_price_fils: 0, max_workers: null, max_clients: null, max_managers: null, on_sale: false, sort_order: 0, backup_keep_days: 30, created_at_utc: "2026-11-11T00:00:00Z" },
  { code: "small", version: 1, name: "Small Company Plan", price_fils: 19900, addon_price_fils: 2000, max_workers: 15, max_clients: 5, max_managers: 1, on_sale: true, sort_order: 1, backup_keep_days: 30, created_at_utc: "2026-11-11T00:00:00Z" },
  { code: "mid", version: 1, name: "Mid Size Company Plan", price_fils: 29900, addon_price_fils: 2000, max_workers: 35, max_clients: 9, max_managers: 2, on_sale: true, sort_order: 2, backup_keep_days: 30, created_at_utc: "2026-11-11T00:00:00Z" },
  { code: "large", version: 1, name: "Large Size Company Plan", price_fils: 49900, addon_price_fils: 4000, max_workers: null, max_clients: null, max_managers: null, on_sale: true, sort_order: 3, backup_keep_days: 30, created_at_utc: "2026-11-11T00:00:00Z" },
];
const plan = (code) => plans.find((p) => p.code === code);

// Sample accounts: [name, email, days since signup, plan state, workers, clients, last seen days ago, version].
const tenants = [];
const periods = [];
const slips = [];
const devices = [];
const members = [];
const holds = [];
const overrides = [];
const notes = [];
const money = [];
const backups = [];
const audit = [];
const costs = [];
const settings = { bank_name: null, account_number: null, iban: null, account_holder: null, trial_days: 15, support_contact: null, updated_at_utc: ago(15) };

function tenant(name, email, signupDaysAgo, extra = {}) {
  const t = { tenant_id: randomUUID(), name, created_at_utc: ago(signupDaysAgo), is_test: false, workers: 0, clients: 0, reported: ago(0, 2), ...extra };
  tenants.push(t);
  const user = randomUUID();
  members.push({ tenant_id: t.tenant_id, user_id: user, email, role: "owner", since: t.created_at_utc, revoked_at: null, banned_until: null, confirmed: extra.confirmed ?? true });
  devices.push({ id: randomUUID(), tenant_id: t.tenant_id, label: extra.phone ?? "Samsung A15", platform: "android", app_version: extra.version ?? "0.1.0", last_seen: extra.seen ?? ago(0, 1), since: t.created_at_utc, off_at: null, user_email: email });
  periods.push(period(t, "plan", "trial", "trial", now() - signupDaysAgo * day, now() - signupDaysAgo * day + 15 * day, 0));
  return t;
}

function period(t, kind, code, source, start, end, amount, extra = {}) {
  return {
    id: randomUUID(), tenant_id: t.tenant_id, plan_code: code, plan_version: 1, source, slip_id: null, starts_at_utc: iso(start), ends_at_utc: iso(end),
    anchor_at_utc: iso(start), anchor_months: source === "slip" ? 1 : 0, amount_fils: amount, bank_reference: null, received_on: null, note: null,
    revoked_at_utc: null, revoke_reason: null, created_at_utc: iso(start), kind, cut_at: null, ...extra,
  };
}

function slip(t, code, months, covers, sentDaysAgo, state = "waiting", extra = {}) {
  const p = plan(code);
  const s = {
    id: randomUUID(), tenant_id: t.tenant_id, plan_code: code, plan_version: 1, months, covers,
    expected_fils: months * (covers === "plan" ? p.price_fils : covers === "addon" ? p.addon_price_fils : p.price_fils + p.addon_price_fils),
    file_path: `${t.tenant_id}/${randomUUID()}.jpg`, state, refuse_reason: null, submitted_by: members.find((m) => m.tenant_id === t.tenant_id).user_id,
    submitted_at_utc: ago(sentDaysAgo, 2), decided_at_utc: state === "waiting" ? null : ago(sentDaysAgo - 1), payer_bank: null, payer_last4: null, file_missing: false, ...extra,
  };
  slips.push(s);
  return s;
}

function paid(t, code, startDaysAgo, months, ref, bank, last4, covers = "plan") {
  const s = slip(t, code, months, covers, startDaysAgo + 1, "accepted", { payer_bank: bank, payer_last4: last4 });
  const start = now() - startDaysAgo * day;
  const p = plan(code);
  periods.push(period(t, "plan", code, "slip", start, start + months * 30 * day, months * p.price_fils, { slip_id: s.id, bank_reference: ref, received_on: dateOnly(start - day), anchor_months: months }));
  if (covers === "plan_addon") periods.push(period(t, "addon", code, "slip", start, start + months * 30 * day, months * p.addon_price_fils, { slip_id: s.id, bank_reference: ref, received_on: dateOnly(start - day), anchor_months: months }));
  log("accept_slip", t.tenant_id, s.id, `bank reference ${ref}`, { state: "waiting" }, { state: "accepted" }, start);
  return s;
}

function log(action, tenant_id, target_id, reason, before, after, at = now()) {
  audit.push({ id: randomUUID(), at_utc: iso(at), actor_id: owner, action, tenant_id, target_id, reason, before, after });
}

const gulf = tenant("Gulf Star Manpower", "owner@gulfstar.example", 23, { workers: 28, clients: 6 });
paid(gulf, "mid", 8, 1, "FT2611180311", "Emirates Islamic", "2290");
const noor = tenant("Al Noor Labour Supply", "alnoor@mail.example", 82, { workers: 17, clients: 4, seen: ago(1, 3) });
paid(noor, "small", 66, 1, "FT2609210044", "Mashreq", "1187");
paid(noor, "small", 36, 1, "FT2610210102", "Mashreq", "1187");
paid(noor, "small", 6, 1, "FT2611200019", "Mashreq", "1187");
const rose = tenant("Desert Rose Services", "rose.ops@mail.example", 12, { workers: 6, clients: 2, seen: ago(5), version: "0.1.0" });
slip(rose, "small", 3, "plan_addon", 1);
const sahil = tenant("Sahil Workforce", "sahil.hr@mail.example", 12, { workers: 9, clients: 3 });
slip(sahil, "small", 1, "plan", 0);
const bright = tenant("Bright Way Contracting", "brightway@mail.example", 70, { workers: 11, clients: 3, seen: ago(19) });
paid(bright, "small", 55, 1, "FT2610020071", "ADCB", "0418");
slip(bright, "small", 1, "plan", 3, "waiting", { file_missing: true });
const fajr = tenant("Fajr Builders", "fajr.hr@mail.example", 49, { workers: 24, clients: 7, seen: ago(1, 9) });
paid(fajr, "mid", 34, 3, "MR2610230908", "Mashreq", "5562", "plan_addon");
const hands = tenant("Emirates Hands", "eh.office@mail.example", 55, { workers: 12, clients: 4 });
paid(hands, "small", 25, 1, "FT2611010550", "FAB", "7731");
const palm = tenant("Palm Crew", "palm.crew@mail.example", 0, { workers: 0, clients: 0, confirmed: false });
const test = tenant("Namoona test company", "owner.test@mail.example", 30, { is_test: true, workers: 3, clients: 1 });
backups.push({ tenant_id: gulf.tenant_id, id: randomUUID(), size_bytes: 3_400_000, finished_at: ago(0, 1), keep_until: null });
backups.push({ tenant_id: fajr.tenant_id, id: randomUUID(), size_bytes: 5_100_000, finished_at: ago(1), keep_until: ahead(29) });
notes.push({ id: randomUUID(), tenant_id: gulf.tenant_id, body: "Referral, Al Noor se. Large plan mein dilchaspi.", at_utc: ago(3), actor_id: owner });
costs.push({ id: randomUUID(), month: dateOnly(now()).slice(0, 7) + "-01", item: "Supabase", amount_fils: 0, note: "free plan", created_at_utc: ago(2) });
void palm; void test;

// Account rows as private.account_row builds them.
function live(t) { return holds.find((h) => h.tenant_id === t.tenant_id && !h.lifted_at_utc && (!h.until_utc || Date.parse(h.until_utc) > now())) ?? null; }
function end(p) { return p.cut_at && p.cut_at < p.ends_at_utc ? p.cut_at : p.ends_at_utc; }
function current(t) {
  const n = iso(now());
  return periods.filter((p) => p.tenant_id === t.tenant_id && p.kind === "plan" && !p.revoked_at_utc && p.starts_at_utc <= n && end(p) > n)
    .sort((a, b) => (b.plan_code !== "trial") - (a.plan_code !== "trial") || (b.source === "slip") - (a.source === "slip") || b.ends_at_utc.localeCompare(a.ends_at_utc))[0] ?? null;
}
function cap(t, what, base) {
  if (base === null) return null;
  const o = overrides.filter((x) => x.tenant_id === t.tenant_id && x.what === what && !x.ended_at_utc && Date.parse(x.until_utc) > now());
  return Math.max(base, ...o.map((x) => x.cap));
}
function row(t) {
  const cur = current(t);
  const hold = live(t);
  const own = members.find((m) => m.tenant_id === t.tenant_id && m.role === "owner");
  const devs = devices.filter((d) => d.tenant_id === t.tenant_id);
  const mine = periods.filter((p) => p.tenant_id === t.tenant_id);
  const p = cur ? plan(cur.plan_code) : null;
  const addon = mine.filter((x) => x.kind === "addon" && !x.revoked_at_utc && end(x) > iso(now())).map(end).sort().pop() ?? null;
  return {
    tenant_id: t.tenant_id, name: t.name, created_at: t.created_at_utc, is_test: t.is_test, owner_email: own?.email ?? null, email_confirmed: own?.confirmed ?? null,
    state: hold ? "held" : cur ? (cur.plan_code === "trial" ? "trial" : "paid") : mine.some((x) => x.kind === "plan") ? "ended" : "none",
    plan: cur?.plan_code ?? null, plan_name: p?.name ?? null,
    plan_ends_at: mine.filter((x) => x.kind === "plan" && !x.revoked_at_utc).map(end).sort().pop() ?? null, addon_ends_at: addon,
    hold: hold ? { id: hold.id, kind: hold.kind, until: hold.until_utc, told: hold.told } : null,
    phones_on: devs.filter((d) => !d.off_at).length, last_seen: devs.map((d) => d.last_seen).sort().pop() ?? null, app_version: devs[0]?.app_version ?? null,
    workers: t.workers, clients: t.clients, reported_at: t.reported,
    limits: p ? { workers: cap(t, "workers", p.max_workers), clients: cap(t, "clients", p.max_clients), managers: cap(t, "managers", p.max_managers) } : null,
    slips_waiting: slips.filter((s) => s.tenant_id === t.tenant_id && s.state === "waiting").length,
    paid_fils: mine.filter((x) => x.source === "slip").reduce((s, x) => s + x.amount_fils, 0) - money.filter((m) => m.tenant_id === t.tenant_id && m.kind === "refund").reduce((s, m) => s + m.amount_fils, 0),
  };
}

function story(t) {
  const own = members.find((m) => m.tenant_id === t.tenant_id && m.role === "owner");
  return [
    { at: t.created_at_utc, what: "account_made", detail: own.email },
    own.confirmed ? { at: t.created_at_utc, what: "email_confirmed", detail: own.email } : null,
    { at: t.created_at_utc, what: "company_made", detail: t.name },
    ...periods.filter((p) => p.tenant_id === t.tenant_id).map((p) => ({ at: p.created_at_utc, what: `period_${p.source}`, detail: `${p.kind} ${p.plan_code} ${p.starts_at_utc.slice(0, 10)} ${p.ends_at_utc.slice(0, 10)}` })),
    ...slips.filter((s) => s.tenant_id === t.tenant_id).map((s) => ({ at: s.submitted_at_utc, what: "slip_sent", detail: `${s.plan_code} ${s.months} ${s.expected_fils}` })),
    ...devices.filter((d) => d.tenant_id === t.tenant_id).map((d) => ({ at: d.since, what: "phone_added", detail: d.label })),
    ...audit.filter((a) => a.tenant_id === t.tenant_id).map((a) => ({ at: a.at_utc, what: `admin_${a.action}`, detail: a.reason })),
  ].filter(Boolean).sort((a, b) => b.at.localeCompare(a.at));
}

const strip = ({ file_missing, ...s }) => s;
const userOf = (id) => members.find((m) => m.user_id === id);

function mrrAt(at, includeTest) {
  const t0 = iso(at);
  let total = 0;
  for (const t of tenants.filter((x) => includeTest || !x.is_test)) {
    for (const kind of ["plan", "addon"]) {
      const p = periods.filter((x) => x.tenant_id === t.tenant_id && x.kind === kind && x.source === "slip" && !x.revoked_at_utc && x.starts_at_utc <= t0 && end(x) > t0)
        .sort((a, b) => b.ends_at_utc.localeCompare(a.ends_at_utc))[0];
      if (p) total += kind === "plan" ? plan(p.plan_code).price_fils : plan(p.plan_code).addon_price_fils;
    }
  }
  return total;
}

class Refusal extends Error {}
const refuse = (m) => { throw new Refusal(m); };
const needCode = (claims) => { if (!(claims.amr ?? []).some((a) => a.method === "totp" && a.timestamp > now() / 1000 - 300)) refuse("type the code again"); };
const why = (r) => { if (!r || r.trim().length < 3) refuse("say why"); };
const tenantOf = (id) => tenants.find((t) => t.tenant_id === id) ?? refuse("no such account");

const rpcs = {
  admin_accounts: ({ p_include_test }) => tenants.filter((t) => p_include_test || !t.is_test).map(row).sort((a, b) => b.created_at.localeCompare(a.created_at)),
  admin_account: ({ p_tenant }) => {
    const t = tenantOf(p_tenant);
    return {
      ...row(t),
      members: members.filter((m) => m.tenant_id === t.tenant_id).map(({ confirmed, tenant_id, ...m }) => m),
      devices: devices.filter((d) => d.tenant_id === t.tenant_id).map(({ tenant_id, ...d }) => d),
      periods: periods.filter((p) => p.tenant_id === t.tenant_id).sort((a, b) => b.starts_at_utc.localeCompare(a.starts_at_utc)),
      slips: slips.filter((s) => s.tenant_id === t.tenant_id).map(strip).sort((a, b) => b.submitted_at_utc.localeCompare(a.submitted_at_utc)),
      money_entries: money.filter((m) => m.tenant_id === t.tenant_id),
      holds: holds.filter((h) => h.tenant_id === t.tenant_id).sort((a, b) => b.created_at_utc.localeCompare(a.created_at_utc)),
      overrides: overrides.filter((o) => o.tenant_id === t.tenant_id),
      notes: notes.filter((n) => n.tenant_id === t.tenant_id).sort((a, b) => b.at_utc.localeCompare(a.at_utc)),
      backups: backups.filter((b) => b.tenant_id === t.tenant_id).map(({ tenant_id, ...b }) => b),
      story: story(t),
    };
  },
  admin_overview: ({ p_from, p_to, p_include_test }) => {
    const rows = tenants.filter((t) => p_include_test || !t.is_test).map(row);
    const kept = new Set(rows.map((r) => r.tenant_id));
    const from = p_from.slice(0, 10), to = p_to.slice(0, 10);
    const cash = (a, b) => periods.filter((p) => kept.has(p.tenant_id) && p.source === "slip" && p.received_on >= a && p.received_on <= b).reduce((s, p) => s + p.amount_fils, 0)
      - money.filter((m) => kept.has(m.tenant_id) && m.kind === "refund" && m.on_date >= a && m.on_date <= b).reduce((s, m) => s + m.amount_fils, 0);
    const m0 = new Date(p_to.slice(0, 7) + "-01T00:00:00Z").getTime();
    const months = Array.from({ length: 12 }, (_, i) => { const d = new Date(m0); d.setUTCMonth(d.getUTCMonth() - 11 + i); return d.toISOString().slice(0, 10); });
    const trials = periods.filter((p) => kept.has(p.tenant_id) && p.source === "trial" && p.starts_at_utc >= p_from && p.starts_at_utc <= p_to);
    const opening = mrrAt(m0, p_include_test), closing = mrrAt(Math.min(Date.parse(p_to), m0 + 31 * day), p_include_test);
    const mix = {};
    for (const r of rows) mix[r.plan ?? r.state] = (mix[r.plan ?? r.state] ?? 0) + 1;
    return {
      fetched_at: iso(now()),
      accounts: { total: rows.length, trial: rows.filter((r) => r.state === "trial").length, paying: rows.filter((r) => r.state === "paid").length, ended: rows.filter((r) => r.state === "ended").length, held: rows.filter((r) => r.state === "held").length },
      mrr_fils: mrrAt(Date.parse(p_to), p_include_test), cash_fils: cash(from, to),
      trial_to_paid: { started: trials.length, paid: trials.filter((p) => periods.some((x) => x.tenant_id === p.tenant_id && x.source === "slip")).length },
      slips_waiting: slips.filter((s) => kept.has(s.tenant_id) && s.state === "waiting").length,
      today: {
        slips: slips.filter((s) => kept.has(s.tenant_id) && s.state === "waiting").sort((a, b) => a.submitted_at_utc.localeCompare(b.submitted_at_utc)).map((s) => ({ id: s.id, tenant_id: s.tenant_id, name: tenantOf(s.tenant_id).name, plan: s.plan_code, months: s.months, covers: s.covers, expected_fils: s.expected_fils, sent_at: s.submitted_at_utc, file_arrived: !s.file_missing })),
        over_limit: rows.filter((r) => r.limits && ((r.limits.workers !== null && r.workers > r.limits.workers) || (r.limits.clients !== null && r.clients > r.limits.clients))),
        trials_ending: rows.filter((r) => r.state === "trial" && Date.parse(r.plan_ends_at) < now() + 5 * day),
        offline: rows.filter((r) => (r.state === "trial" || r.state === "paid") && (!r.last_seen || Date.parse(r.last_seen) < now() - 7 * day)),
      },
      cash_by_month: months.map((m) => { const e = new Date(m); e.setUTCMonth(e.getUTCMonth() + 1); return { month: m, cash_fils: cash(m, iso(e.getTime() - day).slice(0, 10)) }; }),
      mrr_bridge: { month: iso(m0).slice(0, 10), opening, new: Math.max(0, closing - opening), reactivation: 0, expansion: 0, contraction: 0, churn: Math.max(0, opening - closing), closing },
      plan_mix: mix,
      addon_accounts: rows.filter((r) => r.addon_ends_at).length,
      costs_fils: costs.filter((c) => c.month === iso(m0).slice(0, 10)).reduce((s, c) => s + c.amount_fils, 0),
    };
  },
  admin_slips: ({ p_from, p_to }) => slips.filter((s) => s.submitted_at_utc >= p_from && s.submitted_at_utc <= p_to).sort((a, b) => b.submitted_at_utc.localeCompare(a.submitted_at_utc)).map((s) => {
    const t = tenantOf(s.tenant_id);
    const u = userOf(s.submitted_by);
    const mine = periods.filter((p) => p.slip_id === s.id);
    return { ...strip(s), tenant_name: t.name, is_test: t.is_test, sender_email: u?.email ?? null, sender_role: u?.role ?? null, plan_name: plan(s.plan_code).name, periods: mine, money_entries: money.filter((m) => mine.some((p) => p.id === m.subscription_id)) };
  }),
  admin_audit: ({ p_from, p_to }) => audit.filter((a) => a.at_utc >= p_from && a.at_utc <= p_to).sort((a, b) => b.at_utc.localeCompare(a.at_utc))
    .map((a) => ({ ...a, actor_email: "malik@platform.example", tenant_name: tenants.find((t) => t.tenant_id === a.tenant_id)?.name ?? null })),
  admin_settings: () => ({
    admins: [{ user_id: owner, email: "malik@platform.example", role: "owner", added_at: ago(15), totp: factorVerified }],
    platform: settings, plans, costs: [...costs].sort((a, b) => b.month.localeCompare(a.month)),
    test_accounts: tenants.filter((t) => t.is_test).map((t) => ({ tenant_id: t.tenant_id, name: t.name })),
  }),

  admin_note: ({ p_tenant, p_body }) => { tenantOf(p_tenant); notes.push({ id: randomUUID(), tenant_id: p_tenant, body: p_body.trim(), at_utc: iso(now()), actor_id: owner }); log("note", p_tenant, null, `note: ${p_body}`, null, null); },
  admin_accept_slip: (a, claims) => {
    const s = slips.find((x) => x.id === a.p_slip) ?? refuse("no such slip");
    if (s.state !== "waiting") refuse("this slip was decided already");
    if (!a.p_amount_fils || !a.p_bank_reference || !a.p_received_on) refuse("the amount received, the bank reference and the date received are needed");
    if (a.p_start_now) needCode(claims);
    const t = tenantOf(s.tenant_id);
    if (a.p_start_now) for (const p of periods.filter((x) => x.tenant_id === t.tenant_id && x.kind === "plan" && x.plan_code !== "trial" && !x.revoked_at_utc && end(x) > iso(now()))) p.cut_at = iso(now());
    const prev = periods.filter((x) => x.tenant_id === t.tenant_id && x.kind === "plan" && x.plan_code !== "trial" && !x.revoked_at_utc && end(x) > iso(now())).sort((x, y) => end(y).localeCompare(end(x)))[0];
    const start = prev ? Date.parse(end(prev)) : now();
    const p = period(t, "plan", s.plan_code, "slip", start, start + s.months * 30 * day, a.p_amount_fils, { slip_id: s.id, bank_reference: a.p_bank_reference, received_on: a.p_received_on, anchor_months: s.months, note: a.p_note });
    periods.push(p);
    if (a.p_start_now && a.p_credit_days > 0) periods.push(period(t, "plan", s.plan_code, "grant", Date.parse(p.ends_at_utc), Date.parse(p.ends_at_utc) + a.p_credit_days * day, 0, { note: "credit" }));
    Object.assign(s, { state: "accepted", decided_at_utc: iso(now()), payer_bank: a.p_payer_bank, payer_last4: a.p_payer_last4 });
    log("accept_slip", t.tenant_id, s.id, `bank reference ${a.p_bank_reference}`, { state: "waiting" }, { state: "accepted", credit_days: a.p_credit_days });
    return p.id;
  },
  admin_refuse_slip: ({ p_slip, p_reason }) => {
    why(p_reason);
    const s = slips.find((x) => x.id === p_slip) ?? refuse("no such slip");
    if (s.state !== "waiting") refuse("this slip was decided already");
    Object.assign(s, { state: "refused", refuse_reason: p_reason, decided_at_utc: iso(now()) });
    log("refuse_slip", s.tenant_id, s.id, p_reason, { state: "waiting" }, { state: "refused" });
  },
  admin_revoke_period: ({ p_period, p_reason }) => {
    why(p_reason);
    const p = periods.find((x) => x.id === p_period) ?? refuse("no such period");
    Object.assign(p, { revoked_at_utc: iso(now()), revoke_reason: p_reason });
    log("revoke_period", p.tenant_id, p.id, p_reason, null, { revoked_at_utc: p.revoked_at_utc });
  },
  admin_give_days: ({ p_tenant, p_kind, p_plan_code, p_days, p_reason }) => {
    why(p_reason);
    const t = tenantOf(p_tenant);
    if (!(p_days >= 1 && p_days <= 366)) refuse("from 1 to 366 days");
    const code = p_plan_code ?? periods.filter((x) => x.tenant_id === t.tenant_id && x.kind === "plan" && x.plan_code !== "trial").map((x) => x.plan_code).pop() ?? refuse("say which plan");
    const run = periods.filter((x) => x.tenant_id === t.tenant_id && x.kind === p_kind && !x.revoked_at_utc && end(x) > iso(now())).map(end).sort().pop();
    const start = run ? Date.parse(run) : now();
    periods.push(period(t, p_kind, code, "grant", start, start + p_days * day, 0, { note: p_reason }));
    log("give_days", t.tenant_id, null, p_reason, null, { kind: p_kind, plan: code, days: p_days, from: iso(start) });
  },
  admin_limit_override: ({ p_tenant, p_what, p_cap, p_until, p_reason }) => {
    why(p_reason);
    if (Date.parse(p_until) <= now()) refuse("the end is in the past");
    overrides.push({ id: randomUUID(), tenant_id: tenantOf(p_tenant).tenant_id, what: p_what, cap: p_cap, until_utc: p_until, reason: p_reason, created_at_utc: iso(now()), created_by: owner, ended_at_utc: null });
    log("limit_override", p_tenant, null, p_reason, null, { what: p_what, cap: p_cap, until: p_until });
  },
  admin_end_override: ({ p_override, p_reason }) => {
    why(p_reason);
    const o = overrides.find((x) => x.id === p_override && !x.ended_at_utc) ?? refuse("no live override with this id");
    o.ended_at_utc = iso(now());
    log("end_override", o.tenant_id, o.id, p_reason, null, { what: o.what, cap: o.cap });
  },
  admin_money_entry: (a, claims) => {
    needCode(claims);
    why(a.p_reason);
    const p = periods.find((x) => x.id === a.p_period && x.tenant_id === a.p_tenant) ?? refuse("no such period");
    if (a.p_kind === "refund") {
      const back = money.filter((m) => m.subscription_id === p.id && m.kind === "refund").reduce((s, m) => s + m.amount_fils, 0);
      if (!(a.p_amount_fils > 0 && a.p_amount_fils <= p.amount_fils - back)) refuse("more than was paid");
    } else if (!a.p_field || !a.p_value) refuse("say what is corrected and to what");
    money.push({ id: randomUUID(), tenant_id: a.p_tenant, kind: a.p_kind, subscription_id: p.id, amount_fils: a.p_kind === "refund" ? a.p_amount_fils : 0, field: a.p_field, value: a.p_value, reference: a.p_reference, on_date: a.p_on_date, reason: a.p_reason, created_at_utc: iso(now()), created_by: owner });
    log(a.p_kind, a.p_tenant, p.id, a.p_reason, null, { amount_fils: a.p_amount_fils, field: a.p_field, value: a.p_value });
  },
  admin_hold: (a, claims) => {
    needCode(claims);
    why(a.p_reason);
    const t = tenantOf(a.p_tenant);
    if (a.p_until && Date.parse(a.p_until) <= now()) refuse("the end is in the past");
    if (live(t)) refuse("this account is held already");
    holds.push({ id: randomUUID(), tenant_id: t.tenant_id, kind: a.p_kind, until_utc: a.p_until, told: a.p_told, note: a.p_note, created_at_utc: iso(now()), created_by: owner, lifted_at_utc: null, lifted_by: null, lift_reason: null });
    log("hold", t.tenant_id, null, a.p_reason, null, { kind: a.p_kind, until: a.p_until, told: a.p_told });
  },
  admin_lift_hold: ({ p_hold, p_reason }, claims) => {
    needCode(claims);
    why(p_reason);
    const h = holds.find((x) => x.id === p_hold && !x.lifted_at_utc) ?? refuse("no live hold with this id");
    Object.assign(h, { lifted_at_utc: iso(now()), lifted_by: owner, lift_reason: p_reason });
    log("lift_hold", h.tenant_id, h.id, p_reason, null, { kind: h.kind });
  },
  admin_free_trial_claim: ({ p_email, p_reason }) => {
    why(p_reason);
    const m = members.find((x) => x.email === p_email.trim()) ?? refuse("no trial claim for this email");
    log("free_trial_claim", m.tenant_id, null, p_reason, [{ kind: "email" }, { kind: "phone" }], null);
    return 2;
  },
  admin_set_test: ({ p_tenant, p_is_test, p_reason }) => { why(p_reason); const t = tenantOf(p_tenant); log("set_test", t.tenant_id, null, p_reason, { is_test: t.is_test }, { is_test: p_is_test }); t.is_test = p_is_test; },
  admin_rename: ({ p_tenant, p_name, p_reason }) => { why(p_reason); const t = tenantOf(p_tenant); log("rename", t.tenant_id, null, p_reason, { name: t.name }, { name: p_name }); t.name = p_name.trim(); },
  admin_phone: ({ p_device_row, p_off, p_reason }) => {
    why(p_reason);
    const d = devices.find((x) => x.id === p_device_row) ?? refuse("no such phone");
    if (p_off === !!d.off_at) refuse("the phone is that way already");
    d.off_at = p_off ? iso(now()) : null;
    log(p_off ? "phone_off" : "phone_on", d.tenant_id, d.id, p_reason, null, null);
  },
  admin_add_cost: ({ p_month, p_item, p_amount_fils, p_note }) => { costs.push({ id: randomUUID(), month: p_month.slice(0, 7) + "-01", item: p_item, amount_fils: p_amount_fils, note: p_note, created_at_utc: iso(now()) }); log("add_cost", null, null, `cost: ${p_item}`, null, { amount_fils: p_amount_fils }); },
  admin_save_settings: (a) => { why(a.p_reason); Object.assign(settings, { bank_name: a.p_bank_name || null, account_number: a.p_account_number || null, iban: a.p_iban || null, account_holder: a.p_account_holder || null, support_contact: a.p_support_contact || null, updated_at_utc: iso(now()) }); log("save_settings", null, null, a.p_reason, null, null); },
  admin_change_plan: ({ p_tenant, p_plan_code, p_days, p_reason }, claims) => {
    needCode(claims);
    why(p_reason);
    const t = tenantOf(p_tenant);
    if (!(p_days >= 1 && p_days <= 366)) refuse("from 1 to 366 days");
    plan(p_plan_code) ?? refuse("no such plan");
    for (const p of periods.filter((x) => x.tenant_id === t.tenant_id && x.kind === "plan" && x.plan_code !== "trial" && !x.revoked_at_utc && end(x) > iso(now()))) p.cut_at = iso(now());
    const g = period(t, "plan", p_plan_code, "grant", now(), now() + p_days * day, 0, { note: p_reason });
    periods.push(g);
    log("change_plan", t.tenant_id, g.id, p_reason, null, { plan: p_plan_code, days: p_days });
    return g.id;
  },
};

// Tokens shaped like Supabase's; nothing here checks a signature.
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
function session(aal) {
  const t = Math.floor(now() / 1000);
  const amr = [{ method: "password", timestamp: t }];
  if (aal === "aal2") amr.push({ method: "totp", timestamp: lastTotp || t });
  const access = `${b64({ alg: "HS256", typ: "JWT" })}.${b64({ sub: owner, email: "malik@platform.example", role: "authenticated", aal, amr, exp: t + 3600, iat: t })}.sample`;
  return { access_token: access, token_type: "bearer", expires_in: 3600, expires_at: t + 3600, refresh_token: `${aal}-refresh`, user: user() };
}
const user = () => ({
  id: owner, aud: "authenticated", role: "authenticated", email: "malik@platform.example", email_confirmed_at: ago(15), created_at: ago(15), app_metadata: {}, user_metadata: {},
  factors: [{ id: "f0000000-0000-4000-8000-000000000001", friendly_name: "Dashboard", factor_type: "totp", status: factorVerified ? "verified" : "unverified", created_at: ago(15), updated_at: ago(15) }],
});
function claimsOf(req) {
  try { return JSON.parse(Buffer.from((req.headers.authorization ?? "").split(".")[1], "base64url").toString()); } catch { return {}; }
}
const slipPicture = (name) => `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="800" viewBox="0 0 600 800"><rect width="600" height="800" fill="#fffdf8"/><rect x="40" y="40" width="520" height="90" fill="#0b2648"/><text x="60" y="95" font-family="Arial" font-size="28" fill="#fff">Namoona bank slip</text><text x="60" y="200" font-family="Arial" font-size="24" fill="#15201b">${name}</text><text x="60" y="260" font-family="Arial" font-size="22" fill="#5a6259">Sample data, not a real transfer</text></svg>`;

createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const send = (status, body, type = "application/json") => {
    res.writeHead(status, { "Content-Type": type, "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "*", "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS" });
    res.end(type === "application/json" ? JSON.stringify(body ?? null) : body);
  };
  if (req.method === "OPTIONS") return send(204, null);
  let body = {};
  if (req.method === "POST" || req.method === "PUT") {
    const raw = await new Promise((ok) => { let d = ""; req.on("data", (c) => (d += c)); req.on("end", () => ok(d)); });
    try { body = raw ? JSON.parse(raw) : {}; } catch { body = {}; }
  }
  const path = url.pathname;
  try {
    if (path === "/auth/v1/token") {
      if (url.searchParams.get("grant_type") === "refresh_token") return send(200, session(body.refresh_token?.startsWith("aal2") ? "aal2" : "aal1"));
      return body.password ? send(200, session("aal1")) : send(400, { code: "invalid_credentials", message: "Invalid login credentials" });
    }
    if (path === "/auth/v1/user") return send(200, user());
    if (path === "/auth/v1/logout") return send(204, null);
    if (path === "/auth/v1/factors" && req.method === "POST") return send(200, { id: "f0000000-0000-4000-8000-000000000001", type: "totp", friendly_name: "Dashboard", totp: { qr_code: `data:image/svg+xml;utf-8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#fff"/><rect x="1" y="1" width="3" height="3"/><rect x="6" y="1" width="3" height="3"/><rect x="1" y="6" width="3" height="3"/><rect x="5" y="5" width="2" height="2"/></svg>')}`, secret: "SAMPLESECRETNOTREAL", uri: "otpauth://totp/sample" } });
    if (/^\/auth\/v1\/factors\/[^/]+$/.test(path) && req.method === "DELETE") return send(200, { id: path.split("/").pop() });
    if (/^\/auth\/v1\/factors\/[^/]+\/challenge$/.test(path)) return send(200, { id: randomUUID(), type: "totp", expires_at: Math.floor(now() / 1000) + 300 });
    if (/^\/auth\/v1\/factors\/[^/]+\/verify$/.test(path)) {
      if (body.code === "000000") return send(422, { code: "mfa_verification_failed", message: "Invalid TOTP code entered" });
      factorVerified = true;
      lastTotp = Math.floor(now() / 1000);
      return send(200, session("aal2"));
    }
    if (path.startsWith("/rest/v1/rpc/")) {
      const name = path.slice("/rest/v1/rpc/".length);
      const claims = claimsOf(req);
      if (name.startsWith("admin_") && claims.aal !== "aal2") return send(403, { code: "42501", message: "admins only" });
      const fn = rpcs[name];
      if (!fn) return send(404, { code: "PGRST202", message: `no function ${name}` });
      return send(200, fn(body, claims) ?? null);
    }
    if (path.startsWith("/storage/v1/object/sign/payment-slips/")) {
      const file = decodeURIComponent(path.slice("/storage/v1/object/sign/payment-slips/".length));
      const s = slips.find((x) => x.file_path === file);
      if (req.method === "GET") return send(200, slipPicture(s ? tenantOf(s.tenant_id).name : ""), "image/svg+xml");
      if (!s || s.file_missing) return send(400, { statusCode: "404", error: "not_found", message: "Object not found" });
      return send(200, { signedURL: `/object/sign/payment-slips/${encodeURIComponent(file)}?token=sample` });
    }
    if (path === "/functions/v1/admin") {
      const t = tenants.find((x) => x.tenant_id === body.tenant_id);
      if (!t) return send(400, { error: "bad_request" });
      const h = live(t);
      for (const m of members.filter((x) => x.tenant_id === t.tenant_id)) m.banned_until = h?.kind === "block" ? (h.until_utc ?? ahead(36500)) : null;
      return send(200, { ok: true, banned: h?.kind === "block", users: members.filter((x) => x.tenant_id === t.tenant_id).length });
    }
    send(404, { message: `fake cloud: nothing at ${path}` });
  } catch (e) {
    if (e instanceof Refusal) return send(400, { code: "P0001", message: e.message, details: null, hint: null });
    console.error(e);
    send(500, { message: String(e) });
  }
}).listen(port, "127.0.0.1", () => console.log(`fake cloud on http://127.0.0.1:${port}, sample data only`));
