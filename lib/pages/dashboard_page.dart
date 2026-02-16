import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/irm_service.dart';
import '../utils/app_colors.dart';
import '../models/user_profile.dart';
import '../models/mood_log.dart';
import '../widgets/exercise_stats_card.dart';
import '../widgets/badges_summary_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/dashboard_cache.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  UserProfile? _profile;
  List<MoodLog> _recentMoods = [];
  Map<String, dynamic>? _contextInsights;
  Map<String, dynamic>? _exerciseStats;
  IRMResult? _irmResult;
  List<Map<String, dynamic>> _irmHistory = [];
  bool _isLoading = true;
  String _period = '7';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (DashboardCache.isValid) {
      setState(() {
        _profile = DashboardCache.profile;
        _recentMoods = DashboardCache.recentMoods ?? [];
        _contextInsights = DashboardCache.contextInsights;
        _exerciseStats = DashboardCache.exerciseStats;
        _isLoading = false;
      });
      _loadIRM();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        SupabaseService.getProfile(),
        SupabaseService.getMoodLogs(limit: int.parse(_period)),
        SupabaseService.getContextInsights(),
        _fetchExerciseStats(),
      ]);

      DashboardCache.update(
        newProfile: results[0] as UserProfile?,
        newMoods: results[1] as List<MoodLog>,
        newContexts: results[2] as Map<String, dynamic>?,
        newStats: results[3] as Map<String, dynamic>?,
      );

      setState(() {
        _profile = results[0] as UserProfile?;
        _recentMoods = results[1] as List<MoodLog>;
        _contextInsights = results[2] as Map<String, dynamic>?;
        _exerciseStats = results[3] as Map<String, dynamic>?;
      });

      await _loadIRM();
    } catch (e) {
      print('❌ Erreur dashboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadIRM() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // ✅ Lire le dernier score depuis Supabase au lieu de recalculer
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from('irm_scores')
          .select('score, zone, date')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      final history = await _fetchIRMHistory();

      if (response != null) {
        final zone = IRMZone.values.firstWhere(
          (z) => z.name == response['zone'],
          orElse: () => IRMZone.stable,
        );
        setState(() {
          _irmResult = IRMResult(
            score: response['score'] as int,
            zone: zone,
            factors: [],
            recommendation: _getRecommendationForZone(zone),
            protocol: _getProtocolForZone(zone),
            notificationMessage: '',
            sleepSource: SleepDataSource.unknown,
            calculatedAt: DateTime.now(),
          );
          _irmHistory = history;
        });
      } else {
        // Pas de score aujourd'hui → on calcule
        final irm = await IRMService.calculateScore();
        setState(() {
          _irmResult = irm;
          _irmHistory = history;
        });
      }
    } catch (e) {
      print('❌ Erreur IRM dashboard: $e');
      // Fallback : calcul normal
      try {
        final irm = await IRMService.calculateScore();
        setState(() => _irmResult = irm);
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> _fetchIRMHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];
      final response = await Supabase.instance.client
          .from('irm_scores')
          .select('score, zone, date')
          .eq('user_id', userId)
          .gte('date', DateTime.now().subtract(Duration(days: 7)).toIso8601String().substring(0, 10))
          .order('date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _fetchExerciseStats() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return null;
      final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
      final response = await Supabase.instance.client
          .from('tips_sessions')
          .select('duration_actual_seconds, tips(category)')
          .eq('user_id', userId)
          .eq('completed', true)
          .gte('completed_at', oneWeekAgo.toIso8601String());

      int breathing = 0, movement = 0, mental = 0, totalSeconds = 0;
      for (var item in response as List) {
        final category = item['tips']?['category'];
        final duration = item['duration_actual_seconds'] ?? 0;
        if (category == 'respiration') breathing++;
        if (category == 'mouvement') movement++;
        if (category == 'mental') mental++;
        totalSeconds += duration as int;
      }
      return {
        'breathing': breathing,
        'movement': movement,
        'mental': mental,
        'total_minutes': (totalSeconds / 60).round(),
      };
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: _isLoading
            ? _buildSkeletonLoader()
            : RefreshIndicator(
                onRefresh: _loadAllData,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'Dashboard',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // 1. IRM HERO CARD
                      _buildIRMHeroCard(),
                      SizedBox(height: 12),

                      // 2. TENDANCE 7 JOURS
                      if (_irmHistory.isNotEmpty) ...[
                        _buildIRMTrend(),
                        SizedBox(height: 12),
                      ],

                      // 3. FACTEURS IRM
                      if (_irmResult != null && _irmResult!.factors.isNotEmpty) ...[
                        _buildIRMFactors(),
                        SizedBox(height: 12),
                      ],

                      // 4. STREAK + BADGES
                      Row(
                        children: [
                          Expanded(child: _buildStreakCard()),
                          SizedBox(width: 12),
                          Expanded(child: _buildMoodCard()),
                        ],
                      ),
                      SizedBox(height: 12),

                      // 5. BADGES
                      BadgesSummaryWidget(),
                      SizedBox(height: 12),

                      // 6. INSIGHT
                      if (_contextInsights != null && (_contextInsights!['total'] as int) > 0) ...[
                        _buildKeyInsight(),
                        SizedBox(height: 12),
                      ],

                      // 7. EXERCICES
                      ExerciseStatsCard(
                        breathingCount: _exerciseStats?['breathing'] ?? 0,
                        movementCount: _exerciseStats?['movement'] ?? 0,
                        mentalCount: _exerciseStats?['mental'] ?? 0,
                        totalMinutes: _exerciseStats?['total_minutes'] ?? 0,
                      ),
                      SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/moodCheck'),
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.favorite, color: Colors.white),
        label: Text('Check-in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── IRM HERO CARD ──
  Widget _buildIRMHeroCard() {
    if (_irmResult == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      );
    }

    final irm = _irmResult!;
    final zoneColor = irm.zone == IRMZone.stable
        ? AppColors.primary
        : irm.zone == IRMZone.pressure
            ? AppColors.warning
            : AppColors.error;


    String trendText = '';
    if (_irmHistory.length >= 2) {
      final today = irm.score;
      final yesterday = (_irmHistory[_irmHistory.length - 2]['score'] as int?) ?? today;
      final diff = today - yesterday;
      trendText = diff >= 0 ? '▲ +$diff pts vs hier' : '▼ $diff pts vs hier';
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: zoneColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${irm.score}',
                      style: TextStyle(color: zoneColor, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(color: zoneColor.withOpacity(0.7), fontSize: 10),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${irm.zoneEmoji} ${irm.zoneLabel}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: zoneColor),
                    ),
                    Text(
                      'IRM · Indice de Régulation Mentale',
                      style: TextStyle(fontSize: 11, color: AppColors.textLight),
                    ),
                    SizedBox(height: 4),
                    Text(
                      irm.zoneDescription,
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                    if (trendText.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(trendText, style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: irm.score / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(zoneColor),
              minHeight: 6,
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔴 0', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              Text('🟠 40', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              Text('🔵 70', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              Text('100', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
            ],
          ),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: zoneColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              irm.protocol,
              style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── TENDANCE 7 JOURS ──
  Widget _buildIRMTrend() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📊 IRM · Tendance 7 jours', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _buildSparkline(),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _buildDayLabels(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSparkline() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final dateStr = date.toIso8601String().substring(0, 10);
      final entry = _irmHistory.firstWhere(
        (h) => h['date'] == dateStr,
        orElse: () => {},
      );
      final score = entry.isNotEmpty ? (entry['score'] as int) : null;
      final isToday = i == 6;

      // Cas : pas de données
      if (score == null) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(height: 13),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Variables déclarées AVANT utilisation
      final barHeight = (score / 100 * 50).clamp(4.0, 50.0);
      final color = score >= 70
          ? AppColors.primary
          : score >= 40
              ? AppColors.warning
              : AppColors.error;

      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isToday)
                Text(
                  '$score',
                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                )
              else
                SizedBox(height: 13),
              Container(
                height: barHeight,
                decoration: BoxDecoration(
                  color: isToday ? color : color.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  List<Widget> _buildDayLabels() {
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final dayIndex = date.weekday - 1;
      final isToday = i == 6;
      return Expanded(
        child: Text(
          days[dayIndex],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: isToday ? AppColors.primary : AppColors.textLight,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    });
  }

  // ── FACTEURS IRM ──
  Widget _buildIRMFactors() {
    final factors = _irmResult!.factors.where((f) => f.impact < 0).take(3).toList();
    if (factors.isEmpty) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⚠️ Facteurs détectés aujourd\'hui', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          SizedBox(height: 10),
          ...factors.map((f) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(f.emoji, style: TextStyle(fontSize: 16)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      Text(f.description, style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: f.impact < -10 
                        ? AppColors.error.withOpacity(0.12)
                        : AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${f.impact > 0 ? '+' : ''}${f.impact} pts',
                    style: TextStyle(
                      fontSize: 11,
                      color: f.impact < -10 ? AppColors.error : AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── STREAK CARD ──
  Widget _buildStreakCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.streakGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department, color: Colors.white, size: 24),
          SizedBox(height: 8),
          Text(
            '${_profile?.currentStreak ?? 0}',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text('jours de suite', style: TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  // ── MOOD CARD ──
  Widget _buildMoodCard() {
    final avg = _recentMoods.isEmpty
        ? 0.0
        : _recentMoods.fold(0.0, (s, l) => s + l.emotionId) / _recentMoods.length;

    final color = avg >= 7 ? AppColors.success : avg >= 4 ? AppColors.warning : AppColors.error;
    final emoji = avg >= 7 ? '😊' : avg >= 4 ? '😐' : '😔';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text(
            _recentMoods.isEmpty ? '-' : '${avg.toStringAsFixed(1)}/10',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          Text('humeur moy. 7j', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
      ),
    );
  }

  // ── KEY INSIGHT ──
  Widget _buildKeyInsight() {
    final data = _contextInsights!['data'] as List;
    final Map<String, int> positiveLocations = {};
    final Map<String, int> negativeLocations = {};

    for (var item in data) {
      final location = item['location'] as String;
      final emotionType = item['emotion_type'] as String;
      if (emotionType == 'positive') {
        positiveLocations[location] = (positiveLocations[location] ?? 0) + 1;
      } else {
        negativeLocations[location] = (negativeLocations[location] ?? 0) + 1;
      }
    }

    final bestLocation = _getMostFrequent(positiveLocations);
    final worstLocation = _getMostFrequent(negativeLocations);
    if (bestLocation == null && worstLocation == null) return SizedBox.shrink();

    final contextLabels = {
      'home': '🏠 la maison',
      'work': '💼 au travail',
      'transport': '🚗 en transport',
      'outdoor': '🌳 dehors',
      'public': '🏬 lieux publics',
    };

    final isPositive = bestLocation != null;
    final location = isPositive ? bestLocation : worstLocation;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.lightbulb : Icons.warning_amber,
              color: isPositive ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isPositive ? '💡 Insight' : '⚠️ Attention',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMedium)),
                SizedBox(height: 2),
                Text(
                  isPositive
                      ? 'Tu te sens mieux ${contextLabels[location] ?? location}'
                      : 'Moins bien ${contextLabels[location] ?? location}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SKELETON ──
  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Container(height: 200, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(20))),
          SizedBox(height: 12),
          Container(height: 90, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16))),
          SizedBox(height: 12),
          Container(height: 120, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16))),
          SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16)))),
            SizedBox(width: 12),
            Expanded(child: Container(height: 90, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16)))),
          ]),
        ],
      ),
    );
  }

  String? _getMostFrequent(Map<String, int> map) {
    if (map.isEmpty) return null;
    var entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  String _getRecommendationForZone(IRMZone zone) {
    switch (zone) {
      case IRMZone.stable: return 'Continue comme ça 🌟';
      case IRMZone.pressure: return 'Prends soin de toi aujourd\'hui';
      case IRMZone.danger: return 'Pause et récupération recommandées';
    }
  }

  String _getProtocolForZone(IRMZone zone) {
    switch (zone) {
      case IRMZone.stable: return 'Maintien';
      case IRMZone.pressure: return 'Récupération légère';
      case IRMZone.danger: return 'Récupération intensive';
    }
  }
}