import 'package:flutter/material.dart';

import '../../../controllers/history_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/screening_result.dart';
import '../../widgets/common/app_components.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final controller = HistoryController();
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(22, widget.standalone ? 6 : 22, 22, 30),
        children: [
          if (!widget.standalone)
            const AppHeader(
              title: 'Screening History',
              subtitle: 'Review saved screening guidance and next steps.',
            ),
          if (!widget.standalone) const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: ['All', 'Low concern', 'Review recommended']
                .map(
                  (value) => ChoiceChip(
                    label: Text(value),
                    selected: filter == value,
                    onSelected: (_) => setState(() => filter = value),
                    showCheckmark: false,
                    selectedColor: const Color(0xFFDCEFEB),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          ...controller.filtered(filter).map(
                (result) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScreeningCard(
                    result: result,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.historyDetail,
                      arguments: result,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
    if (!widget.standalone) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Screening History')),
      body: content,
    );
  }
}

class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({super.key, required this.result});
  final ScreeningResult result;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  bool explanation = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final date =
        '${result.date.day}/${result.date.month}/${result.date.year} at ${result.date.hour.toString().padLeft(2, '0')}:${result.date.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Screening')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 32),
        children: [
          const AppImagePlaceholder(
            height: 220,
            label: 'Saved screening image placeholder',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              StatusBadge(risk: result.risk),
              const Spacer(),
              Text(date, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            result.status,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            result.summary,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 24),
          _SavedData(label: 'Classification', value: result.categoryLabel),
          _SavedData(
            label: 'Confidence',
            value: '${(result.confidence * 100).round()}%',
          ),
          _SavedData(label: 'Recommendation', value: result.recommendation),
          const SizedBox(height: 22),
          InkWell(
            onTap: () => setState(() => explanation = !explanation),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Visual explanation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(explanation ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: explanation
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: const GradCamPlaceholder(),
          ),
          const SizedBox(height: 24),
          if (result.risk != RiskLevel.lowConcern)
            PrimaryButton(
              label: 'Find Care',
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.referral,
                arguments: result,
              ),
              icon: Icons.medical_services_outlined,
            ),
          const SizedBox(height: 20),
          const Text(
            AppConstants.disclaimer,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.secondaryText,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SavedData extends StatelessWidget {
  const _SavedData({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
}
