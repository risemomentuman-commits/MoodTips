import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/emotion_analysis_service.dart';
import '../models/emotion.dart';
import '../models/user_profile.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../widgets/emotion_wheel.dart';
import '../widgets/emotion_alert_widget.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/badge_checker.dart';
import '../services/irm_calculator_v2.dart';
import '../services/user_learning_service.dart';
import '../models/irm_score_detailed.dart';
import '../repositories/irm_scores_repository.dart';
import '../pages/irm_detail_page.dart';
import '../pages/irm_history_page.dart';
import '../services/notification_service.dart';
import '../services/dashboard_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/user_profile_repository.dart';
import '../models/user_profile_dynamic.dart';
import '../services/health_service.dart';
import '../widgets/battery_widget.dart';
import '../services/calendar_service.dart';

class MoodCheckPage extends StatefulWidget {
   const MoodCheckPage({Key? key}) : super(key: key); // ✅ Accepte maintenant une clé

   // ✅ Clé globale pour forcer le refresh
  static final GlobalKey<_MoodCheckPageState> pageKey = GlobalKey<_MoodCheckPageState>();

  // ✅ Méthode pour recharger la page
  static void reload() {
    pageKey.currentState?.reload();
  }

  @override
  _MoodCheckPageState createState() => _MoodCheckPageState();
}

class _MoodCheckPageState extends State<MoodCheckPage> {
  // Variables IRM
  IrmScoreDetailed? _irmScore;
  bool _irmLoading = false;
  double? _estimatedSleepHours;bool _hasSleepData = false; // si saisie manuelle
  Future<List<Emotion>>? _emotionsFuture;
  Future<UserProfile?>? _profileFuture;
  Future<Map<String, dynamic>>? _emotionAnalysisFuture;
  
  bool _isExpressMode = true;
  bool _showAlert = true;
  bool _hasCheckedInToday = false;
  bool _showCheckinExplainer = true;
  bool get hasSleepData {
    return _estimatedSleepHours != null && _estimatedSleepHours! > 0;
  }
  
  @override
  void initState() {
    super.initState();
    _emotionsFuture = SupabaseService.getEmotions();
    _profileFuture = SupabaseService.getProfile();
    _loadEmotionAnalysis();
    _loadIRM();
    _checkTodayCheckin();
  }

  void reload() {
    setState(() {
      // Force le rebuild complet
      _profileFuture = SupabaseService.getProfile();
      _emotionsFuture = SupabaseService.getEmotions();
    });
  }

  Future<void> _loadEmotionAnalysis() async {
    final shouldShow = await EmotionAnalysisService.shouldShowAlert();
    if (shouldShow) {
      setState(() {
        _emotionAnalysisFuture = EmotionAnalysisService.analyzeRecentEmotions();
      });
    }
  }

  Future<void> _checkTodayCheckin() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from('mood_logs')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', '${today}T00:00:00')
          .limit(1)
          .maybeSingle();
      
