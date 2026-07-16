part of '../main.dart';

const _incidentTypes = [
  (value: 'slot_occupied', label: 'Slot occupied by someone else', icon: Icons.directions_car_outlined),
  (value: 'slot_blocked', label: 'Slot blocked or obstructed', icon: Icons.block),
  (value: 'vehicle_damaged', label: 'Vehicle damaged or scratched', icon: Icons.car_crash_outlined),
  (value: 'facility_issue', label: 'Facility issue (lights, floors...)', icon: Icons.build_outlined),
  (value: 'wrong_scan', label: 'Incorrect license plate scan', icon: Icons.qr_code_scanner),
  (value: 'payment_dispute', label: 'Payment or fee dispute', icon: Icons.receipt_long_outlined),
  (value: 'lost_ticket', label: 'Lost parking ticket / QR code', icon: Icons.confirmation_number_outlined),
  (value: 'security', label: 'Security (suspicious activity)', icon: Icons.shield_outlined),
  (value: 'other', label: 'Other general incident', icon: Icons.help_outline),
];

String _incidentTypeLabel(String value) {
  for (final type in _incidentTypes) {
    if (type.value == value) return type.label;
  }
  return value;
}

class IncidentPage extends StatefulWidget {
  const IncidentPage({super.key, required this.session});
  final SessionController session;

  @override
  State<IncidentPage> createState() => _IncidentPageState();
}

class _IncidentPageState extends State<IncidentPage> {
  int tab = 0;
  String selectedType = _incidentTypes.first.value;
  String? selectedBuildingId;
  final targetController = TextEditingController();
  final noteController = TextEditingController();
  bool submitting = false;

  List<Map<String, dynamic>> buildings = [];
  List<Map<String, dynamic>> tickets = [];
  bool ticketsLoading = false;
  bool ticketsLoaded = false;
  String? ticketsError;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  @override
  void dispose() {
    targetController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    try {
      final response = await widget.session.api
          .request('/users/buildings', token: widget.session.token);
      if (mounted) {
        setState(() => buildings = _items(response)
            .where((building) => '${building['_id'] ?? ''}'.isNotEmpty)
            .toList());
      }
    } catch (_) {}
  }

