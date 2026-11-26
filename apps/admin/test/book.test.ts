import { describe, expect, it } from "vitest";
import { addMonth, addMonths, bookLists, cellText, monthsBetween, sheetLines } from "../lib/book";
import { showFils } from "../lib/money";

const names = { workers: new Map([["w1", "Ali"]]), clients: new Map([["c1", "Acme"]]) };

describe("the customers' books (T22d)", () => {
  it("addMonths sums every key", () => {
    const t = addMonths([
      { month: "2026-10", bill: 100000, wages: 60000, estimate: 30000, days: 40, invoices: 2, invoiced: 90000 },
      { month: "2026-11", bill: 50000, wages: 45000, estimate: -5000, days: 20, credited: 1000 },
    ]);
    expect(t).toMatchObject({ bill: 150000, wages: 105000, estimate: 25000, days: 60, invoices: 2, invoiced: 90000, credited: 1000, salaries: 0 });
  });

  it("addMonths refuses a fraction", () => {
    expect(() => addMonths([{ bill: 10.5 }])).toThrow("bill is not a whole number");
  });

  it("monthsBetween spans a year end, and addMonth moves across one", () => {
    expect(monthsBetween("2025-11", "2026-02")).toEqual(["2025-11", "2025-12", "2026-01", "2026-02"]);
    expect(monthsBetween("2026-03", "2026-02")).toEqual([]);
    expect(addMonth("2026-01", -1)).toBe("2025-12");
    expect(addMonth("2025-12", 2)).toBe("2026-02");
  });

  it("the sheet's lines are the app's, and its estimate is the app's own figure", () => {
    const lines = sheetLines(addMonths([{ bill: 39900_00, wages: 26100_00, salaries: 2500_00, allowances: 600_00, cuts: 200_00, room_in: 1500_00, room_out: 3000_00, expenses: 1550_00, estimate: 7850_00 }]));
    expect(lines.map((l) => l.fils)).toEqual([39900_00, -26100_00, 13800_00, -2500_00, -600_00, 200_00, 1500_00, -3000_00, -1550_00, 7850_00]);
    expect(lines.filter((l) => l.total).map((l) => l.label)).toEqual(["Mazdoori ke baad bacha", "Andazan nafa, audit shuda nahin"]);
  });

  it("a record's cells read as the table shows them", () => {
    const hazri = bookLists.find((l) => l.entity === "attendance_entries")!;
    const row = { work_date: "2026-11-05", worker_id: "w1", client_id: "c1", attendance_status: "present", client_billable_minutes: 510, client_amount_fils: 13500, worker_amount_fils: 9000, deleted: 0 };
    expect(hazri.columns.map((c) => cellText(c, row, names, showFils))).toEqual(["05-11-2026", "Ali", "Acme", "Hazir", "8:30", "135.00", "90.00"]);
    expect(hazri.live?.(row)).toBe(true);
    expect(hazri.live?.({ ...row, deleted: 1 })).toBe(false);
  });
});
