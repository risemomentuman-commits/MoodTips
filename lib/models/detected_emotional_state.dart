class DetectedEmotionalState {
  final String? primaryEmotion;
  final List<String> secondaryEmotions;
  final double confidence;
  final List<String> detectionReasons;
  final List<EmotionPrediction> rawPredictions;
  final DateTime detectedAt;

  DetectedEmotionalState({
    this.primaryEmotion,
    this.secondaryEmotions = const [],
    required this.confidence,
    required this.detectionReasons,
    required this.rawPredictions,
    required this.detectedAt,
  });

  bool get hasDetection => primaryEmotion != null && confidence > 0.5;
}

class EmotionPrediction {
  final String emotion;
  final double confidence;
  final String reason;

  EmotionPrediction({
    required this.emotion,
    required this.confidence,
    required this.reason,
  });
}