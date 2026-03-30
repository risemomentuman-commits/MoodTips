import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_routes.dart';

class AccountTypePage extends StatelessWidget {
  const AccountTypePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Tu rejoins MoodTips en tant que...',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Choisis le type de compte qui correspond à ta situation.',
                style: TextStyle(fontSize: 15, color: AppColors.textMedium),
              ),
              SizedBox(height: 48),

              // Carte Particulier
              _TypeCard(
                icon: '🧘',
                title: 'Particulier',
                subtitle: 'Je veux améliorer mon bien-être personnel',
                details: 'Accès gratuit avec option premium',
                color: AppColors.primary,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.createAccount,
                  arguments: {'accountType': 'personal'},
                ),
              ),
              SizedBox(height: 16),

              // Carte Entreprise
              _TypeCard(
                icon: '🏢',
                title: 'Entreprise',
                subtitle: 'Mon employeur utilise MoodTips',
                details: 'Accès Premium offert par ton entreprise',
                color: Color(0xFF1E2D24),
                badge: 'Premium inclus',
                onTap: () => Navigator.pushNamed(context, AppRoutes.enterpriseCode),
              ),

              Spacer(),

              Center(
                child: Text(
                  'Ton choix peut être modifié ultérieurement',
                  style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String details;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(icon, style: TextStyle(fontSize: 28))),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (badge != null) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(0xFFC9973A).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC9973A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: AppColors.textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    details,
                    style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
