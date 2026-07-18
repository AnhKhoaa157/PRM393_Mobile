part of '../main.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.session});
  final SessionController session;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> history = [];
  Set<String> reviewedSessionIds = <String>{};
  DateTime? historyStart;
  DateTime? historyEnd;
  bool loading = true;
  String _filter = 'All'; // All / Active / Completed
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    load();
  }

  @override
  void dispose() { _staggerCtrl.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await widget.session.api.request('/users/parking-history', token: widget.session.token);
      dynamic feedback;
      try { feedback = await widget.session.api.request('/users/feedbacks/me', token: widget.session.token); } catch (_) {}
      if (mounted) setState(() {
        history = _items(response);
        reviewedSessionIds = feedback == null ? <String>{} : _items(feedback).map((item) {
          final session = item['parkingSession'];
          return session is Map ? '${session['_id'] ?? ''}' : '${session ?? ''}';
        }).where((id) => id.isNotEmpty).toSet();
      });
    } catch (error) { if (mounted) _snack(error); }
    if (mounted) { setState(() => loading = false); _staggerCtrl.forward(from: 0); }
  }

  bool _canRate(Map<String, dynamic> item) => item['status'] == 'completed' &&
      '${item['_id'] ?? ''}'.isNotEmpty && !reviewedSessionIds.contains('${item['_id']}');

  Future<void> _pickHistoryDate({required bool start}) async {
    final selected = await showDatePicker(
        context: context,
        initialDate: start ? historyStart ?? DateTime.now() : historyEnd ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (selected == null || !mounted) return;
    setState(() {
      if (start) { historyStart = selected; } else { historyEnd = selected; }
      if (historyStart != null && historyEnd != null && historyEnd!.isBefore(historyStart!)) historyEnd = historyStart;
    });
  }

  List<Map<String, dynamic>> get _visibleHistory => history.where((item) {
    final status = '${item['status'] ?? ''}';
    if (_filter != 'All' && status != _filter.toLowerCase()) return false;
    final raw  = item['entryTime'] ?? item['check_in'] ?? item['checkIn'];
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (date == null) return historyStart == null && historyEnd == null;
    final day   = DateTime(date.year, date.month, date.day);
    final start = historyStart == null ? null : DateTime(historyStart!.year, historyStart!.month, historyStart!.day);
    final end   = historyEnd   == null ? null : DateTime(historyEnd!.year,   historyEnd!.month,   historyEnd!.day);
    return (start == null || !day.isBefore(start)) && (end == null || !day.isAfter(end));
  }).toList();

  double get _totalSpent => history.fold(0.0, (s, i) => s + _asNum(i['fee']));
  int    get _activeCount => history.where((i) => i['status'] == 'active').length;

  Future<void> _showFeedback(Map<String, dynamic> session) async {
    final sessionId = '${session['_id'] ?? ''}';
    if (sessionId.isEmpty) return;
    var rating = 0; var submitting = false; String? error; var comment = '';
    final submitted = await showModalBottomSheet<bool>(
        context: context, isScrollControlled: true, showDragHandle: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpace.lg),
            child: StatefulBuilder(builder: (context, setSheetState) {
              Future<void> submit() async {
                if (rating == 0 || comment.trim().isEmpty) { setSheetState(() => error = 'Choose a rating and add a short comment.'); return; }
                setSheetState(() { submitting = true; error = null; });
                try {
                  await widget.session.api.request('/users/feedbacks', method: 'POST', token: widget.session.token, body: {
                    'parkingSession': sessionId, 'rating': rating, 'comment': comment.trim(),
                    if (session['building'] is Map) 'building': session['building']['_id'],
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (value) { setSheetState(() => error = value.toString()); }
                finally { if (context.mounted) setSheetState(() => submitting = false); }
              }
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Rate your experience', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: LightTheme.textPrimary)),
                const SizedBox(height: AppSpace.xs),
                Text('${session['plateNumber'] ?? 'Parking session'}', style: const TextStyle(color: LightTheme.textSecondary)),
                const SizedBox(height: AppSpace.md),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) => IconButton(
                    tooltip: '${index + 1} stars',
                    onPressed: submitting ? null : () => setSheetState(() => rating = index + 1),
                    iconSize: 36, color: const Color(0xFFCA8A04),
                    icon: Icon(index < rating ? Icons.star_rounded : Icons.star_outline_rounded)))),
                TextField(onChanged: (value) => comment = value, enabled: !submitting, maxLength: 150, minLines: 3, maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Your feedback', hintText: 'Tell us what went well or could improve')),
                if (error != null) Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: Text(error!, style: const TextStyle(color: AppColors.danger))),
                const SizedBox(height: AppSpace.sm),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: submitting ? null : () => Navigator.pop(context), child: const Text('Later'))),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: FilledButton(onPressed: submitting ? null : submit,
                      child: submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Submit review'))),
                ]),
              ]);
            })));
    if (submitted == true) { await load(); if (mounted) _snack('Thank you for your feedback.'); }
  }

  void _snack(Object value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value.toString())));

  Animation<double> _stagger(int i, {int total = 8}) {
    final start = (i / total) * 0.55;
    final end   = (start + 0.5).clamp(0.0, 1.0);
    return CurvedAnimation(parent: _staggerCtrl, curve: Interval(start, end, curve: Curves.easeOutCubic));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleHistory;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: RefreshIndicator(
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
                  title: const Text('Parking history',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: LightTheme.textPrimary,
                          letterSpacing: -0.5)),
                  actions: [
                    _HistRefreshBtn(onTap: load),
                    const SizedBox(width: 16),
                  ],
                ),

                // â”€â”€ Header Panel Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                    child: _HistoryHeader(
                      totalSessions: history.length,
                      activeCount:   _activeCount,
                      totalSpent:    _totalSpent,
                      loading:       loading,
                    ),
                  ),
                ),

                // â”€â”€ Filter bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.xs),
                    child: _FilterBar(
                      selected: _filter,
                      allCount:       history.length,
                      activeCount:    _activeCount,
                      completedCount: history.where((i) => i['status'] == 'completed').length,
                      onSelect: (v) => setState(() => _filter = v),
                    ),
                  ),
                ),

                // â”€â”€ Date pills â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.sm),
                    child: _DateFilterRow(
                      start: historyStart, end: historyEnd,
                      onPickStart: () => _pickHistoryDate(start: true),
                      onPickEnd:   () => _pickHistoryDate(start: false),
                      onClear: (historyStart != null || historyEnd != null)
                          ? () => setState(() { historyStart = null; historyEnd = null; })
                          : null,
                    ),
                  ),
                ),

                // â”€â”€ Loading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (loading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: const LinearProgressIndicator(
                            minHeight: 3, color: LightTheme.brandBlue, backgroundColor: Color(0xFFDCE5F0)),
                      ),
                    ),
                  ),

                // â”€â”€ Empty â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (!loading && history.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                      child: _HistoryEmptyState(icon: Icons.history_rounded,
                          title: 'No parking history yet', detail: 'Completed parking sessions will appear here.')),
                if (!loading && history.isNotEmpty && visible.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                      child: _HistoryEmptyState(icon: Icons.search_off_rounded,
                          title: 'No matching sessions', detail: 'Try a different filter or date range.')),

                // â”€â”€ Session list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.md, 4, AppSpace.md, AppSpace.xl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final item = visible[i];
                        return AnimatedBuilder(
                          animation: _stagger(i),
                          builder: (_, ch) => Opacity(
                            opacity: _stagger(i).value.clamp(0.0, 1.0),
                            child: Transform.translate(
                                offset: Offset(0, 24 * (1 - _stagger(i).value.clamp(0.0, 1.0))), child: ch),
                          ),
                          child: _HistoryCard(
                              item: item, canRate: _canRate(item), onRate: () => _showFeedback(item)),
                        );
                      },
                      childCount: visible.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// GRADIENT HEADER WIDGET
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.totalSessions, required this.activeCount,
    required this.totalSpent, required this.loading,
  });
  final int    totalSessions;
  final int    activeCount;
  final double totalSpent;
  final bool   loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0038A0), Color(0xFF005AC5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF001E6C).withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // Decorative glowing circles
        Positioned(top: -45, right: -35,
            child: Container(height: 150, width: 150,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
        Positioned(bottom: -30, left: -40,
            child: Container(height: 120, width: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Subtitle detail
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 13),
                ),
                const SizedBox(width: 8),
                Text('Overview statistics'.toUpperCase(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ],
            ),
            const SizedBox(height: 20),

            // Top Row: Total Spent prominent display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL SPENT',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.60),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0)),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          loading ? '...' : _money(totalSpent),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'VND',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              height: 1.0),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.20), width: 1.2),
                  ),
                  child: const Icon(Icons.payments_outlined, color: Colors.white, size: 22),
                )
              ],
            ),

            const SizedBox(height: 20),
            // Sleek white divider
            Container(height: 1, color: Colors.white.withOpacity(0.12)),
            const SizedBox(height: 18),

            // Bottom Row: 2 column side-by-side stats
            Row(children: [
              // Total sessions
              Expanded(
                child: Row(children: [
                  Container(
                    height: 38, width: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                    ),
                    child: const Icon(Icons.local_parking_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(loading ? '...' : '$totalSessions',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
                      const SizedBox(height: 2),
                      Text('Total visits',
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              // Active sessions
              Expanded(
                child: Row(children: [
                  Container(
                    height: 38, width: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.30), width: 1),
                    ),
                    child: const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF4ADE80), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(loading ? '...' : '$activeCount',
                          style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
                      const SizedBox(height: 2),
                      Text('Active now',
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// REFRESH BUTTON
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _HistRefreshBtn extends StatefulWidget {
  const _HistRefreshBtn({required this.onTap, this.light = false});
  final VoidCallback onTap;
  final bool light;
  @override State<_HistRefreshBtn> createState() => _HistRefreshBtnState();
}
class _HistRefreshBtnState extends State<_HistRefreshBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rot;
  bool _pressed = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _rot  = Tween<double>(begin: 0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.light ? Colors.white.withOpacity(0.30) : LightTheme.brandBlue.withOpacity(0.22);
    final bgColor     = widget.light
        ? (_pressed ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.14))
        : (_pressed ? LightTheme.brandBlue.withOpacity(0.14) : LightTheme.brandBlue.withOpacity(0.07));
    final iconColor   = widget.light ? Colors.white : LightTheme.brandBlue;
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); _ctrl.forward(from: 0); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 38, width: 38,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1)),
        child: AnimatedBuilder(
          animation: _rot,
          builder: (_, ch) => Transform.rotate(angle: _rot.value * 6.28, child: ch),
          child: Icon(Icons.refresh_rounded, color: iconColor, size: 19),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// FILTER BAR (All / Active / Completed)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected, required this.allCount,
    required this.activeCount, required this.completedCount, required this.onSelect,
  });
  final String   selected;
  final int      allCount;
  final int      activeCount;
  final int      completedCount;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('All',       allCount,       LightTheme.brandBlue),
      ('Active',    activeCount,    const Color(0xFF16A34A)),
      ('Completed', completedCount, const Color(0xFF1D4ED8)),
    ];
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: tabs.map((tab) {
          final (label, count, color) = tab;
          final active = selected == label;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color:        active ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: active ? [BoxShadow(color: color.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 2))] : [],
                ),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label,
                        style: TextStyle(
                            fontSize:   12,
                            fontWeight: FontWeight.w800,
                            color:      active ? Colors.white : LightTheme.textSecondary)),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color:        active ? Colors.white.withOpacity(0.25) : color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('$count',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900,
                                color: active ? Colors.white : color)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DATE FILTER ROW
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow({required this.start, required this.end, required this.onPickStart, required this.onPickEnd, required this.onClear});
  final DateTime? start; final DateTime? end;
  final VoidCallback onPickStart; final VoidCallback onPickEnd; final VoidCallback? onClear;
  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }
  @override
  Widget build(BuildContext context) => Row(children: [
    _DatePill(icon: Icons.calendar_today_rounded, label: start == null ? 'From date' : _fmt(start), active: start != null, onTap: onPickStart),
    const SizedBox(width: 8),
    _DatePill(icon: Icons.event_rounded, label: end == null ? 'To date' : _fmt(end), active: end != null, onTap: onPickEnd),
    if (onClear != null) ...[const SizedBox(width: 8), _ClearPill(onTap: onClear!)],
  ]);
}

class _DatePill extends StatefulWidget {
  const _DatePill({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  @override State<_DatePill> createState() => _DatePillState();
}
class _DatePillState extends State<_DatePill> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final accent = widget.active ? LightTheme.brandBlue : LightTheme.textMuted;
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        transform: Matrix4.identity()..scale(_pressed ? 0.95 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: widget.active ? LightTheme.brandBlue.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: widget.active ? LightTheme.brandBlue.withOpacity(0.30) : LightTheme.borderDefault, width: widget.active ? 1.4 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(widget.label, style: TextStyle(fontSize: 13, fontWeight: widget.active ? FontWeight.w700 : FontWeight.w600,
              color: widget.active ? LightTheme.brandBlue : LightTheme.textSecondary)),
        ]),
      ),
    );
  }
}

