// lib/services/dashboard_data_service.dart
//
// Service centralisé pour les données du dashboard.
// Implémente :
//   • Cache-first via CacheService (Hive)
//   • Lazy loading de l'historique (pagination 30j)
//   • Batching des requêtes Supabase (réduit les N+1)
//
// Stratégie de chargement :
//   1. Retourner immédiatement depuis le cache si valide
//   2. Refresh en arrière-plan si cache > 50% du TTL
//   3. Network si cache absent ou expiré

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prediction.dart';
import '../models/detected_pattern.dart';
import 'cache_service.dart';
import 'user_learning_ml_service.dart';

class DashboardSnapshot {
  final double?          todayScore;
  final Prediction?      tomorrowPrediction;
  final IrmBaseline?     baseline;
  final List<DetectedPattern> topPatterns;
  final List<Map<String, dynamic>> recentCheckins; // 7 derniers jours
  final DateTime         loadedAt;

  const DashboardSnapshot({
    this.todayScore,
    this.tomorrowPrediction,
    this.baseline,
    required this.topPatterns,
    required this.recentCheckins,
    required this.loadedAt,
  });
}

class CheckinPage {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final String? nextCursor; // date ISO du dernier item

  const CheckinPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });
}

class DashboardDataService {
  final SupabaseClient        _supabase;
  final CacheService          _cache;
  final UserLearningService   _learning;

  static const int _pageSize = 30; // Jours par page d'historique

  DashboardDataService({
    SupabaseClient? supabase,
    CacheService? cache,
    UserLearningService? learning,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _cache    = cache    ?? cacheService,
        _learning = learning ?? UserLearningService();

  // ─── SNAPSHOT DASHBOARD ────────────────────────────────────
  /// Charge le snapshot complet en une seule passe (batching).
  /// Stratégie : cache-first → background refresh.
  Future<DashboardSnapshot> loadDashboardSnapshot({
    bool forceRefresh = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utilisateur non connecté');

    // Cache hit
    if (!forceRefresh) {
      final cached = _cache.get<Map<String, dynamic>>(
        CacheService.dashboard(userId),
        (data) => data as Map<String, dynamic>,
      );
      if (cached != null) {
        _scheduleBackgroundRefresh(userId);
        return _snapshotFromCache(cached);
      }
    }

    return _fetchAndCacheSnapshot(userId);
  }

  Future<DashboardSnapshot> _fetchAndCacheSnapshot(String userId) async {
    // Batch : tout en parallèle
    final results = await Future.wait([
      _fetchTodayCheckin(userId),
      _fetchRecentCheckins(userId, 7),
      _supabase
          .from('predictions')
          .select()
          .eq('user_id', userId)
          .gte('predicted_date', DateTime.now().toIso8601String().substring(0, 10))
          .order('predicted_date')
          .limit(1),
      _supabase
          .from('detected_patterns')
          .select()
          .eq('user_id', userId)
          .order('confidence', ascending: false)
          .limit(5),
    ]);

    final todayCheckin = results[0] as Map<String, dynamic>?;
    final recentCheckins = results[1] as List<Map<String, dynamic>>;
    final predictionsRaw = results[2] as List<dynamic>;
    final patternsRaw    = results[3] as List<dynamic>;

    final prediction = predictionsRaw.isNotEmpty
        ? Prediction.fromJson(predictionsRaw.first as Map<String, dynamic>)
        : null;

    final patterns = patternsRaw
        .map((p) => DetectedPattern.fromJson(p as Map<String, dynamic>))
        .toList();

    final baseline = await _learning.getLatestBaseline();

    final snapshot = DashboardSnapshot(
      todayScore:         (todayCheckin?['irm_score'] as num?)?.toDouble(),
      tomorrowPrediction: prediction,
      baseline:           baseline,
      topPatterns:        patterns,
      recentCheckins:     recentCheckins,
      loadedAt:           DateTime.now(),
    );

    // Mettre en cache
    await _cache.set(
      CacheService.dashboard(userId),
      _snapshotToCache(snapshot),
      ttl: CacheService.ttlDashboard,
    );

    return snapshot;
  }

  // ─── HISTORIQUE PAGINÉ ─────────────────────────────────────
  /// Charge l'historique des check-ins page par page.
  /// À utiliser avec un InfiniteScrollController.
  // Remplace tout le bloc de requête dans loadCheckinsPage() par :
  Future<CheckinPage> loadCheckinsPage({
    String? beforeDate,
    int pageSize = _pageSize,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const CheckinPage(items: [], hasMore: false);

    var query = _supabase
        .from('daily_checkins')
        .select(
          'checkin_date, irm_score, sleep_hours, activity_minutes, '
          'mental_load_events, mood_raw, selected_actions',
        )
        .eq('user_id', userId)
        .order('checkin_date', ascending: false);

    // Filtre beforeDate AVANT limit
    if (beforeDate != null) {
      final response = List<Map<String, dynamic>>.from(
        await _supabase
            .from('daily_checkins')
            .select('checkin_date, irm_score, sleep_hours, activity_minutes, mental_load_events, mood_raw, selected_actions')
            .eq('user_id', userId)
            .lte('checkin_date', beforeDate!)
            .order('checkin_date', ascending: false)
            .limit(pageSize),
      );
    }

    final response = List<Map<String, dynamic>>.from(
      await query.limit(pageSize),
    );

    return CheckinPage(
      items:      response,
      hasMore:    response.length >= pageSize,
      nextCursor: response.isNotEmpty ? response.last['checkin_date'] as String? : null,
    );
  }

  // ─── INVALIDATION POST CHECK-IN ─────────────────────────────
  /// À appeler après chaque check-in pour invalider le cache.
  Future<void> invalidateAfterCheckin() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await Future.wait([
      _cache.invalidate(CacheService.dashboard(userId)),
      _cache.invalidate(CacheService.prediction(userId)),
      _cache.invalidate(CacheService.baseline(userId)),
    ]);
  }

  // ─── HELPERS ───────────────────────────────────────────────
  Future<Map<String, dynamic>?> _fetchTodayCheckin(String userId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await _supabase
        .from('daily_checkins')
        .select('irm_score, sleep_hours, mental_load_events')
        .eq('user_id', userId)
        .eq('checkin_date', today)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> _fetchRecentCheckins(
    String userId, int days,
  ) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);
    final response = await _supabase
        .from('daily_checkins')
        .select('checkin_date, irm_score')
        .eq('user_id', userId)
        .gte('checkin_date', since)
        .order('checkin_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  void _scheduleBackgroundRefresh(String userId) {
    // Refresh silencieux sans bloquer l'UI
    Future.microtask(() => _fetchAndCacheSnapshot(userId));
  }

  Map<String, dynamic> _snapshotToCache(DashboardSnapshot s) => {
    'today_score':    s.todayScore,
    'recent_checkins': s.recentCheckins,
    'patterns':       s.topPatterns.map((p) => p.toJson()).toList(),
    'loaded_at':      s.loadedAt.toIso8601String(),
  };

  DashboardSnapshot _snapshotFromCache(Map<String, dynamic> data) {
    final patternsRaw = data['patterns'] as List<dynamic>? ?? [];
    return DashboardSnapshot(
      todayScore:    (data['today_score'] as num?)?.toDouble(),
      topPatterns:   patternsRaw
          .map((p) => DetectedPattern.fromJson(p as Map<String, dynamic>))
          .toList(),
      recentCheckins: List<Map<String, dynamic>>.from(
        (data['recent_checkins'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>(),
      ),
      loadedAt: DateTime.parse(data['loaded_at'] as String),
    );
  }
}