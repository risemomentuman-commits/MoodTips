class UserProfile {
  final String id;
  final bool onboardingCompleted;
  final int onboardingStep;
  final List<String> mainGoals;
  final List<String> preferredCategories;
  final Map<String, dynamic>? preferences; // ✅ AJOUTÉ
  final bool consentNotifications;
  final bool consentData;
  final int totalTipsCompleted;
  final int currentStreak;
  final int? longestStreak;
  final DateTime? lastMoodLogDate;
  final DateTime? lastMoodCheck;
  final bool hasCompletedOnboarding; 

  UserProfile({
    required this.id,
    this.onboardingCompleted = false,
    this.onboardingStep = 0,
    this.mainGoals = const [],
    this.preferredCategories = const [],
    this.preferences, // ✅ AJOUTÉ
    this.consentNotifications = false,
    this.consentData = true,
    this.totalTipsCompleted = 0,
    this.currentStreak = 0,
    this.longestStreak,
    this.lastMoodLogDate,
    this.lastMoodCheck,
    this.hasCompletedOnboarding = false, 
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      onboardingCompleted: json['onboarding_completed'] ?? false,
      onboardingStep: json['onboarding_step'] ?? 0,
      mainGoals: json['main_goals'] != null 
          ? List<String>.from(json['main_goals']) 
          : [],
      preferredCategories: json['preferred_categories'] != null
          ? List<String>.from(json['preferred_categories'])
          : [],
      preferences: json['preferences'] != null  // ✅ AJOUTÉ
          ? Map<String, dynamic>.from(json['preferences'])
          : null,
      consentNotifications: json['consent_notifications'] ?? false,
      consentData: json['consent_data'] ?? true,
      totalTipsCompleted: json['total_tips_completed'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] as int?,
      lastMoodLogDate: json['last_mood_log_date'] != null 
          ? DateTime.parse(json['last_mood_log_date']) 
          : null,
      lastMoodCheck: json['last_mood_check'] != null
          ? DateTime.parse(json['last_mood_check'])
          : null,
      hasCompletedOnboarding: json['has_completed_onboarding'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'onboarding_completed': onboardingCompleted,
      'onboarding_step': onboardingStep,
      'main_goals': mainGoals,
      'preferred_categories': preferredCategories,
      'preferences': preferences, // ✅ AJOUTÉ
      'consent_notifications': consentNotifications,
      'consent_data': consentData,
      'total_tips_completed': totalTipsCompleted,
      'current_streak': currentStreak,
      'last_mood_check': lastMoodCheck?.toIso8601String(),
    };
  }
}
