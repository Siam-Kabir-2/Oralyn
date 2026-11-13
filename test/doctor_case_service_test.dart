import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/services/doctor_case_service.dart';

void main() {
  final endpoint = Uri.parse('https://screening.example/predict');

  test('assigned case list carries the current Clerk token', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/doctor/cases');
      expect(request.headers['authorization'], 'Bearer doctor-session');
      return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'assignment-1',
                'review_requests': {'status': 'assigned'}
              }
            ]
          }),
          200);
    });
    final service = DoctorCaseService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => 'doctor-session');
    expect((await service.cases()).single['id'], 'assignment-1');
  });

  test('review save sends version and user supplied clinical text', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/doctor/cases/assignment-1/review');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['expected_version'], 2);
      expect(body['submit'], isTrue);
      expect(body['observations'], 'Synthetic observation');
      return http.Response(
          jsonEncode({'review_version': 3, 'review_state': 'submitted'}), 200);
    });
    final service = DoctorCaseService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => 'doctor-session');
    final saved = await service.saveReview('assignment-1',
        expectedVersion: 2,
        observations: 'Synthetic observation',
        recommendations: 'Synthetic advice',
        followUp: 'Review later',
        submit: true);
    expect(saved['review_state'], 'submitted');
  });

  test('revoked case and expired session are rejected', () async {
    final client = MockClient((request) async => http.Response('{}', 404));
    final service = DoctorCaseService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => 'doctor-session');
    await expectLater(
        service.detail('revoked'), throwsA(isA<DoctorCaseException>()));
    final expired = DoctorCaseService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => null);
    await expectLater(expired.cases(), throwsA(isA<DoctorCaseException>()));
  });

  test('network failures become user-facing case errors', () async {
    final client = MockClient((_) async {
      throw http.ClientException('synthetic network failure');
    });
    final service = DoctorCaseService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => 'doctor-session');
    await expectLater(
      service.cases(),
      throwsA(isA<DoctorCaseException>().having(
          (error) => error.message, 'message', contains('Unable to reach'))),
    );
  });

  test('Doctor application uses Clerk identity without client role fields',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/doctor/applications');
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer applicant-session');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['display_name'], 'Synthetic Applicant');
      expect(body.containsKey('application_role'), isFalse);
      expect(body.containsKey('verification_state'), isFalse);
      return http.Response(jsonEncode({'verification_state': 'pending'}), 201);
    });
    final service = DoctorCaseService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => 'applicant-session');
    final result = await service.applyAsDoctor({
      'display_name': 'Synthetic Applicant',
      'registration_reference': 'TEST-001',
      'qualification': 'Synthetic degree',
      'specialization': 'Oral medicine',
      'workplace': 'Test clinic',
    });
    expect(result['verification_state'], 'pending');
  });

  test('verified directory consumes only the authenticated API', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/doctors');
      expect(request.headers['authorization'], 'Bearer patient-session');
      return http.Response(
          jsonEncode({
            'items': [
              {
                'display_name': 'Synthetic Verified Doctor',
                'specialization': 'Oral medicine',
                'qualification': 'Test degree'
              }
            ]
          }),
          200);
    });
    final service = DoctorCaseService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => 'patient-session');
    expect((await service.verifiedDoctors()).single['display_name'],
        'Synthetic Verified Doctor');
  });
}
