import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../models/activity.dart';

class AppState extends ChangeNotifier {
  List<Goal> goals = [];
  List<Activity> activities = [];
  int selectedGoalIndex = -1;

  void setGoals(List<Goal> newGoals) {
    goals = newGoals;
    notifyListeners();
  }

  void setActivities(List<Activity> newActivities) {
    activities = newActivities;
    notifyListeners();
  }

  void completeActivity(Activity activity) {
    final goal = goals.firstWhere((g) => g.id == activity.goalId);
    goal.progress++;
    activities.remove(activity);
    notifyListeners();
  }
}
