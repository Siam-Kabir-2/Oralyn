import 'package:flutter/foundation.dart';

import '../models/screening_result.dart';
import '../services/mock_ai_service.dart';

class ScreeningController extends ChangeNotifier {
  ScreeningController({MockAiService? service})
      : _service = service ?? MockAiService();
  final MockAiService _service;
  ScreeningResult? result;
  bool analyzing = false;

  Future<ScreeningResult> analyze() async {
    analyzing = true;
    notifyListeners();
    result = await _service.analyze();
    analyzing = false;
    notifyListeners();
    return result!;
  }
}
