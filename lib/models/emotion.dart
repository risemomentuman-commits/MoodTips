class Emotion {
  final int id;
  final String name;
  final String nameEn;
  final String icon;
  final String color;
  final String emoji;
  final int orderDisplay;

  Emotion({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.icon,
    required this.color,
    required this.emoji,
    required this.orderDisplay,
  });

  factory Emotion.fromJson(Map<String, dynamic> json) {
    return Emotion(
      id: json['id'] as int,
      name: json['name'] as String,
      nameEn: json['name_en'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      emoji: json['emoji'] as String,
      orderDisplay: json['order_display'] as int,
    );
  }
}