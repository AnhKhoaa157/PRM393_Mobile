part of '../main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session});
  final SessionController session;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _maxPlates = 5;

  Future<void> _addPlate() async {
    if (widget.session.user!.plates.length >= _maxPlates) {
      showAppNotice(context, 'You can add up to $_maxPlates vehicles only.',
          tone: AppNoticeTone.info);
      return;
    }
    final number = TextEditingController();
    try {
      String type = 'car';
      String? formError;
      final input = await showDialog<Map<String, String>>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => Dialog(
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
                                      child: const Icon(
                                          Icons.directions_car_outlined,
                                          color: AppColors.brand)),
                                  const SizedBox(width: AppSpace.sm),
                                  const Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text('Add license plate',
                                            style: TextStyle(
                                                fontSize: 23,
                                                fontWeight: FontWeight.w900)),
                                        Text('Add the vehicle you park with.',
                                            style: TextStyle(
                                                color: AppColors.muted))
                                      ])),
                                  IconButton(
                                      tooltip: 'Close',
                                      onPressed: () => Navigator.pop(dialogContext),
                                      icon: const Icon(Icons.close))
                                ]),
                                const SizedBox(height: AppSpace.lg),
                                TextField(
                                    controller: number,
                                    autofocus: true,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    onChanged: (_) {
                                      if (formError != null) {
                                        setDialogState(() => formError = null);
                                      }
                                    },
                                    decoration: const InputDecoration(
                                        labelText: 'Plate number',
                                        prefixIcon: Icon(Icons.pin_outlined))),
                                const SizedBox(height: AppSpace.sm),
                                DropdownButtonFormField<String>(
                                    value: type,
                                    isExpanded: true,
                                    itemHeight: 58,
                                    menuMaxHeight: 180,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                    dropdownColor: AppColors.surface,
                                    decoration: const InputDecoration(
                                        labelText: 'Vehicle type',
                                        prefixIcon:
                                            Icon(Icons.category_outlined)),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'car',
                                          child: Row(children: [
                                            Icon(Icons.directions_car_outlined,
                                                color: AppColors.brand),
                                            SizedBox(width: AppSpace.sm),
                                            Text('Car')
                                          ])),
                                      DropdownMenuItem(
                                          value: 'motorcycle',
                                          child: Row(children: [
                                            Icon(Icons.two_wheeler_outlined,
                                                color: AppColors.brand),
                                            SizedBox(width: AppSpace.sm),
                                            Text('Motorcycle')
                                          ])),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setDialogState(() => type = value);
                                      }
                                    }),
                                if (formError != null)
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          top: AppSpace.sm),
                                      child: Text(formError!,
                                          style: const TextStyle(
                                              color: AppColors.danger))),
                                const SizedBox(height: AppSpace.lg),
                                FilledButton.icon(
                                    onPressed: () {
                                      if (number.text.trim().isEmpty) {
                                        setDialogState(() => formError =
                                            'Enter your license plate number.');
                                        return;
                                      }
                                      Navigator.pop(dialogContext,
                                          {'number': number.text, 'type': type});
                                    },
                                    icon: const Icon(Icons.add_circle_outline),
                                    label: const Text('Add plate')),
                                const SizedBox(height: AppSpace.xs),
                                TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text('Cancel'))
                              ]))))));
      if (input == null) return;
      await widget.session.api.request('/users/license-plates',
          method: 'POST',
          token: widget.session.token,
          body: {
            'plateNumber': input['number']!.trim().toUpperCase(),
            'vehicleType': input['type']
          });
      await widget.session.reloadProfile();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _snack(error);
    } finally {
      number.dispose();
    }
  }
  Future<void> _removePlate(Plate plate) async {
    var removing = false;
    var removed = false;
    String? error;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> confirmRemoval() async {
                setDialogState(() {
                  removing = true;
                  error = null;
                });
                try {
                  await widget.session.api.request(
                      '/users/license-plates/${plate.id}',
                      method: 'DELETE',
                      token: widget.session.token);
                  await widget.session.reloadProfile();
                  removed = true;
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) setState(() {});
                } catch (value) {
                  if (dialogContext.mounted) {
                    setDialogState(() => error = value
                        .toString()
                        .replaceFirst('Exception: ', ''));
                  }
                } finally {
                  if (!removed && dialogContext.mounted) {
                    setDialogState(() => removing = false);
                  }
                }
              }

              return Dialog(
                  insetPadding: const EdgeInsets.all(AppSpace.lg),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                    height: 52,
                                    width: 52,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                        color: AppColors.dangerSoft,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.delete_outline,
                                        color: AppColors.danger)),
                                const SizedBox(height: AppSpace.md),
                                const Text('Remove this vehicle?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: AppSpace.xs),
                                Text(plate.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: AppSpace.sm),
                                const Text(
                                    'This will remove the vehicle and its gate QR code from your account. This action cannot be undone.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.muted, height: 1.4)),
                                if (error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          top: AppSpace.sm),
                                      child: Text(error!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: AppColors.danger))),
                                const SizedBox(height: AppSpace.lg),
                                FilledButton.icon(
                                    onPressed: removing ? null : confirmRemoval,
                                    style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.danger),
                                    icon: removing
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : const Icon(Icons.delete_outline),
                                    label: Text(removing
                                        ? 'Removing vehicle...'
                                        : 'Remove vehicle')),
                                const SizedBox(height: AppSpace.xs),
                                TextButton(
                                    onPressed: removing
                                        ? null
                                        : () => Navigator.pop(dialogContext),
                                    child: const Text('Keep vehicle'))
                              ]))));
            }));
  }
  Future<void> _setDefault(Plate plate) async { if(plate.isDefault)return; try {await widget.session.api.request('/users/license-plates/${plate.id}/default',method:'PATCH',token:widget.session.token);await widget.session.reloadProfile();if(mounted)setState((){});}catch(error){if(mounted)_snack(error);} }
  Future<void> _editProfile() async {
    final name = TextEditingController(text: widget.session.user!.name);
    final phone = TextEditingController(text: widget.session.user!.phone);
    try {
      final save = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Dialog(
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
                                  child: const Icon(Icons.person_outline,
                                      color: AppColors.brand)),
                              const SizedBox(width: AppSpace.sm),
                              const Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                    Text('Edit profile',
                                        style: TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.w900)),
                                    Text('Keep your details up to date',
                                        style: TextStyle(color: AppColors.muted))
                                  ])),
                              IconButton(
                                  tooltip: 'Close',
                                  onPressed: () => Navigator.pop(dialogContext),
                                  icon: const Icon(Icons.close))
                            ]),
                            const SizedBox(height: AppSpace.lg),
                            TextField(
                                controller: name,
                                autofocus: true,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                    labelText: 'Full name',
                                    prefixIcon: Icon(Icons.badge_outlined))),
                            const SizedBox(height: AppSpace.sm),
                            TextField(
                                controller: phone,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => Navigator.pop(dialogContext, true),
                                decoration: const InputDecoration(
                                    labelText: 'Phone number',
                                    prefixIcon: Icon(Icons.phone_outlined))),
                            const SizedBox(height: AppSpace.lg),
                            FilledButton.icon(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Save changes')),
                            const SizedBox(height: AppSpace.xs),
                            TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'))
                          ])))));
      if (save != true) return;
      await widget.session.api.request('/users/profile',
          method: 'PUT',
          token: widget.session.token,
          body: {'fullName': name.text.trim(), 'phone': phone.text.trim()});
      await widget.session.reloadProfile();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _snack(error);
    } finally {
      name.dispose();
      phone.dispose();
    }
  }
  Future<void> _password() async {
    final current = TextEditingController();
    final next = TextEditingController();
    try {
      final save = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Dialog(
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
                                  decoration: const BoxDecoration(color: AppColors.brandSoft, shape: BoxShape.circle),
                                  child: const Icon(Icons.lock_reset_outlined, color: AppColors.brand)),
                              const SizedBox(width: AppSpace.sm),
                              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Change password', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                                Text('Use a strong password you do not reuse.', style: TextStyle(color: AppColors.muted))
                              ])),
                              IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close))
                            ]),
                            const SizedBox(height: AppSpace.lg),
                            TextField(controller: current, autofocus: true, obscureText: true, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline))),
                            const SizedBox(height: AppSpace.sm),
                            TextField(controller: next, obscureText: true, textInputAction: TextInputAction.done, onSubmitted: (_) => Navigator.pop(dialogContext, true), decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.password_outlined))),
                            const SizedBox(height: AppSpace.lg),
                            FilledButton.icon(onPressed: () => Navigator.pop(dialogContext, true), icon: const Icon(Icons.check_circle_outline), label: const Text('Update password')),
                            const SizedBox(height: AppSpace.xs),
                            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))
                          ])))));
      if (save != true) return;
      await widget.session.api.request('/users/profile/password', method: 'PUT', token: widget.session.token, body: {'currentPassword': current.text, 'newPassword': next.text});
      if (mounted) _snack('Password updated.');
    } catch (error) {
      if (mounted) _snack(error);
    } finally {
      current.dispose();
      next.dispose();
    }
  }
  @override
  Widget build(BuildContext context) { final user=widget.session.user!; return PageFrame(title:'Profile',child:ListView(padding:const EdgeInsets.all(AppSpace.lg),children:[AppPanel(child:Row(children:[Container(height:60,width:60,decoration:const BoxDecoration(color:AppColors.brandSoft,shape:BoxShape.circle),alignment:Alignment.center,child:Text(user.name.isEmpty?'U':user.name.substring(0,1).toUpperCase(),style:const TextStyle(color:AppColors.brand,fontSize:26,fontWeight:FontWeight.w900))),const SizedBox(width:AppSpace.md),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(user.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(user.email,style:const TextStyle(color:AppColors.muted)),Text(user.phone.isEmpty?'No phone number added':user.phone,style:const TextStyle(color:AppColors.muted))])),IconButton(tooltip:'Edit profile',onPressed:_editProfile,icon:const Icon(Icons.edit_outlined))])),const SizedBox(height:AppSpace.xl),AppSectionTitle('License plates',action:TextButton.icon(onPressed:_addPlate,icon:const Icon(Icons.add),label:const Text('Add'))),const SizedBox(height:AppSpace.sm),if(user.plates.isEmpty)const AppEmptyState(icon:Icons.directions_car_outlined,title:'No license plates',detail:'Add your vehicle plate to complete your profile.'),...user.plates.map(_plateCard),const SizedBox(height:AppSpace.xl),const AppSectionTitle('Security'),const SizedBox(height:AppSpace.sm),AppPanel(child:Column(children:[ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.lock_outline,color:AppColors.brand),title:const Text('Change password',style:TextStyle(fontWeight:FontWeight.w800)),trailing:const Icon(Icons.chevron_right),onTap:_password),const Divider(height:1),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.logout_outlined,color:AppColors.danger),title:const Text('Sign out',style:TextStyle(color:AppColors.danger,fontWeight:FontWeight.w800)),onTap:widget.session.logout)])),const SizedBox(height:AppSpace.xl)])); }
  Widget _plateCard(Plate plate) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: AppPanel(
          child: Row(children: [
        Container(
            height: 44,
            width: 44,
            decoration: const BoxDecoration(
                color: AppColors.surfaceMuted, shape: BoxShape.circle),
            child: const Icon(Icons.directions_car_outlined,
                color: AppColors.brand)),
        const SizedBox(width: AppSpace.sm),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plate.number,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 3),
          Row(children: [
            Text(plate.type, style: const TextStyle(color: AppColors.muted)),
            if (plate.isDefault) ...[
              const SizedBox(width: AppSpace.xs),
              const AppPill('Default',
                  color: AppColors.successSoft, foreground: AppColors.success)
            ]
          ])
        ])),
        if (!plate.isDefault)
          IconButton(
              tooltip: 'Set as default',
              onPressed: () => _setDefault(plate),
              icon: const Icon(Icons.star_outline)),
        IconButton(
            tooltip: 'Remove plate',
            onPressed: () => _removePlate(plate),
            color: AppColors.danger,
            icon: const Icon(Icons.delete_outline))
      ])));
  void _snack(Object value)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value.toString().replaceFirst('Exception: ',''))));
}
