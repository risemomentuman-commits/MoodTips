// Stub pour mobile (Android/iOS)
class WebNotificationService {
  static Future<bool> requestPermissionAndRegisterToken() async => false;
  static Future<void> setNotificationsEnabled(bool enabled) async {}
  static Future<bool> areNotificationsEnabled() async => false;
  static void setLocalEnabled(bool value) {}
}