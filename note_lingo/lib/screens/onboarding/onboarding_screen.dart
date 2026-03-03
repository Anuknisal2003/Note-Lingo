// lib/screens/onboarding/onboarding_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';

const _blue = Color(0xFF4A7CF5);
const _bgPage = Color(0xFFF2F6FF);
const _textDark = Color(0xFF1C2340);
const _textGrey = Color(0xFF6B7280);
const _dotActive = Color(0xFF4A7CF5);
const _dotInactive = Color(0xFFCED8F0);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _next() {
    if (_page < 3) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _ctrl,
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          _SplashScreen(onNext: _next),
          _FeaturePage(
            onNext: _next,
            dotIndex: 0,
            title: 'Record Your Voice',
            subtitle: 'Capture lectures, meetings, and\nideas instantly.',
            footerText: 'Capture lectures, meetings,\nand ideas instantly.',
            topColors: const [
              Color(0xFF9EC3FA),
              Color(0xFFD8E8FF),
              Colors.white,
            ],
            illustration: const _PersonIllustration(),
          ),
          _FeaturePage(
            onNext: _next,
            dotIndex: 1,
            title: 'AI Generates Smart Notes',
            subtitle: 'Automatic summaries and\nkey points.',
            footerText: 'Automatic summaries and\nkey points.',
            topColors: const [
              Color(0xFFB8D2FC),
              Color(0xFFE4EEFF),
              Colors.white,
            ],
            illustration: const _RobotIllustration(),
          ),
          _SavePage(onDone: _finish),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// SCREEN 1 — SPLASH
// ══════════════════════════════════════════════════════
class _SplashScreen extends StatefulWidget {
  final VoidCallback onNext;
  const _SplashScreen({required this.onNext});
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onNext,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF9EC8FB),
              Color(0xFF6AABF7),
              Color(0xFF8DC3FB),
              Color(0xFFBDD9FB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
        ),
        child: SafeArea(child: Center(child: _buildCard(context))),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.70;
    final h = MediaQuery.of(context).size.height * 0.42;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6BAAF8), Color(0xFF3F76F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A6EE8).withOpacity(0.45),
            blurRadius: 45,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Note Lingo',
            style: TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI Voice Note Generator',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 48),
          AnimatedBuilder(
            animation: _wave,
            builder: (_, __) => CustomPaint(
              size: const Size(210, 54),
              painter: _WavePainter(_wave.value),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);
  static const _bars = [
    0.22,
    0.38,
    0.52,
    0.68,
    0.48,
    0.32,
    0.62,
    0.88,
    1.0,
    0.72,
    0.52,
    0.78,
    0.58,
    0.38,
    0.28,
    0.48,
    0.72,
    1.0,
    0.82,
    0.58,
    0.42,
    0.68,
    0.48,
    0.32,
    0.58,
    0.38,
    0.28,
    0.22,
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final n = _bars.length;
    final gap = size.width / (n * 2);
    for (int i = 0; i < n; i++) {
      final x = i * gap * 2 + gap;
      final anim = math.sin((i / n) * math.pi * 2 + t * math.pi * 2);
      final bh = (_bars[i] + anim * 0.2).clamp(0.1, 1.0) * size.height;
      final y = (size.height - bh) / 2;
      canvas.drawLine(Offset(x, y), Offset(x, y + bh), p);
    }
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════
// SCREENS 2 & 3 — FEATURE PAGES
// ══════════════════════════════════════════════════════
class _FeaturePage extends StatelessWidget {
  final VoidCallback onNext;
  final int dotIndex;
  final String title, subtitle, footerText;
  final List<Color> topColors;
  final Widget illustration;

  const _FeaturePage({
    required this.onNext,
    required this.dotIndex,
    required this.title,
    required this.subtitle,
    required this.footerText,
    required this.topColors,
    required this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: sh * 0.50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: topColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: SafeArea(bottom: false, child: Center(child: illustration)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textDark,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                color: _textGrey,
                height: 1.55,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              footerText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: _textGrey,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Dots(active: dotIndex),
          const SizedBox(height: 24),
          _ArrowBtn(onTap: onNext),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// SCREEN 4 — SAVE & ORGANIZE
// ══════════════════════════════════════════════════════
class _SavePage extends StatelessWidget {
  final VoidCallback onDone;
  const _SavePage({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    return Container(
      color: _bgPage,
      child: Column(
        children: [
          Container(
            height: sh * 0.51,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9EC3FA), Color(0xFFCFDFFB), _bgPage],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            child: const SafeArea(
              bottom: false,
              child: Center(child: _FolderIllustration()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
            child: const Text(
              'Save & Organize',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Access notes anytime\nin English, Sinhala, or Tamil.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: _textGrey, height: 1.55),
            ),
          ),
          const Spacer(),
          const _Dots(active: 2),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GestureDetector(
              onTap: onDone,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B96F5), Color(0xFF3A6EE8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withOpacity(0.40),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 38),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════
class _Dots extends StatelessWidget {
  final int active;
  const _Dots({required this.active});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) {
      final on = i == active;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: on ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: on ? _dotActive : _dotInactive,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }),
  );
}

class _ArrowBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ArrowBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6BA3F8), Color(0xFF3A6EE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.40),
            blurRadius: 18,
            offset: const Offset(0, 7),
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

// ══════════════════════════════════════════════════════
// ILLUSTRATIONS
// ══════════════════════════════════════════════════════

class _PersonIllustration extends StatelessWidget {
  const _PersonIllustration();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 270,
    height: 250,
    child: CustomPaint(painter: _PersonPainter()),
  );
}

class _PersonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + 10;
    final shirt = Paint()..color = const Color(0xFF5B96F5);
    final skin = Paint()..color = const Color(0xFFFFCBA4);
    final hair = Paint()..color = const Color(0xFF1A1A1A);

    // Sparkles
    _spark(canvas, Offset(cx + 78, 20), 7, const Color(0xFFABC8F8));
    _spark(canvas, Offset(cx - 82, 52), 5, const Color(0xFFABC8F8));
    _spark(canvas, Offset(cx + 58, 92), 4, const Color(0xFFB8D0F8));

    // Body
    canvas.drawPath(
      Path()
        ..moveTo(cx - 54, 218)
        ..quadraticBezierTo(cx - 58, 158, cx - 28, 142)
        ..lineTo(cx + 28, 142)
        ..quadraticBezierTo(cx + 58, 158, cx + 54, 218)
        ..close(),
      shirt,
    );

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 130), width: 22, height: 26),
        const Radius.circular(8),
      ),
      skin,
    );

    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, 90), width: 74, height: 80),
      hair,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, 96), width: 66, height: 70),
      skin,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - 37, 84)
        ..quadraticBezierTo(cx - 18, 54, cx, 52)
        ..quadraticBezierTo(cx + 18, 54, cx + 37, 84)
        ..quadraticBezierTo(cx + 28, 74, cx, 72)
        ..quadraticBezierTo(cx - 28, 74, cx - 37, 84)
        ..close(),
      hair,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 34, 97), width: 13, height: 17),
      skin,
    );

    // Eyes
    final ep = Paint()..color = const Color(0xFF222222);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 13, 92), width: 11, height: 8),
      ep,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 13, 92), width: 11, height: 8),
      ep,
    );
    canvas.drawCircle(Offset(cx - 10, 89), 2.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + 16, 89), 2.5, Paint()..color = Colors.white);

    // Smile
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, 106), width: 24, height: 14),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = const Color(0xFFD4845A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Arm + hand
    canvas.drawPath(
      Path()
        ..moveTo(cx + 28, 150)
        ..quadraticBezierTo(cx + 70, 136, cx + 84, 106)
        ..quadraticBezierTo(cx + 87, 96, cx + 80, 94)
        ..quadraticBezierTo(cx + 72, 97, cx + 70, 110)
        ..quadraticBezierTo(cx + 58, 136, cx + 40, 150)
        ..close(),
      shirt,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 80, 97), width: 19, height: 23),
      skin,
    );

    // Phone body + screen
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 86, 72), width: 30, height: 48),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF1C2340),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 86, 72), width: 24, height: 40),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF4A80F0),
    );

    // Mic icon
    final mp = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 86, 68), width: 8, height: 12),
        const Radius.circular(4),
      ),
      mp,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + 86, 76), width: 12, height: 8),
      math.pi,
      math.pi,
      false,
      mp,
    );
    canvas.drawLine(Offset(cx + 86, 80), Offset(cx + 86, 84), mp);

    // Sound waves
    for (int i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx + 60, 72),
          width: i * 18.0,
          height: i * 15.0,
        ),
        -math.pi * 0.4,
        math.pi * 0.8,
        false,
        Paint()
          ..color = const Color(0xFF8DB8FA).withOpacity(0.78 - i * 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  void _spark(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(
        c,
        Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
        p..style = PaintingStyle.stroke,
      );
    }
    canvas.drawCircle(c, r * 0.22, p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_PersonPainter o) => false;
}

