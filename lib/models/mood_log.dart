class MoodLog {
  final int id;
  final String userId;
  final int emotionId;
  final int? intensity;
  final DateTime createdAt;

  MoodLog({
    required this.id,
    required this.userId,
    required this.emotionId,
    this.intensity,
    required this.createdAt,
  });

  factory MoodLog.fromJson(Map<String, dynamic> json) {
    return MoodLog(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      emotionId: json['emotion_id'] as int,
      intensity: json['intensity'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
  


  