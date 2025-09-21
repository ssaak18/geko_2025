import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../models/activity.dart';

class AppState extends ChangeNotifier {
  List<Goal> goals = [];
  List<Activity> activities = [];
  List<String> preferredGenres = [];
  int selectedGoalIndex = -1;
  Map<String, int> badgeProgress = {};

  void setGoals(List<Goal> newGoals) {
    goals = newGoals;
    notifyListeners();
  }

  void setActivities(List<Activity> newActivities) {
    activities = newActivities;
    notifyListeners();
  }

  void setPreferredGenres(List<String> genres) {
    preferredGenres = genres;
    notifyListeners();
  }

  void addActivity(Activity activity) {
    activities.add(activity);
    notifyListeners();
  }

  void completeActivity(Activity activity) {
    final goal = goals.firstWhere((g) => g.id == activity.goalId, orElse: () => goals.isNotEmpty ? goals[0] : Goal(id: '', title: ''));
    goal.progress++;
    activities.remove(activity);
    // Update badge progress
    badgeProgress[activity.category] = (badgeProgress[activity.category] ?? 0) + 1;
    notifyListeners();
  }

  int getBadgeProgress(String category) {
    return badgeProgress[category] ?? 0;
  }
}
