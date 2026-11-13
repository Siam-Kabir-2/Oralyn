import 'package:flutter/foundation.dart';

import '../models/screening_result.dart';
import '../services/screening_history_service.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this.repository);

  final ScreeningHistoryRepository repository;
  List<ScreeningResult> _results = const [];
  bool loading = false;
  String? error;

  List<ScreeningResult> filtered(String filter) {
    if (filter == 'Low concern') {
      return _results
          .where((item) => item.risk == RiskLevel.lowConcern)
          .toList(growable: false);
    }
    if (filter == 'Review recommended') {
      return _results
          .where((item) => item.risk != RiskLevel.lowConcern)
          .toList(growable: false);
    }
    return _results;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _results = await repository.list();
    } on ScreeningHistoryException catch (exception) {
      error = exception.message;
    } on FormatException {
      error = 'Saved screening data could not be read.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