  Future<void> loadTickets() async {
    setState(() {
      ticketsLoading = true;
      ticketsError = null;
    });
    try {
      final response = await widget.session.api
          .request('/users/incidents/me', token: widget.session.token);
      if (mounted) {
        setState(() {
          tickets = _ticketItems(response);
          ticketsLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => ticketsError = '$error');
    }
    if (mounted) setState(() => ticketsLoading = false);
  }

  List<Map<String, dynamic>> _ticketItems(dynamic response) {
    final data = _map(response)?['data'];
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final items = _items(response);
    return items.isNotEmpty ? items : _items(response, 'incidents');
  }

  void _openTab(int index) {
    setState(() => tab = index);
    if (index == 1 && !ticketsLoaded && !ticketsLoading) loadTickets();
  }

  Future<void> submit() async {
    final note = noteController.text.trim();
    if (note.isEmpty) {
      showAppNotice(context, 'Describe what happened before submitting the report.');
      return;
    }
    setState(() => submitting = true);
    try {
      final body = <String, dynamic>{'type': selectedType, 'note': note};
      final target = targetController.text.trim();
      if (target.isNotEmpty) body['target'] = target;
      if (selectedBuildingId != null) body['buildingId'] = selectedBuildingId;
      await widget.session.api.request('/users/incidents',
          method: 'POST', token: widget.session.token, body: body);
      if (!mounted) return;
      showAppNotice(context, 'Your report was sent to the building security crew.',
          tone: AppNoticeTone.success);
      noteController.clear();
      targetController.clear();
      setState(() {
        selectedType = _incidentTypes.first.value;
        ticketsLoaded = false;
      });
      _openTab(1);
    } catch (error) {
      if (mounted) {
        final buildingRequired =
            (error is ApiException && error.code == 'BUILDING_REQUIRED') ||
                '$error'.contains('BUILDING_REQUIRED');
        showAppNotice(
            context,
            buildingRequired
                ? 'Select a building so the security team knows where the incident happened.'
                : error);
      }
    }
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Incident reports',
      actions: [
        if (tab == 1)
          IconButton(
              tooltip: 'Refresh tickets',
              onPressed: ticketsLoading ? null : loadTickets,
              icon: const Icon(Icons.refresh))
      ],
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
                    child: _tabs()),
                Expanded(child: tab == 0 ? _reportTab() : _ticketsTab()),
              ]))));

  Widget _tabs() => Container(
      padding: const EdgeInsets.all(AppSpace.xxs),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        _tabButton(0, Icons.edit_note, 'Report issue'),
        const SizedBox(width: AppSpace.xxs),
        _tabButton(1, Icons.confirmation_number_outlined, 'My tickets'),
      ]));

  Widget _tabButton(int index, IconData icon, String label) {
    final active = tab == index;
    return Expanded(
        child: Semantics(
            button: true,
            selected: active,
            label: label,
            child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => _openTab(index),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                    decoration: BoxDecoration(
                        color: active ? AppColors.brand : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 18, color: active ? Colors.white : AppColors.muted),
                      const SizedBox(width: AppSpace.xs),
                      Text(label,
                          style: TextStyle(
                              color: active ? Colors.white : AppColors.muted,
                              fontWeight: FontWeight.w800))
                    ])))));
  }

  Widget _reportTab() => ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
        const Text(
            'Tell the building security crew what went wrong. They will follow up on your ticket.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: AppSpace.md),
        AppPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Incident type'),
          const SizedBox(height: AppSpace.xs),
          ..._incidentTypes.map(_typeOption),
          const SizedBox(height: AppSpace.md),
          const _FieldLabel('Building'),
          const SizedBox(height: AppSpace.xs),
          _buildingSelector(),
          const SizedBox(height: AppSpace.md),
          const _FieldLabel('Related plate / slot code (optional)'),
          const SizedBox(height: AppSpace.xs),
          TextField(
              controller: targetController,
              maxLength: 40,
              decoration: const InputDecoration(
                  hintText: 'E.g. 59G2-038.80 or Slot A-05', counterText: '')),
          const SizedBox(height: AppSpace.md),
          const _FieldLabel('Detailed description'),
          const SizedBox(height: AppSpace.xs),
          TextField(
              controller: noteController,
              maxLength: 500,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                  hintText: 'Describe what happened in detail...')),
          const SizedBox(height: AppSpace.md),
          FilledButton.icon(
              onPressed: submitting ? null : submit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: Text(submitting ? 'Submitting...' : 'Submit report')),
        ])),
        const SizedBox(height: AppSpace.xl),
      ]);

  Widget _typeOption(({String value, String label, IconData icon}) type) {
    final active = selectedType == type.value;
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.xxs),
        child: Semantics(
            button: true,
            selected: active,
            label: type.label,
            child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => setState(() => selectedType = type.value),
                child: Ink(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm, vertical: AppSpace.sm),
                    decoration: BoxDecoration(
                        color: active ? AppColors.brandSoft : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                            color: active ? AppColors.brand : AppColors.border)),
                    child: Row(children: [
                      Icon(type.icon,
                          size: 20, color: active ? AppColors.brand : AppColors.muted),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                          child: Text(type.label,
                              style: TextStyle(
                                  color: active ? AppColors.brand : AppColors.foreground,
                                  fontWeight: active ? FontWeight.w800 : FontWeight.w600))),
                      Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18, color: active ? AppColors.brand : AppColors.muted)
                    ])))));
  }

  Widget _buildingSelector() => DropdownButtonFormField<String>(
      initialValue: selectedBuildingId,
      isExpanded: true,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.business_outlined)),
      items: [
        const DropdownMenuItem<String>(
            value: null, child: Text('Auto-detect from my subscription or session')),
        ...buildings.map((building) => DropdownMenuItem<String>(
            value: '${building['_id']}',
            child: Text('${building['name'] ?? building['code'] ?? 'Building'}',
                overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (value) => setState(() => selectedBuildingId = value));

  Widget _ticketsTab() => RefreshIndicator(
      onRefresh: loadTickets,
      child: ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
        if (ticketsLoading) const LinearProgressIndicator(),
        if (ticketsLoading) const SizedBox(height: AppSpace.lg),
        if (!ticketsLoading && ticketsError != null)
          AppPanel(
              color: AppColors.dangerSoft,
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                    child: Text(ticketsError!,
                        style: const TextStyle(
                            color: AppColors.danger, fontWeight: FontWeight.w600))),
                TextButton(onPressed: loadTickets, child: const Text('Retry')),
              ])),
        if (!ticketsLoading && ticketsError == null && tickets.isEmpty)
          const AppEmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'No tickets yet',
              detail: 'Reports you submit will show up here with their status.'),
        ...tickets.map(_ticketCard),
        const SizedBox(height: AppSpace.xl),
      ]));

  (Color, Color) _statusStyle(String status) => switch (status) {
        'open' => (AppColors.warning, AppColors.warningSoft),
        'investigating' || 'escalated' => (AppColors.brand, AppColors.brandSoft),
        'resolved' => (AppColors.success, AppColors.successSoft),
        _ => (AppColors.muted, AppColors.surfaceMuted),
      };

  Widget _ticketCard(Map<String, dynamic> ticket) {
    final status = '${ticket['status'] ?? 'open'}'.toLowerCase();
    final (statusColor, statusSoft) = _statusStyle(status);
    final building = ticket['building'] is Map
        ? '${ticket['building']['name'] ?? ticket['building']['code'] ?? ''}'
        : '';
    final target = '${ticket['target'] ?? ''}'.trim();
    final note = '${ticket['note'] ?? ''}'.trim();
    final resolution = '${ticket['resolutionNote'] ?? ''}'.trim();
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: AppPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('${ticket['code'] ?? 'TICKET'}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            AppPill(status.toUpperCase(), color: statusSoft, foreground: statusColor),
          ]),
          const SizedBox(height: AppSpace.xs),
          Text(_incidentTypeLabel('${ticket['type'] ?? ''}'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          if (building.isNotEmpty || target.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xxs),
            Wrap(spacing: AppSpace.md, runSpacing: AppSpace.xxs, children: [
              if (building.isNotEmpty) _metaRow(Icons.business_outlined, building),
              if (target.isNotEmpty) _metaRow(Icons.tag, target),
            ]),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSpace.xs),
            Text(note, style: const TextStyle(color: AppColors.muted, height: 1.35)),
          ],
          const SizedBox(height: AppSpace.xs),
          _metaRow(Icons.schedule_outlined, 'Reported ${_date(ticket['createdAt'])}'),
          if (resolution.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: const Color(0x330c8f62))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _FieldLabel('Security response'),
                  const SizedBox(height: AppSpace.xxs),
                  Text(resolution,
                      style: const TextStyle(color: AppColors.foreground, height: 1.35)),
                ])),
          ],
        ])));
  }

  Widget _metaRow(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: AppSpace.xxs),
        Text(text,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .6));
}
