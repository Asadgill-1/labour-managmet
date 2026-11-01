import 'dart:convert';

import 'package:domain/calc.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/closing.dart';
import 'package:labour_app/data/documents.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';

import 'support.dart';

const from = '2020-10-01';
const to = '2020-10-31';
const shift = ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60, breakMinutes: 60);

late String asif;
late String bilal;
late String emaar;
late String marina;
late String creek;

Future<String> work(TenantDatabase db, String date, {String? worker, String? site, ShiftInput input = shift}) => db.saveAttendanceBatch(
  workDate: date,
  clientId: emaar,
  siteId: site ?? marina,
  inputs: [EntryInput(workerId: worker ?? asif, shift: input)],
  operationId: newUuid(),
);

/// Pays AED 10 an hour, bills AED 15, for 9 hours a day after an unpaid hour's break.
Future<void> seed(TenantDatabase db) async {
  await seedProfile(db);
  asif = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Asif')));
  bilal = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W2'), name: Value('Bilal'), trade: Value('Helper')));
  emaar = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
  marina = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Marina')));
  creek = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Creek')));
  for (final w in [asif, bilal]) {
    await db.saveRow(
      db.payContracts,
      id: null,
      operationId: newUuid(),
      fields: PayContractsCompanion(workerId: Value(w), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')),
    );
  }
  await db.saveRow(
    db.billingContracts,
    id: null,
    operationId: newUuid(),
    fields: BillingContractsCompanion(clientId: Value(emaar), basis: Value(RateBasis.hour.name), rateFils: const Value(1500), effectiveFrom: const Value('2020-01-01')),
  );
}

void main() {
  late TenantDatabase db;

  setUp(() async {
    db = memoryDb();
    await seed(db);
  });

  tearDown(() => db.close());

  Future<String> draft({String? site, String start = from, String end = to}) => db.createTimesheet(clientId: emaar, siteId: site, from: start, to: end, operationId: newUuid());

  Future<TimesheetRevision> latest(String id) async => (await db.timesheetView(id)).revision;

  Future<String> approved({String? site}) async {
    final id = await draft(site: site);
    await db.approveTimesheet((await latest(id)).id, operationId: newUuid());
    return id;
  }

  group('a draft reads live attendance (TS-01)', () {
    test('it stores no lines, and shows the company side only', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      final view = await db.timesheetView(id);
      expect(view.status, TsStatus.draft);
      expect(view.sheet.number, isNull);
      expect(await db.select(db.timesheetLines).get(), isEmpty);
      final row = view.rows.single;
      expect(row.workerName, 'Asif');
      expect(row.line.billableMinutes, 540);
      expect(row.line.rateFils, 1500);
      expect(row.line.amountFils, 13500);
    });

    test('a row entered or changed later shows at once', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      await work(db, '2020-10-06', worker: bilal);
      expect((await db.timesheetView(id)).rows, hasLength(2));
    });

    test('keeps to its company, site and dates, and leaves an absent row out', () async {
      await work(db, '2020-10-05');
      await work(db, '2020-10-06', site: creek);
      await work(db, '2020-11-02');
      await work(db, '2020-10-07', worker: bilal, input: const ShiftInput(status: AttendanceStatus.absent));
      final id = await draft(site: creek);
      final rows = (await db.timesheetView(id)).rows;
      expect(rows.map((r) => r.line.workDate), ['2020-10-06']);
      expect((await db.timesheetView(await draft())).rows.map((r) => r.line.workDate), ['2020-10-05', '2020-10-06']);
    });

    test('says what it left out and why', () async {
      final noRate = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('No Rate')));
      final site = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(noRate), name: const Value('S')));
      await db.saveAttendanceBatch(workDate: '2020-10-05', clientId: noRate, siteId: site, inputs: [EntryInput(workerId: asif, shift: shift)], operationId: newUuid());
      final preview = await db.timesheetPreview(clientId: noRate, from: from, to: to);
      expect(preview.rows, isEmpty);
      expect(preview.leftOut.noCompanyRate, 1);
      final unpaid = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W3'), name: Value('Nadeem')));
      await work(db, '2020-10-05', worker: unpaid);
      await work(db, '2020-10-06');
      final mine = await db.timesheetPreview(clientId: emaar, from: from, to: to);
      expect(mine.rows, hasLength(1));
      expect(mine.leftOut.noWorkerRate, 1);
    });

    test('nothing to put on it stops it, and leaves nothing behind', () async {
      await expectLater(draft(), throwsA(isA<TimesheetEmpty>()));
      expect(await db.select(db.timesheets).get(), isEmpty);
      expect(await db.select(db.timesheetRevisions).get(), isEmpty);
    });

    test('a draft can be thrown away, and its number is never used', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      await db.deleteTimesheetDraft((await latest(id)).id, operationId: newUuid());
      expect(await db.select(db.timesheets).get(), isEmpty);
      expect((await db.timesheetView(await approved())).sheet.seq, 1);
    });
  });

  group('approving (TS-04)', () {
    test('freezes the attendance, stores the lines and gives a number', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      final entry = await db.select(db.attendanceEntries).getSingle();
      expect(entry.state, 'approved');
      final view = await db.timesheetView(id);
      expect(view.status, TsStatus.approved);
      expect(view.sheet.number, matches(RegExp(r'^TS-\d{4}-0001$')));
      final line = await db.select(db.timesheetLines).getSingle();
      expect((line.entryId, line.workKey, line.live, line.amountFils), (entry.id, entry.id, true, 13500));
      expect((line.workerName, line.workerCode, line.siteName), ('Asif', 'W1', 'Marina'));
    });

    test('later edits to names and rates reach neither the lines nor the view', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      await db.saveRow(db.workers, id: asif, operationId: newUuid(), fields: const WorkersCompanion(name: Value('Renamed')));
      expect((await db.timesheetView(id)).rows.single.workerName, 'Asif');
    });

    test('the same dates again pick up only what is new, so nothing is on two timesheets (TS-05)', () async {
      await work(db, '2020-10-05');
      await approved();
      await expectLater(draft(), throwsA(isA<TimesheetEmpty>()));
      await work(db, '2020-10-06');
      final second = await db.timesheetView(await approved());
      expect(second.rows.map((r) => r.line.workDate), ['2020-10-06']);
      expect(second.sheet.seq, 2);
    });

    test('two drafts over the same dates: the first approved keeps the rows', () async {
      await work(db, '2020-10-05');
      final a = await draft();
      final b = await draft();
      await db.approveTimesheet((await latest(a)).id, operationId: newUuid());
      final later = await db.timesheetView(b);
      expect(later.rows, isEmpty);
      expect(later.leftOut!.onOtherTimesheet, 1);
      await expectLater(db.approveTimesheet(later.revision.id, operationId: newUuid()), throwsA(isA<TimesheetEmpty>()));
    });

    test('a retry with the same operation changes nothing', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      final rev = await latest(id);
      final op = newUuid();
      await db.approveTimesheet(rev.id, operationId: op);
      await db.approveTimesheet(rev.id, operationId: op);
      expect(await db.select(db.timesheetLines).get(), hasLength(1));
    });

    test('what is stored refuses to change', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      final line = await db.select(db.timesheetLines).getSingle();
      expect(() => db.customStatement("UPDATE timesheet_lines SET amount_fils = 1 WHERE id = '${line.id}'"), throwsA(anything));
      expect(() => db.customStatement("DELETE FROM timesheet_lines WHERE id = '${line.id}'"), throwsA(anything));
      expect(() => db.customStatement("UPDATE timesheets SET to_date = '2020-12-31' WHERE id = '$id'"), throwsA(anything));
      expect(() => db.customStatement("DELETE FROM timesheets WHERE id = '$id'"), throwsA(anything));
      final rev = await latest(id);
      expect(() => db.customStatement("UPDATE timesheet_revisions SET status = 'draft' WHERE id = '${rev.id}'"), throwsA(anything));
      expect(() => db.customStatement("UPDATE timesheet_revisions SET adjustments = '{\"a\":1}' WHERE id = '${rev.id}'"), throwsA(anything));
      expect(() => db.customStatement("DELETE FROM timesheet_revisions WHERE id = '${rev.id}'"), throwsA(anything));
      await expectLater(db.deleteTimesheetDraft(rev.id, operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
    });

    test('a timesheet for a closed month changes nothing in it', () async {
      await work(db, '2020-10-05');
      await db.postPayroll('2020-10', operationId: newUuid());
      for (final f in (await db.closingFor('2020-10')).findings) {
        await db.markDayOff(f.date, [for (final t in f.targets) t.id], operationId: newUuid());
      }
      await db.closeMonth('2020-10', operationId: newUuid());
      final view = await db.timesheetView(await approved());
      expect(view.status, TsStatus.approved);
      expect(view.rows, hasLength(1));
    });
  });

  group('the steps after approval (TS-04)', () {
    test('shared, then accepted, then locked', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      await db.markTimesheetShared((await latest(id)).id, '2020-11-02', operationId: newUuid());
      expect((await db.timesheetView(id)).status, TsStatus.shared);
      await db.recordTimesheetResponse((await latest(id)).id, accepted: true, date: '2020-11-03', note: 'Site manager agreed', operationId: newUuid());
      final rev = await latest(id);
      expect((rev.status, rev.respondedOn, rev.responseNote), ('accepted', '2020-11-03', 'Site manager agreed'));
      expect(() => db.customStatement("UPDATE timesheet_revisions SET response_note = 'x' WHERE id = '${rev.id}'"), throwsA(anything));
      await expectLater(db.recordTimesheetResponse(rev.id, accepted: false, date: '2020-11-04', operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
    });

    test('steps cannot be skipped or repeated', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      final rev = await latest(id);
      await expectLater(db.markTimesheetShared(rev.id, '2020-11-02', operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
      await expectLater(db.recordTimesheetResponse(rev.id, accepted: true, date: '2020-11-02', operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
      await db.approveTimesheet(rev.id, operationId: newUuid());
      await expectLater(db.approveTimesheet(rev.id, operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
      await expectLater(db.recordTimesheetResponse(rev.id, accepted: true, date: '2020-11-02', operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
    });

    test('a dispute can still end in acceptance of the same revision', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      await db.markTimesheetShared((await latest(id)).id, '2020-11-02', operationId: newUuid());
      await db.recordTimesheetResponse((await latest(id)).id, accepted: false, date: '2020-11-03', note: 'Hours look high', operationId: newUuid());
      expect((await db.timesheetView(id)).status, TsStatus.disputed);
      await db.recordTimesheetResponse((await latest(id)).id, accepted: true, date: '2020-11-05', operationId: newUuid());
      expect((await db.timesheetView(id)).status, TsStatus.accepted);
    });

    test('a photo of what came back is kept, and goes on no paper (TS-04)', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      await db.markTimesheetShared((await latest(id)).id, '2020-11-02', operationId: newUuid());
      final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/AAAMBAQBzCmLZAAAAAElFTkSuQmCC');
      final photo = await db.saveEvidenceImage(png, operationId: newUuid());
      await db.recordTimesheetResponse((await latest(id)).id, accepted: true, date: '2020-11-03', evidenceAssetId: photo, operationId: newUuid());
      expect((await latest(id)).evidenceAssetId, photo);
      expect(await db.documentTemplate(), isNull);
      final asset = await db.select(db.documentAssets).getSingle();
      expect(asset.kind, 'evidence');
    });
  });

  group('a revision keeps the original (TS-06)', () {
    test('the old lines stay, the number stays, and the reason is on record', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      final first = await latest(id);
      await db.startTimesheetRevision(id, reason: 'Company asked for a correction', operationId: newUuid());
      final view = await db.timesheetView(id);
      expect((view.revision.revision, view.revision.status, view.revision.reason), (2, 'draft', 'Company asked for a correction'));
      expect(view.sheet.seq, 1);
      expect(view.revisions.map((r) => r.revision), [2, 1]);
      await db.approveTimesheet(view.revision.id, operationId: newUuid());
      final lines = await db.select(db.timesheetLines).get();
      expect(lines, hasLength(2));
      expect(lines.singleWhere((l) => l.revisionId == first.id).live, isFalse);
      expect(lines.singleWhere((l) => l.revisionId != first.id).live, isTrue);
      expect((await db.timesheetView(id, revision: 1)).rows, hasLength(1));
      final audit = await (db.select(db.auditEvents)..where((a) => a.reason.equals('Company asked for a correction'))).get();
      expect(audit, hasLength(1));
    });

    test('one revision at a time, and only from the latest', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      final first = await latest(id);
      await db.startTimesheetRevision(id, reason: 'One', operationId: newUuid());
      await expectLater(db.startTimesheetRevision(id, reason: 'Two', operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
      await expectLater(db.markTimesheetShared(first.id, '2020-11-02', operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
    });

    test('a new revision thrown away goes back to the one before', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      await db.startTimesheetRevision(id, reason: 'Mistake', operationId: newUuid());
      await db.deleteTimesheetDraft((await latest(id)).id, operationId: newUuid());
      final view = await db.timesheetView(id);
      expect((view.revision.revision, view.status), (1, TsStatus.approved));
      expect(view.rows, hasLength(1));
    });

    test('corrected attendance leaves the approved line as it was, says so, and a revision takes it in', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      final old = await db.select(db.attendanceEntries).getSingle();
      await db.correctEntry(old, EntryInput(workerId: old.workerId, shift: const ShiftInput(startMinute: 8 * 60, endMinute: 16 * 60, breakMinutes: 60)), reason: 'Left early', operationId: newUuid());
      final stale = await db.timesheetView(id);
      expect(stale.rows.single.line.amountFils, 13500);
      expect(stale.changedRows, 1);
      expect(await db.unbilledLines(id), isEmpty, reason: 'old figures are not billed once the work has changed');
      await db.startTimesheetRevision(id, reason: 'Attendance corrected', operationId: newUuid());
      final draftView = await db.timesheetView(id);
      expect(draftView.rows.single.line.amountFils, 10500);
      expect(draftView.rows.single.workKey, old.id);
      await db.approveTimesheet(draftView.revision.id, operationId: newUuid());
      final after = await db.timesheetView(id);
      expect(after.changedRows, 0);
      expect(after.rows.single.line.amountFils, 10500);
      expect(await db.unbilledLines(id), hasLength(1));
    });

    test('a corrected row is still the same work, so no other timesheet can take it', () async {
      await work(db, '2020-10-05');
      await approved();
      final old = await db.select(db.attendanceEntries).getSingle();
      await db.correctEntry(old, EntryInput(workerId: old.workerId, shift: const ShiftInput(startMinute: 8 * 60, endMinute: 16 * 60, breakMinutes: 60)), reason: 'Left early', operationId: newUuid());
      await expectLater(draft(), throwsA(isA<TimesheetEmpty>()));
    });

    test('work corrected to absent leaves the next revision, and shows against what was billed', () async {
      await work(db, '2020-10-05');
      await work(db, '2020-10-06');
      final id = await approved();
      await db.allocateBilling('invoice-1', await db.unbilledLines(id), operationId: newUuid());
      final old = (await db.select(db.attendanceEntries).get()).firstWhere((e) => e.workDate == '2020-10-05');
      await db.correctEntry(old, EntryInput(workerId: old.workerId, shift: const ShiftInput(status: AttendanceStatus.absent)), reason: 'Never came', operationId: newUuid());
      await db.startTimesheetRevision(id, reason: 'Corrected', operationId: newUuid());
      await db.approveTimesheet((await latest(id)).id, operationId: newUuid());
      final view = await db.timesheetView(id);
      expect(view.rows.map((r) => r.line.workDate), ['2020-10-06']);
      final change = view.billingChanges.single;
      expect((change.workDate, change.billedFils, change.nowFils), ('2020-10-05', 13500, 0));
    });

    test('a retry of any step changes nothing and raises nothing', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      final rev = await latest(id);
      final share = newUuid();
      await db.markTimesheetShared(rev.id, '2020-11-02', operationId: share);
      await db.markTimesheetShared(rev.id, '2020-11-02', operationId: share);
      final accept = newUuid();
      await db.recordTimesheetResponse(rev.id, accepted: true, date: '2020-11-03', operationId: accept);
      await db.recordTimesheetResponse(rev.id, accepted: true, date: '2020-11-03', operationId: accept);
      final revise = newUuid();
      await db.startTimesheetRevision(id, reason: 'Again', operationId: revise);
      await db.startTimesheetRevision(id, reason: 'Again', operationId: revise);
      expect((await db.timesheetView(id)).revisions, hasLength(2));
      final drop = newUuid();
      await db.deleteTimesheetDraft((await latest(id)).id, operationId: drop);
      expect((await db.timesheetView(id)).revisions, hasLength(1));
    });
  });

  group('what a company agrees differs from attendance, and pay never moves (TS-06)', () {
    const agreed = TsAdjustment(status: AttendanceStatus.present, minutes: 480, amountFils: 12000, reason: 'Site says eight hours');

    test('it changes the company side only', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      final before = await db.select(db.attendanceEntries).getSingle();
      await db.adjustTimesheetRow((await latest(id)).id, before.id, agreed, operationId: newUuid());
      final row = (await db.timesheetView(id)).rows.single;
      expect((row.line.billableMinutes, row.line.amountFils, row.adjustReason), (480, 12000, 'Site says eight hours'));
      await db.approveTimesheet((await latest(id)).id, operationId: newUuid());
      final line = await db.select(db.timesheetLines).getSingle();
      expect((line.billableMinutes, line.amountFils, line.adjustReason), (480, 12000, 'Site says eight hours'));
      final entry = await db.select(db.attendanceEntries).getSingle();
      expect((entry.clientBillableMinutes, entry.clientAmountFils, entry.workerPayableMinutes, entry.workerAmountFils), (before.clientBillableMinutes, before.clientAmountFils, before.workerPayableMinutes, before.workerAmountFils));
      await db.postPayroll('2020-10', operationId: newUuid());
      expect((await db.select(db.payrollLines).getSingle()).earnedFils, before.workerAmountFils);
    });

    test('a line the company did not take stays on it, charged nothing, and is not billed again', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      final entry = await db.select(db.attendanceEntries).getSingle();
      await db.adjustTimesheetRow((await latest(id)).id, entry.id, const TsAdjustment(status: AttendanceStatus.absent, minutes: 0, amountFils: 0, reason: 'Not on site'), operationId: newUuid());
      await db.approveTimesheet((await latest(id)).id, operationId: newUuid());
      final view = await db.timesheetView(id);
      expect(view.rows, hasLength(1));
      expect(view.totals.uniqueWorkers, 0);
      expect(view.totals.amountFils, 0);
      expect(view.daily, isEmpty);
      expect(await db.unbilledLines(id), isEmpty);
      await expectLater(draft(), throwsA(isA<TimesheetEmpty>()));
    });

    test('it carries into the next revision, and corrected attendance drops it', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      final entry = await db.select(db.attendanceEntries).getSingle();
      await db.adjustTimesheetRow((await latest(id)).id, entry.id, agreed, operationId: newUuid());
      await db.approveTimesheet((await latest(id)).id, operationId: newUuid());
      await db.startTimesheetRevision(id, reason: 'Again', operationId: newUuid());
      expect((await db.timesheetView(id)).rows.single.line.amountFils, 12000);
      await db.correctEntry(entry, EntryInput(workerId: entry.workerId, shift: const ShiftInput(startMinute: 8 * 60, endMinute: 16 * 60, breakMinutes: 60)), reason: 'Left early', operationId: newUuid());
      final row = (await db.timesheetView(id)).rows.single;
      expect((row.line.amountFils, row.adjustReason), (10500, null));
    });

    test('it can be taken back, and refused once approved', () async {
      await work(db, '2020-10-05');
      final id = await draft();
      final entry = await db.select(db.attendanceEntries).getSingle();
      final rev = await latest(id);
      await db.adjustTimesheetRow(rev.id, entry.id, agreed, operationId: newUuid());
      await db.adjustTimesheetRow(rev.id, entry.id, null, operationId: newUuid());
      expect((await db.timesheetView(id)).rows.single.line.amountFils, 13500);
      await db.approveTimesheet(rev.id, operationId: newUuid());
      await expectLater(db.adjustTimesheetRow(rev.id, entry.id, agreed, operationId: newUuid()), throwsA(isA<TimesheetWrongStep>()));
    });
  });

  group('the same work is never charged twice (TS-05, TC-004)', () {
    Future<String> twoDays() async {
      await work(db, '2020-10-05');
      await work(db, '2020-10-06');
      return approved();
    }

    test('one timesheet can feed several invoices that do not overlap', () async {
      final id = await twoDays();
      final lines = await db.unbilledLines(id);
      expect(lines, hasLength(2));
      await db.allocateBilling('invoice-1', [lines.first], operationId: newUuid());
      final left = await db.unbilledLines(id);
      expect(left.map((l) => l.id), [lines.last.id]);
      await db.allocateBilling('invoice-2', left, operationId: newUuid());
      expect(await db.unbilledLines(id), isEmpty);
    });

    test('billing the same work again is refused whole, whatever else is asked for', () async {
      final id = await twoDays();
      final lines = await db.unbilledLines(id);
      await db.allocateBilling('invoice-1', [lines.first], operationId: newUuid());
      await expectLater(db.allocateBilling('invoice-2', lines, operationId: newUuid()), throwsA(isA<AlreadyBilled>()));
      expect((await db.select(db.billedAllocations).get()).map((b) => b.invoiceId), ['invoice-1']);
    });

    test('the database itself refuses a second live charge, and any edit', () async {
      final id = await twoDays();
      final line = (await db.unbilledLines(id)).first;
      await db.allocateBilling('invoice-1', [line], operationId: newUuid());
      final b = await db.select(db.billedAllocations).getSingle();
      Future<void> again() => db.into(db.billedAllocations).insert(
        BilledAllocationsCompanion.insert(id: newUuid(), tenantId: testTenant, createdAtUtc: DateTime.now().toUtc(), updatedAtUtc: DateTime.now().toUtc(), actorId: 'x', sourceOperationId: newUuid(), lineId: line.id, workKey: line.workKey, invoiceId: 'invoice-2', amountFils: 1),
      );
      await expectLater(again(), throwsA(anything));
      expect(() => db.customStatement("UPDATE billed_allocations SET amount_fils = 1 WHERE id = '${b.id}'"), throwsA(anything));
      expect(() => db.customStatement("DELETE FROM billed_allocations WHERE id = '${b.id}'"), throwsA(anything));
    });

    test('a retry with the same operation bills once', () async {
      final id = await twoDays();
      final lines = await db.unbilledLines(id);
      final op = newUuid();
      await db.allocateBilling('invoice-1', lines, operationId: op);
      await db.allocateBilling('invoice-1', lines, operationId: op);
      expect(await db.select(db.billedAllocations).get(), hasLength(2));
    });

    test('a credit note or cancellation frees the work, and stays on record', () async {
      final id = await twoDays();
      final lines = await db.unbilledLines(id);
      await db.allocateBilling('invoice-1', lines, operationId: newUuid());
      await db.releaseBilling('invoice-1', reason: 'Credit note', operationId: newUuid());
      expect(await db.unbilledLines(id), hasLength(2));
      expect((await db.select(db.billedAllocations).get()).every((b) => b.released), isTrue);
      final b = (await db.select(db.billedAllocations).get()).first;
      expect(() => db.customStatement("UPDATE billed_allocations SET released = 0 WHERE id = '${b.id}'"), throwsA(anything));
      await db.allocateBilling('invoice-2', lines, operationId: newUuid());
      expect(await db.unbilledLines(id), isEmpty);
    });

    test('a revision after billing leaves the invoice as it was and shows the difference', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      await db.allocateBilling('invoice-1', await db.unbilledLines(id), operationId: newUuid());
      final old = await db.select(db.attendanceEntries).getSingle();
      await db.correctEntry(old, EntryInput(workerId: old.workerId, shift: const ShiftInput(startMinute: 8 * 60, endMinute: 16 * 60, breakMinutes: 60)), reason: 'Left early', operationId: newUuid());
      await db.startTimesheetRevision(id, reason: 'Corrected', operationId: newUuid());
      await db.approveTimesheet((await latest(id)).id, operationId: newUuid());
      expect(await db.unbilledLines(id), isEmpty, reason: 'the corrected row is still the same work');
      expect((await db.select(db.billedAllocations).getSingle()).amountFils, 13500);
      final change = (await db.timesheetView(id)).billingChanges.single;
      expect((change.billedFils, change.nowFils, change.differenceFils), (13500, 10500, -3000));
    });

    test('a disputed revision is not billed until it is settled', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      await db.markTimesheetShared((await latest(id)).id, '2020-11-02', operationId: newUuid());
      await db.recordTimesheetResponse((await latest(id)).id, accepted: false, date: '2020-11-03', operationId: newUuid());
      expect(await db.unbilledLines(id), isEmpty);
      await db.recordTimesheetResponse((await latest(id)).id, accepted: true, date: '2020-11-04', operationId: newUuid());
      expect(await db.unbilledLines(id), hasLength(1));
    });
  });

  group('monthly contracts (TS-08)', () {
    test('the attendance is evidence: no daily amounts, and nothing to bill from the rows', () async {
      final fixed = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Fixed Fee')));
      final site = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(fixed), name: const Value('Tower')));
      await db.saveRow(
        db.billingContracts,
        id: null,
        operationId: newUuid(),
        fields: BillingContractsCompanion(clientId: Value(fixed), basis: Value(RateBasis.monthFixed.name), rateFils: const Value(500000), effectiveFrom: const Value('2020-01-01')),
      );
      for (final (w, date) in [(asif, '2020-10-05'), (bilal, '2020-10-05'), (asif, '2020-10-20')]) {
        await db.saveAttendanceBatch(workDate: date, clientId: fixed, siteId: site, inputs: [EntryInput(workerId: w, shift: shift)], operationId: newUuid());
      }
      final id = await db.createTimesheet(clientId: fixed, from: from, to: to, operationId: newUuid());
      await db.approveTimesheet((await latest(id)).id, operationId: newUuid());
      final view = await db.timesheetView(id);
      expect(view.rows, hasLength(3));
      expect(view.rows.every((r) => r.line.amountFils == null), isTrue);
      expect(view.totals.amountFils, 0);
      final month = view.monthly.single;
      expect((month.basis, month.rateFils, month.fromDate, month.toDate, month.persons), (RateBasis.monthFixed, 500000, '2020-10-05', '2020-10-20', 2));
      expect(await db.unbilledLines(id), isEmpty);
    });
  });

  test('the list says where each timesheet stands', () async {
    await work(db, '2020-10-05');
    final id = await approved();
    final open = await db.select(db.timesheets).get();
    expect(open, hasLength(1));
    final rows = await db.watchTimesheets().first;
    final row = rows.single;
    expect((row.id, row.clientName, row.status, row.amountFils), (id, 'Emaar', TsStatus.approved, 13500));
    expect(row.number, matches(RegExp(r'^TS-\d{4}-0001$')));
  });

  test('a paper number stays with the timesheet through its revisions', () {
    expect(documentNumber(DocKind.timesheetDaily, 2026, 12, 1), 'TS-2026-0012');
    expect(documentNumber(DocKind.timesheetWorkersPriced, 2026, 12, 2), 'TS-2026-0012 R2');
  });
}
