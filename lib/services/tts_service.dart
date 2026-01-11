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
      // Web Speech API pour le web
      try {
        final utterance = html.SpeechSynthesisUtterance(text);
        utterance.lang = 'fr-FR';
        utterance.rate = 0.9;
        utterance.pitch = 1.0;
        utterance.volume = 1.0;
        
        html.window.speechSynthesis?.speak(utterance);
        _isSpeaking = true;
        
        utterance.onEnd.listen((event) {
          _isSpeaking = false;
        });
        
        print('🗣️ Web Speech: $text');
      } catch (e) {
        print('❌ Erreur Web Speech: $e');
      }
    } else {
      // Mobile (Android/iOS)
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