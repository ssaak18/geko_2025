import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/goal.dart';
import '../models/activity.dart';

class GeminiService {
  final http.Client httpClient;
  final String apiKey;
  final String googleMapsApiKey;
  final bool useGeminiLocationVerifier;
  final double verificationConfidenceThreshold;

  GeminiService({
    http.Client? httpClient,
    String? apiKey,
    String? googleMapsApiKey,
    bool? useGeminiLocationVerifier,
    double? verificationConfidenceThreshold,
  })  : httpClient = httpClient ?? http.Client(),
    apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
    googleMapsApiKey = googleMapsApiKey ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
    useGeminiLocationVerifier = useGeminiLocationVerifier ?? false,
    verificationConfidenceThreshold = verificationConfidenceThreshold ?? 0.5;

  Future<List<Goal>> generateGoals(String userInput) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey",
      );

      final response = await httpClient.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                      "You are the very best life coach in the world," +
                      "and the user needs advice on how to summarize all of their" +
                      "plans into concrete life goals. Based on these user goals: '$userInput'," +
                      "generate exactly 5 specific, actionable life goals that " +
                      "encapsulate everything in the user goals. The goals should" +
                      "only be active/positive actions; do not say something like" +
                      "practice moderation. They should not be too specific but be" +
                      "categories that allow for the person's travel agency to then" +
                      "suggest activites related to them to help the user live a better" +
                      "life. Make the list of goals the most helpful for the travel agency" +
                      "planner. Format each goal as a simple sentence on a new line. Do not" +
                      "include numbers, bullets, or extra formatting. ",
                },
              ],
            },
          ],
        }),
      );

      print("API Response Status: ${response.statusCode}");
      print("API Response Body: ${response.body}");

      if (response.statusCode != 200) {
        print("API Error: ${response.statusCode}");
        return _getFallbackGoals();
      }

      final data = jsonDecode(response.body);

      // Check if the response has the expected structure
      if (data == null ||
          data["candidates"] == null ||
          data["candidates"].isEmpty ||
          data["candidates"][0]["content"] == null ||
          data["candidates"][0]["content"]["parts"] == null ||
          data["candidates"][0]["content"]["parts"].isEmpty) {
        print("Invalid API response structure");
        return _getFallbackGoals();
      }

      final text =
          data["candidates"][0]["content"]["parts"][0]["text"] as String;
    final goalLines = text
      .split("\n")
      .where((g) => g.trim().isNotEmpty)
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .take(3)
      .toList();

      if (goalLines.isEmpty) {
        return _getFallbackGoals();
      }

      return goalLines
          .map(
            (g) => Goal(
              id: g.hashCode.toString(),
              title: g.replaceAll(
                RegExp(r'^[0-9]+\.?\s*'),
                '',
              ), // Remove any numbers at the start
            ),
          )
          .toList();
    } catch (e) {
      print("Error generating goals: $e");
      return _getFallbackGoals();
    }
  }

  List<Goal> _getFallbackGoals() {
    return [
      Goal(id: "1", title: "Learn a new skill this year"),
      Goal(id: "2", title: "Exercise regularly and stay healthy"),
      Goal(
        id: "3",
        title: "Build stronger relationships with family and friends",
      ),
      Goal(id: "4", title: "Advance in my career or education"),
      Goal(id: "5", title: "Practice mindfulness and personal growth"),
    ];
  }

  Future<List<Activity>> suggestActivities(double lat, double lng, List<String> genres) async {
    // Build a prompt for Gemini to generate 3 local activities tailored to genres
  final prompt = """
You are a local guide. Recommend exactly 3 specific, immediate activities someone can do right now near these coordinates: ($lat, $lng).

Constraints:
- Activities must be local and non-touristy (avoid chains and major tourist sites).
- Each activity must be doable within 1-2 hours from now.
- Tailor each activity to the user's stated interests/genres: ${genres.join(', ')}.
- Provide precise places and addresses.

Output EXACTLY 3 blocks, each formatted this way (no extra text):
Activity: <short, enticing description>
Place: <place name>
Address: <street address>, <city>, <state>, <country>

Separate blocks with a single blank line.
""";

    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey");
    final response = await httpClient.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      print("Gemini API Error: ${response.statusCode}");
      return [];
    }

    final data = jsonDecode(response.body);
    String text = "";
    try {
      if (data is Map && data['candidates'] != null && data['candidates'] is List && data['candidates'].isNotEmpty) {
        final cand = data['candidates'][0];
        if (cand is Map) {
          final content = cand['content'];
          if (content is String) {
            text = content;
          } else if (content is Map && content['parts'] is List && content['parts'].isNotEmpty) {
            final part0 = content['parts'][0];
            if (part0 is Map && part0['text'] is String) text = part0['text'];
          }
        } else if (cand is String) {
          text = cand;
        }
      } else if (data is Map && data['text'] is String) {
        text = data['text'];
      }
    } catch (e) {
      text = '';
    }
    final activityBlocks = text.trim().split('\n\n');
    List<Activity> activities = [];
    List<Activity> fallbackActivities = [];
    Map<String, Map<String, double>> geoCache = {};
    Map<String, Map<String, dynamic>> verificationMeta = {};
    // Badge category mapping
    Map<String, String> typeToCategory = {
      'cafe': 'Cafe Explorer',
      'park': 'Park Adventurer',
      'museum': 'Museum Enthusiast',
      'restaurant': 'Restaurant Critic',
      'trail': 'Trailblazer',
      'library': 'Library Scholar',
      'beach': 'Beachcomber',
      'fitness': 'Fitness Fanatic',
      'gym': 'Fitness Fanatic',
      'art': 'Art Lover',
      'historic': 'Historic Site Seeker',
      'site': 'Historic Site Seeker',
      'hiking': 'Hiking Hero',
      'bike': 'Biking Buff',
      'biking': 'Biking Buff',
      'run': 'Running Rookie',
      'running': 'Running Rookie',
      'climb': 'Climbing Champ',
      'climbing': 'Climbing Champ',
      'swim': 'Swimming Star',
      'swimming': 'Swimming Star',
      'shop': 'Shopping Specialist',
      'shopping': 'Shopping Specialist',
      'cinema': 'Cinema Fan',
      'movie': 'Cinema Fan',
      'zoo': 'Zoo Visitor',
      'playground': 'Playground Pro',
      'child': 'Playground Pro',
    };
  // Only generate 3 activities
  for (int i = 0; i < 3 && i < activityBlocks.length; i++) {
      final lines = activityBlocks[i].split('\n');
      String title = '';
      String address = '';
      String place = '';
      String city = '';
      String state = '';
      String country = '';
      String activityType = '';
      for (final line in lines) {
        if (line.startsWith('Activity:')) {
          activityType = line.replaceFirst('Activity:', '').trim().toLowerCase();
          title = line.replaceFirst('Activity:', '').trim();
        } else if (line.startsWith('Place:')) {
          place = line.replaceFirst('Place:', '').trim();
          title += ' at ' + place;
        } else if (line.startsWith('Address:')) {
          address = line.replaceFirst('Address:', '').trim();
          title += ' (' + address + ')';
          // Try to extract city/state/country from address
          final parts = address.split(',');
          if (parts.length >= 4) {
            city = parts[1].trim();
            state = parts[2].trim();
            country = parts[3].trim();
          }
        }
      }
      // Determine category
      String category = typeToCategory.entries.firstWhere(
        (e) => activityType.contains(e.key),
        orElse: () => MapEntry('other', 'Other'),
      ).value;
      // Build a robust query for Nominatim
      String geoQuery = '';
      if (place.isNotEmpty) geoQuery += place + ', ';
      geoQuery += address;
      if (city.isNotEmpty) geoQuery += ', ' + city;
      if (state.isNotEmpty) geoQuery += ', ' + state;
      if (country.isNotEmpty) geoQuery += ', ' + country;
      double markerLat = lat;
      double markerLng = lng;
      bool geocoded = false;
      // Use cache if available
      if (geoCache.containsKey(geoQuery)) {
        markerLat = geoCache[geoQuery]!['lat']!;
        markerLng = geoCache[geoQuery]!['lng']!;
        geocoded = true;
      } else if (geoQuery.isNotEmpty) {
        if (useGeminiLocationVerifier) {
          // Try verifying the address via Gemini Location Verifier
          try {
            final verified = await _verifyLocationWithGemini(geoQuery, lat, lng);
            if (verified != null) {
              final conf = (verified['confidence'] is num) ? (verified['confidence'] as num).toDouble() : double.tryParse(verified['confidence']?.toString() ?? '') ?? 0.0;
              if (conf >= verificationConfidenceThreshold) {
                markerLat = verified['lat'] as double;
                markerLng = verified['lng'] as double;
                geocoded = true;
                geoCache[geoQuery] = {'lat': markerLat, 'lng': markerLng};
                verificationMeta[geoQuery] = {'confidence': conf, 'source': verified['source'] ?? 'gemini'};
              }
            }
          } catch (e) {
            // Fall back to Google Geocoding below
          }
        }
        if (!geocoded) {
          // Google Maps Geocoding API
          final geoUrl = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(geoQuery)}&key=$googleMapsApiKey');
          final geoResp = await httpClient.get(geoUrl);
          if (geoResp.statusCode == 200) {
            final geoData = jsonDecode(geoResp.body);
            if (geoData['results'] != null && geoData['results'].isNotEmpty) {
              // Select the result closest to the user's location
              double minDist = double.infinity;
              Map<String, dynamic>? best;
              for (var result in geoData['results']) {
                final loc = result['geometry']?['location'];
                double? resLat = loc != null ? loc['lat']?.toDouble() : null;
                double? resLng = loc != null ? loc['lng']?.toDouble() : null;
                if (resLat != null && resLng != null) {
                  double dist = ((lat - resLat) * (lat - resLat)) + ((lng - resLng) * (lng - resLng));
                  if (dist < minDist) {
                    minDist = dist;
                    best = result;
                  }
                }
              }
              if (best != null) {
                final loc = best['geometry']['location'];
                markerLat = loc['lat']?.toDouble() ?? lat;
                markerLng = loc['lng']?.toDouble() ?? lng;
                geocoded = true;
                geoCache[geoQuery] = {'lat': markerLat, 'lng': markerLng};
              }
            }
          }
        }
      }
      if (geocoded && (markerLat != lat || markerLng != lng)) {
        final meta = verificationMeta[geoQuery];
        activities.add(Activity(
          id: "${DateTime.now().millisecondsSinceEpoch}_${i}",
          title: title,
          lat: markerLat,
          lng: markerLng,
          goalId: '',
          category: category,
          verified: meta != null,
          verificationConfidence: meta != null ? (meta['confidence'] as double) : 0.0,
          verificationSource: meta != null ? (meta['source']?.toString() ?? '') : '',
        ));
      } else {
        // Randomize fallback location to avoid overlap
        final offsetLat = lat + 0.01 * (i + 1) * (i.isEven ? 1 : -1);
        final offsetLng = lng + 0.01 * (i + 1) * (i.isOdd ? 1 : -1);
        fallbackActivities.add(Activity(
          id: "fallback_${DateTime.now().millisecondsSinceEpoch}_$i",
          title: title + " (location not verified)",
          lat: offsetLat,
          lng: offsetLng,
          goalId: '',
          category: category,
          verified: false,
          verificationConfidence: 0.0,
          verificationSource: '',
        ));
      }
    }
    // Always return 3 activities: prefer geocoded, fill with fallback if needed
    List<Activity> result = [];
    // Add up to 3 geocoded activities, enforcing unique titles
    final seenTitles = <String>{};
    for (var act in activities) {
      final t = act.title.toLowerCase();
      if (result.length >= 3) break;
      if (seenTitles.contains(t)) continue;
      seenTitles.add(t);
      result.add(act);
    }
    // Fill with fallback activities if needed (also enforce unique titles)
    for (var act in fallbackActivities) {
      if (result.length >= 3) break;
      final t = act.title.toLowerCase();
      if (seenTitles.contains(t)) continue;
      seenTitles.add(t);
      result.add(act);
    }
    // If still less than 3, fill with generic randomized fallback
    for (int i = result.length; i < 3; i++) {
      final offsetLat = lat + 0.02 * (i + 1) * (i.isEven ? 1 : -1);
      final offsetLng = lng + 0.02 * (i + 1) * (i.isOdd ? 1 : -1);
      final title = "Explore a local spot (location not verified) ${i}";
      if (seenTitles.contains(title.toLowerCase())) continue;
      seenTitles.add(title.toLowerCase());
      result.add(Activity(
        id: "generic_fallback_${DateTime.now().millisecondsSinceEpoch}_$i",
        title: title,
        lat: offsetLat,
        lng: offsetLng,
        goalId: '',
        category: 'Other',
      ));
    }
    // Ensure all returned activities have distinct coordinates (nudge duplicates)
    const minSeparation = 0.0001; // ~11m
    for (int i = 0; i < result.length; i++) {
      for (int j = i + 1; j < result.length; j++) {
        if ((result[i].lat - result[j].lat).abs() < minSeparation && (result[i].lng - result[j].lng).abs() < minSeparation) {
          // Nudge the later one slightly
          result[j] = result[j].copyWith(
            lat: result[j].lat + minSeparation * (j + 1),
            lng: result[j].lng + minSeparation * (j + 1),
          );
        }
      }
    }
    return result;
  }

  // Call Gemini to verify an address and return {'lat': double, 'lng': double}
  Future<Map<String, dynamic>?> _verifyLocationWithGemini(String address, double userLat, double userLng) async {
    final verifyPrompt = '''VERIFY_COORDINATES_JSON
You are a location verification assistant. Given the address below and the user's approximate coordinates ($userLat, $userLng), return a JSON object ONLY with keys: lat, lng, confidence, source.
Address: $address

Return example: {"lat":37.12345, "lng":-122.12345, "confidence":0.9, "source":"gemini"}
If you cannot verify, return {"lat":null, "lng":null, "confidence":0.0, "source":"gemini"}.
''';

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');
    final resp = await httpClient.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': verifyPrompt}
          ]
        }
      ]
    }));
    if (resp.statusCode != 200) return null;
    try {
      final data = jsonDecode(resp.body);
      String txt = '';
      if (data is Map && data['candidates'] != null && data['candidates'] is List && data['candidates'].isNotEmpty) {
        final cand = data['candidates'][0];
        if (cand is Map && cand['content'] is Map && cand['content']['parts'] is List && cand['content']['parts'].isNotEmpty) {
          final part0 = cand['content']['parts'][0];
          if (part0 is Map && part0['text'] is String) txt = part0['text'];
        } else if (cand is String) {
          txt = cand;
        }
      }
      // Extract JSON substring from txt
      final jsonStart = txt.indexOf('{');
      final jsonEnd = txt.lastIndexOf('}');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = txt.substring(jsonStart, jsonEnd + 1);
        final parsed = jsonDecode(jsonStr);
        if (parsed is Map && parsed['lat'] != null && parsed['lng'] != null) {
          final lat = parsed['lat'] is num ? (parsed['lat'] as num).toDouble() : double.tryParse(parsed['lat'].toString());
          final lng = parsed['lng'] is num ? (parsed['lng'] as num).toDouble() : double.tryParse(parsed['lng'].toString());
          final confidence = parsed['confidence'] is num ? (parsed['confidence'] as num).toDouble() : double.tryParse(parsed['confidence']?.toString() ?? '') ?? 0.0;
          final source = parsed['source']?.toString() ?? 'gemini';
          if (lat != null && lng != null) return {'lat': lat, 'lng': lng, 'confidence': confidence, 'source': source};
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
