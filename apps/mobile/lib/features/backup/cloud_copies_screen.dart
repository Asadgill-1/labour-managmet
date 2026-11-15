import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/account.dart';
import '../../data/cloud_copy.dart';
import '../../data/plans.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screens.dart';
import '../plans/plan_screen.dart';
import 'backup_screen.dart';

/// What the owner picked from the cloud: the copy's file, when the cloud took it, and whether it is the newest there.
typedef CloudPick = ({Uint8List bytes, DateTime at, bool newest});

/// The copies the cloud keeps for the company (T20d-c, D-072), each with its date and size, shown with the add-on or
/// without. With it a tap brings the file to the phone, and the restore goes on as with a picked file. Without it the
/// page says what is there and leads to Plan lein; a Play Store build says the add-on is not sold there (BILL-07).
/// The cloud decides who gets a copy, so its refusal is what the page shows.
class CloudCopiesScreen extends ConsumerStatefulWidget {
  const CloudCopiesScreen({required this.account, super.key});

  final Account account;

  @override
  ConsumerState<CloudCopiesScreen> createState() => _CloudCopiesScreenState();
}

class _CloudCopiesScreenState extends ConsumerState<CloudCopiesScreen> {
  List<CloudCopy>? _copies;

  /// Why the list, the plan's check or a download did not go through.
  AccountProblem? _problem;
  var _addon = false;
  var _busy = false;
  var _fetching = false;

  String get _tenantId => ref.read(dbProvider).tenantId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    final account = widget.account;
    final licensing = ref.read(licensingProvider);
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      List<CloudCopy> copies;
      try {
        copies = await account.cloudCopies(_tenantId);
      } on AccountRefused catch (e) {
        // The cloud no longer takes the session kept on the phone: the password brings it back.
        if (e.problem != AccountProblem.signedOut || !mounted) rethrow;
        // The bar means the app is working; while the owner types, it is the app that waits.
        setState(() => _busy = false);
        final password = await askLoginPassword(context, title: l10n.cloudListTitle, action: l10n.cloudListShow);
        if (password == null) rethrow;
        if (mounted) setState(() => _busy = true);
        await account.signInAgain(password);
        copies = await account.cloudCopies(_tenantId);
      }
      // A slip accepted since the last check shows only in a fresh licence.
      await licensing?.refresh();
      if (!mounted) return;
      final view = licensing?.view;
      setState(() {
        _copies = copies;
        _problem = view?.problem;
        _addon = view?.licence?.addonUntil?.isAfter(DateTime.now()) ?? false;
      });
    } on AccountRefused catch (e) {
      if (mounted) setState(() => _problem = e.problem);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetch(CloudCopy copy) async {
    setState(() {
      _busy = true;
      _fetching = true;
      _problem = null;
    });
    try {
      final bytes = await widget.account.downloadCloudCopy(_tenantId, copy.id);
      if (mounted) Navigator.of(context).pop<CloudPick>((bytes: bytes, at: copy.at, newest: copy.id == _copies!.first.id));
    } on AccountRefused catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.problem == AccountProblem.addonNeeded) {
          _addon = false;
        } else {
          _problem = e.problem;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _fetching = false;
        });
      }
    }
  }

  /// To a screen that can change what the cloud answers, then the list again.
  Future<void> _go(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }

  String _say(AppLocalizations l10n, AccountProblem problem) => switch (problem) {
    AccountProblem.offline => l10n.cloudListOffline,
    AccountProblem.signedOut => l10n.cloudListSignedOut,
    _ => accountProblemText(l10n, AccountRefused(problem)),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copies = _copies;
    final problem = _problem;
    // A company whose plan ended buys the two together; the others the add-on alone, as their plan goes on.
    final ended = ref.watch(licenceProvider).value?.licence?.state == 'none';
    final note = _fetching
        ? l10n.cloudFetching
        : problem != null
        ? null
        : _addon
        ? l10n.cloudListIntro
        : (playStoreBuild ? l10n.cloudAddonPlayStore : l10n.cloudAddonNeeded);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cloudListTitle),
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3)) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (problem != null && !_busy) ...[
            NoteRow(icon: Icons.warning_amber, text: _say(l10n, problem), color: due),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                // The old phone is turned off from the phones list; anything else is tried again.
                child: problem == AccountProblem.otherPhone
                    ? TextButton.icon(
                        onPressed: () => _go(PhonesScreen(account: widget.account)),
                        icon: const Icon(Icons.phonelink_erase_outlined),
                        label: Text(l10n.phonesTitle),
                      )
                    : TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(l10n.cloudListRetry)),
              ),
            ),
            const Divider(height: 1),
          ],
          if (copies != null && copies.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.cloudListNone, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink)),
            ),
          if (copies != null && copies.isNotEmpty) ...[
            if (note != null) Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: MarginNote(note)),
            if (problem == null && !_addon && !playStoreBuild)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _busy ? null : () => _go(PlanScreen(account: widget.account, covers: ended ? SlipCovers.planAddon : SlipCovers.addon)),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(l10n.cloudAddonTake),
                  ),
                ),
              ),
            const Divider(height: 1),
            for (final copy in copies)
              RowCard(
                child: ListTile(
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: Text(shownWhen(copy.at), style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
                  subtitle: Text(copy.id == copies.first.id ? l10n.cloudCopyNewest(shownSize(copy.sizeBytes)) : shownSize(copy.sizeBytes)),
                  trailing: _addon ? const Icon(Icons.download_outlined) : null,
                  onTap: _addon && !_busy ? () => _fetch(copy) : null,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
