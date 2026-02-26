import 'package:flutter/material.dart';
import '../services/consent_service.dart';

/// Widget de gestion du consentement IRM v2 pour la page des paramètres
/// 
/// Permet à l'utilisateur d'activer/désactiver le traitement IRM v2
/// à tout moment (droit de retrait du consentement RGPD).
/// 
/// Exemple d'utilisation dans ta page de paramètres :
/// ```dart
/// IrmConsentToggle(
///   onConsentChanged: (isEnabled) {
///     // Adapter l'UI ou les fonctionnalités en conséquence
///   },
/// )
/// ```
class IrmConsentToggle extends StatefulWidget {
  /// Callback appelé quand le consentement change
  final ValueChanged<bool>? onConsentChanged;

  const IrmConsentToggle({
    super.key,
    this.onConsentChanged,
  });

  @override
  State<IrmConsentToggle> createState() => _IrmConsentToggleState();
}

class _IrmConsentToggleState extends State<IrmConsentToggle> {
  final ConsentService _consentService = ConsentService();

  bool _irmEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsentStatus();
  }

  Future<void> _loadConsentStatus() async {
    final hasConsent = await _consentService.hasIrmConsent();
    if (mounted) {
      setState(() {
        _irmEnabled = hasConsent;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleConsent(bool newValue) async {
    // Si l'utilisateur désactive, demander confirmation
    if (!newValue) {
      final confirmed = await _showWithdrawDialog();
      if (!confirmed) return;
    }

    // Si l'utilisateur active, afficher les explications
    if (newValue) {
      final accepted = await _showActivateDialog();
      if (!accepted) return;
    }

    setState(() => _isLoading = true);

    bool success;
    if (newValue) {
      success = await _consentService.acceptIrmConsent();
    } else {
      success = await _consentService.withdrawIrmConsent();
    }

    if (success && mounted) {
      setState(() {
        _irmEnabled = newValue;
        _isLoading = false;
      });
      widget.onConsentChanged?.call(newValue);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'Recommandations intelligentes activées'
                : 'Recommandations intelligentes désactivées',
          ),
          backgroundColor: newValue ? Colors.green.shade700 : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur. Veuillez réessayer.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<bool> _showWithdrawDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Désactiver les recommandations IA ?'),
            content: const Text(
              'En désactivant cette fonctionnalité :\n\n'
              '• Vos données algorithmiques (baselines, patterns, scores) '
              'seront supprimées sous 30 jours\n\n'
              '• Vous conserverez l\'accès aux fonctionnalités de base '
              '(suivi d\'humeur, conseils généraux)\n\n'
              '• Vous pourrez réactiver à tout moment\n\n'
              'Conformément au RGPD, le retrait du consentement n\'affecte '
              'pas la licéité du traitement effectué avant le retrait.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                ),
                child: const Text('Désactiver'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showActivateDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Activer les recommandations intelligentes'),
            content: const Text(
              'En activant cette fonctionnalité, vous consentez à ce que '
              'MoodTips analyse vos données émotionnelles pour :\n\n'
              '• Calculer votre baseline personnalisée\n'
              '• Générer un score de "batterie mentale"\n'
              '• Détecter des patterns et tendances\n'
              '• Vous proposer des prédictions et insights\n'
              '• Personnaliser vos recommandations\n\n'
              'Ces résultats sont des estimations algorithmiques, '
              'pas des diagnostics médicaux.\n\n'
              'Vous pouvez retirer ce consentement à tout moment '
              'depuis les paramètres.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'J\'accepte',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icône
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (_irmEnabled
                          ? const Color(0xFF6C63FF)
                          : Colors.grey.shade400)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: _irmEnabled
                      ? const Color(0xFF6C63FF)
                      : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Texte
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommandations intelligentes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D3A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Système IRM',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle
              _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: _irmEnabled,
                      onChanged: _toggleConsent,
                      activeColor: const Color(0xFF6C63FF),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _irmEnabled
                ? 'Activé — Vos recommandations sont personnalisées par l\'IA'
                : 'Désactivé — Vous utilisez les fonctionnalités de base',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}