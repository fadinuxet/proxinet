import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProxinetSecureStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _kSecretSalt = 'proxinet_secret_salt';

  Future<String?> getSecretSalt() async {
    return _storage.read(key: _kSecretSalt);
  }

  Future<void> setSecretSalt(String value) async {
    await _storage.write(key: _kSecretSalt, value: value);
  }
}
