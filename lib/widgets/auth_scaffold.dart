import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0F1E),
                    Color(0xFF0F172A),
                    Color(0xFF020810),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Ambient glow
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.brandBlue.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.cyan.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Twinkling stars
            const Positioned.fill(child: _TwinkleDotsLayer()),

            // Back button
            if (topLeftAction != null)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 8,
                child: topLeftAction!,
              ),

            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [AppColors.brandBlue, Color(0xFF22D3EE)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandBlue.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.satellite_alt,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.slate400,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Form card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1629).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.slate700.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
    _StarSpec(topFactor: 0.08, leftFactor: 0.15, size: 2.5, phase: 0.1),
    _StarSpec(topFactor: 0.14, leftFactor: 0.42, size: 2.0, phase: 0.4),
    _StarSpec(topFactor: 0.07, leftFactor: 0.78, size: 2.8, phase: 0.8),
    _StarSpec(topFactor: 0.22, leftFactor: 0.90, size: 1.8, phase: 0.2),
    _StarSpec(topFactor: 0.32, leftFactor: 0.12, size: 2.2, phase: 0.6),
    _StarSpec(topFactor: 0.45, leftFactor: 0.55, size: 3.0, phase: 0.35),
    _StarSpec(topFactor: 0.55, leftFactor: 0.82, size: 1.8, phase: 0.7),
    _StarSpec(topFactor: 0.63, leftFactor: 0.25, size: 2.4, phase: 0.9),
    _StarSpec(topFactor: 0.72, leftFactor: 0.65, size: 2.6, phase: 0.15),
    _StarSpec(topFactor: 0.80, leftFactor: 0.88, size: 2.0, phase: 0.55),
    _StarSpec(topFactor: 0.87, leftFactor: 0.42, size: 2.2, phase: 0.75),
    _StarSpec(topFactor: 0.93, leftFactor: 0.15, size: 2.8, phase: 0.48),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
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
    final opacity = 0.08 + ((wave + 1) / 2) * 0.6;

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
              color: Colors.white.withValues(alpha: 0.4),
              blurRadius: star.size * 2,
              spreadRadius: 0.2,
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
