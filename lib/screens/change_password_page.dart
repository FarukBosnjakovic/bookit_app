import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override 
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); 

  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isSaving = false;

  @override  
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // -- Change Password
  Future<void> _changePassword() async {
    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    // -- Validation
    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showSnackBar('Molimo popunite sva polja.', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showSnackBar('Nova lozinka mora imati najmanje 6 znakova.', isError: true);
      return;
    }
    if (newPass != confirm) {
      _showSnackBar('Lozinke se ne podudaraju.', isError: true);
      return;
    }
    if (current == newPass) {
      _showSnackBar('Nova lozinka mora biti različita od trenutne.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception('Niste prijavljeni.');

      // Re-authenticate before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPass);

      if (!mounted) return;
      _showSnackBar('Lozinka je uspješno promijenjena!', isError: false);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          _showSnackBar('Trenutna lozinka nije ispravna', isError: true);
          break;
        case 'weak-password':
          _showSnackBar('Nova lozinka je preslaba. Koristite najmanje 6 znakova', isError: true);
          break;
        default:
          _showSnackBar('Greška: ${e.message}', isError: true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      _showSnackBar('Greška pri promjeni lozinke. Pokušajte ponovo.', isError: true);
    }
  }
  
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: 
          isError 
            ? const Color(0xFFD94F4F)
            : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)
        ),
      ),
    );
  }

  @override  
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 42),

              // -- Top Bar
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Promjena lozinke',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // -- Current Password
              _InputField(
                controller: _currentPasswordController,
                label: 'Trenutna lozinka',
                hint: 'Unesite trenutnu lozinku',
                obscureText: !_currentPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _currentPasswordVisible 
                      ? Icons.visibility_outlined 
                      : Icons.visibility_off_outlined,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                  onPressed: () => setState(
                    () => _currentPasswordVisible = !_currentPasswordVisible
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -- New Password
              _InputField(
                controller: _newPasswordController,
                label: 'Nova lozinka',
                hint: 'Unesite novu lozinku',
                obscureText: !_newPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _newPasswordVisible 
                      ? Icons.visibility_outlined 
                      : Icons.visibility_off_outlined,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                  onPressed: () => setState(
                    () => _newPasswordVisible = !_newPasswordVisible
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -- Confirm Password
              _InputField(
                controller: _confirmPasswordController,
                label: 'Potvrdite lozinku',
                hint: 'Ponovite novu lozinku',
                obscureText: !_confirmPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmPasswordVisible 
                      ? Icons.visibility_outlined 
                      : Icons.visibility_off_outlined,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                  onPressed: () => setState(
                    () => _confirmPasswordVisible = !_confirmPasswordVisible
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // -- Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7C45),
                    foregroundColor: const Color(0xFFCCD9B0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving 
                    ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5
                      ),
                    )
                    : const Text(
                      'Sačuvaj lozinku',
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

// -- Reusable Input Field

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