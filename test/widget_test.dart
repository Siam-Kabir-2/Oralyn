import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/data/mock/mock_data.dart';
import 'package:oralyn/views/screens/onboarding/onboarding_screens.dart';
import 'package:oralyn/models/screening_session.dart';
import 'package:oralyn/views/screens/result/result_screens.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('renders the Oralyn onboarding flow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Understand oral changes earlier'), findsOneWidget);
  });

  testWidgets('keeps the medical screening disclaimer visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          outcome: ScreeningOutcome(result: MockData.results.first),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.textContaining('not a medical diagnosis'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('not a medical diagnosis'), findsOneWidget);
    expect(find.text('What happens next'), findsOneWidget);
  });
}
