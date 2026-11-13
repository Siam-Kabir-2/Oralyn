abstract final class ApiConfig {
  static const _defaultBaseUrl =
      'https://manufacturing-yea-guild-roommates.trycloudflare.com';
  static const defaultPredictionPath = '/predict';

  static const baseUrl = String.fromEnvironment(
    'ORALYN_API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static Uri get predictionUri {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBaseUrl$defaultPredictionPath');
  }
}
