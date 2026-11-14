import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/core/routes/app_routes.dart';
import 'package:oralyn/views/screens/home/main_shell.dart';

void main() {
  testWidgets('Patient bottom navigation stays visible on detail routes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MainShell(
        detailRouteFactory: (settings) {
          if (settings.name != AppRoutes.preparation) return null;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Screening detail')),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Screening detail'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Care'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
