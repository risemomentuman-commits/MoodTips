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

  /// Récupère les événements RESTANTS de la journée (de maintenant → 23h59)
  static Future<List<CalendarEventData>> getTodayEvents() async {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Si on est après 23h, plus rien à affronter
    if (now.isAfter(endOfDay)) return [];

    try {
      final calendarsResult = await _calendar.retrieveCalendars();
      final List<CalendarEventData> allEvents = [];
      final Set<String> seenEvents = {};

      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        for (final calendar in calendarsResult.data!) {
          final eventsResult = await _calendar.retrieveEvents(
            calendar.id,
            RetrieveEventsParams(
              startDate: now,       // ✅ À partir de maintenant
              endDate: endOfDay,    // ✅ Jusqu'à fin de journée
            ),
          );

          if (eventsResult.isSuccess && eventsResult.data != null) {
            for (final event in eventsResult.data!) {
              if (event.start == null) continue;
              if (event.allDay == true) continue;
              if (event.end == null) continue;

              // Ignorer les événements déjà terminés
              if (event.end!.isBefore(now)) continue;

              // Déduplication
              final eventKey =
                  '${event.title}_${event.start!.toIso8601String()}_${event.end!.toIso8601String()}';
              if (seenEvents.contains(eventKey)) continue;
              seenEvents.add(eventKey);

              // Tronquer : si l'événement a commencé avant maintenant,
              // ne compter que la partie restante
              final effectiveStart =
                  event.start!.isBefore(now) ? now : event.start!;
              final effectiveEnd =
                  event.end!.isAfter(endOfDay) ? endOfDay : event.end!;

              final durationMinutes =
                  effectiveEnd.difference(effectiveStart).inMinutes;

              if (durationMinutes <= 0) continue;

              final title = event.title ?? 'Sans titre';
              final category = _categorizeEvent(title);

              allEvents.add(
                CalendarEventData(
                  title: title,
                  startTime: effectiveStart,
                  durationMinutes: durationMinutes,
                  category: category,
                ),
              );
            }
          }
        }
      }

      allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Log détaillé
      final totalImpact = allEvents.fold<double>(0, (sum, e) => sum + e.weightedImpact);
      print('📅 ${allEvents.length} événements restants aujourd\'hui');
      for (final e in allEvents) {
        print('   → ${e.title} | ${e.category.label} (impact: ${e.category.impactWeight}) | ${e.durationMinutes}min');
      }
      print('📊 Impact pondéré total: ${totalImpact.toStringAsFixed(1)}');

      return allEvents;
    } catch (e) {
      print('❌ Erreur récupération événements: $e');
      return [];
    }
  }

  // ─── CATÉGORISATION INTELLIGENTE ────────────────────────

  static EventCategory _categorizeEvent(String title) {
    final lower = title.toLowerCase();

    // === RÉCUPÉRATION (score négatif = bénéfique) ===
    if (_matchesAny(lower, _recoveryKeywords)) return EventCategory.recovery;

    // === SPORT (score négatif = régulateur) ===
    if (_matchesAny(lower, _sportKeywords)) return EventCategory.sport;

    // === TRAVAIL - LEADERSHIP (impact 5) ===
    if (_matchesAny(lower, _workLeadershipKeywords)) return EventCategory.workLeadership;

    // === TRAVAIL - CLIENT (impact 4) ===
    if (_matchesAny(lower, _workClientKeywords)) return EventCategory.workClient;

    // === TRAVAIL - DEEP WORK (impact 4) ===
    if (_matchesAny(lower, _workDeepKeywords)) return EventCategory.workDeep;

    // === TRAVAIL - RÉUNION STANDARD (impact 3) ===
    if (_matchesAny(lower, _workMeetingKeywords)) return EventCategory.workMeeting;

    // === TRAVAIL - ADMIN (impact 2) ===
    if (_matchesAny(lower, _workAdminKeywords)) return EventCategory.workAdmin;

    // === PERSO - SANTÉ (impact 3) ===
    if (_matchesAny(lower, _personalHealthKeywords)) return EventCategory.personalHealth;

    // === PERSO - ADMIN (impact 2) ===
    if (_matchesAny(lower, _personalAdminKeywords)) return EventCategory.personalAdmin;

    // === PERSO - FAMILLE (impact 2) ===
    if (_matchesAny(lower, _personalFamilyKeywords)) return EventCategory.personalFamily;

    // === DÉPLACEMENT (impact 2) ===
    if (_matchesAny(lower, _travelKeywords)) return EventCategory.travel;

    // === PERSO - SOCIAL (impact 1) ===
    if (_matchesAny(lower, _personalSocialKeywords)) return EventCategory.personalSocial;

    // === PERSO - LOGISTIQUE (impact 1) ===
    if (_matchesAny(lower, _personalLogisticsKeywords)) return EventCategory.personalLogistics;

    // === NON RECONNU ===
    return EventCategory.unknown;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  // ─── DICTIONNAIRES DE MOTS-CLÉS ────────────────────────

  static const _workLeadershipKeywords = [
    // Direction / Gouvernance
    'codir', 'comex', 'comité de direction', 'comité exécutif',
    'board', 'conseil d\'administration', 'assemblée générale',
    'strategic review', 'revue stratégique',
    // Entretiens RH critiques
    'entretien annuel', 'évaluation annuelle', 'plan de performance',
    'licenciement', 'restructuration',
  ];

  static const _workClientKeywords = [
    // Ventes / Commercial
    'client', 'prospect', 'pitch', 'démo client', 'demo client',
    'soutenance', 'appel d\'offres', 'appel d\'offre',
    'négociation', 'negociation', 'closing', 'signature',
    'contrat', 'partenaire', 'partenariat',
    // Présentation externe
    'keynote', 'conférence', 'webinar', 'webinaire',
    'salon', 'événement',
  ];

  static const _workDeepKeywords = [
    // Deadlines / Livrables
    'deadline', 'livraison', 'rendu', 'release', 'mise en prod',
    'go live', 'go-live', 'lancement',
    // Audit / Examen
    'audit', 'inspection', 'certification', 'examen', 'exam',
    'concours', 'test technique',
    // Urgences
    'urgence', 'urgent', 'crise', 'incident', 'escalade',
  ];

  static const _workMeetingKeywords = [
    // Réunions standard
    'réunion', 'reunion', 'meeting', 'visio', 'visioconférence',
    'call', 'conf call', 'conférence téléphonique',
    'standup', 'stand-up', 'daily', 'weekly', 'sync',
    'point', 'point d\'équipe', 'point projet',
    'review', 'retro', 'rétrospective', 'sprint',
    'brainstorm', 'atelier', 'workshop',
    '1:1', 'one-on-one', 'one on one', '1-1',
    'catch up', 'catch-up', 'debrief',
  ];

  static const _workAdminKeywords = [
    // Admin / Formation
    'formation', 'training', 'onboarding', 'intégration',
    'e-learning', 'elearning', 'mooc',
    'admin', 'administratif', 'paperasse',
    'note de frais', 'timesheet', 'rapport',
    'rh', 'ressources humaines', 'mutuelle',
  ];

  static const _personalHealthKeywords = [
    // Médical
    'médecin', 'medecin', 'docteur', 'dr ', 'dr.',
    'dentiste', 'ophtalmo', 'dermato', 'cardio',
    'kiné', 'kine', 'ostéo', 'osteo', 'ostéopathe',
    'psy', 'psychologue', 'psychiatre', 'thérapeute',
    'hôpital', 'hopital', 'clinique', 'urgences',
    'radio', 'scanner', 'irm', 'prise de sang', 'labo',
    'pharmacie', 'ordonnance', 'vaccin', 'vaccination',
    'chirurgien', 'opération', 'rdv médical', 'rdv santé',
  ];

  static const _personalAdminKeywords = [
    // Admin perso
    'banque', 'assurance', 'impôts', 'impots', 'trésor public',
    'notaire', 'avocat', 'huissier', 'tribunal',
    'préfecture', 'prefecture', 'mairie', 'caf',
    'pôle emploi', 'pole emploi', 'cpam', 'sécu',
    'dossier', 'papiers', 'déclaration',
  ];

  static const _personalFamilyKeywords = [
    // Famille / Enfants
    'école', 'ecole', 'crèche', 'creche', 'garderie',
    'périscolaire', 'cantine', 'sortie scolaire',
    'réunion parents', 'conseil de classe',
    'pédiatre', 'pediatre',
    'famille', 'enfants', 'bébé', 'bebe',
    'anniversaire enfant',
  ];

  static const _personalSocialKeywords = [
    // Social / Loisirs
    'déjeuner', 'dejeuner', 'dîner', 'diner', 'brunch',
    'apéro', 'apero', 'afterwork', 'after-work',
    'soirée', 'soiree', 'fête', 'fete',
    'café', 'verre', 'boire un', 'resto',
    'cinéma', 'cinema', 'théâtre', 'theatre', 'concert',
    'expo', 'musée', 'musee', 'spectacle',
    'amis', 'copains', 'potes',
    'anniversaire', 'mariage', 'baptême',
  ];

  static const _personalLogisticsKeywords = [
    // Logistique / Maison
    'courses', 'supermarché', 'marché', 'drive',
    'ménage', 'menage', 'nettoyage', 'repassage',
    'plombier', 'électricien', 'serrurier', 'artisan',
    'déménagement', 'demenagement', 'emménagement',
    'livraison', 'colis', 'la poste',
    'garage', 'contrôle technique', 'vidange', 'mécano',
    'bricolage', 'jardinage', 'tonte',
    'rdv technique', 'technicien', 'internet', 'fibre',
    'pain', 'boulangerie', 'pressing',
  ];

  static const _sportKeywords = [
    // Sport / Exercice
    'sport', 'gym', 'salle de sport', 'musculation',
    'course', 'running', 'jogging', 'footing',
    'yoga', 'pilates', 'stretching', 'étirements',
    'piscine', 'natation', 'aqua',
    'vélo', 'velo', 'cycling', 'vtt',
    'tennis', 'padel', 'squash', 'badminton',
    'foot', 'football', 'basket', 'volley',
    'boxe', 'arts martiaux', 'judo', 'karaté',
    'escalade', 'randonnée', 'rando', 'marche',
    'crossfit', 'hiit', 'cardio', 'training',
    'coach sportif', 'entraînement', 'entrainement',
    'match', 'compétition',
  ];

  static const _recoveryKeywords = [
    // Récupération / Bien-être
    'massage', 'spa', 'hammam', 'sauna', 'jacuzzi',
    'méditation', 'meditation', 'sophrologie', 'relaxation',
    'sieste', 'repos', 'récupération', 'recuperation',
    'acupuncture', 'réflexologie', 'reflexologie',
    'bain', 'detox', 'bien-être', 'bien être',
    'coiffeur', 'coiffeuse', 'esthéticienne', 'manucure',
  ];

  static const _travelKeywords = [
    // Déplacements
    'trajet', 'déplacement', 'deplacement',
    'train', 'tgv', 'ter', 'sncf',
    'vol', 'avion', 'aéroport', 'aeroport',
    'taxi', 'uber', 'vtc',
    'route', 'autoroute', 'covoiturage',
    'voyage', 'aller-retour', 'transfert',
  ];

  // ─── HELPERS POUR L'IRM CALCULATOR ──────────────────────

  /// Score d'impact pondéré total (charge - récupération)
  static double calculateWeightedImpact(List<CalendarEventData> events) {
    return events.fold<double>(0, (sum, e) => sum + e.weightedImpact);
  }

  /// Heures de réunions (événements avec impact >= 3)
  static double calculateMeetingHours(List<CalendarEventData> events) {
    return events
        .where((e) => e.category.impactWeight >= 3)
        .fold<double>(0, (sum, e) => sum + e.durationHours);
  }

  /// Nombre d'événements pro (impact >= 2, hors sport/recovery)
  static int countWorkEvents(List<CalendarEventData> events) {
    return events
        .where((e) =>
            e.category.impactWeight >= 2 &&
            e.category != EventCategory.sport &&
            e.category != EventCategory.recovery &&
            e.category != EventCategory.travel)
        .length;
  }

  /// Nombre d'événements positifs (sport + recovery)
  static int countPositiveEvents(List<CalendarEventData> events) {
    return events
        .where((e) => e.category.impactWeight < 0)
        .length;
  }

  // ─── SAUVEGARDE CONNEXION ───────────────────────────────

  static Future<void> _saveConnectionStatus(String source, bool active) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('user_data_sources').upsert(
      {
        'user_id': userId,
        'source_type': source,
        'is_active': active,
        'last_sync_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,source_type',
    );
  }
}