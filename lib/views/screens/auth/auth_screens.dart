import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:clerk_flutter/src/widgets/authentication/clerk_forgotten_password_panel.dart';
import 'package:clerk_flutter/src/widgets/authentication/clerk_sign_in_panel.dart';
import 'package:clerk_flutter/src/widgets/authentication/clerk_sign_up_panel.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/app_components.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.sessionExpired = false});

  final bool sessionExpired;

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Welcome back',
        subtitle: sessionExpired
            ? 'Your session has ended. Sign in to continue.'
            : 'Sign in to continue your oral health journey.',
        child: const ClerkErrorListener(child: ClerkSignInPanel()),
        footer: TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
          child: const Text('New to Oralyn? Create account',
              style: TextStyle(color: AppColors.teal)),
        ),
      );
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Create your account',
        subtitle: 'Keep your screening guidance and care options in one place.',
        child: const ClerkErrorListener(child: ClerkSignUpPanel()),
        footer: TextButton(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.login),
          child: const Text('Already have an account? Sign in',
              style: TextStyle(color: AppColors.teal)),
        ),
      );
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Reset password',
        subtitle: 'Enter your email to receive a recovery code.',
        child: FilledButton(
          onPressed: () => ClerkForgottenPasswordPanel.show(context),
          child: const Text('Continue'),
        ),
        footer: TextButton(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, AppRoutes.login),
          child: const Text('Back to sign in',
              style: TextStyle(color: AppColors.teal)),
        ),
      );
}

class ExpiredSessionScreen extends StatelessWidget {
  const ExpiredSessionScreen({super.key});

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Session ended',
        subtitle: 'Sign in again to continue your screening.',
        child: FilledButton(
          onPressed: () async {
            try {
              await ClerkAuth.of(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.login, (_) => false);
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Could not reset the session. Please retry.'),
                ));
              }
            }
          },
          child: const Text('Sign in again'),
        ),
        footer: const SizedBox.shrink(),
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
  Widget build(BuildContext context) => Scaffold(
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
