import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/core/routes/app_routes.dart';
import 'package:oralyn/data/mock/mock_data.dart';
import 'package:oralyn/models/screening_session.dart';
import 'package:oralyn/views/screens/home/main_shell.dart';
import 'package:oralyn/views/screens/result/result_screens.dart';

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

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Screening detail'), findsNothing);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });

  testWidgets('system Back from a screening result returns to prior page',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MainShell(detailRouteFactory: (settings) {
        if (settings.name == AppRoutes.preparation) {
          return MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.result),
                      child: const Text('Open result'),
                    ),
                  ));
        }
        if (settings.name == AppRoutes.result) {
          return MaterialPageRoute<void>(
              builder: (_) => ResultScreen(
                    outcome: ScreeningOutcome(result: MockData.results.first),
                  ));
        }
        return null;
      }),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open result'));
    await tester.pumpAndSettle();
    expect(find.text('Screening result'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open result'), findsOneWidget);
  });
}
