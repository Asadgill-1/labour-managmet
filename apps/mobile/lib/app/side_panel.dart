import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/more/profile_form_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'theme.dart';

/// Every main screen. The index is its branch in the router.
enum Section {
  today,
  groups,
  attendanceRegister,
  labour,
  workerRegister,
  visa,
  visaRegister,
  companies,
  sites,
  rates,
  companyRegister,
  payroll,
  payrollRegister,
  advanceRegister,
  timesheets,
  cash,
  balances,
  cashRegister,
  closing,
  rooms,
  roomRegister,
  documents,
  letterhead,
  settings,
}

String sectionLabel(AppLocalizations l10n, Section section) => switch (section) {
  Section.today => l10n.tabToday,
  Section.groups => l10n.tabGroups,
  Section.attendanceRegister => l10n.regAttendance,
  Section.labour => l10n.tabLabour,
  Section.workerRegister => l10n.regWorkers,
  Section.visa => l10n.tabVisa,
  Section.visaRegister => l10n.regVisa,
  Section.companies => l10n.tabCompanies,
  Section.sites => l10n.sitesHeading,
  Section.rates => l10n.tabRates,
  Section.companyRegister => l10n.regCompanies,
  Section.payroll => l10n.menuPayroll,
  Section.payrollRegister => l10n.regPayroll,
  Section.advanceRegister => l10n.regAdvance,
  Section.timesheets => l10n.tsTab,
  Section.cash => l10n.tabCash,
  Section.balances => l10n.openingHeading,
  Section.cashRegister => l10n.regCash,
  Section.closing => l10n.tabClosing,
  Section.rooms => l10n.tabRooms,
  Section.roomRegister => l10n.regRooms,
  Section.documents => l10n.docsTab,
  Section.letterhead => l10n.lhTab,
  Section.settings => l10n.tabSettings,
};

/// A main tab and the sub-tabs under it. Related screens stay together (D-036).
class MainTab {
  const MainTab(this.label, this.icon, this.sections);

  final String Function(AppLocalizations) label;
  final IconData icon;
  final List<Section> sections;
}

final mainTabs = [
  MainTab((l) => l.mainAttendance, Icons.how_to_reg, const [Section.today, Section.groups, Section.attendanceRegister]),
  MainTab((l) => l.tabLabour, Icons.groups, const [Section.labour, Section.workerRegister]),
  MainTab((l) => l.mainVisa, Icons.badge, const [Section.visa, Section.visaRegister]),
  MainTab((l) => l.tabCompanies, Icons.apartment, const [Section.companies, Section.sites, Section.rates, Section.companyRegister]),
  MainTab((l) => l.menuPayroll, Icons.payments, const [Section.payroll, Section.payrollRegister, Section.advanceRegister]),
  MainTab((l) => l.mainBilling, Icons.receipt_long, const [Section.timesheets]),
  MainTab((l) => l.mainMoney, Icons.account_balance_wallet, const [Section.cash, Section.balances, Section.cashRegister, Section.closing]),
  MainTab((l) => l.tabRooms, Icons.bed, const [Section.rooms, Section.roomRegister]),
  MainTab((l) => l.mainDocuments, Icons.description, const [Section.documents, Section.letterhead]),
];

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
            child: Text(AppLocalizations.of(context).menuLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// The sub-tabs of the current main tab, under the header, so moving between them takes one tap.
class SubTabs extends StatefulWidget implements PreferredSizeWidget {
  const SubTabs(this.section, {this.below, super.key});

  final Section section;

  /// A screen's own tabs, shown under these.
  final PreferredSizeWidget? below;

  @override
  Size get preferredSize => Size.fromHeight(46 + (below?.preferredSize.height ?? 0));

  @override
  State<SubTabs> createState() => _SubTabsState();
}

class _SubTabsState extends State<SubTabs> {
  final _selected = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _selected.currentContext;
      if (context != null && context.mounted) Scrollable.ensureVisible(context, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final siblings = mainTabs.firstWhere((t) => t.sections.contains(widget.section)).sections;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final section in siblings)
                Padding(
                  key: section == widget.section ? _selected : null,
                  padding: EdgeInsets.zero,
                  child: _SubTab(
                    sectionLabel(l10n, section),
                    selected: section == widget.section,
                    onTap: () => StatefulNavigationShell.of(context).goBranch(section.index),
                  ),
                ),
            ],
          ),
        ),
        ?widget.below,
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  const _SubTab(this.label, {required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: selected ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? Colors.white : Colors.transparent, width: 3)),
          ),
          child: Text(
            label,
            style: TextStyle(fontFamily: headingFont, fontSize: 14.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? Colors.white : Colors.white.withValues(alpha: 0.82)),
          ),
        ),
      ),
    );
  }
}

