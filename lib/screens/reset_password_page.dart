part of '../main.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.session,
    required this.token,
    required this.onComplete,
  });

  final SessionController session;
  final String token;
  final VoidCallback onComplete;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool submitting = false;
  bool showPassword = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final nextPassword = password.text;
    if (nextPassword.length < 6) {
      setState(() => error = 'Password must contain at least 6 characters.');
      return;
    }
    if (nextPassword != confirmation.text) {
      setState(() => error = 'Passwords do not match.');
      return;
    }

    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.session.api.request('/users/auth/reset-password',
          method: 'POST', body: {
        'token': widget.token,
        'newPassword': nextPassword,
      });
      await widget.session.logout();
      if (!mounted) return;
      showAppNotice(context, 'Password updated. Please sign in with your new password.',
          tone: AppNoticeTone.success);
      widget.onComplete();
    } catch (value) {
      if (mounted) setState(() => error = value.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: AppPanel(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                    height: 56,
                                    width: 56,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                        color: AppColors.brandSoft,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.lock_reset_outlined,
                                        color: AppColors.brand, size: 28)),
                                const SizedBox(height: AppSpace.lg),
                                const Text('Create a new password',
                                    style: TextStyle(
                                        fontSize: 27,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: AppSpace.xs),
                                const Text(
                                    'Choose a secure password with at least 6 characters.',
                                    style: TextStyle(
                                        color: AppColors.muted, height: 1.4)),
                                const SizedBox(height: AppSpace.lg),
                                TextField(
                                    controller: password,
                                    enabled: !submitting,
                                    obscureText: !showPassword,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                        labelText: 'New password',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                            tooltip: showPassword
                                                ? 'Hide password'
                                                : 'Show password',
                                            onPressed: () => setState(
                                                () => showPassword = !showPassword),
                                            icon: Icon(showPassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined)))),
                                const SizedBox(height: AppSpace.sm),
                                TextField(
                                    controller: confirmation,
                                    enabled: !submitting,
                                    obscureText: !showPassword,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => submit(),
                                    decoration: const InputDecoration(
                                        labelText: 'Confirm new password',
                                        prefixIcon:
                                            Icon(Icons.lock_outline))),
                                if (error != null) ...[
                                  const SizedBox(height: AppSpace.sm),
                                  Text(error!,
                                      style: const TextStyle(
                                          color: AppColors.danger)),
                                ],
                                const SizedBox(height: AppSpace.lg),
                                FilledButton.icon(
                                    onPressed: submitting ? null : submit,
                                    icon: submitting
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : const Icon(Icons.check_circle_outline),
                                    label: Text(submitting
                                        ? 'Updating password...'
                                        : 'Update password')),
                                const SizedBox(height: AppSpace.xs),
                                TextButton(
                                    onPressed:
                                        submitting ? null : widget.onComplete,
                                    child: const Text('Back to sign in')),
                              ])))))));
}
