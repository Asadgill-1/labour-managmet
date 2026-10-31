import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cash/cash_screen.dart';
import '../features/companies/companies_screen.dart';
import '../features/companies/sites_screen.dart';
import '../features/groups/groups_screen.dart';
import '../features/labour/labour_screen.dart';
import '../features/more/profile_form_screen.dart';
import '../features/more/settings_screen.dart';
import '../features/payroll/payroll_screen.dart';
import '../features/rates/balances_screen.dart';
import '../features/registers/ledger_screen.dart';
import '../features/rates/rates_screen.dart';
import '../features/rooms/rooms_screen.dart';
import '../features/today/today_screen.dart';
import '../features/visa/visa_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'settings.dart';
import 'side_panel.dart';
import 'theme.dart';

Widget _screen(Section section) => switch (section) {
  Section.today => const TodayScreen(),
  Section.cash => const CashScreen(),
  Section.rooms => const RoomsScreen(),
  Section.companies => const CompaniesScreen(),
  Section.sites => const SitesScreen(),
  Section.labour => const LabourScreen(),
  Section.groups => const GroupsScreen(),
  Section.rates => const RatesScreen(),
  Section.balances => const BalancesScreen(),
  Section.payroll => const PayrollScreen(),
  Section.settings => const SettingsScreen(),
  Section.visa => const VisaScreen(),
  Section.attendanceRegister ||
  Section.workerRegister ||
  Section.visaRegister ||
  Section.companyRegister ||
  Section.payrollRegister ||
  Section.advanceRegister ||
  Section.cashRegister ||
  Section.roomRegister => LedgerScreen(section),
};

final _routerProvider = Provider(
  (ref) => GoRouter(
    initialLocation: '/today',
    routes: [
      // Detail screens use Navigator.push inside a branch, so each section keeps its place (D-027).
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _Shell(shell),
        branches: [
          for (final section in Section.values)
            StatefulShellBranch(routes: [GoRoute(path: '/${section.name}', builder: (_, _) => _screen(section))]),
        ],
      ),
    ],
  ),
);

class LabourApp extends ConsumerWidget {
  const LabourApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: usePalette(settings.palette),
      routerConfig: ref.watch(_routerProvider),
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        if (!settings.largeText) return child!;
        final scale = MediaQuery.textScalerOf(context).scale(1) * 1.3;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
    );
  }
}

class _Shell extends ConsumerWidget {
  const _Shell(this.shell);

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    if (profile.hasError) {
      return Scaffold(
        body: SafeArea(
          child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.databaseError)),
        ),
      );
    }
    if (!profile.hasValue) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (profile.value == null) return const ProfileFormScreen();
    return Scaffold(
      key: shellKey,
      drawer: SidePanel(
        current: Section.values[shell.currentIndex],
        onSelect: (section) {
          shellKey.currentState?.closeDrawer();
          shell.goBranch(section.index, initialLocation: section.index == shell.currentIndex);
        },
      ),
      body: shell,
    );
  }
}
