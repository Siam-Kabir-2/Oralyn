import 'dart:typed_data';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/doctor_case_service.dart';
import '../../../services/screening_history_service.dart';
import '../home/main_shell.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key});
  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  final service = DoctorCaseService();
  late Future<Map<String, dynamic>> profile = service.profile();
  @override
  void dispose() {
    service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: profile,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
                body: Center(
                    child: snapshot.hasError
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('Account profile is unavailable.'),
                            TextButton(
                                onPressed: () =>
                                    setState(() => profile = service.profile()),
                                child: const Text('Try again')),
                          ])
                        : const CircularProgressIndicator()));
          }
          final value = snapshot.data!;
          return value['application_role'] == 'doctor'
              ? DoctorWorkspace(profile: value)
              : const MainShell();
        },
      );
}

class DoctorWorkspace extends StatefulWidget {
  const DoctorWorkspace({super.key, required this.profile, this.caseService});
  final Map<String, dynamic> profile;
  final DoctorCaseService? caseService;
  @override
  State<DoctorWorkspace> createState() => _DoctorWorkspaceState();
}

class _DoctorWorkspaceState extends State<DoctorWorkspace> {
  late final service = widget.caseService ?? DoctorCaseService();
  late Future<List<Map<String, dynamic>>> cases = service.cases();
  String filter = 'All';
  @override
  void dispose() {
    if (widget.caseService == null) service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.profile['doctor_profiles'] as Map<String, dynamic>?;
    final verified = doctor?['verification_state'] == 'verified';
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor workspace'), actions: [
        IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ClerkAuth.of(context, listen: false).signOut();
              if (context.mounted)
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.login, (_) => false);
            }),
      ]),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(22), children: [
        Text(doctor?['display_name'] as String? ?? 'Doctor',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(doctor?['specialization'] as String? ?? '',
            style: const TextStyle(color: AppColors.secondaryText)),
        if (doctor != null) ...[
          const SizedBox(height: 8),
          Text('Qualification: ${doctor['qualification'] ?? ''}'),
          Text('Registration: ${doctor['registration_reference'] ?? ''}'),
        ],
        const SizedBox(height: 20),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  verified
                      ? 'Verification active'
                      : 'Verification ${doctor?['verification_state'] ?? 'pending'}. Assigned cases are unavailable.',
                ))),
        const SizedBox(height: 24),
        Text('Assigned cases', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (verified)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: cases,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return TextButton(
                    onPressed: () => setState(() => cases = service.cases()),
                    child: const Text('Could not load cases. Try again'));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty)
                return const Text('No assigned cases yet.');
              final rows = snapshot.data!;
              final counts = <String, int>{};
              for (final row in rows) {
                final request = row['review_requests'] as Map<String, dynamic>;
                final status = request['status'] as String;
                counts[status] = (counts[status] ?? 0) + 1;
              }
              final visible = rows.where((row) =>
                  filter == 'All' ||
                  (row['review_requests'] as Map<String, dynamic>)['status'] ==
                      filter);
              return Column(children: [
                Text(
                    '${counts['assigned'] ?? 0} assigned · ${counts['in_review'] ?? 0} in review · ${counts['reviewed'] ?? 0} reviewed'),
                const SizedBox(height: 12),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        children: ['All', 'assigned', 'in_review', 'reviewed']
                            .map((value) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                    label: Text(value.replaceAll('_', ' ')),
                                    selected: filter == value,
                                    onSelected: (_) =>
                                        setState(() => filter = value))))
                            .toList())),
                const SizedBox(height: 12),
                if (visible.isEmpty) const Text('No cases in this status.'),
                ...visible.map((caseRow) {
                  final request =
                      caseRow['review_requests'] as Map<String, dynamic>;
                  return Card(
                      child: ListTile(
                    title: Text('Case ${request['screening_id']}'),
                    subtitle: Text(
                        'Status: ${request['status']}\nAssigned: ${caseRow['assigned_at'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => DoctorCaseScreen(
                                assignmentId: caseRow['id'] as String))),
                  ));
                }),
              ]);
            },
          ),
      ])),
    );
  }
}

class DoctorCaseScreen extends StatefulWidget {
  const DoctorCaseScreen({super.key, required this.assignmentId});
  final String assignmentId;
  @override
  State<DoctorCaseScreen> createState() => _DoctorCaseScreenState();
}

class _DoctorCaseScreenState extends State<DoctorCaseScreen> {
  final service = DoctorCaseService();
  final assets = ScreeningHistoryApiRepository();
  late Future<Map<String, dynamic>> detail =
      service.detail(widget.assignmentId);
  final observations = TextEditingController();
  final recommendations = TextEditingController();
  final followUp = TextEditingController();
  int version = 0;
  bool saving = false;
  bool hydrated = false;
  bool dirty = false;
  bool submitted = false;
  String? error;
  @override
  void initState() {
    super.initState();
    observations.addListener(_markDirty);
    recommendations.addListener(_markDirty);
    followUp.addListener(_markDirty);
  }

  void _markDirty() {
    if (hydrated && !dirty && !submitted && mounted)
      setState(() => dirty = true);
  }

