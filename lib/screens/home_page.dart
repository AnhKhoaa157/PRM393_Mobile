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
  List<Map<String, dynamic>> packages = [];
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> feedbackReplies = [];
  Map<String, dynamic>? activeSession;
  final feedbackStorage = const FlutterSecureStorage();
  Set<String> readFeedbackIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFeedbackReadIds();
    load();
  }

  String get _feedbackReadKey =>
      'pbms_feedback_read_ids:${widget.session.user!.id}';

  Future<void> _loadFeedbackReadIds() async {
    try {
      final raw = await feedbackStorage.read(key: _feedbackReadKey);
      final values = raw == null ? <dynamic>[] : jsonDecode(raw);
      if (values is List && mounted) {
        setState(() => readFeedbackIds = values.map((value) => '$value').toSet());
      }
    } catch (_) {}
  }

  Future<void> _markFeedbackRead(Map<String, dynamic> reply) async {
    final id = '${reply['_id'] ?? ''}';
    if (id.isEmpty || readFeedbackIds.contains(id)) return;
    final next = {...readFeedbackIds, id};
    setState(() => readFeedbackIds = next);
    try {
      await feedbackStorage.write(key: _feedbackReadKey, value: jsonEncode(next.toList()));
    } catch (_) {}
  }

  Future<void> load() async {
    setState(() => loading = true);
    final token = widget.session.token!;
    final results = await Future.wait([
      _requestOrNull('/users/wallet', token),
      _requestOrNull('/users/long-term/packages', token),
      _requestOrNull('/users/notifications', token),
      _requestOrNull('/users/feedbacks/me', token),
      _requestOrNull('/users/parking-history', token),
    ]);
    if (mounted) {
      setState(() {
        if (results[0] != null) balance = _asNum(_data(results[0])['walletBalance']);
        if (results[1] != null) {
          packages = _items(results[1], 'packages');
          if (packages.isEmpty) packages = _items(results[1]);
        }
        if (results[2] != null) notifications = _items(results[2]);
        if (results[3] != null) {
          feedbackReplies = _items(results[3])
              .where((item) => '${item['staffReply'] ?? ''}'.trim().isNotEmpty)
              .toList();
        }
        activeSession = null;
        if (results[4] != null) {
          activeSession = _items(results[4]).cast<Map<String, dynamic>>().firstWhere(
              (item) => item['status'] == 'active',
              orElse: () => <String, dynamic>{});
          if (activeSession!.isEmpty) activeSession = null;
        }
        loading = false;
      });
    }
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
    final user = widget.session.user!;
    final unread = notifications.where((item) => item['isRead'] != true).length +
        feedbackReplies.where((item) => !readFeedbackIds.contains('${item['_id'] ?? ''}')).length;
    return RefreshIndicator(
        onRefresh: load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 30),
                  decoration: const BoxDecoration(
                      color: AppColors.brandDeep,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.lg))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const AppBrandMark(dark: true),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Good to see you', style: TextStyle(color: Color(0xd9ffffff))),
                        Text(user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      ])),
                      IconButton(
                          tooltip: 'Notifications',
                          onPressed: _notifications,
                          icon: Badge(
                              isLabelVisible: unread > 0,
                              label: Text('$unread'),
                              child: const Icon(Icons.notifications_outlined, color: Colors.white))),
                      IconButton(
                          tooltip: 'Sign out',
                          onPressed: widget.session.logout,
                          icon: const Icon(Icons.logout_outlined, color: Colors.white)),
                    ]),
                    const SizedBox(height: AppSpace.lg),
                    _balancePanel(),
                  ]))),
          SliverPadding(
              padding: const EdgeInsets.all(AppSpace.lg),
              sliver: SliverList(delegate: SliverChildListDelegate([
                if (loading) const LinearProgressIndicator(),
                if (loading) const SizedBox(height: AppSpace.lg),
                const AppSectionTitle('Quick actions'),
                const SizedBox(height: AppSpace.sm),
                _quickActions(),
                if (activeSession != null) ...[
                  const SizedBox(height: AppSpace.lg),
                  _activeParkingCard(),
                ],
                if (user.plates.isEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  _profilePrompt(),
                ],
                if (packages.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xl),
                  AppSectionTitle('Explore packages',
                      action: TextButton(onPressed: () => widget.openTab(3), child: const Text('See all'))),
                  const SizedBox(height: AppSpace.sm),
                  ...packages.take(2).map(_packageCard),
                ],
                const SizedBox(height: AppSpace.xl),
              ])))
        ]));
  }

  Widget _balancePanel() => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .13),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('WALLET BALANCE',
            style: TextStyle(color: Color(0xccffffff), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: AppSpace.xs),
        Text(balance == null ? 'Unavailable' : '${_money(balance!)} VND',
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpace.sm),
        TextButton.icon(
            onPressed: () => widget.openTab(2),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Top up wallet')),
      ]));

  Widget _quickActions() {
    final actions = <(IconData, String, Color, VoidCallback)>[
      (Icons.account_balance_wallet_outlined, 'Top up', AppColors.brand, () => widget.openTab(2)),
      (Icons.business_outlined, 'Buildings', AppColors.success, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BuildingsPage(session: widget.session)))),
      (Icons.inventory_2_outlined, 'Packages', const Color(0xff8b3bb6), () => widget.openTab(3)),
      (Icons.qr_code_2_outlined, 'My QR', AppColors.success, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VehicleQrPage(session: widget.session, onAddVehicle: () => widget.openTab(4))))),
      (Icons.report_problem_outlined, 'Incidents', AppColors.danger, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => IncidentPage(session: widget.session)))),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 480 ? actions.length : 3;
      final tileWidth = (constraints.maxWidth - AppSpace.sm * (columns - 1)) / columns;
      return Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: actions
              .map((action) => SizedBox(
                  width: tileWidth,
                  child: _quickAction(action.$1, action.$2, action.$3, action.$4)))
              .toList());
    });
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Ink(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md, horizontal: AppSpace.xs),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                  child: Column(children: [
                    Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
                        child: Icon(icon, color: color)),
                    const SizedBox(height: AppSpace.xs),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ]))));

  Widget _profilePrompt() => AppPanel(
      color: AppColors.warningSoft,
      child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          title: const Text('Complete your profile', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Add a license plate to your parking profile.'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
          onTap: () => widget.openTab(4)));

  Widget _activeParkingCard() {
    final building = activeSession!['building'] is Map
        ? '${activeSession!['building']['name'] ?? 'Parking location'}'
        : 'Parking location';
    return AppPanel(
        color: AppColors.successSoft,
        child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_parking_outlined,
                color: AppColors.success),
            title: const Text('Vehicle currently parked',
                style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${activeSession!['plateNumber'] ?? 'Vehicle'} · $building'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.openTab(1)));
  }

  Widget _packageCard(Map<String, dynamic> package) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppPanel(
          child: Row(children: [
            Container(
                height: 44,
                width: 44,
                decoration: const BoxDecoration(color: Color(0xfff2e9fb), shape: BoxShape.circle),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xff8b3bb6))),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((package['name'] ?? 'Parking package').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('${package['durationDays'] ?? '—'} days', style: const TextStyle(color: AppColors.muted)),
            ])),
            const SizedBox(width: AppSpace.sm),
            Text('${_money(_asNum(package['price']))} VND', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w900)),
          ])));

  Future<void> _markRead(Map<String, dynamic> notification) async {
    final id = notification['_id']?.toString();
    if (id == null || id.isEmpty || notification['isRead'] == true) return;
    try {
      await widget.session.api.request('/users/notifications/$id/read', method: 'PATCH', token: widget.session.token);
      if (mounted) setState(() => notification['isRead'] = true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.session.api.request('/users/notifications/read-all', method: 'PATCH', token: widget.session.token);
      if (mounted) setState(() {
        for (final notification in notifications) {
          notification['isRead'] = true;
        }
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _notifications() => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.md, 0, AppSpace.md, AppSpace.md),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Updates',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900))),
                      TextButton(
                          onPressed: notifications.any(
                                  (item) => item['isRead'] != true)
                              ? () async {
                                  await _markAllRead();
                                  setSheetState(() {});
                                }
                              : null,
                          child: const Text('Mark notifications read')),
                    ]),
                    const SizedBox(height: AppSpace.xs),
                    if (notifications.isEmpty && feedbackReplies.isEmpty)
                      const AppEmptyState(
                          icon: Icons.notifications_none,
                          title: 'Nothing new',
                          detail: 'You are all caught up.')
                    else
                      Flexible(
                          child: ListView(children: [
                        if (notifications.isNotEmpty) ...[
                          const _InboxHeading('Notifications'),
                          ...notifications.map((notification) =>
                              _notificationTile(notification, setSheetState)),
                        ],
                        if (feedbackReplies.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.sm),
                          const _InboxHeading('Replies from parking management'),
                          ...feedbackReplies.map((reply) =>
                              _feedbackReplyTile(reply, setSheetState)),
                        ],
                      ]))
                  ])))));

  Widget _notificationTile(
          Map<String, dynamic> notification, StateSetter setSheetState) =>
      ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          leading: Icon(
              notification['isRead'] == true
                  ? Icons.notifications_none
                  : Icons.notifications,
              color: notification['isRead'] == true
                  ? AppColors.muted
                  : AppColors.brand),
          title: Text('${notification['title'] ?? 'Notification'}',
              style: TextStyle(
                  fontWeight: notification['isRead'] == true
                      ? FontWeight.w600
                      : FontWeight.w800)),
          subtitle: Text('${notification['message'] ?? ''}'),
          onTap: () async {
            await _markRead(notification);
            setSheetState(() {});
          });

  Widget _feedbackReplyTile(
          Map<String, dynamic> reply, StateSetter setSheetState) {
    final read = readFeedbackIds.contains('${reply['_id'] ?? ''}');
    final building = reply['building'] is Map
        ? '${reply['building']['name'] ?? reply['building']['code'] ?? 'Parking management'}'
        : 'Parking management';
    final session = reply['parkingSession'] is Map
        ? '${reply['parkingSession']['plateNumber'] ?? ''}'
        : '';
    return AppPanel(
        padding: const EdgeInsets.all(AppSpace.sm),
        color: read ? AppColors.surface : AppColors.brandSoft,
        child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () async {
              await _markFeedbackRead(reply);
              setSheetState(() {});
            },
            child: Padding(
                padding: const EdgeInsets.all(AppSpace.xs),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.reply_outlined, color: AppColors.brand),
                        const SizedBox(width: AppSpace.xs),
                        Expanded(
                            child: Text(building,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900))),
                        if (!read)
                          const AppPill('New',
                              color: AppColors.brand,
                              foreground: Colors.white),
                      ]),
                      if (session.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.xxs),
                        Text(session,
                            style: const TextStyle(color: AppColors.muted)),
                      ],
                      const SizedBox(height: AppSpace.xs),
                      Text('${reply['staffReply']}',
                          maxLines: read ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.foreground, height: 1.35)),
                    ]))));
}

}

class _InboxHeading extends StatelessWidget {
  const _InboxHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.muted, fontWeight: FontWeight.w800)));
}
