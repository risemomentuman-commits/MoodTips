import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class BreathingPlayer extends StatefulWidget {
  final int durationMinutes;
  final VoidCallback? onComplete;

  const BreathingPlayer({
    Key? key,
    required this.durationMinutes,
    this.onComplete,
  }) : super(key: key);

  @override
  State<BreathingPlayer> createState() => _BreathingPlayerState();
}

class _BreathingPlayerState extends State<BreathingPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _cycleTimer;
  String _phase = 'Préparez-vous...';
  int _cycleCount = 0;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationMinutes * 60;

    // Animation controller pour le cercle
    _controller = AnimationController(
      duration: Duration(seconds: 5),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Écouter les changements d'animation
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _phase = 'Expirez...';
        });
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _phase = 'Inspirez...';
          _cycleCount++;
        });
        _controller.forward();
      }
    });

    // Démarrer l'animation
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _phase = 'Inspirez...');
        _controller.forward();
      }
    });

    // Timer pour le compte à rebours
    _cycleTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
