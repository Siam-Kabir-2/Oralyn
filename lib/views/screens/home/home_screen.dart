import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../../widgets/common/app_components.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recent = MockData.results.first;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ariana',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Open profile',
                button: true,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE4ECEF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _ScreeningHero(
            onTap: () => Navigator.pushNamed(context, AppRoutes.preparation),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: 8),
          _QuickAction(
            icon: Icons.local_hospital_outlined,
            title: 'Find a doctor',
            subtitle: 'Nearby verified care',
            onTap: () => Navigator.pushNamed(context, AppRoutes.doctorSearch),
          ),
          const Divider(height: 1),
          _QuickAction(
            icon: Icons.history_rounded,
            title: 'Screening history',
            subtitle: 'Review previous guidance',
            onTap: () => Navigator.pushNamed(context, AppRoutes.history),
          ),
          const Divider(height: 1),
          _QuickAction(
            icon: Icons.menu_book_outlined,
            title: 'Learn about oral lesions',
            subtitle: 'Short, clear health guidance',
            onTap: () => Navigator.pushNamed(context, AppRoutes.education),
          ),
          const SizedBox(height: 27),
          SectionHeader(
            title: 'Recent screening',
            action: 'View all',
            onTap: () => Navigator.pushNamed(context, AppRoutes.history),
          ),
          const SizedBox(height: 10),
          ScreeningCard(
            result: recent,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.historyDetail,
              arguments: recent,
            ),
          ),
          const SizedBox(height: 26),
          const _HealthTip(),
        ],
      ),
    );
  }
}

class _ScreeningHero extends StatelessWidget {
  const _ScreeningHero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 14, 18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check an oral concern',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white, fontSize: 21),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Take a clear photo and receive preliminary screening guidance.',
                      style: TextStyle(
                        color: Color(0xFFC8D4DE),
                        height: 1.45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 82,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF183B58),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 51,
                      height: 36,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF6EC8BA),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    const Icon(
                      Icons.center_focus_strong,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 19),
              label: const Text('Start Screening'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.teal, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      );
}

class _HealthTip extends StatelessWidget {
  const _HealthTip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: AppColors.blue),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Oral health note',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Persistent oral ulcers should be professionally evaluated, especially if they last longer than two weeks.',
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
