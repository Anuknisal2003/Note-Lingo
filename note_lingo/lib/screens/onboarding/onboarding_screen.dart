import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _current = 0;
  late AnimationController _btnCtrl;
  late Animation<double> _btnScale;

  final List<_OBPage> _pages = const [
    _OBPage(
      gradient: LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      iconBg: Color(0xFF6C63FF),
      icon: Icons.mic_rounded,
      tag: '🎙️  Voice Recording',
      title: 'Speak,\nDon\'t Type',
      body:
          'Record lectures, meetings and interviews with one tap. Note Lingo captures every word — in English, Sinhala or Tamil.',
    ),
    _OBPage(
      gradient: LinearGradient(
        colors: [Color(0xFF00D9B5), Color(0xFF0099CC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      iconBg: Color(0xFF00D9B5),
      icon: Icons.auto_awesome_rounded,
      tag: '🤖  AI Powered',
      title: 'AI Writes\nYour Notes',
      body:
          'OpenAI Whisper transcribes your speech instantly. GPT summarizes key points so you always have a clean, structured note.',
    ),
    _OBPage(
      gradient: LinearGradient(
        colors: [Color(0xFFFF5370), Color(0xFFFF8A65)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      iconBg: Color(0xFFFF5370),
      icon: Icons.download_rounded,
      tag: '📤  Export Anywhere',
      title: 'Organize\n& Export',
      body:
          'Auto-categorize notes by topic. Export as PDF, DOCX or TXT. Everything securely synced to Firebase — available everywhere.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _btnScale = _btnCtrl;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _next() {
    if (_current < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Animated gradient blob top-right
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            top: -80,
            right: -80,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [page.iconBg.withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Skip button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 20, 0),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _PageContent(page: _pages[i]),
                ),
              ),
              // Bottom section
              Padding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  0,
                  28,
                  MediaQuery.of(context).padding.bottom + 36,
                ),
                child: Column(
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _current;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: active ? page.gradient : null,
                            color: active ? null : AppColors.bgBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    // CTA button
                    GestureDetector(
                      onTapDown: (_) => _btnCtrl.reverse(),
                      onTapUp: (_) {
                        _btnCtrl.forward();
                        _next();
                      },
                      onTapCancel: () => _btnCtrl.forward(),
                      child: ScaleTransition(
                        scale: _btnScale,
                        child: Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: page.gradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: page.iconBg.withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _current == _pages.length - 1
                                  ? 'Get Started 🚀'
                                  : 'Continue',
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OBPage {
  final LinearGradient gradient;
  final Color iconBg;
  final IconData icon;
  final String tag;
  final String title;
  final String body;
  const _OBPage({
    required this.gradient,
    required this.iconBg,
    required this.icon,
    required this.tag,
    required this.title,
    required this.body,
  });
}

class _PageContent extends StatefulWidget {
  final _OBPage page;
  const _PageContent({required this.page});

  @override
  State<_PageContent> createState() => _PageContentState();
}

class _PageContentState extends State<_PageContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: widget.page.gradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: widget.page.iconBg.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(widget.page.icon, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 36),
              // Tag pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.page.iconBg.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.page.iconBg.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  widget.page.tag,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.page.iconBg,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                widget.page.title,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 16),
              // Body
              Text(
                widget.page.body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
