import '../data/mock/mock_data.dart';
import '../models/doctor.dart';

class MockDoctorService {
  Future<List<Doctor>> search(String query, String specialty) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return MockData.doctors.where((doctor) {
      final text =
          '${doctor.name} ${doctor.specialty} ${doctor.facility}'.toLowerCase();
      final matchesQuery = text.contains(query.trim().toLowerCase());
      final matchesFilter = specialty == 'All' ||
          doctor.specialty.toLowerCase().contains(specialty.toLowerCase()) ||
          (specialty == 'Hospital' &&
              doctor.facility.toLowerCase().contains('hospital'));
      return matchesQuery && matchesFilter;
    }).toList();
  }
}
