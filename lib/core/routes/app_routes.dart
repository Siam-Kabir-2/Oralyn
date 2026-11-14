import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';

import '../../data/mock/mock_data.dart';
import '../../models/doctor.dart';
import '../../models/screening_result.dart';
import '../../models/screening_session.dart';
import '../../views/screens/auth/auth_screens.dart';
import '../../views/screens/doctors/doctor_screens.dart';
import '../../views/screens/doctors/doctor_workspace.dart';
import '../../views/screens/doctors/doctor_account_screens.dart';
import '../../views/screens/education/education_screen.dart';
import '../../views/screens/history/history_screens.dart';
import '../../views/screens/onboarding/onboarding_screens.dart';
import '../../views/screens/profile/profile_screens.dart';
import '../../views/screens/referral/referral_screen.dart';
import '../../views/screens/result/result_screens.dart';
import '../../views/screens/screening/screening_flow.dart';
import '../../views/screens/settings/api_settings_screen.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const authChoice = '/choose-role';
  static const doctorLogin = '/doctor/login';
  static const doctorRegister = '/doctor/register';
  static const doctorApply = '/doctor/apply';
  static const doctorProfile = '/doctor/profile';
  static const doctorMessages = '/doctor/messages';
  static const adminLogin = '/admin/login';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const preparation = '/screening/preparation';
  static const capture = '/screening/capture';
  static const preview = '/screening/preview';
  static const quality = '/screening/quality';
  static const analysis = '/screening/analysis';
  static const result = '/screening/result';
  static const explainability = '/screening/explainability';
  static const referral = '/referral';
  static const doctorSearch = '/doctors/search';
  static const doctorDetail = '/doctors/detail';
  static const map = '/doctors/map';
  static const history = '/history';
  static const historyDetail = '/history/detail';
  static const education = '/education';
  static const privacy = '/privacy';
  static const about = '/about';
  static const apiSettings = '/settings/screening-server';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      splash => const SplashScreen(),
      onboarding => const OnboardingScreen(),
      authChoice => const AuthChoiceScreen(),
      login => const LoginScreen(),
      register => const RegisterScreen(),
      doctorLogin => const LoginScreen(role: 'doctor'),
      doctorRegister => const RegisterScreen(role: 'doctor'),
      doctorApply => const DoctorApplicationScreen(),
      doctorProfile => const DoctorProfileScreen(),
      doctorMessages => const DoctorMessagesScreen(),
      adminLogin => const LoginScreen(role: 'admin'),
      forgotPassword => const ForgotPasswordScreen(),
      home => const RoleHomeScreen(),
      preparation => const ScreeningPreparationScreen(),
      capture => const CaptureScreen(),
      preview => ImagePreviewScreen(
          photo: settings.arguments is ScreeningPhoto
              ? settings.arguments! as ScreeningPhoto
              : null,
        ),
      quality => QualityCheckScreen(
          photo: settings.arguments is ScreeningPhoto
              ? settings.arguments! as ScreeningPhoto
              : null,
        ),
      analysis => AnalysisScreen(
          photo: settings.arguments is ScreeningPhoto
              ? settings.arguments! as ScreeningPhoto
              : null,
        ),
      result => ResultScreen(
          outcome: settings.arguments is ScreeningOutcome
              ? settings.arguments! as ScreeningOutcome
              : ScreeningOutcome(
                  result: settings.arguments is ScreeningResult
                      ? settings.arguments! as ScreeningResult
                      : MockData.results[MockData.activeScenarioIndex],
                ),
        ),
      explainability => ExplainabilityScreen(
          result: settings.arguments is ScreeningResult
              ? settings.arguments! as ScreeningResult
              : MockData.results[MockData.activeScenarioIndex],
        ),
      referral => ReferralScreen(
          result: settings.arguments is ScreeningResult
              ? settings.arguments! as ScreeningResult
              : MockData.results[MockData.activeScenarioIndex],
        ),
      doctorSearch => const DoctorSearchScreen(),
      doctorDetail => DoctorDetailScreen(
          doctor: settings.arguments is Doctor
              ? settings.arguments! as Doctor
              : MockData.doctors.first,
        ),
      map => const MapScreen(),
      history => const HistoryScreen(standalone: true),
      historyDetail => settings.arguments is ScreeningResult
          ? HistoryDetailScreen(
              result: settings.arguments! as ScreeningResult,
            )
          : const HistoryScreen(standalone: true),
      education => const EducationScreen(),
      privacy => const PrivacyScreen(),
      about => const AboutScreen(),
      apiSettings => const ApiSettingsScreen(),
      _ => const _NotFoundScreen(),
    };
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, animation, __) => _AuthRoute(
        routeName: settings.name,
        child: page,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final offset = Tween(
          begin: const Offset(.035, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(offset),
            child: child,
          ),
        );
      },
    );
  }
}

class _AuthRoute extends StatelessWidget {
  const _AuthRoute({required this.routeName, required this.child});

  final String? routeName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (routeName == AppRoutes.splash || routeName == AppRoutes.onboarding) {
      return child;
    }
    final isAuthRoute = routeName == AppRoutes.authChoice ||
        routeName == AppRoutes.doctorLogin ||
        routeName == AppRoutes.doctorRegister ||
        routeName == AppRoutes.adminLogin ||
        routeName == AppRoutes.login ||
        routeName == AppRoutes.register ||
        routeName == AppRoutes.forgotPassword;
    return ClerkAuthBuilder(
      signedInBuilder: (_, auth) {
        final session = auth.session;
        final active = session != null &&
            session.isActive &&
            session.expireAt.isAfter(DateTime.now());
        if (!active) {
          return const ExpiredSessionScreen();
        }
        if (routeName == AppRoutes.doctorRegister ||
            routeName == AppRoutes.doctorApply) {
          return const DoctorApplicationScreen();
        }
        if (routeName == AppRoutes.doctorLogin) {
          return const RoleHomeScreen(preferredRole: 'doctor');
        }
        if (routeName == AppRoutes.adminLogin) {
          return const RoleHomeScreen(preferredRole: 'admin');
        }
        return isAuthRoute ? const RoleHomeScreen() : child;
      },
      signedOutBuilder: (_, __) =>
          isAuthRoute ? child : const AuthChoiceScreen(),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This page is not available.')),
      );
}
