import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_settings_service.dart';
import 'clerk_session_provider.dart';

class CaseConversation {
  const CaseConversation({
    required this.assignmentId,
    required this.screeningId,
    required this.doctorName,
    required this.status,
    required this.isActive,
    required this.assignedAt,
    this.lastMessageAt,
    this.lastMessagePreview,
  });

  final String assignmentId;
  final String screeningId;
  final String doctorName;
  final String status;
  final bool isActive;
  final DateTime assignedAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;

  factory CaseConversation.fromJson(Map<String, dynamic> json) {
    final id = json['assignment_id'];
    final screening = json['screening_id'];
    final active = json['is_active'];
    final assigned = DateTime.tryParse('${json['assigned_at']}');
    if (id is! String ||
        screening is! String ||
        active is! bool ||
        assigned == null) {
      throw const FormatException('Conversation response is invalid.');
    }
    return CaseConversation(
      assignmentId: id,
      screeningId: screening,
      doctorName: json['doctor_name'] is String
          ? json['doctor_name'] as String
          : 'Doctor',
      status: json['status'] is String ? json['status'] as String : 'assigned',
      isActive: active,
      assignedAt: assigned,
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.tryParse('${json['last_message_at']}'),
      lastMessagePreview: json['last_message_preview'] as String?,
    );
  }
}

class CaseMessage {
  const CaseMessage({
    required this.id,
    required this.body,
    required this.senderIsSelf,
    required this.createdAt,
  });

  final String id;
  final String body;
  final bool senderIsSelf;
  final DateTime createdAt;

  factory CaseMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final body = json['body'];
    final self = json['sender_is_self'];
    final created = DateTime.tryParse('${json['created_at']}');
    if (id is! String || body is! String || self is! bool || created == null) {
      throw const FormatException('Message response is invalid.');
    }
    return CaseMessage(
      id: id,
      body: body,
      senderIsSelf: self,
      createdAt: created,
    );
  }
}

class CaseMessageException implements Exception {
  const CaseMessageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CaseMessageService {
  CaseMessageService({
    http.Client? client,
    Uri? predictionEndpoint,
    Future<String?> Function()? tokenProvider,
    ApiSettingsService? settingsService,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _predictionEndpoint = predictionEndpoint,
        _tokenProvider = tokenProvider ?? ClerkSessionProvider.token,
        _settingsService = settingsService ?? ApiSettingsService();

  final http.Client _client;
  final bool _ownsClient;
  final Uri? _predictionEndpoint;
  final Future<String?> Function() _tokenProvider;
  final ApiSettingsService _settingsService;

  static String newMessageId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<({Uri base, String token})> _context() async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const CaseMessageException('Session expired. Sign in again.');
    }
    final endpoint =
        _predictionEndpoint ?? await _settingsService.getPredictionUri();
    return (
      base: endpoint.replace(path: '', query: null, fragment: null),
      token: token
    );
  }

  Future<List<CaseConversation>> conversations() async {
    final context = await _context();
    final response = await _send(() => _client.get(
          context.base.resolve('/conversations'),
          headers: {'authorization': 'Bearer ${context.token}'},
        ));
    final rows = _items(response);
    return List.unmodifiable(rows.map(CaseConversation.fromJson));
  }

  Future<List<CaseMessage>> messages(
    String assignmentId, {
    CaseMessage? before,
    int limit = 50,
  }) async {
    final context = await _context();
    final uri = context.base.resolve('/cases/$assignmentId/messages').replace(
      queryParameters: {
        'limit': '$limit',
        if (before != null)
          'before_at': before.createdAt.toUtc().toIso8601String(),
        if (before != null) 'before_id': before.id,
      },
    );
    final response = await _send(() => _client.get(
          uri,
          headers: {'authorization': 'Bearer ${context.token}'},
        ));
    return List.unmodifiable(_items(response).map(CaseMessage.fromJson));
  }

  Future<CaseMessage> send(
    String assignmentId,
    String body, {
    required String clientMessageId,
  }) async {
    final context = await _context();
    final response = await _send(() => _client.post(
          context.base.resolve('/cases/$assignmentId/messages'),
          headers: {
            'authorization': 'Bearer ${context.token}',
            'content-type': 'application/json'
          },
          body: jsonEncode(
              {'client_message_id': clientMessageId, 'body': body.trim()}),
        ));
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) {
      throw const CaseMessageException('Message response is invalid.');
    }
    return CaseMessage.fromJson(value);
  }

  List<Map<String, dynamic>> _items(http.Response response) {
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic> || value['items'] is! List) {
      throw const CaseMessageException('Conversation response is invalid.');
    }
    return (value['items'] as List).map((item) {
      if (item is! Map<String, dynamic>) {
        throw const CaseMessageException('Conversation response is invalid.');
      }
      return item;
    }).toList();
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw CaseMessageException(switch (response.statusCode) {
        401 => 'Session expired. Sign in again.',
        404 => 'This conversation is no longer available.',
        409 => 'This message was already sent with different content.',
        422 => 'The message or page request is invalid.',
        _ => 'Messaging is temporarily unavailable. Try again.',
      });
    } on TimeoutException {
      throw const CaseMessageException('Messaging timed out. Try again.');
    } on http.ClientException {
      throw const CaseMessageException(
          'Unable to reach messaging. Check your connection.');
    } on FormatException {
      throw const CaseMessageException('Messaging response is invalid.');
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
