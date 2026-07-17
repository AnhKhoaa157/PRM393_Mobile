part of '../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIGHT DESIGN SYSTEM TOKENS
// ─────────────────────────────────────────────────────────────────────────────

abstract final class LightTheme {
  // ── Background layers ──────────────────────────────────────────────────────
  static const scaffoldBg   = Color(0xFFF1F5F9); // off-white, never blinding
  static const surfaceWhite = Colors.white;
  static const surfaceCard  = Color(0xFFFAFCFF); // barely tinted white

  // ── Brand palette (synced with Admin/Staff) ────────────────────────────────
  static const brandBlue    = Color(0xFF0052CC); // Royal Blue anchor
  static const brandCyan    = Color(0xFF0284C7); // Electric Cyan accent
  static const brandDeep    = Color(0xFF003A91); // deeper hover/pressed tint

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF0F172A); // Charcoal – max contrast
  static const textSecondary = Color(0xFF475569); // Slate-500
  static const textMuted     = Color(0xFF94A3B8); // Slate-400

  // ── Border ────────────────────────────────────────────────────────────────
  static const borderDefault = Color(0xFFE2E8F0);
  static const borderFocus   = Color(0xFF0052CC);

  // ── Multi-layer soft shadows (3-D lift) ───────────────────────────────────
  static List<BoxShadow> cardShadow() => [
    BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 8, offset: const Offset(0, 4)),
    BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 24, offset: const Offset(0, 12)),
  ];

  static List<BoxShadow> floatingShadow() => [
    BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 4, offset: const Offset(0, 2)),
    BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, 8)),
    BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 40, offset: const Offset(0, 24)),
  ];

  static List<BoxShadow> buttonShadow() => [
    BoxShadow(color: brandBlue.withOpacity(0.28),
              blurRadius: 8, offset: const Offset(0, 3)),
    BoxShadow(color: brandBlue.withOpacity(0.18),
              blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> focusShadow() => [
    BoxShadow(color: brandBlue.withOpacity(0.12),
              blurRadius: 6, spreadRadius: 2, offset: Offset.zero),
  ];

  // ── Frosted glass backdrop blur config ────────────────────────────────────
  // Usage: wrap container with BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))
  // and set container color to Colors.white.withOpacity(0.55).
  static const glassOpacity = 0.55;
  static const glassBlur    = 12.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH PAGE  (Login + Register)
// ─────────────────────────────────────────────────────────────────────────────

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.session});
  final SessionController session;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool registerMode        = false;
  bool busy                = false;
  bool showPassword        = false;
  bool showConfirmPassword = false;

  final name     = TextEditingController();
  final email    = TextEditingController();
  final phone    = TextEditingController();
  final password = TextEditingController();
  final confirm  = TextEditingController();

  @override
  void dispose() {
    for (final c in [name, email, phone, password, confirm]) c.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty ||
        password.text.isEmpty ||
        (registerMode && name.text.trim().isEmpty)) {
      _snack('Please fill in all required fields.');
      return;
    }
    if (registerMode && password.text != confirm.text) {
      _snack('Passwords do not match.');
      return;
    }
    setState(() => busy = true);
    try {
      if (registerMode) {
        await widget.session.register(
            name.text, email.text, password.text, phone.text);
      } else {
        await widget.session.login(email.text, password.text);
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg.replaceFirst('Exception: ', ''))));

  void _toggleMode() => setState(() {
        registerMode        = !registerMode;
        showPassword        = false;
        showConfirmPassword = false;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightTheme.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, box) {
          final wide   = box.maxWidth >= 760;
          final hPad   = wide ? AppSpace.xl : AppSpace.md;
          final intro  = _IntroCard(registerMode: registerMode, wide: wide);
          final form   = _FormCard(
            registerMode:        registerMode,
            busy:                busy,
            showPassword:        showPassword,
            showConfirmPassword: showConfirmPassword,
            name:                name,
            email:               email,
            phone:               phone,
            password:            password,
            confirm:             confirm,
            onSubmit:            submit,
            onToggleMode:        _toggleMode,
            onTogglePassword:    () => setState(() => showPassword = !showPassword),
            onToggleConfirm:     () => setState(() => showConfirmPassword = !showConfirmPassword),
            onForgotPassword:    () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ForgotPasswordPage(
                    session:      widget.session,
                    initialEmail: email.text.trim()))),
          );

          return SingleChildScrollView(
            padding: EdgeInsets.all(hPad),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (box.maxHeight - hPad * 2).clamp(0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Expanded(flex: 11, child: intro),
                          const SizedBox(width: AppSpace.xl),
                          Expanded(flex: 9, child: form),
                        ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          intro,
                          const SizedBox(height: AppSpace.lg),
                          form,
                        ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTRO CARD  – gradient brand card with 3-D tilt entry animation
// ─────────────────────────────────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.registerMode, required this.wide});
  final bool registerMode;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween:    Tween(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 1200),
      curve:    Curves.easeOutCubic,
      builder:  (ctx, t, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(0.10 * t)
          ..rotateY(-0.06 * t),
        child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width:       double.infinity,
        padding:     EdgeInsets.all(wide ? 42 : AppSpace.lg),
        decoration:  BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF0052CC), Color(0xFF0284C7), Color(0xFF06B6D4)],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          boxShadow: LightTheme.floatingShadow()
            ..add(BoxShadow(
              color:      const Color(0xFF0052CC).withOpacity(0.22),
              blurRadius: 32,
              offset:     const Offset(0, 16),
            )),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _BrandLogoChip(),
          const SizedBox(height: AppSpace.xl),
          // Headline
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize:   wide ? 38 : 30,
                height:     1.14,
                fontWeight: FontWeight.w900,
                color:      Colors.white,
              ),
              children: [
                TextSpan(
                  text: registerMode ? 'Your parking,\n' : 'Park with\n',
                ),
                const TextSpan(
                  text:  'confidence.',
                  style: TextStyle(color: Color(0xFFBAE6FD)),   // sky-200
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          const Text(
            'Manage your wallet, vehicle plates and parking packages with PBMS.',
            style: TextStyle(color: Color(0xCCFFFFFF), height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: AppSpace.lg),
          const _FeatureRow(icon: Icons.account_balance_wallet_outlined, label: 'Wallet at a glance'),
          const _FeatureRow(icon: Icons.directions_car_outlined,          label: 'Vehicle details kept together'),
          const _FeatureRow(icon: Icons.inventory_2_outlined,             label: 'Flexible parking packages'),
        ]),
      ),
    );
  }
}

