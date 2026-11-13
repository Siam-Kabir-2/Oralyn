import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/doctor_case_service.dart';

/// Public professional details come from verified Doctor records only.
class VerifiedDoctorDirectory extends StatefulWidget {
  const VerifiedDoctorDirectory(
      {super.key, this.embedded = false, this.caseService});

  final bool embedded;
  final DoctorCaseService? caseService;

  @override
  State<VerifiedDoctorDirectory> createState() =>
      _VerifiedDoctorDirectoryState();
}

class _VerifiedDoctorDirectoryState extends State<VerifiedDoctorDirectory> {
  late final service = widget.caseService ?? DoctorCaseService();
  late Future<List<Map<String, dynamic>>> doctors = service.verifiedDoctors();
  final search = TextEditingController();

  @override
  void dispose() {
    if (widget.caseService == null) service.close();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        children: [
          Text('Find Care', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
              'Verified Oralyn Doctor profiles. Review requests are made from your saved screening.'),
          const SizedBox(height: 18),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search name, specialty or workplace',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: doctors,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(children: [
                  const Text('Verified Doctor profiles are unavailable.'),
                  TextButton(
                      onPressed: () => setState(() {
                            doctors = service.verifiedDoctors();
                          }),
                      child: const Text('Try again')),
                ]);
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final query = search.text.trim().toLowerCase();
              final visible = snapshot.data!
                  .where((doctor) =>
                      '${doctor['display_name']} ${doctor['specialization']} ${doctor['workplace']}'
                          .toLowerCase()
                          .contains(query))
                  .toList();
              if (visible.isEmpty) {
                return const Text(
                    'No verified Doctor profiles match this search.');
              }
              return Column(children: [
                for (final doctor in visible)
                  Card(
                      child: ListTile(
                    leading: const Icon(Icons.verified_rounded,
                        color: AppColors.teal),
                    title: Text(doctor['display_name'] as String? ?? 'Doctor'),
                    subtitle: Text(
                        '${doctor['specialization'] ?? ''}\n${doctor['workplace'] ?? ''}'),
                    isThreeLine: true,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                VerifiedDoctorDetail(doctor: doctor))),
                  )),
              ]);
            },
          ),
        ],
      );
}

class VerifiedDoctorDetail extends StatelessWidget {
  const VerifiedDoctorDetail({super.key, required this.doctor});
  final Map<String, dynamic> doctor;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Doctor profile')),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          const Center(
              child: Icon(Icons.verified_rounded,
                  size: 52, color: AppColors.teal)),
          const SizedBox(height: 14),
          Text(doctor['display_name'] as String? ?? 'Doctor',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Verified professional', textAlign: TextAlign.center),
          const SizedBox(height: 25),
          for (final entry in [
            ('Specialization', doctor['specialization']),
            ('Qualification', doctor['qualification']),
            ('Workplace / institution', doctor['workplace']),
          ])
            if (entry.$2 is String && (entry.$2 as String).isNotEmpty)
              ListTile(
                  title: Text(entry.$1), subtitle: Text(entry.$2 as String)),
          const SizedBox(height: 18),
          const Text(
              'To request a professional review, open a saved screening in History. Case assignment is managed separately.'),
        ]),
      );
}
