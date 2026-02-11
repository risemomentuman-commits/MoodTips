import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/emotion_detection_service.dart';
import '../models/detected_emotional_state.dart';
import '../utils/app_colors.dart';
import '../widgets/emotion_wheel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_routes.dart';

class IntelligentModeFlowPage extends StatefulWidget {
  const IntelligentModeFlowPage({Key? key}) : super(key: key);

  @override
  State<IntelligentModeFlowPage> createState() => _IntelligentModeFlowPageState();
}

class _IntelligentModeFlowPageState extends State<IntelligentModeFlowPage> {
  DetectedEmotionalState? _detectedState;
  bool _isLoading = true;
  bool _userValidated = false;
  String? _selectedEmotion;
  
  @override
  void initState() {
    super.initState();
    _runDetection();
  }
  
  Future<void> _runDetection() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.delayed(Duration(milliseconds: 500)); // UX
      final state = await EmotionDetectionService.detectCurrentState();
      
      setState(() {
        _detectedState = state;
        _selectedEmotion = state.primaryEmotion;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur détection: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }
    
    if (_detectedState == null || !_detectedState!.hasDetection) {
      return _buildNoDetectionScreen();
    }
    
    if (!_userValidated) {
      return _buildValidationScreen();
    }
    
    return _buildSuccessScreen();
  }
  
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
              CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                '🧠 Analyse en cours...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Sommeil • Calendrier • Activité',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
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
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Mode Intelligent',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
                
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sensors_off,
                          size: 80,
                          color: AppColors.warning,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Pas assez de données',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Connecte tes sources de données\npour activer la détection auto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textMedium,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Ici tu peux ajouter navigation vers ConnectionsSettingsPage
                          },
                          icon: Icon(Icons.settings),
                          label: Text('Gérer les connexions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Utiliser Mode Standard'),
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
  
  Widget _buildValidationScreen() {
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
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Mode Intelligent',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
                      // État détecté
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '✅ État détecté',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              _getEmotionEmoji(_selectedEmotion!),
                              style: TextStyle(fontSize: 64),
                            ),
                            SizedBox(height: 12),
                            Text(
                              _capitalizeEmotion(_selectedEmotion!),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Confiance: ${(_detectedState!.confidence * 100).toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Raisons
                      if (_detectedState!.detectionReasons.isNotEmpty)
                        Container(
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
                                  Text(
                                    'Pourquoi cette détection ?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
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
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: TextStyle(height: 1.4, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              
              // Boutons bas
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showManualSelection,
                        child: Text('Modifier'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _validateEmotion,
                        child: Text('C\'est ça ! ✓'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
  
  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.success.withOpacity(0.1),
              AppColors.backgroundPrimary,
            ],
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
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 80,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(height: 32),
                  Text(
                    'État enregistré !',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Ton ressenti a été sauvegardé',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textMedium,
                    ),
                  ),
                  SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Text('Terminer', style: TextStyle(fontSize: 16)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
  
  void _showManualSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choisis ton émotion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Liste émotions simplifiée (à remplacer par ta roue si tu veux)
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(20),
                  children: [
                    _buildEmotionTile('heureux', '😊'),
                    _buildEmotionTile('calme', '😌'),
                    _buildEmotionTile('fatigué', '😴'),
                    _buildEmotionTile('anxieux', '😰'),
                    _buildEmotionTile('triste', '😢'),
                    _buildEmotionTile('stressé', '😤'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildEmotionTile(String emotion, String emoji) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedEmotion = emotion);
        Navigator.pop(context);
        HapticFeedback.mediumImpact();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedEmotion == emotion 
            ? AppColors.primary.withOpacity(0.1)
            : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedEmotion == emotion 
              ? AppColors.primary
              : AppColors.surfaceLight,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 32)),
            SizedBox(width: 16),
            Text(
              _capitalizeEmotion(emotion),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _validateEmotion() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Non connecté');
      
      // Sauvegarder l'émotion
      await Supabase.instance.client.from('mood_logs').insert({
        'user_id': userId,
        'emotion_id': _getEmotionId(_selectedEmotion!),
        'created_at': DateTime.now().toIso8601String(),
      });
      
      HapticFeedback.heavyImpact();
      
      if (mounted) {
        // ✅ Naviguer vers TipsResultPage avec l'emotionId
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.tipsResult,
          arguments: _getEmotionId(_selectedEmotion!), // Passer l'emotionId
        );
      }
      
    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  
  int _getEmotionId(String emotion) {
    // Map simplifié - à adapter selon ta table emotions
    Map<String, int> emotionIds = {
      'heureux': 1,
      'calme': 2,
      'fatigué': 3,
      'anxieux': 4,
      'triste': 5,
      'stressé': 6,
    };
    return emotionIds[emotion] ?? 1;
  }
  
  String _getEmotionEmoji(String emotion) {
    Map<String, String> emojis = {
      'heureux': '😊',
      'calme': '😌',
      'fatigué': '😴',
      'anxieux': '😰',
      'triste': '😢',
      'stressé': '😤',
      'débordé': '🤯',
      'reposé': '😊',
      'énergique': '⚡',
    };
    return emojis[emotion] ?? '😐';
  }
  
  String _capitalizeEmotion(String emotion) {
    return emotion[0].toUpperCase() + emotion.substring(1);
  }
}