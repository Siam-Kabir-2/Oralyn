import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/main.dart';

void main() {
  testWidgets('launches into the Oralyn onboarding flow', (tester) async {
    await tester.pumpWidget(const OralynApp());

    expect(find.text('Oralyn'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('Understand oral changes earlier'), findsOneWidget);
  });
}