  Future<void> _confirmLeave(bool didPop) async {
    if (didPop || !dirty || submitted) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved review?'),
        content: const Text('Your changes have not been saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard')),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => dirty = false);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    service.close();
    assets.close();
    observations.dispose();
    recommendations.dispose();
    followUp.dispose();
    super.dispose();
  }

  Future<void> _save(bool submit) async {
    if (observations.text.trim().isEmpty ||
        recommendations.text.trim().isEmpty ||
        followUp.text.trim().isEmpty) {
      setState(() => error = 'Complete all review fields before saving.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await service.saveReview(widget.assignmentId,
          expectedVersion: version,
          observations: observations.text.trim(),
          recommendations: recommendations.text.trim(),
          followUp: followUp.text.trim(),
          submit: submit);
      if (!mounted) return;
      version = saved['review_version'] as int;
      setState(() {
        dirty = false;
        submitted = submit;
        detail = service.detail(widget.assignmentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(submit ? 'Review submitted.' : 'Draft saved.')));
    } on DoctorCaseException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !dirty || submitted,
      onPopInvokedWithResult: (didPop, _) => _confirmLeave(didPop),
      child: Scaffold(
        appBar: AppBar(title: const Text('Assigned case')),
        body: FutureBuilder<Map<String, dynamic>>(
            future: detail,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                    child: TextButton(
                        onPressed: () => setState(
                            () => detail = service.detail(widget.assignmentId)),
                        child: const Text('Case unavailable. Try again')));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final screening =
                  snapshot.data!['screening'] as Map<String, dynamic>;
              final review = snapshot.data!['review'] as Map<String, dynamic>?;
              if (!hydrated) {
                version = review?['version'] as int? ?? 0;
                observations.text = review?['observations'] as String? ?? '';
                recommendations.text =
                    review?['recommendations'] as String? ?? '';
                followUp.text = review?['follow_up'] as String? ?? '';
                hydrated = true;
              }
              submitted = submitted || review?['state'] == 'submitted';
              return ListView(padding: const EdgeInsets.all(22), children: [
                Text('AI assisted screening',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Category: ${screening['primary_prediction']}'),
                Text('Model score: ${screening['primary_score']}'),
                Text('Guidance: ${screening['screening_status']}'),
                const SizedBox(height: 8),
                for (final score
                    in (screening['primary_predictions'] as List? ?? const []))
                  if (score is Map)
                    Text(
                        '${score['class'] ?? score['label'] ?? 'Class'}: ${score['score'] ?? score['confidence'] ?? ''}'),
                if ((screening['cancer_verification'] as Map?)?['performed'] ==
                    true)
                  Text(
                      'Secondary verification: ${screening['cancer_verification']}'),
                const SizedBox(height: 12),
                const Text('Original oral image'),
                _CaseImage(
                    path: screening['image_path'] as String?, assets: assets),
                const SizedBox(height: 12),
                const Text(
                    'Grad-CAM visual explanation (not lesion segmentation)'),
                _CaseImage(
                    path: (screening['gradcam']
                        as Map<String, dynamic>)['asset_path'] as String?,
                    assets: assets),
                const SizedBox(height: 24),
                Text('Professional review',
                    style: Theme.of(context).textTheme.titleLarge),
                for (final field in [
                  (observations, 'Clinical observations'),
                  (recommendations, 'Recommendations'),
                  (followUp, 'Suggested follow up'),
                ])
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: field.$1,
                        enabled: !submitted,
                        maxLines: 4,
                        maxLength:
                            field.$2 == 'Suggested follow up' ? 2000 : 4000,
                        decoration: InputDecoration(
                            labelText: field.$2,
                            border: const OutlineInputBorder()),
                      )),
                if (error != null)
                  Text(error!, style: const TextStyle(color: AppColors.danger)),
                if (!submitted) ...[
                  OutlinedButton(
                      onPressed: saving ? null : () => _save(false),
                      child: const Text('Save draft')),
                  FilledButton(
                      onPressed: saving ? null : () => _save(true),
                      child: const Text('Submit review')),
                ] else
                  const Text('Submitted review is read only.'),
              ]);
            }),
      ));
}

class _CaseImage extends StatefulWidget {
  const _CaseImage({required this.path, required this.assets});
  final String? path;
  final ScreeningHistoryApiRepository assets;
  @override
  State<_CaseImage> createState() => _CaseImageState();
}

class _CaseImageState extends State<_CaseImage> {
  Future<Uint8List>? image;
  @override
  void initState() {
    super.initState();
    if (widget.path != null) image = widget.assets.loadAsset(widget.path!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.path == null) return const Text('Image unavailable.');
    return FutureBuilder<Uint8List>(
        future: image,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () =>
                  setState(() => image = widget.assets.loadAsset(widget.path!)),
              child: const Text('Private image unavailable. Try again'),
            );
          }
          if (!snapshot.hasData)
            return const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator()));
          return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child:
                  Image.memory(snapshot.data!, height: 220, fit: BoxFit.cover));
        });
  }
}
