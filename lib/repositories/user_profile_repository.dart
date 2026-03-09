import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile_dynamic.dart';

class UserProfileRepository {
  final SupabaseClient _client;

  UserProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<UserProfileDynamic?> getProfile(String userId) async {
    final response = await _client
        .from('user_profiles_dynamic')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return null;
    return UserProfileDynamic.fromJson(response);
  }

  Future<UserProfileDynamic> getOrCreateProfile(String userId) async {
    final existing = await getProfile(userId);
    if (existing != null) return existing;
    return await createProfile(userId);
  }

  Future<UserProfileDynamic> createProfile(String userId) async {
    // Appel de la fonction SQL d'initialisation
    await _client.rpc('initialize_user_profile_v2', params: {
      'p_user_id': userId,
    });
    final profile = await getProfile(userId);
    return profile!;
  }

  Future<void> updateProfile(UserProfileDynamic profile) async {
    await _client
        .from('user_profiles_dynamic')
        .update(profile.toJson())
        .eq('user_id', profile.userId);
  }

  Future<void> updateBaseline({
    required String userId,
    required double avgSleep,
    required int avgSteps,
    required double avgLoad,
    required int totalDays,
  }) async {
    final confidence = totalDays >= 7 ? 0.7 : (totalDays / 7.0) * 0.7;
    await _client.from('user_profiles_dynamic').update({
      'baseline_sleep_hours': avgSleep,
      'baseline_steps': avgSteps,
      'baseline_mental_load': avgLoad,
      'total_days_data': totalDays,
      'confidence_level': confidence.clamp(0.0, 1.0),
      'last_baseline_update': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
  }
}