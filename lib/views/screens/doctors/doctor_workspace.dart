import 'dart:typed_data';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/doctor_case_service.dart';
import '../../../services/screening_history_service.dart';
import '../home/main_shell.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key, this.caseService, this.preferredRole});
  final DoctorCaseService? caseService;
  final String? preferredRole;
  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  late final service = widget.caseService ?? DoctorCaseService();
  late Future<Map<String, dynamic>> profile = service.profile();
  @override
  void dispose() {
    if (widget.caseService == null) service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: profile,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return MainShell(
              connectionUnavailable: true,
              connectionPending: !snapshot.hasError,
              onRetryConnection: () => setState(() {
                profile = service.profile();
              }),
            );
          }
          final value = snapshot.data!;
          final role = value['application_role'];
          if (role == 'admin') return const _AdminLandingScreen();
          if (role == 'doctor') {
            final doctor = value['doctor_profiles'] as Map<String, dynamic>?;
            final state =
                doctor?['verification_state'] as String? ?? 'unavailable';
            return state == 'verified'
                ? DoctorWorkspace(profile: value, caseService: service)
                : _DoctorStatusScreen(
                    state: state,
                    refresh: () => setState(() {
                          profile = service.profile();
                        }));
          }
          if (widget.preferredRole == 'doctor') {
            return Scaffold(
                appBar: AppBar(title: const Text('Doctor access'), actions: [
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await ClerkAuth.of(context, listen: false).signOut();
                      if (context.mounted)
                        Navigator.pushNamedAndRemoveUntil(
                            context, AppRoutes.authChoice, (_) => false);
                    },
                  ),
                ]),
                body: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(22),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text(
                              'No Doctor application is associated with this account.'),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: () => Navigator.pushNamed(
                                  context, AppRoutes.doctorApply),
                              child: const Text('Apply as Doctor')),
                          TextButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                                context, AppRoutes.home, (_) => false),
                            child: const Text('Continue as Patient'),
                          ),
                        ]))));
          }
          if (widget.preferredRole == 'admin') {
            return Scaffold(
                appBar: AppBar(actions: [
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await ClerkAuth.of(context, listen: false).signOut();
                      if (context.mounted)
                        Navigator.pushNamedAndRemoveUntil(
                            context, AppRoutes.authChoice, (_) => false);
                    },
                  )
                ]),
                body: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(22),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text(
                              'Admin access is not assigned to this account.'),
                          TextButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                                context, AppRoutes.home, (_) => false),
                            child: const Text('Continue as Patient'),
                          ),
                        ]))));
          }
          return const MainShell();
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
            tooltip: 'Screening server',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.apiSettings)),
        IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ClerkAuth.of(context, listen: false).signOut();
              if (context.mounted)
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil(
                        AppRoutes.authChoice, (_) => false);
            }),
      ]),
      body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
              children: [
            Text('CLINICAL WORKSPACE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text('Welcome back',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [AppColors.ink, AppColors.inkLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.medical_services_outlined,
                            color: Colors.white, size: 27),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: verified
                              ? AppColors.tealBright.withValues(alpha: .18)
                              : Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          verified
                              ? 'Verification active'
                              : 'Verification ${doctor?['verification_state'] ?? 'pending'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Text(doctor?['display_name'] as String? ?? 'Doctor',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                        doctor?['specialization'] as String? ??
                            'Care professional',
                        style: const TextStyle(color: Color(0xFFD4E7E3))),
                    if (!verified) ...[
                      const SizedBox(height: 12),
                      const Text('Assigned cases are unavailable.',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ]),
            ),
            const SizedBox(height: 24),
            Text('Your workspace',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _WorkspaceAction(
                  icon: Icons.badge_outlined,
                  label: 'My Doctor Profile',
                  color: AppColors.mint,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.doctorProfile),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WorkspaceAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages · Coming Soon',
                  color: AppColors.peachSoft,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.doctorMessages),
                ),
              ),
            ]),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: Text('Assigned cases',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Refresh cases',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() => cases = service.cases()),
              ),
            ]),
            const SizedBox(height: 12),
            if (verified)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: cases,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return TextButton(
                        onPressed: () => setState(() {
                              cases = service.cases();
                            }),
                        child: const Text('Could not load cases. Try again'));
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.isEmpty) return const _WorkspaceEmpty();
                  final rows = snapshot.data!;
                  final counts = <String, int>{};
                  for (final row in rows) {
                    final request =
                        row['review_requests'] as Map<String, dynamic>;
                    final status = request['status'] as String;
                    counts[status] = (counts[status] ?? 0) + 1;
                  }
                  final visible = rows.where((row) =>
                      filter == 'All' ||
                      (row['review_requests']
                              as Map<String, dynamic>)['status'] ==
                          filter);
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                            child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(children: [
                            const Icon(Icons.folder_open_outlined,
                                color: AppColors.teal),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                              '${counts['assigned'] ?? 0} assigned · ${counts['in_review'] ?? 0} in review · ${counts['reviewed'] ?? 0} reviewed',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            )),
                          ]),
                        )),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                                children: [
                              'All',
                              'assigned',
                              'in_review',
                              'reviewed'
                            ]
                                    .map((value) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                            label: Text(
                                                value.replaceAll('_', ' ')),
                                            selected: filter == value,
                                            onSelected: (_) => setState(
                                                () => filter = value))))
                                    .toList())),
                        const SizedBox(height: 12),
                        if (visible.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No cases in this status.'),
                          ),
                        ...visible.map((caseRow) {
                          final request = caseRow['review_requests']
                              as Map<String, dynamic>;
                          return Card(
                              margin: const EdgeInsets.only(top: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.successSoft,
                                  child: Icon(Icons.assignment_outlined,
                                      color: AppColors.teal),
                                ),
                                title: Text('Case ${request['screening_id']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    '${(request['status'] as String).replaceAll('_', ' ')} · Assigned ${caseRow['assigned_at'] ?? 'recently'}'),
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => DoctorCaseScreen(
                                              assignmentId:
                                                  caseRow['id'] as String)));
                                  if (mounted) {
                                    setState(() {
                                      cases = service.cases();
                                    });
                                  }
                                },
                              ));
                        }),
                      ]);
                },
              ),
          ])),
    );
  }
}

