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
import '../services/irm_service.dart';
import '../services/notification_service.dart';
import '../services/dashboard_cache.dart';

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
  IRMResult? _irmResult;
  bool _irmLoading = false;
  double? _estimatedSleepHours; // si saisie manuelle
  Future<List<Emotion>>? _emotionsFuture;
  Future<UserProfile?>? _profileFuture;
  Future<Map<String, dynamic>>? _emotionAnalysisFuture;
  
  bool _isExpressMode = true;
  bool _showAlert = true;
  
  @override
  void initState() {
    super.initState();
    _emotionsFuture = SupabaseService.getEmotions();
    _profileFuture = SupabaseService.getProfile();
    _loadEmotionAnalysis();
    _loadIRM();
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

  Future<void> _loadIRM() async {
    setState(() => _irmLoading = true);
    try {
      final result = await IRMService.calculateScore(
        estimatedSleepHours: _estimatedSleepHours,
      );
      setState(() {
        _irmResult = result;
        _irmLoading = false;
      });
    } catch (e) {
      print('❌ Erreur IRM: $e');
      setState(() => _irmLoading = false);
    }
  }

  Future<void> _showExpressSuccess(String emotionName) async {
    HapticFeedback.heavyImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Check-in validé ! Humeur "$emotionName" enregistrée 🎉',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    await BadgeChecker.checkAndShowBadges(context);
    
    setState(() {
      _profileFuture = SupabaseService.getProfile();
      _loadEmotionAnalysis();
    });
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
                                onPressed: () => Navigator.pushNamed(context, AppRoutes.dashboard),
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
                            DashboardCache.clear(); // ✅ Force le dashboard à se recharger
                            if (moodLog == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur lors de l\'enregistrement'), backgroundColor: AppColors.error),
                              );
                              return;
                            }
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
                  
                  // Bouton Feedback
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = 'https://docs.google.com/forms/d/e/1FAIpQLSd5GIhsTxsvTGQULpspFzYboTV3jKXCG8ymRTSU4EYQdOlpUQ/viewform';
                      try {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Impossible d\'ouvrir le lien')),
                        );
                      }
                    },
                    icon: Icon(Icons.feedback, size: 20),
                    label: Text('Feedback Test MoodTips'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary, // ✅ Secondary au lieu de warning
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                ],         // ferme children
              ),             // ferme Column
            ),               // ferme SingleChildScrollView  
          ),                 // ferme SafeArea
        ),                   // ferme Scaffold
      ),                     // ferme Container gradient
    ),                       // ferme Container couleur
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

    if (_irmResult == null) return SizedBox.shrink();

    final irm = _irmResult!;

    final zoneColor = irm.zone == IRMZone.stable
        ? AppColors.primary
        : irm.zone == IRMZone.pressure
            ? AppColors.warning
            : AppColors.error;

    final zoneBg = zoneColor.withOpacity(0.08);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          // ── HEADER ──
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: zoneBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: zoneColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: zoneColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${irm.score}', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('/100', style: TextStyle(color: Colors.white70, fontSize: 8)),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(irm.zoneEmoji, style: TextStyle(fontSize: 13)),
                          SizedBox(width: 4),
                          Text(irm.zoneLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: zoneColor)),
                          SizedBox(width: 4),
                          Text('· IRM', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(irm.zoneDescription, style: TextStyle(fontSize: 11, color: AppColors.textMedium, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _loadIRM,
                  child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.refresh, color: AppColors.textLight, size: 16)),
                ),
              ],
            ),
          ),

          // ── BARRE PROGRESSION ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: irm.score / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(zoneColor),
                minHeight: 4,
              ),
            ),
          ),

          // ── FACTEUR + PROTOCOLE ──
          Padding(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: 10),
            child: Row(
              children: [
                if (irm.topFactor != null) ...[
                  Text(irm.topFactor!.emoji, style: TextStyle(fontSize: 12)),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      irm.topFactor!.label,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Text('💡', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    irm.protocol,
                    style: TextStyle(fontSize: 10, color: AppColors.textMedium),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── SOMMEIL INCONNU ──
          if (irm.sleepSource == SleepDataSource.unknown)
            Container(
              margin: EdgeInsets.only(left: 12, right: 12, bottom: 12),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💤 Combien d\'heures as-tu dormi ?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSleepButton('< 5h', 4.5),
                      _buildSleepButton('5-6h', 5.5),
                      _buildSleepButton('6-7h', 6.5),
                      _buildSleepButton('7-8h', 7.5),
                      _buildSleepButton('8h+', 8.5),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSleepButton(String label, double hours) {
    final isSelected = _estimatedSleepHours == hours;
    return GestureDetector(
      onTap: () {
        setState(() => _estimatedSleepHours = hours);
        HapticFeedback.lightImpact();
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
