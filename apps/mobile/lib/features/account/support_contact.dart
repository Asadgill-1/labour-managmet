import 'package:flutter/material.dart';

import '../../app/form_bits.dart';
import '../../app/theme.dart';
import '../../data/account.dart';
import '../../l10n/app_localizations.dart';

/// The platform's support contact from the live settings, or that none is set yet, under [title] and [body] (T20d-c,
/// T22b).
Future<void> showSupportContact(BuildContext context, Account account, {required String title, String? body}) async {
  final l10n = AppLocalizations.of(context);
  final contact = await account.supportContact();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (body != null) ...[Text(body), fieldGap],
          if (contact == null)
            Text(l10n.restoreForgotNoContact, style: const TextStyle(color: muted))
          else
            SelectableText(l10n.restoreForgotContact(contact), style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.cancel))],
    ),
  );
}
