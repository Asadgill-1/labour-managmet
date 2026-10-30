import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/accounts_screen.dart';
import '../features/companies/companies_screen.dart';
import '../features/labour/labour_screen.dart';
import '../features/more/more_screen.dart';
import '../features/more/profile_form_screen.dart';
import '../features/today/today_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'settings.dart';
import 'theme.dart';

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(routes: [GoRoute(path: path, builder: (_, _) => screen)]);
}

final _routerProvider = Provider(
  (ref) => GoRouter(
    initialLocation: '/today',
    routes: [
      // Detail screens use Navigator.push inside a branch, so the tabs stay visible (UX-01).
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _TabShell(shell),
        branches: [
          _branch('/today', const TodayScreen()),
          _branch('/companies', const CompaniesScreen()),
          _branch('/labour', const LabourScreen()),
          _branch('/accounts', const AccountsScreen()),
          _branch('/more', const MoreScreen()),
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
      theme: appTheme,
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

class _TabShell extends ConsumerWidget {
  const _TabShell(this.shell);

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
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.today), label: l10n.tabToday),
          NavigationDestination(icon: const Icon(Icons.apartment), label: l10n.tabCompanies),
          NavigationDestination(icon: const Icon(Icons.groups), label: l10n.tabLabour),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: l10n.tabAccounts),
          NavigationDestination(icon: const Icon(Icons.more_horiz), label: l10n.tabMore),
        ],
      ),
    );
  }
}
