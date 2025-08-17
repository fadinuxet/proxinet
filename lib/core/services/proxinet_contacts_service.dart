import 'dart:convert';
import 'package:http/http.dart' as http;
import 'proxinet_oauth_service.dart';
import 'proxinet_crypto_service.dart';

class ProxinetContactsService {
  final ProxinetOauthService _oauth;
  final ProxinetCryptoService _crypto;
  ProxinetContactsService(this._oauth, this._crypto);

  Future<List<Map<String, String>>> fetchGoogleContacts() async {
    final token = await _oauth.getGoogleAccessToken();
    if (token == null) return [];
    final uri = Uri.parse(
        'https://people.googleapis.com/v1/people/me/connections?personFields=names,emailAddresses,phoneNumbers&pageSize=2000');
    final resp =
        await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode != 200) return [];
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final List<dynamic> connections = data['connections'] ?? [];
    return connections
        .map((c) {
          final names = (c['names'] as List?) ?? [];
          final emails = (c['emailAddresses'] as List?) ?? [];
          final phones = (c['phoneNumbers'] as List?) ?? [];
          final name = names.isNotEmpty
              ? (names.first['displayName'] as String? ?? '')
              : '';
          final email =
              emails.isNotEmpty ? (emails.first['value'] as String? ?? '') : '';
          final phone =
              phones.isNotEmpty ? (phones.first['value'] as String? ?? '') : '';
          return {'name': name, 'email': email, 'phone': phone};
        })
        .toList()
        .cast<Map<String, String>>();
  }

  Future<List<String>> tokenizeContacts(
      List<Map<String, String>> contacts) async {
    final salt = await _crypto.getOrCreateSecretSalt();
    final tokens = <String>[];
    for (final c in contacts) {
      final email = c['email'];
      final phone = c['phone'];
      if (email != null && email.isNotEmpty) {
        tokens.add(_crypto.hmacToken(secretSalt: salt, value: email));
      }
      if (phone != null && phone.isNotEmpty) {
        tokens.add(_crypto.hmacToken(secretSalt: salt, value: phone));
      }
    }
    return tokens;
  }

  Future<List<Map<String, String>>> fetchMicrosoftContacts() async {
    // TODO: Implement with Graph OAuth
    return [];
  }
}
// Removed old stub duplicate class
