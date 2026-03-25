// lib/pages/intelligent_mode_flow_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/emotion_detection_service.dart';
import '../services/irm_calculator_v2.dart';
import '../services/user_learning_service.dart';
import '../models/detected_emotional_state.dart';
import '../models/irm_score_detailed.dart';
import '../models/user_profile_dynamic.dart';
import '../repositories/irm_scores_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../pages/irm_detail_page.dart';
import '../pages/irm_history_page.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';
import '../widgets/battery_widget.dart';
import '../services/health_service.dart';
import '../services/calendar_service.dart';

class IntelligentModeFlowPage extends StatefulWidget {
  const IntelligentModeFlowPage({Key? key}) : super(key: key);

  @override
  State<IntelligentModeFlowPage> createState() => _IntelligentModeFlowPageState();
}

class _IntelligentModeFlowPageState extends State<IntelligentModeFlowPage> {
  DetectedEmotionalState? _detectedState;
  IrmScoreDetailed? _irmScore;
  bool _isLoading = true;
  bool _userValidated = false;
  String? _selectedEmotion;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _validateFromIrm() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Mapper le score IRM vers une émotion
      final score = _irmScore?.score ?? 50;
      String emotion;
      if (score >= 80) {
        emotion = 'joyeux';
      } else if (score >= 65) {
        emotion = 'confiant';
      } else if (score >= 50) {
        emotion = 'calme';
      } else if (score >= 35) {
        emotion = 'fatigué';
      } else if (score >= 20) {
        emotion = 'stressé';
      } else {
        emotion = 'épuisé';
      }

      final emotionId = _getEmotionId(emotion);

      await Supabase.instance.client.from('mood_logs').insert({
        'user_id': userId,
        'emotion_id': emotionId,
        'created_at': DateTime.now().toIso8601String(),
      });

