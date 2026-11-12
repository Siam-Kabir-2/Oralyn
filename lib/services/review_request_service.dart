import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_settings_service.dart';
import 'clerk_session_provider.dart';

class ReviewRequestStatus {
  const ReviewRequestStatus(
      {required this.id, required this.screeningId, required this.status});
  final String id;
  final String screeningId;
  final String status;

  factory ReviewRequestStatus.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final screeningId = json['screening_id'];
    final status = json['status'];
    if (id is! String || status is! String) {
      throw const FormatException('Review request response is invalid.');
    }
    return ReviewRequestStatus(
      id: id,
      screeningId: screeningId is String ? screeningId : '',
      status: status,
    );
  }
}

class ReviewRequestException implements Exception {
  const ReviewRequestException(this.message);
  final String message;
}

class ReviewRequestService {
  ReviewRequestService(
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
    if (token == null || token.isEmpty) {
      throw const ReviewRequestException(
          'Your session has ended. Sign in again.');
    }
    final endpoint =
        _predictionEndpoint ?? await _settingsService.getPredictionUri();
    return (
      base: endpoint.replace(path: '', query: null, fragment: null),
      token: token
    );
  }

  Future<List<ReviewRequestStatus>> list() async {
    final context = await _context();
    final response = await _client.get(
      context.base.resolve('/review-requests'),
      headers: {'authorization': 'Bearer ${context.token}'},
    ).timeout(const Duration(seconds: 20));
    _check(response);
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['items'] is! List) {
      throw const FormatException('Review request list is invalid.');
    }
    return List.unmodifiable((body['items'] as List).map(
        (item) => ReviewRequestStatus.fromJson(item as Map<String, dynamic>)));
  }

  Future<List<Map<String, dynamic>>> feedback() async {
    final context = await _context();
    final response = await _client.get(
      context.base.resolve('/feedback'),
      headers: {'authorization': 'Bearer ${context.token}'},
    ).timeout(const Duration(seconds: 20));
    _check(response);
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['items'] is! List) {
      throw const FormatException('Doctor feedback is invalid.');
    }
    return List.unmodifiable(
        (body['items'] as List).cast<Map<String, dynamic>>());
  }

  Future<ReviewRequestStatus> request(String screeningId) async {
    final context = await _context();
    final response = await _client
        .post(
          context.base.resolve('/screenings/$screeningId/review-request'),
          headers: {
            'authorization': 'Bearer ${context.token}',
            'content-type': 'application/json',
          },
          body: jsonEncode({'consent_to_share': true}),
        )
        .timeout(const Duration(seconds: 20));
    _check(response);
    return ReviewRequestStatus.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final message = switch (response.statusCode) {
      401 || 403 => 'Your account is not authorized. Sign in again.',
      404 => 'This screening is not eligible for review.',
      _ => 'Review service is temporarily unavailable. Try again.',
    };
    throw ReviewRequestException(message);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
