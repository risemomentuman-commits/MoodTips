// lib/utils/badge_checker.dart
// Helper pour vérifier automatiquement les badges

import 'package:flutter/material.dart';
import '../services/badge_service.dart';
import '../widgets/badge_unlock_dialog.dart';
import '../models/badge.dart' as models;

class BadgeChecker {
  /// Vérifier et afficher les nouveaux badges après une action
  static Future<void> checkAndShowBadges(BuildContext context) async {
    try {
      final newBadges = await BadgeService.checkAndUnlockBadges();
      
      if (newBadges.isEmpty) return;
      
      // Afficher animation pour chaque nouveau badge
      for (var badge in newBadges) {
        if (!context.mounted) break;
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => BadgeUnlockDialog(badge: badge),
        );
      }
    } catch (e) {
      print('❌ Erreur checkAndShowBadges: $e');
    }
  }
  
  /// Vérifier silencieusement (sans animation) - utile pour le background
  static Future<List<models.Badge>> checkSilently() async {
    try {
      return await BadgeService.checkAndUnlockBadges();
    } catch (e) {
      print('❌ Erreur checkSilently: $e');
      return [];
    }
  }
  
  /// Obtenir le nombre de badges débloqués (pour affichage dans profil)
  static Future<int> getUnlockedCount() async {
    try {
      final badges = await BadgeService.getUserBadges();
      return badges.where((b) => b.isUnlocked).length;
    } catch (e) {
      print('❌ Erreur getUnlockedCount: $e');
      return 0;
    }
  }
  
  /// Vérifier si un badge spécifique est débloqué
  static Future<bool> isBadgeUnlocked(String badgeId) async {
    try {
      final badges = await BadgeService.getUserBadges();
      final badge = badges.firstWhere(
        (b) => b.id == badgeId,
        orElse: () => badges.first,
      );
      return badge.isUnlocked;
    } catch (e) {
      print('❌ Erreur isBadgeUnlocked: $e');
      return false;
    }
  }
}