/// Left panel, hidden until asked for (D-027). Main tabs open to show their sub-tabs (D-036).
/// Sections not built yet show as "soon" and do nothing (AI-07).
class SidePanel extends ConsumerWidget {
  const SidePanel({required this.current, required this.onSelect, super.key});

  final Section current;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).value;
    final navigator = Navigator.of(context);

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: brand,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
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
                          Text(l10n.localOnlyNote, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.menuClose,
                      color: Colors.white,
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final tab in mainTabs)
                  _MainTabRow(
                    icon: tab.icon,
                    label: tab.label(l10n),
                    open: tab.sections.contains(current),
                    children: [
                      for (final section in tab.sections)
                        _SubRow(sectionLabel(l10n, section), key: ValueKey('sub-${sectionLabel(l10n, section)}'), selected: section == current, onTap: () => onSelect(section)),
                    ],
                  ),
                _MainTabRow(
                  icon: Icons.schedule,
                  label: l10n.groupSoon,
                  open: false,
                  children: [
                    for (final label in [
                      l10n.menuTimesheets,
                      l10n.menuInvoices,
                      l10n.menuReceived,
                      l10n.menuReports,
                      l10n.menuTeam,
                      l10n.menuBackup,
                      l10n.menuPlan,
                      l10n.menuHelp,
                    ])
                      _SubRow(label),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _FooterRow(
                    Icons.business,
                    l10n.myCompany,
                    onTap: () {
                      shellKey.currentState?.closeDrawer();
                      navigator.push(MaterialPageRoute<void>(builder: (_) => ProfileFormScreen(profile: profile)));
                    },
                  ),
                  _FooterRow(Icons.settings, l10n.tabSettings, selected: current == Section.settings, onTap: () => onSelect(Section.settings)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainTabRow extends StatelessWidget {
  const _MainTabRow({required this.icon, required this.label, required this.open, required this.children});

  final IconData icon;
  final String label;
  final bool open;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: open,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(44, 0, 12, 6),
      iconColor: muted,
      collapsedIconColor: muted,
      minTileHeight: 48,
      leading: Icon(icon, color: open ? action : muted, size: 22),
      title: Text(label, style: sectionTitleStyle.copyWith(fontWeight: FontWeight.w500)),
      children: children,
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow(this.label, {this.selected = false, this.onTap, super.key});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? brandSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: headingFont,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? action : (onTap == null ? muted : ink),
                  ),
                ),
              ),
              if (onTap == null) Text(AppLocalizations.of(context).soon, style: const TextStyle(fontSize: 13, color: muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow(this.icon, this.label, {this.selected = false, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        minTileHeight: 46,
        tileColor: Colors.transparent,
        selectedTileColor: brandSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        selected: selected,
        onTap: onTap,
        leading: Icon(icon, color: selected ? action : muted),
        title: Text(label, style: TextStyle(fontFamily: headingFont, fontSize: 15, fontWeight: FontWeight.w500, color: selected ? action : ink)),
      ),
    );
  }
}
