import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../pages/paywall_page.dart';
import '../utils/app_colors.dart';

/// Bandeau qui s'affiche quand le trial approche de la fin
class TrialBanner extends StatefulWidget {
  const TrialBanner({Key? key}) : super(key: key);

  @override
  State<TrialBanner> createState() => _TrialBannerState();
}

class _TrialBannerState extends State<TrialBanner> {

  @override
  void initState() {
    super.initState();
    SubscriptionService.accessNotifier.addListener(_refresh);
  }

  @override
  void dispose() {
    SubscriptionService.accessNotifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Ne rien afficher si premium ou pas en fin de trial
    if (SubscriptionService.isPremium) return SizedBox.shrink();
    if (SubscriptionService.trialExpired) return _buildExpiredBanner(context);

    final days = SubscriptionService.trialDaysRemaining;

    // Afficher le bandeau seulement dans les 3 derniers jours
    if (days > 3) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage())),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: days <= 1
                  ? [Colors.red.shade400, Colors.red.shade600]
                  : [Colors.orange.shade400, Colors.orange.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                days <= 1 ? Icons.warning_amber : Icons.timer,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      days <= 0
                          ? 'Dernier jour d\'essai !'
                          : days == 1
                              ? 'Plus que 1 jour d\'essai'
                              : 'Plus que $days jours d\'essai',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Abonne-toi pour garder l\'acces',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Voir les offres',
                  style: TextStyle(
                    color: days <= 1 ? Colors.red.shade600 : Colors.orange.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredBanner(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage())),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.diamond, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ton essai gratuit est terminé',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Passe en Premium pour continuer',
                      style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'S\'abonner',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}