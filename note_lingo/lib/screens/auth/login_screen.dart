import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

// ── Onboarding-matched palette ─────────────────────────────────────
const _bgTop = Color(0xFF6AABF8);
const _bgMid = Color(0xFF9AC8FB);
const _bgBot = Color(0xFFEFF5FF);
const _deep = Color(0xFF2356C8);
const _primary = Color(0xFF4F8EF7);
const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);
const _cardBg = Color(0xFFFFFFFF);
const _inputBg = Color(0xFFF0F5FF);
const _border = Color(0xFFD0DFFF);
const _error = Color(0xFFE53E3E);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;

  // Entry animation
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entryCtrl,
    curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

  // Floating orb loop
  late final AnimationController _orbCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _entryCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: _error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(color: _textDark)),
            ),
          ],
        ),
        backgroundColor: _cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signIn(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _googleLoading = true);
    try {
      await context.read<AuthProvider>().signInWithGoogle();
      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full page gradient ──────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgTop, _bgMid, _bgBot],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.38, 1.0],
              ),
            ),
          ),

          // ── Floating decorative orbs ────────────────────────────
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (_, __) {
              final t = _orbCtrl.value;
              return Stack(
                children: [
                  Positioned(
                    top: -40 + 18 * math.sin(t * math.pi),
                    right: -50,
                    child: _Orb(
                      size: 210,
                      color: const Color(0xFF5AA0F8).withOpacity(0.28),
                    ),
                  ),
                  Positioned(
                    top: size.height * 0.32 - 14 * math.sin(t * math.pi),
                    left: -45,
                    child: _Orb(
                      size: 150,
                      color: const Color(0xFF88BFFB).withOpacity(0.22),
                    ),
                  ),
                  Positioned(
                    bottom: size.height * 0.10 + 10 * math.sin(t * math.pi),
                    right: 10,
                    child: _Orb(size: 80, color: _deep.withOpacity(0.10)),
                  ),
                ],
              );
            },
          ),

          // ── Scrollable content ──────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),

                      // ── Logo row ──────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6BAAF8), _deep],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Note',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w300,
                                    color: _textDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Lingo',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ── Heading ───────────────────────────────────
                      const Text(
                        'Welcome back ',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: -1.0,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to continue',
                        style: TextStyle(
                          fontSize: 15,
                          color: _textGrey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Glass card ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.80),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A7CF5).withOpacity(0.10),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Email
                              _FieldLabel(label: 'Email address'),
                              const SizedBox(height: 8),
                              _InputField(
                                controller: _emailCtrl,
                                hint: 'you@example.com',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter your email';
                                  }
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(v.trim())) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Password
                              _FieldLabel(label: 'Password'),
                              const SizedBox(height: 8),
                              _InputField(
                                controller: _passCtrl,
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscure,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: _textGrey,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter your password';
                                  }
                                  if (v.length < 6) return 'Password too short';
                                  return null;
                                },
                              ),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // TODO: forgot password
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: _primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Sign in button
                              _GradientButton(
                                label: 'Sign In',
                                loading: _loading,
                                onTap: _loading ? null : _login,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Divider ───────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: _textGrey.withOpacity(0.30),
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'or',
                              style: TextStyle(
                                fontSize: 13,
                                color: _textGrey.withOpacity(0.70),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: _textGrey.withOpacity(0.30),
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Google button ─────────────────────────────
                      _SocialButton(
                        emoji: '🌐',
                        label: 'Continue with Google',
                        onTap: _googleLoading ? null : _googleLogin,
                        loading: _googleLoading,
                      ),
                      const SizedBox(height: 36),

                      // ── Register link ─────────────────────────────
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                fontSize: 14,
                                color: _textGrey.withOpacity(0.85),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
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

// ══════════════════════════════════════════════════════════════════
// SHARED WIDGETS (scoped to this file)
// ══════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _textDark,
      letterSpacing: 0.1,
    ),
  );
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 15, color: _textDark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _textGrey.withOpacity(0.55), fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: _primary.withOpacity(0.70)),
      suffixIcon: suffix,
      filled: true,
      fillColor: _inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _error, width: 1.5),
      ),
      errorStyle: const TextStyle(color: _error, fontSize: 12),
    ),
    validator: validator,
  );
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _GradientButton({
    required this.label,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(
      opacity: onTap == null ? 0.65 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6BAAF8), _deep],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.40),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // shine
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 27,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ],
        ),
      ),
    ),
  );
}

class _SocialButton extends StatelessWidget {
  final String emoji, label;
  final VoidCallback? onTap;
  final bool loading;
  const _SocialButton({
    required this.emoji,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A7CF5).withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: loading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _textGrey,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
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
      gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
    ),
  );
}
