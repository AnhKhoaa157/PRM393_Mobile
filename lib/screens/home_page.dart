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
  double? balance = 0;
  List<Map<String, dynamic>> packages = [], notifications = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final token = widget.session.token!;
    final results = await Future.wait([
      _requestOrNull('/users/wallet', token),
      _requestOrNull('/users/long-term/packages', token),
      _requestOrNull('/users/notifications', token),
    ]);
    if (mounted) {
      setState(() {
        if (results[0] != null) {
          balance = _asNum(_data(results[0])['walletBalance']);
        }
        if (results[1] != null) {
          packages = _items(results[1], 'packages');
          if (packages.isEmpty) packages = _items(results[1]);
        }
        if (results[2] != null) notifications = _items(results[2]);
      });
    }
    if (mounted) setState(() => loading = false);
  }

  Future<dynamic> _requestOrNull(String path, String token) async {
    try {
      return await widget.session.api.request(path, token: token);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _quick(Icons.account_balance_wallet_outlined, 'Top up', 2,
                    Colors.blue),
                _quick(
                    Icons.inventory_2_outlined, 'Packages', 3, Colors.purple),
                _quick(Icons.qr_code_2_outlined, 'My QR', -1, Colors.teal),
              ]),
              const SizedBox(height: 26),
              if (widget.session.user!.plates.isEmpty)
                _warning(
                    'Incomplete profile',
                    'Add a license plate before making a reservation.',
                    () => widget.openTab(4)),
              if (packages.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Subscription packages',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 10),
                ...packages.take(3).map(_packageCardClean)
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

  Widget _reservationCardClean(Map<String, dynamic> reservation) => Card(
      child: ListTile(
          leading:
              const CircleAvatar(child: Icon(Icons.local_parking_outlined)),
          title: Text((reservation['building'] is Map
                  ? reservation['building']['name']
                  : null) ??
              'Parking reservation'),
          subtitle: Text(
              "${reservation['plateNumber'] ?? ''} • ${reservation['status'] ?? 'pending'}"),
          trailing: Text(
              _asNum(reservation['fee']) == 0
                  ? ''
                  : "${_money(_asNum(reservation['fee']))} VND")));

  Widget _packageCardClean(Map<String, dynamic> package) => Card(
      child: ListTile(
          leading: const CircleAvatar(
              backgroundColor: Color(0x1a7c3aed),
              child:
                  Icon(Icons.inventory_2_outlined, color: Colors.deepPurple)),
          title: Text((package['name'] ?? 'Parking package').toString()),
          subtitle: Text("${package['durationDays'] ?? '—'} days"),
          trailing: Text("${_money(_asNum(package['price']))} VND",
              style: const TextStyle(fontWeight: FontWeight.bold))));
  Future<void> _markRead(Map<String, dynamic> notification) async {
    final id = notification['_id']?.toString();
    if (id == null || id.isEmpty || notification['isRead'] == true) return;
    try {
      await widget.session.api.request('/users/notifications/$id/read',
          method: 'PATCH', token: widget.session.token);
      if (mounted) setState(() => notification['isRead'] = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.session.api.request('/users/notifications/read-all',
          method: 'PATCH', token: widget.session.token);
      if (mounted) {
        setState(() {
          for (final notification in notifications) {
            notification['isRead'] = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _notifications() => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
          builder: (context, setSheetState) => ListView(children: [
                ListTile(
                    title: const Text('Notifications',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: TextButton(
                        onPressed: notifications.any((n) => n['isRead'] != true)
                            ? () async {
                                await _markAllRead();
                                setSheetState(() {});
                              }
                            : null,
                        child: const Text('Read all'))),
                if (notifications.isEmpty)
                  const ListTile(title: Text('No notifications yet.')),
                ...notifications.map((notification) => ListTile(
                    leading: Icon(
                        notification['isRead'] == true
                            ? Icons.notifications_none
                            : Icons.notifications,
                        color: notification['isRead'] == true ? _muted : _sky),
                    title: Text('${notification['title'] ?? 'Notification'}',
                        style: TextStyle(
                            fontWeight: notification['isRead'] == true
                                ? FontWeight.normal
                                : FontWeight.w700)),
                    subtitle: Text('${notification['message'] ?? ''}'),
                    onTap: () async {
                      await _markRead(notification);
                      setSheetState(() {});
                    }))
              ])));
}
