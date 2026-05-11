import 'package:flutter/material.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'dart:math' as math;

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.topLeftAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? topLeftAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryDark, AppColors.bgMainGradientEnd],
              ),
            ),
          ),
          const Positioned.fill(child: _TwinkleDotsLayer()),
          if (topLeftAction != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 8,
              child: topLeftAction!,
            ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.slate400.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.slate400.withValues(alpha: 0.95),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TwinkleDotsLayer extends StatefulWidget {
  const _TwinkleDotsLayer();

  @override
  State<_TwinkleDotsLayer> createState() => _TwinkleDotsLayerState();
}

class _TwinkleDotsLayerState extends State<_TwinkleDotsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _stars = <_StarSpec>[
    _StarSpec(topFactor: 0.10, leftFactor: 0.12, size: 3, phase: 0.1),
    _StarSpec(topFactor: 0.16, leftFactor: 0.38, size: 2.5, phase: 0.4),
    _StarSpec(topFactor: 0.09, leftFactor: 0.74, size: 3.2, phase: 0.8),
    _StarSpec(topFactor: 0.24, leftFactor: 0.88, size: 2.2, phase: 0.2),
    _StarSpec(topFactor: 0.34, leftFactor: 0.16, size: 2.4, phase: 0.6),
    _StarSpec(topFactor: 0.42, leftFactor: 0.52, size: 3.4, phase: 0.35),
    _StarSpec(topFactor: 0.52, leftFactor: 0.77, size: 2.1, phase: 0.7),
    _StarSpec(topFactor: 0.61, leftFactor: 0.27, size: 2.8, phase: 0.9),
    _StarSpec(topFactor: 0.69, leftFactor: 0.62, size: 3.0, phase: 0.15),
    _StarSpec(topFactor: 0.78, leftFactor: 0.86, size: 2.6, phase: 0.55),
    _StarSpec(topFactor: 0.84, leftFactor: 0.46, size: 2.3, phase: 0.75),
    _StarSpec(topFactor: 0.90, leftFactor: 0.18, size: 3.1, phase: 0.48),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  for (final star in _stars)
                    Positioned(
                      top: constraints.maxHeight * star.topFactor,
                      left: constraints.maxWidth * star.leftFactor,
                      child: _buildStar(star),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStar(_StarSpec star) {
    final wave = math.sin((_controller.value + star.phase) * 2 * math.pi);
    final opacity = 0.12 + ((wave + 1) / 2) * 0.7;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        width: star.size,
        height: star.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.5),
              blurRadius: star.size * 2.6,
              spreadRadius: 0.3,
            ),
          ],
        ),
      ),
    );
  }
}

class _StarSpec {
  const _StarSpec({
    required this.topFactor,
    required this.leftFactor,
    required this.size,
    required this.phase,
  });

  final double topFactor;
  final double leftFactor;
  final double size;
  final double phase;
}
