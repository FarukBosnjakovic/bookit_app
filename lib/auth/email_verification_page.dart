import 'package:bookit/screens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:bookit/auth/auth_service.dart';
import 'package:bookit/screens/splash_screen_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  final String password;

  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;
  bool _messageIsError = false;

  // ── Check if verified and proceed ─────────────────────────────────
  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    final verified = await _authService.checkEmailVerified(
      email: widget.email,
      password: widget.password,
    );

    if (!mounted) return;

    if (verified) {
      // Replace the entire stack with SplashScreen which will re-route
      // based on the now-authenticated + verified user
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _isChecking = false;
        _message =
            'Email još nije verificiran. Provjerite inbox i kliknite na link.';
        _messageIsError = true;
      });
    }
  }

  // ── Resend verification email ──────────────────────────────────────
  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _message = null;
    });

    final error = await _authService.resendVerificationEmail(
      email: widget.email,
      password: widget.password,
    );

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (error == null) {
        _message = 'Email je ponovo poslan na ${widget.email}.';
        _messageIsError = false;
      } else {
        _message = error;
        _messageIsError = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Icon ─────────────────────────────────────────────
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFECF2DF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 44,
                  color: Color(0xFF6B7C45),
                ),
              ),

              const SizedBox(height: 28),

              // ── Title ─────────────────────────────────────────────
              Text(
                'Verificirajte email',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),

              // ── Description ───────────────────────────────────────
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                  children: [
                    const TextSpan(
                        text: 'Poslali smo link za verifikaciju na\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7C45),
                      ),
                    ),
                    const TextSpan(
                        text:
                            '\n\nOtvorite email i kliknite na link, a zatim se\nvratite ovdje.'),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Feedback message ──────────────────────────────────
              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _messageIsError
                        ? const Color(0xFFD94F4F).withOpacity(0.10)
                        : const Color(0xFF4CAF50).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _messageIsError
                          ? const Color(0xFFD94F4F).withOpacity(0.3)
                          : const Color(0xFF4CAF50).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _messageIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: _messageIsError
                            ? const Color(0xFFD94F4F)
                            : const Color(0xFF4CAF50),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _messageIsError
                                ? const Color(0xFFD94F4F)
                                : const Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Primary button: already verified ──────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7C45),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCCD9B0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Verificirao sam email',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Secondary button: resend ───────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _isResending ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7C45),
                    side: const BorderSide(
                        color: Color(0xFF6B7C45), width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Color(0xFF6B7C45), strokeWidth: 2.5),
                        )
                      : const Text(
                          'Pošalji ponovo',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Back to login ──────────────────────────────────────
              GestureDetector(
                // onTap: () => Navigator.pop(context),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginPage(),
                    ),
                  );
                },
                child: const Text(
                  'Nazad na prijavu',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8A9A7A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}