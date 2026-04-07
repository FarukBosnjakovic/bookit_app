import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _currentPhotoUrl = '';
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Load current user data from Firestore ──────────────────────────
  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = doc.data();
    if (data == null) return;

    setState(() {
      _nameController.text = data['name'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _currentPhotoUrl = data['photoUrl'] ?? '';
      _isLoading = false;
    });
  }

  // ── Pick image from gallery ────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 512,
    );
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
  }

  // ── Upload image to Firebase Storage ──────────────────────────────
  Future<String?> _uploadImage(String uid) async {
    if (_pickedImage == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child('$uid.jpg');
    await ref.putFile(_pickedImage!);
    return await ref.getDownloadURL();
  }

  // ── Save changes to Firestore ──────────────────────────────────────
  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Ime ne može biti prazno.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Niste prijavljeni.');

      // Upload new photo if one was picked
      String? newPhotoUrl;
      if (_pickedImage != null) {
        newPhotoUrl = await _uploadImage(uid);
      }

      // Build update map
      final updates = <String, dynamic>{
        'name': name,
        'phone': phone,
      };
      if (newPhotoUrl != null) {
        updates['photoUrl'] = newPhotoUrl;
        setState(() => _currentPhotoUrl = newPhotoUrl!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);

      if (!mounted) return;
      _showSnackBar('Profil je uspješno ažuriran!', isError: false);
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      _showSnackBar('Greška pri čuvanju. Pokušajte ponovo.', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFD94F4F) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF6B7C45), strokeWidth: 2.5),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),

                          // ── Top bar ────────────────────────────────
                          Row(
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
                                'Uredi profil',
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

                          const SizedBox(height: 32),

                          // ── Profile photo ──────────────────────────
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 52,
                                  backgroundColor:
                                      const Color(0xFFD8E6C0),
                                  backgroundImage: _pickedImage != null
                                      ? FileImage(_pickedImage!)
                                          as ImageProvider
                                      : _currentPhotoUrl.isNotEmpty
                                          ? NetworkImage('$_currentPhotoUrl?t=${DateTime.now().millisecondsSinceEpoch}')
                                          : null,
                                  child: (_pickedImage == null &&
                                          _currentPhotoUrl.isEmpty)
                                      ? const Icon(Icons.person,
                                          size: 52,
                                          color: Color(0xFF6B7C45))
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6B7C45),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .scaffoldBackgroundColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          Center(
                            child: TextButton(
                              onPressed: _pickImage,
                              child: const Text(
                                'Promijeni fotografiju',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7C45),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Form fields ────────────────────────────
                          _buildSectionLabel(context, 'Ime i prezime'),
                          const SizedBox(height: 8),
                          _EditField(
                            controller: _nameController,
                            hint: 'Ime i prezime',
                            icon: Icons.person_outline,
                          ),

                          const SizedBox(height: 20),

                          _buildSectionLabel(context, 'Email adresa'),
                          const SizedBox(height: 8),
                          // Email is read-only — changing email in
                          // Firebase Auth requires re-authentication
                          _EditField(
                            controller: _emailController,
                            hint: 'Email adresa',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: true,
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'Email adresa se ne može mijenjati.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          _buildSectionLabel(context, 'Broj telefona'),
                          const SizedBox(height: 8),
                          _EditField(
                            controller: _phoneController,
                            hint: 'Broj telefona',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),

                          const SizedBox(height: 40),

                          // ── Save button ────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed:
                                  _isSaving ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF6B7C45),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFFCCD9B0),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'Sačuvaj izmjene',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).textTheme.bodySmall!.color,
      ),
    );
  }
}

// ─── Edit field ───────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool readOnly;

  const _EditField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: TextStyle(
        fontSize: 15,
        color: readOnly
            ? Theme.of(context).textTheme.bodySmall!.color
            : Theme.of(context).textTheme.bodyLarge!.color,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(context).textTheme.bodySmall!.color,
          fontSize: 15,
        ),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7C45)),
        filled: true,
        fillColor: readOnly
            ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
            : Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: readOnly
                ? const Color(0xFFCCD9B0).withOpacity(0.5)
                : const Color(0xFFCCD9B0),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: readOnly
                ? const Color(0xFFCCD9B0).withOpacity(0.5)
                : const Color(0xFF6B7C45),
            width: 1.8,
          ),
        ),
      ),
    );
  }
}