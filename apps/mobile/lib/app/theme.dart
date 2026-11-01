import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/closing.dart';
import '../data/tenant_database.dart';
import '../l10n/app_localizations.dart';

/// The colours a user can choose from in Settings (D-040).
enum AppPalette {
  blue(Color(0xFF143E8F), Color(0xFFE7EDFA), Color(0xFFE8590C), Colors.white),
  green(Color(0xFF0B6B5D), Color(0xFFE0F2EE), Color(0xFFF2B233), Color(0xFF1B2A25)),
  maroon(Color(0xFF7A1F3D), Color(0xFFF7E8ED), Color(0xFFE9A92B), Color(0xFF2A1A12));

  const AppPalette(this.brand, this.brandSoft, this.action, this.onAction);

  final Color brand;
  final Color brandSoft;
  final Color action;
  final Color onAction;
}

var _palette = AppPalette.blue;

/// The header and everything that means "this app".
Color get brand => _palette.brand;
Color get brandSoft => _palette.brandSoft;

/// The screen's one main action.
Color get action => _palette.action;
Color get onAction => _palette.onAction;

const ink = Color(0xFF1C2433);
const muted = Color(0xFF5F6878);
const paper = Color(0xFFF3F4F7);
const rule = Color(0xFFE2E5EB);
const due = Color(0xFFC62828);
const dueSoft = Color(0xFFFDE7E7);
const settled = Color(0xFF12804F);
const settledSoft = Color(0xFFDDF5E8);
const warn = Color(0xFF9A5B00);
const warnSoft = Color(0xFFFFF1D6);

/// Named outright and bundled: a style with no family falls back to the phone's own font, which on some phones is a handwriting theme.
const headingFont = 'Roboto';

const _heading = TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, color: ink);

/// Section headings inside a screen.
const sectionTitleStyle = TextStyle(fontFamily: headingFont, fontSize: 17, fontWeight: FontWeight.w700, color: ink);

/// Lines up digits in amount columns.
const amountStyle = TextStyle(fontFamily: headingFont, fontSize: 17, fontWeight: FontWeight.w700, color: ink, fontFeatures: [FontFeature.tabularFigures()]);

final _corner12 = BorderRadius.circular(12);

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
    outline: Color(0xFF9AA3B2),
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
  drawerTheme: const DrawerThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder()),
  tabBarTheme: TabBarThemeData(
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
    indicatorColor: action,
    dividerColor: Colors.transparent,
    labelStyle: _heading.copyWith(fontSize: 15),
    unselectedLabelStyle: _heading.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
  ),
  listTileTheme: ListTileThemeData(
    tileColor: Colors.white,
    iconColor: muted,
    titleTextStyle: _heading.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    subtitleTextStyle: const TextStyle(fontFamily: headingFont, fontSize: 13.5, height: 1.35, color: muted),
    leadingAndTrailingTextStyle: const TextStyle(fontFamily: headingFont, fontSize: 15, color: ink),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: action,
      foregroundColor: onAction,
      disabledBackgroundColor: rule,
      disabledForegroundColor: muted,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: _heading.copyWith(fontSize: 17),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: brand,
      backgroundColor: brandSoft,
      minimumSize: const Size.fromHeight(48),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: _corner12),
      textStyle: _heading.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: brand,
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(fontFamily: headingFont, fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: _corner12, borderSide: const BorderSide(color: rule)),
    enabledBorder: OutlineInputBorder(borderRadius: _corner12, borderSide: const BorderSide(color: Color(0xFFCBD2DE))),
    focusedBorder: OutlineInputBorder(borderRadius: _corner12, borderSide: BorderSide(color: brand, width: 2)),
  ),
  chipTheme: ChipThemeData(
    showCheckmark: false,
    selectedColor: brand,
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFCBD2DE)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    labelStyle: TextStyle(
      fontFamily: headingFont,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      color: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : ink),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titleTextStyle: _heading.copyWith(fontSize: 19),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
  ),
  snackBarTheme: const SnackBarThemeData(backgroundColor: ink, contentTextStyle: TextStyle(fontFamily: headingFont, fontSize: 15, color: Colors.white)),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 15),
    bodyLarge: TextStyle(fontSize: 16),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
  ),
);

/// The coloured block under the header that holds a screen's date and main figures.
class TopBand extends StatelessWidget {
  const TopBand({required this.child, this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 16), super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: brand, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22))),
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
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x141C2433), blurRadius: 12, offset: Offset(0, -2))]),
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
