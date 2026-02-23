import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'onboarding/onboarding_screen.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final hasOnboarding = await auth.hasSeenOnboarding();

    if (!mounted) return;

    Widget destination;
    if (!hasOnboarding) {
      destination = const OnboardingScreen();
    } else if (auth.isLoggedIn) {
      destination = const HomeScreen();
    } else {
      destination = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Background radial glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.7,
                    colors: [
                      AppColors.primary.withOpacity(0.12 * _glowAnim.value),
                      AppColors.bgDark,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -60,
            right: -60,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.08 * _glowAnim.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withOpacity(0.06 * _glowAnim.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Center content
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App icon
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(
                                0.5 * _glowAnim.value,
                              ),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // App name
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: Text(
                          'Note Lingo',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI-Powered Notes',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom loading indicator
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Opacity(
                opacity: _glowAnim.value,
                child: Center(
                  child: SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.bgBorder,
                        color: AppColors.primary,
                        minHeight: 2,
                      ),
                    ),
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
