import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceTokenRepository {
  static final _supabase = Supabase.instance.client;

  static Future<void> upsertToken({
    required String token,
    required String platform, // 'web' | 'ios' | 'android'
    required bool enabled,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('❌ [TOKENS] user not logged in');
      return;
    }

    await _supabase.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': platform,
      'enabled': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');

    print('✅ [TOKENS] saved ($platform): ${token.substring(0, 16)}...');
  }

  static Future<bool> isEnabled() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final res = await _supabase
        .from('device_tokens')
        .select('id')
        .eq('user_id', userId)
        .eq('enabled', true)
        .limit(1);

    return (res as List).isNotEmpty;
  }

  static Future<void> setEnabledForUser(bool enabled) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('device_tokens').update({
      'enabled': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId);
  }
}
