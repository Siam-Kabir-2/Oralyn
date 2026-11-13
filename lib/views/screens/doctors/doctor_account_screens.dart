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
        body: ListView(padding: const EdgeInsets.all(22), children: [
          Text('Professional verification',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
              'Your application remains pending until an authorized administrator verifies your professional details. Screening cases stay unavailable until then.'),
          const SizedBox(height: 20),
          DoctorDetailsForm(
              onSave: submit,
              saving: saving,
              error: error,
              buttonLabel: 'Submit application'),
        ]),
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
            return ListView(padding: const EdgeInsets.all(22), children: [
              Text(value['display_name'] as String? ?? 'Doctor',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(ClerkAuth.userOf(context)?.email ?? '',
                  style: const TextStyle(color: AppColors.secondaryText)),
              const SizedBox(height: 12),
              Chip(label: Text('Verification: $state')),
              const SizedBox(height: 12),
              const Text(
                  'Changing professional details requires a new verification. Your case access will pause until approval.'),
              const SizedBox(height: 20),
              if (state == 'pending' || state == 'verified')
                DoctorDetailsForm(
                    initial: value,
                    onSave: save,
                    saving: saving,
                    error: error,
                    buttonLabel: 'Save professional details')
              else
                const Text(
                    'This account cannot edit its professional profile. Contact an administrator.'),
            ]);
          },
        ),
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