      setState(() {
        _hasCheckedInToday = response != null;
      });
    } catch (e) {
      print('⚠️ Erreur vérification check-in: $e');
    }
  }

  Future<void> _loadIRM() async {
    setState(() => _irmLoading = true);
    try {
      final repo = IrmScoresRepository();
      final learning = UserLearningService();
      final profileRepo = UserProfileRepository();

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _irmLoading = false);
        return;
      }

      if (_estimatedSleepHours == null) {
        _estimatedSleepHours = await _loadManualSleepHours();
      }

      

      // Récupérer les données
      final now = DateTime.now();
      final profile = await profileRepo.getProfile(userId) ??
          UserProfileDynamic(
            userId: userId,
            createdAt: now,
            updatedAt: now,
          );
      final realHealth = await HealthService.getAllHealthData();
      final last7Emotions = await learning.getLast7Emotions(userId);

      final sleepHours = _estimatedSleepHours ?? realHealth.sleep?.durationHours ?? 7.0;
      final steps = realHealth.activity?.steps ?? 0;
      // Charger les événements calendrier
      int totalEvents = 0;
      int workEvents = 0;
      int positiveEvents = 0;
      bool hasCalendar = false;
      double meetingHours = 0;
      try {
        final events = await CalendarService.getTodayEvents();
        totalEvents = events.length;
        workEvents = events.where((e) => e.isStressful).length;
        positiveEvents = events.where((e) => !e.isStressful).length;
        hasCalendar = totalEvents > 0;
        meetingHours = events.fold<double>(0, (sum, e) => sum + e.durationHours);
        print('📅 $totalEvents événements, ${meetingHours.toStringAsFixed(1)}h de réunions');
      } catch (e) {
        print('⚠️ Calendrier non disponible: $e');
      }

      final sources = <String>['checkin'];
      if (hasCalendar) sources.add('calendar');
      bool hasSleepData = realHealth.sleep != null;
      _hasSleepData = hasSleepData;
      if (hasSleepData) {
        sources.add('apple_health');
      } else if (_estimatedSleepHours != null) {
        sources.add('manual');
      }
      if (realHealth.activity != null && steps > 0) {
        if (!sources.contains('apple_health')) sources.add('apple_health');
      }

      final score = IrmCalculatorV2.calculate(
        profile: profile,
        sleepHours: sleepHours,
        steps: steps,
        totalEvents: totalEvents,
        workEvents: workEvents,
        positiveEvents: positiveEvents,
        meetingHours: meetingHours,
        last7Emotions: last7Emotions,
        sources: sources,
        
        triggeredBy: 'auto',
      );

      // Sauvegarder
      try {
        print('🔍 MoodCheck - Saving IRM score: ${score.score} for user: $userId');
        await repo.saveScore(
          userId: userId,
          score: score,
          triggeredBy: 'auto',
        );
        print('🔍 MoodCheck - Score saved OK');
      } catch (e) {
        print('❌ MoodCheck - Erreur save score: $e');
      }
      await learning.saveDailyHealthData(
        userId: userId,
        sleepHours: sleepHours,
        sleepSource: realHealth.sleep != null ? 'health' : (_estimatedSleepHours != null ? 'manual' : 'estimated'),
        steps: steps,
        totalEvents: totalEvents,
        workEvents: workEvents,
        positiveEvents: positiveEvents,
      );

      setState(() {
        _irmScore = score;
        _irmLoading = false;
      });
    } catch (e) {
      print('❌ Erreur IRM V2: $e');
      setState(() => _irmLoading = false);
    }
  }

  Future<double?> _loadManualSleepHours() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from('daily_health_data')
          .select('sleep_duration_hours')
          .eq('user_id', userId)
          .eq('date', today)
          .eq('sleep_source', 'manual')
          .maybeSingle();
      if (response?['sleep_duration_hours'] != null) {
        return (response!['sleep_duration_hours'] as num).toDouble();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveManualSleepHours(double hours) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      await Supabase.instance.client.from('daily_health_data').upsert({
        'user_id': userId,
        'date': today,
        'sleep_duration_hours': hours,
        'sleep_source': 'manual',
      }, onConflict: 'user_id,date');
      
      print('✅ Sommeil manuel sauvegardé: ${hours}h');
    } catch (e) {
      print('❌ Erreur saveManualSleepHours: $e');
    }
  }

  @override
    Widget build(BuildContext context) {
      return KeyedSubtree(
        key: ValueKey(AppColors.currentThemeId),
        child: Container(
          color: AppColors.backgroundPrimary, // ✅ Fond beige opaque en base
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  AppColors.backgroundPrimary,
                  AppColors.secondary.withOpacity(0.08),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Header - RÉDUIT
                  Padding(
                    padding: EdgeInsets.only(
                      top: 8,        // ✅ Réduit (plus de double padding)
                      left: 20,
                      right: 20,
                      bottom: 4,     // ✅ Réduit
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ✅ Expanded pour éviter l'overflow
                        Expanded(
                          child: Text(
                            'Comment te sens-tu ?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        // Icônes plus compactes
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
                                onPressed: () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.pushNamed(context, AppRoutes.dashboard);
                                  }
                                },
                                tooltip: 'Mes statistiques',
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.settings, color: AppColors.primary, size: 20),
                                onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                                tooltip: 'Paramètres',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 🧠 IRM WIDGET
                  _buildIRMWidget(),
                  SizedBox(height: 8),

                  

                  // Alerte émotionnelle
                  if (_showAlert)
                    FutureBuilder<Map<String, dynamic>>(
                      future: _emotionAnalysisFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return SizedBox.shrink();
                        
                        final analysis = snapshot.data!;
                        
                        if (!analysis['shouldShow']) return SizedBox.shrink();
                        
                        return EmotionAlertWidget(
                          alertLevel: analysis['alertLevel'],
                          message: analysis['message'],
                          action: analysis['action'],
                          consecutiveNegative: analysis['consecutiveNegative'],
                          onDismiss: () {
                            setState(() => _showAlert = false);
                          },
                        );
                      },
                    ),

                  SizedBox(height: 12),


                 // Toggle Mode Intelligent / Standard
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // MODE INTELLIGENT
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isExpressMode = true);
                              HapticFeedback.lightImpact();
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: _isExpressMode
                                    ? LinearGradient(
                                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: _isExpressMode ? null : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isExpressMode
                                    ? [BoxShadow(
                                        color: AppColors.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      )]
                                    : [],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.psychology,
                                    color: _isExpressMode ? Colors.white : Colors.grey[500],
                                    size: 24,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Mode Intelligent',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _isExpressMode ? Colors.white : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '✨ Détection auto',
                                    style: TextStyle(
                                      color: _isExpressMode ? Colors.white70 : Colors.grey[400],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // MODE STANDARD
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isExpressMode = false);
                              HapticFeedback.lightImpact();
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: !_isExpressMode
                                    ? Colors.grey[100]
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.tune,
                                    color: !_isExpressMode ? Colors.grey[700] : Colors.grey[400],
                                    size: 24,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Mode Standard',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_isExpressMode ? Colors.grey[700] : Colors.grey[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Parcours complet',
                                    style: TextStyle(
                                      color: !_isExpressMode ? Colors.grey[500] : Colors.grey[400],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  if (_isExpressMode)
                    _buildIntelligentWidget()
                  else ...[
                    Text(
                      'Fais tourner la roue et sélectionne',
                      style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    FutureBuilder<List<Emotion>>(
                      future: _emotionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(child: Text('Erreur de chargement', style: TextStyle(color: AppColors.error)));
                        }
                        return EmotionWheel(
                          emotions: snapshot.data!,
                          onEmotionSelected: (emotion) async {
                            HapticFeedback.mediumImpact();
                            final moodLog = await SupabaseService.createMoodLog(emotionId: emotion.id);
                            DashboardCache.clear();
                            if (moodLog == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur lors de l\'enregistrement'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
                            
                            // ✅ Recalculer IRM avec l'émotion fraîchement enregistrée
                            await _loadIRM();
                            setState(() => _hasCheckedInToday = true);
                            
                            await BadgeChecker.checkAndShowBadges(context);
                            Navigator.pushNamed(context, AppRoutes.context, arguments: {
                              'emotionId': emotion.id,
                              'moodLogId': moodLog.id,
                            });
                          },
                          isIntelligentMode: false,
                        );
                      },
                    ),
                  ],
                  
                  SizedBox(height: 12),
                  
                  // 🆕 Bouton Aide au sommeil - NORMAL AU-DESSUS
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 32),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.sleep),
                      icon: Icon(Icons.nightlight, size: 20),
                      label: Text('Aide au sommeil'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 8),
                
                ],         // ferme children
              ),             // ferme Column
            ),               // ferme SingleChildScrollView  
          ),                 // ferme SafeArea
        ),                   // ferme Scaffold
      ),                     // ferme Container gradient
    ),                       // ferme Container couleur
  );
  }

  Widget _buildCheckinBanner() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hasCheckedInToday
              ? AppColors.success.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasCheckedInToday
                ? AppColors.success.withOpacity(0.3)
                : AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasCheckedInToday ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _hasCheckedInToday ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hasCheckedInToday
                        ? 'Check-in du jour validé ✓'
                        : 'Check-in du jour · à compléter',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _hasCheckedInToday ? AppColors.success : AppColors.textDark,
                    ),
                  ),
                ),
                if (!_hasCheckedInToday)
                  GestureDetector(
                    onTap: () => setState(() => _showCheckinExplainer = !_showCheckinExplainer),
                    child: Icon(
                      _showCheckinExplainer ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMedium,
                      size: 22,
                    ),
                  ),
              ],
            ),
            if (!_hasCheckedInToday && _showCheckinExplainer) ...[
              SizedBox(height: 8),
              Text(
                'Plus tu fais ton check-in régulièrement, plus MoodTips apprend à te connaître et personnalise tes conseils.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIRMWidget() {
    if (_irmLoading) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            SizedBox(width: 10),
            Text('Calcul IRM...', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
          ],
        ),
      );
    }

    if (_irmScore == null) return SizedBox.shrink();

    final irm = _irmScore!;
    final scoreColor = irm.score >= 80
        ? const Color(0xFF2E7D32)
        : irm.score >= 60
            ? const Color(0xFF4CAF50)
            : irm.score >= 40
                ? const Color(0xFFFF9800)
                : const Color(0xFFF44336);

    // Conseil principal
    String? mainConseil;
    final mainFactorLabel = irm.mainFactor;
    for (final f in [irm.sleep, irm.activity, irm.mentalLoad, irm.emotionStability]) {
      if (f.conseil != null) {
        mainConseil = f.conseil;
        break;
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => IrmDetailPage(score: irm)),
      ),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            _buildCheckinBanner(),
            // Header + Batterie sur la même ligne
            Row(
              children: [
                // Batterie compacte à gauche
                BatteryWidget(
                  percentage: irm.score,
                  isCharging: irm.score > 60,
                  width: 100,
                  height: 45,
                ),
                SizedBox(width: 16),
                // Infos à droite
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Énergie Mentale',
                            style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _loadIRM,
                                child: Icon(Icons.refresh, color: Colors.grey.shade500, size: 18),
                              ),
                              SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IrmHistoryPage())),
                                child: Icon(Icons.timeline, color: Colors.grey.shade500, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      if (mainConseil != null)
                        Text(
                          mainConseil,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Lien détail
            SizedBox(height: 8),
            Text(
              'Voir le détail →',
              style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),

            // Saisie sommeil si pas de Health
            if (!hasSleepData && _estimatedSleepHours == null) ...[
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💤 Combien d\'heures as-tu dormi ?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSleepButton('< 5h', 5.0),
                        _buildSleepButton('5-6h', 6.0),
                        _buildSleepButton('6-7h', 7.0),
                        _buildSleepButton('7-8h', 7.5),
                        _buildSleepButton('8h+', 8.5),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }       // ferme _buildIRMWidget

  Widget _buildSleepButton(String label, double hours) {
    final isSelected = _estimatedSleepHours == hours;
    return GestureDetector(
      onTap: () async {
        setState(() => _estimatedSleepHours = hours);
        HapticFeedback.lightImpact();
        await _saveManualSleepHours(hours);
        _loadIRM();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
  Widget _buildIntelligentWidget() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Card principale
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.secondary.withOpacity(0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                // Icône animée
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.psychology, color: Colors.white, size: 40),
                ),
                SizedBox(height: 16),
                Text(
                  'Mode Intelligent',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'L\'IA analyse tes données\npour détecter ton état émotionnel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20),

                // Sources de données
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDataSource(Icons.bedtime, 'Sommeil'),
                    _buildDataSource(Icons.directions_walk, 'Activité'),
                    _buildDataSource(Icons.calendar_today, 'Agenda'),
                    _buildDataSource(Icons.history, 'Historique'),
                  ],
                ),
                SizedBox(height: 24),

                // Bouton analyse
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pushNamed(context, AppRoutes.intelligentMode);
                    },
                    icon: Icon(Icons.search, size: 22),
                    label: Text(
                      'Analyser mon état maintenant',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSource(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.9),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
