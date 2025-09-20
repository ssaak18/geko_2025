import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/goal.dart';
import '../models/activity.dart';

class GeminiService {
  final String apiKey = dotenv.env['GEMINI_API_KEY']!;

  Future<List<Goal>> generateGoals(String userInput) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey",
      );

      final response = await http.post(
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
          .take(5)
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

  Future<List<Activity>> suggestActivities(double lat, double lng, List<Goal> goals) async {
    // Build a prompt for Gemini to generate 3 local activities
  final prompt = """
You are a local guide. Given the user's location (latitude: $lat, longitude: $lng), suggest 3 physical activities to do nearby. Each activity should:
  - Be a real place (restaurant, cafe, park, museum, etc.)
  - Include the activity type, place name, and full address
  - The address must include street address, city, state, and country
  - Be a reasonable walking/driving distance from the user's location
  - Match the activity type to the place (e.g., hiking at a park, eating at a restaurant)
  - The location marker should be placed at the activity's place, not the user's current location
Format:
Activity: <activity type>
Place: <place name>
Address: <street address>, <city>, <state>, <country>
Separate each activity with a blank line. Only output the activities in the format above.""";

    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey");
    final response = await http.post(
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
    final text = data["candidates"]?[0]["content"]?["parts"]?[0]["text"] ?? "";
    final activityBlocks = text.trim().split('\n\n');
    List<Activity> activities = [];
    List<Activity> fallbackActivities = [];
    Map<String, Map<String, double>> geoCache = {};
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
    for (int i = 0; i < activityBlocks.length; i++) {
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
        final geoUrl = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(geoQuery)}&addressdetails=1&limit=5');
        final geoResp = await http.get(geoUrl, headers: {'User-Agent': 'geko-app'});
        if (geoResp.statusCode == 200) {
          final geoData = jsonDecode(geoResp.body);
          if (geoData is List && geoData.isNotEmpty) {
            // Select the result closest to the user's location
            double minDist = double.infinity;
            Map<String, dynamic>? best;
            for (var result in geoData) {
              double? resLat = double.tryParse(result['lat'] ?? '');
              double? resLng = double.tryParse(result['lon'] ?? '');
              if (resLat != null && resLng != null) {
                double dist = ((lat - resLat) * (lat - resLat)) + ((lng - resLng) * (lng - resLng));
                if (dist < minDist) {
                  minDist = dist;
                  best = result;
                }
              }
            }
            if (best != null) {
              markerLat = double.tryParse(best['lat'] ?? '') ?? lat;
              markerLng = double.tryParse(best['lon'] ?? '') ?? lng;
              geocoded = true;
              geoCache[geoQuery] = {'lat': markerLat, 'lng': markerLng};
            }
          }
        }
      }
      if (geocoded && (markerLat != lat || markerLng != lng)) {
        activities.add(Activity(
          id: "${DateTime.now().millisecondsSinceEpoch}_${i}",
          title: title,
          lat: markerLat,
          lng: markerLng,
          goalId: goals.isNotEmpty ? goals[i % goals.length].id : '',
          category: category,
        ));
      } else {
        // Prepare fallback activity at a nearby location
        fallbackActivities.add(Activity(
          id: "fallback_${DateTime.now().millisecondsSinceEpoch}_$i",
          title: title + " (location not verified)",
          lat: lat + 0.005 * (i + 1),
          lng: lng - 0.005 * (i + 1),
          goalId: goals.isNotEmpty ? goals[i % goals.length].id : '',
          category: category,
        ));
      }
    }
    // Always return 3 activities: prefer geocoded, fill with fallback if needed
    List<Activity> result = [];
    result.addAll(activities);
    for (int i = result.length; i < 3 && i < activities.length + fallbackActivities.length; i++) {
      result.add(fallbackActivities[i - activities.length]);
    }
    // If still less than 3, fill with generic fallback
    for (int i = result.length; i < 3; i++) {
      result.add(Activity(
        id: "generic_fallback_${DateTime.now().millisecondsSinceEpoch}_$i",
        title: "Explore a local spot (location not verified)",
        lat: lat + 0.01 * (i + 1),
        lng: lng - 0.01 * (i + 1),
        goalId: '',
        category: 'Other',
      ));
    }
    return result;
  }
}
