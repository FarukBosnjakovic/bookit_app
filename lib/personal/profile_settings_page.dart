// import 'dart:typed_data';
import 'package:bookit/personal/edit_profile_page.dart';
import 'package:bookit/personal/users_reviews_page.dart';
import 'package:bookit/search/search_restaurants.dart';
import 'package:bookit/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:bookit/home/home_page.dart';
import 'package:bookit/restaurants/favourite_restaurants_page.dart';
import 'package:bookit/settings/security_page.dart';
import 'package:bookit/settings/support_page.dart';
import 'package:bookit/auth/auth_service.dart';
import 'package:bookit/screens/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookit/restaurants/restaurants_bookings_page.dart';
import 'package:bookit/points/bookit_points_page.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  int _selectedNavIndex = 4;

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Odjava',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge!.color)),
        content: Text('Da li ste sigurni da se želite odjaviti?',
            style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium!.color,
                height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Odustani',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall!.color,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Odjavi se',
                style: TextStyle(
                    color: Color(0xFFD94F4F), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── New cover + avatar header ──────────────────────
                    _ProfileHeader(),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: 'Vaša aktivnost'),
                          _MenuCard(items: [
                            _MenuItem(
                              icon: Icons.star_border,
                              label: 'Favoriti',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const FavouriteRestaurantsPage())),
                            ),
                            _PointsMenuItem(),
                            _MenuItem(
                              icon: Icons.rate_review_outlined,
                              label: 'Moje recenzije',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const UserReviewsPage())),
                              showDivider: false,
                            ),
                          ]),

                          const SizedBox(height: 20),

                          _SectionLabel(label: 'O Vama'),
                          _MenuCard(items: [
                            _MenuItem(
                              icon: Icons.shield_outlined,
                              label: 'Sigurnost',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SecurityPage())),
                            ),
                            _MenuItem(
                              icon: Icons.person_outline,
                              label: 'Lični detalji',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const EditProfilePage())),
                            ),
                            _MenuItem(
                              icon: Icons.settings_outlined,
                              label: 'Podešavanja',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsPage())),
                              showDivider: false,
                            ),
                          ]),

                          const SizedBox(height: 20),

                          _SectionLabel(label: 'Pomoć'),
                          _MenuCard(items: [
                            _MenuItem(
                              icon: Icons.help_outline,
                              label: 'Podrška',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SupportPage())),
                              showDivider: false,
                            ),
                          ]),

                          const SizedBox(height: 12),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _handleSignOut(context),
                              child: const Text('Odjava',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFD94F4F),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _BottomNavBar(
              selectedIndex: _selectedNavIndex,
              onTap: (i) => setState(() => _selectedNavIndex = i),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatefulWidget {
  _ProfileHeader();

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  static const double _coverHeight = 160.0;
  static const double _avatarRadius = 46.0;

  String _name = '';
  String _email = '';
  String _photoUrl = '';
  String _coverUrl = '';
  bool _loading = true;
  bool _uploadingCover = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final d = doc.data() ?? {};
    setState(() {
      _name = d['name'] ?? '';
      _email = d['email'] ?? user.email ?? '';
      _photoUrl = d['photoUrl'] ?? '';
      _coverUrl = d['coverPhotoUrl'] ?? '';
      _loading = false;
    });
  }

  Future<void> _pickAndUpload({required bool isCover}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final bytes = await picked.readAsBytes();
    final field = isCover ? 'coverPhotoUrl' : 'photoUrl';
    final storagePath =
        isCover ? 'users/$uid/cover.jpg' : 'users/$uid/avatar.jpg';

    setState(() {
      if (isCover) _uploadingCover = true;
      else _uploadingAvatar = true;
    });

    try {
      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({field: url});
      setState(() {
        if (isCover) _coverUrl = url;
        else _photoUrl = url;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri uploadu: $e')),
        );
      }
    } finally {
      setState(() {
        if (isCover) _uploadingCover = false;
        else _uploadingAvatar = false;
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: _coverHeight + _avatarRadius + 60,
        child: Center(
            child: CircularProgressIndicator(
                color: Color(0xFF6B7C45), strokeWidth: 2)),
      );
    }

    return Column(
      children: [
        // ── Cover + avatar stack ─────────────────────────────────────
        SizedBox(
          // total height: cover + half of avatar sticking below
          height: _coverHeight + _avatarRadius,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover photo
              Positioned(
                top: 0, left: 0, right: 0,
                height: _coverHeight,
                child: GestureDetector(
                  onTap: () => _pickAndUpload(isCover: true),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover image or placeholder
                      _coverUrl.isNotEmpty
                          ? Image.network(
                              _coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _CoverPlaceholder(),
                            )
                          : _CoverPlaceholder(),

                      // Dark gradient at bottom so avatar stays visible
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        height: 60,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.25),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Camera button overlay (top-right)
                      Positioned(
                        top: 12, right: 12,
                        child: _uploadingCover
                            ? const SizedBox(
                                width: 32, height: 32,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_outlined,
                                    color: Colors.white, size: 18),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Avatar — sits at the bottom of the cover, half sticking out
              Positioned(
                bottom: 0,
                left: 20,
                child: GestureDetector(
                  onTap: () => _pickAndUpload(isCover: false),
                  child: Stack(
                    children: [
                      // White ring border
                      CircleAvatar(
                        radius: _avatarRadius + 3,
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        child: CircleAvatar(
                          radius: _avatarRadius,
                          backgroundColor: const Color(0xFFD8E6C0),
                          backgroundImage: _photoUrl.isNotEmpty
                              ? NetworkImage(_photoUrl)
                              : null,
                          child: _photoUrl.isEmpty
                              ? Text(
                                  _getInitials(_name),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6B7C45)),
                                )
                              : null,
                        ),
                      ),

                      // Small camera badge
                      Positioned(
                        bottom: 2, right: 2,
                        child: _uploadingAvatar
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF6B7C45),
                                    strokeWidth: 2))
                            : Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B7C45),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor,
                                      width: 2),
                                ),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 13),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Name + email below ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name.isNotEmpty ? _name : 'Korisnik',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color),
              ),
              const SizedBox(height: 3),
              Text(
                _email,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall!.color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Cover placeholder ────────────────────────────────────────────────────────

class _CoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF2A3024) : const Color(0xFFD8E6C0),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 32,
              color: isDark
                  ? const Color(0xFF6B7C45)
                  : const Color(0xFF6B7C45).withOpacity(0.6)),
          const SizedBox(height: 6),
          Text('Dodaj naslovnu fotografiju',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF6B7C45)
                      : const Color(0xFF6B7C45).withOpacity(0.7))),
        ]),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyLarge!.color)),
    );
  }
}

