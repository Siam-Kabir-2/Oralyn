import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/doctor.dart';
import '../../../models/screening_result.dart';

class OralynLogo extends StatelessWidget {
  const OralynLogo({super.key, this.size = 52, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: onDark
            ? const LinearGradient(colors: [Colors.white, Color(0xFFE3FFF8)])
            : const LinearGradient(
                colors: [AppColors.inkLight, AppColors.ink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(size * .34),
        boxShadow: onDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: .16),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * .52,
            height: size * .38,
            decoration: BoxDecoration(
              border: Border.all(
                color: onDark ? AppColors.ink : AppColors.tealBright,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(size),
            ),
          ),
          Container(
            width: size * .13,
            height: size * .13,
            decoration: BoxDecoration(
              color: onDark ? AppColors.teal : Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ink.withValues(alpha: .55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
        label: Text(label),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon ?? Icons.arrow_back_rounded, size: 19),
        label: Text(label),
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.secondaryText),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onTap,
  });
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            child: Text(action!, style: const TextStyle(color: AppColors.teal)),
          ),
      ],
    );
  }
}

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.keyboardType,
    this.password = false,
    this.validator,
    this.prefixIcon,
  });
  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool password;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool hidden = widget.password;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: hidden,
      validator: widget.validator,
      autofillHints: widget.password ? const [AutofillHints.password] : null,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 20),
        suffixIcon: widget.password
            ? IconButton(
                tooltip: hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }
}

class AppImagePlaceholder extends StatelessWidget {
  const AppImagePlaceholder({
    super.key,
    this.height = 180,
    this.icon = Icons.health_and_safety_outlined,
    this.label = 'Oral image placeholder',
    this.compact = false,
  });
  final double height;
  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0F2),
          borderRadius: BorderRadius.circular(compact ? 12 : 18),
        ),
        child: CustomPaint(
          painter: _PlaceholderPainter(),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 24 : 36, color: AppColors.blue),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.blue.withValues(alpha: .08);
    for (double x = -size.height; x < size.width; x += 28) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.risk, this.compact = false});
  final RiskLevel risk;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color, background, icon) = switch (risk) {
      RiskLevel.lowConcern => (
          'Low Concern',
          AppColors.success,
          AppColors.successSoft,
          Icons.check_circle_outline,
        ),
      RiskLevel.professionalReview => (
          'Professional Review',
          AppColors.warning,
          AppColors.warningSoft,
          Icons.schedule_outlined,
        ),
      RiskLevel.promptSpecialistReview => (
          'Prompt Specialist Review',
          AppColors.danger,
          AppColors.dangerSoft,
          Icons.priority_high_rounded,
        ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RiskIndicator extends StatelessWidget {
  const RiskIndicator({super.key, required this.risk});
  final RiskLevel risk;

  @override
  Widget build(BuildContext context) {
    final active = switch (risk) {
      RiskLevel.lowConcern => 1,
      RiskLevel.professionalReview => 2,
      RiskLevel.promptSpecialistReview => 3,
    };
    return Row(
      children: List.generate(3, (index) {
        final colors = [AppColors.success, AppColors.warning, AppColors.danger];
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
            height: 5,
            decoration: BoxDecoration(
              color: index < active ? colors[index] : AppColors.divider,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }
}

class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Model score')),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 650),
            builder: (_, progress, __) => LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: AppColors.teal,
              backgroundColor: AppColors.divider,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This model score is not a disease probability or diagnosis.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, required this.onTap});
  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 64,
                child: AppImagePlaceholder(
                  height: 72,
                  compact: true,
                  icon: Icons.person_outline,
                  label: 'Doctor portrait placeholder',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doctor.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (doctor.verified)
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.teal,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      doctor.specialty,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      doctor.facility,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _Meta(
                          icon: Icons.near_me_outlined,
                          text: '${doctor.distanceKm} km away',
                        ),
                        _Meta(
                          icon: Icons.schedule_outlined,
                          text: doctor.availability,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondaryText),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class ScreeningCard extends StatelessWidget {
  const ScreeningCard({super.key, required this.result, required this.onTap});
  final ScreeningResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date =
        '${result.date.day.toString().padLeft(2, '0')} ${_month(result.date.month)} ${result.date.year}';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SizedBox(
                width: 58,
                child: AppImagePlaceholder(
                  height: 58,
                  compact: true,
                  label: 'Screening thumbnail',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 3),
                    Text(
                      result.status,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      result.categoryLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 76, child: RiskIndicator(risk: result.risk)),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _month(int value) => const [
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
        'Dec',
      ][value - 1];
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.inbox_outlined,
  });
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2F1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.teal, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: PrimaryButton(label: actionLabel, onPressed: onAction),
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        title: title,
        message: message,
        actionLabel: 'Try Again',
        onAction: onRetry,
        icon: Icons.sync_problem_outlined,
      );
}

class GradCamPlaceholder extends StatelessWidget {
  const GradCamPlaceholder({super.key, this.height = 220});
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFE3EAEC)),
            CustomPaint(painter: _HeatmapPainter()),
            Positioned(
              left: 16,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Visual explanation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .58, size.height * .48);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * .66,
        height: size.height * .48,
      ),
      Paint()..color = AppColors.ink.withValues(alpha: .08),
    );
    final gradient = RadialGradient(
      colors: [
        AppColors.danger.withValues(alpha: .58),
        AppColors.warning.withValues(alpha: .34),
        AppColors.teal.withValues(alpha: 0),
      ],
    );
    canvas.drawCircle(
      center,
      math.min(size.width, size.height) * .3,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: center,
            radius: math.min(size.width, size.height) * .3,
          ),
        ),
    );
    final guide = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .17,
          size.height * .18,
          size.width * .66,
          size.height * .64,
        ),
        const Radius.circular(28),
      ),
      guide,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
