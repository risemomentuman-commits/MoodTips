import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../pages/paywall_page.dart';

class PremiumGate extends StatelessWidget {
  final Widget child;
  final String featureName;
  final double blurAmount;

  const PremiumGate({
    Key? key,
    required this.child,
    this.featureName = 'cette fonctionnalite',
    this.blurAmount = 2.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Acces si premium OU en periode d'essai
    if (SubscriptionService.hasAccess) return child;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage())),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
              child: child,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Text('Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}