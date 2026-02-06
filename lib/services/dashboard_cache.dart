import '../models/user_profile.dart';
import '../models/mood_log.dart';

class DashboardCache {
  static UserProfile? profile;
  static List<MoodLog>? recentMoods;
  static Map<String, dynamic>? contextInsights;
  static Map<String, dynamic>? exerciseStats;
  static DateTime? lastUpdate;
  
  static bool get isValid {
    if (lastUpdate == null) return false;
    // Cache valide pendant 5 minutes
    return DateTime.now().difference(lastUpdate!) < Duration(minutes: 5);
  }
  
  static void clear() {
    profile = null;
    recentMoods = null;
    contextInsights = null;
    exerciseStats = null;
    lastUpdate = null;
  }
  
  static void update({
    UserProfile? newProfile,
    List<MoodLog>? newMoods,
    Map<String, dynamic>? newContexts,
    Map<String, dynamic>? newStats,
  }) {
    profile = newProfile;
    recentMoods = newMoods;
    contextInsights = newContexts;
    exerciseStats = newStats;
    lastUpdate = DateTime.now();
  }
}