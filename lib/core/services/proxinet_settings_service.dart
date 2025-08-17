import 'package:shared_preferences/shared_preferences.dart';

class ProxinetSettingsService {
  static const _kPresenceEnabled = 'proxinet_presence_enabled';
  static const _kPrecisionKm = 'proxinet_precision_km';
  static const _kSmsFallback = 'proxinet_sms_fallback';

  Future<bool> isPresenceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPresenceEnabled) ?? true;
  }

  Future<void> setPresenceEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPresenceEnabled, value);
  }

  Future<double> getPrecisionKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kPrecisionKm) ?? 5.0;
  }

  Future<void> setPrecisionKm(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrecisionKm, value);
  }

  Future<bool> isSmsFallbackEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSmsFallback) ?? false;
  }

  Future<void> setSmsFallbackEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSmsFallback, value);
  }
}
