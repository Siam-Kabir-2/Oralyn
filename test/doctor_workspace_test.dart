import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/services/doctor_case_service.dart';
import 'package:oralyn/views/screens/doctors/doctor_workspace.dart';

void main() {
  testWidgets('app remains navigable while role lookup is pending',
      (tester) async {
    final roleResponse = Completer<http.Response>();
    final service = DoctorCaseService(
      client: MockClient((request) async {
        if (request.url.path == '/me') return roleResponse.future;
        return http.Response('{}', 503);
      }),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(caseService: service),
    ));
    await tester.pump();
    expect(find.textContaining('Connecting to the server'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    roleResponse.complete(http.Response('{"application_role":"patient"}', 200));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connecting to the server'), findsNothing);
    service.close();
  });

  testWidgets('Patient entering Doctor sign in sees application, not cases',
      (tester) async {
    var caseRequests = 0;
    final service = DoctorCaseService(
      client: MockClient((request) async {
        if (request.url.path == '/doctor/cases') caseRequests++;
        return http.Response('{"application_role":"patient"}', 200);
      }),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(caseService: service, preferredRole: 'doctor'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Apply as Doctor'), findsOneWidget);
    expect(find.text('Continue as Patient'), findsOneWidget);
    expect(caseRequests, 0);
    service.close();
  });

  testWidgets('pending Doctor refresh enters workspace after verification',
      (tester) async {
    var verified = false;
    var caseRequests = 0;
    final service = DoctorCaseService(
      client: MockClient((request) async {
        if (request.url.path == '/me') {
          return http.Response(
              '{"application_role":"doctor",'
              '"doctor_profiles":{"display_name":"Synthetic Doctor",'
              '"verification_state":"${verified ? 'verified' : 'pending'}"}}',
              200);
        }
        if (request.url.path == '/doctor/cases') {
          caseRequests++;
          return http.Response('{"items":[]}', 200);
        }
        return http.Response('{}', 404);
      }),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic-session',
    );
    await tester
        .pumpWidget(MaterialApp(home: RoleHomeScreen(caseService: service)));
    await tester.pumpAndSettle();
    expect(find.text('Application pending'), findsOneWidget);
    expect(caseRequests, 0);
    verified = true;
    await tester.tap(find.text('Refresh status'));
    await tester.pumpAndSettle();
    expect(find.text('Doctor workspace'), findsOneWidget);
    expect(caseRequests, 1);
    service.close();
  });

  testWidgets('role loading error allows browsing before server setup',
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
    expect(find.textContaining('Server unavailable.'), findsOneWidget);
    expect(find.text('Set up'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
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
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'in review'));
    await tester.pumpAndSettle();
    expect(find.text('No cases in this status.'), findsOneWidget);
    service.close();
  });
}
