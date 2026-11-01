// Hallmark · theme: dose, palette and surfaces only (dealt 3/3, seed phone-app-labour-supply-d9dd·82ad75fc·2026-11-01·r0)
// shape: app screen · redesign: full · signature: the bound account book, dark cover over ruled cream pages, double rule under a total, a stamp on a closed month
// waive: Dose's "never red for late": a wage owed and a month that cannot close must read as money at stake, in words as well as colour (UX-04).
// waive: Floor 15 and 16 (CSS stamp, sloplint): this is Flutter, so the stamp sits here and screens are read by eye from golden images.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/closing.dart';
import '../data/tenant_database.dart';
import '../l10n/app_localizations.dart';

/// The colours a user can choose from in Settings (D-040).
enum AppPalette {
  blue(Color(0xFF0B2648), Color(0xFFE0EEFF), Color(0xFF155AA7), Color(0xFF034486)),
  green(Color(0xFF00301B), Color(0xFFDDF3E6), Color(0xFF007040), Color(0xFF00572E)),
  maroon(Color(0xFF43131E), Color(0xFFFFE5E8), Color(0xFF9C2A47), Color(0xFF7C1734));

  const AppPalette(this.brand, this.brandSoft, this.action, this.rim);

  /// The book's cover: header and anything that says "this app".
  final Color brand;
  final Color brandSoft;

  /// The one signal: the main action and what is selected.
  final Color action;

  /// The moulded edge under the main action.
  final Color rim;
}

var _palette = AppPalette.blue;

/// The header and everything that means "this app".
Color get brand => _palette.brand;
Color get brandSoft => _palette.brandSoft;

/// The screen's one main action.
Color get action => _palette.action;
const onAction = Colors.white;

const ink = Color(0xFF15201B);
const muted = Color(0xFF5A6259);
const paper = Color(0xFFFAF7EF);
const rule = Color(0xFFDDD8CB);

/// The edge of a field, darker than a rule so it can be seen on paper.
const fieldEdge = Color(0xFFA9A79C);
const due = Color(0xFF9E2320);
const dueSoft = Color(0xFFFBE7E2);
const settled = Color(0xFF036639);
const settledSoft = Color(0xFFDBF4E3);
const warn = Color(0xFF7E4F04);
const warnSoft = Color(0xFFFBEDD1);

/// Named outright and bundled: a style with no family falls back to the phone's own font, which on some phones is a handwriting theme.
const headingFont = 'Roboto';

const _heading = TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, color: ink);

/// Section headings inside a screen.
const sectionTitleStyle = TextStyle(fontFamily: headingFont, fontSize: 16, fontWeight: FontWeight.w700, color: ink);

/// Lines up digits in amount columns.
const amountStyle = TextStyle(fontFamily: headingFont, fontSize: 17, fontWeight: FontWeight.w700, color: ink, fontFeatures: [FontFeature.tabularFigures()]);

final _corner10 = BorderRadius.circular(10);

final _themes = <AppPalette, ThemeData>{};

/// Switches the app's colours. Colours are read while widgets build, so after a change everything builds again,
/// and the user stays on the same screen with nothing lost.
ThemeData usePalette(AppPalette palette) {
  if (palette != _palette) {
    _palette = palette;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(mark);
    });
  }
  return _themes[palette] ??= _buildTheme();
}

ThemeData _buildTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: headingFont,
  colorScheme: ColorScheme.light(
    primary: brand,
    onPrimary: Colors.white,
    secondary: action,
    onSecondary: onAction,
    surface: Colors.white,
    onSurface: ink,
    onSurfaceVariant: muted,
    error: due,
    outline: fieldEdge,
    outlineVariant: rule,
  ),
  scaffoldBackgroundColor: paper,
  dividerTheme: const DividerThemeData(color: rule, thickness: 1, space: 1),
  appBarTheme: AppBarTheme(
    backgroundColor: brand,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
    titleTextStyle: _heading.copyWith(fontSize: 20, color: Colors.white),
  ),
  drawerTheme: const DrawerThemeData(backgroundColor: paper, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder()),
  tabBarTheme: TabBarThemeData(
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
    indicatorColor: action,
    dividerColor: Colors.transparent,
    labelStyle: _heading.copyWith(fontSize: 15),
    unselectedLabelStyle: _heading.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
  ),
  listTileTheme: ListTileThemeData(
    tileColor: Colors.transparent,
    iconColor: muted,
    titleTextStyle: _heading.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
    subtitleTextStyle: const TextStyle(fontFamily: headingFont, fontSize: 14, height: 1.35, color: muted),
    leadingAndTrailingTextStyle: const TextStyle(fontFamily: headingFont, fontSize: 15, color: ink),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: action,
      foregroundColor: onAction,
      disabledBackgroundColor: rule,
      disabledForegroundColor: muted,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: _corner10),
      textStyle: _heading.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: action,
      minimumSize: const Size(64, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      side: BorderSide(color: action),
      shape: RoundedRectangleBorder(borderRadius: _corner10),
      textStyle: _heading.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: action,
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontFamily: headingFont, fontSize: 15, fontWeight: FontWeight.w500),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: _corner10, borderSide: const BorderSide(color: fieldEdge)),
    enabledBorder: OutlineInputBorder(borderRadius: _corner10, borderSide: const BorderSide(color: fieldEdge)),
    focusedBorder: OutlineInputBorder(borderRadius: _corner10, borderSide: BorderSide(color: action, width: 2)),
  ),
  chipTheme: ChipThemeData(
    showCheckmark: false,
    selectedColor: action,
    backgroundColor: Colors.white,
    side: const BorderSide(color: fieldEdge),
    shape: const StadiumBorder(),
    labelStyle: TextStyle(
      fontFamily: headingFont,
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      color: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : ink),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    titleTextStyle: _heading.copyWith(fontSize: 18),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: paper,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
  ),
  snackBarTheme: const SnackBarThemeData(backgroundColor: ink, contentTextStyle: TextStyle(fontFamily: headingFont, fontSize: 15, color: Colors.white)),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 15),
    bodyLarge: TextStyle(fontSize: 16),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  ),
);

/// The rest of the cover under the header, holding a screen's date and main figures. Its straight edge meets the page.
class TopBand extends StatelessWidget {
  const TopBand({required this.child, this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 14), super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: brand,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A text action on the coloured header.
class BarButton extends StatelessWidget {
  const BarButton(this.label, {required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// The screen's one main action, at thumb height (UX-03).
class MainActionBar extends StatelessWidget {
  const MainActionBar({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: paper,
        border: Border(top: BorderSide(color: rule)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 13),
          // A moulded edge under the one main action, gone when it can't be pressed.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _corner10,
              boxShadow: [if (onPressed != null) BoxShadow(color: _palette.rim, offset: const Offset(0, 3))],
            ),
            child: FilledButton(onPressed: onPressed, child: Text(label)),
          ),
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
  final l10n = AppLocalizations.of(context);
  try {
    await work();
    return true;
  } catch (e) {
    if (context.mounted) showFormError(context, saveErrorText(l10n, e));
    return false;
  }
}

/// What to tell the owner when a save fails. A closed month says what to do instead (REP-04).
String saveErrorText(AppLocalizations l10n, Object error) => switch (error) {
  PeriodLocked() => l10n.periodLockedError,
  LaterMonthClosed() => l10n.reopenLater,
  MonthNotReady() => l10n.closeNotReady,
  _ => l10n.saveFailed,
};
