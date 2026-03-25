// lib/widgets/prediction_card.dart
//
// Affiche la prédiction IRM J+1 dans le dashboard.
// Features :
//   • Score prédit avec batterie animée
//   • Jauge de confiance
//   • Chips des facteurs contributifs
//   • Conseil préventif
//   • Feedback utilisateur (👍 / 👎)

import 'package:flutter/material.dart';
import '../models/prediction.dart';

class PredictionCard extends StatefulWidget {
  final Prediction prediction;
  final VoidCallback? onRefresh;
  final void Function(bool correct)? onFeedback;

  const PredictionCard({
    super.key,
    required this.prediction,
    this.onRefresh,
    this.onFeedback,
  });

  @override
  State<PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<PredictionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded    = false;
  bool? _feedbackGiven;
  late AnimationController _controller;
  late Animation<double>   _scoreAnim;

  // ─── Couleurs de la charte MoodTips ─────────────────────
  static const _sagePrimary = Color(0xFF4A7C59);
  static const _golden      = Color(0xFFC9973A);
  static const _dark        = Color(0xFF1E2D24);
  static const _mid         = Color(0xFF5A6E61);
  static const _sageLight   = Color(0xFFE8F0EB);
  static const _goldenLight = Color(0xFFFDF4E7);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(
      begin: 0,
      end:   widget.prediction.predictedScore / 100,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final p = widget.prediction;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow:    [
          BoxShadow(
            color:      _sagePrimary.withOpacity(0.10),
            blurRadius: 16,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────
          _buildHeader(p),

          // ── Score + Confiance ──────────────────────────
          _buildScoreSection(p),

          // ── Factors chips ─────────────────────────────
          if (p.contributingFactors.isNotEmpty) _buildFactorsRow(p),

          // ── Conseil préventif ──────────────────────────
          if (p.preventiveAdvice != null) _buildAdvice(p.preventiveAdvice!),

          // ── Section expandable ─────────────────────────
          _buildExpandToggle(),
          if (_expanded) _buildExpandedContent(p),

          // ── Feedback ──────────────────────────────────
          _buildFeedbackRow(p),
        ],
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader(Prediction p) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient:     LinearGradient(
          colors: [_sagePrimary, Color(0xFF3D6B4B)],
          begin:  Alignment.centerLeft,
          end:    Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('🔮', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prédiction de demain',
                style: TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize:   16,
                ),
              ),
              Text(
                _formatTomorrow(),
                style: TextStyle(
                  color:    Colors.white.withOpacity(0.75),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (widget.onRefresh != null)
            GestureDetector(
              onTap: widget.onRefresh,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SCORE + CONFIANCE ─────────────────────────────────────
  Widget _buildScoreSection(Prediction p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          // Batterie animée
          _AnimatedBattery(animation: _scoreAnim, score: p.predictedScore),
          const SizedBox(width: 20),
          // Score texte + catégorie
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _scoreAnim,
                  builder: (_, __) => Text(
                    '${(_scoreAnim.value * 100).toStringAsFixed(0)} / 100',
                    style: const TextStyle(
                      fontSize:   32,
                      fontWeight: FontWeight.bold,
                      color:      _dark,
                    ),
                  ),
                ),
                Text(
                  p.scoreCategory,
                  style: TextStyle(
                    fontSize: 13,
                    color:    _scoreColor(p.predictedScore),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                // Confiance
                _ConfidenceBar(confidence: p.confidence),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── FACTEURS CONTRIBUTIFS ────────────────────────────────
  Widget _buildFactorsRow(Prediction p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: p.contributingFactors.map((f) {
          final isPositive = f.delta >= 0;
          return Chip(
            label: Text(
              '${f.emoji} ${f.label}'
              ' ${isPositive ? '+' : ''}${f.delta.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize:   12,
                color:      isPositive ? _sagePrimary : Colors.red[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: isPositive ? _sageLight : Colors.red[50],
            padding:         EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide.none,
          );
        }).toList(),
      ),
    );
  }

  // ─── CONSEIL PRÉVENTIF ─────────────────────────────────────
  Widget _buildAdvice(String advice) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        _goldenLight,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _golden.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              advice,
              style: const TextStyle(
                  fontSize: 13, color: _dark, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── EXPAND TOGGLE ────────────────────────────────────────
  Widget _buildExpandToggle() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _expanded ? 'Moins de détails' : 'Voir les détails',
              style: const TextStyle(
                  fontSize: 12, color: _mid, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns:    _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child:    const Icon(Icons.keyboard_arrow_down_rounded,
                           size: 18, color: _mid),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CONTENU EXPANDED ─────────────────────────────────────
  Widget _buildExpandedContent(Prediction p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 16),
          const Text('Détail des facteurs',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: _dark)),
          const SizedBox(height: 8),
          ...p.contributingFactors.map((f) => _FactorRow(factor: f)),
          const SizedBox(height: 8),
          Text(
            'Confiance : ${p.confidenceLabel} '
            '(${(p.confidence * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 12, color: _mid),
          ),
        ],
      ),
    );
  }

  // ─── FEEDBACK ─────────────────────────────────────────────
  Widget _buildFeedbackRow(Prediction p) {
    if (_feedbackGiven != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          _feedbackGiven! ? '✅ Merci pour ton retour !' : '📊 Noté — on améliore le modèle',
          style: const TextStyle(fontSize: 12, color: _mid),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Cette prédiction te semble juste ?',
              style: TextStyle(fontSize: 12, color: _mid)),
          const SizedBox(width: 12),
          _FeedbackButton(
            emoji: '👍',
            onTap: () {
              setState(() => _feedbackGiven = true);
              widget.onFeedback?.call(true);
            },
          ),
          const SizedBox(width: 8),
          _FeedbackButton(
            emoji: '👎',
            onTap: () {
              setState(() => _feedbackGiven = false);
              widget.onFeedback?.call(false);
            },
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────
  Color _scoreColor(double score) {
    if (score >= 70) return _sagePrimary;
    if (score >= 45) return _golden;
    return Colors.red[600]!;
  }

  String _formatTomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    const days   = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const months = ['', 'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
                        'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${days[tomorrow.weekday]} ${tomorrow.day} ${months[tomorrow.month]}';
  }
}

// ─── SOUS-WIDGETS ─────────────────────────────────────────────

class _AnimatedBattery extends StatelessWidget {
  final Animation<double> animation;
  final double score;

  const _AnimatedBattery({required this.animation, required this.score});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => SizedBox(
        width:  56,
        height: 80,
        child:  CustomPaint(
          painter: _BatteryPainter(level: animation.value, score: score),
        ),
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double level; // 0.0 → 1.0
  final double score;

  _BatteryPainter({required this.level, required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 8, size.width, size.height - 8),
      const Radius.circular(6),
    );

    // Corps vide
    final borderPaint = Paint()
      ..color  = const Color(0xFF4A7C59)
      ..style  = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(bodyRect, borderPaint);

    // Borne +
    final capPaint = Paint()..color = const Color(0xFF4A7C59);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.35, 0, size.width * 0.3, 9),
        const Radius.circular(3),
      ),
      capPaint,
    );

    // Remplissage
    final fillHeight = (size.height - 8 - 8) * level;
    final fillColor  = score >= 70
        ? const Color(0xFF4A7C59)
        : score >= 45
            ? const Color(0xFFC9973A)
            : const Color(0xFFC0392B);

    final fillPaint = Paint()..color = fillColor.withOpacity(0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          4,
          size.height - 4 - fillHeight,
          size.width - 8,
          fillHeight,
        ),
        const Radius.circular(4),
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_BatteryPainter old) => old.level != level;
}

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  const _ConfidenceBar({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confiance : ${(confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 11, color: Color(0xFF5A6E61)),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:            confidence,
            minHeight:        6,
            backgroundColor:  const Color(0xFFE8F0EB),
            valueColor: AlwaysStoppedAnimation<Color>(
              confidence >= 0.70
                  ? const Color(0xFF4A7C59)
                  : confidence >= 0.50
                      ? const Color(0xFFC9973A)
                      : Colors.red[400]!,
            ),
          ),
        ),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  final ContributingFactor factor;
  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final isPositive = factor.delta >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(factor.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(factor.label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E2D24))),
          ),
          Text(
            '${isPositive ? '+' : ''}${factor.delta.toStringAsFixed(0)} pts',
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.bold,
              color:      isPositive
                  ? const Color(0xFF4A7C59)
                  : Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  const _FeedbackButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:    const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color:        const Color(0xFFE8F0EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}