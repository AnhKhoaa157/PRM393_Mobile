part of '../main.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key, required this.session});
  final SessionController session;
  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  List<Map<String, dynamic>> packages = [], subscriptions = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final rs = await Future.wait([
        widget.session.api
            .request('/users/long-term/packages', token: widget.session.token),
        widget.session.api.request('/users/long-term/subscriptions',
            token: widget.session.token)
      ]);
      if (mounted)
        setState(() {
          packages = _items(rs[0], 'packages');
          if (packages.isEmpty) packages = _items(rs[0]);
          subscriptions = _items(rs[1]);
        });
    } catch (e) {
      if (mounted) _snack(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> subscribe(Map<String, dynamic> p) async {
    if (widget.session.user!.plates.isEmpty) {
      _snack('Add a license plate in Profile first.');
      return;
    }
    final choice = await showDialog<Plate>(
        context: context,
        builder: (_) => SimpleDialog(
            title: const Text('Choose a license plate'),
            children: widget.session.user!.plates
                .map((x) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, x),
                    child: Text('${x.number} (${x.type})')))
                .toList()));
    if (choice == null) return;
    final building = p['building'];
    final buildingId = building is Map ? building['_id'] : null;
    if (buildingId == null) {
      _snack('This package does not specify a building.');
      return;
    }
    try {
      await widget.session.api.request('/users/long-term/subscriptions',
          method: 'POST',
          token: widget.session.token,
          body: {
            'packageId': p['_id'],
            'plateNumber': choice.number,
            'buildingId': buildingId
          });
      await load();
      if (mounted) _snack('Package subscription created.');
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Packages',
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
        child: RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (loading) const LinearProgressIndicator(),
              if (subscriptions.isNotEmpty) ...[
                const Text('My subscriptions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ...subscriptions.map((s) => Card(
                    color: const Color(0xfff0fdf4),
                    child: ListTile(
                        leading: const Icon(Icons.verified_outlined,
                            color: Colors.green),
                        title: Text(
                            '${s['package'] is Map ? s['package']['name'] : 'Parking package'}'),
                        subtitle: Text(
                            '${s['plateNumber'] ?? ''} ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ ${s['status'] ?? ''}')))),
                const SizedBox(height: 16),
              ],
              const Text('Available packages',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              if (!loading && packages.isEmpty)
                const _Empty(
                    icon: Icons.inventory_2_outlined,
                    text: 'No packages are currently available.'),
              ...packages.map((p) => Card(
                  child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text('${p['name'] ?? 'Parking'}',
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800))),
                              Text('${_money(_asNum(p['price']))} VND',
                                  style: const TextStyle(
                                      color: _skyDark,
                                      fontWeight: FontWeight.bold))
                            ]),
                            const SizedBox(height: 6),
                            Text(
                                '${p['durationDays'] ?? 'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â'} days ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ ${p['description'] ?? 'Long-term parking'}',
                                style: const TextStyle(color: _muted)),
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                    onPressed: () => subscribe(p),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Subscribe'))),
                          ])))),
            ])),
      );
  void _snack(Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e.toString())));
}
