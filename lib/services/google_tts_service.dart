import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

enum TTSGender { female, male }

class GoogleTTSService {
  static const String _apiKey = 'AIzaSyBaVo_ZDYNXWq8ozoz87bU6K1i8MAdEPuA';
  static const String _apiUrl = 'https://texttospeech.googleapis.com/v1/text:synthesize';
  static final Map<String, String> _audioCache = {};

  static TTSGender _gender = TTSGender.female;
  static AudioPlayer? _player;

  // Voix Neural2 françaises naturelles
  static const Map<TTSGender, String> _voices = {
    TTSGender.female: 'fr-FR-Neural2-A', // Douce et naturelle
    TTSGender.male:   'fr-FR-Neural2-B', // Posé et grave
  };

  static Future<void> initialize() async {
    if (kIsWeb) return;
    _player = AudioPlayer();
    await _loadSavedGender();
    print('✅ Google TTS initialisé - ${_gender.name}');
  }

  static Future<void> speak(String text) async {
    if (kIsWeb) return;
    if (_player == null) await initialize();

    try {
      final cacheKey = '${_gender.name}_$text';
      
      Uint8List bytes;
      
      if (_audioCache.containsKey(cacheKey)) {
        // ✅ Utilise le cache
        bytes = base64Decode(_audioCache[cacheKey]!);
        print('⚡ Cache TTS utilisé');
      } else {
        // 🌐 Appel API
        final response = await http.post(
          Uri.parse('$_apiUrl?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'input': {'text': text},
            'voice': {
              'languageCode': 'fr-FR',
              'name': _voices[_gender],
            },
            'audioConfig': {
              'audioEncoding': 'MP3',
              'speakingRate': 0.85,
              'pitch': _gender == TTSGender.female ? 0.0 : -2.0,
            },
          }),
        );

        if (response.statusCode != 200) {
          print('❌ Erreur Google TTS: ${response.statusCode}');
          return;
        }

        final data = jsonDecode(response.body);
        final audioContent = data['audioContent'] as String;
        _audioCache[cacheKey] = audioContent; // ✅ Sauvegarde en cache
        bytes = base64Decode(audioContent);
      }

      await _playBytes(bytes);
    } catch (e) {
      print('❌ Erreur Google TTS: $e');
    }
  }

  static Future<void> _playBytes(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_output.mp3');
      await file.writeAsBytes(bytes);
      
      await _player!.stop();
      await _player!.setAudioSource(
        AudioSource.file(
          file.path,
          tag: MediaItem(
            id: 'tts_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Exercice guidé',
            artist: 'MoodTips',
          ),
        ),
      );
      await _player!.play();
    } catch (e) {
      print('❌ Erreur lecture audio: $e');
    }
  }

  static Future<void> stop() async {
    await _player?.stop();
  }

  static Future<void> setGender(TTSGender gender) async {
    _gender = gender;
    await _saveGender(gender);
    print('🎙️ Voix changée: ${_voices[gender]}');
  }

  static TTSGender get currentGender => _gender;

  static Future<void> _saveGender(TTSGender gender) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'tts_gender': gender.name})
          .eq('id', userId);
    } catch (_) {}
  }

  static Future<void> _loadSavedGender() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('tts_gender')
          .eq('id', userId)
          .maybeSingle();
      _gender = profile?['tts_gender'] == 'male'
          ? TTSGender.male
          : TTSGender.female;
    } catch (_) {}
  }

  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}