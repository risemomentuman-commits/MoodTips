import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/user_profile_repository.dart';

class UserLearningService {
  final SupabaseClient _client;
  final UserProfileRepository _profileRepo;

  UserLearningService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        _profileRepo = UserProfileRepository(client: client);

  /// Recalcule la baseline sur les 7 derniers jours
  Future<void> updateBaseline(String userId) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final response = await _client
        .from('daily_health_data')
        .select('sleep_duration_hours, steps_total, total_events')
        .eq('user_id', userId)
        .gte('date', sevenDaysAgo.toIso8601String().substring(0, 10))
        .lte('date', now.toIso8601String().substring(0, 10));

    final data = response as List;
    if (data.isEmpty) return;

    double totalSleep = 0;
    int totalSteps = 0;
    double totalLoad = 0;

    for (final row in data) {
      totalSleep += (row['sleep_duration_hours'] as num?)?.toDouble() ?? 0;
      totalSteps += (row['steps_total'] as num?)?.toInt() ?? 0;
      totalLoad += (row['total_events'] as num?)?.toDouble() ?? 0;
    }

    final count = data.length;

    await _profileRepo.updateBaseline(
      userId: userId,
      avgSleep: totalSleep / count,
      avgSteps: (totalSteps / count).round(),
      avgLoad: totalLoad / count,
      totalDays: count,
    );
  }

  /// Sauvegarde les données santé du jour
  Future<void> saveDailyHealthData({
    required String userId,
    required double sleepHours,
    int sleepQuality = 0,
    String sleepSource = 'manual',
    int steps = 0,
    int activeMinutes = 0,
    int totalEvents = 0,
    int workEvents = 0,
    int positiveEvents = 0,
    double meetingHours = 0,
    String? morningEmotion,
    int? morningIntensity,
    String? eveningEmotion,
    int? eveningIntensity,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final dayOfWeek = DateTime.now().weekday;
    final isWeekend = dayOfWeek == 6 || dayOfWeek == 7;

    final data = {
      'user_id': userId,
      'date': today,
      'sleep_duration_hours': sleepHours,
      'sleep_quality_score': sleepQuality,
      'sleep_source': sleepSource,
      'steps_total': steps,
      'active_minutes': activeMinutes,
      'total_events': totalEvents,
      'work_events': workEvents,
      'positive_events': positiveEvents,
      'meeting_hours': meetingHours,
      'day_of_week': ['', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'][dayOfWeek],
      'is_weekend': isWeekend,
    };

    if (morningEmotion != null) {
      data['morning_emotion'] = morningEmotion;
      data['morning_intensity'] = morningIntensity ?? 3;
    }
    if (eveningEmotion != null) {
      data['evening_emotion'] = eveningEmotion;
      data['evening_intensity'] = eveningIntensity ?? 3;
    }

    try {
      await _client.from('daily_health_data').upsert(
        data,
        onConflict: 'user_id,date',
      );
      print('✅ daily_health_data sauvegardé: $today');
    } catch (e) {
      print('❌ Erreur daily_health_data: $e');
    }
  }

  /// Récupère les émotions des 7 derniers jours
  Future<List<String>> getLast7Emotions(String userId) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final emotions = <String>[];

    try {
      final moodLogs = await _client
          .from('mood_logs')
          .select('emotions!inner(name)')
          .eq('user_id', userId)
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .order('created_at', ascending: false);

      for (final row in moodLogs as List) {
        if (row['emotions'] != null && row['emotions']['name'] != null) {
          emotions.add(row['emotions']['name'] as String);
        }
      }
    } catch (e) {
      print('⚠️ Erreur lecture émotions mood_logs: $e');
    }

    return emotions;
  }


  /// Récupère les données santé du jour
  Future<Map<String, dynamic>?> getTodayHealthData(String userId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await _client
        .from('daily_health_data')
        .select()
        .eq('user_id', userId)
        .eq('date', today)
        .maybeSingle();
  }
}