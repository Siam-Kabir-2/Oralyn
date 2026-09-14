import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/screening_result.dart';
import '../../widgets/common/app_components.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result});
  final ScreeningResult result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
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
            _StatusPanel(result: result),
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