class _ClearPill extends StatelessWidget {
  const _ClearPill({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.filter_alt_off_outlined, size: 14, color: AppColors.danger.withOpacity(0.80)),
        const SizedBox(width: 5),
        Text('Clear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger.withOpacity(0.80))),
      ]),
    ),
  );
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// PREMIUM HISTORY CARD
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.item, required this.canRate, required this.onRate});
  final Map<String, dynamic> item; final bool canRate; final VoidCallback onRate;
  @override State<_HistoryCard> createState() => _HistoryCardState();
}
class _HistoryCardState extends State<_HistoryCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final item      = widget.item;
    final status    = '${item['status'] ?? 'unknown'}';
    final isActive  = status == 'active';
    final plate     = '${item['plateNumber'] ?? 'Vehicle'}';
    final building  = item['building'] is Map ? '${item['building']['name'] ?? 'Parking location'}' : 'Parking location';
    final entryRaw  = item['entryTime'] ?? item['check_in'] ?? item['checkIn'];
    final exitRaw   = item['exitTime']  ?? item['check_out'] ?? item['checkOut'];
    final fee       = _asNum(item['fee']);
    final isCar     = plate.length > 7;

    final vehicleColors = isCar
        ? [const Color(0xFF0052CC), const Color(0xFF00A8E8)]
        : [const Color(0xFF7C3AED), const Color(0xFFA78BFA)];

    final (statusBg, statusFg, statusBorder) = switch (status) {
      'active'    => (const Color(0xFFDCFCE7), const Color(0xFF15803D), const Color(0xFF16A34A)),
      'completed' => (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), const Color(0xFF3B82F6)),
      _           => (const Color(0xFFF8FAFC), LightTheme.textMuted,    LightTheme.borderDefault),
    };

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 14),
        transform: Matrix4.identity()
          ..translate(0.0, _pressed ? 3.0 : 0.0)
          ..scale(_pressed ? 0.982 : 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isActive ? const Color(0xFF16A34A).withOpacity(0.28) : const Color(0xFFE2E8F0),
              width: 1.2),
          boxShadow: _pressed ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 2,  offset: const Offset(0, 1)),
            BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 30, offset: const Offset(0, 16)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // â”€â”€ Colored banner header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [vehicleColors[0].withOpacity(0.08), vehicleColors[1].withOpacity(0.03)],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: vehicleColors[0].withOpacity(0.10), width: 1)),
            ),
            child: Row(children: [
              // Vehicle icon
              Container(
                height: 46, width: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [vehicleColors[0].withOpacity(0.18), vehicleColors[1].withOpacity(0.09)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: vehicleColors[0].withOpacity(0.25), width: 1.2),
                  boxShadow: [BoxShadow(color: vehicleColors[0].withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: ShaderMask(
                  shaderCallback: (r) => LinearGradient(colors: vehicleColors, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(r),
                  child: Icon(isCar ? Icons.directions_car_filled_rounded : Icons.two_wheeler_rounded, color: Colors.white, size: 23),
                ),
              ),
              const SizedBox(width: 12),
              // Plate number (Vietnamese License Plate Style) + building
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF475569), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 2, offset: const Offset(0, 1))
                    ]
                  ),
                  child: Text(
                    plate.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.8,
                      height: 1.1
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 12, color: LightTheme.textMuted),
                  const SizedBox(width: 3),
                  Expanded(child: Text(building, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: LightTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
                ]),
              ])),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: statusBorder.withOpacity(0.35), width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isActive)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Container(
                        height: 7, width: 7, margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: statusFg.withOpacity(_pulseAnim.value), shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: statusFg.withOpacity(_pulseAnim.value * 0.55), blurRadius: 6, spreadRadius: 1)],
                        ),
                      ),
                    )
                  else
                    Container(height: 7, width: 7, margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(color: statusFg, shape: BoxShape.circle)),
                  Text(status, style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),

          // â”€â”€ Timeline row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              // Entry
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(height: 8, width: 8,
                      decoration: BoxDecoration(color: vehicleColors[0], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('CHECK IN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                      color: vehicleColors[0], letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(_date(entryRaw),
                      style: const TextStyle(color: LightTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ])),

              // Divider (Premium track line connector)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: isActive ? const Color(0xFF16A34A) : LightTheme.textMuted,
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // Exit
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('CHECK OUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                      color: isActive ? const Color(0xFF16A34A) : LightTheme.textMuted, letterSpacing: 0.8)),
                  const SizedBox(width: 6),
                  Container(height: 8, width: 8,
                      decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF16A34A) : LightTheme.textMuted,
                          shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                      isActive ? 'Parking...' : _date(exitRaw),
                      style: TextStyle(
                          color: isActive ? const Color(0xFF16A34A) : LightTheme.textPrimary,
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ])),
            ]),
          ),

          // â”€â”€ Footer: fee + rate â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: const Color(0xFFE8EFF8), width: 1)),
            ),
            child: Row(children: [
              // Fee chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: fee > 0
                        ? [LightTheme.brandBlue.withOpacity(0.09), LightTheme.brandCyan.withOpacity(0.05)]
                        : [LightTheme.textMuted.withOpacity(0.07), LightTheme.textMuted.withOpacity(0.03)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: fee > 0 ? LightTheme.brandBlue.withOpacity(0.18) : LightTheme.borderDefault),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.payments_outlined, size: 13,
                      color: fee > 0 ? LightTheme.brandBlue : LightTheme.textMuted),
                  const SizedBox(width: 5),
                  Text('${_money(fee)} VND',
                      style: TextStyle(
                          color: fee > 0 ? LightTheme.brandBlue : LightTheme.textMuted,
                          fontWeight: FontWeight.w900, fontSize: 13)),
                ]),
              ),

              const Spacer(),

              if (widget.canRate)
                GestureDetector(
                  onTap: widget.onRate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: const Color(0xFFCA8A04).withOpacity(0.30)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.star_outline_rounded, size: 14, color: Color(0xFFB45309)),
                      SizedBox(width: 5),
                      Text('Rate visit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                    ]),
                  ),
                )
              else if (status == 'completed')
                Row(children: const [
                  Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 4),
                  Text('Completed', style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EMPTY STATE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.icon, required this.title, required this.detail});
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
}class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.session});
  final SessionController session;
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with TickerProviderStateMixin {
  static const _minimumTopUp = 2000;
  static const _maximumTopUp = 10000000;
  double balance = 0;
  List<Map<String, dynamic>> transactions = [];
  DateTime? transactionStart;
  DateTime? transactionEnd;
  bool loading = true;
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    load();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        widget.session.api.request('/users/wallet', token: widget.session.token),
        widget.session.api.request('/users/wallet/transactions', token: widget.session.token)
      ]);
      if (mounted) {
        setState(() {
          balance = _asNum(_data(values[0])['walletBalance']);
          transactions = _items(values[1]);
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

  Animation<double> _stagger(int i, {int total = 8}) {
    final start = (i / total) * 0.5;
    final end = (start + 0.5).clamp(0.0, 1.0);
    return CurvedAnimation(parent: _staggerCtrl, curve: Interval(start, end, curve: Curves.easeOutCubic));
  }

  Future<void> topUp() async {
    final controller = TextEditingController(text: '50000');
    final amount = await showDialog<double>(
        context: context,
        builder: (dialogContext) {
          String? error;
          return StatefulBuilder(builder: (context, setDialogState) {
            void continuePayment() {
              final value = double.tryParse(controller.text.replaceAll(',', ''));
              if (value == null || value < _minimumTopUp) {
                setDialogState(() => error = 'Minimum top-up is ' + _money(_minimumTopUp) + ' VND.');
                return;
              }
              if (value > _maximumTopUp) {
                setDialogState(() => error = 'Maximum top-up is ' + _money(_maximumTopUp) + ' VND.');
                return;
              }
              Navigator.pop(dialogContext, value);
            }

            return Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                insetPadding: const EdgeInsets.all(AppSpace.lg),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Container(
                                    height: 46, width: 46,
                                    decoration: BoxDecoration(
                                        color: LightTheme.brandBlue.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: LightTheme.brandBlue.withOpacity(0.20))),
                                    child: Icon(Icons.account_balance_wallet_outlined, color: LightTheme.brandBlue, size: 22)),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text('Top up wallet',
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  color: LightTheme.textPrimary,
                                                  letterSpacing: -0.4)),
                                          Text('Select or enter amount',
                                              style: TextStyle(color: LightTheme.textSecondary, fontSize: 13))
                                        ])),
                                IconButton(
                                    tooltip: 'Close',
                                    onPressed: () => Navigator.pop(dialogContext),
                                    icon: const Icon(Icons.close_rounded))
                              ]),
                              const SizedBox(height: AppSpace.lg),
                              TextField(
                                  controller: controller,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) {
                                    if (error != null) setDialogState(() => error = null);
                                  },
                                  onSubmitted: (_) => continuePayment(),
                                  decoration: InputDecoration(
                                      labelText: 'Amount (VND)',
                                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                                      prefixIcon: Icon(Icons.payments_outlined, color: LightTheme.brandBlue),
                                      suffixText: 'VND',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                      focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: LightTheme.brandBlue, width: 2),
                                          borderRadius: BorderRadius.circular(16)))),
                              const SizedBox(height: AppSpace.md),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final value in [50000, 100000, 200000, 500000])
                                  _FastAmountChip(
                                    value: value,
                                    selected: controller.text == '$value',
                                    onSelected: () => setDialogState(() {
                                      controller.text = '$value';
                                      error = null;
                                    }),
                                  )
                              ]),
                              if (error != null) ...[
                                const SizedBox(height: AppSpace.sm),
                                Text(error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13))
                              ],
                              const SizedBox(height: AppSpace.lg),
                              Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0))),
                                  child: Row(children: [
                                    Icon(Icons.info_outline_rounded, color: LightTheme.textSecondary, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text('Minimum ' + _money(_minimumTopUp) + ' VND. Secure payment authentication inside banking app.',
                                            style: TextStyle(color: LightTheme.textSecondary, fontSize: 11, height: 1.4)))
                                  ])),
                              const SizedBox(height: AppSpace.xl),
                              _CustomScaleButton(
                                onTap: continuePayment,
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF0038A0), Color(0xFF0072FF)]),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF0038A0).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))
                                    ]
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Continue to payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpace.xs),
                              TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: LightTheme.textSecondary)))
                            ]))));
          });
        });
    controller.dispose();
    if (amount == null || amount <= 0) return;
    try {
      final result = await widget.session.api.request('/users/wallet/topup', method: 'POST', token: widget.session.token, body: {'amount': amount.round()});
      final data = _data(result);
      if (data['credited'] == true) {
        await load();
        if (mounted) _snack('Wallet topped up successfully.');
        return;
      }
      final orderCode = '${data['orderCode'] ?? ''}';
      if (!mounted) return;
      await _showPaymentDetails(data, amount.round());
      if (orderCode.isNotEmpty) await _verifyTopUp(orderCode, quiet: true);
    } catch (error) { if (mounted) _snack(error); }
  }

  Future<void> _showPaymentDetails(Map<String, dynamic> data, int amount) async {
    final orderCode = '${data['orderCode'] ?? ''}';
    final checkoutUrl = Uri.tryParse('${data['checkoutUrl'] ?? ''}');
    final qrCode = '${data['qrCode'] ?? ''}';
    Future<void> openCheckout() async {
      if (checkoutUrl == null || !await canLaunchUrl(checkoutUrl)) {
        if (mounted) _snack('Unable to open the payment page. Scan the QR code instead.');
        return;
      }
      await launchUrl(checkoutUrl, mode: LaunchMode.externalApplication);
    }

    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            insetPadding: const EdgeInsets.all(AppSpace.lg),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Container(
                                height: 46, width: 46,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF86EFAC))),
                                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF15803D), size: 24)),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('Complete payment',
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: LightTheme.textPrimary)),
                                      Text('Scan with your banking app',
                                          style: TextStyle(color: LightTheme.textSecondary, fontSize: 13)),
                                    ])),
                            IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close_rounded)),
                          ]),
                          const SizedBox(height: AppSpace.lg),
                          if (qrCode.isNotEmpty)
                            Center(
                                child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))
                                      ]
                                    ),
                                    child: QrImageView(data: qrCode, size: 188)))
                          else
                            const AppEmptyState(
                                icon: Icons.qr_code_2_outlined,
                                title: 'QR is unavailable',
                                detail: 'Open the secure payment page instead.'),
                          const SizedBox(height: AppSpace.lg),
                          _paymentDetail('Amount', _money(amount) + ' VND', emphasis: true),
                          _paymentDetail('Account number', '${data['accountNumber'] ?? 'Not provided'}'),
                          _paymentDetail('Account holder', '${data['accountName'] ?? 'Not provided'}'),
                          _paymentDetail('Transfer content', '${data['description'] ?? orderCode}'),
                          const SizedBox(height: AppSpace.lg),
                          _CustomScaleButton(
                            onTap: openCheckout,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                  color: LightTheme.brandBlue,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: LightTheme.brandBlue.withOpacity(0.20), blurRadius: 12, offset: const Offset(0, 4))
                                  ]
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Open payment page', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          OutlinedButton.icon(
                              onPressed: orderCode.isEmpty
                                  ? null
                                  : () async {
                                      await _verifyTopUp(orderCode);
                                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                                    },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: LightTheme.brandBlue, width: 1.5)
                              ),
                              icon: const Icon(Icons.verified_user_outlined, size: 18),
                              label: const Text('I completed payment', style: TextStyle(fontWeight: FontWeight.w800))),
                          const SizedBox(height: 6),
                          TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Verify later', style: TextStyle(color: LightTheme.textSecondary, fontWeight: FontWeight.bold))),
                        ])))));
  }

  Widget _paymentDetail(String label, String value, {bool emphasis = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9))
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  color: LightTheme.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8)),
          const SizedBox(height: 4),
          SelectableText(value,
              style: TextStyle(
                  color: emphasis ? LightTheme.brandBlue : LightTheme.textPrimary,
                  fontSize: emphasis ? 18 : 14,
                  fontWeight: emphasis ? FontWeight.w900 : FontWeight.w700)),
        ]),
      ));

  Future<void> _verifyTopUp(String orderCode, {bool quiet = false}) async {
    try {
      final result = await widget.session.api.request(
          '/users/wallet/topup/$orderCode/status',
          token: widget.session.token);
      await load();
      if (!mounted || quiet) return;
      final data = _data(result);
      _snack(data['credited'] == true
          ? 'Payment verified. Your wallet has been credited.'
          : 'Payment status: ' + (data['status'] ?? 'pending') + '.');
    } catch (error) {
      if (mounted && !quiet) _snack(error);
    }
  }

  Future<void> _pickTransactionDate({required bool start}) async {
    final selected = await showDatePicker(
        context: context,
        initialDate: start ? transactionStart ?? DateTime.now() : transactionEnd ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (selected == null || !mounted) return;
    setState(() {
      if (start) transactionStart = selected; else transactionEnd = selected;
      if (transactionStart != null && transactionEnd != null && transactionEnd!.isBefore(transactionStart!)) transactionEnd = transactionStart;
    });
  }

  List<Map<String, dynamic>> get _visibleTransactions => transactions.where((item) {
    final date = DateTime.tryParse('${item['createdAt'] ?? ''}')?.toLocal();
    if (date == null) return transactionStart == null && transactionEnd == null;
    final day = DateTime(date.year, date.month, date.day);
    final start = transactionStart == null ? null : DateTime(transactionStart!.year, transactionStart!.month, transactionStart!.day);
    final end = transactionEnd == null ? null : DateTime(transactionEnd!.year, transactionEnd!.month, transactionEnd!.day);
    return (start == null || !day.isBefore(start)) && (end == null || !day.isAfter(end));
  }).toList();

  void _snack(Object value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value.toString())));

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTransactions;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: RefreshIndicator(
            onRefresh: load,
            color: LightTheme.brandBlue,
            strokeWidth: 2.5,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Premium SliverAppBar ──────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  backgroundColor: const Color(0xFFF0F4FA),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Wallet',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: LightTheme.textPrimary,
                              letterSpacing: -0.5)),
                      Text('Parking made simple',
                          style: TextStyle(fontSize: 12, color: LightTheme.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  actions: [
                    _HistRefreshBtn(onTap: load),
                    const SizedBox(width: 16),
                  ],
                ),

                // ── Holographic 3D Balance Card ────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                    child: Container(
                      height: 190,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0038A0), Color(0xFF0072FF), Color(0xFF00D2FF)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0038A0).withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2)),
                          BoxShadow(color: const Color(0xFF0038A0).withOpacity(0.16), blurRadius: 16, offset: const Offset(0, 8)),
                          BoxShadow(color: const Color(0xFF0072FF).withOpacity(0.20), blurRadius: 36, offset: const Offset(0, 16)),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(children: [
                        // Glass waves / curves backgrounds
                        Positioned(top: -40, right: -40,
                            child: Container(height: 180, width: 180,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
                        Positioned(bottom: -60, right: 30,
                            child: Container(height: 160, width: 160,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
                        Positioned(top: 20, left: -50,
                            child: Container(height: 130, width: 130,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),

                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('AVAILABLE BALANCE'.toUpperCase(),
                                          style: TextStyle(
                                              color: Colors.white.withOpacity(0.85),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.6)),
                                      const SizedBox(height: 6),
                                      Text(
                                        _money(balance) + ' VND',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.payment_rounded, color: Colors.white.withOpacity(0.35), size: 36),
                                ],
                              ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: _CustomScaleButton(
                                  onTap: topUp,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4)
                                        )
                                      ]
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.add_rounded, color: Color(0xFF0038A0), size: 16),
                                        SizedBox(width: 6),
                                        Text('Top up wallet', style: TextStyle(color: Color(0xFF0038A0), fontWeight: FontWeight.w900, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

                // â”€â”€ Section Title: Transactions & Filter actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transactions',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightTheme.textPrimary)),
                        TextButton.icon(
                          onPressed: (transactionStart != null || transactionEnd != null)
                              ? () => setState(() { transactionStart = null; transactionEnd = null; })
                              : null,
                          style: TextButton.styleFrom(
                            foregroundColor: LightTheme.brandBlue,
                            disabledForegroundColor: LightTheme.textMuted,
                          ),
                          icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                          label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),

                // â”€â”€ Frosted Glass Pills (Date picker row) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.sm),
                    child: Row(children: [
                      Expanded(
                        child: _DatePill(
                          icon: Icons.calendar_today_rounded,
                          label: transactionStart == null ? 'From date' : '${transactionStart!.day.toString().padLeft(2,"0")}/${transactionStart!.month.toString().padLeft(2,"0")}/${transactionStart!.year}',
                          active: transactionStart != null,
                          onTap: () => _pickTransactionDate(start: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DatePill(
                          icon: Icons.event_rounded,
                          label: transactionEnd == null ? 'To date' : '${transactionEnd!.day.toString().padLeft(2,"0")}/${transactionEnd!.month.toString().padLeft(2,"0")}/${transactionEnd!.year}',
                          active: transactionEnd != null,
                          onTap: () => _pickTransactionDate(start: false),
                        ),
                      ),
                    ]),
                  ),
                ),

                // â”€â”€ Loading state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (loading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: const LinearProgressIndicator(
                            minHeight: 3, color: LightTheme.brandBlue, backgroundColor: Color(0xFFDCE5F0)),
                      ),
                    ),
                  ),

                // â”€â”€ Empty state (Artistic Widget) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (!loading && transactions.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: const _WalletEmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No transactions yet',
                      detail: 'Wallet activity will appear here.',
                    ),
                  ),
                if (!loading && transactions.isNotEmpty && visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: const _WalletEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching transactions',
                      detail: 'Try a different date range.',
                    ),
                  ),

                // â”€â”€ List of Transactions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.md, 4, AppSpace.md, AppSpace.xl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final item = visible[i];
                        return AnimatedBuilder(
                          animation: _stagger(i),
                          builder: (_, ch) => Opacity(
                            opacity: _stagger(i).value.clamp(0.0, 1.0),
                            child: Transform.translate(
                                offset: Offset(0, 20 * (1 - _stagger(i).value.clamp(0.0, 1.0))), child: ch),
                          ),
                          child: _TransactionCard(item: item),
                        );
                      },
                      childCount: visible.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SUPPORTING WIDGETS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _FastAmountChip extends StatelessWidget {
  const _FastAmountChip({required this.value, required this.selected, required this.onSelected});
  final int value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? LightTheme.brandBlue.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? LightTheme.brandBlue : const Color(0xFFCBD5E1),
              width: selected ? 1.6 : 1),
        ),
        child: Text(
          _money(value) + ' VND',
          style: TextStyle(
              color: selected ? LightTheme.brandBlue : LightTheme.textPrimary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13),
        ),
      ),
    );
  }
}

