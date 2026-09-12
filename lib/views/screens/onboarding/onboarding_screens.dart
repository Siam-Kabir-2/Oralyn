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
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OnboardingVisual(index: index, icon: item.icon),
                        const SizedBox(height: 42),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.displaySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item.body,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: AppColors.secondaryText),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
  const _OnboardingVisual({required this.index, required this.icon});
  final int index;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 235,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F2F0),
              borderRadius: BorderRadius.circular(46),
            ),
          ),
          Positioned(
            top: 22 + index * 6,
            right: 7,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE8F2),
                borderRadius: BorderRadius.circular(19),
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            left: 3 + index * 10,
            child: Container(
              width: 78,
              height: 48,
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
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
            child: Icon(icon, color: AppColors.teal, size: 52),
          ),
        ],
      ),
    );
  }
}
