import 'package:health/health.dart';
import '../models/health_context_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppleHealthService {
  static final Health _health = Health();
  
  static final types = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];
  
  /// Demande permissions
  static Future<bool> requestAuthorization() async {
    try {
      bool authorized = await _health.requestAuthorization(types);
      
      if (authorized) {
        await _saveConnectionStatus('apple_health', true);
      }
      
      return authorized;
    } catch (e) {
      print('❌ Erreur autorisation Apple Health: $e');
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
        types: [HealthDataType.STEPS],  // ✅ types:
        startTime: startOfDay,           // ✅ startTime:
        endTime: now,                    // ✅ endTime:
      );
      
      int totalSteps = 0;
      for (var point in stepsData) {
        totalSteps += (point.value as num).toInt();
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
  
  /// Récupère toutes les données
  static Future<HealthContextData> getAllHealthData() async {
    final sleep = await getTodaySleepData();
    final activity = await getTodayActivityData();
    
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
    
    // ✅ CORRECTION : Spécifier les colonnes de conflit pour le upsert
    await Supabase.instance.client.from('user_data_sources').upsert(
      {
        'user_id': userId,
        'source_type': source,
        'is_active': active,
        'last_sync_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(), // ✅ Ajouter aussi
      },
      onConflict: 'user_id,source_type', // ✅ IMPORTANT : Spécifier les colonnes uniques
    );
  }
}