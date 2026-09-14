import 'package:flutter/material.dart';

import '../../../controllers/screening_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/app_components.dart';

class PhotoFlowArgs {
  const PhotoFlowArgs({this.poorQuality = false});
  final bool poorQuality;
}

class ScreeningPreparationScreen extends StatelessWidget {
  const ScreeningPreparationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const instructions = [
      (
        Icons.wb_sunny_outlined,
        'Use good lighting',
        'Face a soft, even light source.',
      ),
      (
        Icons.pan_tool_alt_outlined,
        'Keep the camera steady',
        'Hold your phone with both hands.',
      ),
      (
        Icons.visibility_outlined,
        'Make the area visible',
        'Gently position the mouth for a clear view.',
      ),
      (
        Icons.zoom_out_map_outlined,
        'Avoid excessive zoom',
        'Move closer instead of using digital zoom.',
      ),
    ];
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 2, 22, 22),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const AppHeader(
                      title: 'Before taking the photo',
                      subtitle:
                          'A clear, well-lit image helps provide more useful screening guidance.',
                    ),
                    const SizedBox(height: 28),
                    ...instructions.asMap().entries.map(
                          (entry) => _Instruction(
                            index: entry.key + 1,
                            icon: entry.value.$1,
                            title: entry.value.$2,
                            subtitle: entry.value.$3,
                          ),
                        ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.privacy_tip_outlined,
                            color: AppColors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your photo remains within this local prototype and is not uploaded.',
                              style: TextStyle(fontSize: 13.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PrimaryButton(
                label: 'Continue',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.capture),
                icon: Icons.camera_alt_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F2F0),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.teal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. $title',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool flash = false;

  void proceed(bool poor) => Navigator.pushNamed(
        context,
        AppRoutes.preview,
        arguments: PhotoFlowArgs(poorQuality: poor),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101920),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close camera',
                  ),
                  const Expanded(
                    child: Text(
                      'Center the area of concern',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => flash = !flash),
                    icon: Icon(
                      flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Toggle flash',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF38464D),
                    child: CustomPaint(
                      painter: _CameraGuidePainter(),
                      child: const Center(
                        child: Text(
                          'Camera preview',
                          style: TextStyle(
                            color: Color(0xFFAEBBC0),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 4),
              child: Text(
                'Keep the outlined area clear and fill it with the region you want to screen.',
                style: TextStyle(
                  color: Color(0xFFC7D0D4),
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CameraAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => proceed(true),
                  ),
                  Semantics(
                    button: true,
                    label: 'Capture photo',
                    child: GestureDetector(
                      onTap: () => proceed(false),
                      child: Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _CameraAction(
                    icon: Icons.help_outline_rounded,
                    label: 'Guide',
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const _CaptureHelp(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .48),
      width: size.width * .68,
      height: size.height * .35,
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(56)),
      paint,
    );
    final tick = Paint()
      ..color = AppColors.teal
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const length = 22.0;
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(length, 0), tick);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, length), tick);
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight - const Offset(length, 0),
      tick,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight - const Offset(0, length),
      tick,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 34,
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 25),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

class _CaptureHelp extends StatelessWidget {
  const _CaptureHelp();

  @override
  Widget build(BuildContext context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture guidance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                'Use the rear camera if possible. Keep the lens clean, avoid harsh shadows, and make sure the area of concern sits within the guide.',
              ),
              SizedBox(height: 18),
            ],
          ),
        ),
      );
}

