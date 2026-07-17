part of '../main.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key, required this.session});
  final SessionController session;
  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> with TickerProviderStateMixin {
  final search = TextEditingController();
  List<Map<String, dynamic>> packages = [];
  List<Map<String, dynamic>> subscriptions = [];
  bool loading = true;
  String tab = 'browse'; // browse / mine
  String vehicleFilter = 'all';
  String durationFilter = 'all';
  String statusFilter = 'all';
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    search.addListener(_refreshFilters);
    load();
  }

  @override
  void dispose() {
    search.removeListener(_refreshFilters);
    search.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _refreshFilters() => setState(() {});

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        widget.session.api.request('/users/long-term/packages', token: widget.session.token),
        widget.session.api.request('/users/long-term/subscriptions', token: widget.session.token),
      ]);
      if (mounted) {
        setState(() {
          packages = _items(values[0], 'packages');
          subscriptions = _items(values[1]);
        });
      }
    } catch (error) {
      if (mounted) _snack(error);
    }
    if (mounted) {
      setState(() => loading = false);
      _staggerCtrl.forward(from: 0);
    }
  }

  Future<void> subscribe(Map<String, dynamic> package) async {
    final eligiblePlates = widget.session.user!.plates
        .where((plate) => _matchesVehicle(plate.type, package))
        .toList();
    if (eligiblePlates.isEmpty) {
      _snack('Add a matching license plate in Profile before subscribing.');
      return;
    }
    final plate = await showVehiclePicker(context,
        plates: eligiblePlates,
        title: 'Choose a vehicle',
        description: 'This vehicle will be linked to the package.');
    if (plate == null) return;
    try {
      await widget.session.api.request('/users/long-term/subscriptions',
          method: 'POST', token: widget.session.token, body: {
        'packageId': package['_id'],
        'plateNumber': plate.number,
      });
      await load();
      if (mounted) {
        showAppNotice(context, 'Package subscription created.', tone: AppNoticeTone.success);
      }
    } catch (error) {
      if (mounted) _snack(error);
    }
  }

  Future<void> renew(Map<String, dynamic> item) async {
    final id = '${item['_id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      await widget.session.api.request('/users/long-term/subscriptions/$id/renew',
          method: 'POST', token: widget.session.token);
      await load();
      if (mounted) {
        showAppNotice(context, 'Subscription renewed.', tone: AppNoticeTone.success);
      }
    } catch (error) {
      if (mounted) _snack(error);
    }
  }

  Future<void> cancel(Map<String, dynamic> item) async {
    final id = '${item['_id'] ?? ''}';
    if (id.isEmpty) return;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Cancel subscription?',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4)),
                  const SizedBox(height: AppSpace.sm),
                  const Text('Your eligible refund is calculated based on the building policy. Are you sure you want to cancel?',
                      style: TextStyle(color: LightTheme.textSecondary, fontSize: 14, height: 1.5)),
                  const SizedBox(height: AppSpace.lg),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Keep it'))),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                        child: const Text('Cancel'))),
                  ])
                ]))));
    if (accepted != true) return;
    try {
      await widget.session.api.request(
          '/users/long-term/subscriptions/$id/cancel',
          method: 'POST', token: widget.session.token, body: {
        'cancelReason': 'no_longer_needed',
      });
      await load();
      if (mounted) {
        showAppNotice(context, 'Subscription cancelled.', tone: AppNoticeTone.success);
      }
    } catch (error) {
      if (mounted) _snack(error);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _vehicleText(Map<String, dynamic> package) {
    final vehicle = package['vehicleType'];
    if (vehicle is Map) {
      return '${vehicle['code'] ?? vehicle['name'] ?? ''}'.toLowerCase();
    }
    return '$vehicle'.toLowerCase();
  }

  bool _matchesVehicle(String plateType, Map<String, dynamic> package) {
    final vehicle = _vehicleText(package);
    if (vehicle.isEmpty || vehicle == 'all') return true;
    if (plateType == 'motorcycle') {
      return vehicle.contains('motor') || vehicle.contains('moto') || vehicle.contains('bike');
    }
    return vehicle.contains('car') || vehicle.contains('auto') || vehicle.contains('oto');
  }

  bool _matchesFilters(Map<String, dynamic> package, {String? status}) {
    final building = _asMap(package['building']);
    final query = search.text.trim().toLowerCase();
    final searchable = [
      '${package['name'] ?? ''}',
      '${building['name'] ?? ''}',
      '${building['code'] ?? ''}',
      '${building['address'] ?? ''}',
    ].join(' ').toLowerCase();
    if (query.isNotEmpty && !searchable.contains(query)) return false;
    if (vehicleFilter != 'all') {
      final type = _vehicleText(package);
      if (vehicleFilter == 'car' && !(type.contains('car') || type.contains('auto') || type.contains('oto'))) return false;
      if (vehicleFilter == 'motorcycle' && !(type.contains('motor') || type.contains('moto') || type.contains('bike'))) return false;
    }
    if (durationFilter != 'all' && '${package['durationDays']}' != durationFilter) return false;
    return statusFilter == 'all' || status == null || status == statusFilter;
  }

  List<Map<String, dynamic>> get _filteredPackages =>
      packages.where(_matchesFilters).toList();

  List<Map<String, dynamic>> get _filteredSubscriptions => subscriptions.where((item) {
        final package = _asMap(item['package']);
        final building = _asMap(item['building']);
        final normalized = {...package};
        if (normalized['building'] == null && building.isNotEmpty) {
          normalized['building'] = building;
        }
        return _matchesFilters(normalized, status: '${item['status'] ?? ''}');
      }).toList();

  Map<String, List<Map<String, dynamic>>> get _packagesByBuilding {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final package in _filteredPackages) {
      final building = _asMap(package['building']);
      final key = '${building['_id'] ?? building['id'] ?? 'other'}';
      grouped.putIfAbsent(key, () => []).add(package);
    }
    return grouped;
  }

  void _snack(Object value) => showAppNotice(context, value);

  Animation<double> _stagger(int i, {int total = 8}) {
    final start = (i / total) * 0.55;
    final end   = (start + 0.5).clamp(0.0, 1.0);
    return CurvedAnimation(parent: _staggerCtrl, curve: Interval(start, end, curve: Curves.easeOutCubic));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: RefreshIndicator(
        onRefresh: load,
        color: LightTheme.brandBlue,
        strokeWidth: 2.5,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // â”€â”€ Clean Pinned SliverAppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverAppBar(
              pinned: true,
              backgroundColor: const Color(0xFFF0F4FA),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Packages',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.5)),
              actions: [
                _SpringRefreshButton(onTap: load),
                const SizedBox(width: 16),
              ],
            ),

            // â”€â”€ Sub-description text â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Choose a long-term parking package for your vehicle.',
                      style: TextStyle(color: LightTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),

            // â”€â”€ Custom sliding tab switcher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.md),
                child: _CustomSlidingSegment(
                  selected: tab,
                  onChanged: (v) => setState(() { tab = v; _staggerCtrl.forward(from: 0); }),
                ),
              ),
            ),

            // â”€â”€ Search & Filters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: _FiltersWidget(
                  searchController: search,
                  tab: tab,
                  vehicleFilter: vehicleFilter,
                  durationFilter: durationFilter,
                  statusFilter: statusFilter,
                  onVehicleSelected: (v) => setState(() => vehicleFilter = v),
                  onDurationSelected: (v) => setState(() => durationFilter = v),
                  onStatusSelected: (v) => setState(() => statusFilter = v),
                ),
              ),
            ),

            // â”€â”€ Loading indicator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: const LinearProgressIndicator(minHeight: 3, color: LightTheme.brandBlue, backgroundColor: Color(0xFFDCE5F0)),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),

            // â”€â”€ Content list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (!loading && tab == 'browse') ..._browseContent(),
            if (!loading && tab == 'mine') ..._subscriptionContent(),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
          ],
        ),
      ),
    );
  }

  List<Widget> _browseContent() {
    if (packages.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false,
            child: _PackagesEmptyState(icon: Icons.inventory_2_outlined,
                title: 'No packages available', detail: 'New packages will be listed here.')),
      ];
    }
    if (_packagesByBuilding.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false,
            child: _PackagesEmptyState(icon: Icons.search_off_outlined,
                title: 'No matching packages', detail: 'Try changing the filters.')),
      ];
    }

    final list = <Widget>[];
    var staggerIndex = 0;
    _packagesByBuilding.forEach((key, group) {
      final building = _asMap(group.first['building']);
      list.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xs),
          child: Row(
            children: [
              Container(
                height: 38, width: 38,
                decoration: BoxDecoration(
                  color: LightTheme.brandBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: LightTheme.brandBlue.withOpacity(0.20)),
                ),
                child: Icon(Icons.business_rounded, color: LightTheme.brandBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${building['name'] ?? 'Parking building'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4)),
                  if ('${building['code'] ?? ''}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text('${building['code']}'.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF00A8E8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ));

      list.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 6),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, idx) {
              final item = group[idx];
              final localIdx = staggerIndex++;
              return AnimatedBuilder(
                animation: _stagger(localIdx),
                builder: (_, ch) => Opacity(
                  opacity: _stagger(localIdx).value.clamp(0.0, 1.0),
                  child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _stagger(localIdx).value.clamp(0.0, 1.0))), child: ch),
                ),
                child: _ParkingPackageCard(item: item, onSubscribe: () => subscribe(item)),
              );
            },
            childCount: group.length,
          ),
        ),
      ));
    });
    return list;
  }

  List<Widget> _subscriptionContent() {
    if (subscriptions.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false,
            child: _PackagesEmptyState(icon: Icons.card_membership_outlined,
                title: 'No subscriptions yet', detail: 'Your active and past subscriptions will appear here.')),
      ];
    }
    if (_filteredSubscriptions.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false,
            child: _PackagesEmptyState(icon: Icons.search_off_outlined,
                title: 'No matching subscriptions', detail: 'Try changing the filters.')),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 4),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, idx) {
              final item = _filteredSubscriptions[idx];
              return AnimatedBuilder(
                animation: _stagger(idx),
                builder: (_, ch) => Opacity(
                  opacity: _stagger(idx).value.clamp(0.0, 1.0),
                  child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _stagger(idx).value.clamp(0.0, 1.0))), child: ch),
                ),
                child: _SubscriptionCard(item: item, onRenew: () => renew(item), onCancel: () => cancel(item)),
              );
            },
            childCount: _filteredSubscriptions.length,
          ),
        ),
      )
    ];
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CUSTOM SEGMENTED SLIDER
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _CustomSlidingSegment extends StatelessWidget {
  const _CustomSlidingSegment({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isBrowse = selected == 'browse';
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: isBrowse ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0052CC), Color(0xFF0072FF)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0038A0).withOpacity(0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged('browse'),
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.explore_outlined, size: 16, color: isBrowse ? Colors.white : LightTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Browse packages',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isBrowse ? Colors.white : LightTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged('mine'),
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: !isBrowse ? Colors.white : LightTheme.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'My packages',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: !isBrowse ? Colors.white : LightTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SPRING REFRESH BUTTON
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _SpringRefreshButton extends StatefulWidget {
  const _SpringRefreshButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_SpringRefreshButton> createState() => _SpringRefreshButtonState();
}
class _SpringRefreshButtonState extends State<_SpringRefreshButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.82), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.82, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: RotationTransition(
        turns: _rotationAnimation,
        child: GestureDetector(
          onTap: _handleTap,
          child: Container(
            height: 38, width: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: LightTheme.brandBlue.withOpacity(0.22), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(Icons.refresh_rounded, color: LightTheme.brandBlue, size: 19),
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SEARCH & FILTERS WIDGET
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _FiltersWidget extends StatefulWidget {
  const _FiltersWidget({
    required this.searchController, required this.tab,
    required this.vehicleFilter, required this.durationFilter, required this.statusFilter,
    required this.onVehicleSelected, required this.onDurationSelected, required this.onStatusSelected,
  });
  final TextEditingController searchController;
  final String tab;
  final String vehicleFilter;
  final String durationFilter;
  final String statusFilter;
  final ValueChanged<String> onVehicleSelected;
  final ValueChanged<String> onDurationSelected;
  final ValueChanged<String> onStatusSelected;

  @override
  State<_FiltersWidget> createState() => _FiltersWidgetState();
}
class _FiltersWidgetState extends State<_FiltersWidget> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Animated search border glow
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isFocused ? [
            BoxShadow(color: const Color(0xFF00D2FF).withOpacity(0.15), blurRadius: 10, spreadRadius: 2)
          ] : [],
        ),
        child: TextField(
          controller: widget.searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search package or building',
            hintStyle: TextStyle(color: LightTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
            prefixIcon: const Icon(Icons.search_rounded, color: LightTheme.brandBlue, size: 20),
            suffixIcon: widget.searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () { widget.searchController.clear(); FocusScope.of(context).unfocus(); },
                    icon: const Icon(Icons.close_rounded, size: 18, color: LightTheme.textSecondary)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.8)),
          ),
        ),
      ),
      const SizedBox(height: AppSpace.md),

      // Vehicle filter row
      _FilterRow(
        label: 'Vehicle type',
        selected: widget.vehicleFilter,
        values: const {
          'all': 'All vehicles',
          'car': 'Car',
          'motorcycle': 'Motorcycle',
        },
        onSelected: widget.onVehicleSelected,
      ),
      const SizedBox(height: AppSpace.sm),

      // Duration filter row
      _FilterRow(
        label: 'Duration',
        selected: widget.durationFilter,
        values: const {
          'all': 'All durations',
          '7': '1 week',
          '30': '1 month',
          '365': '1 year',
        },
        onSelected: widget.onDurationSelected,
      ),

      // Status filter row (only My packages tab)
      if (widget.tab == 'mine') ...[
        const SizedBox(height: AppSpace.sm),
        _FilterRow(
          label: 'Status',
          selected: widget.statusFilter,
          values: const {
            'all': 'All status',
            'active': 'Active',
            'pending': 'Pending',
            'expired': 'Expired',
            'cancelled': 'Cancelled',
          },
          onSelected: widget.onStatusSelected,
        ),
      ]
    ]);
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.label, required this.selected, required this.values, required this.onSelected});
  final String label;
  final String selected;
  final Map<String, String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
          style: TextStyle(color: LightTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: values.entries.map((entry) {
          final active = selected == entry.key;
          return GestureDetector(
            onTap: () => onSelected(entry.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(colors: [Color(0xFF00D2FF), Color(0xFF0052CC)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: active ? null : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: active ? Colors.transparent : const Color(0xFFCBD5E1).withOpacity(0.60)),
                boxShadow: active
                    ? [BoxShadow(color: const Color(0xFF0072FF).withOpacity(0.24), blurRadius: 8, offset: const Offset(0, 3))]
                    : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? Colors.white : LightTheme.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// PARKING PACKAGE CARD (Re-designed for Premium Mobile UI)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ParkingPackageCard extends StatelessWidget {
  const _ParkingPackageCard({required this.item, required this.onSubscribe});
  final Map<String, dynamic> item;
  final VoidCallback onSubscribe;

  String _vehicleText(Map<String, dynamic> package) {
    final vehicle = package['vehicleType'];
    if (vehicle is Map) return '${vehicle['code'] ?? vehicle['name'] ?? ''}'.toLowerCase();
    return '$vehicle'.toLowerCase();
  }

  double _asNum(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String _money(num amount) => amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (_) => ',');

  @override
  Widget build(BuildContext context) {
    final name        = '${item['name'] ?? 'Parking package'}';
    final price       = _asNum(item['price']);
    final desc        = '${item['description'] ?? ''}'.trim();
    final duration    = item['durationDays'] ?? 'â€”';
    final vehicle     = _vehicleText(item);
    final isMotor     = vehicle.contains('motor') || vehicle.contains('moto') || vehicle.contains('bike');
    final dedicated   = item['allowDedicatedSlot'] == true;

    final vehicleColors = isMotor
        ? [const Color(0xFF7C3AED), const Color(0xFFA78BFA)]
        : [const Color(0xFF0052CC), const Color(0xFF00A8E8)];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top Row: Title + Tags on Left; Styled vehicle icon on Right
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left content: title + tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4, height: 1.25)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      _PastelTag(label: '$duration Days', bgColor: const Color(0xFFEFF6FF), fgColor: const Color(0xFF1D4ED8)),
                      _PastelTag(
                        label: isMotor ? 'Motorcycle' : 'Car',
                        bgColor: isMotor ? const Color(0xFFF5F3FF) : const Color(0xFFECFDF5),
                        fgColor: isMotor ? const Color(0xFF6D28D9) : const Color(0xFF047857),
                      ),
                      _PastelTag(
                        label: dedicated ? 'Dedicated slot' : 'Flexible parking',
                        bgColor: const Color(0xFFF1F5F9),
                        fgColor: const Color(0xFF475569),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right content: Vehicle Icon with circular gradient
            Container(
              height: 44, width: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [vehicleColors[0].withOpacity(0.18), vehicleColors[1].withOpacity(0.09)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: vehicleColors[0].withOpacity(0.25), width: 1.2),
              ),
              child: ShaderMask(
                shaderCallback: (r) => LinearGradient(colors: vehicleColors, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(r),
                child: Icon(isMotor ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded, color: Colors.white, size: 21),
              ),
            ),
          ],
        ),

        // Description text (if any)
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(desc, style: TextStyle(color: LightTheme.textSecondary, fontSize: 13, height: 1.45, fontWeight: FontWeight.w500)),
        ],

        const SizedBox(height: 16),
        // Spacer / divider representation
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        const SizedBox(height: 12),

        // Bottom Row: Price on Left; Subscribe button on Right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL PRICE'.toUpperCase(),
                    style: TextStyle(color: LightTheme.textMuted, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(
                  '${_money(price)} VND',
                  style: const TextStyle(color: LightTheme.brandBlue, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.3),
                ),
              ],
            ),
            _SubscribeScaleButton(onTap: onSubscribe),
          ],
        ),
      ]),
    );
  }
}

