import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';

import '../../l10n/app_localizations.dart';

String basisLabel(AppLocalizations l10n, RateBasis basis) => switch (basis) {
  RateBasis.hour => l10n.basisHour,
  RateBasis.day => l10n.basisDay,
  RateBasis.shift => l10n.basisShift,
  RateBasis.month => l10n.basisMonth,
  RateBasis.monthPerWorker => l10n.basisMonthPerWorker,
  RateBasis.monthFixed => l10n.basisMonthFixed,
};

/// "AED 10.00, Per hour"
String rateSummary(AppLocalizations l10n, String basis, int rateFils) {
  return '${formatAed(rateFils)}, ${basisLabel(l10n, RateBasis.values.byName(basis))}';
}

/// "From 01-11-2026" or "01-11-2026 to 30-11-2026"
String dateRange(AppLocalizations l10n, String from, String? to) {
  return to == null ? l10n.dateFrom(showDate(from)) : l10n.dateFromTo(showDate(from), showDate(to));
}
