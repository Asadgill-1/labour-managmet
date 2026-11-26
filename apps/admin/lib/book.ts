// The customers' books as the app sends them (D-081 part 2, D-084). The month's figures are worked out on the phone,
// with the code that draws "Malik ki sheet"; the dashboard only adds them up, so the two never disagree. Fils.

export type MonthSummary = {
  month: string;
  bill: number;
  wages: number;
  salaries: number;
  allowances: number;
  cuts: number;
  room_in: number;
  room_out: number;
  expenses: number;
  estimate: number;
  days: number;
  invoices: number;
  invoiced: number;
  credited: number;
  workers?: number;
  no_rate?: number;
  accounts?: number;
};

export type Figures = Omit<MonthSummary, "month" | "workers" | "no_rate" | "accounts">;

const keys = ["bill", "wages", "salaries", "allowances", "cuts", "room_in", "room_out", "expenses", "estimate", "days", "invoices", "invoiced", "credited"] as const;

/** Each figure added up over [rows]. A figure that is not a whole number means a broken record, so it stops here. */
export function addMonths(rows: Partial<MonthSummary>[]): Figures {
  const total = Object.fromEntries(keys.map((k) => [k, 0])) as Figures;
  for (const r of rows) {
    for (const k of keys) {
      const v = r[k] ?? 0;
      if (!Number.isSafeInteger(v)) throw new Error(`${k} is not a whole number: ${v}`);
      total[k] += v;
    }
  }
  return total;
}

/** Every month from [from] to [to], both `YYYY-MM`, in order. */
export function monthsBetween(from: string, to: string): string[] {
  const out: string[] = [];
  let [y, m] = from.split("-").map(Number);
  const [ty, tm] = to.split("-").map(Number);
  while (y < ty || (y === ty && m <= tm)) {
    out.push(`${y}-${String(m).padStart(2, "0")}`);
    [y, m] = m === 12 ? [y + 1, 1] : [y, m + 1];
  }
  return out;
}

/** A month `YYYY-MM` moved by [n] months. */
export function addMonth(month: string, n: number): string {
  const [y, m] = month.split("-").map(Number);
  const i = y * 12 + (m - 1) + n;
  return `${Math.floor(i / 12)}-${String((i % 12) + 1).padStart(2, "0")}`;
}

/** The lines of "Malik ki sheet", as the app shows them: costs negative, the two totals marked. */
export function sheetLines(f: Figures): { label: string; fils: number; total?: boolean }[] {
  return [
    { label: "Clients ka bill", fils: f.bill },
    { label: "Us kaam ki mazdoori", fils: -f.wages },
    { label: "Mazdoori ke baad bacha", fils: f.bill - f.wages, total: true },
    { label: "Mahana tankhwah, company par nahin bati", fils: -f.salaries },
    { label: "Allowance", fils: -f.allowances },
    { label: "Tankhwah se doosri katoti", fils: f.cuts },
    { label: "Room se aaya, tankhwah aur cash", fils: f.room_in },
    { label: "Room ka kiraya diya", fils: -f.room_out },
    { label: "Doosre kharche", fils: -f.expenses },
    { label: "Andazan nafa, audit shuda nahin", fils: f.estimate, total: true },
  ];
}

export type BookRow = { id: string; version: number; at: string; data: Record<string, unknown> };

export type ColumnKind = "text" | "word" | "fils" | "date" | "minutes" | "flag" | "worker" | "client";

/** The app's own words for the values it keeps by name. */
export const bookWords: Record<string, string> = {
  present: "Hazir", half: "Aadha din", absent: "Ghair hazir",
  advanceGiven: "Advance", salaryPaid: "Tankhwah", roomRentPaid: "Room ka kiraya diya", expense: "Kharcha", advanceReturned: "Advance wapas mila",
  roomRentReceived: "Room ka kiraya mila", clientReceipt: "Company se mila", visaPaid: "Visa ka kharcha", visaReturned: "Visa ka paisa wapas mila",
  invoice: "Invoice", credit: "Credit note", draft: "Draft", issued: "Jaari", credited: "Credit hua",
};
export type BookColumn = { key: string; label: string; kind: ColumnKind };

