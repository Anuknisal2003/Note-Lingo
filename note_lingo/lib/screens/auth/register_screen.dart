import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';

// ── Onboarding-matched palette ─────────────────────────────────────
const _bgTop = Color(0xFF88BAF9); // onboarding page 2 topA
const _bgMid = Color(0xFFB5D5FC); // onboarding page 2 topB
const _bgBot = Color(0xFFF3F7FF); // onboarding page 2 bg
const _deep = Color(0xFF2356C8);
const _primary = Color(0xFF4F8EF7);
const _textDark = Color(0xFF0E1A3A);
const _textGrey = Color(0xFF6B7A99);
const _inputBg = Color(0xFFF0F5FF);
const _border = Color(0xFFD0DFFF);
const _error = Color(0xFFE53E3E);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String _selectedRole = 'Student';

  final List<String> _roles = [
    'Student',
    'Professional',
    'Researcher',
    'Other',
  ];

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
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

  // Floating orb loop
  late final AnimationController _orbCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
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
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _nameCtrl.text.trim(),
        _selectedRole,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (_) => false,
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                stops: [0.0, 0.35, 1.0],
              ),
            ),
          ),

          // ── Floating decorative orbs ────────────────────────────
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (_, _) {
              final t = _orbCtrl.value;
              return Stack(
                children: [
                  Positioned(
                    top: -30 + 16 * math.sin(t * math.pi),
                    right: -55,
                    child: _Orb(
                      size: 200,
                      color: const Color(0xFF5AA0F8).withValues(alpha: 0.26),
                    ),
                  ),
                  Positioned(
                    top: size.height * 0.40 - 12 * math.sin(t * math.pi),
                    left: -45,
                    child: _Orb(
                      size: 140,
                      color: const Color(0xFF88BFFB).withValues(alpha: 0.20),
                    ),
                  ),
                  Positioned(
                    bottom: 40 + 8 * math.sin(t * math.pi),
                    right: 20,
                    child: _Orb(size: 70, color: _deep.withValues(alpha: 0.09)),
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
                child: Column(
                  children: [
                    // ── App bar ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _CircleBack(onTap: () => Navigator.pop(context)),
                          const SizedBox(width: 12),
                          const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // ── Heading ────────────────────────────
                            const Text(
                              'Join NoteLingo',
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
                              'Create an account to start capturing smarter',
                              style: TextStyle(
                                fontSize: 14,
                                color: _textGrey,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ── Glass card ─────────────────────────
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4A7CF5,
                                    ).withValues(alpha: 0.10),
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
                                    // Full name
                                    _FieldLabel(label: 'Full name'),
                                    const SizedBox(height: 8),
                                    _InputField(
                                      controller: _nameCtrl,
                                      hint: 'Your name',
                                      icon: Icons.person_outline_rounded,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? 'Enter your name'
                                          : null,
                                    ),
                                    const SizedBox(height: 18),

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
                                          return 'Enter email';
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

                                    // Role selector
                                    _FieldLabel(label: 'I am a…'),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: _roles.map((role) {
                                        final sel = _selectedRole == role;
                                        return Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _selectedRole = role,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              margin: const EdgeInsets.only(
                                                right: 7,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: sel
                                                    ? const LinearGradient(
                                                        colors: [
                                                          Color(0xFF6BAAF8),
                                                          _deep,
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      )
                                                    : null,
                                                color: sel ? null : _inputBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: sel
                                                      ? _primary
                                                      : _border,
                                                  width: 1.2,
                                                ),
                                                boxShadow: sel
                                                    ? [
                                                        BoxShadow(
                                                          color: _primary
                                                              .withValues(alpha: 
                                                                0.30,
                                                              ),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Text(
                                                role,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: sel
                                                      ? Colors.white
                                                      : _textGrey,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 18),

                                    // Password
                                    _FieldLabel(label: 'Password'),
                                    const SizedBox(height: 8),
                                    _InputField(
                                      controller: _passCtrl,
                                      hint: '••••••••',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePass,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscurePass
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                          color: _textGrey,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePass = !_obscurePass,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Enter password';
                                        }
                                        if (v.length < 8) {
                                          return 'Minimum 8 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),

                                    // Confirm password
                                    _FieldLabel(label: 'Confirm password'),
                                    const SizedBox(height: 8),
                                    _InputField(
                                      controller: _confirmCtrl,
                                      hint: '••••••••',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscureConfirm,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscureConfirm
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                          color: _textGrey,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscureConfirm =
                                              !_obscureConfirm,
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v != _passCtrl.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 26),

                                    // Register button
                                    _GradientButton(
                                      label: 'Create Account ',
                                      loading: _loading,
                                      onTap: _loading ? null : _register,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
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

class _CircleBack extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBack({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        shape: BoxShape.circle,
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A7CF5).withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 16,
        color: _textDark,
      ),
    ),
  );
}

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
      hintStyle: TextStyle(color: _textGrey.withValues(alpha: 0.55), fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: _primary.withValues(alpha: 0.70)),
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
              color: _primary.withValues(alpha: 0.40),
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
                      Colors.white.withValues(alpha: 0.18),
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
                      letterSpacing: 0.2,
                    ),
                  ),
          ],
        ),
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
