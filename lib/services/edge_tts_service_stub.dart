// Stub pour mobile
class EdgeTtsService {
  static Future<void> speak(String text) async {}
  static void stop() {}
  static void pause() {}
  static void resume() {}
}
// Stub pour mobile (Android/iOS)
class EdgeTtsService {
  static bool get isSupported => false;
  
  static Future<void> initialize() async {}
  
  static Future<List<String>> getAvailableVoices() async => [];
  
  static Future<void> speak(String text, {
    String? voiceName,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    print('🔇 TTS non disponible sur mobile');
  }
  
  static void stop() {}
  
  static void pause() {}
  
  static void resume() {}
  
  static bool get isSpeaking => false;
  
  static bool get isPaused => false;
}