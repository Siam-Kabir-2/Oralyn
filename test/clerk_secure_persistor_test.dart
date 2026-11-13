import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oralyn/services/clerk_secure_persistor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('restores and removes Clerk session data across instances', () async {
    final first = ClerkSecurePersistor();
    await first.initialize();
    await first.write('client_token', 'synthetic-token');
    await first.write('client', {'id': 'client_synthetic'});

    final restored = ClerkSecurePersistor();
    await restored.initialize();
    expect(restored.read<String>('client_token'), 'synthetic-token');
    expect(restored.read<Map<String, dynamic>>('client'),
        {'id': 'client_synthetic'});

    await restored.delete('client_token');
    final afterSignOut = ClerkSecurePersistor();
    await afterSignOut.initialize();
    expect(afterSignOut.read<String>('client_token'), isNull);
  });
}
