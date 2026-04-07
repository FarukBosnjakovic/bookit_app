import 'package:flutter/material.dart';
import 'package:bookit/screens/change_password_page.dart';
import 'package:bookit/screens/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  bool _notificationsEnabled = true;
  bool _isDeleting = false;

  // ── Delete account flow ────────────────────────────────────────────
  Future<void> _showDeleteConfirmationDialog() async {
    // Step 1 — confirm intent
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Izbrišite nalog',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        content: Text(
          'Da li ste sigurni da želite izbrisati Vaš nalog? Ova akcija se ne može poništiti.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall!.color,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Odustani',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall!.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Nastavi',
              style: TextStyle(
                color: Color(0xFFD94F4F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Step 2 — ask for password to re-authenticate
    final passwordController = TextEditingController();
    bool passwordVisible = false;

    final password = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: Text(
            'Potvrdite identitet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unesite Vašu lozinku kako bismo potvrdili da ste Vi.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: !passwordVisible,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                decoration: InputDecoration(
                  hintText: 'Lozinka',
                  hintStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      passwordVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Theme.of(context).textTheme.bodySmall!.color,
                      size: 20,
                    ),
                    onPressed: () => setDialogState(
                        () => passwordVisible = !passwordVisible),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFCCD9B0), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF6B7C45), width: 1.8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Odustani',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall!.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, passwordController.text),
              child: const Text(
                'Izbriši nalog',
                style: TextStyle(
                  color: Color(0xFFD94F4F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (password == null || password.isEmpty || !mounted) return;

    // Step 3 — re-authenticate and delete
    setState(() => _isDeleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null)
        throw Exception('Niste prijavljeni.');

      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;

      // Delete Firestore user data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      // Delete favourites subcollection
      final favourites = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favourites')
          .get();
      for (final doc in favourites.docs) {
        await doc.reference.delete();
      }

      // Delete Firebase Auth account
      await user.delete();

      if (!mounted) return;

      // Navigate to login and clear stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isDeleting = false);
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Pogrešna lozinka. Pokušajte ponovo.';
          break;
        case 'too-many-requests':
          message = 'Previše pokušaja. Pokušajte ponovo kasnije.';
          break;
        default:
          message = 'Greška: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD94F4F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _isDeleting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Greška pri brisanju naloga. Pokušajte ponovo.'),
          backgroundColor: const Color(0xFFD94F4F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Top bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Sigurnost',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Security options ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ── Notifications toggle ─────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_outlined,
                                size: 22,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Obavijesti',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _notificationsEnabled,
                                onChanged: (value) => setState(
                                    () => _notificationsEnabled = value),
                                activeThumbColor: Colors.white,
                                activeTrackColor: const Color(0xFFD94F4F),
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor:
                                    const Color(0xFFCCD9B0),
                              ),
                            ],
                          ),
                        ),

                        const Divider(
                            height: 1,
                            indent: 52,
                            color: Color(0xFFECF2DF)),

                        // ── Change password ──────────────────────────
                        _SecurityRow(
                          icon: Icons.lock_outline,
                          label: 'Promijenite lozinku',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ChangePasswordPage()),
                          ),
                        ),

                        const Divider(
                            height: 1,
                            indent: 52,
                            color: Color(0xFFECF2DF)),

                        // ── Delete account ───────────────────────────
                        _SecurityRow(
                          icon: Icons.delete_outline,
                          label: 'Izbrisite nalog',
                          isDestructive: true,
                          onTap: _isDeleting
                              ? () {}
                              : _showDeleteConfirmationDialog,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Full-screen loading overlay while deleting ─────────────
            if (_isDeleting)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF6B7C45), strokeWidth: 2.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Security row ─────────────────────────────────────────────────────────────

class _SecurityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SecurityRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFD94F4F)
        : Theme.of(context).textTheme.bodyLarge!.color!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}