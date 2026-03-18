import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';
import '../utils/app_colors.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({Key? key}) : super(key: key);
  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String _selectedPlan = 'annual';

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await SubscriptionService.getOfferings();
    setState(() { _offerings = offerings; _isLoading = false; });
  }

  Package? get _monthlyPackage => _offerings?.current?.monthly;
  Package? get _annualPackage => _offerings?.current?.annual;

  Future<void> _purchase(Package package) async {
    setState(() => _isPurchasing = true);
    final success = await SubscriptionService.purchasePackage(package);
    setState(() => _isPurchasing = false);
    if (success && mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenue dans MoodTips Premium ! 🎉'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _restore() async {
    setState(() => _isPurchasing = true);
    final success = await SubscriptionService.restorePurchases();
    setState(() => _isPurchasing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Abonnement restaure ! 🎉' : 'Aucun abonnement trouve'),
          backgroundColor: success ? AppColors.success : AppColors.textMedium,
        ),
      );
      if (success) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      IconButton(icon: Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                    ]),
                  ),
                  Expanded(child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(children: [
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(Icons.diamond, color: AppColors.primary, size: 48),
                      ),
                      SizedBox(height: 20),
                      Text('MoodTips Premium', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 8),
                      Text(
                        'Ton essai gratuit est termine.\nContinue a prendre soin de toi !',
                        style: TextStyle(fontSize: 15, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32),
                      _buildFeature(Icons.battery_charging_full, 'Score IRM', 'Mesure precise de ton energie mentale'),
                      _buildFeature(Icons.psychology, 'Mode Intelligent', 'Detection automatique de ton etat'),
                      _buildFeature(Icons.notifications_active, 'Alertes preventives', 'Prevention avant l\'epuisement'),
                      _buildFeature(Icons.timeline, 'Historique illimite', 'Suivi de ton evolution sans limite'),
                      _buildFeature(Icons.auto_awesome, 'Tips Premium', 'Acces a tous les exercices guides'),
                      _buildFeature(Icons.description, 'Export therapeute', 'Partage ton suivi avec un pro'),
                      SizedBox(height: 32),
                      // Offre fondateurs
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('🔥', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text('Offre fondateurs · Places limitees', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 13)),
                        ]),
                      ),
                      SizedBox(height: 24),
                      // Plans
                      _buildPlanCard(
                        id: 'annual',
                        title: 'Annuel',
                        price: _annualPackage?.storeProduct.priceString ?? '59,99€',
                        subtitle: 'soit ~5€/mois · Economise 37%',
                        isPopular: true,
                      ),
                      SizedBox(height: 12),
                      _buildPlanCard(
                        id: 'monthly',
                        title: 'Mensuel',
                        price: _monthlyPackage?.storeProduct.priceString ?? '7,99€',
                        subtitle: 'par mois · Sans engagement',
                        isPopular: false,
                      ),
                      SizedBox(height: 24),
                      // CTA
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isPurchasing ? null : () {
                            final pkg = _selectedPlan == 'annual' ? _annualPackage : _monthlyPackage;
                            if (pkg != null) _purchase(pkg);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isPurchasing
                              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('S\'abonner maintenant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      SizedBox(height: 16),
                      // Restaurer
                      TextButton(
                        onPressed: _isPurchasing ? null : _restore,
                        child: Text('Restaurer un achat', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ),
                      SizedBox(height: 8),
                      // Legal
                      Text(
                        'L\'abonnement se renouvelle automatiquement. Tu peux annuler a tout moment dans les reglages de ton telephone.',
                        style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                    ]),
                  )),
                ]),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String desc) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          Text(desc, style: TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        Icon(Icons.check_circle, color: AppColors.primary, size: 20),
      ]),
    );
  }

  Widget _buildPlanCard({required String id, required String title, required String price, required String subtitle, required bool isPopular}) {
    final isSelected = _selectedPlan == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.1), width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? AppColors.primary : Colors.white38, width: 2)),
            child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary))) : null,
          ),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              if (isPopular) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                  child: Text('Populaire', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ],
            ]),
            SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ])),
          Text(price, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
      ),
    );
  }
}