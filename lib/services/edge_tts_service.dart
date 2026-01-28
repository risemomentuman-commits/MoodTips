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
    
    // Arrêter toute voix en cours
    if (_isSpeaking) {
      await stop();
    }
    
    try {
      _isSpeaking = true;
      
      // Créer l'utterance
      _currentUtterance = html.SpeechSynthesisUtterance(text);
      
      // Sélectionner une voix française
      final voices = html.window.speechSynthesis!.getVoices();
      final frenchVoice = voices.firstWhere(
        (v) => v.lang?.startsWith('fr-FR') == true && v.name?.contains('Female') == true,
        orElse: () => voices.firstWhere(
          (v) => v.lang?.startsWith('fr') == true,
          orElse: () => voices.first,
        ),
      );
      
      _currentUtterance!.voice = frenchVoice;
      
      // Configuration pour voix douce et naturelle
      _currentUtterance!.rate = 0.85;  // Vitesse (0.8 = un peu plus lent que normal)
      _currentUtterance!.pitch = 1.0;  // Ton normal
      _currentUtterance!.volume = 1.0; // Volume max
      
      print('🎙️ Parle avec voix: ${frenchVoice.name}');
      
      // Écouter la fin
      _currentUtterance!.onEnd.listen((_) {
        print('✅ Voix terminée');
        _isSpeaking = false;
      });
      
      // Écouter les erreurs
      _currentUtterance!.onError.listen((error) {
        print('❌ Erreur voix: $error');
        _isSpeaking = false;
      });
      
      // Lancer la synthèse
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
