import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/data/mock/mock_data.dart';
import 'package:oralyn/main.dart';
import 'package:oralyn/models/screening_session.dart';
import 'package:oralyn/views/screens/result/result_screens.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('launches into the Oralyn onboarding flow', (tester) async {
    await tester.pumpWidget(const OralynApp());

    expect(find.text('Oralyn'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('Understand oral changes earlier'), findsOneWidget);
  });

  testWidgets('labels sample screening output clearly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          outcome: ScreeningOutcome(result: MockData.results.first),
        ),
      ),
    );

    expect(
      find.text(
        'Simulated result using sample data — not an analysis of your photo.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Your practical care plan'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Your practical care plan'), findsOneWidget);
  });
}
