import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de gestion des consentements CGU et IRM v2
/// 
/// Gère la vérification, l'enregistrement et le retrait
/// des consentements utilisateur conformément au RGPD.
class ConsentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Version actuelle des CGU — À METTRE À JOUR à chaque nouvelle version
  static const String currentCguVersion = '2.0';

  /// Version actuelle du consentement IRM v2
  static const String currentIrmVersion = '2.0';

  // ======================== VÉRIFICATIONS ========================

  /// Vérifie si l'utilisateur a accepté la version actuelle des CGU
  Future<bool> hasCguAccepted() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('cgu_version_accepted')
          .eq('id', userId)
          .single();

      return response['cgu_version_accepted'] == currentCguVersion;
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si l'utilisateur a donné son consentement IRM v2
  Future<bool> hasIrmConsent() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('irm_consent')
          .eq('id', userId)
          .single();

      return response['irm_consent'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Vérifie tous les consentements nécessaires
  /// Retourne un objet indiquant quels consentements manquent
  Future<ConsentStatus> checkAllConsents() async {
    final cguOk = await hasCguAccepted();
    final irmOk = await hasIrmConsent();
    return ConsentStatus(cguAccepted: cguOk, irmConsented: irmOk);
  }

  // ======================== ENREGISTREMENT ========================

  /// Enregistre l'acceptation des CGU
  Future<bool> acceptCgu() async {
    try {
      await _supabase.rpc('record_consent', params: {
        'p_consent_type': 'cgu',
        'p_action': 'accepted',
        'p_version': currentCguVersion,
      });
      return true;
    } catch (e) {
      print('Erreur acceptation CGU: $e');
      return false;
    }
  }

  /// Enregistre le consentement IRM v2
  Future<bool> acceptIrmConsent() async {
    try {
      await _supabase.rpc('record_consent', params: {
        'p_consent_type': 'irm_v2',
        'p_action': 'accepted',
        'p_version': currentIrmVersion,
      });
      return true;
    } catch (e) {
      print('Erreur consentement IRM: $e');
      return false;
    }
  }

  /// Retire le consentement IRM v2 (droit de retrait RGPD)
  Future<bool> withdrawIrmConsent() async {
    try {
      await _supabase.rpc('record_consent', params: {
        'p_consent_type': 'irm_v2',
        'p_action': 'withdrawn',
        'p_version': currentIrmVersion,
      });
      return true;
    } catch (e) {
      print('Erreur retrait consentement IRM: $e');
      return false;
    }
  }

  // ======================== HISTORIQUE ========================

  /// Récupère l'historique des consentements de l'utilisateur
  Future<List<Map<String, dynamic>>> getConsentHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('consent_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}

/// État des consentements de l'utilisateur
class ConsentStatus {
  final bool cguAccepted;
  final bool irmConsented;

  ConsentStatus({
    required this.cguAccepted,
    required this.irmConsented,
  });

  /// Indique si tous les consentements obligatoires sont en place
  bool get allRequiredConsentsGiven => cguAccepted;

  /// Indique si le consentement IRM est manquant
  /// (pas obligatoire, mais nécessaire pour les fonctionnalités IRM v2)
  bool get irmConsentMissing => !irmConsented;
}