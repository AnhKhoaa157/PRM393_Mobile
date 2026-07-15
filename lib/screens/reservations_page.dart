part of '../main.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key, required this.session});
  final SessionController session;
  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  List<Map<String, dynamic>> reservations = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await widget.session.api
          .request('/users/reservations', token: widget.session.token);
      if (mounted) setState(() => reservations = _items(response));
    } catch (e) {
      if (mounted) _snack(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> cancel(String id) async {
    try {
      await widget.session.api.request('/users/reservations/$id',
          method: 'DELETE', token: widget.session.token);
      await load();
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Reservations',
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      child: RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ReservationForm(session: widget.session)));
                  load();
                },
                icon: const Icon(Icons.add),
                label: const Text('New reservation')),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (!loading && reservations.isEmpty)
              const _Empty(
                  icon: Icons.event_available_outlined,
                  text: 'No reservations yet.'),
            ...reservations.map((r) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    (r['building'] is Map
                                            ? r['building']['name']
                                            : null) ??
                                        'Parking reservation',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            _status(r['status'])
                          ]),
                          const SizedBox(height: 7),
                          Text(
                              'Plate: ${r['plateNumber'] ?? 'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â'}'),
                          Text('Start: ${_date(r['startTime'])}'),
                          if (r['endTime'] != null)
                            Text('End: ${_date(r['endTime'])}'),
                          if (['pending', 'confirmed'].contains(r['status']))
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                    onPressed: () => _confirmCancel(r),
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text('Cancel'))),
                        ])))),
          ])));
  Widget _status(dynamic value) => Chip(
      label: Text((value ?? 'pending').toString()),
      visualDensity: VisualDensity.compact);
  Future<void> _confirmCancel(Map<String, dynamic> r) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Cancel reservation?'),
                content: const Text(
                    'The refund is calculated by the parking policy.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Cancel'))
                ]));
    if (yes == true) cancel('${r['_id']}');
  }

  void _snack(Object e) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e.toString())));
}

class ReservationForm extends StatefulWidget {
  const ReservationForm({super.key, required this.session});
  final SessionController session;
  @override
  State<ReservationForm> createState() => _ReservationFormState();
}

