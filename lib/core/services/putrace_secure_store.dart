import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class PutraceSecureStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _kSecretSalt = 'putrace_secret_salt';
  static const _kProfessionalIdentity = 'professional_identity';

  Future<String?> getSecretSalt() async {
    return _storage.read(key: _kSecretSalt);
  }

  Future<void> setSecretSalt(String value) async {
    await _storage.write(key: _kSecretSalt, value: value);
  }

  // Enhanced methods for professional encryption
  Future<void> storeValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> getValue(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> deleteValue(String key) async {
    await _storage.delete(key: key);
  }

  // Professional identity storage (encrypted locally)
  Future<void> storeProfessionalIdentity(Map<String, dynamic> identity) async {
    final identityJson = json.encode(identity);
    await _storage.write(key: _kProfessionalIdentity, value: identityJson);
  }

  Future<Map<String, dynamic>?> getProfessionalIdentity() async {
    final identityJson = await _storage.read(key: _kProfessionalIdentity);
    if (identityJson != null) {
      return json.decode(identityJson) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> deleteProfessionalIdentity() async {
    await _storage.delete(key: _kProfessionalIdentity);
  }

  // Clear all stored data (for logout/reset)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Get all keys (for debugging)
  Future<Map<String, String>> getAllValues() async {
    return await _storage.readAll();
  }
}
