import 'package:flutter/material.dart';

const ink = Color(0xFF1F2A7A);
const paper = Color(0xFFF4F7FB);
const rule = Color(0xFFD5DCE8);
const hiVis = Color(0xFFFFC400);
const due = Color(0xFFB3261E);
const settled = Color(0xFF1B6E43);

/// Lines up digits in amount columns.
const amountStyle = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: ink,
    onPrimary: Colors.white,
    secondary: hiVis,
    onSecondary: ink,
    surface: paper,
    onSurface: ink,
    error: due,
    outline: rule,
  ),
  scaffoldBackgroundColor: paper,
  dividerTheme: const DividerThemeData(color: rule, thickness: 1, space: 1),
  appBarTheme: const AppBarTheme(backgroundColor: paper, foregroundColor: ink, elevation: 0, scrolledUnderElevation: 0),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: rule,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: hiVis,
      foregroundColor: ink,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 16),
    bodyLarge: TextStyle(fontSize: 17),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
  ),
);

/// The screen's one main action, at thumb height above the tabs (UX-03).
class MainActionBar extends StatelessWidget {
  const MainActionBar({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
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
