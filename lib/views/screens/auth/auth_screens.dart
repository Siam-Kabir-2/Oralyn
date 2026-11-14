import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:clerk_flutter/src/widgets/authentication/clerk_forgotten_password_panel.dart';
import 'package:clerk_flutter/src/widgets/authentication/clerk_sign_in_panel.dart';
import 'package:clerk_flutter/src/widgets/authentication/clerk_sign_up_panel.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/app_components.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen(
      {super.key, this.sessionExpired = false, this.role = 'patient'});

  final bool sessionExpired;
  final String role;

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        eyebrow: role == 'doctor'
            ? 'DOCTOR ACCESS'
            : role == 'admin'
                ? 'ADMIN ACCESS'
                : 'PATIENT ACCESS',
        title: role == 'admin'
            ? 'Admin sign in'
            : role == 'doctor'
                ? 'Doctor sign in'
                : 'Patient sign in',
        subtitle: sessionExpired
            ? 'Your session has ended. Sign in to continue.'
            : role == 'doctor'
                ? 'Use your Oralyn account to access your professional workspace.'
                : role == 'admin'
                    ? 'Authorized administrators only.'
                    : 'Sign in to continue your oral health journey.',
        child: const ClerkErrorListener(child: ClerkSignInPanel()),
        footer: role == 'admin'
            ? const SizedBox.shrink()
            : TextButton(
                onPressed: () => Navigator.pushNamed(
                    context,
                    role == 'doctor'
                        ? AppRoutes.doctorRegister
                        : AppRoutes.register),
                child: Text(
                    role == 'doctor'
                        ? 'New Doctor? Apply for verification'
                        : 'New to Oralyn? Create account',
                    style: const TextStyle(color: AppColors.teal)),
              ),
      );
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, this.role = 'patient'});

  final String role;

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        eyebrow: role == 'doctor' ? 'DOCTOR APPLICATION' : 'JOIN ORALYN',
        title: role == 'doctor'
            ? 'Create a Doctor account'
            : 'Create your account',
        subtitle: role == 'doctor'
            ? 'After email verification, submit your professional details for review.'
            : 'Keep your screening guidance and care options in one place.',
        child: const ClerkErrorListener(child: ClerkSignUpPanel()),
        footer: TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context,
              role == 'doctor' ? AppRoutes.doctorLogin : AppRoutes.login),
          child: const Text('Already have an account? Sign in',
              style: TextStyle(color: AppColors.teal)),
        ),
      );
}

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              const OralynLogo(),
              const SizedBox(height: 26),
              Text('Welcome to Oralyn',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 10),
              Text(
                'Personal screening and professional review, in one secure place.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 30),
              Text('CHOOSE YOUR SPACE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(height: 12),
              _RoleEntry(
                icon: Icons.person_outline_rounded,
                title: 'Continue as Patient',
                description: 'Screen, save results, and request care.',
                onTap: () => Navigator.pushNamed(context, AppRoutes.login),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.register),
                child: const Text('Register as Patient'),
              ),
              const SizedBox(height: 10),
              _RoleEntry(
                icon: Icons.medical_services_outlined,
                title: 'Continue as Doctor',
                description: 'Review cases assigned to your verified account.',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.doctorLogin),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.doctorRegister),
                child: const Text('Apply as Doctor'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.adminLogin),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Admin sign in'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _RoleEntry extends StatelessWidget {
  const _RoleEntry({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: AppColors.teal, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AppColors.secondaryText),
            ]),
          ),
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
                    context, AppRoutes.authChoice, (_) => false);
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
    this.eyebrow = 'ACCOUNT ACCESS',
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const OralynLogo(size: 48),
                      const SizedBox(height: 28),
                      Text(eyebrow,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Text(title,
                          style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 10),
                      Text(subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: AppColors.secondaryText)),
                      const SizedBox(height: 26),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: child,
                      ),
                      const SizedBox(height: 16),
                      Center(child: footer),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(
                              context, AppRoutes.authChoice, (_) => false),
                          child: const Text('Choose another account type'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
