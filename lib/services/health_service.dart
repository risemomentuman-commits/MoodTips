import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/health_context_data.dart';

class HealthService {
  static final Health _health = Health();

  static final List<HealthDataType> _types = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Demande permissions selon la plateforme
  static Future<bool> requestAuthorization() async {
    try {
      // ✅ Health Connect sur Android, Apple Health sur iOS
      if (!kIsWeb) {
        bool authorized = await _health.requestAuthorization(_types);
        if (authorized) {
          final source = defaultTargetPlatform == TargetPlatform.iOS 
              ? 'apple_health' 
              : 'google_fit';
          await _saveConnectionStatus(source, true);
        }
        return authorized;
      }
      return false;
    } catch (e) {
      print('❌ Erreur autorisation Health: $e');
      return false;
    }
  }

  /// Récupère données sommeil dernières 24h
  static Future<SleepData?> getTodaySleepData() async {
    DateTime now = DateTime.now();
    DateTime yesterday = now.subtract(Duration(hours: 24));
    try {
      List<HealthDataPoint> sleepData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: yesterday,
        endTime: now,
      );
      if (sleepData.isEmpty) return null;

      double totalHours = 0;
      for (var point in sleepData) {
        Duration duration = point.dateTo.difference(point.dateFrom);
        totalHours += duration.inMinutes / 60;
      }
      return SleepData(
        durationHours: totalHours,
        qualityScore: _calculateSleepQuality(totalHours),
      );
    } catch (e) {
      print('❌ Erreur récupération sommeil: $e');
      return null;
    }
  }

  /// Récupère activité physique du jour
  static Future<ActivityData?> getTodayActivityData() async {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    try {
      List<HealthDataPoint> stepsData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: now,
      );
      int totalSteps = 0;
      for (var point in stepsData) {
        if (point.value is NumericHealthValue) {
          totalSteps += (point.value as NumericHealthValue).numericValue.round();
        }
      }
      return ActivityData(
        steps: totalSteps,
        activeMinutes: (totalSteps / 100).round(),
      );
    } catch (e) {
      print('❌ Erreur récupération activité: $e');
      return null;
    }
  }

  /// Récupère toutes les données (appelé par l'algo)
  static Future<HealthContextData> getAllHealthData() async {
    // ✅ Toujours demander/vérifier l'autorisation avant de lire
    if (!kIsWeb) {
      try {
        await _health.requestAuthorization(_types);
      } catch (e) {
        print('⚠️ Autorisation Health: $e');
      }
    }

    final sleep = await getTodaySleepData();
    final activity = await getTodayActivityData();
    
    print('✅ Health data: sommeil=${sleep?.durationHours}h, pas=${activity?.steps}');
    
    return HealthContextData(
      sleep: sleep,
      activity: activity,
      retrievedAt: DateTime.now(),
    );
  }

  static int _calculateSleepQuality(double hours) {
    if (hours >= 7 && hours <= 9) return 85;
    if (hours >= 6 && hours < 7) return 70;
    if (hours >= 5 && hours < 6) return 50;
    return 30;
  }

  static Future<void> _saveConnectionStatus(String source, bool active) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client.from('user_data_sources').upsert(
      {
        'user_id': userId,
        'source_type': source,
        'is_active': active,
        'last_sync_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,source_type',
    );
  }
}