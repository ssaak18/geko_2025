import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleCalendarService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
  );

  Future<String?> signInAndGetToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  Future<List<Map<String, DateTime>>> fetchBusyTimes(String accessToken, DateTime start, DateTime end) async {
    final url = Uri.parse('https://www.googleapis.com/calendar/v3/freeBusy');
    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'timeMin': start.toUtc().toIso8601String(),
        'timeMax': end.toUtc().toIso8601String(),
        'items': [{'id': 'primary'}],
      }),
    );

    if (resp.statusCode != 200) throw Exception('FreeBusy fetch failed');

    final data = jsonDecode(resp.body);
    final busySlots = (data['calendars']['primary']['busy'] as List)
        .map((b) => {
              'start': DateTime.parse(b['start']),
              'end': DateTime.parse(b['end']),
            })
        .toList();
    return busySlots;
  }

  List<Map<String, DateTime>> computeFreeTimes(
      List<Map<String, DateTime>> busySlots,
      DateTime dayStart,
      DateTime dayEnd) {
    List<Map<String, DateTime>> freeTimes = [];
    DateTime current = dayStart;

    for (var slot in busySlots) {
      if (slot['start']!.isAfter(current)) {
        freeTimes.add({'start': current, 'end': slot['start']!});
      }
      if (slot['end']!.isAfter(current)) {
        current = slot['end']!;
      }
    }

    if (current.isBefore(dayEnd)) freeTimes.add({'start': current, 'end': dayEnd});
    return freeTimes;
  }
}
