import 'package:flutter/foundation.dart';

import '../models/screening_result.dart';
import '../models/screening_session.dart';
import '../services/screening_api_service.dart';

class ScreeningController extends ChangeNotifier {
  ScreeningController({ScreeningAnalysisService? service})
      : _service = service ?? ScreeningApiService();
  final ScreeningAnalysisService _service;
  ScreeningResult? _result;
  bool _analyzing = false;
  bool _disposed = false;

  ScreeningResult? get result => _result;
  bool get analyzing => _analyzing;

  Future<ScreeningResult> analyze(ScreeningPhoto photo) async {
    if (_disposed) throw StateError('ScreeningController is disposed.');
    _analyzing = true;
    notifyListeners();
    try {
      final completed = await _service.analyze(photo);
      if (!_disposed) _result = completed;
      return completed;
    } finally {
      _analyzing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _service.close();
    super.dispose();
  }
}