class _CustomScaleButton extends StatefulWidget {
  const _CustomScaleButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_CustomScaleButton> createState() => _CustomScaleButtonState();
}
class _CustomScaleButtonState extends State<_CustomScaleButton> {
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
        child: widget.child,
      ),
    );
  }
}

// â”€â”€ Neumorphic Empty State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WalletEmptyState extends StatelessWidget {
  const _WalletEmptyState({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Embossed Neumorphic container
            Container(
              height: 100, width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF0F4FA),
                boxShadow: [
                  BoxShadow(color: Colors.white, blurRadius: 12, offset: const Offset(-6, -6)),
                  BoxShadow(color: const Color(0xFFCBD5E1).withOpacity(0.50), blurRadius: 12, offset: const Offset(6, 6)),
                ],
              ),
              child: Center(
                child: Container(
                  height: 72, width: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.70)),
                  ),
                  child: Icon(icon, color: LightTheme.brandBlue, size: 28),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: LightTheme.textPrimary,
                    letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: LightTheme.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Transaction Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TransactionCard extends StatefulWidget {
  const _TransactionCard({required this.item});
  final Map<String, dynamic> item;
  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}
class _TransactionCardState extends State<_TransactionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final credit = ['topup', 'refund', 'credit'].contains('${item['type']}');
    final isTopUp = '${item['reason']}'.contains('topup');
    final color = isTopUp
        ? LightTheme.brandBlue
        : credit
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444);
    final bgColor = isTopUp
        ? const Color(0xFFDBEAFE)
        : credit
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2);
    final typeName = '${item['type']}'.toUpperCase();
    final desc = '${item['description'] ?? item['type'] ?? 'Transaction'}';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        margin: const EdgeInsets.only(bottom: 12),
        transform: Matrix4.identity()
          ..translate(0.0, _pressed ? 2.0 : 0.0)
          ..scale(_pressed ? 0.985 : 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: _pressed ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Circular status icon
            Container(
              height: 44, width: 44,
              decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.70),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.20))),
              child: Icon(
                credit ? Icons.add_rounded : Icons.remove_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: LightTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(typeName,
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: LightTheme.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      Text(_date(item['createdAt']),
                          style: const TextStyle(color: LightTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Money value
            Text(
              (credit ? '+' : '-') + _money(_asNum(item['amount'])) + ' VND',
              style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14, letterSpacing: -0.2),
            ),
          ]),
        ),
      ),
    );
  }
}double _asNum(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(num amount) => amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (_) => ',');
String _date(dynamic value) {
  if (value == null || '$value'.isEmpty) return '--/--/---- --:--';
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final date = parsed.toLocal();
  return date.day.toString().padLeft(2, '0') + '/' +
         date.month.toString().padLeft(2, '0') + '/' +
         date.year.toString() + ' ' +
         date.hour.toString().padLeft(2, '0') + ':' +
         date.minute.toString().padLeft(2, '0');
}
