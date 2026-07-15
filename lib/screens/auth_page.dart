part of '../main.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.session});
  final SessionController session;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool registerMode = false, busy = false;
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [name, email, phone, password, confirm]) {
      c.dispose();
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
        await widget.session
            .register(name.text, email.text, password.text, phone.text);
      } else {
        await widget.session.login(email.text, password.text);
      }
    } catch (e) {
      if (mounted) _message(e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceFirst('Exception: ', ''))));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 52, 24, 42),
                decoration: const BoxDecoration(
                    color: _skyDark,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(64))),
                child: Column(children: [
                  const Icon(Icons.local_parking_rounded,
                      size: 54, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(registerMode ? 'Create your account' : 'Hello, Welcome',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                      registerMode
                          ? 'Park smarter with PBMS'
                          : "Don't have an account?",
                      style: const TextStyle(color: Color(0xccffffff))),
                  TextButton(
                      onPressed: () =>
                          setState(() => registerMode = !registerMode),
                      child: Text(registerMode ? 'Sign in instead' : 'Register',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(registerMode ? 'Register' : 'Login',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: _text)),
                      const SizedBox(height: 25),
                      if (registerMode) ...[
                        _field(name, 'Full name', Icons.person_outline),
                        const SizedBox(height: 14),
                        _field(phone, 'Phone number', Icons.phone_outlined,
                            type: TextInputType.phone),
                        const SizedBox(height: 14)
                      ],
                      _field(email, 'Email', Icons.mail_outline,
                          type: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      _field(password, 'Password', Icons.lock_outline,
                          secret: true),
                      if (registerMode) ...[
                        const SizedBox(height: 14),
                        _field(confirm, 'Confirm password', Icons.lock_outline,
                            secret: true)
                      ],
                      if (!registerMode)
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: _forgotPassword,
                                child: const Text('Forgot password?'))),
                      const SizedBox(height: 8),
                      FilledButton(
                          onPressed: busy ? null : submit,
                          style: FilledButton.styleFrom(
                              backgroundColor: _sky,
                              padding: const EdgeInsets.all(17)),
                          child: busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text(
                                  registerMode ? 'Create account' : 'Login')),
                    ]),
              ),
            ]),
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
          {bool secret = false, TextInputType? type}) =>
      TextField(
          controller: controller,
          obscureText: secret,
          keyboardType: type,
          decoration:
              InputDecoration(labelText: label, prefixIcon: Icon(icon)));
  Future<void> _forgotPassword() async {
    if (email.text.trim().isEmpty) {
      _message('Enter your email first.');
      return;
    }
    try {
      await widget.session.api
          .request('/users/auth/forgot-password', method: 'POST', body: {
        'email': email.text.trim(),
        'clientType': 'mobile',
        'frontendUrl': 'parkingmobile://reset-password'
      });
      if (mounted) _message('Reset instructions have been sent.');
    } catch (e) {
      if (mounted) _message(e.toString());
    }
  }
}
