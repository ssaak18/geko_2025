import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'mocks.dart';
import 'package:geko/services/gemini_service.dart';

void main() {
  test('activities are unique and coordinates distinct', () async {
    // Arrange: create Gemini response with duplicate titles/addresses
    final geminiResponse = '''
Activity: Visit the cozy cafe
Place: Cozy Cafe
Address: 10 Main St, Testtown

Activity: Visit the cozy cafe
Place: Cozy Cafe
Address: 10 Main St, Testtown

Activity: Stroll the neighborhood
Place: Corner Walk
Address: 12 Main St, Testtown
''';

    final geocodeResponses = {
      'Cozy Cafe, 10 Main St, Testtown': {
        'results': [
          {
            'geometry': {
              'location': {'lat': 40.0, 'lng': -75.0}
            }
          }
        ],
        'status': 'OK'
      },
      'Corner Walk, 12 Main St, Testtown': {
        'results': [
          {
            'geometry': {
              'location': {'lat': 40.00005, 'lng': -75.00005}
            }
          }
        ],
        'status': 'OK'
      },
    };

    final client = MockClient((http.Request req) async {
      final url = req.url.toString();
      if (url.contains('generate') || url.contains('models')) {
        return http.Response(jsonEncode({'candidates': [ {'content': geminiResponse} ]}), 200, headers: {
          'content-type': 'application/json'
        });
      }
      if (url.contains('geocode')) {
        final query = req.url.queryParameters['address'] ?? req.url.queryParameters['input'] ?? '';
        final body = geocodeResponses[query] ?? {'results': [], 'status': 'ZERO_RESULTS'};
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });

    final service = GeminiService(httpClient: client, apiKey: 'DUMMY', googleMapsApiKey: 'DUMMY');

    // Act
    final activities = await service.suggestActivities(40.0, -75.0, ['coffee']);

    // Assert: should have 3 activities
    expect(activities.length, 3);
    // Titles should be unique
    final titles = activities.map((a) => a.title.toLowerCase()).toList();
    final uniqueTitles = titles.toSet();
    expect(uniqueTitles.length, titles.length);
    // Coordinates should not be identical
    for (int i = 0; i < activities.length; i++) {
      for (int j = i + 1; j < activities.length; j++) {
        final sameLat = (activities[i].lat - activities[j].lat).abs() < 0.000001;
        final sameLng = (activities[i].lng - activities[j].lng).abs() < 0.000001;
        expect(!(sameLat && sameLng), isTrue, reason: 'Activities $i and $j have overlapping coordinates');
      }
    }
  });
}
