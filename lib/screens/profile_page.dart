part of '../main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session});
  final SessionController session;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool busy = false;
  Future<void> _addPlate() async {
    final number = TextEditingController();
    String type = 'car';
    final input = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
                    title: const Text('Add license plate'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: number,
                          textCapitalization: TextCapitalization.characters,
                          decoration:
                              const InputDecoration(labelText: 'Plate number')),
                      DropdownButtonFormField(
                          value: type,
                          items: const [
                            DropdownMenuItem(value: 'car', child: Text('Car')),
                            DropdownMenuItem(
                                value: 'motorcycle', child: Text('Motorcycle'))
                          ],
                          onChanged: (v) => setLocal(() => type = v!))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(
                              context, {'number': number.text, 'type': type}),
                          child: const Text('Add'))
                    ])));
    if (input == null || input['number']!.trim().isEmpty) return;
    try {
      await widget.session.api.request('/users/license-plates',
          method: 'POST',
          token: widget.session.token,
          body: {
            'plateNumber': input['number']!.trim().toUpperCase(),
            'vehicleType': input['type']
          });
      await widget.session.reloadProfile();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> _removePlate(Plate p) async {
    try {
      await widget.session.api.request('/users/license-plates/${p.id}',
          method: 'DELETE', token: widget.session.token);
      await widget.session.reloadProfile();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> _setDefaultPlate(Plate p) async {
    if (p.isDefault) return;
    try {
      await widget.session.api.request('/users/license-plates/${p.id}/default',
          method: 'PATCH', token: widget.session.token);
      await widget.session.reloadProfile();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: widget.session.user!.name);
    final phone = TextEditingController(text: widget.session.user!.phone);
    final save = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Edit profile'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Full name')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'Phone'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save'))
                ]));
    if (save != true) return;
    try {
      await widget.session.api.request('/users/profile',
          method: 'PUT',
          token: widget.session.token,
          body: {'fullName': name.text.trim(), 'phone': phone.text.trim()});
      await widget.session.reloadProfile();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  Future<void> _password() async {
    final old = TextEditingController();
    final next = TextEditingController();
    final save = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Change password'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: old,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Current password')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: next,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'New password'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Update'))
                ]));
    if (save != true) return;
    try {
      await widget.session.api.request('/users/profile/password',
          method: 'PUT',
          token: widget.session.token,
          body: {'currentPassword': old.text, 'newPassword': next.text});
      if (mounted) _snack('Password updated.');
    } catch (e) {
      if (mounted) _snack(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.session.user!;
    return PageFrame(
        title: 'Profile',
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
              child: ListTile(
                  leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: _sky.withValues(alpha: .15),
                      child: Text(
                          u.name.isEmpty
                              ? 'U'
                              : u.name.substring(0, 1).toUpperCase(),
                          style:
                              const TextStyle(fontSize: 24, color: _skyDark))),
                  title: Text(u.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                   subtitle: Text(
                      "${u.email}\n${u.phone.isEmpty ? 'No phone number' : u.phone}"),
                  isThreeLine: true,
                  trailing: IconButton(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined)))),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(
                child: Text('License plates',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            TextButton.icon(
                onPressed: _addPlate,
                icon: const Icon(Icons.add),
                label: const Text('Add'))
          ]),
          if (u.plates.isEmpty)
            const _Empty(
                icon: Icons.directions_car_outlined,
                text: 'No license plates added.'),
          ...u.plates.map((p) => Card(
              child: ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.directions_car_outlined)),
                  title: Text(p.number,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle:
                      Text(p.isDefault ? "${p.type} • Default" : p.type),
                  /* legacy text with invalid nested quotes:
                  subtitle: Text(
                      '${p.type}${p.isDefault ? ' ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ Default' : ''}'),
                  */
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                     if (!p.isDefault)
                       IconButton(
                           tooltip: 'Set as default',
                           onPressed: () => _setDefaultPlate(p),
                           icon: const Icon(Icons.star_outline)),
                     IconButton(
                         onPressed: () => _removePlate(p),
                         icon: const Icon(Icons.delete_outline),
                         color: Colors.red)
                    ])))),
          const SizedBox(height: 18),
          const Text('Security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _password)),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign out',
                      style: TextStyle(color: Colors.red)),
                  onTap: widget.session.logout))
        ]));
  }

  void _snack(Object e) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 38),
      child: Center(
          child: Column(children: [
        Icon(icon, size: 48, color: _muted),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(color: _muted))
      ])));
}

double _asNum(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(num amount) => amount
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'(?<!^)(?=(\d{3})+$)'), (_) => ',');
String _date(dynamic value) {
  if (value == null || '$value'.isEmpty) return 'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â';
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  final d = parsed.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
