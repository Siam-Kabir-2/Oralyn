import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/controllers/doctor_controller.dart';
import 'package:oralyn/controllers/screening_controller.dart';
import 'package:oralyn/data/mock/mock_data.dart';
import 'package:oralyn/models/doctor.dart';
import 'package:oralyn/models/screening_result.dart';
import 'package:oralyn/models/screening_session.dart';
import 'package:oralyn/services/mock_doctor_service.dart';
import 'package:oralyn/services/screening_api_service.dart';

class _PendingDoctorService extends MockDoctorService {
  final requests = <String, Completer<List<Doctor>>>{};

  @override
  Future<List<Doctor>> search(String query, String specialty) {
    final completer = Completer<List<Doctor>>();
    requests[query] = completer;
    return completer.future;
  }
}

class _PendingScreeningService implements ScreeningAnalysisService {
  final completer = Completer<ScreeningResult>();
  bool closed = false;

  @override
  Future<ScreeningResult> analyze(ScreeningPhoto photo) => completer.future;

  @override
  void close() => closed = true;
}

void main() {
  test('an older doctor search cannot replace the latest search', () async {
    final service = _PendingDoctorService();
    final controller = DoctorController(service: service);
    final first = controller.load(query: 'first');
    final second = controller.load(query: 'second');

    service.requests['second']!.complete([MockData.doctors.last]);
    await second;
    service.requests['first']!.complete([MockData.doctors.first]);
    await first;

    expect(controller.loading, isFalse);
    expect(controller.doctors.single.id, MockData.doctors.last.id);
    controller.dispose();
  });

  test('doctor search completing after disposal is ignored', () async {
    final service = _PendingDoctorService();
    final controller = DoctorController(service: service);
    final pending = controller.load(query: 'pending');
    controller.dispose();

    service.requests['pending']!.complete([MockData.doctors.first]);
    await pending;
    expect(controller.doctors, isEmpty);
  });

  test('screening completion after disposal does not update UI state',
      () async {
    final service = _PendingScreeningService();
    final controller = ScreeningController(service: service);
    final photo = ScreeningPhoto(
      bytes: Uint8List.fromList([1]),
      name: 'test.jpg',
      fromCamera: false,
    );
    final pending = controller.analyze(photo);
    controller.dispose();

    service.completer.complete(MockData.results.first);
    expect(await pending, same(MockData.results.first));
    expect(controller.result, isNull);
    expect(controller.analyzing, isFalse);
    expect(service.closed, isTrue);
  });
}
