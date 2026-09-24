import 'package:flutter/foundation.dart';

import '../models/screening_result.dart';
import '../models/screening_session.dart';
import '../services/screening_api_service.dart';

class ScreeningController extends ChangeNotifier {
  ScreeningController({ScreeningAnalysisService? service})
      : _service = service ?? ScreeningApiService();
  final ScreeningAnalysisService _service;
  ScreeningResult? result;
  bool analyzing = false;

  Future<ScreeningResult> analyze(ScreeningPhoto photo) async {
    analyzing = true;
    notifyListeners();
    try {
      result = await _service.analyze(photo);
      return result!;
    } finally {
      analyzing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }
}
