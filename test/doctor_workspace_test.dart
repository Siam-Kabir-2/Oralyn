import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/services/doctor_case_service.dart';
import 'package:oralyn/views/screens/doctors/doctor_workspace.dart';

void main() {
  testWidgets('role loading error links to screening server settings',
      (tester) async {
    final service = DoctorCaseService(
      client: MockClient((_) async => http.Response('{}', 503)),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(caseService: service),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Account profile is unavailable.'), findsOneWidget);
    expect(find.text('Screening server'), findsOneWidget);
    service.close();
  });

  testWidgets('unverified Doctor sees account state without fetching cases',
      (tester) async {
    var requests = 0;
    final service = DoctorCaseService(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester.pumpWidget(MaterialApp(
      home: DoctorWorkspace(
        caseService: service,
        profile: const {
          'application_role': 'doctor',
          'doctor_profiles': {
            'display_name': 'Synthetic Doctor',
            'verification_state': 'pending',
            'specialization': 'Oral medicine',
            'qualification': 'Synthetic qualification',
            'registration_reference': 'TEST-001',
          },
        },
      ),
    ));
    expect(find.textContaining('Verification pending'), findsOneWidget);
    expect(find.byTooltip('Screening server'), findsOneWidget);
    expect(find.text('No assigned cases yet.'), findsNothing);
    expect(requests, 0);
    service.close();
  });

  testWidgets('verified Doctor sees real assignment and status filter',
      (tester) async {
    final service = DoctorCaseService(
      client: MockClient((request) async {
        expect(request.url.path, '/doctor/cases');
        return http.Response(
          '{"items":[{"id":"assignment-1","assigned_at":"2026-11-12",'
          '"review_requests":{"screening_id":"screening-1","status":"assigned"}}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester.pumpWidget(MaterialApp(
      home: DoctorWorkspace(
        caseService: service,
        profile: const {
          'application_role': 'doctor',
          'doctor_profiles': {
            'display_name': 'Synthetic Doctor',
            'verification_state': 'verified',
          },
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Case screening-1'), findsOneWidget);
    expect(find.textContaining('1 assigned'), findsOneWidget);
    await tester.tap(find.text('in review').first);
    await tester.pumpAndSettle();
    expect(find.text('No cases in this status.'), findsOneWidget);
    service.close();
  });
}
