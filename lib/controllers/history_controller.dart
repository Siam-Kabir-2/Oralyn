import '../data/mock/mock_data.dart';
import '../models/screening_result.dart';

class HistoryController {
  List<ScreeningResult> filtered(String filter) {
    if (filter == 'Low concern') {
      return MockData.results
          .where((item) => item.risk == RiskLevel.lowConcern)
          .toList();
    }
    if (filter == 'Review recommended') {
      return MockData.results
          .where((item) => item.risk != RiskLevel.lowConcern)
          .toList();
    }
    return MockData.results;
  }
}
