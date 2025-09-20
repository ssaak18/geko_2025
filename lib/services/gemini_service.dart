import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/goal.dart';
import '../models/activity.dart';

class GeminiService {
  final String apiKey = dotenv.env['GEMINI_API_KEY']!;

  Future<List<Goal>> generateGoals(String userInput) async {
    try {
      final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "Based on these user goals: '$userInput', generate exactly 5 specific, actionable life goals. Format each goal as a simple sentence on a new line. Do not include numbers, bullets, or extra formatting."}
              ]
            }
          ]
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

      final text = data["candidates"][0]["content"]["parts"][0]["text"] as String;
      final goalLines = text.split("\n")
          .where((g) => g.trim().isNotEmpty)
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .take(5)
          .toList();

      if (goalLines.isEmpty) {
        return _getFallbackGoals();
      }

      return goalLines.map((g) => Goal(
        id: g.hashCode.toString(), 
        title: g.replaceAll(RegExp(r'^[0-9]+\.?\s*'), '') // Remove any numbers at the start
      )).toList();

    } catch (e) {
      print("Error generating goals: $e");
      return _getFallbackGoals();
    }
  }

  List<Goal> _getFallbackGoals() {
    return [
      Goal(id: "1", title: "Learn a new skill this year"),
      Goal(id: "2", title: "Exercise regularly and stay healthy"),
      Goal(id: "3", title: "Build stronger relationships with family and friends"),
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
    for (int i = 0; i < activityBlocks.length; i++) {
      final lines = activityBlocks[i].split('\n');
      String title = '';
      String address = '';
      String place = '';
      for (final line in lines) {
        if (line.startsWith('Activity:')) {
          title = line.replaceFirst('Activity:', '').trim();
        } else if (line.startsWith('Place:')) {
          place = line.replaceFirst('Place:', '').trim();
          title += ' at ' + place;
        } else if (line.startsWith('Address:')) {
          address = line.replaceFirst('Address:', '').trim();
          title += ' (' + address + ')';
        }
      }
      String geoQuery = address;
      if (place.isNotEmpty) geoQuery = place + ', ' + address;
      double markerLat = lat;
      double markerLng = lng;
      bool geocoded = false;
      if (geoQuery.isNotEmpty) {
        final geoUrl = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(geoQuery)}&addressdetails=1&limit=1');
        final geoResp = await http.get(geoUrl, headers: {'User-Agent': 'geko-app'});
        if (geoResp.statusCode == 200) {
          final geoData = jsonDecode(geoResp.body);
          if (geoData is List && geoData.isNotEmpty) {
            markerLat = double.tryParse(geoData[0]['lat'] ?? '') ?? lat;
            markerLng = double.tryParse(geoData[0]['lon'] ?? '') ?? lng;
            geocoded = true;
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
        ));
      } else {
        // Prepare fallback activity at a nearby location
        fallbackActivities.add(Activity(
          id: "fallback_${DateTime.now().millisecondsSinceEpoch}_$i",
          title: title + " (location not verified)",
          lat: lat + 0.005 * (i + 1),
          lng: lng - 0.005 * (i + 1),
          goalId: goals.isNotEmpty ? goals[i % goals.length].id : '',
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
      ));
    }
    return result;
  }
}