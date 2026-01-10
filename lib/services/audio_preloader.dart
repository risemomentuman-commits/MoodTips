import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioPreloader {
  static final Map<String, AudioPlayer> _preloadedPlayers = {};
  static bool _isPreloaded = false;

  static Future<void> preloadAudio() async {
    if (_isPreloaded) return;

    final audioFiles = [
      'rain.mp3',
      'relaxation.mp3',
      'ocean.mp3',
      'meditation.mp3',
      'energetic.mp3',
      'nature_rain.mp3',
      'forest.mp3',
      'nature_waves.mp3',
      'whitenoise.mp3',
      'piano.mp3',
      // Ajoutez tous vos fichiers
    ];

    for (final file in audioFiles) {
      try {
        final player = AudioPlayer();
        await player.setSource(AssetSource('audio/$file'));
        await player.setVolume(0); // Volume 0 pour le préchargement
        _preloadedPlayers[file] = player;
        print('✅ Préchargé : $file');
      } catch (e) {
        print('❌ Erreur préchargement $file : $e');
      }
    }

    _isPreloaded = true;
  }

  static AudioPlayer? getPlayer(String filename) {
    return _preloadedPlayers[filename];
  }

  static void dispose() {
    for (final player in _preloadedPlayers.values) {
      player.dispose();
    }
    _preloadedPlayers.clear();
    _isPreloaded = false;
  }
}