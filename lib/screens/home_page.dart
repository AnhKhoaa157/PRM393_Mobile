part of '../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME PAGE
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session, required this.openTab});
  final SessionController session;
  final ValueChanged<int> openTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // ── data ──────────────────────────────────────────────────────────────────
  bool loading = true;
  double? balance = 0;
  List<Map<String, dynamic>> packages        = [];
  List<Map<String, dynamic>> notifications   = [];
  List<Map<String, dynamic>> feedbackReplies = [];
  Map<String, dynamic>?      activeSession;

  final feedbackStorage = const FlutterSecureStorage();
  Set<String> readFeedbackIds = <String>{};

  // ── animations ────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  late final AnimationController _shimmerCtrl;
  late final Animation<double>   _shimmerAnim;
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    _staggerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    );

    _loadFeedbackReadIds();
    load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  String get _feedbackReadKey =>
      'pbms_feedback_read_ids:${widget.session.user!.id}';

  Future<void> _loadFeedbackReadIds() async {
    try {
      final raw    = await feedbackStorage.read(key: _feedbackReadKey);
      final values = raw == null ? <dynamic>[] : jsonDecode(raw);
      if (values is List && mounted) {
        setState(() => readFeedbackIds = values.map((v) => '$v').toSet());
      }
    } catch (_) {}
  }

  Future<void> _markFeedbackRead(Map<String, dynamic> reply) async {
    final id = '${reply['_id'] ?? ''}';
    if (id.isEmpty || readFeedbackIds.contains(id)) return;
    final next = {...readFeedbackIds, id};
    setState(() => readFeedbackIds = next);
    try {
      await feedbackStorage.write(
          key: _feedbackReadKey, value: jsonEncode(next.toList()));
    } catch (_) {}
  }

  Future<void> load() async {
    setState(() => loading = true);
    final token   = widget.session.token!;
    final results = await Future.wait([
      _safe('/users/wallet',             token),
      _safe('/users/long-term/packages', token),
      _safe('/users/notifications',      token),
      _safe('/users/feedbacks/me',       token),
      _safe('/users/parking-history',    token),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0] != null) {
        balance = _asNum(_data(results[0])['walletBalance']);
      }
      if (results[1] != null) {
        packages = _items(results[1], 'packages');
        if (packages.isEmpty) packages = _items(results[1]);
      }
      if (results[2] != null) notifications = _items(results[2]);
      if (results[3] != null) {
        feedbackReplies = _items(results[3])
            .where((i) => '${i['staffReply'] ?? ''}'.trim().isNotEmpty)
            .toList();
      }
      activeSession = null;
      if (results[4] != null) {
        final found = _items(results[4])
            .cast<Map<String, dynamic>>()
            .firstWhere((i) => i['status'] == 'active',
                orElse: () => <String, dynamic>{});
        if (found.isNotEmpty) activeSession = found;
      }
      loading = false;
    });
    _staggerCtrl.forward(from: 0);
  }

  Future<dynamic> _safe(String path, String token) async {
    try { return await widget.session.api.request(path, token: token); }
    catch (_) { return null; }
  }

  int get _unread =>
      notifications.where((n) => n['isRead'] != true).length +
      feedbackReplies
          .where((r) => !readFeedbackIds.contains('${r['_id'] ?? ''}'))
          .length;

  // ── stagger helper ────────────────────────────────────────────────────────
  Animation<double> _stagger(int index, {int total = 6}) {
    final start = (index / total) * 0.6;
    final end   = (start + 0.5).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerCtrl,
      curve:  Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user!;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: RefreshIndicator(
        onRefresh:   load,
        color:       LightTheme.brandBlue,
        strokeWidth: 2.5,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Gradient header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                user:            user,
                unread:          _unread,
                balance:         balance,
                loading:         loading,
                shimmerAnim:     _shimmerAnim,
                onNotifications: _showNotifications,
                onLogout:        widget.session.logout,
                onTopUp:         () => widget.openTab(2),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.xl),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // Loading bar
                  if (loading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: const LinearProgressIndicator(
                        minHeight: 3,
                        color:      LightTheme.brandBlue,
                        backgroundColor: Color(0xFFDCE5F0),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                  ],

                  // Quick actions
                  _FadeSlide(
                    animation: _stagger(0),
                    child: _SectionHeading(title: 'Quick actions'),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _FadeSlide(
                    animation: _stagger(1),
                    child: _QuickActionsRow(
                      session: widget.session,
                      openTab: widget.openTab,
                    ),
                  ),

                  // Active parking
                  if (activeSession != null) ...[
                    const SizedBox(height: AppSpace.md),
                    _FadeSlide(
                      animation: _stagger(2),
                      child: _ActiveParkingCard(
                        session:   activeSession!,
                        pulseAnim: _pulseAnim,
                        onTap:     () => widget.openTab(1),
                      ),
                    ),
                  ],

                  // Profile prompt
                  if (user.plates.isEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    _FadeSlide(
                      animation: _stagger(3),
                      child: _ProfilePrompt(onTap: () => widget.openTab(4)),
                    ),
                  ],

                  // Packages
                  if (packages.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xl),
                    _FadeSlide(
                      animation: _stagger(4),
                      child: _SectionHeading(
                        title: 'Explore packages',
                        trailing: _SeeAllButton(
                            onTap: () => widget.openTab(3)),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    ...packages.take(4).toList().asMap().entries.map(
                      (e) => _FadeSlide(
                        animation: _stagger(5 + e.key, total: 9),
                        child: _PackageCard(package: e.value),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── notification sheet ────────────────────────────────────────────────────
  void _showNotifications() => showModalBottomSheet(
        context:         context,
        showDragHandle:  true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => StatefulBuilder(
          builder: (ctx, setSheet) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, 0, AppSpace.md, AppSpace.md),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Expanded(
                    child: Text('Updates',
                        style: TextStyle(
                            fontSize:   22,
                            fontWeight: FontWeight.w900,
                            color:      LightTheme.textPrimary)),
                  ),
                  TextButton(
                    onPressed: notifications.any((n) => n['isRead'] != true)
                        ? () async {
                            await _markAllRead();
                            setSheet(() {});
                          }
                        : null,
                    style: TextButton.styleFrom(
                        foregroundColor: LightTheme.brandBlue),
                    child: const Text('Mark all read',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: AppSpace.xs),
                if (notifications.isEmpty && feedbackReplies.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                    child: Column(children: [
                      Container(
                        height: 60, width: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              LightTheme.brandBlue.withOpacity(0.12),
                              LightTheme.brandCyan.withOpacity(0.06),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_none,
                            color: LightTheme.brandBlue, size: 28),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      const Text('You\'re all caught up!',
                          style: TextStyle(fontWeight: FontWeight.w800,
                              color: LightTheme.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('No new notifications right now.',
                          style: TextStyle(color: LightTheme.textSecondary, fontSize: 13)),
                    ]),
                  )
                else
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      if (notifications.isNotEmpty) ...[
                        _InboxHeading('Notifications'),
                        ...notifications.map((n) => _notifTile(n, setSheet)),
                      ],
                      if (feedbackReplies.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.sm),
                        _InboxHeading('Replies from parking management'),
                        ...feedbackReplies.map((r) => _feedbackTile(r, setSheet)),
                      ],
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      );

  Future<void> _markRead(Map<String, dynamic> n) async {
    final id = n['_id']?.toString();
    if (id == null || id.isEmpty || n['isRead'] == true) return;
    try {
      await widget.session.api.request('/users/notifications/$id/read',
          method: 'PATCH', token: widget.session.token);
      if (mounted) setState(() => n['isRead'] = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.session.api.request('/users/notifications/read-all',
          method: 'PATCH', token: widget.session.token);
      if (mounted) setState(() { for (final n in notifications) n['isRead'] = true; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _notifTile(Map<String, dynamic> n, StateSetter setSheet) => ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        leading: Container(
          height: 40, width: 40,
          decoration: BoxDecoration(
            color: n['isRead'] == true
                ? const Color(0xFFF1F5F9)
                : LightTheme.brandBlue.withOpacity(0.09),
            shape: BoxShape.circle,
          ),
          child: Icon(
            n['isRead'] == true
                ? Icons.notifications_none
                : Icons.notifications,
            color: n['isRead'] == true
                ? LightTheme.textMuted
                : LightTheme.brandBlue,
            size: 20,
          ),
        ),
        title: Text('${n['title'] ?? 'Notification'}',
            style: TextStyle(
                fontWeight: n['isRead'] == true
                    ? FontWeight.w600 : FontWeight.w800,
                color: LightTheme.textPrimary, fontSize: 14)),
        subtitle: Text('${n['message'] ?? ''}',
            style: const TextStyle(color: LightTheme.textSecondary, fontSize: 13)),
        onTap: () async { await _markRead(n); setSheet(() {}); },
      );

  Widget _feedbackTile(Map<String, dynamic> reply, StateSetter setSheet) {
    final read     = readFeedbackIds.contains('${reply['_id'] ?? ''}');
    final building = reply['building'] is Map
        ? '${reply['building']['name'] ?? 'Parking management'}'
        : 'Parking management';
    final plate = reply['parkingSession'] is Map
        ? '${reply['parkingSession']['plateNumber'] ?? ''}' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.xs),
      decoration: BoxDecoration(
        color:        read ? const Color(0xFFF8FAFC) : LightTheme.brandBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: read ? LightTheme.borderDefault : LightTheme.brandBlue.withOpacity(0.20),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () async { await _markFeedbackRead(reply); setSheet(() {}); },
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.reply_outlined, color: LightTheme.brandBlue, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(building,
                  style: const TextStyle(fontWeight: FontWeight.w800,
                      color: LightTheme.textPrimary, fontSize: 13))),
              if (!read) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LightTheme.brandBlue,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text('New', style: TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ]),
            if (plate.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(plate, style: const TextStyle(color: LightTheme.textMuted, fontSize: 11)),
            ],
            const SizedBox(height: 6),
            Text('${reply['staffReply']}',
                maxLines: read ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: LightTheme.textSecondary, height: 1.4, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.unread,
    required this.balance,
    required this.loading,
    required this.shimmerAnim,
    required this.onNotifications,
    required this.onLogout,
    required this.onTopUp,
  });
  final dynamic           user;
  final int               unread;
  final double?           balance;
  final bool              loading;
  final Animation<double> shimmerAnim;
  final VoidCallback      onNotifications;
  final VoidCallback      onLogout;
  final VoidCallback      onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF001E6C), Color(0xFF0038A0), Color(0xFF005AC5), Color(0xFF0082C8)],
          begin:  Alignment(-1.0, -1.0),
          end:    Alignment(1.0, 1.0),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(children: [
        // Decorative blurred circles
        Positioned(top: -40, right: -30,
          child: Container(
            height: 180, width: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Positioned(bottom: 20, left: -50,
          child: Container(
            height: 140, width: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, AppSpace.xl + 12, AppSpace.md, 36),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top bar ────────────────────────────────────────────────
            Row(children: [
              // Avatar
              Container(
                height: 48, width: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  shape:  BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.40), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    (user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Good to see you 👋',
                      style: TextStyle(
                          color: Color(0xAAFFFFFF), fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(user.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900,
                          letterSpacing: -0.3)),
                ]),
              ),
              _HeaderBtn(
                icon: Icons.notifications_outlined,
                tooltip: 'Notifications',
                badge: unread > 0 ? '$unread' : null,
                onTap: onNotifications,
              ),
              const SizedBox(width: 8),
              _HeaderBtn(
                icon: Icons.logout_outlined,
                tooltip: 'Sign out',
                onTap: onLogout,
              ),
            ]),

            const SizedBox(height: AppSpace.xl),

            // ── ATM Wallet Card ─────────────────────────────────────────
            _WalletCard(
              balance:     balance,
              loading:     loading,
              shimmerAnim: shimmerAnim,
              onTopUp:     onTopUp,
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Header icon button ────────────────────────────────────────────────────────
class _HeaderBtn extends StatefulWidget {
  const _HeaderBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });
  final IconData     icon;
  final String       tooltip;
  final String?      badge;
  final VoidCallback onTap;

  @override
  State<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends State<_HeaderBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _down = true),
        onTapUp:     (_) => setState(() => _down = false),
        onTapCancel: ()  => setState(() => _down = false),
        onTap:        widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve:    Curves.easeOut,
          height: 42, width: 42,
          decoration: BoxDecoration(
            color: _down
                ? Colors.white.withOpacity(0.30)
                : Colors.white.withOpacity(0.14),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Icon(widget.icon, color: Colors.white, size: 20),
            if (widget.badge != null)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  height: 13, width: 13,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(widget.badge!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 7,
                          fontWeight: FontWeight.w900)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATM-STYLE WALLET CARD  (with shimmer, chip, dot pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _WalletCard extends StatefulWidget {
  const _WalletCard({
    required this.balance,
    required this.loading,
    required this.shimmerAnim,
    required this.onTopUp,
  });
  final double?           balance;
  final bool              loading;
  final Animation<double> shimmerAnim;
  final VoidCallback      onTopUp;

  @override
  State<_WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<_WalletCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter:  (_) => setState(() => _hovered = true),
      onExit:   (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve:    Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_hovered ? -0.015 : 0)
          ..translate(0.0, _hovered ? -4.0 : 0.0),
        child: Container(
          width:   double.infinity,
          height:  175,
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF0096C7), Color(0xFF00B4D8)],
              begin:  Alignment(-0.8, -1.0),
              end:    Alignment(1.0,  1.0),
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
            boxShadow: [
              BoxShadow(
                color:      const Color(0xFF0052CC).withOpacity(_hovered ? 0.45 : 0.28),
                blurRadius: _hovered ? 36 : 22,
                offset:     Offset(0, _hovered ? 18 : 10),
              ),
              BoxShadow(
                color:      Colors.white.withOpacity(0.08),
                blurRadius: 1,
                offset:     const Offset(0, -1),
              ),
            ],
          ),
          child: Stack(children: [
            // ── Dot grid watermark ──────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter()),
            ),
            // ── Shimmer sweep ───────────────────────────────────────────
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedBuilder(
                  animation: widget.shimmerAnim,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(widget.shimmerAnim.value *
                        MediaQuery.of(context).size.width, 0),
                    child: Container(
                      width:   90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.10),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Card content ────────────────────────────────────────────
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Row: label + chip icon
              Row(children: [
                const Text('WALLET BALANCE',
                    style: TextStyle(
                        color:         Color(0xBBFFFFFF),
                        fontSize:      9,
                        fontWeight:    FontWeight.w800,
                        letterSpacing: 1.8)),
                const Spacer(),
                // Simulated chip
                Container(
                  height: 22, width: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // Balance
              widget.loading
                  ? _ShimmerBar(width: 170, height: 32)
                  : Text(
                      widget.balance == null
                          ? 'Unavailable'
                          : '${_money(widget.balance!)} VND',
                      style: const TextStyle(
                          color:       Colors.white,
                          fontSize:    28,
                          fontWeight:  FontWeight.w900,
                          letterSpacing: -0.5,
                          height:      1.0),
                    ),

              const Spacer(),

              // Bottom row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Top-up pill
                  GestureDetector(
                    onTap: widget.onTopUp,
                    child: _GlowPill(
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.add_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 5),
                        Text('Top up', style: TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  // PBMS watermark
                  Text('PBMS',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.30),
                          fontSize: 13, fontWeight: FontWeight.w900,
                          letterSpacing: 4)),
                ],
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// Pill with glow border
class _GlowPill extends StatelessWidget {
  const _GlowPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withOpacity(0.38), width: 1),
          boxShadow: [
            BoxShadow(
              color:      Colors.white.withOpacity(0.08),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

// Shimmer bar for loading state
class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
        ),
      );
}

// Dot grid watermark painter
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color  = Colors.white.withOpacity(0.06)
      ..style  = PaintingStyle.fill;
    const step = 18.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.session, required this.openTab});
  final SessionController session;
  final ValueChanged<int> openTab;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, List<Color>, VoidCallback)>[
      (Icons.account_balance_wallet_outlined, 'Top up',
          [const Color(0xFF0052CC), const Color(0xFF00A8E8)],
          () => openTab(2)),
      (Icons.business_outlined, 'Buildings',
          [const Color(0xFF059669), const Color(0xFF34D399)],
          () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BuildingsPage(session: session)))),
      (Icons.inventory_2_outlined, 'Packages',
          [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
          () => openTab(3)),
      (Icons.qr_code_2_outlined, 'My QR',
          [const Color(0xFF0891B2), const Color(0xFF22D3EE)],
          () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VehicleQrPage(
                  session: session, onAddVehicle: () => openTab(4))))),
      (Icons.report_problem_outlined, 'Incidents',
          [const Color(0xFFE11D48), const Color(0xFFFB7185)],
          () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => IncidentPage(session: session)))),
    ];
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding:          const EdgeInsets.symmetric(horizontal: 2),
        itemCount:        items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final (icon, label, colors, onTap) = items[i];
          return _QuickChip(
              icon: icon, label: label, colors: colors, onTap: onTap);
        },
      ),
    );
  }
}

class _QuickChip extends StatefulWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });
  final IconData     icon;
  final String       label;
  final List<Color>  colors;
  final VoidCallback onTap;

  @override
  State<_QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<_QuickChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown:   (_) => _ctrl.forward(),
        onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: ()  => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: SizedBox(
            width: 80,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Gradient circle
              Container(
                height: 62, width: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.colors[0].withOpacity(0.14),
                      widget.colors[1].withOpacity(0.07),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: widget.colors[0].withOpacity(0.22), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color:      widget.colors[0].withOpacity(0.15),
                        blurRadius: 14, offset: const Offset(0, 5)),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (r) => LinearGradient(
                    colors: widget.colors,
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ).createShader(r),
                  child: Icon(widget.icon, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(height: 7),
              Text(widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: LightTheme.textPrimary)),
            ]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE PARKING CARD  (pulsing LED + frosted green glass)
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveParkingCard extends StatelessWidget {
  const _ActiveParkingCard({
    required this.session,
    required this.pulseAnim,
    required this.onTap,
  });
  final Map<String, dynamic> session;
  final Animation<double>    pulseAnim;
  final VoidCallback         onTap;

  @override
  Widget build(BuildContext context) {
    final building = session['building'] is Map
        ? '${session['building']['name'] ?? 'Parking location'}'
        : 'Parking location';
    final plate = '${session['plateNumber'] ?? 'Vehicle'}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:     const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDCFCE7), Color(0xFFECFDF5)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: const Color(0xFF16A34A).withOpacity(0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
                color:      const Color(0xFF16A34A).withOpacity(0.10),
                blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          // Pulsing LED
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Container(
              height: 11, width: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(pulseAnim.value),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      const Color(0xFF16A34A)
                        .withOpacity(pulseAnim.value * 0.55),
                    blurRadius: 10, spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Icon
          Container(
            height: 40, width: 40,
            decoration: BoxDecoration(
              color:  const Color(0xFF16A34A).withOpacity(0.12),
              shape:  BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF16A34A).withOpacity(0.20)),
            ),
            child: const Icon(Icons.local_parking_rounded,
                color: Color(0xFF15803D), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Vehicle currently parked',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14,
                      color: Color(0xFF14532D))),
              const SizedBox(height: 3),
              Text('$plate · $building',
                  style: const TextStyle(
                      color: Color(0xFF166534), fontSize: 12, height: 1.3)),
            ]),
          ),
          Container(
            height: 28, width: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF15803D), size: 18),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE PROMPT
