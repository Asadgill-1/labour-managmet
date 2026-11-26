// CSV for the accountant and for Excel. A cell a spreadsheet would run as a formula is opened as text.

function cell(v: string): string {
  const safe = /^[=+\-@]/.test(v) ? `'${v}` : v;
  return /[",\r\n]/.test(safe) ? `"${safe.replaceAll('"', '""')}"` : safe;
}

export const toCsv = (rows: string[][]) => rows.map((r) => r.map(cell).join(",") + "\r\n").join("");

/** Saves the rows as a file; the byte-order mark makes Excel read the names as UTF-8. */
export function downloadCsv(name: string, rows: string[][]): void {
  const url = URL.createObjectURL(new Blob(["﻿" + toCsv(rows)], { type: "text/csv;charset=utf-8" }));
  const a = Object.assign(document.createElement("a"), { href: url, download: name });
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
