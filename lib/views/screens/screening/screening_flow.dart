import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../controllers/screening_controller.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/screening_session.dart';
import '../../widgets/common/app_components.dart';

class ScreeningPreparationScreen extends StatelessWidget {
  const ScreeningPreparationScreen({super.key});

  static const _instructions = [
    (
      Icons.cleaning_services_outlined,
      'Clean the camera lens',
      'A quick wipe prevents haze and glare.'
    ),
    (
      Icons.wb_sunny_outlined,
      'Use bright, even light',
      'Stand near a window or use a cool white room light.'
    ),
    (
      Icons.pan_tool_alt_outlined,
      'Keep your phone steady',
      'Use both hands and ask someone you trust for help if needed.'
    ),
    (
      Icons.center_focus_strong_outlined,
      'Fill the guide with the area',
      'Move closer instead of using digital zoom.'
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Column(children: [
            Expanded(
                child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 22),
              children: [
                const AppHeader(
                  title: 'Take a useful oral photo',
                  subtitle:
                      'Good image quality makes the simulated guidance easier to understand.',
                ),
                const SizedBox(height: 22),
                const _PreparationVisual(),
                const SizedBox(height: 24),
                ..._instructions.asMap().entries.map(
                      (entry) => TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 280 + entry.key * 80),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                              offset: Offset(0, 12 * (1 - value)),
                              child: child),
                        ),
                        child: _Instruction(
                          index: entry.key + 1,
                          icon: entry.value.$1,
                          title: entry.value.$2,
                          subtitle: entry.value.$3,
                        ),
                      ),
                    ),
                const _PrivacyNote(),
              ],
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              child: PrimaryButton(
                label: 'Open Camera',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.capture),
                icon: Icons.camera_alt_outlined,
              ),
            ),
          ]),
        ),
      );
}

class _PreparationVisual extends StatelessWidget {
  const _PreparationVisual();
  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF102A43), Color(0xFF174B5D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(children: [
          Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .05)),
              )),
          const Center(
              child: SizedBox(
                  width: 190,
                  height: 82,
                  child: CustomPaint(painter: _CameraGuidePainter()))),
          const Positioned(
              left: 18,
              bottom: 14,
              child: Row(children: [
                Icon(Icons.auto_awesome, color: Color(0xFF71D6C5), size: 17),
                SizedBox(width: 7),
                Text('Clear • close • well lit',
                    style: TextStyle(color: Colors.white, fontSize: 12.5)),
              ])),
        ]),
      );
}