// ─── Menu card ────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<Widget> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: items),
    );
  }
}

// ─── Menu item ────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Icon(icon,
                size: 22,
                color: Theme.of(context).textTheme.bodyLarge!.color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFF8A9A7A)),
          ]),
        ),
      ),
      if (showDivider)
        const Divider(
            height: 1, thickness: 1, indent: 52, color: Color(0xFFECF2DF)),
    ]);
  }
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.home_outlined,        activeIcon: Icons.home_rounded,         label: 'Početna'),
    _NavItem(icon: Icons.search_outlined,      activeIcon: Icons.search_rounded,       label: 'Pretraga'),
    _NavItem(icon: Icons.book_online_outlined, activeIcon: Icons.book_online_rounded,  label: 'Rezervacije'),
    _NavItem(icon: Icons.favorite_outline,     activeIcon: Icons.favorite_rounded,     label: 'Favoriti'),
    _NavItem(icon: Icons.person_outline,       activeIcon: Icons.person_rounded,       label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (index) {
            final isSelected = index == selectedIndex;
            final item = _items[index];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  onTap(index);
                  _handleNavigation(context, index);
                },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      key: ValueKey(isSelected),
                      size: 24,
                      color: isSelected
                          ? const Color(0xFF6B7C45)
                          : const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF6B7C45)
                            : const Color(0xFF9E9E9E)),
                    child: Text(item.label),
                  ),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomePage()));
        break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SearchRestaurantsPage()));
        break;
      case 2:
        Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const RestaurantBookingsPage()));
        break;
      case 3:
        Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const FavouriteRestaurantsPage()));
        break;
      case 4:
        break;
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon, required this.activeIcon, required this.label});
}


// ─── Points menu item ─────────────────────────────────────────────────────────

class _PointsMenuItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final points = (snap.data?.data()
            as Map<String, dynamic>?)?['bookitPoints'] as int? ?? 0;
        final tier = tierFromPoints(points);
        final tColor = tierColor(tier);

        return Column(children: [
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookItPointsPage()),
            ),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(children: [
                Icon(tierIcon(tier), size: 22, color: tColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('BookIt Poeni',
                      style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                          fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$points • ${tierName(tier)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tColor),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Color(0xFF8A9A7A)),
              ]),
            ),
          ),
          const Divider(
              height: 1, thickness: 1, indent: 52, color: Color(0xFFECF2DF)),
        ]);
      },
    );
  }
}