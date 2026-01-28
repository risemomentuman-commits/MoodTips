import 'dart:js_util' as js_util;

Future<String?> getFcmTokenFromWebJs(String vapidKey) async {
  try {
    final token = await js_util.promiseToFuture<String?>(
      js_util.callMethod(js_util.globalThis, 'getFcmTokenFromWeb', [vapidKey]),
    );
    return token;
  } catch (e) {
    // Tu verras l'erreur dans la console navigateur
    // (service worker pas trouvé, etc.)
    // Ne crash pas l'app
    // ignore: avoid_print
    print('❌ [FCM][JS] getToken error: $e');
    return null;
  }
}
