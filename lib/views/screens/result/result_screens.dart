import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/screening_result.dart';
import '../../../models/screening_session.dart';
import '../../../services/screening_history_service.dart';
import '../../widgets/common/app_components.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.outcome,
    this.historyRepository,
  });
  final ScreeningOutcome outcome;
  final ScreeningHistoryRepository? historyRepository;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final ScreeningHistoryRepository historyRepository =
      widget.historyRepository ?? ScreeningHistoryApiRepository();
  late final String idempotencyKey = _newIdempotencyKey();
  bool saving = false;
  bool saved = false;

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(18, (_) => random.nextInt(256)),
    );
    return 'mobile_${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  @override
  void dispose() {
    if (widget.historyRepository == null) historyRepository.close();
    super.dispose();
  }

  Future<void> _save() async {
    final photo = widget.outcome.photo;
    if (photo == null || saving || saved) return;
    setState(() => saving = true);
    try {
      await historyRepository.save(photo, idempotencyKey: idempotencyKey);
      if (!mounted) return;
      setState(() {
        saving = false;
        saved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Screening saved to your private history.')),
      );
    } on ScreeningHistoryException catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on FormatException {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('The saved result could not be verified.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.outcome.result;
    final overlayBytes = _decodeDataImage(result.gradCamImageBase64);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Screening result'),
        leading: IconButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to home',
        ),
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing is not available yet.')),
            ),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share result',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          children: [
            _ResultIntroduction(result: result),
            const SizedBox(height: 22),
            _AttentionPhoto(
              overlayBytes: overlayBytes,
              photo: widget.outcome.photo,
              label: result.gradCamLabel ?? 'Area highlighted for review',
            ),
            const SizedBox(height: 14),
            _ResultSignals(result: result),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.referral,
                  arguments: result,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined, size: 21),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Find a dental professional',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 21),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        widget.outcome.photo == null || saved ? null : _save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(saved
                            ? Icons.bookmark_added_rounded
                            : Icons.bookmark_border_rounded),
                    label: Text(
                      saving ? 'Saving…' : (saved ? 'Saved' : 'Save result'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.history,
                    ),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('View history'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _WhatHappensNext(),
            const SizedBox(height: 20),
            _ResultDetails(result: result),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.apiDisclaimer ?? AppConstants.disclaimer,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Uint8List? _decodeDataImage(String? value) {
  if (value == null || value.isEmpty) return null;
  final separator = value.indexOf(',');
  if (separator < 0 || separator == value.length - 1) return null;
  try {
    return base64Decode(value.substring(separator + 1));
  } on FormatException {
    return null;
  }
}

class _ResultIntroduction extends StatelessWidget {
  const _ResultIntroduction({required this.result});
  final ScreeningResult result;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 62),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: AppColors.success,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Screening complete',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(result.status,
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 10),
                Text(
                  result.summary,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 58,
              height: 74,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.health_and_safety_outlined,
                      color: AppColors.ink, size: 24),
                  SizedBox(height: 5),
                  Text(
                    'Oral\nscreening',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, height: 1.15),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _AttentionPhoto extends StatelessWidget {
  const _AttentionPhoto({
    required this.overlayBytes,
    required this.photo,
    required this.label,
  });
  final Uint8List? overlayBytes;
  final ScreeningPhoto? photo;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bytes = overlayBytes ?? photo?.bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 1.35,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            else
              const AppImagePlaceholder(
                height: 260,
                icon: Icons.image_outlined,
                label: 'Screening image unavailable',
              ),
            if (overlayBytes != null)
              Positioned(
                right: 14,
                top: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 4,
                        backgroundColor: Color(0xFFEF7F7E),
                      ),
                      const SizedBox(width: 7),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultSignals extends StatelessWidget {
  const _ResultSignals({required this.result});
  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    final verification = result.cancerVerificationPerformed
        ? 'Second model reviewed'
        : 'Not run';
    return Row(
      children: [
        Expanded(
          child: _SignalTile(
            icon: Icons.center_focus_strong_outlined,
            color: const Color(0xFFE4F0FF),
            title: 'Attention',
            value: result.gradCamAvailable ? 'Overlay ready' : 'Unavailable',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SignalTile(
            icon: Icons.insights_outlined,
            color: const Color(0xFFFFEFDC),
            title: 'Model score',
            value: '${(result.confidence * 100).round()}%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SignalTile(
            icon: Icons.fact_check_outlined,
            color: const Color(0xFFEEE7FF),
            title: 'Verification',
            value: verification,
          ),
        ),
      ],
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        height: 116,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: AppColors.ink),
            ),
            const Spacer(),
            Text(title,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10,
                height: 1.15,
              ),
            ),
          ],
        ),
      );
}

