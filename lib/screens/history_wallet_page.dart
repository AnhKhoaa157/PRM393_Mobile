part of '../main.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.session});
  final SessionController session;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> history = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final r = await widget.session.api
          .request('/users/parking-history', token: widget.session.token);
      if (mounted) setState(() => history = _items(r));
    } catch (e) {
      if (mounted) _snack(e);
    }
    if (mounted) setState(() => loading = false);
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
                    trailing: h['fee'] == null
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
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
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
