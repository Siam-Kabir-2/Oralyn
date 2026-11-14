import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/data/mock/mock_data.dart';
import 'package:oralyn/models/screening_result.dart';
import 'package:oralyn/models/screening_session.dart';
import 'package:oralyn/services/screening_history_service.dart';
import 'package:oralyn/services/screening_history_updates.dart';
import 'package:oralyn/views/screens/history/history_screens.dart';

class _HistoryRepository implements ScreeningHistoryRepository {
  List<ScreeningResult> results = [];
  int listCalls = 0;

  @override
  Future<List<ScreeningResult>> list() async {
    listCalls++;
    return results;
  }

  @override
  Future<ScreeningResult> save(ScreeningPhoto photo,
          {required String idempotencyKey}) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> loadAsset(String path) async => Uint8List(0);

  @override
  Future<void> delete(String id) async {}

  @override
  void close() {}
}

void main() {
  testWidgets('mounted History refreshes after a successful save signal',
      (tester) async {
    final repository = _HistoryRepository();
    await tester.pumpWidget(MaterialApp(
        home: HistoryScreen(repository: repository, standalone: true)));
    await tester.pumpAndSettle();
    expect(find.text('No saved screenings yet.'), findsOneWidget);

    repository.results = [MockData.results.first];
    ScreeningHistoryUpdates.instance.saved();
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(find.text('No saved screenings yet.'), findsNothing);
    expect(find.textContaining('Low Concern'), findsWidgets);
  });
}
