import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/views/screens/auth/auth_screens.dart';
import 'package:oralyn/views/screens/doctors/doctor_account_screens.dart';

void main() {
  testWidgets('role choice offers Doctor application and no Admin registration',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthChoiceScreen()));
    expect(find.text('Continue as Patient'), findsOneWidget);
    expect(find.text('Apply as Doctor'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Admin sign in'), 200);
    expect(find.text('Admin sign in'), findsOneWidget);
    expect(find.text('Register as Admin'), findsNothing);
  });

  testWidgets('future Doctor messages cannot approve or send', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DoctorMessagesScreen()));
    expect(
        find.textContaining('Messaging is not available yet'), findsOneWidget);
    expect(find.text('Chat requests'), findsOneWidget);
    expect(find.text('Active conversations'), findsOneWidget);
    expect(find.text('Closed conversations'), findsOneWidget);
    for (final action in ['Approve · Coming Soon', 'Decline · Coming Soon']) {
      await tester.scrollUntilVisible(find.text(action), 200);
      final button = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, action));
      expect(button.onPressed, isNull);
    }
    await tester.scrollUntilVisible(find.text('Send'), 200);
    final send =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'));
    expect(send.onPressed, isNull);
  });
}
