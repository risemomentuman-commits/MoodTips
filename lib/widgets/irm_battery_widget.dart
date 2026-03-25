// lib/widgets/irm_battery_widget.dart
//
// Batterie IRM V2 — version perfectionnée Août 2026.
// Features :
//   • Liquid fill animé (vague)
//   • Micro-vibration aux seuils (40/60/80)
//   • Compteur animé du score
//   • Indicateur de tendance (↑ ↓ →)
//   • Couleur adaptive sage/golden/red

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_animations.dart';

class IrmBatteryWidget extends StatefulWidget {
  final double score;          // 0–100
  final double? previousScore; // Pour la tendance
  final bool   showLabel;
  final bool   showTrend;
  final double size;

  const IrmBatteryWidget({
    super.key,
    required this.score,
    this.previousScore,
    this.showLabel = true,
    this.showTrend = true,
    this.size      = 180,
  });

  @override
  State<IrmBatteryWidget> createState() => _IrmBatteryWidgetState();
}

class _IrmBatteryWidgetState extends State<IrmBatteryWidget>
    with TickerProviderStateMixin {
  late AnimationController _fillCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _fillAnim;
  late Animation<double>   _pulseAnim;

  double _previousScore = 0;

  // Couleurs MoodTips
  static const _sage   = Color(0xFF4A7C59);
  static const _golden = Color(0xFFC9973A);
  static const _red    = Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    _fillCtrl = AnimationController(vsync: this, duration: AppDurations.battery);
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: AppDurations.medium);

    _fillAnim = Tween<double>(begin: 0, end: widget.score / 100).animate(
      CurvedAnimation(parent: _fillCtrl, curve: AppCurves.smooth),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fillCtrl.forward();
  }

  @override
  void didUpdateWidget(IrmBatteryWidget old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _previousScore = old.score;
      _fillAnim = Tween<double>(
        begin: old.score / 100,
        end:   widget.score / 100,
      ).animate(CurvedAnimation(parent: _fillCtrl, curve: AppCurves.smooth));
      _fillCtrl.forward(from: 0);

      // Vibration si franchissement de seuil
      final threshold = ScoreThresholdNotifier.checkThreshold(
        old.score, widget.score,
      );
      if (threshold != null) {
        HapticFeedback.mediumImpact();
        _pulseCtrl.forward().then((_) => _pulseCtrl.reverse());
      }
    }
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color _scoreColor(double score) {
    if (score >= 60) return _sage;
    if (score >= 40) return _golden;
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    final color   = _scoreColor(widget.score);
    final trend   = widget.previousScore != null
        ? widget.score - widget.previousScore!
        : null;

    return AnimatedBuilder(
      animation: Listenable.merge([_fillAnim, _waveCtrl, _pulseAnim]),
      builder: (_, __) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width:  widget.size * 0.55,
                height: widget.size,
                child: CustomPaint(
                  painter: _LiquidBatteryPainter(
                    fillLevel:  _fillAnim.value,
                    wavePhase:  _waveCtrl.value * 2 * pi,
                    color:      color,
                    score:      widget.score,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.showLabel) ...[
                          AnimatedCounter(
                            value: widget.score,
                            style: TextStyle(
                              fontSize:   widget.size * 0.18,
                              fontWeight: FontWeight.bold,
                              color:      _fillAnim.value > 0.5
                                          ? Colors.white
                                          : color,
                            ),
                          ),
                          Text(
                            '/100',
                            style: TextStyle(
                              fontSize: widget.size * 0.09,
                              color:    _fillAnim.value > 0.5
                                        ? Colors.white70
                                        : color.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Tendance
              if (widget.showTrend && trend != null) ...[
                const SizedBox(height: 8),
                _TrendBadge(delta: trend, color: color),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── LIQUID BATTERY PAINTER ───────────────────────────────────

class _LiquidBatteryPainter extends CustomPainter {
  final double fillLevel; // 0.0 → 1.0
  final double wavePhase;
  final Color  color;
  final double score;

  _LiquidBatteryPainter({
    required this.fillLevel,
    required this.wavePhase,
    required this.color,
    required this.score,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final capH = h * 0.06;

    // Contour de la batterie
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, capH, w, h - capH),
      const Radius.circular(14),
    );

    // Borne +
    final capPaint = Paint()..color = color.withOpacity(0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, 0, w * 0.36, capH + 2),
        const Radius.circular(4),
      ),
      capPaint,
    );

    // Fond blanc
    canvas.drawRRect(
      bodyRect,
      Paint()..color = const Color(0xFFF4F7F5),
    );

    // Découpe pour clipping du liquide dans la batterie
    canvas.save();
    canvas.clipRRect(bodyRect);

    final fillH    = (h - capH) * fillLevel;
    final fillTop  = h - fillH;
    final waveAmp  = fillLevel > 0.05 && fillLevel < 0.95 ? 5.0 : 0.0;

    // Vague
    final wavePath = Path();
    wavePath.moveTo(0, fillTop);
    for (double x = 0; x <= w; x++) {
      final y = fillTop + sin((x / w * 2 * pi) + wavePhase) * waveAmp;
      wavePath.lineTo(x, y);
    }
    wavePath.lineTo(w, h);
    wavePath.lineTo(0, h);
    wavePath.close();

    // Gradient liquide
    final liquidPaint = Paint()
      ..shader = LinearGradient(
        begin:  Alignment.topCenter,
        end:    Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.7),
          color,
        ],
      ).createShader(Rect.fromLTWH(0, fillTop, w, fillH));

    canvas.drawPath(wavePath, liquidPaint);
    canvas.restore();

    // Bordure
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color  = color
        ..style  = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Lignes de graduation (25% / 50% / 75%)
    if (fillLevel < 0.95) {
      final gradPaint = Paint()
        ..color       = color.withOpacity(0.25)
        ..strokeWidth = 1;
      for (final pct in [0.25, 0.50, 0.75]) {
        final yLine = h - (h - capH) * pct;
        canvas.drawLine(
          Offset(4, yLine),
          Offset(w - 4, yLine),
          gradPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LiquidBatteryPainter old) =>
      old.fillLevel != fillLevel || old.wavePhase != wavePhase;
}

// ─── TREND BADGE ─────────────────────────────────────────────

class _TrendBadge extends StatelessWidget {
  final double delta;
  final Color  color;

  const _TrendBadge({required this.delta, required this.color});

  @override
  Widget build(BuildContext context) {
    final String arrow;
    final Color  bg;
    if (delta >  3) {
      arrow = '↑';
      bg    = const Color(0xFF4A7C59);
    } else if (delta < -3) {
      arrow = '↓';
      bg    = const Color(0xFFC0392B);
    } else {
      arrow = '→';
      bg    = const Color(0xFFC9973A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:        bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: bg.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(arrow, style: TextStyle(color: bg, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(
            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)} pts',
            style: TextStyle(
              color:      bg,
              fontSize:   12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}