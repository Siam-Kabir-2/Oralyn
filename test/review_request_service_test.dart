import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/services/review_request_service.dart';

void main() {
  final endpoint = Uri.parse('https://screening.example/predict');

  test('consent request sends current Clerk token and maps persisted status',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/screenings/screening-1/review-request');
      expect(request.headers['authorization'], 'Bearer session-one');
      expect(jsonDecode(request.body)['consent_to_share'], isTrue);
      return http.Response(
          jsonEncode({'id': 'request-1', 'status': 'pending_assignment'}), 200);
    });
    final service = ReviewRequestService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => 'session-one');
    final result = await service.request('screening-1');
    expect(result.id, 'request-1');
    expect(result.status, 'pending_assignment');
  });

  test('list uses authenticated request and preserves database status',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/review-requests');
      expect(request.headers['authorization'], 'Bearer session-two');
      return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'request-1',
                'screening_id': 'screening-1',
                'status': 'assigned'
              }
            ]
          }),
          200);
    });
    final service = ReviewRequestService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => 'session-two');
    final items = await service.list();
    expect(items.single.screeningId, 'screening-1');
    expect(items.single.status, 'assigned');
  });

  test('expired session never sends a review request', () async {
    var sent = false;
    final client = MockClient((request) async {
      sent = true;
      return http.Response('{}', 200);
    });
    final service = ReviewRequestService(
        client: client,
        predictionEndpoint: endpoint,
        tokenProvider: () async => null);
    await expectLater(
        service.request('screening-1'), throwsA(isA<ReviewRequestException>()));
    expect(sent, isFalse);
  });
}
