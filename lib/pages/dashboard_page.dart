import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../models/user_profile.dart';
import '../models/mood_log.dart';
import '../models/irm_score_detailed.dart';
import '../widgets/exercise_stats_card.dart';
import '../widgets/badges_summary_widget.dart';
import '../widgets/battery_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/dashboard_cache.dart';
import '../services/irm_calculator_v2.dart';
import '../services/user_learning_service.dart';
import '../services/health_service.dart';
import '../repositories/irm_scores_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../pages/irm_detail_page.dart';
import '../pages/irm_history_page.dart';
import '../services/calendar_service.dart';
import '../widgets/battery_widget.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  UserProfile? _profile;
  List<MoodLog> _recentMoods = [];
  Map<String, dynamic>? _contextInsights;
  Map<String, dynamic>? _exerciseStats;
  bool _isLoading = true;

  IrmScoreDetailed? _irmScore;
  bool _irmLoading = true;
  List<Map<String, dynamic>> _irmHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllData();
    _loadIrmScore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadIrmScore();
    }
  }

  // ══════════════════════════════════════
  // CHARGEMENT DES DONNÉES
  // ══════════════════════════════════════

  Future<void> _loadIrmScore() async {
    setState(() => _irmLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      print('🔍 Dashboard IRM - userId: $userId');
      if (userId == null) return;

      final scoresRepo = IrmScoresRepository();
      final existing = await scoresRepo.getLatestScore(userId);
      print('🔍 Dashboard IRM - score trouvé: ${existing?.score}');

      setState(() {
        _irmScore = existing;
        _irmLoading = false;
      });
    } catch (e) {
      print('❌ Erreur IRM dashboard: $e');
      setState(() => _irmLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchIrmHistory(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('irm_scores_timeline')
          .select('score, date, timestamp')
          .eq('user_id', userId)
          .gte('date', DateTime.now().subtract(Duration(days: 7)).toIso8601String().substring(0, 10))
          .order('timestamp', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Erreur historique IRM: $e');
      return [];
    }
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
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        SupabaseService.getProfile(),
        SupabaseService.getMoodLogs(limit: 7),
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
    } catch (e) {
      print('❌ Erreur dashboard: $e');
    } finally {
      setState(() => _isLoading = false);
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

  // ══════════════════════════════════════
  // BUILD PRINCIPAL
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: _isLoading
            ? _buildSkeletonLoader()
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([_loadAllData(), _loadIrmScore()]);
                },
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(),

                      // Score IRM principal
                      _buildIrmCard(),

                      // Courbe 7 jours
                      if (_irmHistory.length >= 2) _buildTrendChart(),

                      // 4 facteurs rapides
                      if (_irmScore != null) _buildFactorsRow(),

                      // Streak + Humeur
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(child: _buildStreakCard()),
                            SizedBox(width: 12),
                            Expanded(child: _buildMoodCard()),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),

                      // Badges
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: BadgesSummaryWidget(),
                      ),
                      SizedBox(height: 12),

                      // Insight
                      if (_contextInsights != null && (_contextInsights!['total'] as int) > 0)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: _buildKeyInsight(),
                        ),
                      SizedBox(height: 12),

                      // Exercices
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: ExerciseStatsCard(
                          breathingCount: _exerciseStats?['breathing'] ?? 0,
                          movementCount: _exerciseStats?['movement'] ?? 0,
                          mentalCount: _exerciseStats?['mental'] ?? 0,
                          totalMinutes: _exerciseStats?['total_minutes'] ?? 0,
                        ),
                      ),
                      SizedBox(height: 100),
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

  // ══════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour ☀️' : hour < 18 ? 'Bon après-midi 👋' : 'Bonsoir 🌙';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark, size: 20),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                Text(
                  'Ton tableau de bord',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // CARTE IRM PRINCIPALE
  // ══════════════════════════════════════

  Widget _buildIrmCard() {
    if (_irmLoading) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              SizedBox(width: 10),
              Text('Chargement IRM...', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
            ],
          ),
        ),
      );
    }

    if (_irmScore == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GestureDetector(
          onTap: () async {
            await Navigator.pushNamed(context, '/mood-check');
            _loadIrmScore();
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle),
                  child: Center(child: Text('--', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⚡ Énergie Mentale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      Text('Fais ton premier check-in →', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
              ],
            ),
          ),
        ),
      );
    }

    final score = _irmScore!.score;
    final color = _getScoreColor(score);
    final label = score >= 80 ? 'Excellent' : score >= 60 ? 'Bon' : score >= 40 ? 'Moyen' : 'Faible';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IrmDetailPage(score: _irmScore!))),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              BatteryWidget(
                percentage: score,
                width: 50,
                height: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚡ Énergie Mentale · $label',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                    ),
                    Text(
                      '$score/100 · IRM',
                      style: TextStyle(fontSize: 11, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _loadIrmScore,
                child: Icon(Icons.refresh, color: Colors.grey.shade400, size: 18),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // COURBE DE TENDANCE 7 JOURS
  // ══════════════════════════════════════

  Widget _buildTrendChart() {
    // Agréger par jour (moyenne si plusieurs scores/jour)
    final Map<String, List<int>> dailyScores = {};
    for (final entry in _irmHistory) {
      final date = entry['date'] as String;
      final score = entry['score'] as int;
      dailyScores.putIfAbsent(date, () => []).add(score);
    }

    final sortedDays = dailyScores.keys.toList()..sort();
    final spots = <FlSpot>[];
    final labels = <String>[];
    final dayNames = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    for (var i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final scores = dailyScores[day]!;
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      spots.add(FlSpot(i.toDouble(), avg));
      final dt = DateTime.parse(day);
      labels.add(dayNames[dt.weekday - 1]);
    }

    if (spots.length < 2) return SizedBox.shrink();

    final lastScore = spots.last.y.round();
    final firstScore = spots.first.y.round();
    final diff = lastScore - firstScore;
    final trendText = diff >= 0 ? '+$diff pts' : '$diff pts';
    final trendColor = diff >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFF44336);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre + tendance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📈 Évolution 7 jours',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IrmHistoryPage())),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: trendColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trendText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: trendColor),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right, color: AppColors.textLight, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Graphique
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 50,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: TextStyle(color: AppColors.textLight, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) return SizedBox.shrink();
                          final isLast = idx == labels.length - 1;
                          return Text(
                            labels[idx],
                            style: TextStyle(
                              color: isLast ? AppColors.primary : AppColors.textLight,
                              fontSize: 10,
                              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          final isLast = index == spots.length - 1;
                          return FlDotCirclePainter(
                            radius: isLast ? 4 : 2.5,
                            color: isLast ? AppColors.primary : AppColors.primary.withOpacity(0.6),
                            strokeWidth: isLast ? 2 : 0,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(enabled: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // 4 FACTEURS RAPIDES
  // ══════════════════════════════════════

  Widget _buildFactorsRow() {
    final irm = _irmScore!;
    final items = [
      _FactorItem('🛏️', 'Sommeil', irm.sleep.points, irm.sleep.maxPoints),
      _FactorItem('🚶', 'Activité', irm.activity.points, irm.activity.maxPoints),
      _FactorItem('🧠', 'Charge', irm.mentalLoad.points, irm.mentalLoad.maxPoints),
      _FactorItem('💚', 'Stabilité', irm.emotionStability.points, irm.emotionStability.maxPoints),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: items.map((item) {
          final ratio = item.max > 0 ? item.points / item.max : 0.0;
          final color = ratio >= 0.8
              ? const Color(0xFF2E7D32)
              : ratio >= 0.5
                  ? const Color(0xFFFF9800)
                  : const Color(0xFFF44336);

          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 3),
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Text(item.emoji, style: TextStyle(fontSize: 18)),
                  SizedBox(height: 4),
                  Text(
                    '${item.points}/${item.max}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  ),
                  SizedBox(height: 2),
                  Text(item.label, style: TextStyle(fontSize: 9, color: AppColors.textMedium)),
                  SizedBox(height: 4),
                  // Mini barre de progression
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════
  // STREAK CARD
  // ══════════════════════════════════════

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

  // ══════════════════════════════════════
  // MOOD CARD
  // ══════════════════════════════════════

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

  // ══════════════════════════════════════
  // KEY INSIGHT
  // ══════════════════════════════════════

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
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.success.withOpacity(0.12) : AppColors.error.withOpacity(0.12),
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
                Text(
                  isPositive ? '💡 Insight' : '⚠️ Attention',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMedium),
                ),
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

  // ══════════════════════════════════════
  // SKELETON LOADER
  // ══════════════════════════════════════

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(height: 20),
          Container(height: 80, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(20))),
          SizedBox(height: 12),
          Container(height: 160, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(16))),
          SizedBox(height: 12),
          Container(height: 60, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12))),
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

  // ══════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF2E7D32);
    if (score >= 60) return const Color(0xFF4CAF50);
    if (score >= 40) return const Color(0xFFFF9800);
    if (score >= 20) return const Color(0xFFF44336);
    return const Color(0xFFB71C1C);
  }

  String? _getMostFrequent(Map<String, int> map) {
    if (map.isEmpty) return null;
    var entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}

class _FactorItem {
  final String emoji;
  final String label;
  final int points;
  final int max;
  _FactorItem(this.emoji, this.label, this.points, this.max);
}