import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/app_components.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted)
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: controller, curve: Curves.easeOut),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OralynLogo(size: 70, onDark: true),
              SizedBox(height: 22),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
              ),
              SizedBox(height: 7),
              Text(
                AppConstants.subtitle,
                style: TextStyle(
                  color: Color(0xFFC7D4DF),
                  fontSize: 14,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final pageController = PageController();
  int page = 0;
  static const pages = [
    (
      title: 'Understand oral changes earlier',
      body:
          'Use your smartphone to document a concern and receive clear preliminary guidance.',
      icon: Icons.visibility_outlined,
    ),
    (
      title: 'AI-assisted visual screening',
      body:
          'Oralyn reviews visible image patterns and explains what influenced the screening.',
      icon: Icons.center_focus_strong_outlined,
    ),
    (
      title: 'Know your next step',
      body:
          'Get practical referral guidance and discover nearby oral health professionals.',
      icon: Icons.route_outlined,
    ),
  ];

  void next() {
    if (page == pages.length - 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else {
      pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            children: [
              Row(
                children: [
                  const OralynLogo(size: 40),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.login,
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  onPageChanged: (value) => setState(() => page = value),
                  itemCount: pages.length,
                  itemBuilder: (context, index) {
                    final item = pages[index];
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxHeight < 460;
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: constraints.maxHeight),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _OnboardingVisual(
                                  index: index,
                                  icon: item.icon,
                                  compact: compact,
                                ),
                                SizedBox(height: compact ? 22 : 34),
                                Text(
                                  item.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(fontSize: compact ? 26 : 31),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.body,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                          color: AppColors.secondaryText),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: page == index ? 24 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: page == index ? AppColors.teal : AppColors.divider,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: page == pages.length - 1 ? 'Get Started' : 'Continue',
                onPressed: next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({
    required this.index,
    required this.icon,
    required this.compact,
  });
  final int index;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 190 : 236,
      height: compact ? 174 : 218,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: compact ? 160 : 196,
            height: compact ? 160 : 196,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE0F4EE), Color(0xFFCBE9E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(compact ? 40 : 52),
            ),
          ),
          Positioned(
            top: 14 + index * 5,
            right: 7,
            child: Container(
              width: compact ? 45 : 58,
              height: compact ? 45 : 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7D5),
                borderRadius: BorderRadius.circular(19),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 3 + index * 10,
            child: Container(
              width: compact ? 58 : 72,
              height: compact ? 40 : 47,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Container(
            width: compact ? 96 : 120,
            height: compact ? 96 : 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: .1),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.ink, size: compact ? 40 : 50),
          ),
        ],
      ),
    );
  }
}
