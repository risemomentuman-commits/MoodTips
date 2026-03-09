import 'package:supabase_flutter/supabase_flutter.dart';

enum EventCategory {
  workMeeting,
  workDeep,
  workAdmin,
  personalPositive,
  personalSocial,
  personalHealth,
  personalAdmin,
  recovery,
  unknown,
}

class EventClassifierService {
  final SupabaseClient _client;

  EventClassifierService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // Mots-clés par catégorie
  static const Map<EventCategory, List<String>> _keywords = {
    EventCategory.workMeeting: [
      'réunion', 'meeting', 'call', 'sync', 'standup',
      'point', 'review', 'retro', 'sprint', 'daily',
    ],
    EventCategory.workDeep: [
      'focus', 'deep work', 'concentration', 'dev',
      'coding', 'rédaction', 'analyse',
    ],
    EventCategory.workAdmin: [
      'admin', 'email', 'paperasse', 'compta',
      'facturation', 'déclaration',
    ],
    EventCategory.personalPositive: [
      'sport', 'yoga', 'méditation', 'course',
      'marche', 'gym', 'vélo', 'natation',
      'ami', 'resto', 'cinéma', 'sortie', 'fête',
    ],
    EventCategory.personalSocial: [
      'dîner', 'déjeuner', 'apéro', 'famille',
      'brunch', 'soirée',
    ],
    EventCategory.personalHealth: [
      'médecin', 'docteur', 'dentiste', 'kiné',
      'psy', 'ostéo', 'rdv santé', 'pharmacie',
    ],
    EventCategory.personalAdmin: [
      'banque', 'impôts', 'assurance', 'notaire',
      'avocat', 'démarche', 'préfecture',
    ],
    EventCategory.recovery: [
      'repos', 'sieste', 'pause', 'détente',
      'relaxation', 'off', 'congé', 'vacances',
    ],
  };

  /// Classifie un événement par son titre
  Future<EventCategory> classifyEvent(
    String title,
    String userId,
  ) async {
    final titleLower = title.toLowerCase().trim();

    // 1. Chercher un pattern appris par l'utilisateur
    final learned = await _getLearnedCategory(titleLower, userId);
    if (learned != null) return learned;

    // 2. Classification par mots-clés
    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        if (titleLower.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return EventCategory.unknown;
  }

  /// Vérifie si un pattern a déjà été appris
  Future<EventCategory?> _getLearnedCategory(
    String title,
    String userId,
  ) async {
    final response = await _client
        .from('user_event_classifications')
        .select()
        .eq('user_id', userId)
        .order('times_confirmed', ascending: false);

    for (final row in response as List) {
      final pattern = (row['event_title_pattern'] as String).toLowerCase();
      if (title.contains(pattern)) {
        return _categoryFromString(row['category'] as String);
      }
    }
    return null;
  }

  /// Enregistre/confirme une classification utilisateur
  Future<void> confirmClassification({
    required String userId,
    required String eventTitle,
    required EventCategory category,
  }) async {
    final pattern = eventTitle.toLowerCase().trim();
    final categoryStr = category.name;

    // Upsert : incrémenter si existe, créer sinon
    final existing = await _client
        .from('user_event_classifications')
        .select()
        .eq('user_id', userId)
        .eq('event_title_pattern', pattern)
        .maybeSingle();

    if (existing != null) {
      await _client.from('user_event_classifications').update({
        'category': categoryStr,
        'times_confirmed': (existing['times_confirmed'] as int) + 1,
      }).eq('id', existing['id']);
    } else {
      await _client.from('user_event_classifications').insert({
        'user_id': userId,
        'event_title_pattern': pattern,
        'category': categoryStr,
        'times_confirmed': 1,
      });
    }
  }

  /// Classifie une liste d'événements et retourne les compteurs
  Future<Map<String, int>> classifyEvents(
    List<String> titles,
    String userId,
  ) async {
    int work = 0;
    int positive = 0;
    int total = titles.length;

    for (final title in titles) {
      final cat = await classifyEvent(title, userId);
      if (cat == EventCategory.workMeeting ||
          cat == EventCategory.workDeep ||
          cat == EventCategory.workAdmin) {
        work++;
      } else if (cat == EventCategory.personalPositive ||
          cat == EventCategory.personalSocial ||
          cat == EventCategory.personalHealth ||
          cat == EventCategory.recovery) {
        positive++;
      }
    }

    return {
      'total': total,
      'work': work,
      'positive': positive,
    };
  }

  static EventCategory _categoryFromString(String value) {
    return EventCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventCategory.unknown,
    );
  }

  /// Indique si c'est un événement positif
  static bool isPositive(EventCategory cat) {
    return cat == EventCategory.personalPositive ||
        cat == EventCategory.personalSocial ||
        cat == EventCategory.personalHealth ||
        cat == EventCategory.recovery;
  }

  /// Indique si c'est un événement pro
  static bool isWork(EventCategory cat) {
    return cat == EventCategory.workMeeting ||
        cat == EventCategory.workDeep ||
        cat == EventCategory.workAdmin;
  }
}