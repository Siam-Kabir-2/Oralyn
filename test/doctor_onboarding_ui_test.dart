import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/services/case_message_service.dart';
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

  testWidgets('Doctor messages shows a private assigned-case empty state',
      (tester) async {
    final service = CaseMessageService(
      client: MockClient((_) async => http.Response('{"items":[]}', 200)),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester.pumpWidget(MaterialApp(
      home: DoctorMessagesScreen(service: service),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Patient conversations'), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.textContaining('not an emergency service'), findsOneWidget);
    expect(find.textContaining('Coming Soon'), findsNothing);
    service.close();
  });

  testWidgets('Doctor can open and close message details', (tester) async {
    final service = CaseMessageService(
      client: MockClient((_) async => http.Response('{"items":[]}', 200)),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester.pumpWidget(MaterialApp(
      home: DoctorMessagesScreen(service: service),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Message details'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Only the Patient and assigned verified Doctor can read these messages.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Close details'));
    await tester.pumpAndSettle();
    expect(find.text('Assigned case only'), findsNothing);
    service.close();
  });
}
