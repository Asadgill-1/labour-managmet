import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

const ink = Color(0xFF14171A);
const muted = Color(0xFF596068);
const paper = Color(0xFFF0F1EE);
const rule = Color(0xFFDADCD7);
const hiVis = Color(0xFFFFC400);
const hiVisSoft = Color(0xFFFFF3C4);
const due = Color(0xFFB3261E);
const dueSoft = Color(0xFFF9DEDC);
const settled = Color(0xFF1B6E43);
const settledSoft = Color(0xFFDDF0E4);

/// Narrow and bold like site signage, so long Roman Urdu labels and amounts fit a small phone.
const headingFont = 'RobotoCondensed';

const _heading = TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, color: ink);

/// Section headings inside a screen.
const sectionTitleStyle = TextStyle(fontFamily: headingFont, fontSize: 18, fontWeight: FontWeight.w700, color: ink);

/// Named outright: a style with no family falls back to the phone's own font, which on some phones is a handwriting theme.
const _body = 'Roboto';

/// Lines up digits in amount columns.
const amountStyle = TextStyle(fontFamily: headingFont, fontSize: 18, fontWeight: FontWeight.w700, color: ink, fontFeatures: [FontFeature.tabularFigures()]);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: ink,
    onPrimary: Colors.white,
    secondary: hiVis,
    onSecondary: ink,
    surface: Colors.white,
    onSurface: ink,
    onSurfaceVariant: muted,
    error: due,
    outline: Color(0xFF8E949A),
    outlineVariant: rule,
  ),
  scaffoldBackgroundColor: paper,
  dividerTheme: const DividerThemeData(color: rule, thickness: 1, space: 1),
  appBarTheme: AppBarTheme(
    backgroundColor: hiVis,
    foregroundColor: ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    titleTextStyle: _heading.copyWith(fontSize: 22),
  ),
  drawerTheme: const DrawerThemeData(backgroundColor: ink, shape: RoundedRectangleBorder()),
  tabBarTheme: TabBarThemeData(
    labelColor: ink,
    unselectedLabelColor: ink.withValues(alpha: 0.7),
    indicatorColor: ink,
    dividerColor: Colors.transparent,
    labelStyle: _heading.copyWith(fontSize: 16),
    unselectedLabelStyle: _heading.copyWith(fontSize: 16),
  ),
  listTileTheme: ListTileThemeData(
    tileColor: Colors.white,
    iconColor: muted,
    titleTextStyle: _heading.copyWith(fontSize: 18),
    subtitleTextStyle: const TextStyle(fontFamily: _body, fontSize: 14, color: muted),
    leadingAndTrailingTextStyle: const TextStyle(fontFamily: _body, fontSize: 15, color: ink),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      disabledBackgroundColor: rule,
      disabledForegroundColor: muted,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: _heading.copyWith(fontSize: 19),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      backgroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      side: const BorderSide(color: ink, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: _heading.copyWith(fontSize: 17),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ink,
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontFamily: _body, fontSize: 15, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  ),
  chipTheme: ChipThemeData(
    showCheckmark: false,
    selectedColor: ink,
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFF8E949A)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    labelStyle: TextStyle(
      fontFamily: _body,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : ink),
    ),
  ),
  dialogTheme: DialogThemeData(titleTextStyle: _heading.copyWith(fontSize: 20)),
  snackBarTheme: const SnackBarThemeData(backgroundColor: ink, contentTextStyle: TextStyle(fontFamily: _body, fontSize: 15, color: Colors.white)),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 16),
    bodyLarge: TextStyle(fontSize: 17),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
  ),
);

/// The screen's one main action, at thumb height (UX-03).
class MainActionBar extends StatelessWidget {
  const MainActionBar({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: rule))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton(onPressed: onPressed, child: Text(label)),
        ),
      ),
    );
  }
}

/// A problem with the form as a whole. Floats above the action bar, so it shows wherever the form is scrolled.
void showFormError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
        backgroundColor: due,
        content: Text(message),
      ),
    );
}

/// Tells the user the write reached local storage (UX-04, UX-07).
void showSavedOnPhone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // Floats above the main action bar, so entering several records in a row never misses a tap.
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Runs a save and says so plainly if it fails, so a failed write is never silent (UX-07).
/// The caller keeps its operation ID, so trying again cannot apply twice.
Future<bool> saveOrExplain(BuildContext context, Future<void> Function() work) async {
  final message = AppLocalizations.of(context).saveFailed;
  try {
    await work();
    return true;
  } catch (_) {
    if (context.mounted) showFormError(context, message);
    return false;
  }
}
