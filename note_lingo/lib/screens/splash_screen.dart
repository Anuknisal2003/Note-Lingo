import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'onboarding/onboarding_screen.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

// ── Onboarding-matched palette ─────────────────────────────────────
const _bgTop = Color(0xFF6AABF8); // same topA as onboarding page 1
const _bgMid = Color(0xFF9AC8FB); // same topB
const _bgBot = Color(0xFFEFF5FF); // same bg
const _deep = Color(0xFF2356C8); // deep blue accent
const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Main entry animation ──────────────────────────────────────────
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  late final Animation<double> _fade = Tween<double>(begin: 0.0, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
        ),
      );

  late final Animation<double> _scale = Tween<double>(begin: 0.65, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
        ),
      );

  late final Animation<double> _glow = Tween<double>(begin: 0.0, end: 1.0)
      .animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
        ),
      );

  // ── Floating orb loop ─────────────────────────────────────────────
  late final AnimationController _orbCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    try {
      final auth = context.read<AuthProvider>();
      final seen = await auth.hasSeenOnboarding();
      if (!mounted) return;

      Widget dest;
      if (!seen) {
        dest = const OnboardingScreen();
      } else if (auth.isLoggedIn) {
        dest = const HomeScreen();
      } else {
        dest = const LoginScreen();
      }
      _goTo(dest);
    } catch (_) {
      if (mounted) _goTo(const LoginScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full page gradient (matches onboarding) ────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgTop, _bgMid, _bgBot],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Floating decorative orbs ───────────────────────────
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (_, _) {
              final t = _orbCtrl.value;
              return Stack(
                children: [
                  // Top-right large orb
                  Positioned(
                    top: -50 + 20 * math.sin(t * math.pi),
                    right: -60,
                    child: _Orb(
                      size: 220,
                      color: const Color(0xFF5AA0F8).withValues(alpha: 0.30),
                    ),
                  ),
                  // Left mid orb
                  Positioned(
                    top: size.height * 0.30 - 15 * math.sin(t * math.pi),
                    left: -55,
                    child: _Orb(
                      size: 160,
                      color: const Color(0xFF88BFFB).withValues(alpha: 0.25),
                    ),
                  ),
                  // Bottom-right small orb
                  Positioned(
                    bottom: size.height * 0.15 + 12 * math.sin(t * math.pi),
                    right: 20,
                    child: _Orb(size: 90, color: _deep.withValues(alpha: 0.12)),
                  ),
                  // Bottom-left tiny orb
                  Positioned(
                    bottom: 60 - 8 * math.sin(t * math.pi),
                    left: 30,
                    child: _Orb(
                      size: 60,
                      color: const Color(0xFF4F8EF7).withValues(alpha: 0.18),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Centre content ─────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── App icon ────────────────────────────────
                      AnimatedBuilder(
                        animation: _glow,
                        builder: (_, _) => Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6BAAF8), Color(0xFF2356C8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4A7CF5,
                                ).withValues(alpha: 0.55 * _glow.value),
                                blurRadius: 48,
                                spreadRadius: 6,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── App name — two-line style ────────────────
                      Column(
                        children: [
                          const Text(
                            'Note',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w300,
                              color: _textDark,
                              height: 1.0,
                              letterSpacing: -1.5,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                              colors: [Color(0xFF4F8EF7), Color(0xFF2356C8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(r),
                            child: const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Lingo',
                                style: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.25,
                                  letterSpacing: -2.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Tagline with pill ────────────────────────
                      AnimatedBuilder(
                        animation: _glow,
                        builder: (_, _) => Opacity(
                          opacity: _glow.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.55),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4F8EF7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'AI VOICE NOTES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom progress bar ────────────────────────────────
          Positioned(
            bottom: 52,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _glow,
              builder: (_, _) => Opacity(
                opacity: _glow.value,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loading dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return AnimatedBuilder(
                            animation: _orbCtrl,
                            builder: (_, _) {
                              final pulse = math.sin(
                                _orbCtrl.value * math.pi * 2 + i * 1.0,
                              );
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF4F8EF7,
                                  ).withValues(alpha: 0.4 + 0.6 * ((pulse + 1) / 2)),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Loading…',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textGrey.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
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

// ── Orb helper ────────────────────────────────────────────────────
class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}
