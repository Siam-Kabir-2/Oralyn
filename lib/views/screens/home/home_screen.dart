import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/screening_result.dart';
import '../../../services/screening_history_service.dart';
import '../../../services/review_request_service.dart';
import '../../widgets/common/app_components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.historyRepository});
  final ScreeningHistoryRepository? historyRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScreeningHistoryRepository repository =
      widget.historyRepository ?? ScreeningHistoryApiRepository();
  late final Future<List<ScreeningResult>> history = repository.list();
  final ReviewRequestService reviewService = ReviewRequestService();
  late final Future<List<ReviewRequestStatus>> reviews = reviewService.list();

  @override
  void dispose() {
    if (widget.historyRepository == null) repository.close();
    reviewService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
        children: [
          const _HomeHeader(),
          const SizedBox(height: 22),
          _ScreeningHero(
            onTap: () => Navigator.pushNamed(context, AppRoutes.preparation),
          ),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Recent screening',
            action: 'View all',
            onTap: () => Navigator.pushNamed(context, AppRoutes.history),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ScreeningResult>>(
            future: history,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 90,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const _HomeMessage(
                  'Recent screening is unavailable. Open History to try again.',
                );
              }
              final results = snapshot.data ?? const <ScreeningResult>[];
              if (results.isEmpty) {
                return const _NoRecentScreening();
              }
              final recent = results.first;
              return ScreeningCard(
                result: recent,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.historyDetail,
                  arguments: recent,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ReviewRequestStatus>>(
            future: reviews,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return const _HomeMessage(
                    'Doctor review status is unavailable.');
              }
              final requests = snapshot.data!;
              final pending = requests
                  .where((item) =>
                      item.status != 'reviewed' && item.status != 'closed')
                  .length;
              final completed = requests
                  .where((item) =>
                      item.status == 'reviewed' || item.status == 'closed')
                  .length;
              return Semantics(
                label:
                    '$pending pending Doctor reviews, $completed completed Doctor reviews',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(child: Text('Doctor reviews\n$pending pending')),
                      Expanded(child: Text('$completed completed')),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.history),
                        child: const Text('View history'),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.history_rounded,
                  title: 'History',
                  subtitle: 'Past check-ins',
                  color: AppColors.mint,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.history),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.medical_services_outlined,
                  title: 'Find care',
                  subtitle: 'Nearby specialists',
                  color: AppColors.peachSoft,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.doctorSearch),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _HealthNote(),
        ],
      ),
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message),
        ),
      );
}

class _NoRecentScreening extends StatelessWidget {
  const _NoRecentScreening();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Text(
          'No saved screenings yet. Save a result to see it here.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final name = ClerkAuth.userOf(context)?.name.trim();
    final displayName = name == null || name.isEmpty ? 'Oralyn member' : name;
    final parts = displayName.split(RegExp(r'\s+'));
    final initials = parts.take(2).map((part) => part[0]).join().toUpperCase();
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.peachSoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(initials,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                  child: Icon(Icons.notifications_none_rounded, size: 21)),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScreeningHero extends StatelessWidget {
  const _ScreeningHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cyanSoft,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: .07),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -52,
              top: -62,
              child: Container(
                width: 184,
                height: 184,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .38),
                ),
              ),
            ),
            const Positioned(right: 26, bottom: 62, child: _FocusMark()),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .48),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .45),
                      ),
                    ),
                    child: const Text(
                      'ORAL SCREENING',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Check a visible\nconcern',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.text,
                          fontSize: 26,
                          height: 1.13,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 245,
                    child: Text(
                      'Capture a clear image and receive careful next-step guidance.',
                      style: TextStyle(
                        color: Color(0xFF55716F),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 49),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    icon:
                        const Icon(Icons.center_focus_strong_rounded, size: 19),
                    label: const Text('Start screening'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _FocusMark extends StatelessWidget {
  const _FocusMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .55)),
        ),
        child: const Icon(
          Icons.camera_alt_outlined,
          color: AppColors.teal,
          size: 27,
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 15, 10, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.ink, size: 24),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HealthNote extends StatelessWidget {
  const _HealthNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EDE4),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.warning,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Two-week rule',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'An oral sore lasting longer than two weeks should be reviewed by a dental professional.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
