import 'instruction_step.dart';

class Tip {
  final int id;
  final String category;
  final String title;
  final String description;
  final int? durationMinutes;
  final dynamic instructions;
  final String? imageUrl;
  final int intensityLevel;
  final String difficulty;
  final List<String> emotions;
  final String? audioUrl;
  final List<InstructionStep>? instructionsSteps;
  final String? backgroundMusic; 

  Tip({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.durationMinutes,
    this.instructions,
    this.imageUrl,
    required this.intensityLevel,
    required this.difficulty,
    required this.emotions,
    this.audioUrl,
    this.instructionsSteps,
    this.backgroundMusic,
  });

  factory Tip.fromJson(Map<String, dynamic> json) {
    return Tip(
      id: json['id'] as int,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int?,
      instructions: json['instructions'],
      imageUrl: json['image_url'] as String?,
      intensityLevel: json['intensity_level'] as int? ?? 2,
      difficulty: json['difficulty'] as String? ?? 'beginner',
      emotions: json['emotions'] != null
          ? List<String>.from(json['emotions'])
          : [],
      backgroundMusic: json['background_music'] as String?,
      instructionsSteps: json['instructions_steps'] != null
          ? (json['instructions_steps'] as List)
              .map((step) => InstructionStep.fromJson(step as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  bool get hasAudioGuide => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasInstructions => instructionsSteps != null && instructionsSteps!.isNotEmpty;
  bool get hasEnrichedContent => hasAudioGuide || hasInstructions;
}