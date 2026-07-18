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
      showAppNotice(context, 'You can add up to $_maxPlates vehicles only.', tone: AppNoticeTone.info);
      return;
    }
    try {
      final input = await showDialog<Map<String, String>>(
          context: context,
          builder: (dialogContext) => const _AddPlateDialog());
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
                    setDialogState(() => error = value.toString().replaceFirst('Exception: ', ''));
                  }
                } finally {
                  if (!removed && dialogContext.mounted) {
                    setDialogState(() => removing = false);
                  }
                }
              }

              return Dialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                                    height: 52, width: 52,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: AppColors.danger.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.danger.withOpacity(0.20))),
                                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22)),
                                const SizedBox(height: AppSpace.md),
                                const Text('Remove this vehicle?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4)),
                                const SizedBox(height: AppSpace.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(plate.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                                ),
                                const SizedBox(height: AppSpace.md),
                                const Text(
                                    'This will remove the vehicle and its gate QR code from your account. This action cannot be undone.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: LightTheme.textSecondary, fontSize: 13, height: 1.45, fontWeight: FontWeight.w500)),
                                if (error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: AppSpace.sm),
                                      child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600))),
                                const SizedBox(height: AppSpace.lg),
                                FilledButton.icon(
                                    onPressed: removing ? null : confirmRemoval,
                                    style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.danger,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(vertical: 12)),
                                    icon: removing
                                        ? const SizedBox(
                                            height: 16, width: 16,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Icon(Icons.delete_outline_rounded, size: 18),
                                    label: Text(removing ? 'Removing vehicle...' : 'Remove vehicle', style: const TextStyle(fontWeight: FontWeight.w800))),
                                const SizedBox(height: AppSpace.xs),
                                TextButton(
                                    onPressed: removing ? null : () => Navigator.pop(dialogContext),
                                    child: const Text('Keep vehicle', style: TextStyle(fontWeight: FontWeight.bold)))
                              ]))));
            }));
  }

  Future<void> _setDefault(Plate plate) async {
    if (plate.isDefault) return;
    try {
      await widget.session.api.request('/users/license-plates/${plate.id}/default', method: 'PATCH', token: widget.session.token);
      await widget.session.reloadProfile();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _snack(error);
    }
  }


  Future<void> _editProfile() async {
    try {
      final input = await showDialog<Map<String, String>>(
          context: context,
          builder: (dialogContext) => _EditProfileDialog(
                initialName: widget.session.user!.name,
                initialPhone: widget.session.user!.phone,
              ));
      if (input == null) return;
      await widget.session.api.request('/users/profile',
          method: 'PUT',
          token: widget.session.token,
          body: {'fullName': input['name']!.trim(), 'phone': input['phone']!.trim()});
      await widget.session.reloadProfile();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _snack(error);
    }
  }

  Future<void> _password() async {
    try {
      final input = await showDialog<Map<String, String>>(
          context: context,
          builder: (dialogContext) => const _ChangePasswordDialog());
      if (input == null) return;
      await widget.session.api.request('/users/profile/password',
          method: 'PUT',
          token: widget.session.token,
          body: {
            'currentPassword': input['current']!,
            'newPassword': input['next']!
          });
      if (mounted) _snack('Password updated.');
    } catch (error) {
      if (mounted) _snack(error);
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = widget.session.user!;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FA),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // â”€â”€ Clean Pinned SliverAppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF0F4FA),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text('Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.5)),
          ),

          // â”€â”€ Sub-description text â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Parking made simple',
                    style: TextStyle(color: LightTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),

          // â”€â”€ User info card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Avatar with Gradient circle 3D
                    Container(
                      height: 64, width: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0052CC), Color(0xFF00D2FF)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0052CC).withOpacity(0.24),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.name.isEmpty ? 'U' : user.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // User text info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(color: LightTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.phone.isEmpty ? 'No phone number added' : user.phone,
                            style: TextStyle(color: LightTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    // Edit button
                    _SpringEditButton(onTap: _editProfile),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),

          // â”€â”€ License plates title row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('License plates',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4)),
                  TextButton.icon(
                    onPressed: _addPlate,
                    style: TextButton.styleFrom(
                      foregroundColor: LightTheme.brandBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

          // â”€â”€ Empty license plates state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (user.plates.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 8),
                child: _PlatesEmptyState(
                  icon: Icons.directions_car_outlined,
                  title: 'No license plates',
                  detail: 'Add your vehicle plate to complete your profile.',
                ),
              ),
            ),

          // â”€â”€ License plates cards list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (user.plates.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 6),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) => _plateCard(user.plates[idx]),
                  childCount: user.plates.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),

          // â”€â”€ Security section title â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.xs),
              child: Text('Security',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4)),
            ),
          ),

          // â”€â”€ Security list tile container â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Change password
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      leading: Container(
                        height: 38, width: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2FF).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0052CC), size: 18),
                      ),
                      title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w800, color: LightTheme.textPrimary, fontSize: 13.5)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: LightTheme.textMuted),
                      onTap: _password,
                    ),

                    // Divider
                    Container(height: 1, color: const Color(0xFFF1F5F9), margin: const EdgeInsets.symmetric(horizontal: 16)),

                    // Sign out
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      leading: Container(
                        height: 38, width: 38,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.logout_rounded, color: AppColors.danger, size: 18),
                      ),
                      title: Text('Sign out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 13.5)),
                      onTap: widget.session.logout,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
        ],
      ),
    );
  }

  Widget _plateCard(Plate plate) {
    final isMotor = plate.type.toLowerCase().contains('motor') || plate.type.toLowerCase().contains('moto') || plate.type.toLowerCase().contains('bike');
    final vehicleColors = isMotor
        ? [const Color(0xFF7C3AED), const Color(0xFFA78BFA)]
        : [const Color(0xFF0052CC), const Color(0xFF00A8E8)];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Left side: Gradient circle with Vehicle Icon
          Container(
            height: 44, width: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [vehicleColors[0].withOpacity(0.15), vehicleColors[1].withOpacity(0.07)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: vehicleColors[0].withOpacity(0.25),
                width: 1.2,
              ),
            ),
            child: Icon(
              isMotor ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded,
              color: vehicleColors[0],
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Middle side: Vietnamese license plate and type info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Vietnamese Plate Box Mockup
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
                        ],
                      ),
                      child: Text(
                        plate.number,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      isMotor ? 'Motorcycle' : 'Car',
                      style: const TextStyle(color: LightTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (plate.isDefault) ...[
                      const SizedBox(width: 8),
                      // Emerald Green default tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.40)),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF10B981).withOpacity(0.12), blurRadius: 4, spreadRadius: 1)
                          ]
                        ),
                        child: const Text('Default', style: TextStyle(color: Color(0xFF065F46), fontSize: 9, fontWeight: FontWeight.w800)),
                      )
                    ]
                  ],
                )
              ],
            ),
          ),

          // Right side: Set Default (star) and Remove (trash)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!plate.isDefault) ...[
                _CustomIconButton(
                  icon: Icons.star_rounded,
                  color: const Color(0xFFEAB308),
                  onTap: () => _setDefault(plate),
                  tooltip: 'Set default',
                ),
                const SizedBox(width: 6),
              ],
              _CustomIconButton(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFEF4444),
                onTap: () => _removePlate(plate),
                tooltip: 'Remove',
              ),
            ],
          )
        ],
      ),
    );
  }

  void _snack(Object value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value.toString().replaceFirst('Exception: ', ''))));
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// CUSTOM ICON BUTTON WITH SCALE FEEDBACK
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _CustomIconButton extends StatefulWidget {
  const _CustomIconButton({required this.icon, required this.color, required this.onTap, required this.tooltip});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_CustomIconButton> createState() => _CustomIconButtonState();
}
class _CustomIconButtonState extends State<_CustomIconButton> {
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
        transform: Matrix4.identity()..scale(_pressed ? 0.88 : 1.0),
        height: 36, width: 36,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.06),
          shape: BoxShape.circle,
          border: Border.all(color: widget.color.withOpacity(0.18), width: 1),
        ),
        child: Icon(widget.icon, color: widget.color, size: 18),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SPRING EDIT BUTTON
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _SpringEditButton extends StatefulWidget {
  const _SpringEditButton({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_SpringEditButton> createState() => _SpringEditButtonState();
}
class _SpringEditButtonState extends State<_SpringEditButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.85, end: 1.1), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          height: 36, width: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: LightTheme.brandBlue.withOpacity(0.20), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
            ],
          ),
          child: const Icon(Icons.edit_outlined, color: LightTheme.brandBlue, size: 18),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// PLATES EMPTY STATE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _PlatesEmptyState extends StatelessWidget {
  const _PlatesEmptyState({required this.icon, required this.title, required this.detail});
  final IconData icon; final String title; final String detail;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 80, width: 80,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [
            LightTheme.brandBlue.withOpacity(0.10), LightTheme.brandBlue.withOpacity(0.03), Colors.transparent,
          ])),
          child: Center(child: Container(
            height: 56, width: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [LightTheme.brandBlue.withOpacity(0.12), LightTheme.brandCyan.withOpacity(0.06)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              border: Border.all(color: LightTheme.brandBlue.withOpacity(0.16)),
            ),
            child: Icon(icon, color: LightTheme.brandBlue, size: 28),
          )),
        ),
        const SizedBox(height: AppSpace.md),
        Text(title, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(detail, textAlign: TextAlign.center,
            style: const TextStyle(color: LightTheme.textSecondary, fontSize: 13, height: 1.45)),
      ]),
    ),
  );
}


// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// STATEFUL DIALOGS (To prevent premature controller disposal crashes)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _AddPlateDialog extends StatefulWidget {
  const _AddPlateDialog();

  @override
  State<_AddPlateDialog> createState() => _AddPlateDialogState();
}

class _AddPlateDialogState extends State<_AddPlateDialog> {
  final _number = TextEditingController();
  String _type = 'car';
  String? _formError;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                            height: 44, width: 44,
                            decoration: BoxDecoration(
                                color: LightTheme.brandBlue.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: LightTheme.brandBlue.withOpacity(0.15))),
                            child: const Icon(Icons.directions_car_outlined, color: LightTheme.brandBlue, size: 20)),
                        const SizedBox(width: AppSpace.sm),
                        const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Add license plate',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4)),
                              Text('Add the vehicle you park with.',
                                  style: TextStyle(color: LightTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500))
                            ])),
                        IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20, color: LightTheme.textSecondary))
                      ]),
                      const SizedBox(height: AppSpace.lg),
                      TextField(
                          controller: _number,
                          autofocus: true,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) {
                            if (_formError != null) {
                              setState(() => _formError = null);
                            }
                          },
                          decoration: InputDecoration(
                              labelText: 'Plate number',
                              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.8)))),
                      const SizedBox(height: AppSpace.sm),
                      DropdownButtonFormField<String>(
                          value: _type,
                          isExpanded: true,
                          itemHeight: 52,
                          menuMaxHeight: 180,
                          borderRadius: BorderRadius.circular(16),
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                              labelText: 'Vehicle type',
                              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.category_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.8))),
                          items: const [
                            DropdownMenuItem(
                                value: 'car',
                                child: Row(children: [
                                  Icon(Icons.directions_car_outlined, color: LightTheme.brandBlue, size: 18),
                                  SizedBox(width: AppSpace.sm),
                                  Text('Car', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
                                ])),
                            DropdownMenuItem(
                                value: 'motorcycle',
                                child: Row(children: [
                                  Icon(Icons.two_wheeler_outlined, color: Color(0xFF7C3AED), size: 18),
                                  SizedBox(width: AppSpace.sm),
                                  Text('Motorcycle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
                                ])),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _type = value);
                            }
                          }),
                      if (_formError != null)
                        Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Text(_formError!, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600))),
                      const SizedBox(height: AppSpace.lg),
                      FilledButton.icon(
                          onPressed: () {
                            if (_number.text.trim().isEmpty) {
                              setState(() => _formError = 'Enter your license plate number.');
                              return;
                            }
                            Navigator.pop(context, {'number': _number.text, 'type': _type});
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text('Add plate', style: TextStyle(fontWeight: FontWeight.w800))),
                      const SizedBox(height: AppSpace.xs),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)))
                    ]))));
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.initialName, required this.initialPhone});
  final String initialName;
  final String initialPhone;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                            height: 44, width: 44,
                            decoration: BoxDecoration(
                                color: LightTheme.brandBlue.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: LightTheme.brandBlue.withOpacity(0.15))),
                            child: const Icon(Icons.person_outline_rounded, color: LightTheme.brandBlue, size: 20)),
                        const SizedBox(width: AppSpace.sm),
                        const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Edit profile',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4)),
                              Text('Keep your details up to date',
                                  style: TextStyle(color: LightTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500))
                            ])),
                        IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20, color: LightTheme.textSecondary))
                      ]),
                      const SizedBox(height: AppSpace.lg),
                      TextField(
                          controller: _name,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                              labelText: 'Full name',
                              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.8)))),
                      const SizedBox(height: AppSpace.sm),
                      TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            Navigator.pop(context, {'name': _name.text, 'phone': _phone.text});
                          },
                          decoration: InputDecoration(
                              labelText: 'Phone number',
                              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.8)))),
                      const SizedBox(height: AppSpace.lg),
                      FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context, {'name': _name.text, 'phone': _phone.text});
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w800))),
                      const SizedBox(height: AppSpace.xs),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)))
                    ]))));
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                            height: 44, width: 44,
                            decoration: BoxDecoration(
                                color: LightTheme.brandBlue.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: LightTheme.brandBlue.withOpacity(0.15))),
                            child: const Icon(Icons.lock_reset_outlined, color: LightTheme.brandBlue, size: 20)),
                        const SizedBox(width: AppSpace.sm),
                        const Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Change password',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: LightTheme.textPrimary, letterSpacing: -0.4)),
                              Text('Use a strong password.',
                                  style: TextStyle(color: LightTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500))
                            ])),
                        IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20, color: LightTheme.textSecondary))
                      ]),
                      const SizedBox(height: AppSpace.lg),
                      TextField(
                          controller: _current,
                          autofocus: true,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                              labelText: 'Current password',
                              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.8)))),
                      const SizedBox(height: AppSpace.sm),
                      TextField(
                          controller: _next,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            Navigator.pop(context, {'current': _current.text, 'next': _next.text});
                          },
                          decoration: InputDecoration(
                              labelText: 'New password',
                              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              prefixIcon: const Icon(Icons.password_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00D2FF), width: 1.8)))),
                      const SizedBox(height: AppSpace.lg),
                      FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context, {'current': _current.text, 'next': _next.text});
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Update password', style: TextStyle(fontWeight: FontWeight.w800))),
                      const SizedBox(height: AppSpace.xs),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)))
                    ]))));
  }
}
