import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/controllers/screening_controller.dart';
import 'package:oralyn/data/mock/mock_data.dart';
import 'package:oralyn/models/screening_result.dart';
import 'package:oralyn/models/screening_session.dart';
import 'package:oralyn/services/screening_api_service.dart';
import 'package:oralyn/services/screening_history_service.dart';
import 'package:oralyn/views/screens/screening/screening_flow.dart';
import 'package:oralyn/views/screens/result/result_screens.dart';

class _Analysis implements ScreeningAnalysisService {
  int calls = 0;
  @override
  Future<ScreeningResult> analyze(ScreeningPhoto photo) async {
    calls++;
    return MockData.results.first;
  }

  @override
  void close() {}
}

class _History implements ScreeningHistoryRepository {
  _History({this.fail = false});
  final bool fail;
  int saves = 0;
  String? key;

  @override
  Future<ScreeningResult> save(ScreeningPhoto photo,
      {required String idempotencyKey}) async {
    saves++;
    key = idempotencyKey;
    if (fail) throw const ScreeningHistoryException('Synthetic save failure');
    return MockData.results.first;
  }

  @override
  Future<List<ScreeningResult>> list() async => [];
  @override
  Future<Uint8List> loadAsset(String path) async => Uint8List(0);
  @override
  Future<void> delete(String id) async {}
  @override
  void close() {}
}

void main() {
  testWidgets('new screenings default to private automatic saving',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ScreeningPreparationScreen(),
    ));
    await tester.scrollUntilVisible(
        find.text('Save screening automatically'), 200);
    final saveSwitch =
        tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(saveSwitch.value, isTrue);
  });

  Future<ScreeningOutcome> runFlow(WidgetTester tester,
      {required bool optIn,
      bool fail = false,
      bool ownerChanges = false}) async {
    final analysis = _Analysis();
    final history = _History(fail: fail);
    var ownerReads = 0;
    final photoBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC');
    ScreeningOutcome? outcome;
    await tester.pumpWidget(MaterialApp(
      home: AnalysisScreen(
        photo: ScreeningPhoto(
          bytes: photoBytes,
          name: 'synthetic.png',
          fromCamera: false,
          saveToHistory: optIn,
        ),
        screeningController: ScreeningController(service: analysis),
        historyRepository: history,
        ownerIdProvider: (_) =>
            ownerChanges && ++ownerReads > 1 ? 'user_other' : 'user_synthetic',
      ),
      onGenerateRoute: (settings) {
        outcome = settings.arguments as ScreeningOutcome;
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Result reached')),
        );
      },
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Result reached'), findsOneWidget);
    expect(analysis.calls, 1);
    expect(history.saves, optIn && !ownerChanges ? 1 : 0);
    if (optIn && !ownerChanges) expect(history.key, startsWith('mobile_'));
    return outcome!;
  }

  testWidgets('consented screening is saved before showing result',
      (tester) async {
    final outcome = await runFlow(tester, optIn: true);
    expect(outcome.savedRecord, isNotNull);
    expect(outcome.savedScreeningId, MockData.results.first.id);
    expect(outcome.saveError, isNull);
  });

  testWidgets('failed save retains prediction and reports retry state',
      (tester) async {
    final outcome = await runFlow(tester, optIn: true, fail: true);
    expect(outcome.result, MockData.results.first);
    expect(outcome.savedScreeningId, isNull);
    expect(outcome.saveError, 'Synthetic save failure');
    expect(outcome.idempotencyKey, startsWith('mobile_'));
  });

  testWidgets('unsaved screening does not call persistence', (tester) async {
    final outcome = await runFlow(tester, optIn: false);
    expect(outcome.savedScreeningId, isNull);
    expect(outcome.saveError, isNull);
  });

  testWidgets('account change prevents automatic save', (tester) async {
    final outcome = await runFlow(tester, optIn: true, ownerChanges: true);
    expect(outcome.savedScreeningId, isNull);
    expect(outcome.saveError, contains('account changed'));
  });

  testWidgets('unsaved result can enter Doctor flow without a save tap',
      (tester) async {
    final history = _History();
    final photo = ScreeningPhoto(
      bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC'),
      name: 'synthetic.png',
      fromCamera: false,
      saveToHistory: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: ResultScreen(
        outcome: ScreeningOutcome(result: MockData.results.first, photo: photo),
        historyRepository: history,
      ),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Doctor flow opened')),
      ),
    ));
    await tester.scrollUntilVisible(
        find.text('Send to a verified Doctor'), 200);
    await tester.tap(find.text('Send to a verified Doctor'));
    await tester.pumpAndSettle();
    expect(history.saves, 1);
    expect(find.text('Doctor flow opened'), findsOneWidget);
  });
}
