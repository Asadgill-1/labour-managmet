# Progress

Read this first each session (AI-04). Replace it, do not append; git holds the history.

**Phase:** P0, stopped at the gate for owner sign-off  
**Branch:** `p0/t04-specs` (stacked: t01 > t02 > t03 > t04, none merged yet)  
**Next task:** T05, after the gate passes

## Done

| Task | State | Evidence |
| --- | --- | --- |
| T01 | IMPLEMENTED_UNVERIFIED | `python tools/check_trace.py`: 166 traced. Fails correctly when an ID is removed. PRD text matches the docx |
| T02 | IMPLEMENTED_UNVERIFIED | Workflow parses, `dart test` 6 passed locally. No GitHub run has been read yet |
| T03 | IMPLEMENTED_UNVERIFIED | `flutter analyze` clean, `flutter test` passed, fails correctly on plain SQLite. Release APK built (18.6 MB) from this folder, so the space in the path is fine. Not yet run on a phone |
| T04 | IMPLEMENTED_UNVERIFIED | Specs written, 48 test cases linked. Policy defaults D-101 to D-105 still PROPOSED |

Graphify graph of the PRD is in `graphify-out/` (gitignored): 278 nodes, 553 edges, 14 communities. It does not yet include the repo docs or code written after it was built.

## Needed from the owner to pass the gate

Details in `docs/owner/P0_CHECKLIST.md`.

1. Install the test APK on an Android phone and report the result. No phone has been attached here.
2. Approve or change policy defaults D-101 to D-105.
3. Run `gh auth login`. Until then no issues or PRs can be created and CI results cannot be read.

## Open

- After login: open stacked PRs, confirm CI is green, then merge in order. Fix anything the first real CI run reveals (first use of these action versions on this repo).
- AI-05 wants branch protection. GitHub Free may not offer it on private repos; check after login and record the outcome in `DECISIONS.md`.
- `flutter_secure_storage` key behaviour after reinstall and restore belongs in T20.

## Known risks

- E-invoicing, see `DECISIONS.md` D-011.
- Disk is 94% full with 16 GB free. One release build used about 6 GB. Docker for P4 needs more, so free space before then.
- Release APK builds take about 11 minutes here. Use debug builds while developing.
