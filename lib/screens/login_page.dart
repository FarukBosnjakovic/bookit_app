import 'package:flutter/material.dart';
import 'sign_up_page.dart';
import 'forgot_password_page.dart';
import 'package:bookit/home/home_page.dart';
import 'package:bookit/manager/manager_login_page.dart';
import 'package:bookit/manager/manager_dashboard_page.dart';
import 'package:bookit/manager/manager_pending_page.dart';
import 'package:bookit/auth/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  final _authService = AuthService();
  bool _isLoading = false;
  bool _isSocialLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    await _routeAfterLogin();
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isSocialLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.signInWithGoogle();

    if (error != null) {
      setState(() {
        _isSocialLoading = false;
        _errorMessage = error;
      });
      return;
    }

    await _routeAfterLogin();
  }

  Future<void> _handleAppleLogin() async {
    setState(() {
      _isSocialLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.signInWithApple();

    if (error != null) {
      setState(() {
        _isSocialLoading = false;
        _errorMessage = error;
      });
      return;
    }

    await _routeAfterLogin();
  }

  Future<void> _routeAfterLogin() async {
    final userData = await _authService.getCurrentUserData();

    setState(() {
      _isLoading = false;
      _isSocialLoading = false;
    });

    if (!mounted) return;

    final role = userData?['role'] ?? 'user';
    final status = userData?['status'] ?? 'approved';

    if (role == 'manager' && status == 'pending') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ManagerPendingPage()),
        (route) => false,
      );
    } else if (role == 'manager') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ManagerDashboardPage()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Main scrollable content ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),

                    // ── Title ────────────────────────────────────────────
                    const Text(
                      'Prijava',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: null, // Inherit from Theme
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Email field ───────────────────────────────────────
                    _InputField(
                      controller: _emailController,
                      label: 'Email adresa',
                      hint: 'Email adresa',
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16),

                    // ── Password field ────────────────────────────────────
                    _InputField(
                      controller: _passwordController,
                      label: 'Lozinka',
                      hint: 'Lozinka',
                      obscureText: !_passwordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF8A9A7A),
                        ),
                        onPressed: () =>
                            setState(() => _passwordVisible = !_passwordVisible),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Forgot password link ──────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Zaboravljena lozinka',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7C45),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Error message ─────────────────────────────────────
                    if (_errorMessage != null) ...[
                      _ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // ── Login button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            (_isLoading || _isSocialLoading) ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B7C45),
                          disabledBackgroundColor: const Color(0xFFCCD9B0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Prijavite se',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Divider ───────────────────────────────────────────
                    const _OrDivider(),

                    const SizedBox(height: 20),

                    // ── Social buttons ────────────────────────────────────
                    _isSocialLoading
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: Color(0xFF6B7C45),
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _SocialButton(
                                  label: 'Google',
                                  icon: _GoogleIcon(),
                                  onTap: _handleGoogleLogin,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SocialButton(
                                  label: 'Apple',
                                  icon: Icon(
                                    Icons.apple,
                                    size: 20,
                                    color: Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                  onTap: _handleAppleLogin,
                                ),
                              ),
                            ],
                          ),

                    const SizedBox(height: 20),

                    // ── Guest link ────────────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
                        ),
                        child: const Text(
                          'Gost',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF6B7C45),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom links ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text(
                        'Nemate nalog? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium!.color,
                          ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUpPage()),
                        ),
                        child: const Text(
                          'Registrujte se',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7C45),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF6B7C45),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManagerLoginPage()),
                    ),
                    child: const Text(
                      'Prijava za menadžere restorana',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8A9A7A),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF8A9A7A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable input field ─────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: const TextStyle(fontSize: 15),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFCCD9B0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF6B7C45), width: 1.8),
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFD94F4F).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD94F4F).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFD94F4F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFD94F4F)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── "ili" divider ────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFFCCD9B0), thickness: 1),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ili',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A9A7A)),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0xFFCCD9B0), thickness: 1),
        ),
      ],
    );
  }
}

// ─── Social sign-in button ────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: null, // Inherit from Theme
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Google "G" icon ──────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
          height: 1.3,
        ),
      ),
    );
  }
}