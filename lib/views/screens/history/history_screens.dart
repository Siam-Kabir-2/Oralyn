import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../controllers/history_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/screening_result.dart';
import '../../../services/screening_history_service.dart';
import '../../../services/screening_history_updates.dart';
import '../../../services/review_request_service.dart';
import '../../../services/case_message_service.dart';
import '../doctors/verified_doctor_screens.dart';
import '../messages/case_chat_screen.dart';
import '../../widgets/common/app_components.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.standalone = false, this.repository});
  final bool standalone;
  final ScreeningHistoryRepository? repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final ScreeningHistoryRepository repository =
      widget.repository ?? ScreeningHistoryApiRepository();
  late final controller = HistoryController(repository);
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
    ScreeningHistoryUpdates.instance.addListener(_onScreeningSaved);
    controller.load();
  }

  void _onScreeningSaved() => controller.load();

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    ScreeningHistoryUpdates.instance.removeListener(_onScreeningSaved);
    controller.dispose();
    if (widget.repository == null) repository.close();
    super.dispose();
  }

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
          if (controller.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.error != null)
            _HistoryMessage(
              icon: Icons.cloud_off_outlined,
              message: controller.error!,
              actionLabel: 'Try again',
              onAction: controller.load,
            )
          else if (controller.filtered(filter).isEmpty)
            const _HistoryMessage(
              icon: Icons.history_rounded,
              message: 'No saved screenings yet.',
            )
          else
            ...controller.filtered(filter).map(
                  (result) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ScreeningCard(
                      result: result,
                      onTap: () async {
                        final deleted = await Navigator.pushNamed(
                          context,
                          AppRoutes.historyDetail,
                          arguments: result,
                        );
                        if (deleted == true) controller.load();
                      },
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
  const HistoryDetailScreen({
    super.key,
    required this.result,
    this.repository,
  });
  final ScreeningResult result;
  final ScreeningHistoryRepository? repository;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  bool explanation = false;
  bool deleting = false;
  bool requestingReview = false;
  ReviewRequestStatus? reviewRequest;
  Map<String, dynamic>? doctorFeedback;
  String? reviewError;
  String? preferredDoctorName;
  CaseConversation? conversation;
  final reviewService = ReviewRequestService();
  final messageService = CaseMessageService();
  late final ScreeningHistoryRepository repository =
      widget.repository ?? ScreeningHistoryApiRepository();
  late final Future<Uint8List?> image = _load(widget.result.imagePath);
  late final Future<Uint8List?> gradCam = _load(widget.result.gradCamAssetPath);

  @override
  void initState() {
    super.initState();
    _loadReviewStatus();
  }

  Future<void> _loadReviewStatus() async {
    try {
      final requests = await reviewService.list();
      if (!mounted) return;
      for (final item in requests) {
        if (item.screeningId == widget.result.id) {
          setState(() {
            reviewRequest = item;
            preferredDoctorName = item.preferredDoctorName;
          });
          break;
        }
      }
      final feedback = await reviewService.feedback();
      if (!mounted) return;
      for (final item in feedback) {
        if (item['screening_id'] == widget.result.id) {
          setState(() => doctorFeedback = item);
          break;
        }
      }
      try {
        final conversations = await messageService.conversations();
        if (!mounted) return;
        for (final item in conversations) {
          if (item.screeningId == widget.result.id) {
            setState(() => conversation = item);
            break;
          }
        }
      } on CaseMessageException {
        // Review status remains available while messaging is offline.
      }
    } catch (_) {
      if (mounted)
        setState(() => reviewError = 'Review status is unavailable.');
    }
  }

  Future<void> _requestReview() async {
    Map<String, dynamic>? doctor;
    if (reviewRequest?.status == 'pending_assignment' &&
        reviewRequest?.preferredDoctorDirectoryId != null) {
      doctor = {
        'directory_id': reviewRequest!.preferredDoctorDirectoryId,
        'display_name': preferredDoctorName ?? 'Selected Doctor',
      };
    } else {
      doctor = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Choose a Doctor')),
            body: const VerifiedDoctorDirectory(selecting: true),
          ),
        ),
      );
    }
    if (doctor == null || !mounted) return;
    final directoryId = doctor['directory_id'] as String?;
    if (directoryId == null) return;
    final doctorName = doctor['display_name'] as String? ?? 'Selected Doctor';
    final consented = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign this Doctor?'),
        content: Text(
          '$doctorName will immediately receive access to this saved oral image, AI screening result, and visual explanation. You can message the Doctor about this case. Only choose this if you consent to share the case.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Consent and assign')),
        ],
      ),
    );
    if (consented != true || !mounted) return;
    setState(() => requestingReview = true);
    try {
      final result = await reviewService.request(widget.result.id,
          preferredDoctorDirectoryId: directoryId);
      if (mounted)
        setState(() {
          reviewRequest = result;
          preferredDoctorName = doctorName;
          reviewError = null;
        });
      await _loadReviewStatus();
    } on ReviewRequestException catch (error) {
      if (mounted) setState(() => reviewError = error.message);
    } catch (_) {
      if (mounted)
        setState(() => reviewError = 'Review request failed. Try again.');
    } finally {
      if (mounted) setState(() => requestingReview = false);
    }
  }

  Future<Uint8List?> _load(String? path) async {
    if (path == null) return null;
    return repository.loadAsset(path);
  }

  @override
  void dispose() {
    reviewService.close();
    messageService.close();
    if (widget.repository == null) repository.close();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved screening?'),
        content: const Text(
          'The saved result, original image, and visual explanation will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    try {
      await repository.delete(widget.result.id);
      if (mounted) Navigator.pop(context, true);
    } on ScreeningHistoryException catch (error) {
      if (mounted) {
        setState(() => deleting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

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
          _PrivateImage(future: image, height: 220),
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
            label: 'Model score',
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
            secondChild: widget.result.gradCamAssetPath == null
                ? const GradCamPlaceholder()
                : _PrivateImage(future: gradCam, height: 220),
          ),
          const SizedBox(height: 24),
          if (reviewRequest != null)
            _SavedData(
                label: 'Doctor review',
                value: switch (reviewRequest!.status) {
                  'pending_assignment' => 'Waiting for assignment',
                  'assigned' => 'Assigned to Doctor',
                  'in_review' => 'In review',
                  'reviewed' => 'Reviewed',
                  final status => status,
                }),
          if (reviewRequest == null ||
              reviewRequest!.status == 'pending_assignment')
            OutlinedButton.icon(
              onPressed: requestingReview ? null : _requestReview,
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(requestingReview
                  ? 'Assigning Doctor…'
                  : 'Assign a verified Doctor'),
            ),
          if (reviewRequest != null && preferredDoctorName != null)
            _SavedData(label: 'Selected Doctor', value: preferredDoctorName!),
          if (reviewError != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(reviewError!,
                    style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          if (result.risk != RiskLevel.lowConcern)
            PrimaryButton(
              label: 'Find verified Doctors',
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.doctorSearch,
              ),
              icon: Icons.medical_services_outlined,
            ),
          if (doctorFeedback != null) ...[
            const SizedBox(height: 20),
            Text('Doctor feedback',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _SavedData(
                label: 'Doctor',
                value: doctorFeedback!['doctor_name'] as String? ?? ''),
            _SavedData(
                label: 'Specialization',
                value: doctorFeedback!['specialization'] as String? ?? ''),
            _SavedData(
                label: 'Observations',
                value: doctorFeedback!['observations'] as String? ?? ''),
            _SavedData(
                label: 'Recommendations',
                value: doctorFeedback!['recommendations'] as String? ?? ''),
            _SavedData(
                label: 'Follow up',
                value: doctorFeedback!['follow_up'] as String? ?? ''),
          ],
          const SizedBox(height: 20),
          Card(
              child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Private case messages',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(conversation == null
                    ? 'Assign this screening to a verified Doctor to open a private conversation.'
                    : conversation!.isActive
                        ? 'Only you and the assigned verified Doctor can exchange case messages. This is not an emergency service.'
                        : 'This assignment is closed. You can read your earlier messages.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: conversation == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => CaseThreadScreen(
                                conversation: conversation!,
                                isDoctor: false,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open messages'),
                ),
              ],
            ),
          )),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: deleting ? null : _delete,
            icon: deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: Text(deleting ? 'Deleting…' : 'Delete saved screening'),
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

class _PrivateImage extends StatelessWidget {
  const _PrivateImage({required this.future, required this.height});
  final Future<Uint8List?> future;
  final double height;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              height: height,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                snapshot.data!,
                height: height,
                width: double.infinity,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            );
          }
          return AppImagePlaceholder(
            height: height,
            label: 'Private image unavailable',
          );
        },
      );
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(icon, size: 34, color: AppColors.secondaryText),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );
}
