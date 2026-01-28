// lib/services/edge_tts_service.dart
// Service Text-to-Speech utilisant Edge TTS (voix Microsoft neurales)

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EdgeTtsService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isInitialized = false;
  static bool _isSpeaking = false;
  
  // Voix féminine française douce (Microsoft Neural)
  static const String _voiceName = 'fr-FR-DeniseNeural';
  
  // Alternative : 'fr-FR-EloiseNeural' (encore plus douce)
  
  /// Initialiser le service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Configurer l'audio player
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
      print('✅ Edge TTS initialisé avec voix: $_voiceName');
    } catch (e) {
      print('❌ Erreur initialisation Edge TTS: $e');
    }
  }
  
  /// Parler - Convertir texte en audio et jouer
  static Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isSpeaking) {
      await stop();
    }
    
    try {
      _isSpeaking = true;
      
      // Générer l'audio via Edge TTS
      final audioData = await _generateAudio(text);
      
      if (audioData == null) {
        print('❌ Échec génération audio');
        _isSpeaking = false;
        return;
      }
      
      // Jouer l'audio
      await _audioPlayer.play(BytesSource(audioData));
      
      // Attendre la fin de lecture
      await _audioPlayer.onPlayerComplete.first;
      
      _isSpeaking = false;
      
    } catch (e) {
      print('❌ Erreur speak: $e');
      _isSpeaking = false;
    }
  }
  
  /// Arrêter la lecture
  static Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isSpeaking = false;
    } catch (e) {
      print('❌ Erreur stop: $e');
    }
  }
  
  /// Mettre en pause
  static Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('❌ Erreur pause: $e');
    }
  }
  
  /// Reprendre
  static Future<void> resume() async {
    try {
      await _audioPlayer.resume();
    } catch (e) {
      print('❌ Erreur resume: $e');
    }
  }
  
  /// Est en train de parler ?
  static bool get isSpeaking => _isSpeaking;
  
  /// Générer l'audio via Edge TTS API
  static Future<Uint8List?> _generateAudio(String text) async {
    try {
      // URL de l'API Edge TTS (service gratuit)
      final url = 'https://edge-tts-api.vercel.app/api/tts';
      
      // Paramètres
      final params = {
        'text': text,
        'voice': _voiceName,
        'rate': '0%',   // Vitesse normale (peut ajuster: -20% à +20%)
        'pitch': '0%',  // Ton normal (peut ajuster: -20% à +20%)
      };
      
      // Construire l'URL
      final uri = Uri.parse(url).replace(queryParameters: params);
      
      // Faire la requête
      final response = await http.get(uri).timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout Edge TTS'),
      );
      
      if (response.statusCode == 200) {
        print('✅ Audio généré (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      } else {
        print('❌ Erreur API: ${response.statusCode}');
        return null;
      }
      
    } catch (e) {
      print('❌ Erreur génération audio: $e');
      return null;
    }
  }
  
  /// Changer la voix
  static void setVoice(String voiceName) {
    // Peut être utilisé pour tester différentes voix
    // Ex: EdgeTtsService.setVoice('fr-FR-EloiseNeural');
  }
  
  /// Ajuster la vitesse (-50% à +100%)
  static void setSpeed(String rate) {
    // Ex: EdgeTtsService.setSpeed('-10%'); // 10% plus lent
    // Ex: EdgeTtsService.setSpeed('+20%'); // 20% plus rapide
  }
  
  /// Libérer les ressources
  static Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      _isInitialized = false;
      _isSpeaking = false;
    } catch (e) {
      print('❌ Erreur dispose: $e');
    }
  }
}

/// VOIX FRANÇAISES DISPONIBLES (Microsoft Neural)
/// 
/// Féminines douces :
/// - fr-FR-DeniseNeural (Recommandé pour MoodTips)
/// - fr-FR-EloiseNeural (Très douce)
/// 
/// Féminines énergiques :
/// - fr-FR-BrigitteNeural
/// 
/// Masculines :
/// - fr-FR-HenriNeural (Calme)
/// - fr-FR-ClaudeNeural
/// - fr-FR-AlainNeural
/// 
/// Pour tester d'autres voix :
/// EdgeTtsService.setVoice('fr-FR-EloiseNeural');