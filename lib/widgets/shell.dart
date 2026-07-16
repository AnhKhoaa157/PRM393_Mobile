part of '../main.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.session});
  final SessionController session;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
          session: widget.session, openTab: (i) => setState(() => tab = i)),
      HistoryPage(session: widget.session),
      WalletPage(session: widget.session),
      PackagesPage(session: widget.session),
      ProfilePage(session: widget.session)
    ];
    final selectedTab = tab.clamp(0, pages.length - 1) as int;
    return Scaffold(
      body: IndexedStack(index: selectedTab, children: pages),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                  children: const [
                _NavItem(index: 0, icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
                _NavItem(index: 1, icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History'),
                _NavItem(index: 2, icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Wallet'),
                _NavItem(index: 3, icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Packages'),
                _NavItem(index: 4, icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
              ].map((item) => Expanded(child: item)).toList()))),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.index, required this.icon, required this.activeIcon, required this.label});
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorStateOfType<_ShellState>();
    final active = (shell?.tab.clamp(0, 4) as int?) == index;
    return Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => shell?.setState(() => shell.tab = index),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                          color: active ? AppColors.brandSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: Icon(active ? activeIcon : icon,
                          color: active ? AppColors.brand : AppColors.muted, size: 22)),
                  const SizedBox(height: 3),
                  Text(label,
                      style: TextStyle(
                          color: active ? AppColors.brand : AppColors.muted,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11))
                ]))));
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame(
      {super.key, required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          toolbarHeight: 70,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
            const Text('Parking made simple', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          actions: actions),
      body: child);
}
