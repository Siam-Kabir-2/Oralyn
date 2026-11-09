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
    this.imagePath,
    this.gradCamAssetPath,
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
  final String? imagePath;
  final String? gradCamAssetPath;
  final String? apiDisclaimer;

  String get categoryLabel => switch (category) {
        LesionCategory.healthy => 'Healthy pattern',
        LesionCategory.benign => 'Benign oral lesion pattern',
        LesionCategory.opmd => 'OPMD-related pattern',
        LesionCategory.oralCancer => 'Pattern requiring specialist review',
      };

  factory ScreeningResult.fromStoredJson(Map<String, dynamic> json) {
    final prediction = json['primary_prediction'];
    final score = json['primary_score'];
    final status = json['screening_status'];
    final createdAt = json['created_at'];
    final id = json['id'];
    final models = json['model'];
    final verification = json['cancer_verification'];
    final gradCam = json['gradcam'];
    if (prediction is! String ||
        score is! num ||
        status is! String ||
        createdAt is! String ||
        id is! String ||
        models is! Map<String, dynamic> ||
        verification is! Map<String, dynamic> ||
        gradCam is! Map<String, dynamic>) {
      throw const FormatException('Saved screening fields are invalid.');
    }
    final mapping = _mappingFor(prediction, status);
    final performed = verification['performed'];
    final available = gradCam['available'];
    if (performed is! bool || available is! bool) {
      throw const FormatException('Saved screening metadata is invalid.');
    }
    return ScreeningResult(
      id: id,
      date: DateTime.parse(createdAt).toLocal(),
      category: mapping.$1,
      risk: mapping.$2,
      confidence: score.toDouble().clamp(0, 1),
      status: status,
      summary: mapping.$3,
      recommendation: mapping.$4,
      topPredictions: _scores(json['primary_predictions']),
      model: models['primary'] as String?,
      verificationModel: models['verification'] as String?,
      cancerVerificationPerformed: performed,
      cancerVerificationPrediction: verification['prediction'] as String?,
      cancerVerificationScore: (verification['score'] as num?)?.toDouble(),
      cancerVerificationPredictions: _scores(verification['predictions']),
      gradCamAvailable: available,
      gradCamLabel: gradCam['label'] as String?,
      imagePath: json['image_path'] as String?,
      gradCamAssetPath: gradCam['asset_path'] as String?,
      apiDisclaimer: json['disclaimer'] as String?,
    );
  }

  static List<ClassScore> _scores(dynamic value) {
    if (value == null) return const [];
    if (value is! List) throw const FormatException('Scores are invalid.');
    return List.unmodifiable(value.map((item) {
      if (item is! Map<String, dynamic> ||
          item['class'] is! String ||
          item['score'] is! num) {
        throw const FormatException('Score is invalid.');
      }
      return ClassScore(
        className: item['class'] as String,
        score: (item['score'] as num).toDouble().clamp(0, 1),
      );
    }));
  }

  static (LesionCategory, RiskLevel, String, String) _mappingFor(
    String prediction,
    String status,
  ) {
    final category = switch (prediction) {
      'Normal' => LesionCategory.healthy,
      'Variation_from_Normal' => LesionCategory.benign,
      'OPMD' => LesionCategory.opmd,
      'Oral_Cancer' => LesionCategory.oralCancer,
      _ => throw const FormatException('Unknown prediction class.'),
    };
    final risk = switch (status) {
      'Low Concern' => RiskLevel.lowConcern,
      'Review Recommended' ||
      'Professional Review Recommended' =>
        RiskLevel.professionalReview,
      'Prompt Specialist Review' => RiskLevel.promptSpecialistReview,
      _ => throw const FormatException('Unknown screening status.'),
    };
    final guidance = switch (risk) {
      RiskLevel.lowConcern => (
          'No higher-concern visible pattern was highlighted by this screening.',
          'Continue routine oral care and monitor for persistent changes.',
        ),
      RiskLevel.professionalReview => (
          'The screening found visible features that should be reviewed by a dental professional.',
          'Arrange a professional oral examination, especially if the area persists or changes.',
        ),
      RiskLevel.promptSpecialistReview => (
          'The combined screening signals support timely assessment by an oral health specialist.',
          'Consult an oral medicine or oral and maxillofacial specialist promptly.',
        ),
    };
    return (category, risk, guidance.$1, guidance.$2);
  }
}
