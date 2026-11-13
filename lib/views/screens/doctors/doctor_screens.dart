import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mock/mock_data.dart';
import '../../../models/doctor.dart';
import '../../widgets/common/app_components.dart';
import 'verified_doctor_screens.dart';

class DoctorsScreen extends StatelessWidget {
  const DoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const SafeArea(child: VerifiedDoctorDirectory(embedded: true));
}

class DoctorSearchScreen extends StatelessWidget {
  const DoctorSearchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Doctor Search')),
        body: const SafeArea(child: VerifiedDoctorDirectory()),
      );
}

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({super.key, required this.doctor});
  final Doctor doctor;

  void message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => message(context, '${doctor.name} saved.'),
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: 'Save doctor',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
        children: [
          const Text(
              'Illustrative care-location profile. Contact details and availability are demo content.'),
          const SizedBox(height: 12),
          const Center(
            child: SizedBox(
              width: 112,
              child: AppImagePlaceholder(
                height: 118,
                icon: Icons.person_outline,
                label: 'Doctor portrait placeholder',
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  doctor.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              if (doctor.verified)
                const Padding(
                  padding: EdgeInsets.only(left: 7),
                  child: Icon(
                    Icons.verified_rounded,
                    color: AppColors.teal,
                    size: 21,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            doctor.specialty,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            doctor.qualifications,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Call',
                  onPressed: () =>
                      message(context, 'Mock call to ${doctor.phone}'),
                  icon: Icons.call_outlined,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: SecondaryButton(
                  label: 'Directions',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.map),
                  icon: Icons.directions_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Consultation details'),
          const SizedBox(height: 10),
          _DetailLine(
            icon: Icons.local_hospital_outlined,
            title: doctor.facility,
            subtitle: doctor.address,
          ),
          _DetailLine(
            icon: Icons.near_me_outlined,
            title: '${doctor.distanceKm} km away',
            subtitle: 'From your mock current location',
          ),
          _DetailLine(
            icon: Icons.schedule_outlined,
            title: doctor.availability,
            subtitle: 'Call the facility to confirm',
          ),
          _DetailLine(
            icon: Icons.phone_outlined,
            title: doctor.phone,
            subtitle: 'Clinic contact',
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'About'),
          const SizedBox(height: 9),
          Text(
            doctor.bio,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 26),
          SectionHeader(
            title: 'Clinic location',
            action: 'Open map',
            onTap: () => Navigator.pushNamed(context, AppRoutes.map),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.map),
            child: const SizedBox(
              height: 180,
              child: _MapCanvas(compact: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F2F1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _MapCanvas()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 1,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 1,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: AppColors.secondaryText,
                            ),
                            SizedBox(width: 9),
                            Text(
                              'Nearby oral care',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: .34,
            minChildSize: .2,
            maxChildSize: .72,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC7D0D4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nearby locations',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...MockData.clinics.map(
                    (clinic) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F2F0),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clinic.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${clinic.type} · ${clinic.distanceKm} km',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Mock directions to ${clinic.name}',
                                ),
                              ),
                            ),
                            child: const Text(
                              'Directions',
                              style: TextStyle(color: AppColors.teal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 16 : 0),
        child: CustomPaint(
          painter: _MapPainter(),
          child: Stack(
            children: [
              Positioned(
                left: compact ? 80 : 72,
                top: compact ? 54 : 210,
                child: const _MapPin(label: 'You', user: true),
              ),
              Positioned(
                right: compact ? 36 : 64,
                top: compact ? 82 : 270,
                child: const _MapPin(label: 'Dental'),
              ),
              if (!compact)
                const Positioned(
                  left: 54,
                  top: 390,
                  child: _MapPin(label: 'Hospital'),
                ),
              if (!compact)
                const Positioned(
                  right: 110,
                  top: 470,
                  child: _MapPin(label: 'Oral Care'),
                ),
            ],
          ),
        ),
      );
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.label, this.user = false});
  final String label;
  final bool user;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: user ? 20 : 34,
            height: user ? 20 : 34,
            decoration: BoxDecoration(
              color: user ? AppColors.blue : AppColors.ink,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 7)
              ],
            ),
            child: user
                ? null
                : const Icon(
                    Icons.medical_services_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9EEE8),
    );
    final block = Paint()..color = const Color(0xFFDDE5DD);
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 5; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              col * size.width / 5 + 8,
              row * size.height / 7 + 8,
              size.width / 7,
              size.height / 12,
            ),
            const Radius.circular(5),
          ),
          block,
        );
      }
    }
    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(-20, size.height * .24)
      ..cubicTo(
        size.width * .25,
        size.height * .1,
        size.width * .64,
        size.height * .42,
        size.width + 20,
        size.height * .3,
      );
    canvas.drawPath(path, road);
    final road2 = Path()
      ..moveTo(size.width * .24, -20)
      ..cubicTo(
        size.width * .42,
        size.height * .3,
        size.width * .18,
        size.height * .7,
        size.width * .64,
        size.height + 20,
      );
    canvas.drawPath(road2, road..strokeWidth = 11);
    final main = Path()
      ..moveTo(-20, size.height * .76)
      ..lineTo(size.width + 20, size.height * .55);
    canvas.drawPath(main, road..strokeWidth = 18);
    canvas.drawPath(
      main,
      Paint()
        ..color = const Color(0xFFE7C982)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
