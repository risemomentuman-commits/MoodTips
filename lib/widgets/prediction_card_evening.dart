// lib/widgets/prediction_card_evening.dart
//
// Carte prédiction J+1 — version MoodCheck (soir uniquement).
// Visible uniquement après 18h si une prédiction existe.
// Design compact, cohérent avec le style MoodTips existant.

import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../services/prediction_service.dart';
import '../utils/app_colors.dart';

class PredictionCardEvening extends StatefulWidget {
  const PredictionCardEvening({super.key});

  @override
  State<PredictionCardEvening> createState() => _PredictionCardEveningState();
}

class _PredictionCardEveningState extends State<PredictionCardEvening>
    with SingleTickerProviderStateMixin {
  final _service = PredictionService();
  Prediction? _prediction;
  bool _loading = true;
  bool _feedbackGiven = false;

  late AnimationController _scoreCtrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOutCubic),
    );
    _load();
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (DateTime.now().hour < 18) {
      setState(() => _loading = false);
      return;
    }
    final p = await _service.getPredictionForTomorrow();
    if (mounted) {
      // Vérifier si feedback déjà donné
      bool alreadyFeedback = false;
      if (p != null && p.id.isNotEmpty) {
        final response = await Supabase.instance.client
            .from('predictions')
            .select('was_correct')
            .eq('id', p.id)
            .maybeSingle();
        alreadyFeedback = response?['was_correct'] != null;
      }
      setState(() {
        _prediction = p;
        _feedbackGiven = alreadyFeedback;
        _loading = false;
      });
      if (p != null) _scoreCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rien à afficher avant 18h ou si pas de prédiction
    if (_loading) return const SizedBox.shrink();
    if (_prediction == null) return const SizedBox.shrink();
    if (DateTime.now().hour < 18) return const SizedBox.shrink();

    final p = _prediction!;
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (_, __) => _buildCard(p),
    );
  }

  Widget _buildCard(Prediction p) {
    final scoreColor = p.predictedScore >= 70
        ? AppColors.primary
        : p.predictedScore >= 45
            ? const Color(0xFFC9973A)
            : const Color(0xFFC0392B);

    final emoji = p.predictedScore >= 70 ? '🟢' : p.predictedScore >= 45 ? '🟡' : '🔴';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Text('🔮', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prédiction de demain',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2D24),
                        ),
                      ),
                      Text(
                        _formatTomorrow(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF5A6E61)),
                      ),
                    ],
                  ),
                ),
                // Score animé
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$emoji ${(p.predictedScore * _scoreAnim.value).toStringAsFixed(0)}/100',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      p.confidenceLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: scoreColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Conseil préventif ────────────────────────────
          if (p.preventiveAdvice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.preventiveAdvice!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E2D24),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Facteurs contributifs ────────────────────────
          if (p.contributingFactors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: p.contributingFactors.map((f) {
                  final pos = f.delta >= 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pos
                          ? AppColors.primary.withOpacity(0.08)
                          : const Color(0xFFC0392B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${f.emoji} ${f.label} ${pos ? '+' : ''}${f.delta.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: pos ? AppColors.primary : const Color(0xFFC0392B),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── Feedback ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: _feedbackGiven
                ? const Text(
                    '✅ Merci, ça aide à améliorer les prédictions !',
                    style: TextStyle(fontSize: 11, color: Color(0xFF5A6E61)),
                  )
                : Row(
                    children: [
                      const Text(
                        'Cette prédiction te semble juste ?',
                        style: TextStyle(fontSize: 11, color: Color(0xFF5A6E61)),
                      ),
                      const Spacer(),
                      _feedbackBtn('👍', true),
                      const SizedBox(width: 6),
                      _feedbackBtn('👎', false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackBtn(String emoji, bool correct) {
    return GestureDetector(
      onTap: () async {
        setState(() => _feedbackGiven = true);
        if (_prediction?.id != null && _prediction!.id.isNotEmpty) {
          await _service.submitFeedback(
            predictionId: _prediction!.id,
            wasCorrect: correct,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  String _formatTomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    const days = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const months = ['', 'jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${days[tomorrow.weekday]} ${tomorrow.day} ${months[tomorrow.month]}';
  }
}