import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:bookit/home/home_page.dart';
import 'package:bookit/auth/auth_service.dart';
import 'package:bookit/auth/email_verification_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  final _authService = AuthService();
  bool _isLoading = false;
  bool _isSocialLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isSocialLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.signInWithGoogle();

    setState(() => _isSocialLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _handleAppleSignUp() async {
    setState(() {
      _isSocialLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.signInWithApple();

    setState(() => _isSocialLoading = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
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
                      'Registracija',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2A1A),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Full name field ───────────────────────────────────
                    _InputField(
                      controller: _nameController,
                      label: 'Ime i Prezime',
                      hint: 'Ime i Prezime',
                      keyboardType: TextInputType.name,
                    ),

                    const SizedBox(height: 16),

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

                    const SizedBox(height: 24),

                    // ── Error message ─────────────────────────────────────
                    if (_errorMessage != null) ...[
                      _ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // ── Register button ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _isSocialLoading)
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = null;
                                });

                                final error = await _authService.signUpUser(
                                  name: _nameController.text.trim(),
                                  email: _emailController.text.trim(),
                                  phone: '',
                                  password: _passwordController.text.trim(),
                                );

                                setState(() => _isLoading = false);

                                if (error == null) {
                                  if (!mounted) return;
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EmailVerificationPage(
                                        email: _emailController.text.trim(),
                                        password: _passwordController.text,
                                      ),
                                    ),
                                    (route) => false,
                                  );
                                } else {
                                  setState(() => _errorMessage = error);
                                }
                              },
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
                                'Registracija',
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
                                  icon: const _GoogleIcon(),
                                  onTap: _handleGoogleSignUp,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SocialButton(
                                  label: 'Apple',
                                  icon: const Icon(
                                    Icons.apple,
                                    size: 20,
                                    color: Color(0xFF1E2A1A),
                                  ),
                                  onTap: _handleAppleSignUp,
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

            // ── Bottom "Have account" text ─────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Imate nalog? ',
                    style: TextStyle(fontSize: 14, color: Color(0xFF4A5340)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                    child: const Text(
                      'Prijavite se',
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
            ),

            // ── Bottom nav bar ─────────────────────────────────────────
            const _BottomNavBar(),
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
      style: const TextStyle(fontSize: 15, color: Color(0xFF1E2A1A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        labelStyle: const TextStyle(color: Color(0xFF8A9A7A), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFFAABB99), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFECF2DF),
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
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFCCD9B0), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ili',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A9A7A)),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFCCD9B0), thickness: 1)),
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
          color: const Color(0xFFECF2DF),
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
                color: Color(0xFF1E2A1A),
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
    return const SizedBox(
      width: 20,
      height: 20,
      child: Text(
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

// ─── Bottom navigation bar ────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFFECF2DF),
        border: Border(top: BorderSide(color: Color(0xFFCCD9B0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavBarIcon(icon: Icons.search, onTap: () {}),
          _NavBarIcon(icon: Icons.person_outline, onTap: () {}),
          _NavBarIcon(
            icon: Icons.home,
            onTap: () {},
            color: const Color(0xFFD94F4F),
          ),
          _NavBarIcon(icon: Icons.restaurant_menu, onTap: () {}),
        ],
      ),
    );
  }
}

class _NavBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _NavBarIcon({
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF6B7C45),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}