import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:geko/services/gemini_service.dart';
import 'mocks.dart';

void main() {
  test('suggestActivities parses 3 activities and geocodes them', () async {
    // Arrange: mock Gemini LLM response with exactly 3 blocks
    final geminiResponse = '''
Activity: Try the hidden noodle shop
Place: Little Dragon Noodles
Address: 123 Back Alley, Testtown

Activity: Explore the pocket park
Place: Willow Pocket Park
Address: 5 Oak Lane, Testtown

Activity: Visit a local thrift
Place: Thrift & Co
Address: 77 Market Row, Testtown
''';

    // Mock Google Geocoding responses: return slightly different coordinates for each address
    final geocodeResponses = {
      'Little Dragon Noodles, 123 Back Alley, Testtown': {
        'results': [
          {
            'geometry': {
              'location': {'lat': 37.01, 'lng': -122.0}
            }
          }
        ],
        'status': 'OK'
      },
      'Willow Pocket Park, 5 Oak Lane, Testtown': {
        'results': [
          {
            'geometry': {
              'location': {'lat': 37.0105, 'lng': -122.0005}
            }
          }
        ],
        'status': 'OK'
      },
      'Thrift & Co, 77 Market Row, Testtown': {
        'results': [
          {
            'geometry': {
              'location': {'lat': 36.9995, 'lng': -121.9995}
            }
          }
        ],
        'status': 'OK'
      },
    };

    final client = MockClient((http.Request req) async {
      final url = req.url.toString();
      if (url.contains('generate') || url.contains('models')) {
        // Gemini-like response
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

  final service = GeminiService(httpClient: client, apiKey: 'DUMMY_KEY', googleMapsApiKey: 'DUMMY_GOOGLE');

    // Act
    final activities = await service.suggestActivities(37.0, -122.0, ['food']);

  // Assert: 3 activities and each expected type exists (order-independent)
  expect(activities.length, 3);
  final noodle = activities.firstWhere((a) => a.title.toLowerCase().contains('noodle'), orElse: () => throw 'noodle missing');
  final park = activities.firstWhere((a) => a.title.toLowerCase().contains('park'), orElse: () => throw 'park missing');
  final thrift = activities.firstWhere((a) => a.title.toLowerCase().contains('thrift'), orElse: () => throw 'thrift missing');
  // Coordinates close to mocked values
  expect(noodle.lat, closeTo(37.01, 0.0001));
  expect(park.lat, closeTo(37.0105, 0.0001));
  expect(thrift.lat, closeTo(36.9995, 0.0001));
  });
}
