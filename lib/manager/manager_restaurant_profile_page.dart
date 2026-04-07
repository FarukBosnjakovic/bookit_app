import 'dart:io';
import 'package:bookit/manager/manager_analytics_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookit/manager/manager_table_overview_page.dart';
import 'package:bookit/manager/manager_menu_page.dart';
import 'package:bookit/manager/manager_reviews_page.dart';
import 'package:bookit/manager/manager_edit_restaurant_page.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class ManagerRestaurantModel {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String cuisine;
  final String description;
  final int tableCount;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final String coverUrl;
  final bool isOpen;
  final Map<String, dynamic> workingHours;

  const ManagerRestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.cuisine,
    required this.description,
    required this.tableCount,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
    required this.coverUrl,
    required this.isOpen,
    required this.workingHours,
  });

  factory ManagerRestaurantModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ManagerRestaurantModel(
      id: doc.id,
      name: d['name'] ?? '',
      address: d['address'] ?? '',
      phone: d['phone'] ?? '',
      email: d['email'] ?? '',
      cuisine: d['cuisine'] ?? '',
      description: d['description'] ?? '',
      tableCount: d['tableCount'] ?? 0,
      rating: (d['rating'] ?? 0.0).toDouble(),
      reviewCount: d['reviewCount'] ?? 0,
      imageUrl: d['imageUrl'] ?? '',
      coverUrl: d['coverUrl'] ?? '',
      isOpen: d['isOpen'] ?? false,
      workingHours: Map<String, dynamic>.from(d['workingHours'] ?? {}),
    );
  }
}

// ─── Manager Restaurant Profile Page ─────────────────────────────────────────

class ManagerRestaurantProfilePage extends StatefulWidget {
  const ManagerRestaurantProfilePage({super.key});

  @override
  State<ManagerRestaurantProfilePage> createState() =>
      _ManagerRestaurantProfilePageState();
}

