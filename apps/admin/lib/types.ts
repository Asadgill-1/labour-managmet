// What the admin_ functions return (supabase/migrations/20261124120000_owner_dashboard.sql). Money in whole fils.

export type AccountState = "held" | "trial" | "paid" | "ended" | "none";
export type Hold = { id: string; kind: "suspend" | "block"; until: string | null; told: string };
export type Limits = { workers: number | null; clients: number | null; managers: number | null };

export type AccountRow = {
  tenant_id: string;
  name: string;
  created_at: string;
  is_test: boolean;
  owner_email: string | null;
  email_confirmed: boolean | null;
  state: AccountState;
  plan: string | null;
  plan_name: string | null;
  plan_ends_at: string | null;
  addon_ends_at: string | null;
  hold: Hold | null;
  phones_on: number;
  last_seen: string | null;
  app_version: string | null;
  workers: number | null;
  clients: number | null;
  reported_at: string | null;
  limits: Limits | null;
  slips_waiting: number;
  paid_fils: number;
  /** From T22d: the consent, when the books last arrived, and this Dubai month's bill and estimate from its summary. */
  consent_at?: string | null;
  book_at?: string | null;
  bill_month?: number | null;
  estimate_month?: number | null;
};

/** admin_account_book: one account's books in the cloud (T22d). */
export type AccountBook = {
  consent_at: string | null;
  consent_version: number | null;
  last_at: string | null;
  records: number;
  counts: { workers: number; clients: number; sites: number; invoices: number } | null;
  firsts: { worker: string | null; attendance: string | null; invoice: string | null } | null;
  months: import("./book").MonthSummary[];
};

/** admin_business: every account's books added up (T22d). */
export type Business = {
  months: import("./book").MonthSummary[];
  accounts: { tenant_id: string; name: string; bill: number; wages: number; estimate: number; invoiced: number; workers: number; clients: number; last_at: string | null }[];
  workers: number;
  clients: number;
  with_books: number;
  consented: number;
  accounts_total: number;
};

export type Period = {
  id: string;
  tenant_id: string;
  plan_code: string;
  plan_version: number;
  source: "trial" | "slip" | "grant";
  slip_id: string | null;
  starts_at_utc: string;
  ends_at_utc: string;
  anchor_at_utc: string;
  anchor_months: number;
  amount_fils: number;
  bank_reference: string | null;
  received_on: string | null;
  note: string | null;
  revoked_at_utc: string | null;
  revoke_reason: string | null;
  created_at_utc: string;
  kind: "plan" | "addon";
  cut_at?: string | null;
};

export type Slip = {
  id: string;
  tenant_id: string;
  plan_code: string;
  plan_version: number;
  months: number;
  expected_fils: number;
  file_path: string;
  state: "waiting" | "accepted" | "refused";
  refuse_reason: string | null;
  submitted_by: string;
  submitted_at_utc: string;
  decided_at_utc: string | null;
  covers: "plan" | "plan_addon" | "addon";
  payer_bank: string | null;
  payer_last4: string | null;
};

export type MoneyEntry = {
  id: string;
  tenant_id: string;
  kind: "refund" | "correction";
  subscription_id: string;
  amount_fils: number;
  field: string | null;
  value: string | null;
  reference: string | null;
  on_date: string;
  reason: string;
  created_at_utc: string;
  created_by: string;
};

export type HoldRow = {
  id: string;
  tenant_id: string;
  kind: "suspend" | "block";
  until_utc: string | null;
  told: string;
  note: string | null;
  created_at_utc: string;
  created_by: string;
  lifted_at_utc: string | null;
  lifted_by: string | null;
  lift_reason: string | null;
};

export type Override = {
  id: string;
  tenant_id: string;
  what: "workers" | "clients" | "managers";
  cap: number;
  until_utc: string;
  reason: string;
  created_at_utc: string;
  created_by: string;
  ended_at_utc: string | null;
};

export type Member = { user_id: string; email: string | null; role: string; since: string; revoked_at: string | null; banned_until?: string | null };
export type Device = { id: string; label: string; platform: string; app_version: string | null; last_seen: string | null; since: string; off_at: string | null; user_email: string | null };
export type Note = { id: string; tenant_id: string; body: string; at_utc: string; actor_id: string };
export type Backup = { id: string; size_bytes: number; finished_at: string; keep_until: string | null };
export type StoryEvent = { at: string; what: string; detail: string | null };

export type Account = AccountRow & {
  members: Member[];
  devices: Device[];
  periods: Period[];
  slips: Slip[];
  money_entries: MoneyEntry[];
  holds: HoldRow[];
  overrides: Override[];
  notes: Note[];
  backups: Backup[];
  story: StoryEvent[];
};

export type TodaySlip = { id: string; tenant_id: string; name: string; plan: string; months: number; covers: Slip["covers"]; expected_fils: number; sent_at: string; file_arrived: boolean };

export type Overview = {
  fetched_at: string;
  accounts: { total: number; trial: number; paying: number; ended: number; held: number };
  mrr_fils: number;
  cash_fils: number;
  trial_to_paid: { started: number; paid: number };
  slips_waiting: number;
  today: { slips: TodaySlip[]; over_limit: AccountRow[]; trials_ending: AccountRow[]; offline: AccountRow[] };
  cash_by_month: { month: string; cash_fils: number }[];
  mrr_bridge: { month: string; opening: number; new: number; reactivation: number; expansion: number; contraction: number; churn: number; closing: number };
  plan_mix: Record<string, number>;
  addon_accounts: number;
  costs_fils: number;
};

export type SlipFull = Slip & {
  tenant_name: string;
  is_test: boolean;
  sender_email: string | null;
  sender_role: string | null;
  plan_name: string;
  periods: Period[];
  money_entries: MoneyEntry[];
};

export type AuditRow = {
  id: string;
  at_utc: string;
  actor_id: string;
  action: string;
  tenant_id: string | null;
  target_id: string | null;
  reason: string;
  before: unknown;
  after: unknown;
  actor_email: string | null;
  tenant_name: string | null;
};

export type Plan = {
  code: string;
  version: number;
  name: string;
  price_fils: number;
  addon_price_fils: number;
  max_workers: number | null;
  max_clients: number | null;
  max_managers: number | null;
  on_sale: boolean;
  sort_order: number;
  backup_keep_days: number;
  created_at_utc: string;
};

export type Cost = { id: string; month: string; item: string; amount_fils: number; note: string | null; created_at_utc: string };

export type Settings = {
  admins: { user_id: string; email: string; role: string; added_at: string; totp: boolean }[];
  platform: {
    bank_name: string | null;
    account_number: string | null;
    iban: string | null;
    account_holder: string | null;
    trial_days: number;
    support_contact: string | null;
    updated_at_utc: string;
  };
  plans: Plan[];
  costs: Cost[];
  test_accounts: { tenant_id: string; name: string }[];
};
