class InstructionStep {
  final int step;
  final String title;
  final String description;
  final int duration; // en secondes
  final String? icon;

  InstructionStep({
    required this.step,
    required this.title,
    required this.description,
    required this.duration,
    this.icon,
  });

  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    return InstructionStep(
      step: json['step'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      duration: json['duration'] as int,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'title': title,
      'description': description,
      'duration': duration,
      if (icon != null) 'icon': icon,
    };
  }

  String get durationFormatted {
    if (duration < 60) {
      return '$duration sec';
    }
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    if (seconds == 0) {
      return '$minutes min';
    }
    return '$minutes min $seconds sec';
  }
}
