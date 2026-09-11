import 'package:flutter/foundation.dart';

import '../models/doctor.dart';
import '../services/mock_doctor_service.dart';

class DoctorController extends ChangeNotifier {
  DoctorController({MockDoctorService? service})
      : _service = service ?? MockDoctorService();
  final MockDoctorService _service;
  List<Doctor> doctors = const [];
  bool loading = false;

  Future<void> load({String query = '', String filter = 'All'}) async {
    loading = true;
    notifyListeners();
    doctors = await _service.search(query, filter);
    loading = false;
    notifyListeners();
  }
}
