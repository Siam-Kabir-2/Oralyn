import '../data/mock/mock_data.dart';
import '../models/screening_result.dart';

class MockAiService {
  Future<ScreeningResult> analyze() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    return MockData.results[MockData.activeScenarioIndex];
  }
}
