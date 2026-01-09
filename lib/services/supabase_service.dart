import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/emotion.dart';
import '../models/tip.dart';
import '../models/mood_log.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // ========== AUTHENTIFICATION ==========

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static User? get currentUser => _client.auth.currentUser;
  
  static String? get currentUserId => _client.auth.currentUser?.id;

  static bool get isAuthenticated => _client.auth.currentUser != null;

  // ========== PROFIL UTILISATEUR ==========

  static Future<UserProfile?> getProfile() async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Erreur getProfile: $e');
      return null;
    }
  }

  static Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Non authentifie');

    await _client
        .from('profiles')
        .update(data)
        .eq('id', userId);
  }

  static Future<void> updateOnboardingStep(int step) async {
    await updateProfile({'onboarding_step': step});
  }

  static Future<void> completeOnboarding() async {
    await updateProfile({
      'onboarding_completed': true,
      'onboarding_step': 5,
    });
  }

  // ========== ÉMOTIONS ==========

  static Future<List<Emotion>> getEmotions() async {
    try {
      final response = await _client
          .from('emotions')
          .select()
          .eq('is_active', true)
          .order('order_display');

      return (response as List)
          .map((json) => Emotion.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur getEmotions: $e');
      return [];
    }
  }

  // ========== MOOD LOGS ==========

  static Future<MoodLog?> createMoodLog({
    required int emotionId,
    int intensity = 5,
  }) async {
    try {
      print('🔄 createMoodLog appelé - emotionId: $emotionId');
      
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        print('❌ Pas d\'userId dans createMoodLog');
        return null;
      }
      
      print('👤 userId: $userId');
      
      final response = await _client.from('mood_logs').insert({
        'user_id': userId,
        'emotion_id': emotionId,
        'intensity': intensity,
      }).select().single();
      
      print('✅ Mood log créé: ${response['id']}');
      print('🔄 Appel de updateStreak()');
      
      await updateStreak();
      
      print('✅ updateStreak() terminé');
      
      return MoodLog.fromJson(response);
    } catch (e) {
      print('❌ Erreur createMoodLog: $e');
      return null;
    }
  }


  static Future<void> updateStreak() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final profileData = await _client
          .from('profiles')
          .select('current_streak, longest_streak, last_mood_log_date')
          .eq('id', userId)
          .single();

      final currentStreak = profileData['current_streak'] as int? ?? 0;
      final longestStreak = profileData['longest_streak'] as int? ?? 0;
      final lastLogDate = profileData['last_mood_log_date'] as String?;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int newStreak = currentStreak;

      if (lastLogDate == null) {
        newStreak = 1;
      } else {
        final lastDate = DateTime.parse(lastLogDate);
        final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final difference = today.difference(lastDateOnly).inDays;

        if (difference == 0) {
          return;
        } else if (difference == 1) {
          newStreak = currentStreak + 1;
        } else {
          newStreak = 1;
        }
      }

      await _client.from('profiles').update({
        'current_streak': newStreak,
        'longest_streak': newStreak > longestStreak ? newStreak : longestStreak,
        'last_mood_log_date': today.toIso8601String(),
      }).eq('id', userId);

      print('✅ Streak mis à jour : $newStreak jours (longest: ${newStreak > longestStreak ? newStreak : longestStreak})');
    } catch (e) {
      print('❌ Erreur updateStreak : $e');
    }
  }

  static Future<List<MoodLog>> getMoodLogs({int limit = 7}) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await Supabase.instance.client
          .from('mood_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => MoodLog.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur getMoodLogs: $e');
      return [];
    }
  }

  // ========== MOOD CONTEXTS ==========

  static Future<void> saveMoodContext({
    required int moodLogId,
    required String location,
    required String company,
    required String timeOfDay,
    required String activity,
  }) async {
    try {
      await _client.from('mood_contexts').insert({
        'mood_log_id': moodLogId,
        'location': location,
        'company': company,
        'time_of_day': timeOfDay,
        'activity': activity,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Erreur saveMoodContext: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getContextInsights() async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final contextsResponse = await _client
          .from('mood_contexts')
          .select('*, mood_logs!inner(*)')
          .eq('mood_logs.user_id', userId)
          .limit(50);

      print('📊 Contextes récupérés: ${contextsResponse.length}');

      final List<Map<String, dynamic>> enrichedData = [];
      
      for (var context in contextsResponse) {
        final moodLogId = context['mood_log_id'];
        
        final emotionResponse = await _client
            .from('mood_logs')
            .select('emotion_id, emotions!inner(name, type)')
            .eq('id', moodLogId)
            .single();
        
        enrichedData.add({
          ...context,
          'emotion_name': emotionResponse['emotions']['name'],
          'emotion_type': emotionResponse['emotions']['type'],
        });
      }

      print('✅ Données enrichies: ${enrichedData.length}');

      return {
        'total': enrichedData.length,
        'data': enrichedData,
      };
    } catch (e) {
      print('❌ Erreur getContextInsights: $e');
      return null;
    }
  }

  // ========== TIPS ==========

  static Future<List<Tip>> getRecommendedTips(int emotionId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');

      final prefsResponse = await Supabase.instance.client
          .from('profiles')
          .select('preferences')
          .eq('id', userId)
          .single();

      final preferences = prefsResponse['preferences'] as Map<String, dynamic>?;
      List<String> preferredCategories = [];
      
      if (preferences != null && preferences['categories'] != null) {
        final cats = preferences['categories'] as List<dynamic>;
        preferredCategories = cats.map((e) => e.toString()).toList();
      }

      if (preferredCategories.isEmpty) {
        preferredCategories = ['respiration', 'mouvement', 'mental'];
      }

      print('📊 Préférences utilisateur : $preferredCategories');

      final recentTipsResponse = await Supabase.instance.client
          .from('tips_sessions')
          .select('tip_id')
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(10);

      final recentTipIds = (recentTipsResponse as List)
          .map((e) => e['tip_id'] as int)
          .toSet()
          .toList();

      print('🚫 Tips récents à éviter : $recentTipIds');

      List<Tip> candidateTips = [];
      
      for (String category in preferredCategories) {
        var query = Supabase.instance.client
            .from('tips')
            .select()
            .eq('category', category)
            .eq('is_active', true);

        if (recentTipIds.isNotEmpty) {
          query = query.not('id', 'in', '(${recentTipIds.join(',')})');
        }

        final response = await query.limit(5);

        for (var json in response) {
          candidateTips.add(Tip.fromJson(json));
        }
      }

      print('🎲 Candidats disponibles : ${candidateTips.length} tips');

      List<Tip> selectedTips = [];
      candidateTips.shuffle();

      for (String category in preferredCategories) {
        try {
          final tipInCategory = candidateTips.firstWhere(
            (tip) => tip.category == category && !selectedTips.contains(tip),
          );
          selectedTips.add(tipInCategory);
          print('✅ Ajouté tip $category : ${tipInCategory.title}');
        } catch (e) {
          print('⚠️ Aucun tip $category disponible');
        }
      }

      if (selectedTips.length < 3) {
        final excludedIds = selectedTips.map((t) => t.id).toList();
        final remaining = 3 - selectedTips.length;

        var query = Supabase.instance.client
            .from('tips')
            .select()
            .eq('is_active', true)
            .filter('category', 'in', '(${preferredCategories.join(',')})')
            .filter('id', 'not.in', '(${excludedIds.join(',')})');

        if (recentTipIds.isNotEmpty) {
          query = query.not('id', 'in', '(${recentTipIds.join(',')})');
        }

        final response = await query.limit(remaining * 2);
        
        List<Tip> extraTips = (response as List).map((json) => Tip.fromJson(json)).toList();
        extraTips.shuffle();

        for (var tip in extraTips.take(remaining)) {
          selectedTips.add(tip);
          print('➕ Complété avec : ${tip.title}');
        }
      }

      final excludedIds = selectedTips.map((t) => t.id).toList();
      
      var moreQuery = Supabase.instance.client
          .from('tips')
          .select()
          .eq('is_active', true)
          .filter('category', 'in', '(${preferredCategories.join(',')})')
          .filter('id', 'not.in', '(${excludedIds.join(',')})');

      if (recentTipIds.isNotEmpty) {
        moreQuery = moreQuery.not('id', 'in', '(${recentTipIds.join(',')})');
      }

      final moreResponse = await moreQuery.limit(4);

      List<Tip> moreTips = (moreResponse as List).map((json) => Tip.fromJson(json)).toList();
      moreTips.shuffle();

      for (var tip in moreTips.take(2)) {
        selectedTips.add(tip);
        print('📚 Voir plus : ${tip.title}');
      }

      print('🎯 Total tips retournés : ${selectedTips.length}');
      return selectedTips;

    } catch (e) {
      print('❌ Erreur getRecommendedTips: $e');
      rethrow;
    }
  }

  static Future<Tip?> getTip(int tipId) async {
    try {
      final response = await _client
          .from('tips')
          .select()
          .eq('id', tipId)
          .single();

      return Tip.fromJson(response);
    } catch (e) {
      print('Erreur getTip: $e');
      return null;
    }
  }

  static Future<Tip?> getTipById(int tipId) async {
    try {
      final response = await _client
          .from('tips')
          .select()
          .eq('id', tipId)
          .single();

      return Tip.fromJson(response);
    } catch (e) {
      print('Erreur getTipById: $e');
      return null;
    }
  }

  static Future<List<Tip>> getTips() async {
    try {
      final response = await Supabase.instance.client
          .from('tips')
          .select()
          .eq('is_active', true)
          .order('id', ascending: true);

      return (response as List)
          .map((json) => Tip.fromJson(json))
          .toList();
    } catch (e) {
      print('Erreur getTips: $e');
      return [];
    }
  }

  // ========== TIPS SESSIONS ==========

  static Future<int?> createTipSession({
    required int tipId,
    required int moodLogId,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('Non authentifie');

      final moodLogExists = await _client
          .from('mood_logs')
          .select('id')
          .eq('id', moodLogId)
          .maybeSingle();

      if (moodLogExists == null) {
        print('Erreur: mood_log_id $moodLogId inexistant');
        return null;
      }

      final response = await _client
          .from('tips_sessions')
          .insert({
            'user_id': userId,
            'tip_id': tipId,
            'mood_log_id': moodLogId,
            'started_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return response['id'] as int;
    } catch (e) {
      print('Erreur createTipSession: $e');
      return null;
    }
  }

  static Future<void> completeTipSession({
    required int sessionId,
    required int durationSeconds,
    String? rating,
  }) async {
    try {
      await _client
          .from('tips_sessions')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
            'completed': true,
            'duration_actual_seconds': durationSeconds,
            'rating': rating,
          })
          .eq('id', sessionId);
    } catch (e) {
      print('Erreur completeTipSession: $e');
    }
  }

  static Future<void> updateSession(int sessionId, Map<String, dynamic> updates) async {
    try {
      await _client
          .from('tips_sessions')
          .update(updates)
          .eq('id', sessionId);
    } catch (e) {
      print('❌ Erreur updateSession : $e');
      rethrow;
    }
  }

  static Future<void> updateTipSessionRating({
    required int sessionId,
    required String rating,
  }) async {
    try {
      await _client
          .from('tips_sessions')
          .update({'rating': rating})
          .eq('id', sessionId);
    } catch (e) {
      print('Erreur updateTipSessionRating: $e');
    }
  }

  // ========== STATS ==========

  static Future<void> incrementStats({
    required String category,
    required int duration,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final profile = await getProfile();
      if (profile == null) return;

      await _client
          .from('profiles')
          .update({
            'total_tips_completed': profile.totalTipsCompleted + 1,
          })
          .eq('id', userId);
    } catch (e) {
      print('Erreur incrementStats: $e');
    }
  }
}
