// lib/widgets/irm_dashboard_card.dart
import 'package:flutter/material.dart';
import '../models/irm_score_detailed.dart';
import '../widgets/battery_widget.dart';
import '../pages/irm_detail_page.dart';
import '../pages/irm_history_page.dart';

class IrmDashboardCard extends StatelessWidget {
  final IrmScoreDetailed? score;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const IrmDashboardCard({
    super.key,
    this.score,
    this.isLoading = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLoading
          ? _buildLoading()
          : score == null
              ? _buildNoScore(context)
              : _buildWithScore(context),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 160,
      child: Center(
        child: CircularProgressIndicator(color: Colors.grey),
      ),
    );
  }

  Widget _buildNoScore(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.battery_unknown,
          size: 48,
          color: Colors.grey.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        const Text(
          'Énergie Mentale',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fais ton premier check-in\npour découvrir ton niveau d\'énergie',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildWithScore(BuildContext context) {
    final color = _getScoreColor();

    return Column(
      children: [
        // En-tête
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Énergie Mentale',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                if (onRefresh != null)
                  GestureDetector(
                    onTap: onRefresh,
                    child: Icon(
                      Icons.refresh,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const IrmHistoryPage(),
                    ),
                  ),
                  child: Icon(
                    Icons.timeline,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Batterie cliquable
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IrmDetailPage(score: score!),
            ),
          ),
          child: BatteryWidget(
            percentage: score!.score,
            isCharging: score!.score > 60,
            width: 140,
            height: 60,
          ),
        ),
        const SizedBox(height: 12),
        // Conseil principal
        if (_getMainConseil() != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getMainConseil()!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // Lien détail
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IrmDetailPage(score: score!),
            ),
          ),
          child: Text(
            'Voir le détail →',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor() {
    if (score == null) return Colors.grey;
    if (score!.score >= 80) return const Color(0xFF2E7D32);
    if (score!.score >= 60) return const Color(0xFF4CAF50);
    if (score!.score >= 40) return const Color(0xFFFF9800);
    if (score!.score >= 20) return const Color(0xFFF44336);
    return const Color(0xFFB71C1C);
  }

  String? _getMainConseil() {
    if (score == null) return null;
    final factors = [
      score!.sleep,
      score!.activity,
      score!.mentalLoad,
      score!.emotionStability,
    ];
    for (final f in factors) {
      if (f.conseil != null) return f.conseil;
    }
    return null;
  }
}