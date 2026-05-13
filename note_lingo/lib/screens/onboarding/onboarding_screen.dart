// ignore_for_file: unused_element

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';

// ── Palette ────────────────────────────────────────────────────────
const _c1 = Color(0xFF4F8EF7); // primary blue
const _c2 = Color(0xFF7AB3FA); // mid blue
const _c3 = Color(0xFFB8D6FD); // soft blue
const _c4 = Color(0xFF2356C8); // deep blue
const _white = Colors.white;
const _dark = Color(0xFF0E1A3A);
const _grey = Color(0xFF6B7A99);
const _dotOn = Color(0xFF4F8EF7);
const _dotOff = Color(0xFFCDD8F5);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _index = 0;

  // Floating orb animation
  late final AnimationController _orbCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  // Page entry animation
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<double> _entryFade = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _entrySlide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

  static const _pages = [
    _PD(
      img: 'assets/images/onboarding_1.png',
      topA: Color(0xFF6AABF8),
      topB: Color(0xFF9AC8FB),
      bg: Color(0xFFEFF5FF),
      tag: 'VOICE AI',
      title1: 'Record',
      title2: 'Your Voice',
      sub: 'Capture lectures, meetings\nand ideas — effortlessly.',
    ),
    _PD(
      img: 'assets/images/onboarding_2.png',
      topA: Color(0xFF88BAF9),
      topB: Color(0xFFB5D5FC),
      bg: Color(0xFFF3F7FF),
      tag: 'SMART AI',
      title1: 'AI Generates',
      title2: 'Smart Notes',
      sub: 'Instant summaries, key points\nand insights — automatically.',
    ),
    _PD(
      img: 'assets/images/onboarding_3.png',
      topA: Color(0xFF78B1F8),
      topB: Color(0xFFAACDF9),
      bg: Color(0xFFEEF4FF),
      tag: 'ORGANIZE',
      title1: 'Save &',
      title2: 'Organize',
      sub: 'Access notes anytime in\nEnglish, Sinhala, or Tamil.',
      isLast: true,
    ),
  ];

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    final p = await SharedPreferences.getInstance();
    await p.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, a, _, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _next() {
    HapticFeedback.selectionClick();
    _entryCtrl.forward(from: 0);
    if (_index < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _orbCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _pages.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _entryCtrl.forward(from: 0);
            },
            itemBuilder: (_, i) => _PageView(
              data: _pages[i],
              orbCtrl: _orbCtrl,
              entryFade: _entryFade,
              entrySlide: _entrySlide,
              dot: _index,
              total: _pages.length,
              onNext: _next,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page data ─────────────────────────────────────────────────────
class _PD {
  final String img, tag, title1, title2, sub;
  final Color topA, topB, bg;
  final bool isLast;
  const _PD({
    required this.img,
    required this.topA,
    required this.topB,
    required this.bg,
    required this.tag,
    required this.title1,
    required this.title2,
    required this.sub,
    this.isLast = false,
  });
}

// ══════════════════════════════════════════════════════════════════
// PAGE WIDGET
// ══════════════════════════════════════════════════════════════════
class _PageView extends StatelessWidget {
  final _PD data;
  final AnimationController orbCtrl;
  final Animation<double> entryFade;
  final Animation<Offset> entrySlide;
  final int dot, total;
  final VoidCallback onNext;

  const _PageView({
    required this.data,
    required this.orbCtrl,
    required this.entryFade,
    required this.entrySlide,
    required this.dot,
    required this.total,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final bot = MediaQuery.of(context).padding.bottom;
    // ignore: unused_local_variable
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: data.bg,
      child: Stack(
        children: [
          // ── Decorative orbs in background ─────────────────────
          AnimatedBuilder(
            animation: orbCtrl,
            builder: (_, _) {
              final t = orbCtrl.value;
              return Stack(
                children: [
                  Positioned(
                    top: sz.height * 0.10 + 18 * math.sin(t * math.pi),
                    right: -40,
                    child: _Orb(size: 160, color: data.topA.withValues(alpha: 0.28)),
                  ),
                  Positioned(
                    top: sz.height * 0.26 - 12 * math.sin(t * math.pi),
                    left: -50,
                    child: _Orb(size: 120, color: data.topB.withValues(alpha: 0.22)),
                  ),
                  Positioned(
                    bottom: sz.height * 0.28 + 10 * math.sin(t * math.pi),
                    right: 20,
                    child: _Orb(size: 80, color: _c1.withValues(alpha: 0.12)),
                  ),
                ],
              );
            },
          ),

          // ── Main content ───────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── TAG chip ─────────────────────────────────────
                FadeTransition(
                  opacity: entryFade,
                  child: SlideTransition(
                    position: entrySlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _TagChip(label: data.tag, color: data.topA),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── TITLE (two lines, big bold) ───────────────────
                FadeTransition(
                  opacity: entryFade,
                  child: SlideTransition(
                    position: entrySlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First line — normal weight
                          Text(
                            data.title1,
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w300,
                              color: _dark,
                              height: 1.1,
                              letterSpacing: -1.0,
                            ),
                          ),
                          // Second line — heavy with gradient shimmer
                          ShaderMask(
                            shaderCallback: (r) => LinearGradient(
                              colors: [data.topA, _c4],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(r),
                            child: Text(
                              data.title2,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── SUBTITLE ─────────────────────────────────────
                FadeTransition(
                  opacity: entryFade,
                  child: SlideTransition(
                    position: entrySlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        data.sub,
                        style: const TextStyle(
                          fontSize: 15,
                          color: _grey,
                          height: 1.65,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── IMAGE — centre of page ────────────────────────
                Expanded(
                  child: FadeTransition(
                    opacity: entryFade,
                    child: Center(
                      child: Image.asset(
                        data.img,
                        width: sz.width * 0.94,
                        height: sz.height * 0.44,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // ── BOTTOM NAV ────────────────────────────────────
                _BottomNav(
                  dot: dot,
                  total: total,
                  isLast: data.isLast,
                  color: data.topA,
                  onNext: onNext,
                  botPad: bot,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAG CHIP
// ══════════════════════════════════════════════════════════════════
class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.4,
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// BOTTOM NAV — dots + button side by side
// ══════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int dot, total;
  final bool isLast;
  final Color color;
  final VoidCallback onNext;
  final double botPad;

  const _BottomNav({
    required this.dot,
    required this.total,
    required this.isLast,
    required this.color,
    required this.onNext,
    required this.botPad,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 28, botPad + 28),
      child: isLast
          // ── Last screen: full-width Get Started ─────────────
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotsRow(dot: dot, total: total, color: color),
                const SizedBox(height: 26),
                _GetStartedBtn(onTap: onNext, color: color),
              ],
            )
          // ── Other screens: dots left, arrow right ────────────
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DotsRow(dot: dot, total: total, color: color),
                _ArrowBtn(onTap: onNext, color: color),
              ],
            ),
    );
  }
}

// ── Dots row ──────────────────────────────────────────────────────
class _DotsRow extends StatelessWidget {
  final int dot, total;
  final Color color;
  const _DotsRow({required this.dot, required this.total, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(total, (i) {
      final on = i == dot;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 6),
        width: on ? 28 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: on ? color : _dotOff,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }),
  );
}

// ── Arrow button ──────────────────────────────────────────────────
class _ArrowBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  const _ArrowBtn({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, _c4],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.arrow_forward_rounded,
        color: Colors.white,
        size: 26,
      ),
    ),
  );
}

// ── Get Started button ────────────────────────────────────────────
class _GetStartedBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  const _GetStartedBtn({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, _c4],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle shine overlay
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 29,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ],
          ),
        ],
      ),
    ),
  );
}

// ── Decorative orb ────────────────────────────────────────────────
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
