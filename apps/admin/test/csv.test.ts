import { expect, test } from "vitest";
import { toCsv } from "../lib/csv";

test("cells with a comma, a quote or a new line are quoted; lines end with CRLF", () => {
  expect(toCsv([["Company", "Kul"], ["Gulf Star, LLC", "1,455.00"], ['Say "hi"', "a\nb"]])).toBe(
    'Company,Kul\r\n"Gulf Star, LLC","1,455.00"\r\n"Say ""hi""","a\nb"\r\n',
  );
});

test("a cell a spreadsheet would run as a formula is opened as text", () => {
  expect(toCsv([["=HYPERLINK(1)", "+1", "-2", "@x", "ok"]])).toBe("'=HYPERLINK(1),'+1,'-2,'@x,ok\r\n");
});
