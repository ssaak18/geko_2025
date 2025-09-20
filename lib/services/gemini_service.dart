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

  Future<List<Activity>> suggestActivities(
    double lat,
    double lng,
    List<Goal> goals,
  ) async {
    // For now, return activities based on the actual goals provided
    if (goals.isEmpty) {
      return [];
    }

    // Create activities that relate to the user's actual goals
    List<Activity> activities = [];

    for (int i = 0; i < goals.length && i < 3; i++) {
      final goal = goals[i];
      String activityTitle = _getActivityForGoal(goal.title, i);

      activities.add(
        Activity(
          id: "${i + 1}",
          title: activityTitle,
          lat: lat + (0.01 * (i + 1)) * (i.isEven ? 1 : -1),
          lng: lng + (0.01 * (i + 1)) * (i.isOdd ? 1 : -1),
          goalId: goal.id,
        ),
      );
    }

    return activities;
  }

  String _getActivityForGoal(String goalTitle, int index) {
    final lowerGoal = goalTitle.toLowerCase();

    if (lowerGoal.contains('learn') || lowerGoal.contains('skill')) {
      return "Visit the local library or community center";
    } else if (lowerGoal.contains('exercise') || lowerGoal.contains('health')) {
      return "Go for a walk in the nearby park";
    } else if (lowerGoal.contains('relationship') ||
        lowerGoal.contains('family')) {
      return "Visit a local cafe for quality time";
    } else if (lowerGoal.contains('career') || lowerGoal.contains('work')) {
      return "Attend a networking event or workshop";
    } else if (lowerGoal.contains('mindful') || lowerGoal.contains('growth')) {
      return "Find a quiet spot for meditation";
    } else {
      // Fallback activities
      final fallbacks = [
        "Explore a local museum",
        "Try a new restaurant",
        "Visit a nearby attraction",
      ];
      return fallbacks[index % fallbacks.length];
    }
  }
}
