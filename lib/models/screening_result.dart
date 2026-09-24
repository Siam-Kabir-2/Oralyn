enum LesionCategory { healthy, benign, opmd, oralCancer }

enum RiskLevel { lowConcern, professionalReview, promptSpecialistReview }

class ClassScore {
  const ClassScore({required this.className, required this.score});

  final String className;
  final double score;
}

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
    this.topPredictions = const [],
    this.model,
    this.modelVersion,
    this.verificationModel,
    this.cancerVerificationPerformed = false,
    this.cancerVerificationPrediction,
    this.cancerVerificationScore,
    this.cancerVerificationPredictions = const [],
    this.gradCamAvailable = false,
    this.gradCamLabel,
    this.gradCamImageBase64,
    this.apiDisclaimer,
  });

  final String id;
  final DateTime date;
  final LesionCategory category;
  final RiskLevel risk;
  final double confidence;
  final String status;
  final String summary;
  final String recommendation;
  final List<ClassScore> topPredictions;
  final String? model;
  final String? modelVersion;
  final String? verificationModel;
  final bool cancerVerificationPerformed;
  final String? cancerVerificationPrediction;
  final double? cancerVerificationScore;
  final List<ClassScore> cancerVerificationPredictions;
  final bool gradCamAvailable;
  final String? gradCamLabel;
  final String? gradCamImageBase64;
  final String? apiDisclaimer;

  String get categoryLabel => switch (category) {
        LesionCategory.healthy => 'Healthy pattern',
        LesionCategory.benign => 'Benign oral lesion pattern',
        LesionCategory.opmd => 'OPMD-related pattern',
        LesionCategory.oralCancer => 'Pattern requiring specialist review',
      };
}
