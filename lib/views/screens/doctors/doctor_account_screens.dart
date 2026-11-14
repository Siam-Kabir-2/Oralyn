import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/doctor_case_service.dart';

class DoctorApplicationScreen extends StatefulWidget {
  const DoctorApplicationScreen({super.key});

  @override
  State<DoctorApplicationScreen> createState() =>
      _DoctorApplicationScreenState();
}

class _DoctorApplicationScreenState extends State<DoctorApplicationScreen> {
  final service = DoctorCaseService();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    service.close();
    super.dispose();
  }

  Future<void> submit(Map<String, String> values) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await service.applyAsDoctor(values);
      if (mounted)
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (_) => false);
    } on DoctorCaseException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Doctor application')),
        body: SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Text('PROFESSIONAL ONBOARDING',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('Professional verification',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                    'Tell us about your clinical practice. Your details will be reviewed before case access is available.'),
                const SizedBox(height: 20),
                const _DoctorNotice(
                    icon: Icons.verified_user_outlined,
                    text:
                        'Your application stays pending until an authorized administrator verifies it. No patient cases are shared while pending.'),
                const SizedBox(height: 26),
                Text('Professional details',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: DoctorDetailsForm(
                        onSave: submit,
                        saving: saving,
                        error: error,
                        buttonLabel: 'Submit application'),
                  ),
                ),
              ]),
        ),
      );
}

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key, this.caseService});
  final DoctorCaseService? caseService;

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  late final service = widget.caseService ?? DoctorCaseService();
  late Future<Map<String, dynamic>> profile = service.myDoctorProfile();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    if (widget.caseService == null) service.close();
    super.dispose();
  }

  Future<void> save(Map<String, String> values) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await service.updateMyDoctorProfile(values);
      if (!mounted) return;
      if (updated['verification_state'] == 'pending') {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (_) => false);
      } else {
        setState(() {
          profile = Future.value(updated);
        });
      }
    } on DoctorCaseException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Doctor Profile')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: profile,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child: TextButton(
                onPressed: () => setState(() {
                  profile = service.myDoctorProfile();
                }),
                child: const Text('Profile unavailable. Try again'),
              ));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final value = snapshot.data!;
            final state = value['verification_state'] as String? ?? 'pending';
            return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.successSoft,
                          child: Icon(Icons.medical_services_outlined,
                              color: AppColors.teal),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(value['display_name'] as String? ?? 'Doctor',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 3),
                              Text(ClerkAuth.userOf(context)?.email ?? '',
                                  style: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DoctorNotice(
                    icon: state == 'verified'
                        ? Icons.verified_rounded
                        : Icons.hourglass_top_rounded,
                    text:
                        'Verification: $state. Changing professional details requires a new review and pauses case access until approval.',
                  ),
                  const SizedBox(height: 26),
                  Text('Professional details',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (state == 'pending' || state == 'verified')
                    Card(
                        child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: DoctorDetailsForm(
                          initial: value,
                          onSave: save,
                          saving: saving,
                          error: error,
                          buttonLabel: 'Save professional details'),
                    ))
                  else
                    const Text(
                        'This account cannot edit its professional profile. Contact an administrator.'),
                ]);
          },
        ),
      );
}

class _DoctorNotice extends StatelessWidget {
  const _DoctorNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.teal, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, height: 1.4))),
        ]),
      );
}

class DoctorDetailsForm extends StatefulWidget {
  const DoctorDetailsForm(
      {super.key,
      this.initial = const {},
      required this.onSave,
      required this.saving,
      required this.buttonLabel,
      this.error});
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, String>) onSave;
  final bool saving;
  final String buttonLabel;
  final String? error;

  @override
  State<DoctorDetailsForm> createState() => _DoctorDetailsFormState();
}

class _DoctorDetailsFormState extends State<DoctorDetailsForm> {
  final key = GlobalKey<FormState>();
  late final controllers = {
    for (final field in [
      'display_name',
      'registration_reference',
      'qualification',
      'specialization',
      'workplace'
    ])
      field: TextEditingController(text: widget.initial[field] as String? ?? '')
  };

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: key,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final field in controllers.keys) ...[
            TextFormField(
              controller: controllers[field],
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: switch (field) {
                'display_name' => 'Full name',
                'registration_reference' => 'Professional registration number',
                'qualification' => 'Qualification',
                'specialization' => 'Specialization',
                _ => 'Workplace / institution',
              }),
              validator: (value) => (value ?? '').trim().length <
                      (field == 'registration_reference' ? 3 : 2)
                  ? 'Enter a valid value'
                  : null,
              maxLength: 160,
            ),
            const SizedBox(height: 6),
          ],
          if (widget.error != null)
            Text(widget.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: widget.saving
                ? null
                : () {
                    if (key.currentState!.validate()) {
                      widget.onSave({
                        for (final item in controllers.entries)
                          item.key: item.value.text.trim()
                      });
                    }
                  },
            child: widget.saving
                ? const CircularProgressIndicator()
                : Text(widget.buttonLabel),
          ),
        ]),
      );
}

class DoctorMessagesScreen extends StatelessWidget {
  const DoctorMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          Text('Patient conversations',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
              'Coming Soon · Messaging is not available yet. A structured case review does not open a conversation.'),
          const SizedBox(height: 24),
          for (final title in [
            'Chat requests',
            'Active conversations',
            'Closed conversations'
          ])
            Card(
                child: ListTile(
                    title: Text(title),
                    subtitle: const Text(
                        'No conversations available in this version.'),
                    leading: const Icon(Icons.lock_outline))),
          const SizedBox(height: 12),
          const Text(
              'Future request decisions require an assigned case and an authorized Doctor. No request can be approved in this version.'),
          const SizedBox(height: 8),
          const Wrap(spacing: 10, children: [
            OutlinedButton(
                onPressed: null, child: Text('Approve · Coming Soon')),
            OutlinedButton(
                onPressed: null, child: Text('Decline · Coming Soon')),
          ]),
          const SizedBox(height: 22),
          const Text('Conversation unavailable · No approved chat request'),
          const SizedBox(height: 8),
          const TextField(
              enabled: false,
              decoration: InputDecoration(
                  labelText: 'Message composer',
                  hintText: 'Available only for approved conversations')),
          const SizedBox(height: 8),
          const FilledButton(onPressed: null, child: Text('Send')),
        ]),
      );
}