// ─────────────────────────────────────────────────────────────────────────────

class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFEF9C3)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: const Color(0xFFCA8A04).withOpacity(0.30), width: 1.2),
          boxShadow: [
            BoxShadow(
                color:      const Color(0xFFCA8A04).withOpacity(0.09),
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
            height: 42, width: 42,
            decoration: BoxDecoration(
              color:  const Color(0xFFFDE68A).withOpacity(0.6),
              shape:  BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFCA8A04).withOpacity(0.25)),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFB45309), size: 21),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Complete your profile',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14,
                      color: Color(0xFF78350F))),
              SizedBox(height: 2),
              Text('Add a license plate to start parking.',
                  style: TextStyle(color: Color(0xFFA16207), fontSize: 12)),
            ]),
          ),
          Container(
            height: 28, width: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFCA8A04).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFFB45309), size: 14),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PACKAGE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PackageCard extends StatefulWidget {
  const _PackageCard({required this.package});
  final Map<String, dynamic> package;

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isCar = (widget.package['name'] ?? '').toString()
        .toLowerCase().contains('car');
    final accentColors = isCar
        ? [const Color(0xFF0052CC), const Color(0xFF00A8E8)]
        : [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];

    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          margin:  const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md, vertical: 14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border:  Border.all(color: const Color(0xFFE8EFF8), width: 1),
            boxShadow: [
              BoxShadow(
                  color:      const Color(0xFF0052CC).withOpacity(0.04),
                  blurRadius: 2,  offset: const Offset(0, 1)),
              BoxShadow(
                  color:      const Color(0xFF0052CC).withOpacity(0.06),
                  blurRadius: 10, offset: const Offset(0, 4)),
              BoxShadow(
                  color:      const Color(0xFF0052CC).withOpacity(0.03),
                  blurRadius: 24, offset: const Offset(0, 12)),
            ],
          ),
          child: Row(children: [
            // Left accent strip
            Container(
              width: 3, height: 44,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: accentColors,
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Icon
            Container(
              height: 44, width: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColors[0].withOpacity(0.12),
                    accentColors[1].withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: accentColors[0].withOpacity(0.18)),
              ),
              child: ShaderMask(
                shaderCallback: (r) => LinearGradient(
                  colors: accentColors,
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ).createShader(r),
                child: Icon(
                  isCar
                      ? Icons.directions_car_outlined
                      : Icons.two_wheeler_outlined,
                  color: Colors.white, size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  (widget.package['name'] ?? 'Parking package').toString(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14,
                      color: LightTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.schedule_outlined,
                      size: 12, color: LightTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.package['durationDays'] ?? '—'} days',
                    style: const TextStyle(
                        color: LightTheme.textSecondary, fontSize: 12),
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            // Price chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColors[0].withOpacity(0.08),
                    accentColors[1].withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: accentColors[0].withOpacity(0.18)),
              ),
              child: Text(
                '${_money(_asNum(widget.package['price']))} VND',
                style: TextStyle(
                    color:      accentColors[0],
                    fontWeight: FontWeight.w900,
                    fontSize:   12),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FADE + SLIDE  staggered entry animation
// ─────────────────────────────────────────────────────────────────────────────

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget            child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, ch) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value.clamp(0.0, 1.0))),
          child: ch,
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADING
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});
  final String  title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        // Accent bar
        Container(
          width: 3, height: 18,
          margin: const EdgeInsets.only(right: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [LightTheme.brandBlue, LightTheme.brandCyan],
              begin:  Alignment.topCenter,
              end:    Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize:   17,
                  fontWeight: FontWeight.w900,
                  color:      LightTheme.textPrimary,
                  letterSpacing: -0.3)),
        ),
        if (trailing != null) trailing!,
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// SEE ALL BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:        LightTheme.brandBlue.withOpacity(0.07),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
                color: LightTheme.brandBlue.withOpacity(0.18)),
          ),
          child: const Text('See all',
              style: TextStyle(
                  color:      LightTheme.brandBlue,
                  fontWeight: FontWeight.w800,
                  fontSize:   12)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// INBOX HEADING
// ─────────────────────────────────────────────────────────────────────────────

class _InboxHeading extends StatelessWidget {
  const _InboxHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Text(text,
            style: const TextStyle(
                color:      LightTheme.textMuted,
                fontWeight: FontWeight.w800,
                fontSize:   11,
                letterSpacing: 0.6)),
      );
}
