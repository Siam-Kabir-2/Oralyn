import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/models/screening_result.dart';
import 'package:oralyn/models/screening_session.dart';
import 'package:oralyn/services/screening_history_service.dart';

Map<String, dynamic> storedResult({String id = 'screening-1'}) => {
      'id': id,
      'created_at': '2026-11-11T10:00:00Z',
      'primary_prediction': 'Normal',
      'primary_score': 0.91,
      'primary_predictions': [
        {'class': 'Normal', 'score': 0.91},
      ],
      'cancer_verification': {'performed': false},
      'gradcam': {
        'available': true,
        'label': 'Area highlighted for review',
        'asset_path': '/screenings/$id/assets/gradcam',
      },
      'screening_status': 'Low Concern',
      'model': {
        'primary': 'primary-model',
        'verification': 'verification-model'
      },
      'disclaimer': 'Synthetic test only.',
      'image_path': '/screenings/$id/assets/original',
    };

void main() {
  const prediction = 'https://api.example/predict';

  test('lists authenticated saved screenings and maps private asset paths',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/screenings');
      expect(request.headers['authorization'], 'Bearer clerk-session');
      return http.Response(
          jsonEncode({
            'items': [storedResult()]
          }),
          200);
    });
    final repository = ScreeningHistoryApiRepository(
      client: client,
      predictionEndpoint: Uri.parse(prediction),
      tokenProvider: () async => 'clerk-session',
    );

    final results = await repository.list();
    expect(results, hasLength(1));
    expect(results.single.category, LesionCategory.healthy);
    expect(results.single.imagePath, '/screenings/screening-1/assets/original');
    expect(
      results.single.gradCamAssetPath,
      '/screenings/screening-1/assets/gradcam',
    );
  });

  test('save sends image and caller idempotency key', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/screenings');
      expect(request.headers['authorization'], 'Bearer clerk-session');
      expect(request.headers['content-type'], contains('multipart/form-data'));
      expect(latin1.decode(request.bodyBytes), contains('mobile_retry_key_0001'));
      expect(
          request.bodyBytes, containsAllInOrder(<int>[0x89, 0x50, 0x4e, 0x47]));
      return http.Response(jsonEncode(storedResult()), 200);
    });
    final repository = ScreeningHistoryApiRepository(
      client: client,
      predictionEndpoint: Uri.parse(prediction),
      tokenProvider: () async => 'clerk-session',
    );
    final result = await repository.save(
      ScreeningPhoto(
        bytes: Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]),
        name: 'synthetic.png',
        fromCamera: false,
      ),
      idempotencyKey: 'mobile_retry_key_0001',
    );
    expect(result.id, 'screening-1');
  });

  test('loads private bytes and deletes through authenticated API', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers['authorization'], 'Bearer clerk-session');
      if (request.method == 'GET') {
        return http.Response.bytes([1, 2, 3], 200);
      }
      expect(request.method, 'DELETE');
      return http.Response('', 204);
    });
    final repository = ScreeningHistoryApiRepository(
      client: client,
      predictionEndpoint: Uri.parse(prediction),
      tokenProvider: () async => 'clerk-session',
    );
    expect(
      await repository.loadAsset('/screenings/screening-1/assets/original'),
      Uint8List.fromList([1, 2, 3]),
    );
    await repository.delete('screening-1');
    expect(calls, 2);
  });

  test('requires an active Clerk session before any request', () async {
    final repository = ScreeningHistoryApiRepository(
      client: MockClient((_) async => fail('must not make a request')),
      predictionEndpoint: Uri.parse(prediction),
      tokenProvider: () async => null,
    );
    await expectLater(
      repository.list(),
      throwsA(isA<ScreeningHistoryException>()),
    );
  });

  test('cross-user style not-found is privacy-safe', () async {
    final repository = ScreeningHistoryApiRepository(
      client: MockClient((_) async => http.Response('', 404)),
      predictionEndpoint: Uri.parse(prediction),
      tokenProvider: () async => 'clerk-session',
    );
    await expectLater(
      repository.loadAsset('/screenings/other-user/assets/original'),
      throwsA(
        isA<ScreeningHistoryException>().having(
          (error) => error.message,
          'message',
          'This saved screening is no longer available.',
        ),
      ),
    );
  });
}