class _Instruction extends StatelessWidget {
  const _Instruction(
      {required this.index,
      required this.icon,
      required this.title,
      required this.subtitle});
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: const Color(0xFFE7F2F0),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: AppColors.teal, size: 21)),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('$index. $title',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.secondaryText)),
              ])),
        ]),
      );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFEAF2F6),
            borderRadius: BorderRadius.circular(14)),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.blue, size: 20),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Privacy first: the selected photo is held in memory for this session only. This prototype does not upload it.',
                  style: TextStyle(fontSize: 13.5, height: 1.4))),
        ]),
      );
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _opening = false;
  bool _attemptedAutomaticOpen = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverOrOpen());
  }

  Future<void> _recoverOrOpen() async {
    if (_attemptedAutomaticOpen) return;
    _attemptedAutomaticOpen = true;
    try {
      final response = await _picker.retrieveLostData();
      final files = response.files;
      if (files != null && files.isNotEmpty) {
        await _handleFile(files.first, fromCamera: true);
        return;
      }
    } catch (_) {
      // Lost-data recovery is not supported on every platform.
    }
    if (mounted) await _pick(ImageSource.camera);
  }

  Future<void> _pick(ImageSource source) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _message = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
        requestFullMetadata: false,
      );
      if (file == null) {
        if (mounted)
          setState(() => _message = 'No photo selected. Try again when ready.');
        return;
      }
      await _handleFile(file, fromCamera: source == ImageSource.camera);
    } on PlatformException catch (error) {
      if (!mounted) return;
      final code = error.code.toLowerCase();
      final denied = code.contains('denied') || code.contains('access');
      setState(() => _message = denied
          ? 'Camera access is unavailable. Allow camera access in your phone settings, or choose a photo.'
          : 'The camera could not open. Please try again or choose a photo.');
    } catch (_) {
      if (mounted)
        setState(() => _message =
            'We could not read that image. Please try another photo.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _handleFile(XFile file, {required bool fromCamera}) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('Empty image');
    if (!mounted) return;
    final photo = ScreeningPhoto(
      bytes: bytes,
      name: file.name,
      fromCamera: fromCamera,
      qualityWarning: bytes.lengthInBytes < 45000,
    );
    await Navigator.pushNamed(context, AppRoutes.preview, arguments: photo);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0D1C29),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Add an oral photo',
              style: TextStyle(color: Colors.white)),
        ),
        body: SafeArea(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(children: [
            Expanded(
                child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF183B4B), Color(0xFF102A43)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12)),
              child: Stack(children: [
                const Center(
                    child: SizedBox(
                        width: 260,
                        height: 170,
                        child: CustomPaint(painter: _CameraGuidePainter()))),
                Center(
                    child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _opening
                      ? const Column(
                          key: ValueKey('opening'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              CircularProgressIndicator(
                                  color: Color(0xFF71D6C5), strokeWidth: 2.5),
                              SizedBox(height: 18),
                              Text('Opening camera…',
                                  style: TextStyle(color: Colors.white)),
                            ])
                      : const Column(
                          key: ValueKey('ready'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Icon(Icons.camera_alt_outlined,
                                  color: Colors.white, size: 38),
                              SizedBox(height: 14),
                              Text('Your phone camera opens securely',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(height: 6),
                              Text('Use the rear camera for a sharper photo',
                                  style: TextStyle(
                                      color: Color(0xFFB9C8D4), fontSize: 13)),
                            ]),
                )),
                const Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _GuideChip(
                              icon: Icons.wb_sunny_outlined, text: 'Bright'),
                          _GuideChip(
                              icon: Icons.pan_tool_alt_outlined,
                              text: 'Steady'),
                          _GuideChip(
                              icon: Icons.zoom_in_map_outlined, text: 'Close'),
                        ])),
              ]),
            )),
            AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: _message == null
                    ? const SizedBox(height: 20)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFF273B48),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(_message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFFDCE5E9), fontSize: 13)))),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                    onPressed:
                        _opening ? null : () => _pick(ImageSource.camera),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                        disabledBackgroundColor: Colors.white54,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take Photo'))),
            const SizedBox(height: 10),
            TextButton.icon(
                onPressed: _opening ? null : () => _pick(ImageSource.gallery),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDCE5E9)),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Choose from gallery')),
          ]),
        )),
      );
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF71D6C5), size: 15),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        ]),
      );
}