class _RobotIllustration extends StatelessWidget {
  const _RobotIllustration();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 270,
    height: 250,
    child: CustomPaint(painter: _RobotPainter()),
  );
}

class _RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;

    final blue = Paint()..color = const Color(0xFF4A80F0);
    final light = Paint()..color = const Color(0xFF7BABF8);
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = const Color(0xFF2755D8);
    final card = Paint()..color = const Color(0xFFDEEAFD);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 40), width: 112, height: 100),
        const Radius.circular(24),
      ),
      blue,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 26), width: 90, height: 40),
        const Radius.circular(16),
      ),
      light,
    );
    canvas.drawCircle(Offset(cx, cy + 62), 11, light);
    canvas.drawCircle(Offset(cx, cy + 62), 6, blue);

    // Head
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 36), width: 100, height: 88),
        const Radius.circular(28),
      ),
      blue,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 54), width: 80, height: 28),
        const Radius.circular(14),
      ),
      light,
    );

    // Antenna
    final ap = Paint()
      ..color = const Color(0xFF5B96F5)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 80), Offset(cx, cy - 98), ap);
    canvas.drawCircle(Offset(cx, cy - 102), 8, dark);
    canvas.drawCircle(Offset(cx, cy - 102), 4, white);

    // Eyes
    for (final ex in [cx - 23.0, cx + 23.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, cy - 36), width: 28, height: 24),
        white,
      );
      canvas.drawCircle(Offset(ex, cy - 36), 8, dark);
      canvas.drawCircle(Offset(ex + 3, cy - 39), 3, white);
    }

    // Smile
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 18), width: 36, height: 20),
      0.25,
      math.pi - 0.5,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    // Arms
    for (final ax in [cx - 72.0, cx + 72.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(ax, cy + 36), width: 22, height: 52),
          const Radius.circular(11),
        ),
        light,
      );
    }

    // Chat bubble
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - 90, cy - 20),
          width: 46,
          height: 32,
        ),
        const Radius.circular(11),
      ),
      card,
    );
    final lp = Paint()
      ..color = const Color(0xFF9BB8F5)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 103, cy - 24), Offset(cx - 77, cy - 24), lp);
    canvas.drawLine(Offset(cx - 99, cy - 15), Offset(cx - 81, cy - 15), lp);

    // Note card
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + 88, cy - 42),
          width: 38,
          height: 46,
        ),
        const Radius.circular(8),
      ),
      card,
    );
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(cx + 75, cy - 52 + i * 10.0),
        Offset(cx + 100, cy - 52 + i * 10.0),
        lp,
      );
    }

    // Diamonds
    for (final d in [Offset(cx - 62, cy - 82), Offset(cx + 66, cy - 70)]) {
      final r = d.dx < cx ? 6.0 : 5.0;
      canvas.drawPath(
        Path()
          ..moveTo(d.dx, d.dy - r)
          ..lineTo(d.dx + r * 0.6, d.dy)
          ..lineTo(d.dx, d.dy + r)
          ..lineTo(d.dx - r * 0.6, d.dy)
          ..close(),
        Paint()..color = const Color(0xFFB0CCF8),
      );
    }
  }

  @override
  bool shouldRepaint(_RobotPainter o) => false;
}

