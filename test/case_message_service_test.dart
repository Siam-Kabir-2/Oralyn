import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oralyn/services/case_message_service.dart';

void main() {
  final assignmentId = '40000000-0000-4000-8000-000000000001';
  final messageId = '50000000-0000-4000-8000-000000000001';
  final clientId = '60000000-0000-4000-8000-000000000001';

  test('conversation list uses Clerk token and safe case fields', () async {
    final service = CaseMessageService(
      client: MockClient((request) async {
        expect(request.url.path, '/conversations');
        expect(request.headers['authorization'], 'Bearer synthetic');
        return http.Response(
            jsonEncode({
              'items': [
                {
                  'assignment_id': assignmentId,
                  'screening_id': '70000000-0000-4000-8000-000000000001',
                  'doctor_name': 'Synthetic Doctor',
                  'status': 'assigned',
                  'is_active': true,
                  'assigned_at': '2026-11-17T00:00:00Z',
                  'last_message_preview': null,
                  'last_message_at': null
                },
              ]
            }),
            200);
      }),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic',
    );
    final conversations = await service.conversations();
    expect(conversations.single.doctorName, 'Synthetic Doctor');
    expect(conversations.single.isActive, isTrue);
    service.close();
  });

  test('message page sends cursor and send reuses supplied retry id', () async {
    var calls = 0;
    final service = CaseMessageService(
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer synthetic');
        calls++;
        if (request.method == 'GET') {
          expect(request.url.path, '/cases/$assignmentId/messages');
          expect(request.url.queryParameters['before_id'], messageId);
          expect(request.url.queryParameters['limit'], '25');
          return http.Response('{"items":[]}', 200);
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/cases/$assignmentId/messages');
        expect(jsonDecode(request.body), {
          'client_message_id': clientId,
          'body': 'Synthetic question',
        });
        return http.Response(
            jsonEncode({
              'id': messageId,
              'body': 'Synthetic question',
              'sender_is_self': true,
              'created_at': '2026-11-17T00:00:00Z',
            }),
            200);
      }),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic',
    );
    final before = CaseMessage(
        id: messageId,
        body: 'Previous',
        senderIsSelf: true,
        createdAt: DateTime.utc(2026, 11, 17));
    expect(await service.messages(assignmentId, before: before, limit: 25),
        isEmpty);
    final sent = await service.send(assignmentId, '  Synthetic question  ',
        clientMessageId: clientId);
    expect(sent.body, 'Synthetic question');
    expect(calls, 2);
    service.close();
  });

  test('revoked case and expired session cannot send', () async {
    final revoked = CaseMessageService(
      client: MockClient((_) async => http.Response('{}', 404)),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => 'synthetic',
    );
    await expectLater(
      revoked.send(assignmentId, 'Synthetic message',
          clientMessageId: clientId),
      throwsA(isA<CaseMessageException>().having((error) => error.message,
          'message', contains('no longer available'))),
    );
    revoked.close();

    final expired = CaseMessageService(
      client: MockClient((_) async => throw StateError('must not call API')),
      predictionEndpoint: Uri.parse('https://example.test/predict'),
      tokenProvider: () async => null,
    );
    await expectLater(
        expired.conversations(), throwsA(isA<CaseMessageException>()));
    expired.close();
  });
}
