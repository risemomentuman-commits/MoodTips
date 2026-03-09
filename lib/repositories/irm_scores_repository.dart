import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/irm_score_detailed.dart';

class IrmScoresRepository {
  final SupabaseClient _client;

  IrmScoresRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<void> saveScore({
    required String userId,
    required IrmScoreDetailed score,
    required String triggeredBy,
  }) async {
    final data = score.toJsonForDb();
    data['user_id'] = userId;
    data['date'] = DateTime.now().toIso8601String().substring(0, 10);
    data['triggered_by'] = triggeredBy;
    data['timestamp'] = DateTime.now().toIso8601String();
    await _client.from('irm_scores_timeline').insert(data);
  }

  Future<IrmScoreDetailed?> getLatestScore(String userId) async {
    print('🔍 getLatestScore query for userId: $userId');
    try {
      final response = await _client
          .from('irm_scores_timeline')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();
      print('🔍 getLatestScore raw response: $response');
      if (response == null) return null;
      return IrmScoreDetailed.fromJson(response);
    } catch (e) {
      print('❌ getLatestScore ERROR: $e');
      return null;
    }
  }

  Future<List<IrmScoreDetailed>> getScoresForDate(
    String userId,
    DateTime date,
  ) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final response = await _client
        .from('irm_scores_timeline')
        .select()
        .eq('user_id', userId)
        .eq('date', dateStr)
        .order('timestamp', ascending: true);
    return (response as List)
        .map((e) => IrmScoreDetailed.fromJson(e))
        .toList();
  }

  Future<List<IrmScoreDetailed>> getScoresForPeriod(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);
    final response = await _client
        .from('irm_scores_timeline')
        .select()
        .eq('user_id', userId)
        .gte('date', startStr)
        .lte('date', endStr)
        .order('timestamp', ascending: true);
    return (response as List)
        .map((e) => IrmScoreDetailed.fromJson(e))
        .toList();
  }

  /// Score moyen par jour sur une période (pour les courbes)
  Future<Map<String, double>> getDailyAverages(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final scores = await getScoresForPeriod(userId, start, end);
    final Map<String, List<int>> grouped = {};
    for (final s in scores) {
      final dateKey = s.timestamp.toIso8601String().substring(0, 10);
      grouped.putIfAbsent(dateKey, () => []).add(s.score);
    }
    return grouped.map((date, values) =>
        MapEntry(date, values.reduce((a, b) => a + b) / values.length));
  }
}