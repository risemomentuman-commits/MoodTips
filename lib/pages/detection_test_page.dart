import 'package:flutter/material.dart';
import '../services/emotion_detection_service.dart';
import '../models/detected_emotional_state.dart';
import '../utils/app_colors.dart';

class DetectionTestPage extends StatefulWidget {
  const DetectionTestPage({Key? key}) : super(key: key);

  @override
  State<DetectionTestPage> createState() => _DetectionTestPageState();
}

class _DetectionTestPageState extends State<DetectionTestPage> {
  DetectedEmotionalState? _detectedState;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Détection'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runDetection,
              icon: Icon(Icons.psychology),
              label: Text(
                _isLoading ? 'Analyse en cours...' : 'Lancer la détection',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            SizedBox(height: 32),
            
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Analyse de ton état...'),
                    SizedBox(height: 8),
                    Text(
                      '🧠 Sommeil • 📅 Calendrier • 💓 Activité',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                  ],
                ),
              )
            else if (_detectedState != null)
              _buildResults(),
          ],
        ),
      ),
    );
  }

  Future<void> _runDetection() async {
    setState(() {
      _isLoading = true;
      _detectedState = null;
    });

    try {
      final state = await EmotionDetectionService.detectCurrentState();
      setState(() {
        _detectedState = state;
      });
    } catch (e) {
      print('❌ Erreur détection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildResults() {
    if (_detectedState!.hasDetection) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
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
                SizedBox(height: 12),
                Text(
                  _getEmotionEmoji(_detectedState!.primaryEmotion!),
                  style: TextStyle(fontSize: 48),
                ),
                SizedBox(height: 8),
                Text(
                  _capitalizeEmotion(_detectedState!.primaryEmotion!),
                  style: TextStyle(
                    fontSize: 24,
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
          
          SizedBox(height: 16),
          
          if (_detectedState!.secondaryEmotions.isNotEmpty) ...[
            Text(
              'Émotions secondaires',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _detectedState!.secondaryEmotions.map((emotion) {
                return Chip(
                  avatar: Text(_getEmotionEmoji(emotion)),
                  label: Text(_capitalizeEmotion(emotion)),
                  backgroundColor: AppColors.surfaceLight,
                );
              }).toList(),
            ),
            SizedBox(height: 16),
          ],
          
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
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
                        fontSize: 16,
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
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔍 Détails techniques',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                ..._detectedState!.rawPredictions.map((pred) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${pred.emotion}: ${(pred.confidence * 100).toInt()}% - ${pred.reason}',
                      style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      );
    } else {
      return Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.sensors_off, size: 64, color: AppColors.warning),
            SizedBox(height: 16),
            Text(
              'Pas assez de données',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Connecte tes sources de données pour améliorer la détection',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium),
            ),
            SizedBox(height: 16),
            if (_detectedState!.detectionReasons.isNotEmpty)
              Text(
                _detectedState!.detectionReasons.first,
                style: TextStyle(fontSize: 12, color: AppColors.textMedium),
              ),
          ],
        ),
      );
    }
  }

  String _getEmotionEmoji(String emotion) {
    Map<String, String> emojis = {
      'heureux': '😊',
      'calme': '😌',
      'fatigué': '😴',
      'anxieux': '😰',
      'triste': '😢',
      'irritable': '😡',
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