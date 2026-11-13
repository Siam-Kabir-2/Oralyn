import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';

import 'core/config/clerk_config.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'services/clerk_secure_persistor.dart';
import 'services/clerk_session_provider.dart';

void main() {
  runApp(const OralynApp());
}

class OralynApp extends StatefulWidget {
  const OralynApp({super.key});

  @override
  State<OralynApp> createState() => _OralynAppState();
}

class _OralynAppState extends State<OralynApp> {
  late Future<ClerkAuthState> _authFuture = _initialize();
  ClerkAuthState? _authState;

  Future<ClerkAuthState> _initialize() async {
    final state = await ClerkAuthState.create(
      config: ClerkAuthConfig(
        publishableKey: ClerkConfig.publishableKey,
        persistor: ClerkSecurePersistor(),
      ),
    );
    _authState = state;
    ClerkSessionProvider.bind(state);
    return state;
  }

  @override
  void dispose() {
    _authState?.terminate();
    ClerkSessionProvider.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClerkAuthState>(
      future: _authFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClerkAuth(authState: snapshot.data!, child: _materialApp());
        }
        return MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Unable to connect to sign-in.'),
                        TextButton(
                          onPressed: () => setState(() {
                            _authFuture = _initialize();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }

  Widget _materialApp() => MaterialApp(
        title: 'Oralyn',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      );
}
