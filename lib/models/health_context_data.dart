class HealthContextData {
  final SleepData? sleep;
  final ActivityData? activity;
  final DateTime retrievedAt;

  HealthContextData({
    this.sleep,
    this.activity,
    required this.retrievedAt,
  });
}

class SleepData {
  final double durationHours;
  final int qualityScore;

  SleepData({
    required this.durationHours,
    required this.qualityScore,
  });
}

class ActivityData {
  final int steps;
  final int activeMinutes;

  ActivityData({
    required this.steps,
    required this.activeMinutes,
  });
}

// ─── CATÉGORIES D'ÉVÉNEMENTS ────────────────────────────

enum EventCategory {
  workLeadership,    // CODIR, board, comex, assemblée
  workClient,        // négo client, pitch, démo, soutenance
  workMeeting,       // réunion, call, standup, visio, sync
  workDeep,          // deadline, livraison, audit, examen
  workAdmin,         // formation, onboarding, admin pro
  personalHealth,    // médecin, dentiste, kiné, psy
  personalAdmin,     // banque, impôts, assurance, notaire
  personalFamily,    // école, crèche, famille, enfants
  personalSocial,    // déjeuner amis, afterwork, apéro, dîner
  personalLogistics, // courses, ménage, rdv technique, plombier
  sport,             // salle, course, yoga, piscine, vélo
  recovery,          // massage, méditation, sieste, spa
  travel,            // trajet, vol, train, déplacement
  unknown,           // non reconnu → défaut prudent
}

extension EventCategoryImpact on EventCategory {
  /// Score d'impact sur la charge mentale
  /// Positif = charge, Négatif = récupération
  int get impactWeight {
    switch (this) {
      case EventCategory.workLeadership:
        return 5;
      case EventCategory.workClient:
        return 4;
      case EventCategory.workDeep:
        return 4;
      case EventCategory.workMeeting:
        return 3;
      case EventCategory.workAdmin:
        return 2;
      case EventCategory.personalHealth:
        return 3;
      case EventCategory.personalAdmin:
        return 2;
      case EventCategory.personalFamily:
        return 2;
      case EventCategory.personalSocial:
        return 1;
      case EventCategory.personalLogistics:
        return 1;
      case EventCategory.travel:
        return 2;
      case EventCategory.sport:
        return -1;
      case EventCategory.recovery:
        return -2;
      case EventCategory.unknown:
        return 2;
    }
  }

  String get label {
    switch (this) {
      case EventCategory.workLeadership:
        return 'Direction';
      case EventCategory.workClient:
        return 'Client';
      case EventCategory.workDeep:
        return 'Travail intense';
      case EventCategory.workMeeting:
        return 'Réunion';
      case EventCategory.workAdmin:
        return 'Admin pro';
      case EventCategory.personalHealth:
        return 'Santé';
      case EventCategory.personalAdmin:
        return 'Admin perso';
      case EventCategory.personalFamily:
        return 'Famille';
      case EventCategory.personalSocial:
        return 'Social';
      case EventCategory.personalLogistics:
        return 'Logistique';
      case EventCategory.travel:
        return 'Déplacement';
      case EventCategory.sport:
        return 'Sport';
      case EventCategory.recovery:
        return 'Récupération';
      case EventCategory.unknown:
        return 'Autre';
    }
  }
}

// ─── ÉVÉNEMENT CALENDRIER ───────────────────────────────

class CalendarEventData {
  final String title;
  final DateTime startTime;
  final int durationMinutes;
  final EventCategory category;

  CalendarEventData({
    required this.title,
    required this.startTime,
    this.durationMinutes = 30,
    this.category = EventCategory.unknown,
  });

  double get durationHours => durationMinutes / 60.0;

  /// Impact pondéré = poids × durée en heures
  double get weightedImpact => category.impactWeight * durationHours;

  /// Rétrocompatibilité
  bool get isStressful => category.impactWeight >= 3;
}