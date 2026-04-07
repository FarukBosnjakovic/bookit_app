import 'package:flutter/material.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override  
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}


class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  @override  
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFFF0F5E4),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // -- Top bar with back arrow and title
              Row(
                children: [
                  GestureDetector(
                    // TODO: Navigate back
                    onTap: () {},
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1E2A1A),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Obnovite lozinku',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2A1A),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // -- Subtitle
              const Text(
                'Kreirajte novu lozinku da bi ste se prijavili',
                style: TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF5A6355),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              // -- Nova lozinka polje
              _InputField(
                controller: _newPasswordController,
                label: 'Nova lozinka',
                hint: 'Nova lozinka',
                obscureText: !_newPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _newPasswordVisible 
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                    color: const Color(0xFF8A9A7A),
                  ),
                  onPressed: () {
                    setState(() => _newPasswordVisible = !_newPasswordVisible);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // -- Potvrdite lozinku polje
              _InputField(
                controller: _confirmPasswordController,
                label: 'Potvrdite lozinku',
                hint: 'Potvrdite lozinku',
                obscureText: !_confirmPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                    color: const Color(0xFF8A9A7A),
                  ),
                  onPressed: () {
                    setState(() => _confirmPasswordVisible = !_confirmPasswordVisible);
                  },
                ),
              ),

              const SizedBox(height: 36),

              // -- Obnovite lozinku
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  // TODO: Add reset password logic
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7C45),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Obnovite lozinku',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// -- Reusable input field

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override  
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1E2A1A),
      ),

      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        labelStyle: const TextStyle(
          color: Color(0xFF8A9A7A),
          fontSize: 13,
        ),

        hintStyle: const TextStyle(
          color: Color(0xFFAABB99),
          fontSize: 15,
        ),

        filled: true,
        fillColor: const Color(0xFFECF2DF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFCCD9B0),
            width: 1.2,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF6B7C45),
            width: 1.8,
          ),
        ),
      ),
    );
  }
}