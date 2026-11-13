import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_settings_service.dart';
import 'clerk_session_provider.dart';

class DoctorCaseService {
  DoctorCaseService(
      {http.Client? client,
      Uri? predictionEndpoint,
      Future<String?> Function()? tokenProvider,
      ApiSettingsService? settingsService})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _predictionEndpoint = predictionEndpoint,
        _tokenProvider = tokenProvider ?? ClerkSessionProvider.token,
        _settingsService = settingsService ?? ApiSettingsService();

  final http.Client _client;
  final bool _ownsClient;
  final Uri? _predictionEndpoint;
  final Future<String?> Function() _tokenProvider;
  final ApiSettingsService _settingsService;

  Future<({Uri base, String token})> _context() async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty)
      throw const DoctorCaseException('Session expired. Sign in again.');
    final endpoint =
        _predictionEndpoint ?? await _settingsService.getPredictionUri();
    return (
      base: endpoint.replace(path: '', query: null, fragment: null),
      token: token
    );
  }

  Future<Map<String, dynamic>> profile() async => _get('/me');
  Future<List<Map<String, dynamic>>> cases() async {
    final body = await _get('/doctor/cases');
    final items = body['items'];
    if (items is! List) throw const FormatException('Case list is invalid.');
    return List.unmodifiable(items.cast<Map<String, dynamic>>());
  }

  Future<Map<String, dynamic>> detail(String id) async =>
      _get('/doctor/cases/$id');

  Future<Map<String, dynamic>> saveReview(
    String assignmentId, {
    required int expectedVersion,
    required String observations,
    required String recommendations,
    required String followUp,
    required bool submit,
  }) async {
    try {
      final context = await _context();
      final response = await _client
          .put(
            context.base.resolve('/doctor/cases/$assignmentId/review'),
            headers: {
              'authorization': 'Bearer ${context.token}',
              'content-type': 'application/json'
            },
            body: jsonEncode({
              'expected_version': expectedVersion,
              'observations': observations,
              'recommendations': recommendations,
              'follow_up': followUp,
              'submit': submit
            }),
          )
          .timeout(const Duration(seconds: 20));
      _check(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw const DoctorCaseException(
          'The case service took too long to respond. Try again.');
    } on http.ClientException {
      throw const DoctorCaseException(
          'Unable to reach the case service. Check your connection.');
    } on FormatException {
      throw const DoctorCaseException('The case service response is invalid.');
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final context = await _context();
      final response = await _client.get(
        context.base.resolve(path),
        headers: {'authorization': 'Bearer ${context.token}'},
      ).timeout(const Duration(seconds: 20));
      _check(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw const DoctorCaseException(
          'The case service took too long to respond. Try again.');
    } on http.ClientException {
      throw const DoctorCaseException(
          'Unable to reach the case service. Check your connection.');
    } on FormatException {
      throw const DoctorCaseException('The case service response is invalid.');
    }
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw DoctorCaseException(switch (response.statusCode) {
      401 => 'Session expired. Sign in again.',
      403 => 'Verified Doctor access is required.',
      404 => 'This case is no longer assigned to you.',
      409 => 'This review changed. Reload the case before editing.',
      _ => 'Case service is unavailable. Try again.',
    });
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class DoctorCaseException implements Exception {
  const DoctorCaseException(this.message);
  final String message;
}
