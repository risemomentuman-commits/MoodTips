import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../pages/paywall_page.dart';

class PremiumGate extends StatefulWidget {
  final Widget child;
  final String featureName;
  final double blurAmount;
  final VoidCallback? onPurchased;

  const PremiumGate({
    Key? key,
    required this.child,
    this.featureName = 'cette fonctionnalité',
    this.blurAmount = 3.0,
    this.onPurchased, 
  }) : super(key: key);

  @override
  State<PremiumGate> createState() => _PremiumGateState();
}

class _PremiumGateState extends State<PremiumGate> {

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
    if (SubscriptionService.hasAccess) return widget.child;

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallPage()),
        );
        // Rafraîchir après retour de la paywall
        if (result == true && mounted) {
          setState(() {});
          widget.onPurchased?.call(); 
        }
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: widget.blurAmount, sigmaY: widget.blurAmount),
              child: widget.child,
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