class _ManagerRestaurantProfilePageState
    extends State<ManagerRestaurantProfilePage> {
  String? _restaurantId;
  bool _loadingId = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurantId();
  }

  // ── Get restaurantId from the logged-in manager's user doc ───────────
  Future<void> _loadRestaurantId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingId = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() {
      _restaurantId = doc.data()?['restaurantId'];
      _loadingId = false;
    });
  }

  // ── Toggle isOpen in Firestore ───────────────────────────────────────
  Future<void> _toggleIsOpen(bool value) async {
    if (_restaurantId == null) return;
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(_restaurantId)
        .update({'isOpen': value});
  }

  // ── Pick and upload image to Firebase Storage ────────────────────────
  Future<void> _pickAndUploadCover() async {
    if (_restaurantId == null) return;
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 80, maxWidth: 1400,
    );
    if (image == null) return;
    try {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance
          .ref().child('restaurants/$_restaurantId/cover.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('restaurants').doc(_restaurantId)
          .update({'coverUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naslovna fotografija ažurirana.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')));
      }
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    if (_restaurantId == null) return;
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 85, maxWidth: 600,
    );
    if (image == null) return;
    try {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance
          .ref().child('restaurants/$_restaurantId/profile.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('restaurants').doc(_restaurantId)
          .update({'imageUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilna slika ažurirana.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading restaurantId ───────────────────────────────────────────
    if (_loadingId) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6B7C45),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // ── No restaurant linked to this manager ───────────────────────────
    if (_restaurantId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Nije pronađen restoran za vaš račun.',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall!.color),
          ),
        ),
      );
    }

    // ── Stream restaurant document for live updates ────────────────────
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(_restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6B7C45),
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Text(
                'Restoran nije pronađen.',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall!.color),
              ),
            ),
          );
        }

        final r = ManagerRestaurantModel.fromFirestore(snapshot.data!);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // ── Top bar ──────────────────────────────────────────
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profil restorana',
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
                        // ── Edit button ────────────────────────────────
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                     const ManagerEditRestaurantPage(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B7C45)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF6B7C45)
                                    .withOpacity(0.4),
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 14, color: Color(0xFF6B7C45)),
                                SizedBox(width: 5),
                                Text(
                                  'Uredi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7C45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Restaurant image ─────────────────────────────────
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover photo
                      GestureDetector(
                        onTap: _pickAndUploadCover,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          color: const Color(0xFFD8E6C0),
                          child: r.coverUrl.isNotEmpty
                            ? Image.network(r.coverUrl, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 56,
                                    color: Color(0xFF6B7C45)
                                  )
                                ))
                            : const Center(
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 48,
                                  color: Color(0xFF6B7C45)
                                )
                            ),
                        ),
                      ),
                      
                      // Cover Camera Badge
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _pickAndUploadCover,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 13,
                                  color: Colors.white
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Naslovna',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500
                                  )
                                ),
                              ]
                            ),
                          ),
                        ),
                      ),

                      // Avatar Overlapping the cover bottom
                      Positioned(
                        bottom: -44,
                        left: 20,
                        child: Stack(
                          children: [
                            Container(
                              width: 88, height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    width: 3),
                                color: const Color(0xFFD8E6C0),
                              ),
                              child: ClipOval(
                                child: r.imageUrl.isNotEmpty 
                                  ? Image.network(r.imageUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.restaurant,
                                        size: 36,
                                        color: Color(0xFF6B7C45)
                                      ))
                                  : const Icon(
                                      Icons.restaurant,
                                      size: 36,
                                      color: Color(0xFF6B7C45),
                                  ),
                              ),
                            ),

                            // -- Avatar Camera Badge
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAndUploadProfileImage,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6B7C45),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                      width: 2
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Name + open/closed toggle ──────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r.cuisine,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Switch(
                                  value: r.isOpen,
                                  onChanged: (value) =>
                                      _toggleIsOpen(value),
                                  activeThumbColor: Colors.white,
                                  activeTrackColor:
                                      const Color(0xFF4CAF50),
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor:
                                      const Color(0xFFCCD9B0),
                                ),
                                Text(
                                  r.isOpen ? 'Otvoreno' : 'Zatvoreno',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: r.isOpen
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFD94F4F),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Quick stats ────────────────────────────────
                        Row(
                          children: [
                            _QuickStat(
                              icon: Icons.star,
                              value: r.rating.toStringAsFixed(1),
                              label: 'Ocjena',
                              color: const Color(0xFFE8B84B),
                            ),
                            const SizedBox(width: 12),
                            _QuickStat(
                              icon: Icons.rate_review_outlined,
                              value: '${r.reviewCount}',
                              label: 'Recenzija',
                              color: const Color(0xFF6B7C45),
                            ),
                            const SizedBox(width: 12),
                            _QuickStat(
                              icon: Icons.table_restaurant_outlined,
                              value: '${r.tableCount}',
                              label: 'Stolova',
                              color: const Color(0xFF6B7C45),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Info card ──────────────────────────────────
                        _SectionCard(
                          title: 'Informacije',
                          children: [
                            _InfoRow(
                              icon: Icons.location_on_outlined,
                              label: 'Adresa',
                              value: r.address,
                            ),
                            const _RowDivider(),
                            _InfoRow(
                              icon: Icons.phone_outlined,
                              label: 'Telefon',
                              value: r.phone,
                            ),
                            const _RowDivider(),
                            _InfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: r.email,
                            ),
                            const _RowDivider(),
                            _ActionRow(
                              icon: Icons.bar_chart_outlined,
                              label: 'Analitika',
                              subtitle: 'Pregled rezervacija, termina i ocjena',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ManagerAnalyticsPage()
                                )
                              ),
                            ),

                            const SizedBox(height: 16),

                            // -- Working Hours Card
                            if (r.workingHours.isNotEmpty)
                              _WorkingHoursCard(workingHours: r.workingHours)
                            else 
                              _SectionCard(
                                title: 'Radno vrijeme',
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Radno vrijeme nije postavljeno.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).textTheme.bodySmall!.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Description card ───────────────────────────
                        _SectionCard(
                          title: 'Opis restorana',
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                r.description.isNotEmpty
                                    ? r.description
                                    : 'Opis još nije dodan.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .color,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Management actions ─────────────────────────
                        _SectionCard(
                          title: 'Upravljanje',
                          children: [
                            _ActionRow(
                              icon: Icons.restaurant_menu_outlined,
                              label: 'Jelovnik',
                              subtitle: 'Dodaj ili uredi stavke jelovnika',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ManagerMenuPage(),
                                  ),
                                );
                              },
                            ),
                            const _RowDivider(),
                            _ActionRow(
                              icon: Icons.table_restaurant_outlined,
                              label: 'Pregled stolova',
                              subtitle:
                                  'Vidi zauzetost stolova po terminu',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TableOverviewPage(),
                                  ),
                                );
                              },
                            ),
                            const _RowDivider(),
                            _ActionRow(
                              icon: Icons.rate_review_outlined,
                              label: 'Recenzije',
                              subtitle:
                                  'Pregledaj i odgovori na recenzije',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ManagerReviewsPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Quick stat ───────────────────────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  color:
                      Theme.of(context).textTheme.bodySmall!.color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        const SizedBox(height: 10),
        Container(
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
          child: Column(children: children),
        ),
      ],
    );
  }
}

// -- Working Hours Card

class _WorkingHoursCard extends StatelessWidget {
  final Map<String, dynamic> workingHours;
  const _WorkingHoursCard({required this.workingHours});

  @override
  Widget build(BuildContext context) {
    const days = ['Ponedjeljak','Utorak','Srijeda','Četvrtak','Petak','Subota','Nedjelja'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Radno vrijeme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge!.color)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(children: days.asMap().entries.map((e) {
          final i = e.key; final day = e.value;
          final d = workingHours[day] as Map?;
          final open = d != null && d['isOpen'] == true;
          final isToday = DateTime.now().weekday - 1 == i;
          final isLast = i == days.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                SizedBox(width: 110, child: Text(day, style: TextStyle(fontSize: 14,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                    color: isToday ? const Color(0xFF6B7C45)
                        : Theme.of(context).textTheme.bodyLarge!.color))),
                Expanded(child: Text(
                  open ? '${d['open']} – ${d['close']}' : 'Zatvoreno',
                  style: TextStyle(fontSize: 14,
                      color: open ? Theme.of(context).textTheme.bodyLarge!.color
                          : const Color(0xFFD94F4F)),
                  textAlign: TextAlign.right,
                )),
              ]),
            ),
            if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFECF2DF)),
          ]);
        }).toList()),
      ),
    ]);
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(
      {required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7C45)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall!.color,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                // color: Theme.of(context).textTheme.bodyLarge!.color,
                color: valueColor ?? Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7C45).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF6B7C45)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFF8A9A7A)),
          ],
        ),
      ),
    );
  }
}

// ─── Row divider ──────────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, indent: 46, color: Color(0xFFECF2DF));
  }
}