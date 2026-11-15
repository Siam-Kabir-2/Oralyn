import 'dart:typed_data';

import 'screening_result.dart';

/// The photo selected for a single screening session.
///
/// Bytes are kept in memory for the current flow and uploaded only when the
/// user starts an API-backed screening.
class ScreeningPhoto {
  const ScreeningPhoto({
    required this.bytes,
    required this.name,
    required this.fromCamera,
    this.qualityWarning = false,
    this.saveToHistory = false,
  });

  final Uint8List bytes;
  final String name;
  final bool fromCamera;
  final bool qualityWarning;
  final bool saveToHistory;
}

class ScreeningOutcome {
  const ScreeningOutcome({
    required this.result,
    this.photo,
    this.savedScreeningId,
    this.savedRecord,
    this.saveError,
    this.idempotencyKey,
    this.ownerId,
  });

  final ScreeningResult result;
  final ScreeningPhoto? photo;
  final String? savedScreeningId;
  final ScreeningResult? savedRecord;
  final String? saveError;
  final String? idempotencyKey;
  final String? ownerId;
}