class _WorkspaceAction extends StatelessWidget {
  const _WorkspaceAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 112,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: AppColors.ink, size: 25),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _WorkspaceEmpty extends StatelessWidget {
  const _WorkspaceEmpty();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
          child: Column(children: [
            const Icon(Icons.inbox_outlined, size: 38, color: AppColors.teal),
            const SizedBox(height: 12),
            Text('No assigned cases yet.',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'New review requests appear here after an authorized assignment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ]),
        ),
      );
}

class _DoctorStatusScreen extends StatelessWidget {
  const _DoctorStatusScreen({required this.state, required this.refresh});
  final String state;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Doctor verification'), actions: [
        IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ClerkAuth.of(context, listen: false).signOut();
              if (context.mounted)
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.authChoice, (_) => false);
            }),
      ]),
      body: Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    state == 'pending'
                        ? Icons.hourglass_top_rounded
                        : Icons.lock_outline,
                    size: 46,
                    color: AppColors.teal),
                const SizedBox(height: 18),
                Text(
                    switch (state) {
                      'rejected' => 'Application rejected',
                      'suspended' => 'Account suspended',
                      'unavailable' => 'Doctor profile unavailable',
                      _ => 'Application pending',
                    },
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                    switch (state) {
                      'rejected' =>
                        'Your application was not approved. Patient cases are unavailable.',
                      'suspended' =>
                        'Your Doctor access has been suspended. Patient cases are unavailable.',
                      'unavailable' =>
                        'Your verification status could not be loaded. Patient cases are unavailable.',
                      _ =>
                        'An authorized administrator must verify your details before case access is available.',
                    },
                    textAlign: TextAlign.center),
                const SizedBox(height: 22),
                FilledButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh status')),
                if (state != 'unavailable')
                  TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.doctorProfile),
                      child: const Text('My Doctor Profile')),
                TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.apiSettings),
                    child: const Text('Screening server')),
              ]))));
}

class _AdminLandingScreen extends StatelessWidget {
  const _AdminLandingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admin access'), actions: [
          IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ClerkAuth.of(context, listen: false).signOut();
                if (context.mounted)
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.authChoice, (_) => false);
              }),
        ]),
        body: const Center(
            child: Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                    'Admin account recognized. The Admin workspace is under development; no patient or Doctor records are available here.'))),
      );
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
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
                        onPressed: () => setState(() {
                              detail = service.detail(widget.assignmentId);
                            }),
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
              onPressed: () => setState(() {
                image = widget.assets.loadAsset(widget.path!);
              }),
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
