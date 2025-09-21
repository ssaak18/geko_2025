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
  }) : httpClient = httpClient ?? http.Client(),
       apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
       googleMapsApiKey =
           googleMapsApiKey ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
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
                      "You are the very best life coach and travel planner in the world. "
                          "The user needs advice on how to summarize all of their plans into concrete life goals, "
                          "and also wants actionable activities for each goal. "
                          "Based on these user goals: '$userInput',\n" +
                      "Generate exactly 5 specific, actionable life goals that encapsulate everything in the user goals. "
                          "The goals should only be active/positive actions; do not say something like 'practice moderation'. "
                          "They should not be too specific but be categories that allow for a travel agency to suggest activities related to them. "
                          "Format each goal as a simple sentence on a new line. Do not include numbers, bullets, or extra formatting.\n",
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
      print("Gemini raw text for goals:\n$text");
      final goalLines = text
          .split("\n")
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .take(5)
          .toList();
      print("Parsed goalLines: $goalLines");

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

  Future<List<Activity>> suggestActivities(
    double lat,
    double lng,
    List<String> genres,
  ) async {
    // Fallback/related place types for common themes
    final Map<String, List<String>> relatedTypes = {
      'cooking school': [
        'culinary school',
        'cooking class',
        'restaurant',
        'grocery store',
        'food market',
      ],
      'grocery store': ['supermarket', 'food market', 'convenience store'],
      'running track': ['track', 'stadium', 'park', 'gym'],
      'music store': ['record store', 'music shop', 'instrument store'],
      'thrift store': [
        'second hand store',
        'charity shop',
        'consignment store',
      ],
      'garden center': ['plant nursery', 'garden shop', 'park'],
      'art gallery': ['museum', 'art museum', 'exhibition'],
      'bookstore': ['library', 'book shop'],
      'playground': ['park', 'recreation area'],
      'zoo': ['animal park', 'wildlife park'],
      // Add more as needed
    };
    // 1. Use Gemini to generate 3 place types/categories only
    final prompt =
        """
Suggest 3 unique, real-world place types or categories (such as 'park', 'cafe', 'museum', 'library', 'restaurant', 'garden center', 'music store', 'thrift store', 'farmers market', 'bookstore', 'art gallery', 'gym', 'beach', 'zoo', 'playground', etc.) that match these interests: ${genres.join(', ')}. Only output the place type or category, one per line. Do not include any organization names, place names, addresses, or extra text. Do not output things like 'community college' or 'YMCA'—use only generic place types that work with OpenStreetMap Nominatim search.
""";

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey",
    );
    final response = await httpClient.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
      }),
    );

    // Parse Gemini response for activity types
    final responseData = jsonDecode(response.body);
    String? text;
    try {
      text =
          responseData['candidates'][0]['content']['parts'][0]['text']
              as String?;
    } catch (_) {
      text = null;
    }
    final activityTypes = (text ?? '')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    print('[DEBUG] Gemini activity types: $activityTypes');

    // 2. For each place type, use OpenStreetMap Nominatim API to find a real place
    List<Activity> activities = [];
    for (int i = 0; i < activityTypes.length && activities.length < 3; i++) {
      String type = activityTypes[i];
      bool found = false;
      List<String> triedTypes = [type];
      List<String> tryTypes = [type, ...?relatedTypes[type.toLowerCase()]];
      for (final tryType in tryTypes) {
        // Build bounding box for ~3km radius
        double delta = 0.03;
        final minLat = lat - delta;
        final maxLat = lat + delta;
        final minLng = lng - delta;
        final maxLng = lng + delta;
        final nominatimUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(tryType)}&limit=5&viewbox=$minLng,$minLat,$maxLng,$maxLat&bounded=1',
        );
        final nominatimResp = await httpClient.get(
          nominatimUrl,
          headers: {'User-Agent': 'geko-app/1.0 (your@email.com)'},
        );
        print(
          '[DEBUG] Nominatim API request for "$tryType": ${nominatimUrl.toString()}',
        );
        if (nominatimResp.statusCode == 200) {
          final nominatimData = jsonDecode(nominatimResp.body);
          print(
            '[DEBUG] Nominatim API response for "$tryType": ${nominatimResp.body}',
          );
          if (nominatimData is List && nominatimData.isNotEmpty) {
            final place = nominatimData[0];
            final name = place['display_name'] ?? tryType;
            final placeLat = double.tryParse(place['lat'] ?? '') ?? lat;
            final placeLng = double.tryParse(place['lon'] ?? '') ?? lng;
            activities.add(
              Activity(
                id: "${DateTime.now().millisecondsSinceEpoch}_${i}",
                title: '$type at $name',
                lat: placeLat,
                lng: placeLng,
                goalId: '',
                category: type,
                verified: true,
                verificationConfidence: 1.0,
                verificationSource: 'nominatim',
              ),
            );
            found = true;
            break;
          } else {
            print('[DEBUG] Nominatim API returned no results for "$tryType"');
          }
        } else {
          print(
            '[DEBUG] Nominatim API error for "$tryType": status ${nominatimResp.statusCode}',
          );
        }
      }
      if (!found) {
        // As a last resort, fallback to a generic local spot for this type
        final offsetLat = lat + 0.02 * (i + 1) * (i.isEven ? 1 : -1);
        final offsetLng = lng + 0.02 * (i + 1) * (i.isOdd ? 1 : -1);
        final title = "$type at a local spot (location not verified)";
        activities.add(
          Activity(
            id: "generic_fallback_${DateTime.now().millisecondsSinceEpoch}_$i",
            title: title,
            lat: offsetLat,
            lng: offsetLng,
            goalId: '',
            category: type,
          ),
        );
      }
    }
    // If less than 3, fill with generic fallback
    for (int i = activities.length; i < 3; i++) {
      final offsetLat = lat + 0.02 * (i + 1) * (i.isEven ? 1 : -1);
      final offsetLng = lng + 0.02 * (i + 1) * (i.isOdd ? 1 : -1);
      final title = "Explore a local spot (location not verified) ${i}";
      activities.add(
        Activity(
          id: "generic_fallback_${DateTime.now().millisecondsSinceEpoch}_$i",
          title: title,
          lat: offsetLat,
          lng: offsetLng,
          goalId: '',
          category: 'Other',
        ),
      );
    }
    // Ensure all returned activities have distinct coordinates (nudge duplicates)
    const minSeparation = 0.0001; // ~11m
    for (int i = 0; i < activities.length; i++) {
      for (int j = i + 1; j < activities.length; j++) {
        if ((activities[i].lat - activities[j].lat).abs() < minSeparation &&
            (activities[i].lng - activities[j].lng).abs() < minSeparation) {
          // Nudge the later one slightly
          activities[j] = activities[j].copyWith(
            lat: activities[j].lat + minSeparation * (j + 1),
            lng: activities[j].lng + minSeparation * (j + 1),
          );
        }
      }
    }
    return activities;
  }

  // Call Gemini to verify an address and return {'lat': double, 'lng': double}
}
