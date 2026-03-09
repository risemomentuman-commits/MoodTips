import 'package:flutter/material.dart';
import '../models/irm_score_detailed.dart';

class IrmBreakdownWidget extends StatelessWidget {
  final IrmScoreDetailed score;

  const IrmBreakdownWidget({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final factors = [
      _FactorData('Sommeil', '😴', score.sleep),
      _FactorData('Activité', '🏃', score.activity),
      _FactorData('Charge mentale', '🧠', score.mentalLoad),
      _FactorData('Émotions', '💚', score.emotionStability),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Détail de ton énergie',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...factors.map((f) => _buildFactorRow(f)),
        if (score.mainFactor.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMainFactorTip(),
        ],
      ],
    );
  }

  Widget _buildFactorRow(_FactorData factor) {
    final color = _getColor(factor.breakdown.percentage);
    final hasConseil = factor.breakdown.conseil != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: hasConseil
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : emoji + nom + points
          Row(
            children: [
              Text(factor.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  factor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${factor.breakdown.points}/${factor.breakdown.maxPoints}',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: factor.breakdown.percentage.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          // Explication
          Text(
            factor.breakdown.explication,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          // Conseil si présent
          if (hasConseil) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      factor.breakdown.conseil!,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainFactorTip() {
    final labels = {
      'sleep': 'Le sommeil',
      'activity': 'L\'activité physique',
      'mental_load': 'La charge mentale',
      'emotion_stability': 'La stabilité émotionnelle',
    };

    final label = labels[score.mainFactor] ?? score.mainFactor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label est ton principal levier d\'amélioration aujourd\'hui.',
              style: TextStyle(
                color: Colors.amber.shade200,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(double percentage) {
    if (percentage >= 0.8) return const Color(0xFF4CAF50);
    if (percentage >= 0.6) return const Color(0xFF2196F3);
    if (percentage >= 0.4) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}

class _FactorData {
  final String name;
  final String emoji;
  final IrmFactorBreakdown breakdown;

  _FactorData(this.name, this.emoji, this.breakdown);
}