# Progress

Read this first each session (AI-04). Replace it, do not append; git holds the history.

**Phase:** P1, stopped at the gate for the owner's phone demo  
**Branch:** `p1/t10-attendance` (stacked: p0/t01 > t02 > t03 > t04 > p1/t05 > t06 > t07 > t09 > t08 > t10, none merged)  
**Next task:** T11 (payroll), after the P1 gate passes

## Done

| Task | State | Evidence |
| --- | --- | --- |
| T01, T02, T03 | IMPLEMENTED_UNVERIFIED | See git log. CI has never been read, and the database has never run on a phone |
| T04 | OWNER_ACCEPTED | Policy defaults D-101 to D-105 approved 2026-10-31 |
| T05 to T10 | IMPLEMENTED_UNVERIFIED | `dart test`: domain passing. `flutter test`: app passing, including one 10-worker flow through the real screens. `flutter analyze` clean. Not yet run on a phone |

Test evidence is host only. Encryption on Android, UX-06 timing and BUILD-04 on a real device are all still open.

## Needed from the owner to pass the gate

Details in `docs/owner/P1_CHECKLIST.md`.

1. Install the APK, run the encryption check, and enter 10 workers on a real phone.
2. Run `gh auth login`. Until then no issues or PRs can be created and CI results cannot be read.

D-023 and D-024 were settled by the owner on 2026-10-31.

## Open

- After login: open the stacked PRs in order, confirm CI is green, merge. These action versions have never run on this repo, so the first run may need fixes.
- AI-05 wants branch protection. GitHub Free may not offer it on private repos; check after login and record the outcome in `DECISIONS.md`.
- `db_check_screen.dart` and `spike_checks.dart` are the T03 proof. Delete both once the phone test passes.
- UX-02 is local only until T19 adds accounts. UX-07's sync statuses arrive with T25.
- Worker lists sort by plain text, so "Worker 10" comes before "Worker 2". Real names are fine; revisit if codes are shown as the sort key.

## Known risks

- E-invoicing, see `DECISIONS.md` D-011.
- Disk is 91% full with 22 GB free. Docker for P4 needs more, so free space before then.
- Release APK builds take 3 to 11 minutes here, depending on the Gradle cache. Use debug builds while developing.
- The P1 release build warns that `CupertinoIcons` has no bundled font. No screen reviewed so far shows one. Check on the phone test.

## Lessons

- In a widget test, database work must run on the real clock (`real()` in `test/support.dart`), or the test hangs.
- Never chain a commit after a test run in one command unless it is gated on the result. It happened once in T06.
- Forms must not sit in a lazy list. Off-screen fields skip validation. Use `FormBody`.
- Never run the bare `graphify update` CLI on this repo. See `CLAUDE.md`. Current graph: 1,219 nodes, 1,898 edges, 62 communities, including all 278 PRD nodes and 166 requirements. Repo docs other than the PRD have no semantic extraction yet.
