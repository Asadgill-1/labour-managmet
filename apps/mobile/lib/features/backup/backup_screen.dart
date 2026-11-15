import 'dart:async';

import 'package:domain/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../data/account.dart';
import '../../data/backup.dart';
import '../../data/cloud_copy.dart';
import '../../data/restore.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screens.dart';
import '../registers/register_export.dart';
import 'restore_screen.dart';

const _files = MethodChannel('labour_app/files');

final backupStoreProvider = Provider((ref) => BackupStore(ref.watch(secureStorageProvider), ref.watch(dbProvider).tenantId));
final lastBackupProvider = FutureProvider((ref) => ref.watch(backupStoreProvider).last());
final _hasPasswordProvider = FutureProvider((ref) async => await ref.watch(backupStoreProvider).password() != null);

/// Why the last cloud copy did not go, in the page's words.
String cloudProblemText(AppLocalizations l10n, AccountProblem problem) => switch (problem) {
  AccountProblem.offline => l10n.cloudOffline,
  AccountProblem.signedOut => l10n.cloudSignedOut,
  _ => accountProblemText(l10n, AccountRefused(problem)),
};

/// 10-11-2026, 14:30 in UAE time.
String shownWhen(DateTime at) => '${showDate(dubaiToday(at))}, ${showMinuteOfDay(dubaiMinuteOfDay(at))}';

/// A file's size as people say it: 340 KB, 2.4 MB.
String shownSize(int bytes) => bytes < 1024 * 1024 ? '${(bytes / 1024).ceil()} KB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Makes the company's backup and hands it to the place the user chooses. True once the file left the app; a closed
/// save screen changes nothing (D-069). A phone that keeps no password yet keeps [password] first.
Future<bool> handOverBackup(WidgetRef ref, {required bool send, String? password}) async {
  final store = ref.read(backupStoreProvider);
  if (password != null && await store.password() == null) {
    await store.setPassword(password);
    ref.invalidate(_hasPasswordProvider);
  }
  final bytes = await ref.read(dbProvider).backupBytes((await store.password())!, work: await getTemporaryDirectory());
  final file = await writeExportFile(backupFileName(DateTime.now()), bytes);
  final done = send
      ? await _files.invokeMethod<bool>('send', {'path': file.path, 'mime': backupMime, 'whatsapp': false})
      : await _files.invokeMethod<bool>('save', {'path': file.path, 'mime': backupMime});
  if (done != true) return false;
  await store.record(sent: send);
  ref.invalidate(lastBackupProvider);
  return true;
}

