import 'package:flutter/material.dart';

class SourceConnectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final VoidCallback? onTap;

  const SourceConnectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isConnected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isConnected
              ? color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isConnected
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isConnected
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isConnected ? 'Connecté ✓' : 'Connecter',
                style: TextStyle(
                  color: isConnected
                      ? const Color(0xFF4CAF50)
                      : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper pour créer les cartes standards
  static List<SourceConnectionCard> buildAll({
    bool healthConnected = false,
    bool calendarConnected = false,
    VoidCallback? onHealthTap,
    VoidCallback? onCalendarTap,
  }) {
    return [
      SourceConnectionCard(
        title: 'Apple Santé / Google Fit',
        subtitle: 'Sommeil, pas, activité physique',
        icon: Icons.favorite,
        color: const Color(0xFFFF2D55),
        isConnected: healthConnected,
        onTap: onHealthTap,
      ),
      SourceConnectionCard(
        title: 'Calendrier',
        subtitle: 'Charge mentale et événements',
        icon: Icons.calendar_today,
        color: const Color(0xFF2196F3),
        isConnected: calendarConnected,
        onTap: onCalendarTap,
      ),
    ];
  }
}