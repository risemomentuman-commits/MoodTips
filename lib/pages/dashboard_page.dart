import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../models/user_profile.dart';
import '../models/mood_log.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  UserProfile? _profile;
  List<MoodLog> _recentMoods = [];
  Map<String, dynamic>? _contextInsights;
  bool _isLoading = true;
  String _period = '7'; // 7 ou 30 jours

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final profile = await SupabaseService.getProfile();
      final moods = await SupabaseService.getMoodLogs(
        limit: int.parse(_period),
      );
      final contexts = await SupabaseService.getContextInsights();

      setState(() {
        _profile = profile;
        _recentMoods = moods;
        _contextInsights = contexts;
      });
    } catch (e) {
      print('Erreur chargement dashboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double get _averageMood {
    if (_recentMoods.isEmpty) return 0;
    final sum = _recentMoods.fold(0.0, (sum, log) => sum + log.emotionId);
    return sum / _recentMoods.length;
  }

  String get _moodTrend {
    if (_recentMoods.length < 2) return '→';
    final recent = _recentMoods.take(3).fold(0.0, (s, l) => s + l.emotionId) / 3;
    final old = _recentMoods.skip(3).take(3).fold(0.0, (s, l) => s + l.emotionId) / 3;
    if (recent > old) return '↗️';
    if (recent < old) return '↘️';
    return '→';
  }

  // ✅ NOUVEAU : Helper pour récupérer les catégories
  List<String> get _userCategories {
    if (_profile?.preferences == null) return [];
    final categories = _profile!.preferences!['categories'];
    if (categories == null) return [];
    return List<String>.from(categories);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.08),
              AppColors.secondary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header avec bouton retour
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'Mon Tableau de Bord',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            // Sélecteur période
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _period,
                                  isDense: true,
                                  items: [
                                    DropdownMenuItem(value: '7', child: Text('7j')),
                                    DropdownMenuItem(value: '30', child: Text('30j')),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _period = value!);
                                    _loadData();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Insights contexte
                        if (_contextInsights != null && (_contextInsights!['total'] as int) > 0)
                          _buildContextInsights(),

                        SizedBox(height: 20),

                        // Graphique humeur
                        _buildMoodChart(),

                        SizedBox(height: 20),

                        // Cards stats
                        _buildStatsCards(),

                        SizedBox(height: 20),

                        // Catégories préférées
                        if (_profile != null && _userCategories.isNotEmpty)
                          _buildCategoriesSection(),

                        SizedBox(height: 20),

                        // Objectifs
                        if (_profile != null && _profile!.mainGoals.isNotEmpty)
                          _buildGoalsSection(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ========== WIDGETS ==========

  Widget _buildContextInsights() {
    final data = _contextInsights!['data'] as List;
    
    final Map<String, Map<String, int>> positiveContexts = {
      'location': {},
      'company': {},
      'time': {},
      'activity': {},
    };
    final Map<String, Map<String, int>> negativeContexts = {
      'location': {},
      'company': {},
      'time': {},
      'activity': {},
    };

    for (var item in data) {
      final location = item['location'] as String;
      final company = item['company'] as String;
      final timeOfDay = item['time_of_day'] as String;
      final activity = item['activity'] as String;
      final emotionType = item['emotion_type'] as String;
      
      if (emotionType == 'positive') {
        positiveContexts['location']![location] = (positiveContexts['location']![location] ?? 0) + 1;
        positiveContexts['company']![company] = (positiveContexts['company']![company] ?? 0) + 1;
        positiveContexts['time']![timeOfDay] = (positiveContexts['time']![timeOfDay] ?? 0) + 1;
        positiveContexts['activity']![activity] = (positiveContexts['activity']![activity] ?? 0) + 1;
      } else {
        negativeContexts['location']![location] = (negativeContexts['location']![location] ?? 0) + 1;
        negativeContexts['company']![company] = (negativeContexts['company']![company] ?? 0) + 1;
        negativeContexts['time']![timeOfDay] = (negativeContexts['time']![timeOfDay] ?? 0) + 1;
        negativeContexts['activity']![activity] = (negativeContexts['activity']![activity] ?? 0) + 1;
      }
    }

    String? bestLocation = _getMostFrequent(positiveContexts['location']!);
    String? worstLocation = _getMostFrequent(negativeContexts['location']!);
    String? bestCompany = _getMostFrequent(positiveContexts['company']!);
    String? worstCompany = _getMostFrequent(negativeContexts['company']!);

    final contextLabels = {
      'home': '🏠 la maison',
      'work': '💼 au travail',
      'transport': '🚗 en transport',
      'outdoor': '🏃 dehors',
      'public': '🏬 dans un lieu public',
      'school': '🏫 à l\'école',
      'medical': '🏥 en contexte médical',
      'alone': '🧘 seul(e)',
      'family': '👨‍👩‍👧 avec ta famille',
      'children': '👶 avec des enfants',
      'friends': '👫 avec tes amis',
      'colleagues': '💼 avec tes collègues',
      'partner': '💑 avec ton/ta partenaire',
      'strangers': '👥 avec des inconnus',
    };

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: AppColors.primary, size: 28),
              SizedBox(width: 12),
              Text(
                'Tes insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Contextes positifs
          if (bestLocation != null || bestCompany != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sentiment_satisfied_alt, color: AppColors.success, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tu te sens bien',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (bestLocation != null)
                    Text(
                      '${contextLabels[bestLocation] ?? bestLocation}',
                      style: TextStyle(fontSize: 15, color: AppColors.textDark),
                    ),
                  if (bestCompany != null)
                    Text(
                      '${contextLabels[bestCompany] ?? bestCompany}',
                      style: TextStyle(fontSize: 15, color: AppColors.textDark),
                    ),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],

          // Contextes négatifs
          if (worstLocation != null || worstCompany != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Attention à',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (worstLocation != null)
                    Text(
                      '${contextLabels[worstLocation] ?? worstLocation}',
                      style: TextStyle(fontSize: 15, color: AppColors.textDark),
                    ),
                  if (worstCompany != null)
                    Text(
                      '${contextLabels[worstCompany] ?? worstCompany}',
                      style: TextStyle(fontSize: 15, color: AppColors.textDark),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _getMostFrequent(Map<String, int> map) {
    if (map.isEmpty) return null;
    var entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  Widget _buildMoodChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Évolution de l\'humeur',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      'Tendance ',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                    Text(
                      _moodTrend,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _recentMoods.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Aucune donnée pour le moment\nCommence par enregistrer ton humeur ! 💜',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMedium),
                    ),
                  ),
                )
              : Container(
                  height: 220,
                  padding: EdgeInsets.only(right: 16, top: 16, bottom: 16), // ✅ Ajout bottom
                  clipBehavior: Clip.hardEdge, // ✅ NOUVEAU : Empêche le débordement
                  decoration: BoxDecoration(),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: AppColors.textLight.withOpacity(0.1),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= _recentMoods.length) return Text('');
                              final mood = _recentMoods[value.toInt()];
                              final date = mood.createdAt;
                              return Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  '${date.day}/${date.month}',
                                  style: TextStyle(fontSize: 10, color: AppColors.textMedium),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (_recentMoods.length - 1).toDouble(),
                      minY: 0,
                      maxY: 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _recentMoods
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value.emotionId.toDouble()))
                              .toList(),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          gradient: AppColors.primaryGradient,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: AppColors.primary,
                                strokeWidth: 2,
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
                                AppColors.primary.withOpacity(0.2),
                                AppColors.primary.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_fire_department,
            value: '${_profile?.currentStreak ?? 0}',
            label: 'Jours de suite',
            color: Colors.orange,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline,
            value: '${_profile?.totalTipsCompleted ?? 0}',
            label: 'Tips complétés',
            color: AppColors.success,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.sentiment_satisfied_alt,
            value: _averageMood.toStringAsFixed(1),
            label: 'Humeur moy.',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = {
      'respiration': {'emoji': '🫁', 'label': 'Respiration', 'color': AppColors.categories['respiration']!},
      'mouvement': {'emoji': '🏃', 'label': 'Mouvement', 'color': AppColors.categories['mouvement']!},
      'mental': {'emoji': '🧠', 'label': 'Mental', 'color': AppColors.categories['mental']!},
      'musique': {'emoji': '🎵', 'label': 'Musique', 'color': AppColors.categories['musique']!},
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes catégories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _userCategories.map((cat) {  // ✅ CORRIGÉ : Utilise _userCategories
            final info = categories[cat];
            if (info == null) return SizedBox.shrink();
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (info['color'] as Color).withOpacity(0.3), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(info['emoji'] as String, style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    info['label'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGoalsSection() {
    final goals = {
      'reduce_stress': {'label': 'Réduire le stress', 'icon': Icons.spa_outlined},
      'better_sleep': {'label': 'Mieux dormir', 'icon': Icons.bedtime_outlined},
      'more_energy': {'label': 'Plus d\'énergie', 'icon': Icons.bolt_outlined},
      'manage_emotions': {'label': 'Gérer émotions', 'icon': Icons.psychology_outlined},
      'improve_focus': {'label': 'Améliorer focus', 'icon': Icons.center_focus_strong_outlined},
      'self_care': {'label': 'Prendre soin', 'icon': Icons.self_improvement_outlined},
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes objectifs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 12),
        ...(_profile!.mainGoals.map((goal) {
          final info = goals[goal];
          if (info == null) return SizedBox.shrink();
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    info['icon'] as IconData,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  info['label'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          );
        }).toList()),
      ],
    );
  }
}
