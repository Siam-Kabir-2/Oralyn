import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/screening_result.dart';
import '../models/screening_session.dart';
import 'api_settings_service.dart';
import 'clerk_session_provider.dart';

class ScreeningHistoryException implements Exception {
  const ScreeningHistoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class ScreeningHistoryRepository {
  Future<List<ScreeningResult>> list();
  Future<ScreeningResult> save(
    ScreeningPhoto photo, {
    required String idempotencyKey,
  });
  Future<Uint8List> loadAsset(String path);
  Future<void> delete(String id);
  void close();
}

class ScreeningHistoryApiRepository implements ScreeningHistoryRepository {
  ScreeningHistoryApiRepository({
    http.Client? client,
    Uri? predictionEndpoint,
    Future<String?> Function()? tokenProvider,
    ApiSettingsService? settingsService,
    this.timeout = const Duration(seconds: 60),
  })  : _client = client ?? http.Client(),
        _predictionEndpoint = predictionEndpoint,
        _settingsService = settingsService ?? ApiSettingsService(),
        _tokenProvider = tokenProvider ?? ClerkSessionProvider.token;

  final http.Client _client;
  final Uri? _predictionEndpoint;
  final ApiSettingsService _settingsService;
  final Future<String?> Function() _tokenProvider;
  final Duration timeout;

  Future<({String token, Uri base})> _context() async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const ScreeningHistoryException(
        'Your session has ended. Sign in and try again.',
      );
    }
    final prediction =
        _predictionEndpoint ?? await _settingsService.getPredictionUri();
    return (
      token: token,
      base: prediction.replace(path: '', query: null, fragment: null),
    );
  }

  @override
  Future<List<ScreeningResult>> list() async {
    final context = await _context();
    final response = await _send(
      http.Request('GET', context.base.resolve('/screenings'))
        ..headers['authorization'] = 'Bearer ${context.token}',
    );
    final body = _json(response);
    final items = body['items'];
    if (items is! List) throw const FormatException('History list is invalid.');
    return List.unmodifiable(items.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('History item is invalid.');
      }
      return ScreeningResult.fromStoredJson(item);
    }));
  }

  @override
  Future<ScreeningResult> save(
    ScreeningPhoto photo, {
    required String idempotencyKey,
  }) async {
    final context = await _context();
    final request = http.MultipartRequest(
      'POST',
      context.base.resolve('/screenings'),
    )
      ..headers['authorization'] = 'Bearer ${context.token}'
      ..fields['idempotency_key'] = idempotencyKey
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          photo.bytes,
          filename: photo.name.split(RegExp(r'[/\\]')).last,
          contentType: _mediaType(photo.name),
        ),
      );
    final response = await _send(request);
    return ScreeningResult.fromStoredJson(_json(response));
  }

  @override
  Future<Uint8List> loadAsset(String path) async {
    final context = await _context();
    final response = await _send(
      http.Request('GET', context.base.resolve(path))
        ..headers['authorization'] = 'Bearer ${context.token}',
      expectJson: false,
    );
    return response.bodyBytes;
  }

  @override
  Future<void> delete(String id) async {
    final context = await _context();
    await _send(
      http.Request('DELETE', context.base.resolve('/screenings/$id'))
        ..headers['authorization'] = 'Bearer ${context.token}',
      expectJson: false,
    );
  }

  Future<http.Response> _send(
    http.BaseRequest request, {
    bool expectJson = true,
  }) async {
    try {
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (response.statusCode) {
          401 || 403 => 'Your session is no longer authorized. Sign in again.',
          404 => 'This saved screening is no longer available.',
          _ => 'Screening history is temporarily unavailable. Try again.',
        };
        throw ScreeningHistoryException(message);
      }
      if (expectJson && response.body.isEmpty) {
        throw const FormatException('History response is empty.');
      }
      return response;
    } on TimeoutException {
      throw const ScreeningHistoryException(
        'Screening history took too long to respond. Try again.',
      );
    } on http.ClientException {
      throw const ScreeningHistoryException(
        'Unable to reach screening history. Check your connection.',
      );
    }
  }

  Map<String, dynamic> _json(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('History response is invalid.');
    }
    return decoded;
  }

  MediaType _mediaType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.bmp')) return MediaType('image', 'bmp');
    return MediaType('image', 'jpeg');
  }

  @override
  void close() => _client.close();
}
