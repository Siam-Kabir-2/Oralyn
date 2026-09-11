class MockLocationService {
  Future<String> currentArea() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return 'Dhanmondi, Dhaka';
  }
}