// Small "P" brand chip
class _BrandLogoChip extends StatelessWidget {
  const _BrandLogoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width:  52,
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color:      Colors.white.withOpacity(0.10),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'P',
        style: TextStyle(
          color:      Colors.white,
          fontSize:   26,
          fontWeight: FontWeight.w900,
          height:     1.0,
        ),
      ),
    );
  }
}

// One feature row inside the intro card
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM CARD  – frosted white glass card with all login fields
// ─────────────────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.registerMode,
    required this.busy,
    required this.showPassword,
    required this.showConfirmPassword,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirm,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onForgotPassword,
  });

  final bool registerMode;
  final bool busy;
  final bool showPassword;
  final bool showConfirmPassword;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController password;
  final TextEditingController confirm;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LightTheme.glassBlur,
          sigmaY: LightTheme.glassBlur,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(LightTheme.glassOpacity + 0.35),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
            boxShadow:    LightTheme.floatingShadow(),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Heading ──────────────────────────────────────────────────
            Text(
              registerMode ? 'Create an account' : 'Welcome back',
              style: const TextStyle(
                color:       LightTheme.textPrimary,
                fontWeight:  FontWeight.w900,
                fontSize:    26,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              registerMode
                  ? 'Start managing your parking in a few steps.'
                  : 'Sign in to continue to your parking dashboard.',
              style: const TextStyle(
                color:   LightTheme.textSecondary,
                height:  1.45,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpace.lg),

            // ── Register-only fields ──────────────────────────────────────
            if (registerMode) ...[
              _LightTextField(
                controller: name,
                label:      'Full name',
                icon:       Icons.person_outline_rounded,
              ),
              const SizedBox(height: AppSpace.sm),
              _LightTextField(
                controller: phone,
                label:      'Phone number',
                icon:       Icons.phone_outlined,
                type:       TextInputType.phone,
              ),
              const SizedBox(height: AppSpace.sm),
            ],

            // ── Shared fields ─────────────────────────────────────────────
            _LightTextField(
              controller: email,
              label:      'Email address',
              icon:       Icons.mail_outline_rounded,
              type:       TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpace.sm),
            _LightTextField(
              controller: password,
              label:      'Password',
              icon:       Icons.lock_outline_rounded,
              secret:     !showPassword,
              action:     registerMode ? TextInputAction.next : TextInputAction.done,
              onSubmitted: registerMode ? null : (_) => onSubmit(),
              suffix: IconButton(
                tooltip:  showPassword ? 'Hide password' : 'Show password',
                onPressed: onTogglePassword,
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
            ),
            if (registerMode) ...[
              const SizedBox(height: AppSpace.sm),
              _LightTextField(
                controller:  confirm,
                label:       'Confirm password',
                icon:        Icons.lock_outline_rounded,
                secret:      !showConfirmPassword,
                action:      TextInputAction.done,
                onSubmitted: (_) => onSubmit(),
                suffix: IconButton(
                  tooltip:  showConfirmPassword ? 'Hide' : 'Show',
                  onPressed: onToggleConfirm,
                  icon: Icon(
                    showConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                ),
              ),
            ],

            // ── Forgot password link ──────────────────────────────────────
            if (!registerMode)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: LightTheme.brandBlue,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),

            const SizedBox(height: AppSpace.sm),

            // ── Sign-in / Create-account button ────────────────────────────
            _GradientButton(
              onTap: busy ? null : onSubmit,
              busy:  busy,
              label: registerMode ? 'Create account' : 'Sign in',
            ),

            const SizedBox(height: AppSpace.md),

            // ── Switch mode row ───────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                registerMode ? 'Already have an account? ' : 'New to PBMS? ',
                style: const TextStyle(color: LightTheme.textSecondary, fontSize: 14),
              ),
              TextButton(
                onPressed: onToggleMode,
                style: TextButton.styleFrom(
                  foregroundColor: LightTheme.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                ),
                child: Text(
                  registerMode ? 'Sign in' : 'Create account',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIGHT TEXT FIELD  – white bg, royal-blue focus ring + focus shadow
// ─────────────────────────────────────────────────────────────────────────────

class _LightTextField extends StatefulWidget {
  const _LightTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.secret      = false,
    this.type,
    this.suffix,
    this.action      = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final bool                  secret;
  final TextInputType?        type;
  final Widget?               suffix;
  final TextInputAction       action;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_LightTextField> createState() => _LightTextFieldState();
}

class _LightTextFieldState extends State<_LightTextField> {
  final _focus    = FocusNode();
  bool  _focused  = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve:    Curves.easeOut,
      decoration: BoxDecoration(
        color:        LightTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? LightTheme.borderFocus : LightTheme.borderDefault,
          width: _focused ? 1.8 : 1.2,
        ),
        boxShadow: _focused ? LightTheme.focusShadow() : LightTheme.cardShadow(),
      ),
      child: TextField(
        controller:       widget.controller,
        focusNode:        _focus,
        obscureText:      widget.secret,
        keyboardType:     widget.type,
        textInputAction:  widget.action,
        onSubmitted:      widget.onSubmitted,
        style: const TextStyle(
          color:      LightTheme.textPrimary,
          fontSize:   15,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: LightTheme.brandBlue,
        decoration: InputDecoration(
          labelText:  widget.label,
          labelStyle: TextStyle(
            color:      _focused ? LightTheme.brandBlue : LightTheme.textMuted,
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            widget.icon,
            color: _focused ? LightTheme.brandBlue : LightTheme.textMuted,
            size:  20,
          ),
          suffixIcon: widget.suffix != null
              ? IconTheme.merge(
                  data: IconThemeData(
                    color: _focused ? LightTheme.brandBlue : LightTheme.textMuted,
                    size:  20,
                  ),
                  child: widget.suffix!,
                )
              : null,
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          filled:         false,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADIENT BUTTON  – blue-to-cyan, 3D shadow, tap scale animation
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.onTap,
    required this.label,
    this.busy = false,
  });
  final VoidCallback? onTap;
  final String        label;
  final bool          busy;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.965)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null && !widget.busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  _enabled ? (_) => _ctrl.forward()  : null,
      onTapUp:    _enabled ? (_) => _ctrl.reverse()  : null,
      onTapCancel: _enabled ?      () => _ctrl.reverse() : null,
      onTap:      _enabled ? widget.onTap            : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder:   (_, __) => Transform.scale(
          scale: _scale.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: _enabled
                  ? const LinearGradient(
                      colors: [Color(0xFF0052CC), Color(0xFF0284C7)],
                      begin:  Alignment.centerLeft,
                      end:    Alignment.centerRight,
                    )
                  : null,
              color: _enabled ? null : LightTheme.borderDefault,
              boxShadow: _enabled ? LightTheme.buttonShadow() : null,
            ),
            alignment: Alignment.center,
            child: widget.busy
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(
                    widget.label,
                    style: TextStyle(
                      color:      _enabled ? Colors.white : LightTheme.textMuted,
                      fontSize:   16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORGOT PASSWORD PAGE  – same light design system
// ─────────────────────────────────────────────────────────────────────────────

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage(
      {super.key, required this.session, this.initialEmail = ''});
  final SessionController session;
  final String            initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController email;
  bool    submitting = false;
  bool    sent       = false;
  String? error;

  @override
  void initState() {
    super.initState();
    email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (email.text.trim().isEmpty) {
      setState(() => error = 'Enter the email address linked to your account.');
      return;
    }
    setState(() { submitting = true; error = null; });
    try {
      await widget.session.api.request(
        '/users/auth/forgot-password',
        method: 'POST',
        body:   {'email': email.text.trim(), 'clientType': 'mobile'},
      );
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: LightTheme.scaffoldBg,
        elevation:       0,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(color: LightTheme.textPrimary,
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: LightTheme.glassBlur,
                      sigmaY: LightTheme.glassBlur),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.90),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.85), width: 1.5),
                      boxShadow: LightTheme.floatingShadow(),
                    ),
                    child: sent ? _success() : _form(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon avatar
          Container(
            height: 56, width: 56,
            decoration: BoxDecoration(
              color:        LightTheme.brandBlue.withOpacity(0.08),
              shape:        BoxShape.circle,
              border: Border.all(
                  color: LightTheme.brandBlue.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.lock_reset_outlined,
                color: LightTheme.brandBlue, size: 28),
          ),
          const SizedBox(height: AppSpace.lg),
          const Text('Reset your password',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900,
                  color: LightTheme.textPrimary, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          const Text(
              'Enter your email and we will send instructions to reset your password.',
              style: TextStyle(color: LightTheme.textSecondary,
                  height: 1.45, fontSize: 14)),
          const SizedBox(height: AppSpace.lg),
          _LightTextField(
            controller:  email,
            label:       'Email address',
            icon:        Icons.mail_outline_rounded,
            type:        TextInputType.emailAddress,
            action:      TextInputAction.done,
            onSubmitted: (_) => _sendReset(),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: AppSpace.lg),
          _GradientButton(
              onTap: submitting ? null : _sendReset,
              label: submitting ? 'Sending instructions…' : 'Send reset instructions',
              busy:  submitting),
          const SizedBox(height: AppSpace.xs),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: LightTheme.brandBlue),
            child: const Text('Back to sign in',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      );

  Widget _success() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56, width: 56,
            decoration: BoxDecoration(
              color:  const Color(0xFFECFDF5),
              shape:  BoxShape.circle,
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.mark_email_read_outlined,
                color: AppColors.success, size: 28),
          ),
          const SizedBox(height: AppSpace.lg),
          const Text('Check your inbox',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900,
                  color: LightTheme.textPrimary, letterSpacing: -0.4)),
          const SizedBox(height: 6),
          Text(
              'If an account exists for ${email.text.trim()}, reset instructions have been sent.',
              style: const TextStyle(
                  color: LightTheme.textSecondary, height: 1.45, fontSize: 14)),
          const SizedBox(height: AppSpace.lg),
          _GradientButton(
              onTap: () => Navigator.pop(context),
              label: 'Back to sign in'),
        ],
      );
}
