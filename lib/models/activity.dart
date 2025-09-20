
class Activity {
  final String id;
  final String title;
  final double lat;
  final double lng;
  final String goalId;
  final String category;
  final bool verified;
  final double verificationConfidence;
  final String verificationSource;

  Activity({
    required this.id,
    required this.title,
    required this.lat,
    required this.lng,
    required this.goalId,
    required this.category,
    this.verified = false,
    this.verificationConfidence = 0.0,
    this.verificationSource = '',
  });

  Activity copyWith({
    String? id,
    String? title,
    double? lat,
    double? lng,
    String? goalId,
    String? category,
    bool? verified,
    double? verificationConfidence,
    String? verificationSource,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      goalId: goalId ?? this.goalId,
      category: category ?? this.category,
      verified: verified ?? this.verified,
      verificationConfidence: verificationConfidence ?? this.verificationConfidence,
      verificationSource: verificationSource ?? this.verificationSource,
    );
  }
}
