import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/services/api_settings_service.dart';

void main() {
  test('adds the default prediction path to a Cloudflare base URL', () {
    expect(
      ApiSettingsService.normalizePredictionUrl(
        ' https://example.trycloudflare.com/ ',
      ),
      'https://example.trycloudflare.com/predict',
    );
  });

  test('corrects a Swagger docs prediction URL', () {
    expect(
      ApiSettingsService.normalizePredictionUrl(
        'https://example.trycloudflare.com/docs/predict',
      ),
      'https://example.trycloudflare.com/predict',
    );
  });

  test('rejects non-HTTPS and query parameters', () {
    expect(
      () => ApiSettingsService.normalizePredictionUrl('http://example.test'),
      throwsFormatException,
    );
    expect(
      () => ApiSettingsService.normalizePredictionUrl(
        'https://example.test/predict?debug=true',
      ),
      throwsFormatException,
    );
  });
}