class _WhatHappensNext extends StatelessWidget {
  const _WhatHappensNext();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What happens next',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                  child: _NextStepItem(
                      icon: Icons.person_outline_rounded,
                      label: '1. Show to a dentist')),
              Expanded(
                  child: _NextStepItem(
                      icon: Icons.calendar_month_outlined,
                      label: '2. Get a professional check')),
              Expanded(
                  child: _NextStepItem(
                      icon: Icons.visibility_outlined,
                      label: '3. Monitor for changes')),
            ],
          ),
        ],
      );
}

class _NextStepItem extends StatelessWidget {
  const _NextStepItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.ink, size: 21),
          ),
          const SizedBox(height: 9),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, height: 1.3)),
        ],
      );
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({required this.result});
  final ScreeningResult result;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text('Screening and model details'),
          leading: const Icon(Icons.insights_outlined),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ConfidenceBar(value: result.confidence),
            if (result.topPredictions.isNotEmpty) ...[
              const SizedBox(height: 18),
              _TopPredictions(predictions: result.topPredictions),
            ],
            if (result.cancerVerificationPerformed) ...[
              const SizedBox(height: 12),
              _CancerVerification(result: result),
            ],
          ],
        ),
      );
}

// Retained for saved-report compatibility while the new result layout is used.
// ignore: unused_element
class _ScreeningBanner extends StatelessWidget {
  const _ScreeningBanner({required this.disclaimer});

  final String disclaimer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0D9A9)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.science_outlined,
              color: AppColors.warning,
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                disclaimer,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

// ignore: unused_element
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
              semanticLabel: 'Photo used for this screening',
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
                          ? 'Captured and uploaded for this screening'
                          : 'Selected and uploaded for this screening',
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

// ignore: unused_element
class _ModelSummary extends StatelessWidget {
  const _ModelSummary({required this.result});

  final ScreeningResult result;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2F6),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            const Icon(Icons.memory_outlined, color: AppColors.blue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                result.modelVersion == null || result.modelVersion!.isEmpty
                    ? 'Analyzed with ${result.model}'
                    : 'Analyzed with ${result.model} • ${result.modelVersion}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CancerVerification extends StatelessWidget {
  const _CancerVerification({required this.result});

  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    final higherConcern = result.cancerVerificationPrediction == 'Cancer';
    final score = result.cancerVerificationScore;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            higherConcern ? const Color(0xFFFFF3EA) : const Color(0xFFEAF5F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              higherConcern ? const Color(0xFFE8C5A7) : const Color(0xFFB9DCD3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Additional verification signal'),
          const SizedBox(height: 10),
          Text(
            higherConcern
                ? 'Higher-concern verification signal'
                : 'Lower-concern verification signal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (score != null) ...[
            const SizedBox(height: 6),
            Text(
              'Model score: ${(score * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 9),
          const Text(
            'A second research model reviewed this image because the first '
            'screening model flagged it for professional review. This signal '
            'cannot confirm or rule out cancer.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (result.verificationModel != null) ...[
            const SizedBox(height: 8),
            Text(
              result.verificationModel!,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopPredictions extends StatelessWidget {
  const _TopPredictions({required this.predictions});

  final List<ClassScore> predictions;

  String _labelFor(String className) {
    switch (className) {
      case 'Normal':
        return 'Normal pattern';
      case 'Variation_from_Normal':
        return 'Variation from normal';
      case 'OPMD':
        return 'OPMD-related pattern';
      case 'Oral_Cancer':
        return 'Pattern requiring specialist review';
      default:
        return className.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Model score breakdown'),
          const SizedBox(height: 6),
          Text(
            'These scores describe model similarity, not the probability of a diagnosis.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 14),
          ...predictions.map(
            (prediction) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _labelFor(prediction.className),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${(prediction.score * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: prediction.score,
                      minHeight: 7,
                      backgroundColor: AppColors.divider,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

// ignore: unused_element
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

// ignore: unused_element
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.result});
  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    final (accent, soft, icon) = switch (result.risk) {
      RiskLevel.lowConcern => (
          AppColors.success,
          AppColors.successSoft,
          Icons.check_rounded,
        ),
      RiskLevel.professionalReview => (
          AppColors.warning,
          AppColors.warningSoft,
          Icons.calendar_month_outlined,
        ),
      RiskLevel.promptSpecialistReview => (
          AppColors.danger,
          AppColors.dangerSoft,
          Icons.priority_high_rounded,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, soft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .09),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(child: StatusBadge(risk: result.risk)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'SCREENING GUIDANCE',
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            result.status,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 27),
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

// ignore: unused_element
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
                  content: Text('Saving results is not available yet.'),
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