/// Makes the company's encrypted backup and hands it to a place the user chooses (DATA-02, DATA-03, DATA-04). The
/// first visit sets the backup password, which this phone then keeps (D-069). Bringing a backup back is on this page
/// too (D-070).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _again = TextEditingController();
  var _busy = false;
  var _changing = false;

  Future<void> _keepPassword() async {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    await ref.read(backupStoreProvider).setPassword(_password.text);
    ref.invalidate(_hasPasswordProvider);
    // The first cloud copy needs nothing more pressed.
    unawaited(ref.read(cloudSenderProvider)?.sendIfDue());
    _password.clear();
    _again.clear();
    if (!mounted) return;
    setState(() => _changing = false);
    showSavedOnPhone(context, l10n.backupPasswordKept);
  }

  Future<void> _make({required bool send}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      if (!await handOverBackup(ref, send: send)) return;
      if (mounted) showSavedOnPhone(context, send ? l10n.backupSent : l10n.backupSaved);
    } catch (_) {
      if (mounted) showFormError(context, l10n.backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _sendToCloud(CloudSender sender, {bool replace = false}) async {
    final l10n = AppLocalizations.of(context);
    await sender.sendNow(replace: replace);
    if (!mounted) return;
    final problem = sender.view.problem;
    // The other phone's question shows on the page itself.
    if (problem == null) {
      showSavedOnPhone(context, l10n.cloudSent);
    } else if (problem != AccountProblem.otherPhoneCopy) {
      showFormError(context, cloudProblemText(l10n, problem));
    }
  }

  /// Keeping this phone's data in place of the other phone's copy can't be undone, so it is asked once more.
  Future<void> _replaceCloudCopy(CloudSender sender) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l10n.cloudReplaceConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.cloudReplaceGo)),
        ],
      ),
    );
    if (yes == true && mounted) await _sendToCloud(sender, replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasPassword = ref.watch(_hasPasswordProvider).value;
    final last = ref.watch(lastBackupProvider).value;
    final setting = hasPassword == false || _changing;
    final restorer = ref.watch(restoreProvider);
    final kept = restorer == null ? null : keptFile(restorer.dir, ref.watch(dbProvider).tenantId);
    final keptAt = kept != null && kept.existsSync() ? kept.lastModifiedSync() : null;
    final accounts = ref.watch(accountProvider) != null;
    final sender = ref.watch(cloudSenderProvider);
    final cloud = ref.watch(cloudViewProvider).value;
    final sending = cloud?.sending ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.menuBackup),
        bottom: _busy || sending ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3)) : null,
      ),
      bottomNavigationBar: hasPassword == null
          ? null
          : setting
          ? MainActionBar(free: true, label: l10n.backupPasswordKeep, onPressed: _keepPassword)
          : MainActionBar(free: true, label: l10n.backupSave, onPressed: _busy ? null : () => _make(send: false)),
      body: Column(
        children: [
          // What no login brings back, before anything else on the page (DATA-03).
          NoteRow(icon: Icons.warning_amber, text: l10n.backupWarning, color: warn),
          const Divider(height: 1),
          Expanded(
            child: Form(
              key: _form,
              child: FormBody(
                children: [
                  Text(
                    last == null ? l10n.backupNone : (last.sent ? l10n.backupSentOn(shownWhen(last.at)) : l10n.backupSavedOn(shownWhen(last.at))),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
                  ),
                  fieldGap,
                  if (setting) ...[
                    Text(l10n.backupPasswordIntro),
                    fieldGap,
                    MarginNote(sender != null ? l10n.backupPasswordWriteDownCloud : l10n.backupPasswordWriteDown),
                    if (_changing) ...[fieldGap, MarginNote(l10n.backupPasswordOld)],
                    fieldGap,
                    PasswordField(
                      l10n.backupPassword,
                      _password,
                      autofillHints: const [AutofillHints.newPassword],
                      helper: l10n.accountPasswordHelp,
                      validator: (v) => isStrongPassword(v ?? '') ? null : l10n.accountPasswordWeak,
                    ),
                    fieldGap,
                    PasswordField(
                      l10n.backupPasswordAgain,
                      _again,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => v == _password.text ? null : l10n.backupPasswordMismatch,
                    ),
                  ] else if (hasPassword == true) ...[
                    MarginNote(l10n.backupWhere),
                    fieldGap,
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => _make(send: true),
                        icon: const Icon(Icons.send_outlined),
                        label: Text(l10n.backupSend),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _busy ? null : () => setState(() => _changing = true),
                        icon: const Icon(Icons.key_outlined),
                        label: Text(l10n.backupPasswordChange),
                      ),
                    ),
                  ],
                  // The cloud copy (D-072): when the last one went, or why none did, and the owner's say on the other
                  // phone's copy. Never called end-to-end encrypted, since the platform can open it (DATA-08).
                  if (accounts) ...[
                    const Divider(height: 32),
                    if (sender == null)
                      Text(l10n.cloudUnavailable, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink))
                    else ...[
                      Text(
                        sending ? l10n.cloudSending : (cloud?.lastAt == null ? l10n.cloudNone : l10n.cloudLast(shownWhen(cloud!.lastAt!))),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
                      ),
                      if (cloud?.problem case final problem? when !sending) ...[
                        fieldGap,
                        if (problem == AccountProblem.otherPhoneCopy) ...[
                          Text(l10n.cloudOtherPhoneAsk),
                          if (restorer != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: _busy ? null : () => _push(const RestoreScreen(cloud: true)),
                                icon: const Icon(Icons.settings_backup_restore),
                                label: Text(l10n.cloudBringBack),
                              ),
                            ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: _busy || hasPassword != true ? null : () => _replaceCloudCopy(sender),
                              icon: const Icon(Icons.phone_android),
                              label: Text(l10n.cloudKeepThis),
                            ),
                          ),
                        ] else
                          Text(cloudProblemText(l10n, problem), style: const TextStyle(color: warn)),
                      ],
                      fieldGap,
                      MarginNote(l10n.cloudPlainWords),
                      if (hasPassword == false) ...[fieldGap, MarginNote(l10n.cloudNeedsPassword)],
                      if (cloud?.problem != AccountProblem.otherPhoneCopy)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: _busy || sending || hasPassword != true ? null : () => _sendToCloud(sender),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text(l10n.cloudSendNow),
                          ),
                        ),
                    ],
                  ],
                  const Divider(height: 32),
                  // On a new phone no password is kept yet, so this stays in reach of the password form too.
                  if (restorer == null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: false,
                      leading: const Icon(Icons.settings_backup_restore),
                      title: Text(l10n.backupRestore),
                      subtitle: Text(l10n.restoreNeedsAccount),
                    )
                  else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.settings_backup_restore),
                      title: Text(l10n.backupRestore),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _push(const RestoreScreen()),
                    ),
                    if (keptAt != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history),
                        title: Text(l10n.restoreKeptTitle),
                        subtitle: Text(l10n.restoreKeptSince(shownWhen(keptAt))),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _push(const RestoreScreen(kept: true)),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// On the day's page once a company has workers and its last backup is a week old, or there is none (D-069).
class BackupDueBanner extends ConsumerWidget {
  const BackupDueBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void open() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BackupScreen()));
    // With the cloud on, a company that keeps no password yet sends no copy, so that comes first (D-072).
    if (ref.watch(cloudSenderProvider) != null && ref.watch(_hasPasswordProvider).value == false) {
      return NoticeRow(icon: Icons.key_outlined, title: l10n.backupPasswordDue, subtitle: l10n.backupPasswordDueBody, onTap: open);
    }
    final workers = ref.watch(workersProvider).value ?? const [];
    final last = ref.watch(lastBackupProvider);
    if (workers.isEmpty || !last.hasValue) return const SizedBox.shrink();
    final at = last.value?.at;
    final days = at == null ? null : daysBetween(dubaiToday(at), dubaiToday(DateTime.now()));
    if (days != null && days < backupEveryDays) return const SizedBox.shrink();
    return NoticeRow(
      icon: Icons.backup_outlined,
      title: days == null ? l10n.backupDueNever : l10n.backupDueDays(days),
      subtitle: l10n.backupDueBody,
      onTap: open,
    );
  }
}