      HapticFeedback.heavyImpact();

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.tipsResult, arguments: emotionId);
      }
    } catch (e) {
      print('❌ Erreur: $e');
    }
  }

  Future<void> _runAnalysis() async {
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Lancer les 2 analyses en parallèle
      final results = await Future.wait([
        EmotionDetectionService.detectCurrentState(),
        _calculateIrmScore(userId),
      ]);

      final detectedState = results[0] as DetectedEmotionalState;
      final irmScore = results[1] as IrmScoreDetailed?;

      setState(() {
        _detectedState = detectedState;
        _irmScore = irmScore;
        _selectedEmotion = detectedState.hasDetection ? detectedState.primaryEmotion : null;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur analyse: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<IrmScoreDetailed?> _calculateIrmScore(String userId) async {
    try {
      final repo = IrmScoresRepository();

      // Réutiliser le score du jour si déjà calculé (avec bon sommeil)
      final existing = await repo.getLatestScore(userId);
      if (existing != null &&
          existing.timestamp.day == DateTime.now().day) {
        return existing;
      }

      // Sinon recalculer
      final learning = UserLearningService();
      final profileRepo = UserProfileRepository();

      final now = DateTime.now();
      final profile = await profileRepo.getProfile(userId) ??
          UserProfileDynamic(userId: userId, createdAt: now, updatedAt: now);

      final realHealth = await HealthService.getAllHealthData();
      final last7Emotions = await learning.getLast7Emotions(userId);

      double sleepHours = realHealth.sleep?.durationHours ?? 0;
      if (sleepHours == 0) {
        try {
          final today = now.toIso8601String().substring(0, 10);
          final manual = await Supabase.instance.client
              .from('irm_scores')
              .select('manual_sleep_hours')
              .eq('user_id', userId)
              .eq('date', today)
              .maybeSingle();
          if (manual?['manual_sleep_hours'] != null) {
            sleepHours = (manual!['manual_sleep_hours'] as num).toDouble();
          }
        } catch (_) {}
        if (sleepHours == 0) sleepHours = 7.0;
      }
      final steps = realHealth.activity?.steps ?? 0;

      int totalEvents = 0;
      int workEvents = 0;
      int positiveEvents = 0;
      bool hasCalendar = false;
      double meetingHours = 0;
      double weightedImpact = 0;
      try {
        final events = await CalendarService.getTodayEvents();
        totalEvents = events.length;
        workEvents = CalendarService.countWorkEvents(events);
        positiveEvents = CalendarService.countPositiveEvents(events);
        hasCalendar = totalEvents > 0;
        meetingHours = CalendarService.calculateMeetingHours(events);
        weightedImpact = CalendarService.calculateWeightedImpact(events);
        print('📅 $totalEvents événements, impact pondéré: ${weightedImpact.toStringAsFixed(1)}');
      } catch (e) {
        print('⚠️ Calendrier non disponible: $e');
      }

      final sources = <String>['checkin'];
      if (hasCalendar) sources.add('calendar');
      if (realHealth.sleep != null || (realHealth.activity != null && steps > 0)) {
        sources.add('apple_health');
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
        weightedImpact: weightedImpact,
       
        triggeredBy: 'checkin',
      );

      await repo.saveScore(userId: userId, score: score, triggeredBy: 'checkin');
      return score;
    } catch (e) {
      print('❌ Erreur IRM V2: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();
    if (_irmScore == null && (_detectedState == null || !_detectedState!.hasDetection)) {
      return _buildNoDetectionScreen();
    }
    if (!_userValidated) return _buildResultScreen();
    return _buildSuccessScreen();
  }

  // ══════════════════════════════════════
  // ÉCRAN CHARGEMENT
  // ══════════════════════════════════════
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.secondary.withOpacity(0.05),
              AppColors.backgroundPrimary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
              SizedBox(height: 24),
              Text(
                '🧠 Analyse en cours...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              SizedBox(height: 12),
              Text(
                'Sommeil • Activité • Agenda • Historique',
                style: TextStyle(fontSize: 14, color: AppColors.textMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // ÉCRAN PAS DE DONNÉES
  // ══════════════════════════════════════
  Widget _buildNoDetectionScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.secondary.withOpacity(0.05),
              AppColors.backgroundPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    Expanded(
                      child: Text('Mode Intelligent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sensors_off, size: 80, color: AppColors.warning),
                        SizedBox(height: 24),
                        Text('Pas assez de données', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text(
                          'Fais ton premier check-in\npour activer l\'analyse intelligente',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: AppColors.textMedium, height: 1.5),
                        ),
                        SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.mood),
                          label: Text('Faire un check-in'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // ÉCRAN RÉSULTATS (IRM V2 + Émotion)
  // ══════════════════════════════════════
  Widget _buildResultScreen() {
    final irm = _irmScore;
    final hasEmotion = _detectedState != null && _detectedState!.hasDetection;

    // Ajoute cette ligne :
    final scoreColor = irm != null && irm.score >= 80
        ? const Color(0xFF2E7D32)
        : irm != null && irm.score >= 60
            ? const Color(0xFF4CAF50)
            : irm != null && irm.score >= 40
                ? const Color(0xFFFF9800)
                : const Color(0xFFF44336);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.secondary.withOpacity(0.05),
              AppColors.backgroundPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    Expanded(
                      child: Text('Analyse Intelligente', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // ── BATTERIE IRM V2 ──
                      if (irm != null) ...[
                        
                        
                        // Facteurs rapides
                        _buildFactorsGrid(irm),
                        SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => IrmDetailPage(score: irm)),
                          ),
                          child: Text(
                            'Voir le détail IRM →',
                            style: TextStyle(color: AppColors.primary.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        SizedBox(height: 16),

                      // ── ÉMOTION DÉTECTÉE ──
                      if (hasEmotion) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            children: [
                              Text('Émotion détectée', style: TextStyle(fontSize: 14, color: AppColors.textMedium)),
                              SizedBox(height: 12),
                              Text(_getEmotionEmoji(_selectedEmotion!), style: TextStyle(fontSize: 48)),
                              SizedBox(height: 8),
                              Text(
                                _capitalizeEmotion(_selectedEmotion!),
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Confiance: ${(_detectedState!.confidence * 100).toInt()}%',
                                style: TextStyle(fontSize: 13, color: AppColors.textMedium),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // ── RAISONS ──
                      if (_detectedState != null && _detectedState!.detectionReasons.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text('Pourquoi cette analyse ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                              SizedBox(height: 12),
                              ..._detectedState!.detectionReasons.map((reason) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.check_circle, size: 16, color: AppColors.success),
                                      SizedBox(width: 8),
                                      Expanded(child: Text(reason, style: TextStyle(height: 1.4, fontSize: 14))),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                      // ── CONSEIL PRINCIPAL ──
                      if (irm != null) ...[
                        SizedBox(height: 16),
                        _buildMainConseil(irm),
                      ],

                      SizedBox(height: 24),
                    ],
                    ],
                  ),
                ),
              ),

              // ── BOUTONS BAS ──
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    if (hasEmotion) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showManualSelection,
                          child: Text('Modifier'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primary),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: hasEmotion ? _validateEmotion : _validateFromIrm,
                        child: Text(hasEmotion ? 'Valider ✓' : 'Continuer →'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // GRILLE 4 FACTEURS
  // ══════════════════════════════════════
  Widget _buildFactorsGrid(IrmScoreDetailed irm) {
    final items = [
      {'emoji': '🛏️', 'label': 'Sommeil', 'points': irm.sleep.points, 'max': irm.sleep.maxPoints},
      {'emoji': '🚶', 'label': 'Activité', 'points': irm.activity.points, 'max': irm.activity.maxPoints},
      {'emoji': '🧠', 'label': 'Charge', 'points': irm.mentalLoad.points, 'max': irm.mentalLoad.maxPoints},
      {'emoji': '💚', 'label': 'Stabilité', 'points': irm.emotionStability.points, 'max': irm.emotionStability.maxPoints},
    ];

    return Row(
      children: items.map((item) {
        final points = item['points'] as int;
        final max = item['max'] as int;
        final ratio = max > 0 ? points / max : 0.0;
        final color = ratio >= 0.8
            ? const Color(0xFF2E7D32)
            : ratio >= 0.5
                ? const Color(0xFFFF9800)
                : const Color(0xFFF44336);

        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                Text('${item['emoji']}', style: TextStyle(fontSize: 20)),
                SizedBox(height: 4),
                Text('$points/${max}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                SizedBox(height: 2),
                Text('${item['label']}', style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════
  // CONSEIL PRINCIPAL
  // ══════════════════════════════════════
  Widget _buildMainConseil(IrmScoreDetailed irm) {
    String? conseil;
    for (final f in [irm.sleep, irm.activity, irm.mentalLoad, irm.emotionStability]) {
      if (f.conseil != null) {
        conseil = f.conseil;
        break;
      }
    }
    if (conseil == null) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text('💡', style: TextStyle(fontSize: 20)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conseil du jour', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                SizedBox(height: 4),
                Text(conseil, style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // ÉCRAN SUCCÈS
  // ══════════════════════════════════════
  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.success.withOpacity(0.1), AppColors.backgroundPrimary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.check_circle, size: 80, color: AppColors.success),
                  ),
                  SizedBox(height: 32),
                  Text('État enregistré !', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('Ton ressenti a été sauvegardé', style: TextStyle(fontSize: 16, color: AppColors.textMedium)),
                  SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Text('Terminer', style: TextStyle(fontSize: 16)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════
  void _showManualSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Comment te sens-tu ?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    _buildEmotionCategory('Positif', [
                      ('heureux',    '😊', 8),
                      ('joyeux',     '😄', 20),
                      ('confiant',   '💪', 21),
                      ('énergique',  '⚡', 22),
                      ('calme',      '😌', 7),
                      ('détendu',    '🧘', 32),
                      ('accompli',   '🏆', 31),
                      ('reposé',     '😴', 32),
                    ]),
                    SizedBox(height: 12),
                    _buildEmotionCategory('Neutre / Mitigé', [
                      ('fatigué',    '😴', 3),
                      ('épuisé',     '🪫', 30),
                      ('sédentaire', '🛋️', 29),
                      ('préoccupé',  '😟', 33),
                      ('frustré',    '😤', 23),
                      ('débordé',    '🤯', 6),
                    ]),
                    SizedBox(height: 12),
                    _buildEmotionCategory('Difficile', [
                      ('stressé',    '😰', 1),
                      ('anxieux',    '😨', 2),
                      ('triste',     '😢', 4),
                      ('colère',     '😡', 5),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmotionCategory(String title, List<(String, String, int)> emotions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMedium,
              letterSpacing: 0.5,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.8,
          children: emotions.map((e) {
            final emotion = e.$1;
            final emoji   = e.$2;
            final isSelected = _selectedEmotion == emotion;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedEmotion = emotion);
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _capitalizeEmotion(emotion),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  int _getEmotionId(String emotion) {
    const ids = {
      'stress':      1,  'stressé':     1,
      'anxiété':     2,  'anxieux':     2,
      'fatigue':     3,  'fatigué':     3,
      'tristesse':   4,  'triste':      4,
      'colère':      5,
      'débordé':     6,
      'calme':       7,
      'heureux':     8,
      'joyeux':      20,
      'confiant':    21,
      'énergique':   22,
      'frustré':     23,
      'sédentaire':  29,
      'épuisé':      30,
      'accompli':    31,
      'détendu':     32,  'reposé':     32,
      'préoccupé':   33,
    };
    return ids[emotion] ?? 8;
  }

  String _getEmotionEmoji(String emotion) {
    const emojis = {
      'stress':      '😰', 'stressé':    '😰',
      'anxiété':     '😨', 'anxieux':    '😨',
      'fatigue':     '😴', 'fatigué':    '😴',
      'tristesse':   '😢', 'triste':     '😢',
      'colère':      '😡',
      'débordé':     '🤯',
      'calme':       '😌',
      'heureux':     '😊',
      'joyeux':      '😄',
      'confiant':    '💪',
      'énergique':   '⚡',
      'frustré':     '😤',
      'sédentaire':  '🛋️',
      'épuisé':      '🪫',
      'accompli':    '🏆',
      'détendu':     '🧘', 'reposé':    '🧘',
      'préoccupé':   '😟',
    };
    return emojis[emotion] ?? '😐';
  }
  String _capitalizeEmotion(String emotion) {
    if (emotion.isEmpty) return emotion;
    return emotion[0].toUpperCase() + emotion.substring(1);
  }

  Future<void> _validateEmotion() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');

      await Supabase.instance.client.from('mood_logs').insert({
        'user_id':    userId,
        'emotion_id': _getEmotionId(_selectedEmotion!),
        'created_at': DateTime.now().toIso8601String(),
      });

      HapticFeedback.heavyImpact();

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.tipsResult,
          arguments: _getEmotionId(_selectedEmotion!),
        );
      }
    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getMotivationalMessage(int score) {
    if (score >= 80) return 'Tu es en pleine forme aujourd\'hui ! 🔥';
    if (score >= 60) return 'Bonne énergie, continue comme ça 💪';
    if (score >= 40) return 'Journée mitigée, prends soin de toi 🌿';
    if (score >= 20) return 'Énergie basse — accorde-toi du repos 🧘';
    return 'Alerte énergie critique — priorité au repos ⚠️';
  }
}