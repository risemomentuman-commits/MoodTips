// lib/services/edge_tts_service.dart
// Service Text-to-Speech utilisant Web Speech API (natif navigateur)
// Remplace Edge TTS pour fiabilité 100%

import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class EdgeTtsService {
  static html.SpeechSynthesisUtterance? _currentUtterance;
  static bool _isInitialized = false;
  static bool _isSpeaking = false;
  
  /// Initialiser le service
  static Future<void> initialize() async {
    if (!kIsWeb) {
      print('❌ EdgeTtsService: Not on web');
      return;
    }
    
    try {
      // Vérifier que Web Speech API est disponible
      if (html.window.speechSynthesis != null) {
        _isInitialized = true;
        print('✅ Web Speech API initialisé');
        
        // Charger les voix disponibles
        _loadVoices();
      } else {
        print('❌ Web Speech API non disponible dans ce navigateur');
      }
    } catch (e) {
      print('❌ Erreur initialisation Web Speech: $e');
    }
  }
  
  /// Charger les voix disponibles
  static void _loadVoices() {
    try {
      final voices = html.window.speechSynthesis!.getVoices();
      print('🎙️ ${voices.length} voix disponibles');
      
      // Lister les voix françaises
      final frenchVoices = voices.where((v) => 
        v.lang?.startsWith('fr') == true
      ).toList();
      
      if (frenchVoices.isNotEmpty) {
        print('✅ Voix françaises trouvées: ${frenchVoices.length}');
        for (var voice in frenchVoices) {
          print('  - ${voice.name} (${voice.lang})');
        }
      } else {
        print('⚠️ Aucune voix française trouvée');
      }
    } catch (e) {
      print('❌ Erreur chargement voix: $e');
    }
  }
  
  /// Parler - Convertir texte en audio
  static Future<void> speak(String text) async {
    if (!kIsWeb) return;
    
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isSpeaking) {
      await stop();
    }
    
    try {
      _isSpeaking = true;
      
      _currentUtterance = html.SpeechSynthesisUtterance(text);
      
      // DÉBUGAGE : Afficher TOUTES les voix disponibles
      final voices = html.window.speechSynthesis!.getVoices();
      print('===== TOUTES LES VOIX DISPONIBLES =====');
      for (var voice in voices) {
        print('Voix: ${voice.name} | Langue: ${voice.lang} | Locale: ${voice.localService}');
      }
      print('=======================================');
      
      // Chercher spécifiquement Aurélie
      final aurelieVoice = voices.firstWhere(
        (v) => v.name?.contains('Aurélie') == true,
        orElse: () => voices.first, // Si pas trouvée, prend la première
      );
      
      print('🎙️ Voix sélectionnée: ${aurelieVoice.name}');
      
      _currentUtterance!.voice = aurelieVoice;
      _currentUtterance!.rate = 0.85;
      _currentUtterance!.pitch = 1.0;
      _currentUtterance!.volume = 1.0;
      
      _currentUtterance!.onEnd.listen((_) {
        _isSpeaking = false;
      });
      
      _currentUtterance!.onError.listen((error) {
        print('❌ Erreur voix: $error');
        _isSpeaking = false;
      });
      
      html.window.speechSynthesis!.speak(_currentUtterance!);
      
    } catch (e) {
      print('❌ Erreur speak: $e');
      _isSpeaking = false;
    }
  }
  
  /// Arrêter la lecture
  static Future<void> stop() async {
    if (!kIsWeb) return;
    
    try {
      html.window.speechSynthesis?.cancel();
      _isSpeaking = false;
      _currentUtterance = null;
      print('🛑 Voix arrêtée');
    } catch (e) {
      print('❌ Erreur stop: $e');
    }
  }
  
  /// Mettre en pause
  static Future<void> pause() async {
    if (!kIsWeb) return;
    
    try {
      html.window.speechSynthesis?.pause();
      print('⏸️ Voix en pause');
    } catch (e) {
      print('❌ Erreur pause: $e');
    }
  }
  
  /// Reprendre
  static Future<void> resume() async {
    if (!kIsWeb) return;
    
    try {
      html.window.speechSynthesis?.resume();
      print('▶️ Voix reprise');
    } catch (e) {
      print('❌ Erreur resume: $e');
    }
  }
  
  /// Est en train de parler ?
  static bool get isSpeaking => _isSpeaking;
  
  /// Libérer les ressources
  static Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }
}

/// NOTES SUR WEB SPEECH API
/// 
/// Avantages :
/// - Natif au navigateur (pas d'API externe)
/// - 100% fiable
/// - Gratuit et illimité
/// - Voix françaises disponibles
/// - Fonctionne sur Chrome, Safari, Firefox
/// 
/// Qualité :
/// - Chrome/Edge : Très bonnes voix (Microsoft)
/// - Safari : Bonnes voix (Apple)
/// - Firefox : Correctes
/// 
/// Voix féminines françaises typiques :
/// - Chrome : "Google français" (féminine)
/// - Edge : "Microsoft Hortense" (féminine, douce)
/// - Safari : "Amélie" (féminine)
