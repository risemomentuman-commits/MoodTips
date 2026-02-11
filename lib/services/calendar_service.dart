import 'package:device_calendar/device_calendar.dart';
import '../models/health_context_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarService {
  static final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();
  
  static Future<bool> requestPermissions() async {
    try {
      var permissionsGranted = await _calendar.requestPermissions();
      
      if (permissionsGranted.isSuccess && permissionsGranted.data == true) {
        await _saveConnectionStatus('calendar', true);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erreur permissions calendrier: $e');
      return false;
    }
  }
  
  static Future<List<CalendarEventData>> getUpcomingEvents() async {
    DateTime now = DateTime.now();
    DateTime tomorrow = now.add(Duration(hours: 24));
    
    try {
      final calendarsResult = await _calendar.retrieveCalendars();
      List<CalendarEventData> allEvents = [];
      
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        for (var calendar in calendarsResult.data!) {
          final eventsResult = await _calendar.retrieveEvents(
            calendar.id,
            RetrieveEventsParams(startDate: now, endDate: tomorrow),
          );
          
          if (eventsResult.isSuccess && eventsResult.data != null) {
            for (var event in eventsResult.data!) {
              allEvents.add(CalendarEventData(
                title: event.title ?? 'Sans titre',
                startTime: event.start!,
                isStressful: _isStressfulEvent(event.title ?? ''),
              ));
            }
          }
        }
      }
      
      allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
      return allEvents;
    } catch (e) {
      print('❌ Erreur récupération événements: $e');
      return [];
    }
  }
  
  static bool _isStressfulEvent(String title) {
    List<String> stressKeywords = [
      'réunion', 'meeting', 'comité',
      'présentation', 'presentation',
      'entretien', 'interview',
      'examen', 'exam'
    ];
    
    String lowerTitle = title.toLowerCase();
    return stressKeywords.any((keyword) => lowerTitle.contains(keyword));
  }
  
  static Future<void> _saveConnectionStatus(String source, bool active) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    
    // ✅ CORRECTION : Spécifier les colonnes de conflit pour le upsert
    await Supabase.instance.client.from('user_data_sources').upsert(
      {
        'user_id': userId,
        'source_type': source,
        'is_active': active,
        'last_sync_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(), // ✅ Ajouter aussi
      },
      onConflict: 'user_id,source_type', // ✅ IMPORTANT : Spécifier les colonnes uniques
    );
  }
}