class _ReservationFormState extends State<ReservationForm> {
  List<Map<String, dynamic>> buildings = [],
      types = [],
      floors = [],
      slots = [];
  String? buildingId, typeId, plate, floorId, slotId;
  DateTime start = DateTime.now().add(const Duration(hours: 1));
  DateTime end = DateTime.now().add(const Duration(hours: 2));
  bool loading = true, submitting = false;
  Map<String, dynamic>? estimate, policy;
  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    try {
      final r = await widget.session.api
          .request('/users/buildings', token: widget.session.token);
      buildings = _items(r);
      if (buildings.isNotEmpty)
        await _setBuilding(buildings.first['_id'].toString());
    } catch (e) {
      if (mounted) _snack(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _setBuilding(String id) async {
    setState(() {
      buildingId = id;
      typeId = null;
      types = [];
      estimate = null;
      floors = [];
      slots = [];
      floorId = null;
      slotId = null;
      policy = null;
    });
    try {
      final r = await widget.session.api.request(
          '/users/buildings/$id/vehicle-types',
          token: widget.session.token);
      if (mounted)
        setState(() {
          types = _items(r);
          if (types.isNotEmpty) typeId = types.first['_id'].toString();
        });
      final extras = await Future.wait([
        widget.session.api.request('/users/reservations/policy?buildingId=$id',
            token: widget.session.token),
        widget.session.api.request(
            '/users/buildings/$id/floors?vehicleTypeId=${typeId ?? ''}',
            token: widget.session.token),
      ]);
      if (mounted)
        setState(() {
          policy = _data(extras[0]);
          floors = (_data(extras[1])['floors'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      await _estimate();
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> _setFloor(String id) async {
    if (buildingId == null) return;
    setState(() {
      floorId = id;
      slotId = null;
      slots = [];
    });
    try {
      final r = await widget.session.api.request(
          '/users/buildings/$buildingId/floors/$id/slots',
          token: widget.session.token);
      if (mounted)
        setState(() => slots = (_data(r)['slots'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> _estimate() async {
    if (buildingId == null || typeId == null) return;
    final query = Uri(queryParameters: {
      'buildingId': buildingId!,
      'vehicleTypeId': typeId!,
      'startTime': start.toIso8601String(),
      'endTime': end.toIso8601String()
    }).query;
    try {
      final r = await widget.session.api.request(
          '/users/reservations/estimate?$query',
          token: widget.session.token);
      if (mounted) setState(() => estimate = _data(r));
    } catch (_) {}
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: isStart ? start : end,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked == null) return;
    final now = isStart ? start : end;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;
    final date =
        DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        start = date;
        if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
      } else {
        end = date;
      }
    });
    await _estimate();
  }

  Future<void> _submit() async {
    if (buildingId == null ||
        typeId == null ||
        plate == null ||
        plate!.isEmpty) {
      _snack('Select a building, vehicle type, and license plate.');
      return;
    }
    if (!end.isAfter(start)) {
      _snack('End time must be after start time.');
      return;
    }
    if (end.difference(start).inMinutes % 60 != 0) {
      _snack('Reservation duration must be a whole number of hours.');
      return;
    }
    if (policy?['isActive'] == false ||
        (start.isAfter(DateTime.now().add(
                Duration(days: _asNum(policy?['maxAdvanceDays']).toInt()))) ||
            end.difference(start).inHours >
                _asNum(policy?['maxDurationHours']).toInt())) {
      _snack(
          'The selected time does not comply with this building\'s reservation policy.');
      return;
    }
    setState(() => submitting = true);
    try {
      await widget.session.api.request('/users/reservations',
          method: 'POST',
          token: widget.session.token,
          body: {
            'buildingId': buildingId,
            'vehicleTypeId': typeId,
            'plateNumber': plate,
            'startTime': start.toIso8601String(),
            'endTime': end.toIso8601String(),
            if (slotId != null) 'slotId': slotId,
          });
      if (mounted) {
        _snack('Reservation created successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack(e);
    }
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('New reservation')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Choose where and when you would like to park.',
                  style: TextStyle(color: _muted)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                  value: buildingId,
                  decoration: const InputDecoration(labelText: 'Building'),
                  items: buildings
                      .map((b) => DropdownMenuItem(
                          value: '${b['_id']}',
                          child: Text('${b['name'] ?? b['code']}')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _setBuilding(v);
                  }),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                  value: typeId,
                  decoration: const InputDecoration(labelText: 'Vehicle type'),
                  items: types
                      .map((t) => DropdownMenuItem(
                          value: '${t['_id']}',
                          child: Text('${t['name'] ?? t['code']}')))
                      .toList(),
                  onChanged: (v) {
                    setState(() => typeId = v);
                    _estimate();
                  }),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                  value: plate,
                  decoration: const InputDecoration(labelText: 'License plate'),
                  items: widget.session.user!.plates
                      .map((p) => DropdownMenuItem(
                          value: p.number,
                          child: Text('${p.number} (${p.type})')))
                      .toList(),
                  onChanged: (v) => setState(() => plate = v)),
              const SizedBox(height: 14),
              if (floors.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                    value: floorId,
                    decoration:
                        const InputDecoration(labelText: 'Optional floor'),
                    items: floors
                        .map((f) => DropdownMenuItem(
                            value: '${f['_id']}',
                            child: Text(
                                '${f['name'] ?? f['code']} • ${f['availableSlots'] ?? 0} free')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _setFloor(v);
                    }),
                const SizedBox(height: 14),
              ],
              if (slots.isNotEmpty)
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: slots
                        .where((s) => s['selectable'] == true)
                        .map((s) => ChoiceChip(
                            label: Text('${s['code']}'),
                            selected: slotId == '${s['_id']}',
                            onSelected: (_) =>
                                setState(() => slotId = '${s['_id']}')))
                        .toList()),
              if (policy != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                        'Policy: up to ${policy!['maxDurationHours']} hours; book ${policy!['maxAdvanceDays']} days ahead.',
                        style: const TextStyle(color: _muted, fontSize: 12))),
              const SizedBox(height: 14),
              _dateField('Start time', start, () => _pick(true)),
              const SizedBox(height: 12),
              _dateField('End time', end, () => _pick(false)),
              const SizedBox(height: 18),
              if (estimate != null)
                Card(
                    color: const Color(0xfff0f9ff),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fee estimate',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                  'Estimated fee: ${_money(_asNum(estimate!['estimatedFee']))} VND'),
                              Text(
                                  'Deposit due now: ${_money(_asNum(estimate!['depositAmount']))} VND'),
                              Text(
                                  'Remaining payment: ${_money(_asNum(estimate!['remainingFee']))} VND')
                            ]))),
              const SizedBox(height: 18),
              FilledButton(
                  onPressed: submitting ? null : _submit,
                  style:
                      FilledButton.styleFrom(padding: const EdgeInsets.all(17)),
                  child: submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Confirm reservation')),
            ]));
  Widget _dateField(String label, DateTime value, VoidCallback press) =>
      InkWell(
          onTap: press,
          child: InputDecorator(
              decoration: InputDecoration(
                  labelText: label,
                  suffixIcon: const Icon(Icons.calendar_today_outlined)),
              child: Text(_date(value))));
  void _snack(Object e) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
}
