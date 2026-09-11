enum LesionCategory { healthy, benign, opmd, oralCancer }

enum RiskLevel { lowConcern, professionalReview, promptSpecialistReview }

class ScreeningResult {
  const ScreeningResult({
    required this.id,
    required this.date,
    required this.category,
    required this.risk,
    required this.confidence,
    required this.status,
    required this.summary,
    required this.recommendation,
  });

  final String id;
  final DateTime date;
  final LesionCategory category;
  final RiskLevel risk;
  final double confidence;
  final String status;
  final String summary;
  final String recommendation;

  String get categoryLabel => switch (category) {
        LesionCategory.healthy => 'Healthy pattern',
        LesionCategory.benign => 'Benign oral lesion pattern',
        LesionCategory.opmd => 'OPMD-related pattern',
        LesionCategory.oralCancer => 'Pattern requiring specialist review',
      };
}
