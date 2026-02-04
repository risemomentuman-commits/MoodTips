import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../models/user_profile.dart';
import '../models/mood_log.dart';
import '../widgets/exercise_stats_card.dart';
import '../services/badge_service.dart';
import '../widgets/badges_summary_widget.dart';

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

  Future<void> _testBadges() async {
    final badges = await BadgeService.getUserBadges();
    print('📊 Total badges: ${badges.length}');
    
    for (var badge in badges) {
      print('${badge.emoji} ${badge.name}: ${badge.currentProgress}/${badge.requiredCount}');
      if (badge.isUnlocked) {
        print('   ✅ Débloqué le ${badge.unlockedAt}');
      }
    }
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
      // ignore: avoid_print
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

    // ⚠️ on évite le /3 si on n'a pas assez de points
    final recentSlice = _recentMoods.take(3).toList();
    final oldSlice = _recentMoods.skip(3).take(3).toList();

    final recent = recentSlice.isEmpty
        ? 0.0
        : recentSlice.fold(0.0, (s, l) => s + l.emotionId) / recentSlice.length;

    final old = oldSlice.isEmpty
        ? recent
        : oldSlice.fold(0.0, (s, l) => s + l.emotionId) / oldSlice.length;

    if (recent > old) return '↗️';
    if (recent < old) return '↘️';
    return '→';
  }

  // Helper catégories
  List<String> get _userCategories {
    if (_profile?.preferences == null) return [];
    final categories = _profile!.preferences!['categories'];
    if (categories == null) return [];
    return List<String>.from(categories);
  }

  // ========= STYLE PANEL (harmonisation globale) =========
  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.primary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _period,
                                  isDense: true,
                                  items: const [
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

                        const SizedBox(height: 24),

                        // ✅ Harmonisé (même cadre)
                        _panel(
                          padding: EdgeInsets.zero,
                          child: ExerciseStatsCard(),
                        ),

                        const SizedBox(height: 20),

                        // Insights contexte
                        if (_contextInsights != null && (_contextInsights!['total'] as int) > 0)
                          _buildContextInsights(),

                        const SizedBox(height: 20),

                        // ✅ À la place du graphique : synthèse plus parlante
                        _buildMoodSummaryCard(),

                        const SizedBox(height: 20),

                        // Stats
                        _buildStatsCards(),

                        const SizedBox(height: 20),

                        // Catégories préférées
                        if (_profile != null && _userCategories.isNotEmpty) _buildCategoriesSection(),

                        const SizedBox(height: 20),

                        // Objectifs
                        if (_profile != null && _profile!.mainGoals.isNotEmpty) _buildGoalsSection(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ========== WIDGETS ==========

  Widget _buildMoodSummaryCard() {
    final avg = _averageMood;
    final trend = _moodTrend;

    String label;
    IconData icon;
    Color color;

    if (_recentMoods.isEmpty) {
      label = "Aucune donnée pour l’instant";
      icon = Icons.info_outline;
      color = AppColors.textMedium;
    } else if (avg >= 7) {
      label = "Plutôt stable et positif";
      icon = Icons.sentiment_very_satisfied_outlined;
      color = AppColors.success;
    } else if (avg >= 4) {
      label = "Mitigé, à surveiller";
      icon = Icons.sentiment_neutral_outlined;
      color = Colors.orange;
    } else {
      label = "Bas, priorité au reset";
      icon = Icons.sentiment_dissatisfied_outlined;
      color = AppColors.error;
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              Text(
                'Ton état (sur ${_period}j)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.16)),
                ),
                child: Text(
                  'Tendance $trend',
                  style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _recentMoods.isEmpty
                ? "Commence par enregistrer ton humeur pour voir une vraie progression."
                : "Humeur moyenne : ${avg.toStringAsFixed(1)}/10 • ${_recentMoods.length} enregistrements",
            style: TextStyle(color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }

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
        positiveContexts['location']![location] =
            (positiveContexts['location']![location] ?? 0) + 1;
        positiveContexts['company']![company] =
            (positiveContexts['company']![company] ?? 0) + 1;
        positiveContexts['time']![timeOfDay] =
            (positiveContexts['time']![timeOfDay] ?? 0) + 1;
        positiveContexts['activity']![activity] =
            (positiveContexts['activity']![activity] ?? 0) + 1;
      } else {
        negativeContexts['location']![location] =
            (negativeContexts['location']![location] ?? 0) + 1;
        negativeContexts['company']![company] =
            (negativeContexts['company']![company] ?? 0) + 1;
        negativeContexts['time']![timeOfDay] =
            (negativeContexts['time']![timeOfDay] ?? 0) + 1;
        negativeContexts['activity']![activity] =
            (negativeContexts['activity']![activity] ?? 0) + 1;
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

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              Text(
                'Tes insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (bestLocation != null || bestCompany != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sentiment_satisfied_alt, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
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
            const SizedBox(height: 12),
          ],

          if (worstLocation != null || worstCompany != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
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
    var entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  Widget _buildStatsCards() {
    return _panel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.local_fire_department,
              value: '${_profile?.currentStreak ?? 0}',
              label: 'Jours de suite',
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_circle_outline,
              value: '${_profile?.totalTipsCompleted ?? 0}',
              label: 'Tips complétés',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.sentiment_satisfied_alt,
              value: _averageMood.toStringAsFixed(1),
              label: 'Humeur moy.',
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Widget badges (temporairement commenté)
  BadgesSummaryWidget(),

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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

    return _panel(
      child: Column(
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _userCategories.map((cat) {
              final info = categories[cat];
              if (info == null) return const SizedBox.shrink();
              final Color chipColor = info['color'] as Color;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipColor.withOpacity(0.28), width: 1.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(info['emoji'] as String, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
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
      ),
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

    return _panel(
      child: Column(
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
          const SizedBox(height: 12),
          ...(_profile!.mainGoals.map((goal) {
            final info = goals[goal];
            if (info == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
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
                  const SizedBox(width: 12),
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
      ),
    );
  }
}
