import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/models/screening_result.dart';
import 'package:oralyn/models/screening_session.dart';
import 'package:oralyn/services/screening_api_service.dart';

void main() {
  final photo = ScreeningPhoto(
    bytes: Uint8List.fromList([1, 2, 3]),
    name: 'oral-photo.jpg',
    fromCamera: true,
  );

  test('uploads the image and maps a successful prediction', () async {
    late http.BaseRequest capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'primary_prediction': 'OPMD',
          'primary_score': 0.8234,
          'primary_predictions': [
            {'class': 'OPMD', 'score': 0.8234},
            {'class': 'Normal', 'score': 0.1766},
          ],
          'cancer_verification': {
            'performed': true,
            'prediction': 'Cancer',
            'score': 0.71,
            'predictions': [
              {'class': 'Cancer', 'score': 0.71},
              {'class': 'Non_Cancer', 'score': 0.29},
            ],
          },
          'gradcam': {
            'available': true,
            'label': 'Area highlighted for review',
            'image_base64': 'data:image/jpeg;base64,ZmFrZQ==',
          },
          'screening_status': 'Prompt Specialist Review',
          'model': {
            'primary': 'ResNet50 SMART-OM 4-class',
            'verification': 'ResNet50 BMIOCD binary',
          },
          'disclaimer':
              'AI-assisted research screening only. This result is not a clinical diagnosis.',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = ScreeningApiService(
      client: client,
      endpoint: Uri.parse('https://example.test/predict'),
      apiKey: 'test-key',
    );

    final result = await service.analyze(photo);

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/predict');
    expect(capturedRequest.headers['x-api-key'], 'test-key');
    expect(
      capturedRequest.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    final finalizedRequest = capturedRequest as http.Request;
    final multipartBody = utf8.decode(
      finalizedRequest.bodyBytes,
      allowMalformed: true,
    );
    expect(multipartBody, contains('name="image"'));
    expect(multipartBody, contains('filename="oral-photo.jpg"'));
    expect(multipartBody.toLowerCase(), contains('content-type: image/jpeg'));
    expect(result.category, LesionCategory.opmd);
    expect(result.risk, RiskLevel.promptSpecialistReview);
    expect(result.status, 'Prompt Specialist Review');
    expect(result.confidence, closeTo(0.8234, 0.00001));
    expect(result.topPredictions, hasLength(2));
    expect(result.model, 'ResNet50 SMART-OM 4-class');
    expect(result.verificationModel, 'ResNet50 BMIOCD binary');
    expect(result.cancerVerificationPerformed, isTrue);
    expect(result.cancerVerificationPrediction, 'Cancer');
    expect(result.cancerVerificationScore, closeTo(0.71, 0.00001));
    expect(result.cancerVerificationPredictions, hasLength(2));
    expect(result.gradCamAvailable, isTrue);
    expect(result.gradCamLabel, 'Area highlighted for review');
    expect(result.gradCamImageBase64, startsWith('data:image/jpeg;base64,'));

    service.close();
  });

  test('handles a low-concern result without cancer verification', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'primary_prediction': 'Normal',
            'primary_score': 0.9,
            'primary_predictions': [
              {'class': 'Normal', 'score': 0.9},
              {'class': 'Variation_from_Normal', 'score': 0.1},
            ],
            'cancer_verification': {'performed': false},
            'screening_status': 'Low Concern',
            'model': {
              'primary': 'ResNet50 SMART-OM 4-class',
              'verification': 'ResNet50 BMIOCD binary',
            },
            'disclaimer':
                'AI-assisted research screening only. This result is not a clinical diagnosis.',
          }),
          200,
        ));
    final service = ScreeningApiService(
      client: client,
      endpoint: Uri.parse('https://example.test/predict'),
      apiKey: 'test-key',
    );

    final result = await service.analyze(photo);

    expect(result.category, LesionCategory.healthy);
    expect(result.risk, RiskLevel.lowConcern);
    expect(result.cancerVerificationPerformed, isFalse);
    expect(result.cancerVerificationPrediction, isNull);

    service.close();
  });

  test('reports an unauthorized API key clearly', () async {
    final service = ScreeningApiService(
      client: MockClient((_) async => http.Response('{}', 401)),
      endpoint: Uri.parse('https://example.test/predict'),
      apiKey: 'wrong-key',
    );

    await expectLater(
      service.analyze(photo),
      throwsA(
        isA<PredictionException>().having(
          (error) => error.kind,
          'kind',
          PredictionErrorKind.unauthorized,
        ),
      ),
    );

    service.close();
  });
}
