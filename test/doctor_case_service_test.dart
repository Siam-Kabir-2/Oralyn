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
}
