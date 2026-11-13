import 'dart:async';
import 'dart:convert';

import 'package:clerk_auth/clerk_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps Clerk's client and rotating tokens in platform protected storage.
class ClerkSecurePersistor implements Persistor {
  ClerkSecurePersistor({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'oralyn_clerk_session_v1';
  final FlutterSecureStorage _storage;
  final Map<String, dynamic> _cache = {};
  Future<void> _pending = Future<void>.value();

  @override
  Future<void> initialize() async {
    final saved = await _storage.read(key: _storageKey);
    if (saved == null) return;
    try {
      _cache.addAll(jsonDecode(saved) as Map<String, dynamic>);
    } on FormatException {
      await _storage.delete(key: _storageKey);
    } on TypeError {
      await _storage.delete(key: _storageKey);
    }
  }

  @override
  FutureOr<T?> read<T>(String key) => _cache[key] as T?;

  @override
  Future<void> write<T>(String key, T value) {
    _cache[key] = value;
    return _persist();
  }

  @override
  Future<void> delete(String key) {
    _cache.remove(key);
    return _persist();
  }

  Future<void> _persist() {
    final snapshot = jsonEncode(_cache);
    _pending = _pending.then((_) => _storage.write(
          key: _storageKey,
          value: snapshot,
        ));
    return _pending;
  }

  @override
  void terminate() {}
}
