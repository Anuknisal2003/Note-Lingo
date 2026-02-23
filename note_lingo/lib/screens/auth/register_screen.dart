import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/nl_button.dart';
import '../../widgets/nl_text_field.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: AppColors.bgSurface,
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
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
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
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Join Note Lingo',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Create an account to start capturing smarter',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 36),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NLTextField(
                    controller: _nameCtrl,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  NLTextField(
                    controller: _emailCtrl,
                    label: 'Email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter email';
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(v.trim()))
                        return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Role selector
                  Text(
                    'I am a...',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _roles.map((role) {
                      final selected = _selectedRole == role;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = role),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? AppColors.primaryGradient
                                  : null,
                              color: selected ? null : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.bgBorder,
                              ),
                            ),
                            child: Text(
                              role,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  NLTextField(
                    controller: _passCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePass,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter password';
                      if (v.length < 8) return 'Minimum 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  NLTextField(
                    controller: _confirmCtrl,
                    label: 'Confirm password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirm,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) {
                      if (v != _passCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  NLButton(
                    label: 'Create Account 🎉',
                    onPressed: _loading ? null : _register,
                    loading: _loading,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
