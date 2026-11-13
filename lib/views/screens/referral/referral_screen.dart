import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../../../models/screening_result.dart';
import '../../widgets/common/app_components.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key, required this.result});
  final ScreeningResult result;

  @override
  Widget build(BuildContext context) {
    final careType = result.risk == RiskLevel.promptSpecialistReview
        ? 'Oral & Maxillofacial Surgery'
        : 'Oral Medicine';
    final nearby = MockData.doctors
        .where(
          (doctor) =>
              doctor.specialty.contains(careType.split(' ').first) ||
              doctor.specialty.contains('Oral'),
        )
        .take(3)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Referral Guidance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          Text(
            'Your recommended next step',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 8),
          Text(
            result.risk == RiskLevel.promptSpecialistReview
                ? 'Consult an oral health specialist promptly.'
                : 'Consult an oral medicine specialist.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'A focused professional examination can assess the area directly and determine whether follow-up is needed.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F2F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.medical_services_outlined,
                  color: AppColors.teal,
                  size: 27,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recommended care type',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        careType,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: 'Nearby options',
            action: 'View map',
            onTap: () => Navigator.pushNamed(context, AppRoutes.map),
          ),
          const SizedBox(height: 10),
          const Text(
              'Care locations below are illustrative demo entries. Use Find Care for verified Oralyn Doctor profiles.'),
          const SizedBox(height: 10),
          ...nearby.map(
            (doctor) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DoctorCard(
                doctor: doctor,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.doctorDetail,
                  arguments: doctor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Options are shown by proximity and specialty match. Oralyn does not rank providers by medical quality.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          SecondaryButton(
            label: 'Browse All Care Options',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.doctorSearch),
            icon: Icons.search_rounded,
          ),
        ],
      ),
    );
  }
}
