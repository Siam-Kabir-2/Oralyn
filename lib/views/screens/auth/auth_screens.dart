import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/app_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController(text: 'demo@oralyn.health');
  final password = TextEditingController(text: 'oralyn1');
  bool loading = false;
  String? error;

  Future<void> submit() async {
    setState(() => error = null);
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => loading = false);
    if (email.text.trim().endsWith('@error.test')) {
      setState(
        () => error =
            'We could not sign you in. Check your details and try again.',
      );
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Welcome back',
        subtitle: 'Sign in to continue your oral health journey.',
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('New to Oralyn? '),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
              child: const Text(
                'Create account',
                style: TextStyle(color: AppColors.teal),
              ),
            ),
          ],
        ),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Email',
                controller: email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Enter a valid email address',
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Password',
                controller: password,
                password: true,
                prefixIcon: Icons.lock_outline,
                validator: (value) => (value?.length ?? 0) >= 6
                    ? null
                    : 'Password must be at least 6 characters',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: AppColors.teal),
                  ),
                ),
              ),
              if (error != null) _InlineError(message: error!),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Sign In',
                onPressed: submit,
                loading: loading,
                icon: Icons.login_rounded,
              ),
            ],
          ),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  bool loading = false;

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Create your account',
        subtitle: 'Keep your screening guidance and care options in one place.',
        footer: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Already have an account? Sign in',
            style: TextStyle(color: AppColors.teal),
          ),
        ),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Full name',
                prefixIcon: Icons.person_outline,
                validator: (value) =>
                    (value?.trim().length ?? 0) > 2 ? null : 'Enter your name',
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Enter a valid email address',
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Password',
                password: true,
                prefixIcon: Icons.lock_outline,
                validator: (value) => (value?.length ?? 0) >= 6
                    ? null
                    : 'Use at least 6 characters',
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Create Account',
                onPressed: submit,
                loading: loading,
                icon: Icons.person_add_alt_1_outlined,
              ),
              const SizedBox(height: 12),
              Text(
                'By continuing, you agree to the prototype privacy terms.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  bool sent = false;

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: sent ? 'Check your inbox' : 'Reset password',
        subtitle: sent
            ? 'We sent a mock recovery link. No email was actually sent.'
            : 'Enter your email and we’ll send recovery instructions.',
        footer: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Back to sign in',
            style: TextStyle(color: AppColors.teal),
          ),
        ),
        child: sent
            ? const Icon(
                Icons.mark_email_read_outlined,
                size: 72,
                color: AppColors.teal,
              )
            : Form(
                key: formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline,
                      validator: (value) => value != null && value.contains('@')
                          ? null
                          : 'Enter a valid email address',
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Send Recovery Link',
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false)
                          setState(() => sent = true);
                      },
                      icon: Icons.send_outlined,
                    ),
                  ],
                ),
              ),
      );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const OralynLogo(),
            const SizedBox(height: 28),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 30),
            child,
            const SizedBox(height: 20),
            footer,
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
