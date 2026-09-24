import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/config/api_config.dart';
import '../models/screening_result.dart';
import '../models/screening_session.dart';
import 'api_settings_service.dart';

enum PredictionErrorKind {
  configuration,
  unauthorized,
  invalidImage,
  payloadTooLarge,
  rateLimited,
  timeout,
  network,
  server,
  invalidResponse,
}

class PredictionException implements Exception {
  const PredictionException(this.kind, this.userMessage);

  final PredictionErrorKind kind;
  final String userMessage;

  @override
  String toString() => userMessage;
}

abstract interface class ScreeningAnalysisService {
  Future<ScreeningResult> analyze(ScreeningPhoto photo);

  void close();
}

class ScreeningApiService implements ScreeningAnalysisService {
  ScreeningApiService({
    http.Client? client,
    Uri? endpoint,
    String? apiKey,
    ApiSettingsService? settingsService,
    this.timeout = const Duration(seconds: 45),
  })  : _client = client ?? http.Client(),
        _endpointOverride = endpoint,
        _settingsService = settingsService ?? ApiSettingsService(),
        _apiKey = apiKey ?? ApiConfig.apiKey;

  static const maxUploadBytes = 10 * 1024 * 1024;

  final http.Client _client;
  final Uri? _endpointOverride;
  final ApiSettingsService _settingsService;
  final String _apiKey;
  final Duration timeout;

