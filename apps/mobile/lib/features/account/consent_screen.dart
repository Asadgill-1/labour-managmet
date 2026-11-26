import 'package:domain/dates.dart';
import 'package:flutter/material.dart';

import '../../app/form_bits.dart';
import '../../app/theme.dart';
import '../../data/account.dart';
import '../../data/books.dart';
import '../../l10n/app_localizations.dart';
import '../plans/plan_screen.dart' show askLoginPassword;
import 'account_screens.dart';

/// What goes to the cloud, who sees it, why, for how long and what never goes, in plain words, before anything leaves
/// the phone (D-081 part 2, D-084). One button agrees. At signup it also offers to log out; an account made before this
/// page can open its books to read only, for now. In Settings, with [onAgree] null, it says what was agreed.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({required this.onAgree, this.onLater, this.onLogOut, this.signup = false, this.state, this.signIn, super.key});

  /// Null once the company agreed.
  final Future<void> Function()? onAgree;

  /// Opens the books to read only, for this run of the app.
  final VoidCallback? onLater;
  final Future<void> Function()? onLogOut;

  /// Asked while the account is made, which cannot go on without it.
  final bool signup;

  /// When the books last reached the cloud, or that the last try failed.
  final String? state;

  /// Asks the password and tries again when this phone keeps no session, as the cloud must hear the yes first.
  final Account? signIn;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> with CloudStep {
  /// Agrees; with no session kept, asks the password with nothing else waiting on screen, then agrees again.
  Future<void> _agree(Future<void> Function() agree) async {
    final account = widget.signIn;
    var signIn = false;
    await attempt(() async {
      try {
        await agree();
      } on AccountRefused catch (e) {
        if (account == null || e.problem != AccountProblem.signedOut) rethrow;
        signIn = true;
      }
    });
    if (!signIn || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final password = await askLoginPassword(context, title: l10n.consentTitle, action: l10n.consentAgree);
    if (password == null || !mounted) return;
    await attempt(() async {
      await account!.signInAgain(password);
      await agree();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final head = Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
    final parts = [
      (l10n.consentWhatHead, l10n.consentWhat),
      (l10n.consentWhoHead, l10n.consentWho),
      (l10n.consentWhyHead, l10n.consentWhy),
      (l10n.consentHowLongHead, l10n.consentHowLong),
      (l10n.consentNeverHead, l10n.consentNever),
      (l10n.consentWorkersHead, l10n.consentWorkers),
    ];
    final agree = widget.onAgree;
    return StepScaffold(
      title: l10n.consentTitle,
      busy: busy,
      action: agree == null
          ? const SizedBox.shrink()
          : MainActionBar(free: true, label: l10n.consentAgree, onPressed: busy ? null : () => _agree(agree)),
      child: FormBody(
        children: [
          Text(agree == null ? l10n.consentGiven : l10n.consentLead),
          for (final (title, body) in parts) ...[
            const SizedBox(height: 20),
            Text(title, style: head),
            const SizedBox(height: 4),
            Text(body),
          ],
          const SizedBox(height: 20),
          if (agree != null) MarginNote(widget.signup ? l10n.consentNeeded : l10n.consentLaterNote),
          if (widget.state case final state?) MarginNote(state),
          if (widget.onLater case final later?) ...[
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerStart, child: TextButton(onPressed: busy ? null : later, child: Text(l10n.consentLater))),
          ],
          if (widget.onLogOut case final logOut?) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(onPressed: busy ? null : () => attempt(logOut), child: Text(l10n.logOut)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The page from Settings or from a lock: what was agreed and when the books last went, or the button, which sends at
/// once and goes back.
class ConsentPage extends StatelessWidget {
  const ConsentPage({required this.books, required this.account, super.key});

  final BookSender books;
  final Account account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<BookView>(
      stream: books.watch(),
      initialData: books.view,
      builder: (context, snapshot) {
        final view = snapshot.data!;
        final state = switch (view) {
          (consented: false, lastAt: _, failed: _) => null,
          (consented: true, lastAt: _, failed: true) => l10n.consentFailed,
          (consented: true, lastAt: final at?, failed: false) => l10n.consentSentAt('${showDate(dubaiToday(at))}, ${showMinuteOfDay(dubaiMinuteOfDay(at))}'),
          _ => null,
        };
        return ConsentScreen(
          state: state,
          signIn: account,
          onAgree: view.consented
              ? null
              : () async {
                  await books.agree();
                  if (context.mounted) Navigator.of(context).pop();
                },
        );
      },
    );
  }
}
