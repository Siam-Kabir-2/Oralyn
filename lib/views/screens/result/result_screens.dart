import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/screening_result.dart';
import '../../../models/screening_session.dart';
import '../../widgets/common/app_components.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.outcome});
  final ScreeningOutcome outcome;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.outcome.result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening Result'),
        leading: IconButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
          ),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close result',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 34),
          children: [
            const _PrototypeBanner(),
            const SizedBox(height: 14),
            _StatusPanel(result: result),
            if (widget.outcome.photo != null) ...[
              const SizedBox(height: 24),
              const SectionHeader(title: 'Photo reviewed'),
              const SizedBox(height: 10),
              _ReviewedPhoto(photo: widget.outcome.photo!),
            ],
            const SizedBox(height: 26),
            const SectionHeader(title: 'AI screening category'),
            const SizedBox(height: 10),
            Text(
              result.categoryLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.blue),
            ),
            const SizedBox(height: 20),
            ConfidenceBar(value: result.confidence),
            const SizedBox(height: 30),
            const SectionHeader(title: 'Areas considered by the model'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.explainability,
                arguments: result,
              ),
              child: const GradCamPlaceholder(),
            ),
            const SizedBox(height: 12),
            Text(
              'Highlighted areas indicate regions that influenced the screening model.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => expanded = !expanded),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'How should I interpret this?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'The overlay is a simplified visual explanation. It shows where the mock model focused, but it does not identify disease boundaries or confirm a diagnosis.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.secondaryText),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _NextStep(result: result),
            const SizedBox(height: 22),
            _Recommendations(result: result),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2F6),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.blue,
                    size: 19,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppConstants.disclaimer,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeBanner extends StatelessWidget {
  const _PrototypeBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0D9A9)),
        ),
        child: const Row(
          children: [
            Icon(Icons.science_outlined, color: AppColors.warning, size: 19),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Simulated result using sample data — not an analysis of your photo.',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _ReviewedPhoto extends StatelessWidget {
  const _ReviewedPhoto({required this.photo});

  final ScreeningPhoto photo;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Image.memory(
              photo.bytes,
              width: double.infinity,
              height: 230,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: 'Photo used for this screening demonstration',
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .58),
                    ],
                    stops: const [.5, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 13,
              right: 13,
              bottom: 12,
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: Colors.white, size: 17),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      photo.fromCamera
                          ? 'Captured in this session • not uploaded'
                          : 'Selected in this session • not uploaded',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.result});

  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    final urgent = result.risk == RiskLevel.promptSpecialistReview;
    final review = result.risk == RiskLevel.professionalReview;
    final items = [
      if (urgent)
        (
          'Arrange prompt care',
          'Contact a dentist or oral medicine specialist as soon as practical.',
          Icons.event_available_outlined
        )
      else if (review)
        (
          'Book a dental review',
          'Arrange a professional examination, especially if the change persists.',
          Icons.event_outlined
        )
      else
        (
          'Keep monitoring',
          'Check the same area weekly in good light and note any change.',
          Icons.visibility_outlined
        ),
      (
        'Avoid irritation',
        'Avoid tobacco, betel nut, and alcohol; limit very hot or spicy foods if the area is sore.',
        Icons.shield_outlined
      ),
      (
        'Protect daily oral health',
        'Brush gently twice daily, clean between teeth, and stay hydrated.',
        Icons.health_and_safety_outlined
      ),
      (
        'Know the warning signs',
        'Seek care for a sore lasting over two weeks, a lump, bleeding, numbness, or trouble swallowing.',
        Icons.warning_amber_rounded
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Your practical care plan'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final item = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F2F0),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(item.$3, color: AppColors.teal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$1,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 3),
                              Text(
                                item.$2,
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
                  ),
                  if (entry.key != items.length - 1)
                    const Divider(height: 1, indent: 67),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.result});
  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBadge(risk: result.risk),
          const SizedBox(height: 17),
          Text(
            result.status,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 9),
          Text(
            result.summary,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 18),
          RiskIndicator(risk: result.risk),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.result});
  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended next step',
            style: TextStyle(
              color: Color(0xFFB9C8D4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            result.recommendation,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'A dentist or oral medicine specialist can perform a complete clinical assessment.',
            style: TextStyle(
              color: Color(0xFFC8D4DE),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.referral,
                arguments: result,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.near_me_outlined, size: 19),
              label: const Text('Find Nearby Care'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Result saved to screening history.'),
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.bookmark_border_rounded, size: 19),
              label: const Text('Save Result'),
            ),
          ),
        ],
      ),
    );
  }
}

class ExplainabilityScreen extends StatelessWidget {
  const ExplainabilityScreen({super.key, required this.result});
  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visual Explanation')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          const AppHeader(
            title: 'Areas considered by the model',
            subtitle:
                'A simplified view of the image regions that influenced this screening output.',
          ),
          const SizedBox(height: 22),
          const GradCamPlaceholder(height: 300),
          const SizedBox(height: 22),
          const _ExplanationRow(
            icon: Icons.layers_outlined,
            title: 'The color overlay',
            body:
                'Warmer areas had more influence on the mock screening category.',
          ),
          const _ExplanationRow(
            icon: Icons.visibility_outlined,
            title: 'What it can show',
            body:
                'It helps make the system’s visual attention more understandable.',
          ),
          const _ExplanationRow(
            icon: Icons.block_outlined,
            title: 'What it cannot show',
            body:
                'It does not confirm disease, define a lesion, or replace a clinical examination.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Visual explanations can be imprecise. A professional should interpret the image together with your health history and an examination.',
              style: TextStyle(height: 1.45),
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'View Referral Guidance',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.referral,
              arguments: result,
            ),
            icon: Icons.route_outlined,
          ),
        ],
      ),
    );
  }
}

class _ExplanationRow extends StatelessWidget {
  const _ExplanationRow({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
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
