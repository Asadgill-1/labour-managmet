import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/more/profile_form_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'theme.dart';

/// Every main screen. The index is its branch in the router.
enum Section { today, companies, sites, labour, groups, rates, balances, settings }

/// The shell's Scaffold. Main screens have their own Scaffold, so they reach the panel through this key.
final shellKey = GlobalKey<ScaffoldState>();

/// Shows the panel. The word stays beside the icon, for users who don't read three lines as a menu (UX-04).
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => shellKey.currentState?.openDrawer(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(AppLocalizations.of(context).menuLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

const _dim = Color(0xFF9AA0A7);

/// Left panel, hidden until asked for (D-027). Sections not built yet show as "soon" and do nothing (AI-07).
class SidePanel extends ConsumerWidget {
  const SidePanel({required this.current, required this.onSelect, super.key});

  final Section current;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).value;
    final navigator = Navigator.of(context);

    Widget item(Section section, IconData icon, String label) =>
        _PanelItem(icon, label, selected: section == current, onTap: () => onSelect(section));

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: hiVis,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.tradingName ?? profile?.legalName ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).appBarTheme.titleTextStyle,
                          ),
                          const SizedBox(height: 2),
                          Text(l10n.localOnlyNote, style: const TextStyle(fontSize: 13, color: ink)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.menuClose,
                      color: ink,
                      icon: const Icon(Icons.chevron_left, size: 30),
                      onPressed: () => shellKey.currentState?.closeDrawer(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                _PanelGroup(l10n.groupDaily),
                item(Section.today, Icons.today, l10n.tabToday),
                _PanelGroup(l10n.groupRegisters),
                item(Section.companies, Icons.apartment, l10n.tabCompanies),
                item(Section.sites, Icons.location_on, l10n.sitesHeading),
                item(Section.labour, Icons.groups, l10n.tabLabour),
                item(Section.groups, Icons.diversity_3, l10n.tabGroups),
                item(Section.rates, Icons.sell, l10n.tabRates),
                item(Section.balances, Icons.history, l10n.openingHeading),
                _PanelGroup(l10n.groupPayroll),
                _PanelItem(Icons.payments, l10n.menuPayroll),
                _PanelItem(Icons.savings, l10n.menuAdvances),
                _PanelItem(Icons.outbox, l10n.menuPayments),
                _PanelItem(Icons.shopping_bag, l10n.menuExpenses),
                _PanelGroup(l10n.groupBilling),
                _PanelItem(Icons.fact_check, l10n.menuTimesheets),
                _PanelItem(Icons.request_quote, l10n.menuInvoices),
                _PanelItem(Icons.move_to_inbox, l10n.menuReceived),
                _PanelGroup(l10n.groupMore),
                _PanelItem(Icons.bar_chart, l10n.menuReports),
                _PanelItem(Icons.folder, l10n.menuDocuments),
                _PanelItem(Icons.group_add, l10n.menuTeam),
                _PanelItem(Icons.cloud_upload, l10n.menuBackup),
                _PanelItem(Icons.workspace_premium, l10n.menuPlan),
                _PanelItem(Icons.help, l10n.menuHelp),
              ],
            ),
          ),
          const Divider(color: Color(0xFF30353A)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _PanelItem(
                    Icons.business,
                    l10n.myCompany,
                    onTap: () {
                      shellKey.currentState?.closeDrawer();
                      navigator.push(MaterialPageRoute<void>(builder: (_) => ProfileFormScreen(profile: profile)));
                    },
                  ),
                  item(Section.settings, Icons.settings, l10n.tabSettings),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelGroup extends StatelessWidget {
  const _PanelGroup(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label, style: const TextStyle(fontSize: 13, color: _dim)),
    );
  }
}

class _PanelItem extends StatelessWidget {
  const _PanelItem(this.icon, this.label, {this.selected = false, this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ink : (onTap == null ? _dim : Colors.white);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        minTileHeight: 48,
        tileColor: Colors.transparent,
        selectedTileColor: hiVis,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        selected: selected,
        enabled: onTap != null,
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(fontFamily: headingFont, fontSize: 17, fontWeight: FontWeight.w700, color: color)),
        trailing: onTap == null ? Text(AppLocalizations.of(context).soon, style: const TextStyle(fontSize: 13, color: _dim)) : null,
      ),
    );
  }
}
