import 'package:flutter/material.dart';

class BatteryWidget extends StatefulWidget {
  final int percentage;
  final bool isCharging;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const BatteryWidget({
    super.key,
    required this.percentage,
    this.isCharging = false,
    this.width = 160,
    this.height = 70,
    this.onTap,
  });

  @override
  State<BatteryWidget> createState() => _BatteryWidgetState();
}

class _BatteryWidgetState extends State<BatteryWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;
  double _previousPercentage = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fillAnimation = Tween<double>(
      begin: 0,
      end: widget.percentage / 100.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(BatteryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _previousPercentage = _fillAnimation.value;
      _fillAnimation = Tween<double>(
        begin: _previousPercentage,
        end: widget.percentage / 100.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBatteryColor(int percentage) {
    if (percentage >= 80) return const Color(0xFF2E7D32); // vert foncé
    if (percentage >= 60) return const Color(0xFF4CAF50); // vert
    if (percentage >= 40) return const Color(0xFFFF9800); // orange
    if (percentage >= 20) return const Color(0xFFF44336); // rouge
    return const Color(0xFFB71C1C); // rouge foncé
  }

  String _getLevelEmoji(int percentage) {
    if (percentage >= 80) return '🟢';
    if (percentage >= 60) return '🔵';
    if (percentage >= 40) return '🟠';
    if (percentage >= 20) return '🔴';
    return '⛔';
  }

  String _getLevelLabel(int percentage) {
    if (percentage >= 80) return 'Excellent';
    if (percentage >= 60) return 'Bon';
    if (percentage >= 40) return 'Moyen';
    if (percentage >= 20) return 'Faible';
    return 'Critique';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBatteryColor(widget.percentage);

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label niveau
          Text(
            '${_getLevelEmoji(widget.percentage)} ${_getLevelLabel(widget.percentage)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          // Batterie
          AnimatedBuilder(
            animation: _fillAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.width, widget.height),
                painter: _BatteryPainter(
                  fillPercentage: _fillAnimation.value,
                  color: color,
                  isCharging: widget.isCharging,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Pourcentage texte
          Text(
            '${widget.percentage}%',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (widget.isCharging)
            Text(
              '⚡ En amélioration',
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final double fillPercentage;
  final Color color;
  final bool isCharging;

  _BatteryPainter({
    required this.fillPercentage,
    required this.color,
    this.isCharging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Dimensions
    final bodyWidth = size.width - 15;
    final bodyHeight = size.height;
    const radius = 8.0;
    const padding = 4.0;

    // Corps de la batterie (fond)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bodyWidth, bodyHeight),
      const Radius.circular(radius),
    );
    canvas.drawRRect(bodyRect, bgPaint);
    canvas.drawRRect(bodyRect, borderPaint);

    // Remplissage
    final fillWidth = (bodyWidth - 4) * fillPercentage;
    if (fillWidth > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(padding, padding, fillWidth, bodyHeight - padding * 2),
        const Radius.circular(radius - 2),
      );

      // Dégradé
      fillPaint.shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.7),
          color,
        ],
      ).createShader(
        Rect.fromLTWH(padding, padding, fillWidth, bodyHeight - padding * 2),
      );

      canvas.drawRRect(fillRect, fillPaint);
    }

    // Borne positive (droite)
    final terminalPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final terminalRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bodyWidth + 2,
        bodyHeight / 2 - 12,
        10,
        24,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(terminalRect, terminalPaint);

    // Éclair si en charge
    if (isCharging) {
      final boltPaint = Paint()
        ..color = Colors.yellowAccent
        ..style = PaintingStyle.fill;

      final boltPath = Path()
        ..moveTo(bodyWidth * 0.55, bodyHeight * 0.15)
        ..lineTo(bodyWidth * 0.4, bodyHeight * 0.45)
        ..lineTo(bodyWidth * 0.5, bodyHeight * 0.45)
        ..lineTo(bodyWidth * 0.45, bodyHeight * 0.85)
        ..lineTo(bodyWidth * 0.6, bodyHeight * 0.55)
        ..lineTo(bodyWidth * 0.5, bodyHeight * 0.55)
        ..close();

      canvas.drawPath(boltPath, boltPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return oldDelegate.fillPercentage != fillPercentage ||
        oldDelegate.color != color ||
        oldDelegate.isCharging != isCharging;
  }
}