class _FolderIllustration extends StatelessWidget {
  const _FolderIllustration();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 310,
    height: 250,
    child: CustomPaint(painter: _FolderPainter()),
  );
}

class _FolderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;

    _folder(
      canvas,
      Offset(cx - 18, cy + 20),
      154,
      110,
      const Color(0xFF3A6EE8),
    );
    _folder(
      canvas,
      Offset(cx + 15, cy + 13),
      150,
      108,
      const Color(0xFF5B96F5),
    );

    // Papers
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 54, cy - 70, 60, 82),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFFE4EDFB),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 30, cy - 78, 62, 86),
        const Radius.circular(7),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 14, cy - 78, 16, 22),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF4CAF50),
    );

    _folder(canvas, Offset(cx, cy + 2), 158, 114, const Color(0xFF7BB3F8));

    // Checklist
    final lp = Paint()
      ..color = const Color(0xFFCDD8F0)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final cp = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final bp = Paint()
      ..color = const Color(0xFFCDD8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final y = cy - 46 + i * 16.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - 16, y), width: 10, height: 10),
          const Radius.circular(2),
        ),
        bp,
      );
      if (i < 2) {
        canvas.drawPath(
          Path()
            ..moveTo(cx - 20, y)
            ..lineTo(cx - 16, y + 3.5)
            ..lineTo(cx - 11, y - 4),
          cp,
        );
      }
      canvas.drawLine(Offset(cx - 6, y), Offset(cx + 26, y), lp);
    }
  }

  void _folder(Canvas canvas, Offset c, double w, double h, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - w / 2, c.dy - h / 2)
        ..lineTo(c.dx - w / 2 + 40, c.dy - h / 2)
        ..quadraticBezierTo(
          c.dx - w / 2 + 48,
          c.dy - h / 2,
          c.dx - w / 2 + 52,
          c.dy - h / 2 + 13,
        )
        ..lineTo(c.dx + w / 2, c.dy - h / 2 + 13)
        ..lineTo(c.dx + w / 2, c.dy + h / 2)
        ..lineTo(c.dx - w / 2, c.dy + h / 2)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_FolderPainter o) => false;
}
