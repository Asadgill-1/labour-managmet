import { showFils } from "@/lib/money";

const monthName = new Intl.DateTimeFormat("en-GB", { month: "short", timeZone: "UTC" });
const monthYear = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });
export const showMonth = (d: string) => monthYear.format(new Date(`${d.slice(0, 7)}-01T00:00:00Z`));

// A round step of 1, 2 or 5 times a power of ten, so the axis's three lines fall on round dirhams.
function niceStep(aed: number): number {
  if (aed <= 0) return 100;
  const power = 10 ** Math.floor(Math.log10(aed));
  return ([1, 2, 5, 10].find((m) => m * power >= aed) ?? 10) * power;
}

/** Money by month as thin bars, one blue, the running month darker; a table of the same numbers under it. */
export function MonthBars({ rows, label }: { rows: { month: string; fils: number; note?: string }[]; label: string }) {
  const step = niceStep(Math.max(0, ...rows.map((r) => r.fils)) / 100 / 3);
  const top = step * 3;
  const ticks = [top, step * 2, step, 0];
  return (
    <figure className="chart">
      <div className="plot" role="img" aria-label={label}>
        <div className="yaxis" aria-hidden="true">{ticks.map((t) => <span key={t}>{t.toLocaleString("en-US")}</span>)}</div>
        {rows.map((r, i) => (
          <span
            key={r.month}
            className={`bar-v${i === rows.length - 1 ? " now" : ""}`}
            style={{ ["--v" as string]: `${Math.max(1, Math.round((r.fils / 100 / top) * 100))}%` }}
            title={`${showMonth(r.month)}: AED ${showFils(r.fils)}`}
          />
        ))}
      </div>
      <div className="xaxis" aria-hidden="true">{rows.map((r) => <span key={r.month}>{monthName.format(new Date(`${r.month.slice(0, 7)}-01T00:00:00Z`))}</span>)}</div>
      <details>
        <summary>Table mein dekhein</summary>
        <table>
          <thead><tr><th>Mahina</th><th className="num">AED</th></tr></thead>
          <tbody>{rows.map((r, i) => <tr key={r.month}><td>{showMonth(r.month)}{i === rows.length - 1 ? ", abhi tak" : ""}</td><td className="num">{showFils(r.fils)}</td></tr>)}</tbody>
        </table>
      </details>
    </figure>
  );
}

/** Counts as horizontal bars with their share. */
export function CountBars({ rows, label }: { rows: { name: string; n: number }[]; label: string }) {
  const total = rows.reduce((s, r) => s + r.n, 0);
  const most = Math.max(1, ...rows.map((r) => r.n));
  return (
    <ol className="hbars" aria-label={label}>
      {rows.map((r) => (
        <li key={r.name}>
          <span>{r.name}</span>
          <span className="track"><span className="fill" style={{ ["--v" as string]: `${Math.round((r.n / most) * 100)}%` }} /></span>
          <span className="n">{r.n}</span>
          <span className="pct">{total ? `${Math.round((r.n / total) * 100)}%` : "-"}</span>
        </li>
      ))}
    </ol>
  );
}
