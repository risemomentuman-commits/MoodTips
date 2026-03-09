import 'package:flutter/material.dart';
import '../models/irm_score_detailed.dart';
import '../widgets/battery_widget.dart';
import '../widgets/irm_breakdown_widget.dart';

class IrmDetailPage extends StatelessWidget {
  final IrmScoreDetailed score;

  const IrmDetailPage({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mon Énergie Mentale',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Batterie principale
            _buildBatterySection(),
            const SizedBox(height: 24),
            // Confiance
            _buildConfidenceBar(),
            const SizedBox(height: 24),
            // Breakdown détaillé
            IrmBreakdownWidget(score: score),
            const SizedBox(height: 24),
            // Sources
            _buildSourcesSection(),
            const SizedBox(height: 24),
            // Horodatage
            _buildTimestamp(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBatterySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          BatteryWidget(
            percentage: score.score,
            isCharging: score.score > 60,
            width: 180,
            height: 80,
          ),
          const SizedBox(height: 16),
          Text(
            _getMotivationalMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar() {
    final percent = (score.confidenceLevel * 100).round();
    final label = percent >= 80
        ? 'Haute précision'
        : percent >= 50
            ? 'Précision moyenne'
            : 'Précision limitée';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                'Fiabilité du score : $label ($percent%)',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score.confidenceLevel.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent >= 80
                    ? const Color(0xFF4CAF50)
                    : percent >= 50
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFF44336),
              ),
              minHeight: 4,
            ),
          ),
          if (percent < 80) ...[
            const SizedBox(height: 8),
            Text(
              _getConfidenceTip(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourcesSection() {
    final sourceLabels = {
      'apple_health': ('Apple Santé', Icons.favorite, const Color(0xFFFF2D55)),
      'google_fit': ('Google Fit', Icons.fitness_center, const Color(0xFF4CAF50)),
      'calendar': ('Calendrier', Icons.calendar_today, const Color(0xFF2196F3)),
      'checkin': ('Check-in', Icons.mood, const Color(0xFFFF9800)),
      'manual': ('Saisie manuelle', Icons.edit, Colors.white54),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sources utilisées pour ce calcul',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Données prises en compte dans ton score',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: score.sourcesUsed.map((source) {
            final info = sourceLabels[source];
            if (info == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: info.$3.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: info.$3.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(info.$2, size: 14, color: info.$3),
                  const SizedBox(width: 6),
                  Text(
                    info.$1,
                    style: TextStyle(color: info.$3, fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimestamp() {
    final h = score.timestamp.hour.toString().padLeft(2, '0');
    final m = score.timestamp.minute.toString().padLeft(2, '0');
    final d = score.timestamp.day.toString().padLeft(2, '0');
    final mo = score.timestamp.month.toString().padLeft(2, '0');

    return Text(
      'Calculé le $d/$mo à ${h}h$m • ${score.triggeredBy ?? "auto"}',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 12,
      ),
    );
  }

  String _getMotivationalMessage() {
    if (score.score >= 80) return 'Tu es en pleine forme aujourd\'hui ! 🔥';
    if (score.score >= 60) return 'Bonne énergie, continue comme ça 💪';
    if (score.score >= 40) return 'Journée mitigée, prends soin de toi 🌿';
    if (score.score >= 20) return 'Énergie basse — accorde-toi du repos 🧘';
    return 'Alerte énergie critique — priorité au repos ⚠️';
  }

  String _getConfidenceTip() {
    if (!score.sourcesUsed.any((s) => s.contains('health'))) {
      return 'Connecte Apple Santé ou Google Fit pour plus de précision';
    }
    if (!score.sourcesUsed.any((s) => s.contains('calendar'))) {
      return 'Connecte ton calendrier pour évaluer ta charge mentale';
    }
    return 'Continue tes check-ins quotidiens pour affiner le score';
  }
}