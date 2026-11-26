import { expect, test } from "vitest";
import { cloudSays, storyDetail } from "../lib/words";

test("the story's details read as words", () => {
  expect(storyDetail("period_slip", "plan mid 2026-11-18 2026-12-18")).toBe("Plan, Mid, 18 Nov 2026 se 18 Dec 2026");
  expect(storyDetail("slip_sent", "small 3 59700")).toBe("Small, 3 mahine, AED 597.00");
  expect(storyDetail("admin_note", "note: call back")).toBe("note: call back");
  expect(storyDetail("phone_added", null)).toBeNull();
});

test("the cloud's refusals in the owner's words, and anything unknown as it came", () => {
  expect(cloudSays("type the code again")).toBe("Is kaam ke liye MFA code dobara likhein.");
  expect(cloudSays("something new")).toBe("something new");
});
