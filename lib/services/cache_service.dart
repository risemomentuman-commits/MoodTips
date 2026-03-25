// lib/services/cache_service.dart
//
// Cache local via Hive — couche d'abstraction simple.
// TTL configurable par clé. Fonctionne offline.
//
// Dépendances pubspec.yaml à ajouter :
//   hive: ^2.2.3
//   hive_flutter: ^1.1.0

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class CacheEntry {
  final String   data;
  final DateTime expiresAt;

  CacheEntry({required this.data, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'data':       data,
    'expires_at': expiresAt.toIso8601String(),
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    data:      json['data']       as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );
}

class CacheService {
  static const _boxName = 'moodtips_cache';
  late Box<String> _box;

  // TTL par défaut par type de donnée
  static const ttlPrediction   = Duration(hours: 6);
  static const ttlPatterns     = Duration(hours: 12);
  static const ttlBaseline     = Duration(hours: 24);
  static const ttlDashboard    = Duration(minutes: 30);
  static const ttlCheckinList  = Duration(hours: 4);

  // ─── INIT ───────────────────────────────────────────────
  Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    await _cleanExpired();
  }

  // ─── ÉCRITURE ───────────────────────────────────────────
  Future<void> set<T>(
    String key,
    T value, {
    Duration ttl = const Duration(hours: 6),
  }) async {
    final entry = CacheEntry(
      data:      json.encode(value),
      expiresAt: DateTime.now().add(ttl),
    );
    await _box.put(key, json.encode(entry.toJson()));
  }

  // ─── LECTURE ────────────────────────────────────────────
  T? get<T>(String key, T Function(dynamic) fromJson) {
    final raw = _box.get(key);
    if (raw == null) return null;

    try {
      final entry = CacheEntry.fromJson(json.decode(raw) as Map<String, dynamic>);
      if (entry.isExpired) {
        _box.delete(key);
        return null;
      }
      return fromJson(json.decode(entry.data));
    } catch (_) {
      _box.delete(key);
      return null;
    }
  }

  // ─── INVALIDATION ───────────────────────────────────────
  Future<void> invalidate(String key) => _box.delete(key);

  Future<void> invalidatePrefix(String prefix) async {
    final keys = _box.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    await _box.deleteAll(keys);
  }

  Future<void> clear() => _box.clear();

  // ─── CLÉS STANDARDISÉES ─────────────────────────────────
  static String prediction(String userId) => 'prediction_$userId';
  static String patterns(String userId)   => 'patterns_$userId';
  static String baseline(String userId)   => 'baseline_$userId';
  static String dashboard(String userId)  => 'dashboard_$userId';
  static String checkins(String userId, String month) => 'checkins_${userId}_$month';
  static String coefficients(String userId) => 'coefficients_$userId';

  // ─── NETTOYAGE AUTOMATIQUE ──────────────────────────────
  Future<void> _cleanExpired() async {
    final expiredKeys = <dynamic>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        final entry = CacheEntry.fromJson(
          json.decode(raw) as Map<String, dynamic>,
        );
        if (entry.isExpired) expiredKeys.add(key);
      } catch (_) {
        expiredKeys.add(key);
      }
    }
    if (expiredKeys.isNotEmpty) await _box.deleteAll(expiredKeys);
  }

  // ─── STATS (pour debug/monitoring) ──────────────────────
  Map<String, dynamic> get stats => {
    'total_keys':   _box.length,
    'box_size_kb':  (_box.keys.fold<int>(
      0,
      (sum, k) => sum + (_box.get(k)?.length ?? 0),
    ) / 1024).toStringAsFixed(1),
  };
}

// ─── SINGLETON GLOBAL ─────────────────────────────────────────
final cacheService = CacheService();