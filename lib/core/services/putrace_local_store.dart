import 'package:shared_preferences/shared_preferences.dart';

class PutraceLocalStore {
  static const _kContactTokens = 'putrace_contact_tokens_v1';
  static const _kPresenceCity = 'putrace_presence_city_v1';
  static const _kPresenceUpdated = 'putrace_presence_updated_v1';

  Future<void> saveTokens(List<String> tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kContactTokens, tokens);
  }

  Future<List<String>> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kContactTokens) ?? const [];
  }

  Future<void> savePresenceCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPresenceCity, city);
    await prefs.setString(
        _kPresenceUpdated, DateTime.now().toUtc().toIso8601String());
  }

  Future<String?> getPresenceCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPresenceCity);
  }

  Future<DateTime?> getPresenceUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kPresenceUpdated);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }
}