class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({super.key, required this.args});
  final PhotoFlowArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review photo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AppImagePlaceholder(
                    height: MediaQuery.sizeOf(context).height * .52,
                    label: args.poorQuality
                        ? 'Selected gallery image placeholder'
                        : 'Captured oral image placeholder',
                    icon: Icons.photo_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    color: AppColors.teal,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Make sure the area of concern is clearly visible.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Retake',
                      onPressed: () => Navigator.pop(context),
                      icon: Icons.replay_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.quality,
                          arguments: args,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('Use Photo'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QualityCheckScreen extends StatefulWidget {
  const QualityCheckScreen({super.key, required this.args});
  final PhotoFlowArgs args;

  @override
  State<QualityCheckScreen> createState() => _QualityCheckScreenState();
}

class _QualityCheckScreenState extends State<QualityCheckScreen> {
  int completed = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (var i = 1; i <= 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 430));
      if (mounted) setState(() => completed = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = completed == 3;
    final poor = widget.args.poorQuality;
    return Scaffold(
      appBar: AppBar(title: const Text('Image quality')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      ready
                          ? (poor
                              ? 'A clearer photo would help'
                              : 'Image looks suitable')
                          : 'Checking image',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ready
                          ? (poor
                              ? 'The image appears slightly blurred around the area of concern.'
                              : 'The image looks suitable for preliminary screening.')
                          : 'We’re reviewing a few visual quality signals.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 30),
                    _QualityItem(
                      label: 'Sharpness',
                      done: completed >= 1,
                      warning: ready && poor,
                    ),
                    _QualityItem(label: 'Lighting', done: completed >= 2),
                    _QualityItem(label: 'Visibility', done: completed >= 3),
                    const SizedBox(height: 26),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: ready
                          ? Container(
                              key: const ValueKey('result'),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: poor
                                    ? AppColors.warningSoft
                                    : AppColors.successSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    poor
                                        ? Icons.blur_on_outlined
                                        : Icons.check_circle_outline,
                                    color: poor
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      poor
                                          ? 'Blur may reduce the usefulness of the result.'
                                          : 'Sharpness, lighting and visibility passed the mock check.',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('progress'),
                              height: 5,
                              child: LinearProgressIndicator(
                                color: AppColors.teal,
                                backgroundColor: AppColors.divider,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              if (ready && poor) ...[
                PrimaryButton(
                  label: 'Retake Photo',
                  onPressed: () => Navigator.popUntil(
                    context,
                    ModalRoute.withName(AppRoutes.capture),
                  ),
                  icon: Icons.camera_alt_outlined,
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: 'Use Anyway',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.analysis),
                  icon: Icons.arrow_forward_rounded,
                ),
              ] else if (ready)
                PrimaryButton(
                  label: 'Continue to Analysis',
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.analysis),
                  icon: Icons.auto_awesome_outlined,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityItem extends StatelessWidget {
  const _QualityItem({
    required this.label,
    required this.done,
    this.warning = false,
  });
  final String label;
  final bool done;
  final bool warning;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                !done
                    ? Icons.more_horiz_rounded
                    : (warning
                        ? Icons.info_outline_rounded
                        : Icons.check_rounded),
                color: !done
                    ? AppColors.secondaryText
                    : (warning ? AppColors.warning : AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                !done ? 'Checking' : (warning ? 'Could improve' : 'Good'),
                style: TextStyle(
                  fontSize: 13,
                  color: !done
                      ? AppColors.secondaryText
                      : (warning ? AppColors.warning : AppColors.success),
                ),
              ),
            ],
          ),
        ),
      );
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  final controller = ScreeningController();
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  int stage = 0;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => stage = 1);
    });
    Future<void>.delayed(const Duration(milliseconds: 1350), () {
      if (mounted) setState(() => stage = 2);
    });
    final result = await controller.analyze();
    if (mounted)
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.result,
        arguments: result,
      );
  }

  @override
  void dispose() {
    pulse.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Preparing image',
      'Analyzing visible patterns',
      'Preparing screening result',
    ];
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                AnimatedBuilder(
                  animation: pulse,
                  builder: (_, child) => Container(
                    width: 220,
                    height: 220,
                    padding: EdgeInsets.all(8 + pulse.value * 7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.teal.withValues(
                          alpha: .28 + pulse.value * .22,
                        ),
                        width: 2,
                      ),
                    ),
                    child: child,
                  ),
                  child: const ClipOval(
                    child: AppImagePlaceholder(
                      height: 200,
                      icon: Icons.center_focus_strong_outlined,
                      label: 'Image being analyzed',
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  'Reviewing your image',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'This usually takes a few moments.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.secondaryText),
                ),
                const SizedBox(height: 30),
                ...labels.asMap().entries.map(
                      (entry) => _AnalysisStage(
                        label: entry.value,
                        state: entry.key < stage
                            ? 2
                            : (entry.key == stage ? 1 : 0),
                      ),
                    ),
                const Spacer(),
                Text(
                  'Do not close the app during this mock analysis.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisStage extends StatelessWidget {
  const _AnalysisStage({required this.label, required this.state});
  final String label;
  final int state;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state == 2 ? AppColors.teal : Colors.transparent,
                border: Border.all(
                  color: state == 0 ? AppColors.divider : AppColors.teal,
                ),
              ),
              child: state == 2
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : (state == 1
                      ? const Padding(
                          padding: EdgeInsets.all(5),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.teal,
                          ),
                        )
                      : null),
            ),
            const SizedBox(width: 11),
            Text(
              label,
              style: TextStyle(
                color: state == 0 ? AppColors.secondaryText : AppColors.text,
                fontWeight: state == 1 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
}
