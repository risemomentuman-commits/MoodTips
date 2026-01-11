import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:html' as html;

class TtsService {
  static FlutterTts? _flutterTts;
  static bool _isSpeaking = false;

  static Future<void> initialize() async {
    if (!kIsWeb) {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage("fr-FR");
      await _flutterTts!.setSpeechRate(0.45);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
    }
  }

  static Future<void> speak(String text) async {
    if (kIsWeb) {
      try {
        final utterance = html.SpeechSynthesisUtterance(text);
        utterance.lang = 'fr-FR';
        utterance.rate = 0.85;    // Plus lent = plus doux
        utterance.pitch = 1.15;   // Plus aigu = plus doux
        utterance.volume = 0.85;  // Moins fort
        
        // Essayer de sélectionner une voix féminine française
        final voices = html.window.speechSynthesis?.getVoices();
        if (voices != null && voices.isNotEmpty) {
          final frenchVoice = voices.firstWhere(
            (voice) => 
              (voice.lang?.startsWith('fr') ?? false) && 
              ((voice.name?.toLowerCase().contains('female') ?? false) ||
              (voice.name?.toLowerCase().contains('femme') ?? false) ||
              (voice.name?.toLowerCase().contains('google') ?? false)),
            orElse: () => voices.first,
          );
          utterance.voice = frenchVoice;
          print('🗣️ Voix: ${frenchVoice.name}');
        }
        
        html.window.speechSynthesis?.speak(utterance);
        _isSpeaking = true;
        
        utterance.onEnd.listen((event) {
          _isSpeaking = false;
        });
        
        print('🗣️ TTS: $text');
      } catch (e) {
        print('❌ Erreur TTS: $e');
      }
    } else {
      // Mobile
      await _flutterTts?.speak(text);
      _isSpeaking = true;
    }
  }

  static Future<void> stop() async {
    if (kIsWeb) {
      html.window.speechSynthesis?.cancel();
    } else {
      await _flutterTts?.stop();
    }
    _isSpeaking = false;
  }

  static bool get isSpeaking => _isSpeaking;

  static void dispose() {
    if (!kIsWeb) {
      _flutterTts?.stop();
    } else {
      html.window.speechSynthesis?.cancel();
    }
  }
}