class _CameraGuidePainter extends CustomPainter {
  const _CameraGuidePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * .78,
        height: size.height * .55);
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: .32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(48)), outline);
    final accent = Paint()
      ..color = const Color(0xFF71D6C5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const length = 24.0;
    canvas
      ..drawLine(rect.topLeft, rect.topLeft + const Offset(length, 0), accent)
      ..drawLine(rect.topLeft, rect.topLeft + const Offset(0, length), accent)
      ..drawLine(
          rect.topRight, rect.topRight + const Offset(-length, 0), accent)
      ..drawLine(rect.topRight, rect.topRight + const Offset(0, length), accent)
      ..drawLine(
          rect.bottomLeft, rect.bottomLeft + const Offset(length, 0), accent)
      ..drawLine(
          rect.bottomLeft, rect.bottomLeft + const Offset(0, -length), accent)
      ..drawLine(
          rect.bottomRight, rect.bottomRight + const Offset(-length, 0), accent)
      ..drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -length),
          accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({super.key, this.photo});
  final ScreeningPhoto? photo;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Review photo')),
        body: SafeArea(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
          child: Column(children: [
            Expanded(
                child: Center(
                    child: Hero(
              tag: 'screening-photo-${photo?.name ?? 'placeholder'}',
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: photo == null
                      ? const AppImagePlaceholder(
                          height: 420,
                          label: 'No photo selected',
                          icon: Icons.photo_outlined)
                      : Image.memory(photo!.bytes,
                          width: double.infinity,
                          height: MediaQuery.sizeOf(context).height * .52,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          semanticLabel: 'Selected oral screening photo')),
            ))),
            const SizedBox(height: 16),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                    color: const Color(0xFFE7F2F0),
                    borderRadius: BorderRadius.circular(13)),
                child: const Row(children: [
                  Icon(Icons.visibility_outlined,
                      color: AppColors.teal, size: 19),
                  SizedBox(width: 9),
                  Expanded(
                      child: Text(
                          'Check that the concern is sharp, centered, and fully visible.',
                          style: TextStyle(fontSize: 13.5))),
                ])),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: SecondaryButton(
                      label: 'Retake',
                      onPressed: () => Navigator.pop(context),
                      icon: Icons.replay_rounded)),
              const SizedBox(width: 12),
              Expanded(
                  child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                          onPressed: photo == null
                              ? null
                              : () => Navigator.pushNamed(
                                  context, AppRoutes.quality, arguments: photo),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          icon: const Icon(Icons.check_rounded, size: 19),
                          label: const Text('Use Photo')))),
            ]),
          ]),
        )),
      );
}

class QualityCheckScreen extends StatefulWidget {
  const QualityCheckScreen({super.key, this.photo});
  final ScreeningPhoto? photo;
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
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (mounted) setState(() => completed = i);
    }
  }

  void _continue() =>
      Navigator.pushNamed(context, AppRoutes.analysis, arguments: widget.photo);

  @override
  Widget build(BuildContext context) {
    final ready = completed == 3;
    final warning = widget.photo?.qualityWarning ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo quality')),
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        child: Column(children: [
          Expanded(
              child: ListView(children: [
            AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(ready),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        ready
                            ? (warning
                                ? 'A clearer photo may help'
                                : 'Photo is ready')
                            : 'Checking your photo',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                        ready
                            ? (warning
                                ? 'The file is small, which can reduce visible detail. You can retake it or continue with the demo.'
                                : 'The photo passed this prototype’s lightweight quality checks.')
                            : 'Reviewing the visible detail before simulated analysis.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.secondaryText)),
                  ],
                )),
            const SizedBox(height: 26),
            if (widget.photo != null)
              ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Image.memory(widget.photo!.bytes,
                      height: 180, width: double.infinity, fit: BoxFit.cover)),
            const SizedBox(height: 18),
            _QualityItem(
                label: 'Visible detail',
                done: completed >= 1,
                warning: ready && warning),
            _QualityItem(label: 'Lighting balance', done: completed >= 2),
            _QualityItem(label: 'Area framing', done: completed >= 3),
            const SizedBox(height: 12),
            AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: ready
                    ? Container(
                        key: const ValueKey('ready'),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: warning
                                ? AppColors.warningSoft
                                : AppColors.successSoft,
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Icon(
                              warning
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: warning
                                  ? AppColors.warning
                                  : AppColors.success),
                          const SizedBox(width: 11),
                          Expanded(
                              child: Text(warning
                                  ? 'Quality guidance is simulated and does not validate medical usefulness.'
                                  : 'Ready for a simulated screening result.')),
                        ]))
                    : const LinearProgressIndicator(
                        key: ValueKey('checking'),
                        minHeight: 5,
                        color: AppColors.teal,
                        backgroundColor: AppColors.divider)),
          ])),
          if (ready && warning) ...[
            PrimaryButton(
                label: 'Retake Photo',
                onPressed: () => Navigator.popUntil(
                    context, ModalRoute.withName(AppRoutes.capture)),
                icon: Icons.camera_alt_outlined),
            const SizedBox(height: 10),
            SecondaryButton(
                label: 'Continue Demo',
                onPressed: _continue,
                icon: Icons.arrow_forward_rounded),
          ] else if (ready)
            PrimaryButton(
                label: 'Run Simulated Analysis',
                onPressed: _continue,
                icon: Icons.auto_awesome_outlined),
        ]),
      )),
    );
  }
}

