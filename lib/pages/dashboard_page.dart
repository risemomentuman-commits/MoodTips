import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../models/user_profile.dart';
import '../models/mood_log.dart';
import '../widgets/exercise_stats_card.dart';
import '../widgets/badges_summary_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Ajouter cette ligne

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  UserProfile? _profile;
  List<MoodLog> _recentMoods = [];
  Map<String, dynamic>? _contextInsights;
  Map<String, dynamic>? _exerciseStats;
  bool _isLoading = true;
  String _period = '7';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadExerciseStats() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Exemple : compter les tips complétés par catégorie cette semaine
      final oneWeekAgo = DateTime.now().subtract(Duration(days: 7));
      
      final response = await Supabase.instance.client
          .from('user_tips')
          .select('tip_id')
          .eq('user_id', userId)
          .eq('status', 'completed')
          .gte('completed_at', oneWeekAgo.toIso8601String());

      // Tu peux ensuite compter par catégorie
      // Ceci est un exemple simplifié
      setState(() {
        _exerciseStats = {
          'breathing': 5,
          'movement': 3,
          'mental': 2,
          'total_minutes': 45,
        };
      });
    } catch (e) {
      print('Erreur chargement stats exercices: $e');
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    final stopwatch = Stopwatch()..start(); // ✅ Mesurer le temps
    
    try {
      // ✅ CHARGER TOUT EN PARALLÈLE avec Future.wait
      final results = await Future.wait([
        SupabaseService.getProfile(),
        SupabaseService.getMoodLogs(limit: int.parse(_period)),
        SupabaseService.getContextInsights(),
        _fetchExerciseStats(),
      ]);
      
      setState(() {
        _profile = results[0] as UserProfile?;
        _recentMoods = results[1] as List<MoodLog>;
        _contextInsights = results[2] as Map<String, dynamic>?;
        _exerciseStats = results[3] as Map<String, dynamic>?;
      });
    } catch (e) {
      print('Erreur chargement dashboard: $e');
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
          .from('user_tips')
          .select('tip_id')
          .eq('user_id', userId)
          .eq('status', 'completed')
          .gte('completed_at', oneWeekAgo.toIso8601String());

      return {
        'breathing': 5,
        'movement': 3,
        'mental': 2,
        'total_minutes': 45,
      };
    } catch (e) {
      print('Erreur stats exercices: $e');
      return null;
    }
  }

  
  double get _averageMood {
    if (_recentMoods.isEmpty) return 0;
    final sum = _recentMoods.fold(0.0, (sum, log) => sum + log.emotionId);
    return sum / _recentMoods.length;
  }

  String get _moodStatus {
    final avg = _averageMood;
    if (_recentMoods.isEmpty) return "Commence ton suivi";
    if (avg >= 7) return "Tu te sens bien";
    if (avg >= 4) return "Mitigé, à surveiller";
    return "Priorité au bien-être";
  }

  IconData get _moodIcon {
    final avg = _averageMood;
    if (_recentMoods.isEmpty) return Icons.favorite_outline;
    if (avg >= 7) return Icons.sentiment_very_satisfied;
    if (avg >= 4) return Icons.sentiment_neutral;
    return Icons.sentiment_dissatisfied;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: _isLoading
          ? _buildSkeletonLoader() // ✅ Skeleton au lieu du spinner
          : RefreshIndicator(
                onRefresh: _loadAllData,  // ✅ _loadAllData au lieu de _loadData
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'Dashboard',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      _buildHeroCard(),
                      SizedBox(height: 16),
                      BadgesSummaryWidget(),
                      SizedBox(height: 16),
                      if (_contextInsights != null && (_contextInsights!['total'] as int) > 0)
                        _buildKeyInsight(),
                      if (_contextInsights != null && (_contextInsights!['total'] as int) > 0)
                        SizedBox(height: 16),
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

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              SizedBox(width: 12),
              Container(
                width: 150,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          // Hero card skeleton
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Badges skeleton
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Exercise stats skeleton
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.streakGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_fire_department, color: Colors.white, size: 28),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_profile?.currentStreak ?? 0} jours',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'de suite',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withOpacity(0.3)),
          SizedBox(height: 24),
          Row(
            children: [
              Icon(_moodIcon, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _moodStatus,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (_recentMoods.isNotEmpty)
                      Text(
                        '${_averageMood.toStringAsFixed(1)}/10 sur ${_period}j',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

    String? bestLocation = _getMostFrequent(positiveLocations);
    String? worstLocation = _getMostFrequent(negativeLocations);

    final contextLabels = {
      'home': '🏠 la maison',
      'work': '💼 au travail',
      'transport': '🚗 en transport',
      'outdoor': '🌳 dehors',
      'public': '🏬 lieux publics',
    };

    if (bestLocation == null && worstLocation == null) return SizedBox.shrink();

    final showPositive = bestLocation != null;
    final location = showPositive ? bestLocation : worstLocation;
    final isPositive = showPositive;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.streakGradient.colors[0].withOpacity(0.15),
            AppColors.streakGradient.colors[1].withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.lightbulb : Icons.warning_amber,
              color: isPositive ? AppColors.success : AppColors.error,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? '💡 Insight' : '⚠️ Attention',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMedium,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isPositive
                      ? 'Tu te sens mieux ${contextLabels[location] ?? location}'
                      : 'Moins bien ${contextLabels[location] ?? location}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getMostFrequent(Map<String, int> map) {
    if (map.isEmpty) return null;
    var entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }
}
