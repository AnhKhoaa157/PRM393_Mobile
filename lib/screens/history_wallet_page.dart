part of '../main.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.session});
  final SessionController session;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> history = [];
  Set<String> reviewedSessionIds = <String>{};
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final historyResponse = await widget.session.api
          .request('/users/parking-history', token: widget.session.token);
      dynamic feedbackResponse;
      try {
        feedbackResponse = await widget.session.api
            .request('/users/feedbacks/me', token: widget.session.token);
      } catch (_) {
        // Keep parking history usable if feedback support is unavailable.
      }
      final feedbacks = feedbackResponse == null
          ? <Map<String, dynamic>>[]
          : _items(feedbackResponse);
      if (mounted) {
        setState(() {
          history = _items(historyResponse);
          reviewedSessionIds = feedbacks
              .map((feedback) {
                final session = feedback['parkingSession'];
                return session is Map
                    ? (session['_id'] ?? '').toString()
                    : (session ?? '').toString();
              })
              .where((id) => id.isNotEmpty)
              .toSet();
        });
      }
    } catch (e) {
      if (mounted) _snack(e);
    }
    if (mounted) setState(() => loading = false);
  }

  bool _canRate(Map<String, dynamic> session) {
    final id = session['_id']?.toString() ?? '';
    return session['status'] == 'completed' &&
        id.isNotEmpty &&
        !reviewedSessionIds.contains(id);
  }

  Future<void> _showFeedback(Map<String, dynamic> session) async {
    final sessionId = session['_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    var rating = 0;
    var submitting = false;
    String? error;
    final comment = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
            child: StatefulBuilder(builder: (context, setSheetState) {
              Future<void> submit() async {
                final trimmedComment = comment.text.trim();
                if (rating == 0 || trimmedComment.isEmpty) {
                  setSheetState(() {
                    error = 'Choose a rating and enter your feedback.';
                  });
                  return;
                }
                setSheetState(() {
                  submitting = true;
                  error = null;
                });
                try {
                  await widget.session.api.request('/users/feedbacks',
                      method: 'POST',
                      token: widget.session.token,
                      body: {
                        'parkingSession': sessionId,
                        'rating': rating,
                        'comment': trimmedComment,
                        if (session['building'] is Map)
                          'building': session['building']['_id'],
                      });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  setSheetState(() => error = e.toString());
                } finally {
                  if (context.mounted) setSheetState(() => submitting = false);
                }
              }

              return Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Rate your parking experience',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${session['plateNumber'] ?? 'Parking session'}',
                    style: const TextStyle(color: _muted)),
                const SizedBox(height: 18),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        5,
                        (index) => IconButton(
                            onPressed: submitting
                                ? null
                                : () => setSheetState(() => rating = index + 1),
                            iconSize: 36,
                            color: Colors.amber.shade700,
                            icon: Icon(index < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded)))),
                TextField(
                    controller: comment,
                    enabled: !submitting,
                    maxLength: 150,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        labelText: 'Your feedback',
                        hintText: 'Tell us about your parking experience')),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Later'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FilledButton(
                          onPressed: submitting ? null : submit,
                          child: submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Submit review')))
                ])
              ]);
            })));
    comment.dispose();
    if (submitted == true) {
      await load();
      if (mounted) _snack('Thank you for your feedback.');
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Parking history',
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
        child: RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (loading) const LinearProgressIndicator(),
              if (!loading && history.isEmpty)
                const _Empty(
                    icon: Icons.history_outlined,
                    text: 'No parking sessions yet.'),
              ...history.map((h) => Card(
                      child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.directions_car_outlined)),
                    title: Text(
                        '${h['plateNumber'] ?? 'Vehicle'} ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ ${h['status'] ?? ''}'),
                    subtitle: Text(
                        '${h['building'] is Map ? h['building']['name'] ?? '' : ''}\n${_date(h['entryTime'] ?? h['check_in'] ?? h['checkIn'])} → ${_date(h['exitTime'] ?? h['check_out'] ?? h['checkOut'])}'),
                    isThreeLine: true,
                    onTap: _canRate(h) ? () => _showFeedback(h) : null,
                    trailing: _canRate(h)
                        ? IconButton(
                            tooltip: 'Rate parking',
                            onPressed: () => _showFeedback(h),
                            icon: const Icon(Icons.star_outline))
                        : h['fee'] == null
                            ? null
                            : Text('${_money(_asNum(h['fee']))} VND'),
                  ))),
            ])),
      );
  void _snack(Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e.toString())));
}

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.session});
  final SessionController session;
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double balance = 0;
  List<Map<String, dynamic>> transactions = [];
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
            .request('/users/wallet', token: widget.session.token),
        widget.session.api
            .request('/users/wallet/transactions', token: widget.session.token)
      ]);
      if (mounted)
        setState(() {
          balance = _asNum(_data(rs[0])['walletBalance']);
          transactions = _items(rs[1]);
        });
    } catch (e) {
      if (mounted) _snack(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> topUp() async {
    final controller = TextEditingController(text: '50000');
    final amount = await showDialog<double>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Top up wallet'),
                content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Amount (VND)')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context,
                          double.tryParse(controller.text.replaceAll(',', ''))),
                      child: const Text('Continue'))
                ]));
    if (amount == null || amount <= 0) return;
    try {
      final r = await widget.session.api.request('/users/wallet/topup',
          method: 'POST',
          token: widget.session.token,
          body: {'amount': amount.round()});
      final data = _data(r);
      final orderCode = data['orderCode']?.toString();
      if (!mounted) return;
      final checkoutUrl = Uri.tryParse('${data['checkoutUrl'] ?? ''}');
      if (checkoutUrl != null && await canLaunchUrl(checkoutUrl)) {
        await launchUrl(checkoutUrl, mode: LaunchMode.externalApplication);
      }
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                  title: const Text('PayOS payment created'),
                  content: SelectableText(
                      'Amount: ${_money(amount)} VND\n\nOpen this payment URL in your browser:\n${data['checkoutUrl'] ?? 'Payment link unavailable'}'),
                  actions: [
                    TextButton(
                        onPressed: orderCode == null
                            ? null
                            : () async {
                                await _verifyTopUp(orderCode);
                                if (mounted) Navigator.pop(context);
                              },
                        child: const Text('I completed payment')),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> _verifyTopUp(String orderCode) async {
    try {
      final result = await widget.session.api.request(
          '/users/wallet/topup/$orderCode/status',
          token: widget.session.token);
      final data = _data(result);
      await load();
      if (mounted) {
        final status = data['status']?.toString() ?? 'pending';
        final credited = data['credited'] == true;
        _snack(credited
            ? 'Payment verified. Your wallet has been credited.'
            : 'Payment status: $status. Your balance will update when payment is confirmed.');
      }
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Wallet',
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
        child: RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                      color: _skyDark, borderRadius: BorderRadius.circular(22)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AVAILABLE BALANCE',
                            style: TextStyle(
                                color: Color(0xbbffffff),
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                        const SizedBox(height: 5),
                        Text('${_money(balance)} VND',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 29,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                            onPressed: topUp,
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _skyDark),
                            icon: const Icon(Icons.add),
                            label: const Text('Top up')),
                      ])),
              const SizedBox(height: 22),
              const Text('Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              if (loading) const LinearProgressIndicator(),
              if (!loading && transactions.isEmpty)
                const _Empty(
                    icon: Icons.receipt_long_outlined,
                    text: 'No transactions yet.'),
              ...transactions.map((t) {
                final credit =
                    ['topup', 'refund', 'credit'].contains(t['type']);
                return Card(
                    child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor:
                                (credit ? Colors.green : Colors.red)
                                    .withValues(alpha: .12),
                            child: Icon(credit ? Icons.add : Icons.remove,
                                color: credit ? Colors.green : Colors.red)),
                        title: Text(
                            '${t['description'] ?? t['type'] ?? 'Transaction'}'),
                        subtitle: Text(_date(t['createdAt'])),
                        trailing: Text(
                            '${credit ? '+' : '-'}${_money(_asNum(t['amount']))} VND',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: credit ? Colors.green : Colors.red))));
              }),
            ])),
      );
  void _snack(Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e.toString())));
}
