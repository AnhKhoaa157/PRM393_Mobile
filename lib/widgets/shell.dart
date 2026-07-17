part of '../main.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SHELL WRAPPER (For backwards compatibility with app.dart)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class Shell extends StatelessWidget {
  const Shell({super.key, required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return MainNavigationShell(session: session);
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MAIN NAVIGATION SHELL (IndexedStack with standard full-width bottom bar)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, required this.session});
  final SessionController session;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
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

    final selectedTab = tab.clamp(0, pages.length - 1);

    return Scaffold(
      extendBody: false, // Standard layout: content ends exactly at the top of bottom bar
      backgroundColor: const Color(0xFFF0F4FA),
      body: IndexedStack(
        index: selectedTab,
        children: pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: selectedTab,
        onTap: (index) => setState(() => tab = index),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CUSTOM BOTTOM NAVIGATION BAR (Standard Full-Width Premium Glassmorphism)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _BottomNavItemData {
  const _BottomNavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = const [
      _BottomNavItemData(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      _BottomNavItemData(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History'),
      _BottomNavItemData(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
      _BottomNavItemData(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded, label: 'Packages'),
      _BottomNavItemData(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SafeArea(
            child: SizedBox(
              height: 60,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / 5;
                  return Stack(
                    children: [
                      // Sleek Top-Aligned Sliding Line Indicator
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        left: currentIndex * tabWidth + (tabWidth - 28) / 2,
                        top: 0,
                        width: 28,
                        height: 3,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF0052CC),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(2),
                              bottomRight: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),

                      // Navigation Items Row
                      Row(
                        children: List.generate(items.length, (index) {
                          final item = items[index];
                          final active = index == currentIndex;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => onTap(index),
                              behavior: HitTestBehavior.opaque,
                              child: _NavBarItem(
                                active: active,
                                data: item,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// NAV BAR ITEM WIDGET WITH BOUNCE MICRO-INTERACTIONS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _NavBarItem extends StatefulWidget {
  const _NavBarItem({required this.active, required this.data});
  final bool active;
  final _BottomNavItemData data;

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.85, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.12, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    
    if (widget.active) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _NavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF0052CC);
    const inactiveColor = Color(0xFF64748B);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: SizedBox(
            height: 26,
            child: Center(
              child: Icon(
                widget.active ? widget.data.activeIcon : widget.data.icon,
                color: widget.active ? activeColor : inactiveColor,
                size: 23,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.data.label,
          style: TextStyle(
            color: widget.active ? activeColor : inactiveColor,
            fontWeight: widget.active ? FontWeight.w900 : FontWeight.w600,
            fontSize: 11,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// PAGE FRAME (For compatibility with other screens)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 70,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
              const Text('Parking made simple', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          actions: actions,
        ),
        body: child,
      );
}
