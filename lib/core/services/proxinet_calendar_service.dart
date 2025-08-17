import 'dart:convert';
import 'package:http/http.dart' as http;
import 'proxinet_oauth_service.dart';

class ProxinetCalendarService {
  final ProxinetOauthService _oauth;
  ProxinetCalendarService(this._oauth);

  Future<List<Map<String, dynamic>>> fetchGoogleUpcomingEvents(
      {int hoursAhead = 72}) async {
    final token = await _oauth.getGoogleAccessToken();
    if (token == null) return [];
    final now = DateTime.now().toUtc();
    final timeMin = now.toIso8601String();
    final timeMax = now.add(Duration(hours: hoursAhead)).toIso8601String();
    final uri = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events'
        '?timeMin=$timeMin&timeMax=$timeMax&singleEvents=true&orderBy=startTime');
    final resp =
        await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode != 200) return [];
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];
    return items.cast<Map<String, dynamic>>();
  }
}