class _QualityItem extends StatelessWidget {
  const _QualityItem(
      {required this.label, required this.done, this.warning = false});
  final String label;
  final bool done;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: done ? AppColors.divider : Colors.transparent)),
          child: Row(children: [
            AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                    !done
                        ? Icons.more_horiz_rounded
                        : (warning
                            ? Icons.info_outline_rounded
                            : Icons.check_circle_rounded),
                    key: ValueKey('$label-$done-$warning'),
                    color: !done
                        ? AppColors.secondaryText
                        : (warning ? AppColors.warning : AppColors.success))),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
            Text(!done ? 'Checking' : (warning ? 'Could improve' : 'Good'),
                style: TextStyle(
                    fontSize: 13,
                    color: !done
                        ? AppColors.secondaryText
                        : (warning ? AppColors.warning : AppColors.success))),
          ]),
        ),
      );
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, this.photo});
  final ScreeningPhoto? photo;
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  final controller = ScreeningController();
  late final AnimationController pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
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
    if (!mounted) return;
    await Navigator.pushReplacementNamed(context, AppRoutes.result,
        arguments: ScreeningOutcome(result: result, photo: widget.photo));
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
      'Preparing your photo',
      'Simulating visible-pattern review',
      'Building recommendations'
    ];
    return PopScope(
        canPop: false,
        child: Scaffold(
            body: SafeArea(
                child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            AnimatedBuilder(
                animation: pulse,
                builder: (_, child) => Container(
                      width: 224,
                      height: 224,
                      padding: EdgeInsets.all(8 + pulse.value * 7),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.teal
                                  .withValues(alpha: .24 + pulse.value * .26),
                              width: 2)),
                      child: child,
                    ),
                child: ClipOval(
                    child: widget.photo == null
                        ? const AppImagePlaceholder(
                            height: 200,
                            icon: Icons.center_focus_strong_outlined,
                            label: 'Demo analysis')
                        : Image.memory(widget.photo!.bytes,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            gaplessPlayback: true))),
            const SizedBox(height: 32),
            Text('Reviewing your photo',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Creating a demonstration result with sample data.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.secondaryText)),
            const SizedBox(height: 28),
            ...labels.asMap().entries.map((entry) => _AnalysisStage(
                label: entry.value,
                state: entry.key < stage ? 2 : (entry.key == stage ? 1 : 0))),
            const Spacer(),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.science_outlined,
                  size: 16, color: AppColors.secondaryText),
              SizedBox(width: 6),
              Text('Prototype only — not a medical diagnosis',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.secondaryText)),
            ]),
          ]),
        ))));
  }
}

class _AnalysisStage extends StatelessWidget {
  const _AnalysisStage({required this.label, required this.state});
  final String label;
  final int state;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: state == 0 ? .55 : 1,
        duration: const Duration(milliseconds: 220),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state == 2 ? AppColors.teal : Colors.transparent,
                      border: Border.all(
                          color:
                              state == 0 ? AppColors.divider : AppColors.teal)),
                  child: state == 2
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : (state == 1
                          ? const Padding(
                              padding: EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.teal))
                          : null)),
              const SizedBox(width: 11),
              Text(label,
                  style: TextStyle(
                      color:
                          state == 0 ? AppColors.secondaryText : AppColors.text,
                      fontWeight:
                          state == 1 ? FontWeight.w600 : FontWeight.w400)),
            ])),
      );
}
