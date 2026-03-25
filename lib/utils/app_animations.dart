// lib/utils/app_animations.dart
//
// Centralize toutes les animations de l'app MoodTips.
// Durées, courbes et transitions standardisées.

import 'package:flutter/material.dart';

// ─── DURÉES STANDARD ──────────────────────────────────────────
class AppDurations {
  AppDurations._();
  static const micro    = Duration(milliseconds: 120);
  static const fast     = Duration(milliseconds: 200);
  static const normal   = Duration(milliseconds: 300);
  static const medium   = Duration(milliseconds: 450);
  static const slow     = Duration(milliseconds: 650);
  static const battery  = Duration(milliseconds: 1200);
  static const pageIn   = Duration(milliseconds: 380);
}

// ─── COURBES STANDARD ─────────────────────────────────────────
class AppCurves {
  AppCurves._();
  static const enter    = Curves.easeOutCubic;
  static const exit     = Curves.easeInCubic;
  static const spring   = Curves.elasticOut;
  static const smooth   = Curves.easeInOutCubic;
  static const bounce   = Curves.bounceOut;
}

// ─── TRANSITIONS DE PAGE ──────────────────────────────────────

/// Transition slide + fade pour la navigation principale.
class SlideUpFadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SlideUpFadePageRoute({required this.child})
      : super(
          transitionDuration:        AppDurations.pageIn,
          reverseTransitionDuration: AppDurations.normal,
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (_, animation, secondaryAnimation, widget) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve:  const Interval(0.0, 0.6, curve: Curves.easeOut),
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end:   Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve:  AppCurves.enter,
                )),
                child: widget,
              ),
            );
          },
        );
}

/// Transition Hero + fade pour les détails.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  FadePageRoute({required this.child})
      : super(
          transitionDuration:        AppDurations.normal,
          reverseTransitionDuration: AppDurations.fast,
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (_, animation, __, widget) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: AppCurves.enter),
              child:   widget,
            );
          },
        );
}

// ─── MICRO-INTERACTIONS ───────────────────────────────────────

/// Bouton avec effet scale on tap (0.97) + feedback haptique léger.
class TapScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  const TapScaleButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.97,
    this.duration    = AppDurations.micro,
  });

  @override
  State<TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<TapScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap?.call(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder:   (_, child) => Transform.scale(scale: _scale.value, child: child),
        child:     widget.child,
      ),
    );
  }
}

/// Card avec élévation animée au survol / tap.
class ElevatedTapCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color  shadowColor;

  const ElevatedTapCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.shadowColor  = const Color(0x1A4A7C59),
  });

  @override
  State<ElevatedTapCard> createState() => _ElevatedTapCardState();
}

class _ElevatedTapCardState extends State<ElevatedTapCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _elevation;

  @override
  void initState() {
    super.initState();
    _ctrl      = AnimationController(vsync: this, duration: AppDurations.fast);
    _elevation = Tween<double>(begin: 4, end: 12).animate(
      CurvedAnimation(parent: _ctrl, curve: AppCurves.smooth),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap?.call(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _elevation,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color:      widget.shadowColor,
                blurRadius: _elevation.value * 2,
                offset:     Offset(0, _elevation.value / 2),
              ),
            ],
          ),
          child: child,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── SHIMMER SKELETON ─────────────────────────────────────────

/// Loading state élégant pour cartes dashboard.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  const ShimmerBox.full({
    super.key,
    required this.height,
    this.borderRadius = 12,
  }) : width = double.infinity;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmer = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Container(
        width:  widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(_shimmer.value - 1, 0),
            end:   Alignment(_shimmer.value + 1, 0),
            colors: const [
              Color(0xFFEEF1EE),
              Color(0xFFF8FAF8),
              Color(0xFFEEF1EE),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton complet du dashboard pendant le chargement.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Carte batterie IRM
          const ShimmerBox.full(height: 180, borderRadius: 20),
          const SizedBox(height: 12),
          // Carte prédiction
          const ShimmerBox.full(height: 120, borderRadius: 20),
          const SizedBox(height: 12),
          // Ligne de chips
          Row(children: const [
            ShimmerBox(width: 90, height: 36, borderRadius: 18),
            SizedBox(width: 8),
            ShimmerBox(width: 110, height: 36, borderRadius: 18),
            SizedBox(width: 8),
            ShimmerBox(width: 80, height: 36, borderRadius: 18),
          ]),
          const SizedBox(height: 12),
          // Liste actions
          ...List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: const [
              ShimmerBox(width: 48, height: 48, borderRadius: 12),
              SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox.full(height: 14, borderRadius: 6),
                  SizedBox(height: 6),
                  ShimmerBox(width: 140, height: 11, borderRadius: 6),
                ],
              )),
            ]),
          )),
        ],
      ),
    );
  }
}

// ─── ANIMATED COUNTER ─────────────────────────────────────────

/// Compteur animé pour afficher un score qui change.
class AnimatedCounter extends StatefulWidget {
  final double value;
  final int decimals;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
    this.suffix   = '',
    this.duration = AppDurations.battery,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: AppCurves.enter),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previousValue = old.value;
      _anim = Tween<double>(begin: _previousValue, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: AppCurves.enter),
      );
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final val = widget.decimals > 0
            ? _anim.value.toStringAsFixed(widget.decimals)
            : _anim.value.toStringAsFixed(0);
        return Text('$val${widget.suffix}', style: widget.style);
      },
    );
  }
}

// ─── SCORE THRESHOLD ANIMATION ────────────────────────────────

/// Animation + vibration quand le score franchit un seuil.
class ScoreThresholdNotifier {
  static const _thresholds = [40.0, 60.0, 80.0];

  static double? checkThreshold(double previous, double current) {
    for (final t in _thresholds) {
      if ((previous < t && current >= t) || (previous >= t && current < t)) {
        return t;
      }
    }
    return null;
  }
}