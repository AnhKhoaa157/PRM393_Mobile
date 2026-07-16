part of '../main.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.session});
  final SessionController session;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool registerMode = false;
  bool busy = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    for (final controller in [name, email, phone, password, confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty ||
        password.text.isEmpty ||
        (registerMode && name.text.trim().isEmpty)) {
      _message('Please fill in all required fields.');
      return;
    }
    if (registerMode && password.text != confirm.text) {
      _message('Passwords do not match.');
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
    } catch (error) {
      if (mounted) _message(error.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceFirst('Exception: ', ''))));

  void _switchMode() => setState(() {
        registerMode = !registerMode;
        showPassword = false;
        showConfirmPassword = false;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final form = _form();
        final intro = _intro(wide);
        return SingleChildScrollView(
            padding: wide
                ? const EdgeInsets.all(AppSpace.xl)
                : const EdgeInsets.all(AppSpace.md),
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight -
                            (wide ? AppSpace.xl * 2 : AppSpace.md * 2))
                        .clamp(0, double.infinity)),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: wide
                            ? Row(children: [
                                Expanded(flex: 11, child: intro),
                                const SizedBox(width: AppSpace.xl),
                                Expanded(flex: 9, child: form),
                              ])
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [intro, const SizedBox(height: AppSpace.lg), form])))));
      })));

  Widget _intro(bool wide) => Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 42 : AppSpace.lg),
      decoration: BoxDecoration(
          color: AppColors.brandDeep,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: const LinearGradient(
              colors: [AppColors.brandDeep, AppColors.brand],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppBrandMark(dark: true),
        const SizedBox(height: AppSpace.xl),
        Text(registerMode ? 'Your parking,\none simple place.' : 'Park with\nconfidence.',
            style: TextStyle(
                color: Colors.white,
                fontSize: wide ? 38 : 30,
                height: 1.12,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpace.sm),
        const Text('Manage your wallet, vehicle plates and parking packages with PBMS.',
            style: TextStyle(color: Color(0xd9ffffff), height: 1.45)),
        const SizedBox(height: AppSpace.lg),
        _feature(Icons.account_balance_wallet_outlined, 'Wallet at a glance'),
        _feature(Icons.directions_car_outlined, 'Vehicle details kept together'),
        _feature(Icons.inventory_2_outlined, 'Flexible parking packages'),
      ]));

  Widget _feature(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(children: [
        const SizedBox(width: 2),
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(width: AppSpace.sm),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
      ]));

  Widget _form() => AppPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(registerMode ? 'Create an account' : 'Welcome back',
            style: const TextStyle(
                color: AppColors.foreground, fontWeight: FontWeight.w900, fontSize: 27)),
        const SizedBox(height: AppSpace.xs),
        Text(registerMode ? 'Start managing your parking in a few steps.' : 'Sign in to continue to your parking dashboard.',
            style: const TextStyle(color: AppColors.muted, height: 1.4)),
        const SizedBox(height: AppSpace.lg),
        if (registerMode) ...[
          _field(name, 'Full name', Icons.person_outline),
          const SizedBox(height: AppSpace.sm),
          _field(phone, 'Phone number', Icons.phone_outlined,
              type: TextInputType.phone),
          const SizedBox(height: AppSpace.sm),
        ],
        _field(email, 'Email address', Icons.mail_outline,
            type: TextInputType.emailAddress),
        const SizedBox(height: AppSpace.sm),
        _field(password, 'Password', Icons.lock_outline,
            secret: !showPassword,
            suffix: IconButton(
                tooltip: showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => showPassword = !showPassword),
                icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
        if (registerMode) ...[
          const SizedBox(height: AppSpace.sm),
          _field(confirm, 'Confirm password', Icons.lock_outline,
              secret: !showConfirmPassword,
              suffix: IconButton(
                  tooltip: showConfirmPassword ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                  icon: Icon(showConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined))),
        ],
        if (!registerMode)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ForgotPasswordPage(
                          session: widget.session, initialEmail: email.text.trim()))),
                  child: const Text('Forgot password?'))),
        const SizedBox(height: AppSpace.sm),
        FilledButton(
            onPressed: busy ? null : submit,
            child: busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(registerMode ? 'Create account' : 'Sign in')),
        const SizedBox(height: AppSpace.md),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(registerMode ? 'Already have an account? ' : 'New to PBMS? ',
              style: const TextStyle(color: AppColors.muted)),
          TextButton(onPressed: _switchMode, child: Text(registerMode ? 'Sign in' : 'Create account')),
        ])
      ]));

  Widget _field(TextEditingController controller, String label, IconData icon,
          {bool secret = false, TextInputType? type, Widget? suffix}) =>
      TextField(
          controller: controller,
          obscureText: secret,
          keyboardType: type,
          textInputAction: label == 'Confirm password' || label == 'Password' && !registerMode
              ? TextInputAction.done
              : TextInputAction.next,
          onSubmitted: label == 'Confirm password' || label == 'Password' && !registerMode
              ? (_) => submit()
              : null,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIcon: suffix));

}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.session, this.initialEmail = ''});
  final SessionController session;
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController email;
  bool submitting = false;
  bool sent = false;
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
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.session.api.request('/users/auth/forgot-password',
          method: 'POST', body: {'email': email.text.trim(), 'clientType': 'mobile'});
      if (mounted) setState(() => sent = true);
    } catch (value) {
      if (mounted) setState(() => error = value.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            leading: BackButton(onPressed: () => Navigator.pop(context))),
        body: SafeArea(
            top: false,
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AppPanel(
                            padding: const EdgeInsets.all(AppSpace.lg),
                            child: sent ? _success() : _form()))))));
  }

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            height: 56,
            width: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.brandSoft, shape: BoxShape.circle),
            child: const Icon(Icons.lock_reset_outlined, color: AppColors.brand, size: 28)),
        const SizedBox(height: AppSpace.lg),
        const Text('Reset your password', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpace.xs),
        const Text('Enter your email and we will send instructions to reset your password.', style: TextStyle(color: AppColors.muted, height: 1.4)),
        const SizedBox(height: AppSpace.lg),
        TextField(
            controller: email,
            enabled: !submitting,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendReset(),
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: AppSpace.sm), child: Text(error!, style: const TextStyle(color: AppColors.danger))),
        const SizedBox(height: AppSpace.lg),
        FilledButton.icon(
            onPressed: submitting ? null : _sendReset,
            icon: submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_outlined),
            label: Text(submitting ? 'Sending instructions...' : 'Send reset instructions')),
        const SizedBox(height: AppSpace.xs),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to sign in'))
      ]);

  Widget _success() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            height: 56,
            width: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 28)),
        const SizedBox(height: AppSpace.lg),
        const Text('Check your inbox', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpace.xs),
        Text('If an account exists for ${email.text.trim()}, reset instructions have been sent.', style: const TextStyle(color: AppColors.muted, height: 1.4)),
        const SizedBox(height: AppSpace.lg),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Back to sign in'))
      ]);
}
