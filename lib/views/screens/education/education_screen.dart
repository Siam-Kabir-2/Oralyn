import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../widgets/common/app_components.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const topics = [
      (
        Icons.spa_outlined,
        'Benign lesions',
        'Many oral changes are non-cancerous, including irritation and common ulcers. Persistent or changing areas still deserve attention.',
      ),
      (
        Icons.manage_search_outlined,
        'Potentially malignant disorders',
        'OPMDs are a group of oral conditions that may carry increased risk and should be evaluated by a trained professional.',
      ),
      (
        Icons.warning_amber_rounded,
        'Warning signs',
        'A sore lasting over two weeks, red or white patches, unexplained lumps, bleeding, numbness, or difficulty swallowing should be assessed.',
      ),
      (
        Icons.medical_services_outlined,
        'When to seek evaluation',
        'Arrange an examination when a change persists, worsens, returns frequently, or concerns you—even if a screening result is lower concern.',
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Oral Health Guide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 34),
        children: [
          const AppHeader(
            title: 'Understanding Oral Lesions',
            subtitle:
                'A short guide to common changes and when professional assessment matters.',
          ),
          const SizedBox(height: 24),
          ...topics.map(
            (topic) => _Topic(icon: topic.$1, title: topic.$2, body: topic.$3),
          ),
          const SizedBox(height: 12),
          const SectionHeader(title: 'A 60-second monthly self-check'),
          const SizedBox(height: 10),
          const _SelfCheckGuide(),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Everyday prevention'),
          const SizedBox(height: 10),
          const _PreventionChecklist(),
          const SizedBox(height: 22),
          const _UrgentCareNote(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2F6),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This educational content is general information and is not a substitute for advice from a qualified healthcare professional.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelfCheckGuide extends StatelessWidget {
  const _SelfCheckGuide();

  static const steps = [
    ('Lips and gums', 'Look for sores, swelling, or color changes.'),
    ('Cheeks and palate', 'Use clean fingers to gently pull each cheek aside.'),
    ('Tongue', 'Check the top, sides, and underneath in good light.'),
    (
      'Neck and jaw',
      'Notice any new lump, tenderness, or persistent swelling.'
    ),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: steps.asMap().entries.map((entry) {
            final step = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: entry.key == steps.length - 1 ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E6F68),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.$2,
                          style: const TextStyle(
                            color: Color(0xFFC8D4DE),
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
}

class _PreventionChecklist extends StatelessWidget {
  const _PreventionChecklist();

  static const items = [
    (Icons.smoke_free_outlined, 'Avoid tobacco and betel nut in every form'),
    (Icons.local_bar_outlined, 'Limit alcohol use'),
    (Icons.brush_outlined, 'Brush gently twice daily and clean between teeth'),
    (Icons.restaurant_outlined, 'Choose varied fruit, vegetables, and protein'),
    (Icons.medical_services_outlined, 'Attend routine dental examinations'),
    (Icons.wb_sunny_outlined, 'Use lip protection when exposed to strong sun'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: items
              .asMap()
              .entries
              .map((entry) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 13),
                        child: Row(
                          children: [
                            Icon(entry.value.$1,
                                color: AppColors.teal, size: 21),
                            const SizedBox(width: 12),
                            Expanded(child: Text(entry.value.$2)),
                            const Icon(Icons.check_circle_outline_rounded,
                                color: AppColors.success, size: 19),
                          ],
                        ),
                      ),
                      if (entry.key != items.length - 1)
                        const Divider(height: 1, indent: 48),
                    ],
                  ))
              .toList(),
        ),
      );
}

class _UrgentCareNote extends StatelessWidget {
  const _UrgentCareNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.emergency_outlined, color: AppColors.danger),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Seek urgent medical help for severe swelling, uncontrolled bleeding, or difficulty breathing or swallowing.',
                style: TextStyle(height: 1.45, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
}

class _Topic extends StatelessWidget {
  const _Topic({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F2F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.teal, size: 21),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 7),
            Text(
              body,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
            ),
          ],
        ),
      );
}