class _PastelTag extends StatelessWidget {
  const _PastelTag({required this.label, required this.bgColor, required this.fgColor});
  final String label;
  final Color bgColor;
  final Color fgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fgColor, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SubscribeScaleButton extends StatefulWidget {
  const _SubscribeScaleButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_SubscribeScaleButton> createState() => _SubscribeScaleButtonState();
}
class _SubscribeScaleButtonState extends State<_SubscribeScaleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_pressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0038A0), Color(0xFF0072FF)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0038A0).withOpacity(0.20),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Subscribe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SUBSCRIPTION CARD (My Packages)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.item, required this.onRenew, required this.onCancel});
  final Map<String, dynamic> item;
  final VoidCallback onRenew;
  final VoidCallback onCancel;

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _date(dynamic value) {
    if (value == null || '$value'.isEmpty) return '--/--/----';
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '$value';
    final date = parsed.toLocal();
    return date.day.toString().padLeft(2, '0') + '/' +
           date.month.toString().padLeft(2, '0') + '/' +
           date.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    final package  = _asMap(item['package']);
    final building = _asMap(item['building']).isNotEmpty ? _asMap(item['building']) : _asMap(package['building']);
    final slot     = _asMap(item['slot']);
    final status   = '${item['status'] ?? 'unknown'}';
    final name     = '${package['name'] ?? 'Parking package'}';
    final plate    = '${item['plateNumber'] ?? 'Vehicle'}';

    final (statusColor, statusBg, statusText) = switch (status) {
      'active'    => (const Color(0xFF16A34A), const Color(0xFFDCFCE7), 'Active'),
      'pending'   => (const Color(0xFFCA8A04), const Color(0xFFFEF3C7), 'Pending'),
      'cancelled' => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), 'Cancelled'),
      _           => (LightTheme.textMuted,    const Color(0xFFF1F5F9), status.toUpperCase()),
    };

    final canRenew = status == 'active' || status == 'expired';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top section: Status + Name
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              height: 40, width: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.card_membership_rounded, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.3)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),

        // Divider
        Container(height: 1, color: const Color(0xFFE2E8F0)),

        // Details lines
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _DetailRow(icon: Icons.business_outlined, label: 'Location', value: '${building['name'] ?? 'Parking building'}'),
            const SizedBox(height: 10),
            _DetailRow(icon: Icons.directions_car_outlined, label: 'Linked Plate', value: plate),
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.date_range_outlined,
              label: 'Validity',
              value: '${_date(item['startDate'])} â€“ ${_date(item['endDate'])}',
            ),
            if (slot.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailRow(icon: Icons.local_parking_outlined, label: 'Dedicated slot', value: '${slot['code'] ?? ''}'),
            ],
          ]),
        ),

        // Action buttons
        if (canRenew) ...[
          Container(height: 1, color: const Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton.icon(
                  onPressed: onRenew,
                  icon: const Icon(Icons.autorenew_rounded, size: 15),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LightTheme.brandBlue,
                    side: BorderSide(color: LightTheme.brandBlue.withOpacity(0.40)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  label: const Text('Renew', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              if (status == 'active') ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger.withOpacity(0.40)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              ]
            ]),
          )
        ],
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: LightTheme.textMuted),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: LightTheme.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      const Text(':', style: TextStyle(color: LightTheme.textMuted)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(color: LightTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EMPTY STATE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _PackagesEmptyState extends StatelessWidget {
  const _PackagesEmptyState({required this.icon, required this.title, required this.detail});
  final IconData icon; final String title; final String detail;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 90, width: 90,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [
            LightTheme.brandBlue.withOpacity(0.12), LightTheme.brandBlue.withOpacity(0.04), Colors.transparent,
          ])),
          child: Center(child: Container(
            height: 66, width: 66,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [LightTheme.brandBlue.withOpacity(0.13), LightTheme.brandCyan.withOpacity(0.07)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              border: Border.all(color: LightTheme.brandBlue.withOpacity(0.18)),
            ),
            child: Icon(icon, color: LightTheme.brandBlue, size: 32),
          )),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(title, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.3)),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center,
            style: const TextStyle(color: LightTheme.textSecondary, fontSize: 14, height: 1.5)),
      ]),
    ),
  );
}