  @override
  Future<ScreeningResult> analyze(ScreeningPhoto photo) async {
    if (_apiKey.trim().isEmpty) {
      throw const PredictionException(
        PredictionErrorKind.configuration,
        'The screening service API key is not configured.',
      );
    }
    if (photo.bytes.isEmpty) {
      throw const PredictionException(
        PredictionErrorKind.invalidImage,
        'The selected image is empty. Please choose another photo.',
      );
    }
    if (photo.bytes.lengthInBytes > maxUploadBytes) {
      throw const PredictionException(
        PredictionErrorKind.payloadTooLarge,
        'This image is larger than 10 MB. Please choose or capture a smaller '
        'image.',
      );
    }

    final endpoint =
        _endpointOverride ?? await _settingsService.getPredictionUri();
    final imageMediaType = _imageMediaType(photo);
    final request = http.MultipartRequest('POST', endpoint)
      ..headers['x-api-key'] = _apiKey
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          photo.bytes,
          filename: _uploadFileName(photo.name),
          contentType: imageMediaType,
        ),
      );

    try {
      final streamedResponse = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) {
        throw _exceptionForStatus(response.statusCode);
      }
      return _parseResponse(response.body);
    } on TimeoutException {
      throw const PredictionException(
        PredictionErrorKind.timeout,
        'The screening service took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const PredictionException(
        PredictionErrorKind.network,
        'Unable to reach the screening service. Check your internet connection '
        'and try again.',
      );
    } on PredictionException {
      rethrow;
    } on FormatException {
      throw const PredictionException(
        PredictionErrorKind.invalidResponse,
        'The screening service returned an unreadable response. Please try '
        'again later.',
      );
    } catch (_) {
      throw const PredictionException(
        PredictionErrorKind.network,
        'Unable to reach the screening service. Check your connection and try '
        'again.',
      );
    }
  }

  ScreeningResult _parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }

    final prediction = decoded['primary_prediction'];
    final score = decoded['primary_score'];
    final screeningStatus = decoded['screening_status'];
    final models = decoded['model'];
    final disclaimer = decoded['disclaimer'];
    if (prediction is! String ||
        prediction.isEmpty ||
        score is! num ||
        screeningStatus is! String ||
        screeningStatus.isEmpty ||
        models is! Map<String, dynamic> ||
        models['primary'] is! String ||
        (models['primary'] as String).isEmpty ||
        models['verification'] is! String ||
        (models['verification'] as String).isEmpty ||
        disclaimer is! String ||
        disclaimer.isEmpty) {
      throw const FormatException('Required prediction fields are missing.');
    }

    final mapped = _mappingFor(prediction, screeningStatus);
    final topPredictions = _parsePredictions(decoded['primary_predictions']);

    final rawVerification = decoded['cancer_verification'];
    if (rawVerification is! Map<String, dynamic> ||
        rawVerification['performed'] is! bool) {
      throw const FormatException('Cancer verification result is missing.');
    }

    final verificationPerformed = rawVerification['performed'] as bool;
    String? verificationPrediction;
    double? verificationScore;
    var verificationPredictions = const <ClassScore>[];
    if (verificationPerformed) {
      final rawPrediction = rawVerification['prediction'];
      final rawScore = rawVerification['score'];
      if (rawPrediction is! String ||
          rawPrediction.isEmpty ||
          rawScore is! num) {
        throw const FormatException('Cancer verification result is invalid.');
      }
      verificationPrediction = rawPrediction;
      verificationScore = _normalizedScore(rawScore);
      verificationPredictions = List.unmodifiable(
        _parsePredictions(rawVerification['predictions']),
      );
    }

    var gradCamAvailable = false;
    String? gradCamLabel;
    String? gradCamImageBase64;
    final rawGradCam = decoded['gradcam'];
    if (rawGradCam is Map<String, dynamic>) {
      final available = rawGradCam['available'];
      if (available is! bool) {
        throw const FormatException('Grad-CAM availability is invalid.');
      }
      gradCamAvailable = available;
      if (gradCamAvailable) {
        final label = rawGradCam['label'];
        final imageBase64 = rawGradCam['image_base64'];
        if (label is! String ||
            label.isEmpty ||
            imageBase64 is! String ||
            !imageBase64.startsWith('data:image/')) {
          throw const FormatException('Grad-CAM image is invalid.');
        }
        gradCamLabel = label;
        gradCamImageBase64 = imageBase64;
      }
    }

    return ScreeningResult(
      id: 'S-${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      category: mapped.category,
      risk: mapped.risk,
      confidence: _normalizedScore(score),
      status: mapped.status,
      summary: mapped.summary,
      recommendation: mapped.recommendation,
      topPredictions: List.unmodifiable(topPredictions),
      model: models['primary'] as String,
      verificationModel: models['verification'] as String,
      cancerVerificationPerformed: verificationPerformed,
      cancerVerificationPrediction: verificationPrediction,
      cancerVerificationScore: verificationScore,
      cancerVerificationPredictions: verificationPredictions,
      gradCamAvailable: gradCamAvailable,
      gradCamLabel: gradCamLabel,
      gradCamImageBase64: gradCamImageBase64,
      apiDisclaimer: disclaimer,
    );
  }

  List<ClassScore> _parsePredictions(dynamic rawPredictions) {
    if (rawPredictions is! List) {
      throw const FormatException('Model score breakdown is missing.');
    }

    return rawPredictions.map((item) {
      if (item is! Map<String, dynamic> ||
          item['class'] is! String ||
          item['score'] is! num) {
        throw const FormatException('Model score breakdown is invalid.');
      }
      return ClassScore(
        className: item['class'] as String,
        score: _normalizedScore(item['score'] as num),
      );
    }).toList(growable: false);
  }

  _PredictionMapping _mappingFor(String rawClass, String screeningStatus) {
    final category = switch (rawClass.trim().toLowerCase()) {
      'normal' => LesionCategory.healthy,
      'variation_from_normal' => LesionCategory.benign,
      'opmd' => LesionCategory.opmd,
      'oral_cancer' => LesionCategory.oralCancer,
      _ => throw const FormatException('Unknown prediction class.'),
    };

    final risk = switch (screeningStatus) {
      'Low Concern' => RiskLevel.lowConcern,
      'Review Recommended' ||
      'Professional Review Recommended' =>
        RiskLevel.professionalReview,
      'Prompt Specialist Review' => RiskLevel.promptSpecialistReview,
      _ => throw const FormatException('Unknown screening status.'),
    };

    final (summary, recommendation) = switch (risk) {
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

    return _PredictionMapping(
      category: category,
      risk: risk,
      status: screeningStatus,
      summary: summary,
      recommendation: recommendation,
    );
  }

  PredictionException _exceptionForStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return const PredictionException(
        PredictionErrorKind.unauthorized,
        'The screening service rejected the API key. Check the app '
        'configuration and try again.',
      );
    }
    if (statusCode == 413) {
      return const PredictionException(
        PredictionErrorKind.payloadTooLarge,
        'This image is too large for the screening service. Please choose a '
        'smaller image.',
      );
    }
    if (statusCode == 400 || statusCode == 415 || statusCode == 422) {
      return const PredictionException(
        PredictionErrorKind.invalidImage,
        'The screening service could not read this image. Please use a valid '
        'JPG, JPEG, PNG, WEBP, or BMP photo.',
      );
    }
    if (statusCode == 429) {
      return const PredictionException(
        PredictionErrorKind.rateLimited,
        'The screening service is receiving too many requests. Please wait a '
        'moment and try again.',
      );
    }
    return const PredictionException(
      PredictionErrorKind.server,
      'The screening service is temporarily unavailable. Please try again '
      'later.',
    );
  }

  double _normalizedScore(num value) => value.toDouble().clamp(0.0, 1.0);

  String _uploadFileName(String originalName) {
    final trimmed = originalName.trim();
    if (trimmed.isEmpty) return 'oral-screening.jpg';
    return trimmed.split(RegExp(r'[/\\]')).last;
  }

  MediaType _imageMediaType(ScreeningPhoto photo) {
    final lowerName = photo.name.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lowerName.endsWith('.png')) return MediaType('image', 'png');
    if (lowerName.endsWith('.webp')) return MediaType('image', 'webp');
    if (lowerName.endsWith('.bmp')) return MediaType('image', 'bmp');

    final bytes = photo.bytes;
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return MediaType('image', 'jpeg');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return MediaType('image', 'png');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return MediaType('image', 'webp');
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return MediaType('image', 'bmp');
    }

    throw const PredictionException(
      PredictionErrorKind.invalidImage,
      'Unsupported image format. Please use JPG, JPEG, PNG, WEBP, or BMP.',
    );
  }

  @override
  void close() => _client.close();
}

class _PredictionMapping {
  const _PredictionMapping({
    required this.category,
    required this.risk,
    required this.status,
    required this.summary,
    required this.recommendation,
  });

  final LesionCategory category;
  final RiskLevel risk;
  final String status;
  final String summary;
  final String recommendation;
}