/** The Kitab tab's lists: which record type, its name, and the columns shown, by the app's own column names. */
export const bookLists: { entity: string; label: string; columns: BookColumn[]; live?: (d: Record<string, unknown>) => boolean }[] = [
  {
    entity: "workers",
    label: "Labour",
    columns: [
      { key: "code", label: "Code", kind: "text" },
      { key: "name", label: "Naam", kind: "text" },
      { key: "trade", label: "Kaam", kind: "text" },
      { key: "phone", label: "Phone", kind: "text" },
      { key: "joining_date", label: "Kab se", kind: "date" },
      { key: "active", label: "Active", kind: "flag" },
    ],
  },
  {
    entity: "clients",
    label: "Companies",
    columns: [
      { key: "name", label: "Naam", kind: "text" },
      { key: "phone", label: "Phone", kind: "text" },
      { key: "trn", label: "TRN", kind: "text" },
      { key: "active", label: "Active", kind: "flag" },
    ],
  },
  {
    entity: "invoices",
    label: "Invoices",
    columns: [
      { key: "number", label: "Number", kind: "text" },
      { key: "issue_date", label: "Tareekh", kind: "date" },
      { key: "client_id", label: "Company", kind: "client" },
      { key: "from_date", label: "Kaam se", kind: "date" },
      { key: "to_date", label: "Kaam tak", kind: "date" },
      { key: "kind", label: "Qisam", kind: "word" },
      { key: "status", label: "Haalat", kind: "word" },
    ],
  },
  {
    entity: "attendance_entries",
    label: "Hazri",
    live: (d) => d.deleted !== 1 && d.superseded !== 1,
    columns: [
      { key: "work_date", label: "Din", kind: "date" },
      { key: "worker_id", label: "Labour", kind: "worker" },
      { key: "client_id", label: "Company", kind: "client" },
      { key: "attendance_status", label: "Haalat", kind: "word" },
      { key: "client_billable_minutes", label: "Company ke ghante", kind: "minutes" },
      { key: "client_amount_fils", label: "Bill", kind: "fils" },
      { key: "worker_amount_fils", label: "Mazdoori", kind: "fils" },
    ],
  },
  {
    entity: "payroll_lines",
    label: "Payroll",
    columns: [
      { key: "period_from", label: "Mahina", kind: "date" },
      { key: "worker_id", label: "Labour", kind: "worker" },
      { key: "earned_fils", label: "Kamaya", kind: "fils" },
      { key: "net_fils", label: "Net", kind: "fils" },
      { key: "payable_fils", label: "Dena", kind: "fils" },
      { key: "reversed", label: "Wapas liya", kind: "flag" },
    ],
  },
  {
    entity: "cash_entries",
    label: "Cash",
    columns: [
      { key: "entry_date", label: "Din", kind: "date" },
      { key: "kind", label: "Qisam", kind: "word" },
      { key: "amount_fils", label: "Raqam", kind: "fils" },
      { key: "worker_id", label: "Labour", kind: "worker" },
      { key: "client_id", label: "Company", kind: "client" },
      { key: "note", label: "Note", kind: "text" },
    ],
  },
];

/** A record's own field as the text a table shows, names looked up for ids. */
export function cellText(column: BookColumn, data: Record<string, unknown>, names: { workers: Map<string, string>; clients: Map<string, string> }, fils: (n: number) => string): string {
  const v = data[column.key];
  if (v === null || v === undefined || v === "") return "";
  switch (column.kind) {
    case "fils":
      return typeof v === "number" ? fils(v) : String(v);
    case "minutes":
      return typeof v === "number" ? `${Math.floor(v / 60)}:${String(v % 60).padStart(2, "0")}` : String(v);
    case "flag":
      return v === 1 || v === true ? "Haan" : "Nahin";
    case "date":
      return typeof v === "string" && /^\d{4}-\d{2}-\d{2}/.test(v) ? `${v.slice(8, 10)}-${v.slice(5, 7)}-${v.slice(0, 4)}` : String(v);
    case "word":
      return bookWords[String(v)] ?? String(v);
    case "worker":
      return names.workers.get(String(v)) ?? String(v);
    case "client":
      return names.clients.get(String(v)) ?? String(v);
    default:
      return String(v);
  }
}

/** A list's records in the order a reader expects: newest day first, or by name where there is no day. */
export function sortRows(columns: BookColumn[], rows: BookRow[]): BookRow[] {
  const day = columns.find((c) => c.kind === "date");
  const name = columns.find((c) => c.kind === "text");
  const key = (r: BookRow) => String(r.data[(day ?? name)?.key ?? "id"] ?? "");
  return [...rows].sort((a, b) => (day ? key(b).localeCompare(key(a)) : key(a).localeCompare(key(b))) || a.id.localeCompare(b.id));
}
