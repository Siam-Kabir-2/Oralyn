import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';

class ApiSettingsService {
  static const _baseUrlPreferenceKey = 'oralyn_api_base_url';

  Future<String> getPredictionUrl() async {
    final preferences = await SharedPreferences.getInstance();
    final savedValue = preferences.getString(_baseUrlPreferenceKey);
    return normalizePredictionUrl(
      savedValue ?? ApiConfig.predictionUri.toString(),
    );
  }

  Future<Uri> getPredictionUri() async {
    return Uri.parse(await getPredictionUrl());
  }

  Future<String> savePredictionUrl(String value) async {
    final normalized = normalizePredictionUrl(value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlPreferenceKey, normalized);
    return normalized;
  }

  Future<void> resetPredictionUrl() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_baseUrlPreferenceKey);
  }

  static String normalizePredictionUrl(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Enter the Cloudflare API URL.');
    }

    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Enter a valid HTTPS URL, for example '
        'https://example.trycloudflare.com/docs/predict',
      );
    }

    var predictionPath = uri.path;
    if (predictionPath.isEmpty || predictionPath == '/') {
      predictionPath = ApiConfig.defaultPredictionPath;
    } else {
      while (predictionPath.endsWith('/')) {
        predictionPath = predictionPath.substring(0, predictionPath.length - 1);
      }
      if (predictionPath.toLowerCase() == '/docs/predict' ||
          predictionPath.toLowerCase() == '/docs') {
        predictionPath = ApiConfig.defaultPredictionPath;
      }
    }

    return Uri(
      scheme: 'https',
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: predictionPath,
    ).toString();
  }
}
