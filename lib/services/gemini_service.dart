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
    // 1. Use Gemini to generate 3 activity types/categories only
    final prompt = """
Suggest 3 unique, real-world place types or categories (e.g., 'music store', 'garden center', 'cafe', 'park') that match these interests: ${genres.join(', ')}. Only output the place type or category, one per line. Do not include any place names, addresses, or extra text.
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

    if (response.statusCode != 200) {
      print("Gemini API Error: ${response.statusCode}");
      return [];
    }

    final data = jsonDecode(response.body);
    String text = "";
    try {
      if (data is Map &&
          data['candidates'] != null &&
          data['candidates'] is List &&
          data['candidates'].isNotEmpty) {
        final cand = data['candidates'][0];
        if (cand is Map) {
          final content = cand['content'];
          if (content is String) {
            text = content;
          } else if (content is Map &&
              content['parts'] is List &&
              content['parts'].isNotEmpty) {
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
    final activityTypes = text.trim().split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    print('[DEBUG] Gemini activity types: $activityTypes');

    // 2. For each activity type, use Google Places API to find a real place
    List<Activity> activities = [];
    for (int i = 0; i < activityTypes.length && activities.length < 3; i++) {
      final type = activityTypes[i];
      // Use Places API nearbysearch with keyword
      final placesUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=3000&keyword=${Uri.encodeComponent(type)}&key=$googleMapsApiKey',
      );
      final placesResp = await httpClient.get(placesUrl);
      print('[DEBUG] Google Places API request for "$type": ${placesUrl.toString()}');
      if (placesResp.statusCode == 200) {
        final placesData = jsonDecode(placesResp.body);
        print('[DEBUG] Google Places API response for "$type": ${placesResp.body}');
        if (placesData['results'] != null && placesData['results'].isNotEmpty) {
          final place = placesData['results'][0];
          final name = place['name'] ?? type;
          final address = place['vicinity'] ?? '';
          final loc = place['geometry']?['location'];
          final placeLat = loc != null ? (loc['lat']?.toDouble() ?? lat) : lat;
          final placeLng = loc != null ? (loc['lng']?.toDouble() ?? lng) : lng;
          activities.add(
            Activity(
              id: "${DateTime.now().millisecondsSinceEpoch}_${i}",
              title: '$type at $name ($address)',
              lat: placeLat,
              lng: placeLng,
              goalId: '',
              category: type,
              verified: true,
              verificationConfidence: 1.0,
              verificationSource: 'google_places',
            ),
          );
        } else {
          print('[DEBUG] Google Places API returned no results for "$type"');
        }
      } else {
        print('[DEBUG] Google Places API error for "$type": status ${placesResp.statusCode}');
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
