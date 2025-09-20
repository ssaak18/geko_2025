import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'mocks.dart';
import 'package:geko/services/gemini_service.dart';

void main() {
  test('uses Gemini verifier when enabled', () async {
  final geminiVerifyJson = '{"lat":41.1,"lng":-74.1,"confidence":0.95,"source":"gemini"}';
  final geminiResponse = geminiVerifyJson; // returned as parts[0].text
    final geminiActivityResponse = '''
Activity: Try the secret spot
Place: Secret Place
Address: 1 Hidden Way, Testtown
''';

    final geocodeResponses = {
      'Secret Place, 1 Hidden Way, Testtown': {
        'results': [
          {
            'geometry': {
              'location': {'lat': 40.0, 'lng': -75.0}
            }
          }
        ],
        'status': 'OK'
      }
    };

    final client = MockClient((http.Request req) async {
      final url = req.url.toString();
      if (url.contains('generate') && req.body.contains('VERIFY_COORDINATES_JSON')) {
        // verifier call
        return http.Response(jsonEncode({'candidates': [ {'content': {'parts': [{'text': geminiResponse}]}} ]}), 200, headers: {'content-type': 'application/json'});
      }
      if (url.contains('generate') || url.contains('models')) {
        // activity generation
        return http.Response(jsonEncode({'candidates': [ {'content': geminiActivityResponse} ]}), 200, headers: {'content-type': 'application/json'});
      }
      if (url.contains('geocode')) {
        final query = req.url.queryParameters['address'] ?? '';
        final body = geocodeResponses[query] ?? {'results': [], 'status': 'ZERO_RESULTS'};
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    final service = GeminiService(httpClient: client, apiKey: 'DUMMY', googleMapsApiKey: 'DUMMY', useGeminiLocationVerifier: true);

    final activities = await service.suggestActivities(40.0, -75.0, ['mystery']);
    expect(activities.length, 3);
    final act = activities.firstWhere((a) => a.title.toLowerCase().contains('secret'));
    // Coordinates should come from verifier (41.1, -74.1)
    expect(act.lat, closeTo(41.1, 0.0001));
    expect(act.lng, closeTo(-74.1, 0.0001));
  });
}
