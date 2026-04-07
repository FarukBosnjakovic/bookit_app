import 'package:bookit/manager/manager_signup_page.dart';
import 'package:bookit/screens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:bookit/manager/manager_dashboard_page.dart';
import 'package:bookit/manager/manager_pending_page.dart';
import 'package:bookit/auth/auth_service.dart';
import 'package:bookit/screens/forgot_password_page.dart';
// import 'package:bookit/manager/manager_shell.dart';

// ─── Manager Login Page ──────────────────────────────────────────────────────

class ManagerLoginPage extends StatefulWidget {
  const ManagerLoginPage({super.key});

  @override
  State<ManagerLoginPage> createState() => _ManagerLoginPageState();
}

class _ManagerLoginPageState extends State<ManagerLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  final _authService = AuthService();
  bool _isLoading = false;
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

    // Step 1 — attempt login
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

    // Step 2 — fetch role and status from Firestore
    final userData = await _authService.getCurrentUserData();
    setState(() => _isLoading = false);

    if (!mounted) return;

    final role = userData?['role'] ?? 'user';
    final status = userData?['status'] ?? 'approved';

    // Step 3 — make sure this is actually a manager account
    if (role != 'manager') {
      setState(() => _errorMessage =
          'Ovaj nalog nije registrovan kao nalog menadžera.');
      await _authService.signOut();
      return;
    }

    // Step 4 — route based on approval status
    if (status == 'pending') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const ManagerPendingPage(),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const ManagerDashboardPage(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // ── Back arrow ───────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  size: 24,
                ),
              ),

              const SizedBox(height: 32),

              // ── Manager badge ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B7C45).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6B7C45).withOpacity(0.4),
                    width: 1.2,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 14, color: Color(0xFF6B7C45)),
                    SizedBox(width: 6),
                    Text(
                      'Menadžer restorana',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7C45),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Title ────────────────────────────────────────────────
              Text(
                'Dobrodošli\nnatrag!',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Prijavite se kako biste upravljali\nVašim restoranom.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // ── Email field ──────────────────────────────────────────
              _InputField(
                controller: _emailController,
                label: 'Email adresa',
                hint: 'email@restoran.ba',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // ── Password field ───────────────────────────────────────
              _InputField(
                controller: _passwordController,
                label: 'Lozinka',
                hint: 'Unesite lozinku',
                obscureText: !_passwordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                  onPressed: () => setState(
                      () => _passwordVisible = !_passwordVisible),
                ),
              ),

              const SizedBox(height: 12),

              // ── Forgot password ──────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Zaboravljena lozinka',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7C45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Error message ────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD94F4F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFD94F4F).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: Color(0xFFD94F4F)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFD94F4F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Login button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7C45),
                    disabledBackgroundColor: const Color(0xFFCCD9B0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(
                          color: Color(0xFF6B7C45), width: 1.8),
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

              const SizedBox(height: 32),

              // ── Divider ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color!
                          .withOpacity(0.3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ili',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall!.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color!
                          .withOpacity(0.3),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Register link ────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManagerSignUpPage(),
                      ),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Nemate nalog? ',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            Theme.of(context).textTheme.bodySmall!.color,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Registrujte restoran',
                          style: TextStyle(
                            color: Color(0xFF6B7C45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Switch to user login ─────────────────────────────────
              Center(
                child: GestureDetector(
                  // onTap: () => Navigator.pop(context),
                  onTap:() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginPage()
                      ),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Korisnik? ',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            Theme.of(context).textTheme.bodySmall!.color,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Korisnička prijava',
                          style: TextStyle(
                            color: Color(0xFFD94F4F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
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
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).textTheme.bodyLarge!.color,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(
          color: Theme.of(context).textTheme.bodySmall!.color,
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: Theme.of(context).textTheme.bodySmall!.color,
          fontSize: 15,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
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