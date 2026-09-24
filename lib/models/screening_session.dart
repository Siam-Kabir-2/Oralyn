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
  });

  final Uint8List bytes;
  final String name;
  final bool fromCamera;
  final bool qualityWarning;
}

class ScreeningOutcome {
  const ScreeningOutcome({required this.result, this.photo});

  final ScreeningResult result;
  final ScreeningPhoto? photo;
}
