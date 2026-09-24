import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/app_components.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        children: [
          const AppHeader(title: 'Profile'),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4ECEF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.ink,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ariana Khan',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'demo@oralyn.health',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _ProfileSection(
            title: 'Account',
            items: [
              _ProfileItem(
                Icons.person_outline,
                'Personal information',
                () => _message(
                  context,
                  'Personal information is read-only in this prototype.',
                ),
              ),
              _ProfileItem(
                Icons.lock_outline,
                'Change password',
                () => _message(context, 'Password change is simulated.'),
              ),
            ],
          ),
          _ProfileSection(
            title: 'Preferences',
            items: [
              _ProfileItem(
                Icons.cloud_outlined,
                'Screening server',
                () => Navigator.pushNamed(context, AppRoutes.apiSettings),
              ),
              _ProfileItem(
                Icons.notifications_none_rounded,
                'Notifications',
                () => _message(
                  context,
                  'Notification preferences updated locally.',
                ),
              ),
              _ProfileItem(
                Icons.language_rounded,
                'Language',
                () => _message(context, 'English is selected.'),
              ),
            ],
          ),
          _ProfileSection(
            title: 'Privacy',
            items: [
              _ProfileItem(
                Icons.shield_outlined,
                'Data & privacy',
                () => Navigator.pushNamed(context, AppRoutes.privacy),
              ),
              _ProfileItem(
                Icons.delete_outline_rounded,
                'Delete screening history',
                () => _deleteDialog(context),
                danger: true,
              ),
            ],
          ),
          _ProfileSection(
            title: 'About',
            items: [
              _ProfileItem(
                Icons.info_outline_rounded,
                'About Oralyn',
                () => Navigator.pushNamed(context, AppRoutes.about),
              ),
              _ProfileItem(
                Icons.health_and_safety_outlined,
                'Medical disclaimer',
                () => Navigator.pushNamed(context, AppRoutes.about),
              ),
              _ProfileItem(
                Icons.help_outline_rounded,
                'Help',
                () => _message(
                  context,
                  'Help content is available in the screening guidance.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (_) => false,
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }

  static void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  static void _deleteDialog(BuildContext context) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete screening history?'),
          content: const Text(
            'This prototype will simulate deletion without changing the bundled mock records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _message(context, 'Screening history deletion simulated.');
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.items});
  final String title;
  final List<_ProfileItem> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: .4),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  return Column(
                    children: [
                      ListTile(
                        onTap: entry.value.onTap,
                        leading: Icon(
                          entry.value.icon,
                          color: entry.value.danger
                              ? AppColors.danger
                              : AppColors.ink,
                          size: 21,
                        ),
                        title: Text(
                          entry.value.label,
                          style: TextStyle(
                            color: entry.value.danger
                                ? AppColors.danger
                                : AppColors.text,
                            fontSize: 14.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                        ),
                        minLeadingWidth: 28,
                      ),
                      if (entry.key < items.length - 1)
                        const Divider(height: 1, indent: 58),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
}

class _ProfileItem {
  const _ProfileItem(this.icon, this.label, this.onTap, {this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Data & Privacy')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          children: [
            const AppHeader(
              title: 'Your data and screening',
              subtitle:
                  'Oralyn uploads a photo only after you choose to start AI-assisted screening.',
            ),
            const SizedBox(height: 24),
            const _Policy(
              title: 'Screening image upload',
              body:
                  'The selected image is kept in app memory and sent to the configured prediction service for analysis. Backend retention depends on the service deployment policy.',
            ),
            const _Policy(
              title: 'No account backend',
              body:
                  'Login and registration states are simulated locally. Credentials are not transmitted.',
            ),
            const _Policy(
              title: 'No real location tracking',
              body: 'Nearby facilities and distances use fictional mock data.',
            ),
            const _Policy(
              title: 'Local history',
              body:
                  'Screening history is bundled demonstration data and resets with the app.',
            ),
          ],
        ),
      );
}

class _Policy extends StatelessWidget {
  const _Policy({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.teal, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('About Oralyn')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
          children: [
            const Center(child: OralynLogo(size: 70)),
            const SizedBox(height: 18),
            const Text(
              AppConstants.appName,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            const Text(
              AppConstants.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 30),
            Text(
              'Oralyn is a smartphone-based UI prototype for preliminary oral lesion screening guidance, explainable results, referral support, and nearby care discovery.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medical disclaimer',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(AppConstants.disclaimer, style: TextStyle(height: 1.5)),
                  SizedBox(height: 8),
                  Text(
                    'Do not use this prototype for emergencies, diagnosis, or treatment decisions.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Center(
              child: Text(
                'Prototype version 1.1.2',
                style:
                    TextStyle(color: AppColors.secondaryText, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
}
