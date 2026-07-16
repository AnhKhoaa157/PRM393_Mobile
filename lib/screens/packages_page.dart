part of '../main.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key, required this.session});

  final SessionController session;

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> packages = [];
  List<Map<String, dynamic>> subscriptions = [];
  bool loading = true;
  String tab = 'browse';
  String vehicleFilter = 'all';
  String durationFilter = 'all';
  String statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    search.addListener(_refreshFilters);
    load();
  }

  @override
  void dispose() {
    search.removeListener(_refreshFilters);
    search.dispose();
    super.dispose();
  }

  void _refreshFilters() => setState(() {});

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        widget.session.api.request('/users/long-term/packages',
            token: widget.session.token),
        widget.session.api.request('/users/long-term/subscriptions',
            token: widget.session.token),
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
    if (mounted) setState(() => loading = false);
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
        showAppNotice(context, 'Package subscription created.',
            tone: AppNoticeTone.success);
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
        showAppNotice(context, 'Subscription renewed.',
            tone: AppNoticeTone.success);
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
        builder: (dialogContext) => AlertDialog(
                title: const Text('Cancel subscription?'),
                content: const Text(
                    'Your eligible refund is calculated with the building policy.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Keep it')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger),
                      child: const Text('Cancel subscription')),
                ]));
    if (accepted != true) return;
    try {
      await widget.session.api.request(
          '/users/long-term/subscriptions/$id/cancel',
          method: 'POST', token: widget.session.token, body: {
        'cancelReason': 'no_longer_needed',
      });
      await load();
      if (mounted) {
        showAppNotice(context, 'Subscription cancelled.',
            tone: AppNoticeTone.success);
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

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Packages',
      actions: [
        IconButton(
            tooltip: 'Refresh packages',
            onPressed: load,
            icon: const Icon(Icons.refresh))
      ],
      child: RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
            const Text('Choose a long-term parking package for your vehicle.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: AppSpace.lg),
            _tabs(),
            const SizedBox(height: AppSpace.md),
            _filters(),
            const SizedBox(height: AppSpace.lg),
            if (loading) const LinearProgressIndicator(),
            if (!loading && tab == 'browse') ..._browseContent(),
            if (!loading && tab == 'mine') ..._subscriptionContent(),
            const SizedBox(height: AppSpace.xl),
          ])));

  Widget _tabs() => SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'browse', label: Text('Browse packages')),
        ButtonSegment(value: 'mine', label: Text('My packages')),
      ],
      selected: {tab},
      onSelectionChanged: (value) => setState(() => tab = value.first));

  Widget _filters() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            controller: search,
            decoration: InputDecoration(
                labelText: 'Search package or building',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: search.clear,
                        icon: const Icon(Icons.close)))),
        const SizedBox(height: AppSpace.sm),
        _filterRow('Vehicle', vehicleFilter, const {
          'all': 'All vehicles',
          'car': 'Car',
          'motorcycle': 'Motorcycle',
        }, (value) => setState(() => vehicleFilter = value)),
        const SizedBox(height: AppSpace.xs),
        _filterRow('Duration', durationFilter, const {
          'all': 'All durations',
          '7': '1 week',
          '30': '1 month',
          '365': '1 year',
        }, (value) => setState(() => durationFilter = value)),
        if (tab == 'mine') ...[
          const SizedBox(height: AppSpace.xs),
          _filterRow('Status', statusFilter, const {
            'all': 'All status',
            'active': 'Active',
            'pending': 'Pending',
            'expired': 'Expired',
            'cancelled': 'Cancelled',
          }, (value) => setState(() => statusFilter = value)),
        ]
      ]);

  Widget _filterRow(String label, String selected, Map<String, String> values,
          ValueChanged<String> onSelected) =>
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        ...values.entries.map((entry) => ChoiceChip(
            label: Text(entry.value),
            selected: selected == entry.key,
            onSelected: (_) => onSelected(entry.key))),
      ]);

  List<Widget> _browseContent() {
    if (packages.isEmpty) {
      return const [
        AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No packages available',
            detail: 'New packages will be listed here.'),
      ];
    }
    if (_packagesByBuilding.isEmpty) {
      return const [
        AppEmptyState(
            icon: Icons.search_off_outlined,
            title: 'No matching packages',
            detail: 'Try changing the filters.'),
      ];
    }
    return _packagesByBuilding.values.expand((group) {
      final building = _asMap(group.first['building']);
      return [
        AppSectionTitle('${building['name'] ?? 'Parking building'}'),
        if ('${building['code'] ?? ''}'.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: AppSpace.xxs),
              child: Text('${building['code']}',
                  style: const TextStyle(color: AppColors.muted))),
        const SizedBox(height: AppSpace.sm),
        ...group.map(_packageCard),
        const SizedBox(height: AppSpace.lg),
      ];
    }).toList();
  }

  List<Widget> _subscriptionContent() {
    if (subscriptions.isEmpty) {
      return const [
        AppEmptyState(
            icon: Icons.card_membership_outlined,
            title: 'No package subscriptions',
            detail: 'Your active and past subscriptions will appear here.'),
      ];
    }
    if (_filteredSubscriptions.isEmpty) {
      return const [
        AppEmptyState(
            icon: Icons.search_off_outlined,
            title: 'No matching subscriptions',
            detail: 'Try changing the filters.'),
      ];
    }
    return _filteredSubscriptions.map(_subscriptionCard).toList();
  }

  Widget _subscriptionCard(Map<String, dynamic> item) {
    final package = _asMap(item['package']);
    final building = _asMap(item['building']).isNotEmpty
        ? _asMap(item['building'])
        : _asMap(package['building']);
    final slot = _asMap(item['slot']);
    final status = '${item['status'] ?? 'unknown'}';
    final statusColor = switch (status) {
      'active' => AppColors.success,
      'pending' => AppColors.warning,
      'cancelled' => AppColors.danger,
      _ => AppColors.muted,
    };
    final canRenew = status == 'active' || status == 'expired';
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: AppPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        shape: BoxShape.circle),
                    child: Icon(Icons.card_membership_outlined,
                        color: statusColor)),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                    child: Text('${package['name'] ?? 'Parking package'}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900))),
                AppPill(status,
                    color: statusColor.withValues(alpha: .12),
                    foreground: statusColor),
              ]),
              const SizedBox(height: AppSpace.sm),
              _detailLine(Icons.business_outlined,
                  '${building['name'] ?? 'Parking building'}'),
              _detailLine(Icons.directions_car_outlined,
                  '${item['plateNumber'] ?? 'Vehicle'}'),
              _detailLine(Icons.date_range_outlined,
                  '${_date(item['startDate']).split(' ').first} – ${_date(item['endDate']).split(' ').first}'),
              if (slot.isNotEmpty)
                _detailLine(Icons.local_parking_outlined,
                    'Dedicated slot ${slot['code'] ?? ''}'),
              if (canRenew) ...[
                const SizedBox(height: AppSpace.sm),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(
                      onPressed: () => renew(item),
                      icon: const Icon(Icons.autorenew_outlined),
                      label: const Text('Renew')),
                  if (status == 'active')
                    TextButton.icon(
                        onPressed: () => cancel(item),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel')),
                ])
              ]
            ])));
  }

  Widget _detailLine(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.xxs),
      child: Row(children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: AppSpace.xs),
        Expanded(
            child: Text(value,
                style: const TextStyle(color: AppColors.muted))),
      ]));

  Widget _packageCard(Map<String, dynamic> item) {
    final description = '${item['description'] ?? ''}'.trim();
    final vehicle = _vehicleText(item);
    final dedicated = item['allowDedicatedSlot'] == true;
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: AppPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('${item['name'] ?? 'Parking package'}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900))),
                Text('${_money(_asNum(item['price']))} VND',
                    style: const TextStyle(
                        color: AppColors.brand, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: AppSpace.xs),
              Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                AppPill('${item['durationDays'] ?? '—'} days'),
                if (vehicle.isNotEmpty)
                  AppPill(vehicle.contains('motor') || vehicle.contains('moto')
                      ? 'Motorcycle'
                      : 'Car',
                      color: AppColors.successSoft,
                      foreground: AppColors.success),
                AppPill(dedicated ? 'Dedicated slot' : 'Flexible parking',
                    color: AppColors.surfaceMuted,
                    foreground: AppColors.muted),
              ]),
              if (description.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: AppSpace.sm),
                    child: Text(description,
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.35))),
              const SizedBox(height: AppSpace.xs),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: () => subscribe(item),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Subscribe'))),
            ])));
  }

  void _snack(Object value) => showAppNotice(context, value);
}
