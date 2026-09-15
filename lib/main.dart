import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const OralynApp());
}

class OralynApp extends StatelessWidget {
  const OralynApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oralyn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
