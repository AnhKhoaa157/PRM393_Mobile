part of '../main.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key, required this.session});
  final SessionController session;
  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  List<Map<String, dynamic>> packages = [];
  List<Map<String, dynamic>> subscriptions = [];
  bool loading = true;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() => loading = true);
    try { final values = await Future.wait([widget.session.api.request('/users/long-term/packages', token: widget.session.token), widget.session.api.request('/users/long-term/subscriptions', token: widget.session.token)]); if (mounted) setState(() { packages = _items(values[0], 'packages'); subscriptions = _items(values[1]); }); }
    catch (error) { if (mounted) _snack(error); }
    if (mounted) setState(() => loading = false);
  }
  Future<void> subscribe(Map<String, dynamic> package) async {
    final plates = widget.session.user!.plates;
    if (plates.isEmpty) { _snack('Add a license plate in Profile first.'); return; }
    final plate = await showVehiclePicker(context, plates: plates, title: 'Choose a vehicle', description: 'This vehicle will be linked to the package.');
    if (plate == null) return;
    try { await widget.session.api.request('/users/long-term/subscriptions', method: 'POST', token: widget.session.token, body: {'packageId': package['_id'], 'plateNumber': plate.number}); await load(); if (mounted) _snack('Package subscription created.'); }
    catch (error) { if (mounted) _snack(error); }
  }
  Future<void> renew(Map<String, dynamic> item) async { final id = '${item['_id'] ?? ''}'; if (id.isEmpty) return; try { await widget.session.api.request('/users/long-term/subscriptions/$id/renew', method: 'POST', token: widget.session.token); await load(); if (mounted) _snack('Subscription renewed.'); } catch (error) { if (mounted) _snack(error); } }
  Future<void> cancel(Map<String, dynamic> item) async { final id = '${item['_id'] ?? ''}'; if (id.isEmpty) return; final accepted = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Cancel subscription?'), content: const Text('Your eligible refund will be calculated using the parking policy.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep it')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Cancel subscription'))])); if (accepted != true) return; try { await widget.session.api.request('/users/long-term/subscriptions/$id/cancel', method: 'POST', token: widget.session.token, body: {'cancelReason':'no_longer_needed'}); await load(); if (mounted) _snack('Subscription cancelled.'); } catch (error) { if (mounted) _snack(error); } }
  @override
  Widget build(BuildContext context) => PageFrame(title: 'Packages', actions: [IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh))], child: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
    const Text('Choose a long-term parking package for your vehicle.', style: TextStyle(color: AppColors.muted)), const SizedBox(height: AppSpace.lg), if (loading) const LinearProgressIndicator(),
    if (subscriptions.isNotEmpty) ...[const AppSectionTitle('My subscriptions'), const SizedBox(height: AppSpace.sm), ...subscriptions.map(_subscriptionCard), const SizedBox(height: AppSpace.xl)],
    const AppSectionTitle('Available packages'), const SizedBox(height: AppSpace.sm), if (!loading && packages.isEmpty) const AppEmptyState(icon: Icons.inventory_2_outlined, title: 'No packages available', detail: 'New packages will be listed here.'), ...packages.map(_packageCard),
  ])));
  Widget _subscriptionCard(Map<String, dynamic> item) { final status = '${item['status'] ?? 'unknown'}'; final package = item['package']; final name = package is Map ? package['name'] : null; final canRenew = status == 'active' || status == 'expired'; return Padding(padding: const EdgeInsets.only(bottom: AppSpace.sm), child: AppPanel(color: AppColors.successSoft, child: Row(children: [const Icon(Icons.verified_outlined, color: AppColors.success), const SizedBox(width: AppSpace.sm), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${name ?? 'Parking package'}',style:const TextStyle(fontWeight:FontWeight.w900)), const SizedBox(height:3), Text('${item['plateNumber'] ?? ''} • $status',style:const TextStyle(color:AppColors.muted))])), if (canRenew) PopupMenuButton<String>(onSelected:(value) { if(value=='renew') renew(item); if(value=='cancel') cancel(item); }, itemBuilder: (_) => [const PopupMenuItem(value:'renew',child:Text('Renew')), if(status=='active') const PopupMenuItem(value:'cancel',child:Text('Cancel'))])]))); }
  Widget _packageCard(Map<String, dynamic> item) { final description = '${item['description'] ?? ''}'.trim(); return Padding(padding: const EdgeInsets.only(bottom: AppSpace.sm), child: AppPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text('${item['name'] ?? 'Parking package'}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))), Text('${_money(_asNum(item['price']))} VND',style:const TextStyle(color:AppColors.brand,fontWeight:FontWeight.w900))]), const SizedBox(height:AppSpace.xs), AppPill('${item['durationDays'] ?? '—'} days'), if(description.isNotEmpty) Padding(padding:const EdgeInsets.only(top:AppSpace.sm), child:Text(description,style:const TextStyle(color:AppColors.muted,height:1.35))), const SizedBox(height:AppSpace.xs), Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>subscribe(item),icon:const Icon(Icons.add_circle_outline),label:const Text('Subscribe')))]))); }
  void _snack(Object value) => showAppNotice(context, value);
}
