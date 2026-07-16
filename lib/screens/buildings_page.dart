part of '../main.dart';

class BuildingsPage extends StatefulWidget {
  const BuildingsPage({super.key, required this.session});
  final SessionController session;

  @override
  State<BuildingsPage> createState() => _BuildingsPageState();
}

class _BuildingsPageState extends State<BuildingsPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> buildings = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    search.addListener(_refreshSearch);
    load();
  }

  @override
  void dispose() {
    search
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() => setState(() {});

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await widget.session.api
          .request('/users/buildings', token: widget.session.token);
      if (mounted) setState(() => buildings = _items(response));
    } catch (error) {
      if (mounted) showAppNotice(context, error);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final filtered = buildings.where((building) {
      if (query.isEmpty) return true;
      return '${building['name'] ?? ''}'.toLowerCase().contains(query) ||
          '${building['code'] ?? ''}'.toLowerCase().contains(query) ||
          _address(building).toLowerCase().contains(query);
    }).toList();
    return PageFrame(
        title: 'Parking buildings',
        actions: [
          IconButton(
              tooltip: 'Refresh buildings',
              onPressed: load,
              icon: const Icon(Icons.refresh))
        ],
        child: RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
              const Text('Browse active parking locations and their details.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: AppSpace.md),
              TextField(
                  controller: search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                      labelText: 'Search buildings',
                      hintText: 'Name, code or address',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: search.clear,
                              icon: const Icon(Icons.close)))),
              const SizedBox(height: AppSpace.lg),
              if (loading) const LinearProgressIndicator(),
              if (!loading && filtered.isEmpty)
                const AppEmptyState(
                    icon: Icons.business_outlined,
                    title: 'No buildings found',
                    detail: 'Try a different search or refresh the list.'),
              ...filtered.map(_buildingCard),
              const SizedBox(height: AppSpace.xl),
            ])));
  }

  Widget _buildingCard(Map<String, dynamic> building) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppPanel(
          child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => _showBuildingInfo(building),
              child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xs),
                  child: Row(children: [
                    Container(
                        height: 48,
                        width: 48,
                        decoration: const BoxDecoration(
                            color: AppColors.brandSoft, shape: BoxShape.circle),
                        child: const Icon(Icons.business_outlined,
                            color: AppColors.brand)),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Expanded(
                                child: Text('${building['name'] ?? 'Parking building'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900))),
                            const AppPill('Active',
                                color: AppColors.successSoft,
                                foreground: AppColors.success)
                          ]),
                          const SizedBox(height: AppSpace.xxs),
                          Text('${building['code'] ?? 'BUILDING'} • ${_address(building)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.muted))
                        ])),
                    const SizedBox(width: AppSpace.xs),
                    const Icon(Icons.chevron_right, color: AppColors.muted)
                  ])))));

  void _showBuildingInfo(Map<String, dynamic> building) => showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(AppSpace.lg),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const AppBrandMark(),
                    const SizedBox(height: AppSpace.md),
                    Text('${building['name'] ?? 'Parking building'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w900)),
                    const SizedBox(height: AppSpace.xs),
                    AppPill('${building['code'] ?? 'BUILDING'}'),
                    const SizedBox(height: AppSpace.lg),
                    _infoRow(Icons.location_on_outlined, _address(building)),
                    if ('${building['operatingHours'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.sm),
                      _infoRow(Icons.schedule_outlined,
                          '${building['operatingHours']}')
                    ],
                    const SizedBox(height: AppSpace.lg),
                    const Text(
                        'Choose a package for this location from the Packages tab.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: AppSpace.sm),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'))
                  ])))));

  Widget _infoRow(IconData icon, String text) => Row(children: [
        Icon(icon, color: AppColors.brand),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted)))
      ]);

  String _address(Map<String, dynamic> building) {
    final address = building['address'];
    if (address is Map) {
      return '${address['fullAddress'] ?? address['address'] ?? 'Address not updated'}';
    }
    return '${address ?? 'Address not updated'}';
  }
}
