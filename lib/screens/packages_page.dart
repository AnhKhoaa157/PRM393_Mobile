part of '../main.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key, required this.session});
  final SessionController session;

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  List<Map<String, dynamic>> packages = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> subscriptions = <Map<String, dynamic>>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final responses = await Future.wait([
        widget.session.api
            .request('/users/long-term/packages', token: widget.session.token),
        widget.session.api
            .request('/users/long-term/subscriptions', token: widget.session.token),
      ]);
      if (!mounted) return;
      setState(() {
        packages = _items(responses[0], 'packages');
        subscriptions = _items(responses[1]);
      });
    } catch (e) {
      if (mounted) _snack(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> subscribe(Map<String, dynamic> package) async {
    final plates = widget.session.user!.plates;
    if (plates.isEmpty) {
      _snack('Add a license plate in Profile first.');
      return;
    }
    final plate = await showDialog<Plate>(
        context: context,
        builder: (context) => SimpleDialog(
                title: const Text('Choose a license plate'),
                children: plates
                    .map((item) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, item),
                        child: Text('${item.number} (${item.type})')))
                    .toList()));
    if (plate == null) return;

    try {
      await widget.session.api.request('/users/long-term/subscriptions',
          method: 'POST',
          token: widget.session.token,
          body: {
            'packageId': package['_id'],
            'plateNumber': plate.number,
          });
      await load();
      if (mounted) _snack('Package subscription created.');
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> renew(Map<String, dynamic> subscription) async {
    final id = subscription['_id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await widget.session.api.request('/users/long-term/subscriptions/$id/renew',
          method: 'POST', token: widget.session.token);
      await load();
      if (mounted) _snack('Subscription renewed.');
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> cancel(Map<String, dynamic> subscription) async {
    final id = subscription['_id']?.toString();
    if (id == null || id.isEmpty) return;
    String reason = 'no_longer_needed';
    final note = TextEditingController();
    final request = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Cancel subscription'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Any eligible refund is calculated by the parking policy.'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          value: reason,
                          decoration: const InputDecoration(labelText: 'Reason'),
                          items: const [
                            DropdownMenuItem(value: 'change_slot', child: Text('Change parking slot')),
                            DropdownMenuItem(value: 'change_vehicle', child: Text('Change vehicle')),
                            DropdownMenuItem(value: 'no_longer_needed', child: Text('No longer needed')),
                            DropdownMenuItem(value: 'pricing_issue', child: Text('Pricing issue')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (value) => setDialogState(() => reason = value!)),
                      if (reason == 'other') ...[
                        const SizedBox(height: 12),
                        TextField(
                            controller: note,
                            maxLength: 300,
                            decoration: const InputDecoration(labelText: 'Details')),
                      ],
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Keep subscription')),
                      FilledButton(
                          onPressed: () {
                            if (reason == 'other' && note.text.trim().isEmpty) return;
                            Navigator.pop(context, {
                              'cancelReason': reason,
                              if (note.text.trim().isNotEmpty)
                                'cancelNote': note.text.trim(),
                            });
                          },
                          child: const Text('Cancel subscription')),
                    ])));
    note.dispose();
    if (request == null) return;

    try {
      await widget.session.api.request('/users/long-term/subscriptions/$id/cancel',
          method: 'POST', token: widget.session.token, body: request);
      await load();
      if (mounted) _snack('Subscription cancelled.');
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
                const SizedBox(height: 8),
                const Text('My subscriptions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...subscriptions.map(_subscriptionCard),
                const SizedBox(height: 18),
              ],
              const Text('Available packages',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              if (!loading && packages.isEmpty)
                const _Empty(
                    icon: Icons.inventory_2_outlined,
                    text: 'No packages are currently available.'),
              const SizedBox(height: 8),
              ...packages.map(_packageCard),
            ])),
      );

  Widget _subscriptionCard(Map<String, dynamic> subscription) {
    final status = subscription['status']?.toString() ?? 'unknown';
    final package = subscription['package'];
    final name = package is Map ? package['name'] : null;
    final canRenew = status == 'active' || status == 'expired';
    return Card(
        color: const Color(0xfff0fdf4),
        child: ListTile(
            leading: const Icon(Icons.verified_outlined, color: Colors.green),
            title: Text('${name ?? 'Parking package'}'),
            subtitle: Text("${subscription['plateNumber'] ?? ''} • $status"),
            trailing: canRenew
                ? PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'renew') renew(subscription);
                      if (action == 'cancel') cancel(subscription);
                    },
                    itemBuilder: (_) => [
                          const PopupMenuItem(value: 'renew', child: Text('Renew')),
                          if (status == 'active')
                            const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                        ])
                : null));
  }

  Widget _packageCard(Map<String, dynamic> package) {
    final duration = package['durationDays'];
    final description = package['description']?.toString().trim();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('${package['name'] ?? 'Parking package'}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                Text('${_money(_asNum(package['price']))} VND',
                    style: const TextStyle(color: _skyDark, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Text(
                  '${duration ?? '—'} days${description == null || description.isEmpty ? '' : ' • $description'}',
                  style: const TextStyle(color: _muted)),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: () => subscribe(package),
                      icon: const Icon(Icons.add),
                      label: const Text('Subscribe'))),
            ])));
  }

  void _snack(Object value) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value.toString().replaceFirst('Exception: ', ''))));
}
