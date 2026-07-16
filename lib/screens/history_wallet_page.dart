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
  void initState() { super.initState(); load(); }

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
    if (mounted) setState(() => loading = false);
  }

  bool _canRate(Map<String, dynamic> item) => item['status'] == 'completed' &&
      '${item['_id'] ?? ''}'.isNotEmpty && !reviewedSessionIds.contains('${item['_id']}');

  Future<void> _showFeedback(Map<String, dynamic> session) async {
    final sessionId = '${session['_id'] ?? ''}';
    if (sessionId.isEmpty) return;
    var rating = 0;
    var submitting = false;
    String? error;
    final comment = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
        context: context, isScrollControlled: true, showDragHandle: true,
        builder: (sheetContext) => Padding(
            padding: EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpace.lg),
            child: StatefulBuilder(builder: (context, setSheetState) {
              Future<void> submit() async {
                if (rating == 0 || comment.text.trim().isEmpty) {
                  setSheetState(() => error = 'Choose a rating and add a short comment.');
                  return;
                }
                setSheetState(() { submitting = true; error = null; });
                try {
                  await widget.session.api.request('/users/feedbacks', method: 'POST', token: widget.session.token, body: {
                    'parkingSession': sessionId, 'rating': rating, 'comment': comment.text.trim(),
                    if (session['building'] is Map) 'building': session['building']['_id'],
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (value) { setSheetState(() => error = value.toString()); }
                finally { if (context.mounted) setSheetState(() => submitting = false); }
              }
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Rate your experience', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: AppSpace.xs),
                Text('${session['plateNumber'] ?? 'Parking session'}', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: AppSpace.md),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) => IconButton(
                    tooltip: '${index + 1} stars', onPressed: submitting ? null : () => setSheetState(() => rating = index + 1), iconSize: 36,
                    color: AppColors.warning, icon: Icon(index < rating ? Icons.star_rounded : Icons.star_outline_rounded)))),
                TextField(controller: comment, enabled: !submitting, maxLength: 150, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Your feedback', hintText: 'Tell us what went well or could improve')),
                if (error != null) Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: Text(error!, style: const TextStyle(color: AppColors.danger))),
                const SizedBox(height: AppSpace.sm),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: submitting ? null : () => Navigator.pop(context), child: const Text('Later'))),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: FilledButton(onPressed: submitting ? null : submit, child: submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Submit review'))),
                ])
              ]);
            })));
    comment.dispose();
    if (submitted == true) { await load(); if (mounted) _snack('Thank you for your feedback.'); }
  }

  @override
  Widget build(BuildContext context) => PageFrame(title: 'Parking history', actions: [IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh))], child: RefreshIndicator(
      onRefresh: load, child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
        const Text('Your completed parking sessions and receipts.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: AppSpace.lg),
        if (loading) const LinearProgressIndicator(),
        if (!loading && history.isEmpty) const AppEmptyState(icon: Icons.history_outlined, title: 'No parking history', detail: 'Completed parking sessions will appear here.'),
        ...history.map(_historyCard),
      ])));

  Widget _historyCard(Map<String, dynamic> item) {
    final canRate = _canRate(item);
    final building = item['building'] is Map ? item['building']['name'] : null;
    return Padding(padding: const EdgeInsets.only(bottom: AppSpace.sm), child: AppPanel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 44, width: 44, decoration: const BoxDecoration(color: AppColors.brandSoft, shape: BoxShape.circle), child: const Icon(Icons.directions_car_outlined, color: AppColors.brand)),
      const SizedBox(width: AppSpace.sm),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${item['plateNumber'] ?? 'Vehicle'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), AppPill('${item['status'] ?? 'unknown'}', color: AppColors.surfaceMuted, foreground: AppColors.muted)]),
        const SizedBox(height: AppSpace.xxs), Text('${building ?? 'Parking location'}', style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: AppSpace.xxs), Text('${_date(item['entryTime'] ?? item['check_in'] ?? item['checkIn'])} to ${_date(item['exitTime'] ?? item['check_out'] ?? item['checkOut'])}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        if (canRate) Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: TextButton.icon(onPressed: () => _showFeedback(item), icon: const Icon(Icons.star_outline, size: 18), label: const Text('Rate this visit'))),
      ])),
      if (item['fee'] != null) Padding(padding: const EdgeInsets.only(left: AppSpace.xs), child: Text('${_money(_asNum(item['fee']))} VND', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w900))),
    ])));
  }
  void _snack(Object value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value.toString())));
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
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([widget.session.api.request('/users/wallet', token: widget.session.token), widget.session.api.request('/users/wallet/transactions', token: widget.session.token)]);
      if (mounted) setState(() { balance = _asNum(_data(values[0])['walletBalance']); transactions = _items(values[1]); });
    } catch (error) { if (mounted) _snack(error); }
    if (mounted) setState(() => loading = false);
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
              if (value == null || value <= 0) {
                setDialogState(() => error = 'Enter a valid amount greater than 0.');
                return;
              }
              Navigator.pop(dialogContext, value);
            }

            return Dialog(
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
                                    height: 46,
                                    width: 46,
                                    decoration: const BoxDecoration(
                                        color: AppColors.brandSoft,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.account_balance_wallet_outlined,
                                        color: AppColors.brand)),
                                const SizedBox(width: AppSpace.sm),
                                const Expanded(
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Top up wallet',
                                              style: TextStyle(
                                                  fontSize: 23,
                                                  fontWeight: FontWeight.w900)),
                                          Text('Choose the amount to add',
                                              style: TextStyle(color: AppColors.muted))
                                        ])),
                                IconButton(
                                    tooltip: 'Close',
                                    onPressed: () => Navigator.pop(dialogContext),
                                    icon: const Icon(Icons.close))
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
                                  decoration: const InputDecoration(
                                      labelText: 'Amount (VND)',
                                      prefixIcon: Icon(Icons.payments_outlined),
                                      suffixText: 'VND')),
                              const SizedBox(height: AppSpace.sm),
                              Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                                for (final value in [50000, 100000, 200000, 500000])
                                  ChoiceChip(
                                      label: Text('${_money(value)} VND'),
                                      selected: controller.text == '$value',
                                      onSelected: (_) => setDialogState(() {
                                            controller.text = '$value';
                                            error = null;
                                          }))
                              ]),
                              if (error != null) ...[
                                const SizedBox(height: AppSpace.sm),
                                Text(error!, style: const TextStyle(color: AppColors.danger))
                              ],
                              const SizedBox(height: AppSpace.md),
                              Container(
                                  padding: const EdgeInsets.all(AppSpace.sm),
                                  decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  child: const Row(children: [
                                    Icon(Icons.info_outline, color: AppColors.muted, size: 19),
                                    SizedBox(width: AppSpace.xs),
                                    Expanded(
                                        child: Text('You will complete payment securely in your browser.',
                                            style: TextStyle(color: AppColors.muted, fontSize: 12)))
                                  ])),
                              const SizedBox(height: AppSpace.lg),
                              FilledButton.icon(
                                  onPressed: continuePayment,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('Continue to payment')),
                              const SizedBox(height: AppSpace.xs),
                              TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'))
                            ]))));
          });
        });
    controller.dispose();
    if (amount == null || amount <= 0) return;
    try {
      final result = await widget.session.api.request('/users/wallet/topup', method: 'POST', token: widget.session.token, body: {'amount': amount.round()});
      final data = _data(result); final orderCode = '${data['orderCode'] ?? ''}'; final url = Uri.tryParse('${data['checkoutUrl'] ?? ''}');
      if (!mounted) return;
      if (url != null && await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Payment created'), content: SelectableText('Amount: ${_money(amount)} VND\n\nComplete payment in the opened browser, then return here to verify it.'), actions: [TextButton(onPressed: orderCode.isEmpty ? null : () async { await _verifyTopUp(orderCode); if (mounted) Navigator.pop(context); }, child: const Text('I completed payment')), TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
    } catch (error) { if (mounted) _snack(error); }
  }
  Future<void> _verifyTopUp(String orderCode) async {
    try { final result = await widget.session.api.request('/users/wallet/topup/$orderCode/status', token: widget.session.token); await load(); if (mounted) { final data = _data(result); _snack(data['credited'] == true ? 'Payment verified. Your wallet has been credited.' : 'Payment status: ${data['status'] ?? 'pending'}.'); } } catch (error) { if (mounted) _snack(error); }
  }
  @override
  Widget build(BuildContext context) => PageFrame(title: 'Wallet', actions: [IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh))], child: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
    Container(padding: const EdgeInsets.all(AppSpace.lg), decoration: BoxDecoration(color: AppColors.brandDeep, borderRadius: BorderRadius.circular(AppRadius.lg), gradient: const LinearGradient(colors: [AppColors.brandDeep, AppColors.brand])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('AVAILABLE BALANCE', style: TextStyle(color: Color(0xccffffff), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)), const SizedBox(height: AppSpace.xs), Text('${_money(balance)} VND', style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)), const SizedBox(height: AppSpace.md), OutlinedButton.icon(onPressed: topUp, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)), icon: const Icon(Icons.add_circle_outline), label: const Text('Top up wallet'))])),
    const SizedBox(height: AppSpace.xl), const AppSectionTitle('Transactions'), const SizedBox(height: AppSpace.sm), if (loading) const LinearProgressIndicator(), if (!loading && transactions.isEmpty) const AppEmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions yet', detail: 'Wallet activity will appear here.'), ...transactions.map(_transactionCard),
  ])));
  Widget _transactionCard(Map<String, dynamic> item) { final credit = ['topup','refund','credit'].contains('${item['type']}'); final color = credit ? AppColors.success : AppColors.danger; return Padding(padding: const EdgeInsets.only(bottom: AppSpace.sm), child: AppPanel(child: ListTile(contentPadding: EdgeInsets.zero, leading: Container(height: 42,width:42,decoration: BoxDecoration(color: color.withValues(alpha:.12),shape:BoxShape.circle),child: Icon(credit ? Icons.add : Icons.remove,color:color)), title: Text('${item['description'] ?? item['type'] ?? 'Transaction'}',style:const TextStyle(fontWeight:FontWeight.w800)), subtitle: Text(_date(item['createdAt'])), trailing: Text('${credit?'+':'-'}${_money(_asNum(item['amount']))} VND',style:TextStyle(fontWeight:FontWeight.w900,color:color))))); }
  void _snack(Object value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value.toString())));
}

double _asNum(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(num amount) => amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (_) => ',');
String _date(dynamic value) { if (value == null || '$value'.isEmpty) return '—'; final parsed = DateTime.tryParse('$value'); if (parsed == null) return '$value'; final date = parsed.toLocal(); return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'; }
