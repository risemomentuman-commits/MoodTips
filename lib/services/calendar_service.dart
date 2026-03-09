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
  
  static Future<List<CalendarEventData>> getTodayEvents() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final calendarsResult = await _calendar.retrieveCalendars();
      final List<CalendarEventData> allEvents = [];
      final Set<String> seenEvents = {};

      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        for (final calendar in calendarsResult.data!) {
          final eventsResult = await _calendar.retrieveEvents(
            calendar.id,
            RetrieveEventsParams(
              startDate: startOfDay,
              endDate: endOfDay,
            ),
          );

          if (eventsResult.isSuccess && eventsResult.data != null) {
            for (final event in eventsResult.data!) {
              if (event.start == null) continue;
              if (event.allDay == true) continue;
              if (event.end == null) continue;

              // Déduplication simple
              final eventKey =
                  '${event.title}_${event.start!.toIso8601String()}_${event.end!.toIso8601String()}';
              if (seenEvents.contains(eventKey)) continue;
              seenEvents.add(eventKey);

              // Tronquer l'événement à la journée
              final effectiveStart =
                  event.start!.isBefore(startOfDay) ? startOfDay : event.start!;
              final effectiveEnd =
                  event.end!.isAfter(endOfDay) ? endOfDay : event.end!;

              final durationMinutes =
                  effectiveEnd.difference(effectiveStart).inMinutes;

              if (durationMinutes <= 0) continue;

              allEvents.add(
                CalendarEventData(
                  title: event.title ?? 'Sans titre',
                  startTime: effectiveStart,
                  isStressful: _isStressfulEvent(event.title ?? ''),
                  durationMinutes: durationMinutes,
                ),
              );
            }
          }
        }
      }

      allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
      print('📅 ${allEvents.length} événements trouvés pour aujourd’hui');
      return allEvents;
    } catch (e) {
      print('❌ Erreur récupération événements: $e');
      return [];
    }
  }
  
  static bool _isStressfulEvent(String title) {
    List<String> stressKeywords = [
      // Réunions
      'réunion', 'meeting', 'comité', 'standup', 'stand-up',
      'call', 'visio', 'conf', 'sync', 'review',
      // Présentations
      'présentation', 'presentation', 'démo', 'demo', 'pitch',
      // Entretiens
      'entretien', 'interview', 'recrutement',
      // Examens/Deadlines
      'examen', 'exam', 'deadline', 'rendu', 'livraison',
      // Médical
      'médecin', 'docteur', 'rdv', 'rendez-vous',
      // Pro stressant
      'bilan', 'évaluation', 'audit', 'urgence', 'urgent',
      'client', 'négociation', 'contrat',
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