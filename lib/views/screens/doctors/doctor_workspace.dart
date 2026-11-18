import 'dart:typed_data';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/doctor_case_service.dart';
import '../../../services/screening_history_service.dart';
import '../../../services/case_message_service.dart';
import '../home/main_shell.dart';
import '../messages/case_chat_screen.dart';
import 'doctor_account_screens.dart';

String _caseCode(Object? screeningId) {
  final value = screeningId is String ? screeningId : '';
  final prefix = value.length >= 8 ? value.substring(0, 8) : value;
  return prefix.isEmpty ? 'New case' : 'OR-${prefix.toUpperCase()}';
}

String _caseDate(Object? timestamp) {
  final date = DateTime.tryParse('$timestamp')?.toLocal();
  if (date == null) return 'Recently';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _caseStatus(Object? status) => switch (status) {
      'assigned' => 'Awaiting review',
      'in_review' => 'In progress',
      'reviewed' => 'Review submitted',
      'closed' => 'Closed',
      _ => 'Assigned case',
    };

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
            final retry = () => setState(() {
                  profile = service.profile();
                });
            if (widget.preferredRole == 'patient') {
              return MainShell(
                connectionUnavailable: true,
                connectionPending: !snapshot.hasError,
                onRetryConnection: retry,
              );
            }
            return _RoleConnectionScreen(
              preferredRole: widget.preferredRole,
              pending: !snapshot.hasError,
              retry: retry,
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

class _RoleConnectionScreen extends StatelessWidget {
  const _RoleConnectionScreen({
    required this.preferredRole,
    required this.pending,
    required this.retry,
  });

  final String? preferredRole;
  final bool pending;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final workspace = preferredRole == 'doctor'
        ? 'Doctor workspace'
        : preferredRole == 'admin'
            ? 'Admin access'
            : 'Your workspace';
    return Scaffold(
      appBar: AppBar(title: Text(workspace)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.successSoft,
                  child: Icon(
                    preferredRole == 'doctor'
                        ? Icons.medical_services_outlined
                        : Icons.shield_outlined,
                    color: AppColors.teal,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  pending ? 'Checking account access' : 'Connect to continue',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  pending
                      ? 'Oralyn is checking your role with the screening server.'
                      : 'The screening server could not confirm your account role. Check its URL, then retry. Doctor cases remain private until your verified role is confirmed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 28),
                if (pending)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  FilledButton.icon(
                    onPressed: retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry connection'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, AppRoutes.apiSettings);
                      if (context.mounted) retry();
                    },
                    icon: const Icon(Icons.settings_ethernet),
                    label: const Text('Screening server settings'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MainShell(
                          connectionUnavailable: true,
                          onRetryConnection: () {
                            Navigator.of(context).pop();
                            retry();
                          },
                        ),
                      ),
                    ),
                    child: const Text('Browse general app'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorWorkspace extends StatefulWidget {
  const DoctorWorkspace({
    super.key,
    required this.profile,
    this.caseService,
    this.messageService,
  });
  final Map<String, dynamic> profile;
  final DoctorCaseService? caseService;
  final CaseMessageService? messageService;
  @override
  State<DoctorWorkspace> createState() => _DoctorWorkspaceState();
}

class _DoctorWorkspaceState extends State<DoctorWorkspace> {
  late final service = widget.caseService ?? DoctorCaseService();
  late final messageService = widget.messageService ?? CaseMessageService();
  late Future<List<Map<String, dynamic>>> cases = service.cases();
  int tab = 0;
  CaseConversation? selectedConversation;

  void refreshCases() => setState(() => cases = service.cases());
  @override
  void dispose() {
    if (widget.caseService == null) service.close();
    if (widget.messageService == null) messageService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.profile['doctor_profiles'] as Map<String, dynamic>?;
    final verified = doctor?['verification_state'] == 'verified';
    return PopScope(
      canPop: tab == 0 && selectedConversation == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selectedConversation != null) {
          setState(() => selectedConversation = null);
        } else if (tab != 0) {
          setState(() => tab = 0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
            leading: selectedConversation == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back to conversations',
                    onPressed: () =>
                        setState(() => selectedConversation = null),
                  ),
            title: Text(selectedConversation != null
                ? 'Case messages'
                : const [
                    'Doctor workspace',
                    'Assigned cases',
                    'Reviews',
                    'Messages',
                    'My profile'
                  ][tab]),
            actions: [
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
        body: IndexedStack(index: tab, children: [
          SafeArea(
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                  children: [
                Text('Your workspace',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [AppColors.ink, AppColors.inkLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.medical_services_outlined,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctor?['display_name'] as String? ?? 'Doctor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white)),
                          Text(
                              doctor?['specialization'] as String? ??
                                  'Care professional',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFD4E7E3))),
                          const SizedBox(height: 8),
                          Text(
                            verified
                                ? 'Verification active'
                                : 'Verification ${doctor?['verification_state'] ?? 'pending'}',
                            style: const TextStyle(
                                color: AppColors.tealBright,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _WorkspaceAction(
                      icon: Icons.folder_open_outlined,
                      label: 'Cases',
                      color: AppColors.mint,
                      onTap: () => setState(() {
                        cases = service.cases();
                        tab = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WorkspaceAction(
                      icon: Icons.chat_bubble_outline,
                      label: 'Messages',
                      color: AppColors.peachSoft,
                      onTap: () => setState(() => tab = 3),
                    ),
                  ),
                ]),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: Text('Recent assignments',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Refresh cases',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => setState(() => cases = service.cases()),
                  ),
                  TextButton(
                    onPressed: () => setState(() => tab = 1),
                    child: const Text('View all'),
                  ),
                ]),
                const SizedBox(height: 6),
                if (verified)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: cases,
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return TextButton(
                            onPressed: () => setState(() {
                                  cases = service.cases();
                                }),
                            child:
                                const Text('Could not load cases. Try again'));
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      if (snapshot.data!.isEmpty)
                        return const _WorkspaceEmpty();
                      final rows = snapshot.data!;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...rows.take(3).map((caseRow) {
                              final request = caseRow['review_requests']
                                  as Map<String, dynamic>;
                              return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 2),
                                    leading: const CircleAvatar(
                                      backgroundColor: AppColors.successSoft,
                                      child: Icon(Icons.assignment_outlined,
                                          color: AppColors.teal),
                                    ),
                                    title: Text(
                                        'Case ${_caseCode(request['screening_id'])}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                        '${_caseStatus(request['status'])} · ${_caseDate(caseRow['assigned_at'])}'),
                                    trailing:
                                        const Icon(Icons.chevron_right_rounded),
                                    onTap: () async {
                                      await Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                              builder: (_) => DoctorCaseScreen(
                                                  assignmentId: caseRow['id']
                                                      as String)));
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
          if (verified && tab == 1)
            _DoctorCaseQueue(
              cases: cases,
              onRefresh: refreshCases,
              reviewsOnly: false,
            )
          else
            const SizedBox(),
          if (verified && tab == 2)
            _DoctorCaseQueue(
              cases: cases,
              onRefresh: refreshCases,
              reviewsOnly: true,
            )
          else
            const SizedBox(),
          if (tab == 3)
            selectedConversation == null
                ? DoctorMessagesScreen(
                    embedded: true,
                    service: messageService,
                    onOpen: (conversation) =>
                        setState(() => selectedConversation = conversation),
                  )
                : CaseThreadScreen(
                    conversation: selectedConversation!,
                    isDoctor: true,
                    embedded: true,
                    service: messageService,
                    onBack: () => setState(() => selectedConversation = null),
                  )
          else
            const SizedBox(),
          if (tab == 4)
            DoctorProfileScreen(embedded: true, caseService: service)
          else
            const SizedBox(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() {
            if (value != 3) selectedConversation = null;
            if (value == 1 || value == 2) cases = service.cases();
            tab = value;
          }),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard'),
            NavigationDestination(
                icon: Icon(Icons.folder_open_outlined),
                selectedIcon: Icon(Icons.folder_open),
                label: 'Cases'),
            NavigationDestination(
                icon: Icon(Icons.rate_review_outlined),
                selectedIcon: Icon(Icons.rate_review),
                label: 'Reviews'),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Messages'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _DoctorCaseQueue extends StatefulWidget {
  const _DoctorCaseQueue({
    required this.cases,
    required this.onRefresh,
    required this.reviewsOnly,
  });

  final Future<List<Map<String, dynamic>>> cases;
  final VoidCallback onRefresh;
  final bool reviewsOnly;

  @override
  State<_DoctorCaseQueue> createState() => _DoctorCaseQueueState();
}

class _DoctorCaseQueueState extends State<_DoctorCaseQueue> {
  final search = TextEditingController();
  String status = 'All';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Widget _caseCard(Map<String, dynamic> row) {
    final request = row['review_requests'] as Map<String, dynamic>? ?? {};
    final id = row['id'] as String?;
    final code = _caseCode(request['screening_id']);
    final state = _caseStatus(request['status']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: id == null
            ? null
            : () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DoctorCaseScreen(assignmentId: id),
                    ));
                if (mounted) widget.onRefresh();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.folder_shared_outlined,
                  color: AppColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Case $code',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text('$state · ${_caseDate(row['assigned_at'])}',
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 12)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondaryText),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Row(children: [
              Expanded(
                child: Text(
                    widget.reviewsOnly ? 'Review queue' : 'Assigned cases',
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              IconButton(
                onPressed: widget.onRefresh,
                tooltip: 'Refresh cases',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
                widget.reviewsOnly
                    ? 'Review assigned screenings and submit feedback.'
                    : 'Cases shared with your verified account.',
                style: const TextStyle(color: AppColors.secondaryText)),
            const SizedBox(height: 16),
            if (!widget.reviewsOnly) ...[
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search case code',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final value in [
                    'All',
                    'assigned',
                    'in_review',
                    'reviewed'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(value.replaceAll('_', ' ')),
                        selected: status == value,
                        onSelected: (_) => setState(() => status = value),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.cases,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      const Text(
                          'Cases are unavailable. Check your connection.'),
                      TextButton.icon(
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ]),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!.where((row) {
                  final request =
                      row['review_requests'] as Map<String, dynamic>? ?? {};
                  final value = request['status'] as String? ?? '';
                  return (widget.reviewsOnly ||
                          status == 'All' ||
                          value == status) &&
                      (widget.reviewsOnly ||
                          '${request['screening_id']}'
                              .toLowerCase()
                              .contains(search.text.trim().toLowerCase()));
                }).toList();
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(snapshot.data!.isEmpty
                        ? 'No assigned cases yet.'
                        : 'No cases match this view.'),
                  );
                }
                if (!widget.reviewsOnly) {
                  return Column(children: rows.map(_caseCard).toList());
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in [
                      ('assigned', 'Awaiting review'),
                      ('in_review', 'In progress'),
                      ('reviewed', 'Submitted reviews'),
                      ('closed', 'Closed cases'),
                    ]) ...[
                      if (rows.any((row) =>
                          (row['review_requests'] as Map?)?['status'] ==
                          group.$1)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                          child: Text(group.$2,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        ...rows
                            .where((row) =>
                                (row['review_requests'] as Map?)?['status'] ==
                                group.$1)
                            .map(_caseCard),
                      ],
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
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
            height: 82,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.ink, size: 23),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
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
  final messageService = CaseMessageService();
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
    messageService.close();
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

  Future<void> _openMessages() async {
    try {
      final conversations = await messageService.conversations();
      if (!mounted) return;
      for (final conversation in conversations) {
        if (conversation.assignmentId == widget.assignmentId) {
          await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CaseThreadScreen(
                    conversation: conversation, isDoctor: true),
              ));
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This case conversation is no longer available.'),
      ));
    } on CaseMessageException catch (failure) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
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
              final score = screening['primary_score'];
              final scoreLabel = score is num
                  ? '${(score * 100).toStringAsFixed(0)}% model score'
                  : 'Model score unavailable';
              final category = '${screening['primary_prediction'] ?? 'Unknown'}'
                  .replaceAll('_', ' ');
              final gradcam = screening['gradcam'] as Map? ?? const {};
              final verification =
                  screening['cancer_verification'] as Map? ?? const {};
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
                children: [
                  Text('ASSIGNED CASE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4)),
                  const SizedBox(height: 5),
                  Text('Case ${_caseCode(screening['id'])}',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                      'Assigned for professional review · '
                      '${_caseDate(screening['created_at'])}',
                      style: const TextStyle(color: AppColors.secondaryText)),
                  const SizedBox(height: 18),
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.auto_awesome_rounded,
                              color: AppColors.teal, size: 20),
                          const SizedBox(width: 9),
                          Expanded(
                              child: Text('AI screening summary',
                                  style:
                                      Theme.of(context).textTheme.titleLarge)),
                        ]),
                        const SizedBox(height: 16),
                        Text(
                            '${screening['screening_status'] ?? 'Screening guidance unavailable'}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 5),
                        Text('$category · $scoreLabel',
                            style: const TextStyle(
                                color: AppColors.secondaryText)),
                        const SizedBox(height: 13),
                        const Text(
                            'AI output supports review; it is not a diagnosis.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.secondaryText)),
                        if ((screening['primary_predictions'] as List? ??
                                    const [])
                                .isNotEmpty ||
                            verification['performed'] == true)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Model details'),
                            children: [
                              for (final item
                                  in (screening['primary_predictions']
                                          as List? ??
                                      const []))
                                if (item is Map)
                                  ListTile(
                                    dense: true,
                                    title: Text(
                                        '${item['class'] ?? item['label'] ?? 'Class'}'
                                            .replaceAll('_', ' ')),
                                    trailing: Text(
                                        '${item['score'] ?? item['confidence'] ?? ''}'),
                                  ),
                              if (verification['performed'] == true)
                                const ListTile(
                                  dense: true,
                                  title: Text('Secondary model'),
                                  trailing: Text('Completed'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                  Text('Case images',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Original oral image',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _CaseImage(
                            path: screening['image_path'] as String?,
                            assets: assets),
                      ],
                    ),
                  )),
                  const SizedBox(height: 12),
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Visual explanation',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        const Text(
                            'Grad-CAM highlights model attention, not lesion boundaries.',
                            style: TextStyle(
                                color: AppColors.secondaryText, fontSize: 12)),
                        const SizedBox(height: 12),
                        _CaseImage(
                            path: gradcam['asset_path'] as String?,
                            assets: assets),
                      ],
                    ),
                  )),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _openMessages,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message Patient about this case'),
                  ),
                  const SizedBox(height: 22),
                  Text('Professional review',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 5),
                  const Text('Your draft is private until you submit it.',
                      style: TextStyle(color: AppColors.secondaryText)),
                  const SizedBox(height: 12),
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      for (final field in [
                        (observations, 'Clinical observations'),
                        (recommendations, 'Recommendations'),
                        (followUp, 'Suggested follow up'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: field.$1,
                            enabled: !submitted,
                            minLines: 2,
                            maxLines: 4,
                            maxLength:
                                field.$2 == 'Suggested follow up' ? 2000 : 4000,
                            decoration: InputDecoration(
                              labelText: field.$2,
                              alignLabelWithHint: true,
                              isDense: true,
                              counterText: '',
                            ),
                          ),
                        ),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(error!,
                                style:
                                    const TextStyle(color: AppColors.danger))),
                      if (!submitted) ...[
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: saving ? null : () => _save(false),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save draft'),
                            )),
                        const SizedBox(height: 9),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: saving ? null : () => _save(true),
                              icon: const Icon(Icons.task_alt_rounded),
                              label: Text(
                                  saving ? 'Saving review…' : 'Submit review'),
                            )),
                      ] else
                        const Row(children: [
                          Icon(Icons.check_circle_outline,
                              color: AppColors.teal),
                          SizedBox(width: 9),
                          Expanded(child: Text('Review submitted · Read only')),
                        ]),
                    ]),
                  )),
                ],
              );
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
