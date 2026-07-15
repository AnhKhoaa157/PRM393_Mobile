part of '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session, required this.openTab});
  final SessionController session;
  final ValueChanged<int> openTab;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;
  double? balance;
  List<Map<String, dynamic>> reservations = [],
      packages = [],
      notifications = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final token = widget.session.token!;
      final results = await Future.wait([
        widget.session.api.request('/users/wallet', token: token),
        widget.session.api.request('/users/reservations', token: token),
        widget.session.api.request('/users/long-term/packages', token: token),
        widget.session.api.request('/users/notifications', token: token),
      ]);
      final wallet = _data(results[0]);
      if (mounted)
        setState(() {
          balance = (wallet['walletBalance'] as num?)?.toDouble() ?? 0;
          reservations = _items(results[1]);
          packages = _items(results[2], 'packages');
          if (packages.isEmpty) packages = _items(results[2]);
          notifications = _items(results[3]);
        });
    } catch (_) {
      // Individual screens retain their own useful errors; home remains usable offline.
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final active = reservations
        .where(
            (r) => !['completed', 'cancelled', 'expired'].contains(r['status']))
        .length;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: _skyDark,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Good day!',
                        style: TextStyle(color: Color(0xccffffff))),
                    Text(widget.session.user!.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ])),
              IconButton(
                  onPressed: _notifications,
                  icon: Badge(
                      label: Text(
                          '${notifications.where((n) => n['isRead'] != true).length}'),
                      isLabelVisible:
                          notifications.any((n) => n['isRead'] != true),
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.white))),
              IconButton(
                  onPressed: widget.session.logout,
                  icon: const Icon(Icons.logout, color: Colors.white)),
            ]),
            const SizedBox(height: 18),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .25))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('WALLET BALANCE',
                          style: TextStyle(
                              color: Color(0xb3ffffff),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(
                          balance == null
                              ? 'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â'
                              : '${_money(balance!)} VND',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w900)),
                      if (active > 0)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                                '$active active reservation${active == 1 ? '' : 's'}',
                                style: const TextStyle(color: Colors.white))),
                    ])),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (loading) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Quick Actions',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 12),
              Row(children: [
                _quick(
                    Icons.calendar_month_outlined, 'Reserve', 1, Colors.orange),
                _quick(Icons.account_balance_wallet_outlined, 'Top up', 3,
                    Colors.blue),
                _quick(
                    Icons.inventory_2_outlined, 'Packages', 4, Colors.purple),
                _quick(Icons.qr_code_2_outlined, 'My QR', -1, Colors.teal),
              ]),
              const SizedBox(height: 26),
              if (widget.session.user!.plates.isEmpty)
                _warning(
                    'Incomplete profile',
                    'Add a license plate before making a reservation.',
                    () => widget.openTab(5)),
              if (reservations.isNotEmpty) ...[
                const Text('Active reservations',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 10),
                ...reservations.take(3).map(_reservationCard)
              ],
              if (packages.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Subscription packages',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 10),
                ...packages.take(3).map(_packageCard)
              ],
            ])),
      ]),
    );
  }

  Widget _quick(IconData icon, String label, int target, Color color) =>
      Expanded(
          child: InkWell(
              onTap: () => target >= 0 ? widget.openTab(target) : _showQr(),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    CircleAvatar(
                        backgroundColor: color.withValues(alpha: .12),
                        child: Icon(icon, color: color)),
                    const SizedBox(height: 7),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700))
                  ]))));
  void _showQr() => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
          title: const Text('My QR check-in'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            QrImageView(data: widget.session.user!.id, size: 220),
            const SizedBox(height: 12),
            Text('Member ID: ${widget.session.user!.id}',
                textAlign: TextAlign.center)
          ])));
  Widget _warning(String title, String body, VoidCallback action) => Card(
      color: const Color(0xfffffbeb),
      child: ListTile(
          leading:
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(body),
          trailing: const Icon(Icons.chevron_right),
          onTap: action));
  Widget _reservationCard(Map<String, dynamic> r) => Card(
      child: ListTile(
          leading:
              const CircleAvatar(child: Icon(Icons.local_parking_outlined)),
          title: Text((r['building'] is Map ? r['building']['name'] : null) ??
              'Parking reservation'),
          subtitle: Text(
              '${r['plateNumber'] ?? ''} ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ ${r['status'] ?? 'pending'}'),
          trailing: Text(
              '${_asNum(r['fee']) == 0 ? '' : '${_money(_asNum(r['fee']))} VND'}')));
  Widget _packageCard(Map<String, dynamic> p) => Card(
      child: ListTile(
          leading: const CircleAvatar(
              backgroundColor: Color(0x1a7c3aed),
              child:
                  Icon(Icons.inventory_2_outlined, color: Colors.deepPurple)),
          title: Text((p['name'] ?? 'Parking package').toString()),
          subtitle: Text('${p['durationDays'] ?? 'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â'} days'),
          trailing: Text('${_money(_asNum(p['price']))} VND',
              style: const TextStyle(fontWeight: FontWeight.bold))));
  void _notifications() => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(children: [
            const ListTile(
                title: Text('Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            if (notifications.isEmpty)
              const ListTile(title: Text('No notifications yet.')),
            ...notifications.map((n) => ListTile(
                title: Text('${n['title'] ?? 'Notification'}'),
                subtitle: Text('${n['message'] ?? ''}')))
          ]));
}
