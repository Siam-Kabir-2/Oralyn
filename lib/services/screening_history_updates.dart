import 'package:flutter/foundation.dart';

/// Notifies mounted screens when this app saves a screening successfully.
class ScreeningHistoryUpdates extends ChangeNotifier {
  ScreeningHistoryUpdates._();

  static final instance = ScreeningHistoryUpdates._();

  void saved() => notifyListeners();
}
