import 'package:flutter/foundation.dart';

import '../models/doctor.dart';
import '../services/mock_doctor_service.dart';

class DoctorController extends ChangeNotifier {
  DoctorController({MockDoctorService? service})
      : _service = service ?? MockDoctorService();
  final MockDoctorService _service;
  List<Doctor> _doctors = const [];
  bool _loading = false;
  String? _errorMessage;
  int _generation = 0;
  bool _disposed = false;

  List<Doctor> get doctors => _doctors;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  Future<void> load({String query = '', String filter = 'All'}) async {
    if (_disposed) return;
    final generation = ++_generation;
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final found = await _service.search(query, filter);
      if (_disposed || generation != _generation) return;
      _doctors = List<Doctor>.unmodifiable(found);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _errorMessage = 'The care directory could not be loaded.';
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
