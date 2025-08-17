import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'proxinet_secure_store.dart';

class ProxinetCryptoService {
  final ProxinetSecureStore _store;
  ProxinetCryptoService(this._store);

  Future<String> getOrCreateSecretSalt() async {
    final existing = await _store.getSecretSalt();
    if (existing != null && existing.isNotEmpty) return existing;
    final salt = _generateSalt();
    await _store.setSecretSalt(salt);
    return salt;
  }

  String hmacToken({required String secretSalt, required String value}) {
    final normalized = value.trim().toLowerCase();
    final key = utf8.encode(secretSalt);
    final bytes = utf8.encode(normalized);
    final digest = Hmac(sha256, key).convert(bytes);
    return digest.toString();
  }

  String _generateSalt({int length = 32}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }
}
