import 'package:bookit/reservations/make_reservations_page.dart';
import 'package:flutter/material.dart';
import 'package:bookit/review/leave_review_page.dart';
import 'package:bookit/restaurants/all_photos_page.dart';
import 'package:bookit/restaurants/menu_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bookit/restaurants/all_reviews_page.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final List<String> cuisines;
  final String description;
  final int reviewCount;
  final double rating;
  final String imageUrl;
  final Map<String, dynamic> workingHours;
  final int tableCount;
  final String phone;
  final String email;
  final double? lat;
  final double? lng;
  final List<String> menuCategories;
  final String coverUrl;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.cuisines,
    required this.description,
    required this.reviewCount,
    required this.rating,
    required this.imageUrl,
    required this.coverUrl,
    required this.workingHours,
    required this.tableCount,
    required this.phone,
    required this.email,
    this.lat,
    this.lng,
    required this.menuCategories,
  });

  String get cuisineLabel => cuisines.join(', ');

  bool get isOpenNow {
    const days = [
      'Ponedjeljak','Utorak','Srijeda','Četvrtak',
      'Petak','Subota','Nedjelja',
    ];
    final today = days[DateTime.now().weekday - 1];
    if (workingHours.isEmpty) return false;
    final d = workingHours[today] as Map?;
    if (d == null || d['isOpen'] != true) return false;
    try {
      final o = _t(d['open'] as String);
      final c = _t(d['close'] as String);
      final now = TimeOfDay.now();
      final n = now.hour * 60 + now.minute;
      final om = o.hour * 60 + o.minute;
      final cm = c.hour * 60 + c.minute;
      return cm > om ? n >= om && n < cm : n >= om || n < cm;
    } catch (_) { return false; }
  }

  String get todayHoursLabel {
    const days = [
      'Ponedjeljak','Utorak','Srijeda','Četvrtak',
      'Petak','Subota','Nedjelja',
    ];
    final d = workingHours[days[DateTime.now().weekday - 1]] as Map?;
    if (d == null || d['isOpen'] != true) return '';
    return '${d['open']} – ${d['close']}';
  }

  String get nextOpenDay {
    const days = [
      'Ponedjeljak','Utorak','Srijeda','Četvrtak',
      'Petak','Subota','Nedjelja',
    ];
    final todayIdx = DateTime.now().weekday - 1;
    for (int i = 1; i <= 7; i++) {
      final day = days[(todayIdx + i) % 7];
      final d = workingHours[day] as Map?;
      if (d != null && d['isOpen'] == true) return '$day u ${d['open']}';
    }
    return '';
  }

  static TimeOfDay _t(String s) {
    final p = s.trim().split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1].substring(0,2)));
  }

  factory RestaurantModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    List<String> cuisines;
    final cd = d['cuisines'], c1 = d['cuisine'];
    if (cd is List) cuisines = cd.map((e) => e.toString()).toList();
    else if (c1 != null) cuisines = [c1.toString()];
    else cuisines = [];
    final catData = d['menuCategories'];
    final cats = catData is List ? catData.map((e) => e.toString()).toList() : <String>[];
    return RestaurantModel(
      id: doc.id,
      name: d['name'] ?? '',
      address: d['address'] ?? '',
      city: d['city'] ?? '',
      cuisines: cuisines,
      description: d['description'] ?? '',
      reviewCount: d['reviewCount'] ?? 0,
      rating: (d['rating'] ?? 0.0).toDouble(),
      imageUrl: d['imageUrl'] ?? '',
      coverUrl: d['coverUrl'] ?? '',
      workingHours: Map<String, dynamic>.from(d['workingHours'] ?? {}),
      tableCount: (d['tableCount'] ?? 0) as int,
      phone: d['phone'] ?? '',
      email: d['email'] ?? '',
      lat: d['lat'] != null ? (d['lat'] as num).toDouble() : null,
      lng: d['lng'] != null ? (d['lng'] as num).toDouble() : null,
      menuCategories: cats,
    );
  }
}

class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final double price;
  final bool available;
  final String imageUrl;

  const MenuItemModel({
    required this.id, required this.name, required this.description,
    required this.category, required this.price, required this.available,
    this.imageUrl = '',
  });

  factory MenuItemModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MenuItemModel(
      id: doc.id, name: d['name'] ?? '', description: d['description'] ?? '',
      category: d['category'] ?? '', price: (d['price'] ?? 0.0).toDouble(),
      available: d['available'] ?? true, imageUrl: d['imageUrl'] ?? '',
    );
  }
}

class ReviewModel {
  final String id;
  final String userName;
  final String userAvatarUrl;
  final double rating;
  final String comment;
  final String timeAgo;
  final String? managerReply;

  const ReviewModel({
    required this.id, required this.userName, required this.userAvatarUrl,
    required this.rating, required this.comment, required this.timeAgo,
    this.managerReply,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['createdAt'] as Timestamp?;
    return ReviewModel(
      id: doc.id, userName: d['userName'] ?? 'Korisnik',
      userAvatarUrl: d['userAvatarUrl'] ?? '',
      rating: (d['rating'] ?? 0.0).toDouble(),
      comment: d['comment'] ?? '',
      timeAgo: ts != null ? _ago(ts.toDate()) : '',
      managerReply: d['managerReply'] as String?,
    );
  }

  static String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Prije ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Prije ${diff.inHours} h';
    if (diff.inDays < 30) return 'Prije ${diff.inDays} dana';
    return 'Prije ${(diff.inDays / 30).floor()} mj.';
  }
}

class PhotoModel {
  final String id;
  final String userId;
  final String userName;
  final String imageUrl;
  final String source; // 'restaurant' or 'user'

  const PhotoModel({
    required this.id, required this.userId, required this.userName,
    required this.imageUrl, required this.source,
  });

  factory PhotoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PhotoModel(
      id: doc.id, userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      source: d['source'] ?? 'user',
    );
  }
}

// ─── Restaurant Profile Page ──────────────────────────────────────────────────

class RestaurantProfilePage extends StatefulWidget {
  final String restaurantId;
  const RestaurantProfilePage({super.key, required this.restaurantId});

  @override
  State<RestaurantProfilePage> createState() => _RestaurantProfilePageState();
}

class _RestaurantProfilePageState extends State<RestaurantProfilePage> {
  RestaurantModel? _restaurant;
  bool _loading = true;
  List<MenuItemModel> _menuItems = [];
  List<ReviewModel> _reviews = [];
  List<PhotoModel> _photos = []; // all community photos from subcollection

  bool _isFavourite = false;
  String? _managerRestaurantId;

  final List<String> _tabs = ['Pregled','Jelovnik','Recenzije','Lokacija','Više detalja'];
  int _activeTab = 0;
  final _scroll = ScrollController();
  final List<GlobalKey> _keys = List.generate(5, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll..removeListener(_onScroll)..dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
  try {
    await Future.wait([
      _loadRestaurant(), _loadMenu(), _loadReviews(),
      _loadPhotos(), _checkAuth(),
    ]);
  } catch (e) {
    debugPrint('_loadAll error: $e');
    if (mounted) setState(() => _loading = false);
  }
}

  Future<void> _loadRestaurant() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .get();
    if (!doc.exists) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _restaurant = RestaurantModel.fromFirestore(doc);
        _loading = false;
      });
    }
  } catch (e) {
    debugPrint('Error loading restaurant: $e');
    if (mounted) setState(() => _loading = false);
  }
}

  Future<void> _loadMenu() async {
    final snap = await FirebaseFirestore.instance
        .collection('restaurants').doc(widget.restaurantId)
        .collection('menuItems').where('available', isEqualTo: true).get();
    if (mounted) setState(() => _menuItems = snap.docs.map((d) => MenuItemModel.fromFirestore(d)).toList());
  }

  Future<void> _loadReviews() async {
    final snap = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    if (mounted) setState(() => _reviews = snap.docs.map((d) => ReviewModel.fromFirestore(d)).toList());
  }

  Future<void> _loadPhotos() async {
    // final snap = await FirebaseFirestore.instance
    //     .collection('restaurants').doc(widget.restaurantId)
    //     .collection('photos').orderBy('createdAt', descending: true).get();

    final snap = await FirebaseFirestore.instance 
        .collection('restaurants')
        .doc(widget.restaurantId)
        .collection('photos')
        .get(); 
    if (mounted) setState(() => _photos = snap.docs.map((d) => PhotoModel.fromFirestore(d)).toList());
  }

  Future<void> _checkAuth() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').doc(uid)
          .collection('favourites').doc(widget.restaurantId).get(),
      FirebaseFirestore.instance.collection('users').doc(uid).get(),
    ]);
    if (mounted) {
      setState(() {
      _isFavourite = results[0].exists;
      _managerRestaurantId = (results[1].data() as Map?)?['restaurantId'];
    });
    }
  }

  bool get _isManager => _managerRestaurantId == widget.restaurantId;

  void _onScroll() {
    if (!mounted) return;
    final mid = MediaQuery.of(context).size.height * 0.4;
    int tab = 0;
    for (int i = _keys.length - 1; i >= 0; i--) {
      final box = _keys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.localToGlobal(Offset.zero).dy <= mid) { tab = i; break; }
    }
    if (tab != _activeTab) setState(() => _activeTab = tab);
  }

  void _scrollTo(int index) {
    final ctx = _keys[index].currentContext;
    if (ctx == null) return;
    setState(() => _activeTab = index);
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  Future<void> _toggleFavourite() async {
    final r = _restaurant; if (r == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid; if (uid == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid)
        .collection('favourites').doc(widget.restaurantId);
    setState(() => _isFavourite = !_isFavourite);
    if (_isFavourite) {
      await ref.set({
        'name': r.name,
        'cuisine': r.cuisineLabel,
        'address': r.address,
        'rating': r.rating,
        'imageUrl': r.imageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  // ── Add community photo ────────────────────────────────────────────
  Future<void> _addPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid; if (uid == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userName = userDoc.data()?['name'] ?? 'Korisnik';
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance.ref().child(
          'restaurant_photos/${widget.restaurantId}/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('restaurants')
          .doc(widget.restaurantId).collection('photos').add({
        'userId': uid, 'userName': userName, 'imageUrl': url,
        'source': 'user', // ← tag as user photo
        // 'createdAt': FieldValue.serverTimestamp(),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      _loadPhotos();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Greška pri dodavanju slike.'),
        backgroundColor: Color(0xFFD94F4F),
      ));
      }
    }
  }

  Future<void> _deletePhoto(PhotoModel photo) async {
    try { await FirebaseStorage.instance.refFromURL(photo.imageUrl).delete(); } catch (_) {}
    await FirebaseFirestore.instance.collection('restaurants')
        .doc(widget.restaurantId).collection('photos').doc(photo.id).delete();
    _loadPhotos();
  }

  void _showDeleteSheet(PhotoModel photo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Slika od ${photo.userName}',
              style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall!.color)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Color(0xFFD94F4F)),
            title: const Text('Obriši sliku', style: TextStyle(color: Color(0xFFD94F4F))),
            onTap: () { Navigator.pop(context); _deletePhoto(photo); },
          ),
        ]),
      ),
    );
  }

  // All photo URLs: restaurant main image first (tagged 'restaurant'), then community
  List<String> get _allPhotoUrls {
    final urls = <String>[];
    if (_restaurant?.imageUrl.isNotEmpty == true) urls.add(_restaurant!.imageUrl);
    urls.addAll(_photos.map((p) => p.imageUrl));
    return urls;
  }

  List<String> _inferCategories() {
    final seen = <String>{};
    return _menuItems.map((i) => i.category).where((c) => c.isNotEmpty && seen.add(c)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(
        child: CircularProgressIndicator(color: const Color(0xFF6B7C45)),
      ));
    }
    if (_restaurant == null) {
      return Scaffold(body: Center(
        child: Text('Restoran nije pronađen.',
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall!.color)),
      ));
    }
    final r = _restaurant!;
    final photos = _allPhotoUrls;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cats = r.menuCategories.isNotEmpty ? r.menuCategories : _inferCategories();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: _BottomBar(restaurant: r),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            // ── Header as plain SliverToBoxAdapter (reactive to setState) ──
            // ── Header as plain SliverToBoxAdapter (reactive to setState) ──
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cover + avatar + action buttons ──────────────────
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover photo
                      Container(
                        width: double.infinity,
                        height: 200,
                        color: const Color(0xFFD8E6C0),
                        child: r.coverUrl.isNotEmpty
                            ? Image.network(r.coverUrl, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.restaurant,
                                        size: 56, color: Color(0xFF6B7C45))))
                            : const Center(child: Icon(Icons.restaurant,
                                size: 56, color: Color(0xFF6B7C45))),
                      ),
                      // Action buttons overlaid on cover
                      Positioned(
                        top: 12, left: 16, right: 16,
                        child: Row(children: [
                          _CircleBtn(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          if (uid != null)
                            GestureDetector(
                              onTap: _addPhoto,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                                ),
                                child: const Row(children: [
                                  Icon(Icons.add_a_photo_outlined, size: 14, color: Color(0xFF6B7C45)),
                                  SizedBox(width: 6),
                                  Text('Dodaj sliku', style: TextStyle(fontSize: 12, color: Color(0xFF6B7C45), fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          const SizedBox(width: 8),
                          _CircleBtn(
                            icon: _isFavourite ? Icons.favorite : Icons.favorite_border,
                            onTap: _toggleFavourite,
                            iconColor: _isFavourite ? const Color(0xFFD94F4F) : null,
                          ),
                        ]),
                      ),
                      // Avatar overlapping cover bottom
                      Positioned(
                        bottom: -44, left: 20,
                        child: Container(
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
                                        Icons.restaurant, size: 36, color: Color(0xFF6B7C45)))
                                : const Icon(Icons.restaurant,
                                    size: 36, color: Color(0xFF6B7C45)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Space for overlapping avatar
                  const SizedBox(height: 58),

                  // Restaurant info
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _OpenBadge(restaurant: r),
                      const SizedBox(height: 8),
                      Text(r.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color)),
                      const SizedBox(height: 6),
                      _InfoRow(Icons.location_on_outlined, r.address),
                      const SizedBox(height: 3),
                      _InfoRow(Icons.wine_bar_outlined, r.cuisineLabel),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.star, size: 15, color: Color(0xFFE8B84B)),
                        const SizedBox(width: 4),
                        Text(
                          r.rating > 0 ? r.rating.toStringAsFixed(1) : 'Bez ocjene',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyLarge!.color),
                        ),
                        if (r.reviewCount > 0) ...[
                          const SizedBox(width: 4),
                          Text('(${r.reviewCount} recenzija)',
                              style: TextStyle(fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall!.color)),
                        ],
                      ]),
                    ]),
                  ),

                  // Photo grid
                  if (photos.isNotEmpty)
                    _PhotoGrid(
                      photos: photos,
                      photos_models: _photos,
                      isManager: _isManager,
                      restaurantImageUrl: r.imageUrl,
                      onTap: (i) => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AllPhotosPage(
                            restaurantId: widget.restaurantId,
                            restaurantName: r.name,
                            restaurantImageUrl: r.imageUrl,
                            communityPhotos: _photos,
                          ))),
                      onDelete: _showDeleteSheet,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8E6C0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Icon(Icons.restaurant, size: 56, color: Color(0xFF6B7C45))),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Sticky tab bar ─────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabDelegate(
                tabs: _tabs, activeIndex: _activeTab, onTap: _scrollTo,
                surface: Theme.of(context).colorScheme.surface,
              ),
            ),

            // ── SECTION 0 — Pregled ────────────────────────────────
            SliverToBoxAdapter(child: Padding(
              key: _keys[0],
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: _SectionTitle('Pregled'),
            )),
            if (r.description.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Text(r.description, style: TextStyle(
                    fontSize: 14, color: Theme.of(context).textTheme.bodySmall!.color, height: 1.6)),
              )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _InfoCard(tiles: [
                _Tile(Icons.location_on_outlined, 'Adresa', r.address),
                if (r.city.isNotEmpty) _Tile(Icons.location_city_outlined, 'Grad', '${r.city}, BiH'),
                if (r.phone.isNotEmpty) _Tile(Icons.phone_outlined, 'Telefon', r.phone),
                if (r.email.isNotEmpty) _Tile(Icons.email_outlined, 'Email', r.email),
                _Tile(Icons.table_restaurant_outlined, 'Stolovi', '${r.tableCount}'),
              ]),
            )),

            // ── SECTION 1 — Jelovnik ───────────────────────────────
            SliverToBoxAdapter(child: Padding(
              key: _keys[1],
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: _SectionTitle('Jelovnik'),
            )),
            if (_menuItems.isEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text('Jelovnik nije dostupan.',
                    style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall!.color)),
              ))
            else ...[
              // Menu preview — first 3 items
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _buildMenuPreview(cats),
              )),
              // "Istraži jelovnik" button
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MenuPage(
                        restaurantId: widget.restaurantId,
                        restaurantName: r.name,
                        menuItems: _menuItems,
                        categories: cats,
                      ))),
                  icon: const Icon(Icons.restaurant_menu_outlined, size: 18, color: Color(0xFF6B7C45)),
                  label: const Text('Istraži jelovnik', style: TextStyle(
                      color: Color(0xFF6B7C45), fontWeight: FontWeight.w600, fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6B7C45), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              )),
            ],

            // ── SECTION 2 — Recenzije ──────────────────────────────
            SliverToBoxAdapter(child: Padding(
              key: _keys[2],
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionTitle('Recenzije'),
                  if (r.reviewCount > 0)
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllReviewsPage(restaurantId: widget.restaurantId, restaurantName: r.name),
                        ),
                      ),
                      child: const Text('Prikaži sve', style: TextStyle(color: Color(0xFF6B7C45), fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_reviews.isNotEmpty) ...[
                  _RatingSummary(reviews: _reviews, rating: r.rating, totalReviews: r.reviewCount),
                  const SizedBox(height: 14),
                ],
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LeaveReviewPage(
                        restaurantId: r.id, restaurantName: r.name,
                        restaurantAddress: r.address, restaurantCuisine: r.cuisineLabel,
                      ))),
                  icon: const Icon(Icons.rate_review_outlined, size: 18, color: Color(0xFF6B7C45)),
                  label: const Text('Ostavite recenziju', style: TextStyle(
                      color: Color(0xFF6B7C45), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6B7C45), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ]),
            )),
            if (_reviews.isEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text('Još nema recenzija.', style: TextStyle(
                    fontSize: 14, color: Theme.of(context).textTheme.bodySmall!.color)),
              ))
            else
              SliverList(delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: ReviewCard(review: _reviews[i]),
                ),
                childCount: _reviews.length,
              )),
            // ── SECTION 3 — Lokacija ───────────────────────────────
            SliverToBoxAdapter(child: Padding(
              key: _keys[3],
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: _SectionTitle('Lokacija'),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(children: [
                _InfoCard(tiles: [
                  _Tile(Icons.location_on_outlined, 'Adresa', r.address),
                  if (r.city.isNotEmpty) _Tile(Icons.location_city_outlined, 'Grad', '${r.city}, BiH'),
                ]),
                const SizedBox(height: 14),
                if (r.lat != null && r.lng != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 260,
                      child: FlutterMap(
                        options: MapOptions(initialCenter: LatLng(r.lat!, r.lng!), initialZoom: 15),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.bookit.app',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(r.lat!, r.lng!),
                              width: 44, height: 44,
                              child: Container(
                                decoration: const BoxDecoration(color: Color(0xFF6B7C45), shape: BoxShape.circle),
                                child: const Icon(Icons.restaurant, size: 22, color: Colors.white),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCCD9B0)),
                    ),
                    child: Center(child: Text('Karta nije dostupna.',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall!.color))),
                  ),
              ]),
            )),

            // ── SECTION 4 — Više detalja ───────────────────────────
            SliverToBoxAdapter(child: Padding(
              key: _keys[4],
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: _SectionTitle('Više detalja'),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _InfoCard(tiles: [
                if (r.phone.isNotEmpty) _Tile(Icons.phone_outlined, 'Telefon', r.phone),
                if (r.email.isNotEmpty) _Tile(Icons.email_outlined, 'Email', r.email),
                _Tile(Icons.wine_bar_outlined, 'Tip kuhinje', r.cuisineLabel),
                _Tile(Icons.table_restaurant_outlined, 'Broj stolova', '${r.tableCount}'),
              ]),
            )),
            if (r.workingHours.isNotEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: _WorkingHoursCard(workingHours: r.workingHours),
              ))
            else
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // Preview of menu: first category with up to 3 items
  Widget _buildMenuPreview(List<String> cats) {
    final previewItems = cats.isEmpty
        ? _menuItems.take(3).toList()
        : _menuItems.where((i) => i.category == cats.first).take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCD9B0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (cats.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(cats.first, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge!.color)),
          ),
          const Divider(height: 1, color: Color(0xFFCCD9B0)),
        ],
        ...previewItems.asMap().entries.map((e) {
          final isLast = e.key == previewItems.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MenuItemTile(item: e.value),
            ),
            if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFECF2DF)),
          ]);
        }),
      ]),
    );
  }
}

// ─── Photo grid ───────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<String> photos;
  final List<PhotoModel> photos_models;
  final bool isManager;
  final String restaurantImageUrl;
  final ValueChanged<int> onTap;
  final void Function(PhotoModel) onDelete;

  const _PhotoGrid({
    required this.photos, required this.photos_models, required this.isManager,
    required this.restaurantImageUrl, required this.onTap, required this.onDelete,
  });

  PhotoModel? _modelAt(int index) {
    final offset = restaurantImageUrl.isNotEmpty ? 1 : 0;
    final i = index - offset;
    return (i >= 0 && i < photos_models.length) ? photos_models[i] : null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SizedBox(
        height: 190,
        child: Row(children: [
          // Large left
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: () => onTap(0),
              onLongPress: isManager && _modelAt(0) != null ? () => onDelete(_modelAt(0)!) : null,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                child: _Thumb(url: photos[0]),
              ),
            ),
          ),
          if (photos.length > 1) ...[
            const SizedBox(width: 3),
            // Center
            Expanded(
              flex: 4,
              child: GestureDetector(
                onTap: () => onTap(1),
                onLongPress: isManager && _modelAt(1) != null ? () => onDelete(_modelAt(1)!) : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topRight: photos.length <= 2 ? const Radius.circular(12) : Radius.zero,
                    bottomRight: photos.length <= 2 ? const Radius.circular(12) : Radius.zero,
                  ),
                  child: _Thumb(url: photos[1]),
                ),
              ),
            ),
          ],
          if (photos.length > 2) ...[
            const SizedBox(width: 3),
            // Right column
            Expanded(
              flex: 3,
              child: Column(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(2),
                    onLongPress: isManager && _modelAt(2) != null ? () => onDelete(_modelAt(2)!) : null,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
                      child: _Thumb(url: photos[2]),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // Bottom right — see all overlay
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(0), // tapping "+N" opens AllPhotosPage via parent
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
                      child: Stack(fit: StackFit.expand, children: [
                        _Thumb(url: photos.length > 3 ? photos[3] : photos[2]),
                        if (photos.length > 3)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.photo_library, color: Colors.white, size: 18),
                                const SizedBox(height: 3),
                                Text('+${photos.length - 3}',
                                    style: const TextStyle(color: Colors.white,
                                        fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            )),
                          ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Tab delegate ─────────────────────────────────────────────────────────────

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final Color surface;

  const _TabDelegate({required this.tabs, required this.activeIndex,
      required this.onTap, required this.surface});

  @override double get minExtent => 48;
  @override double get maxExtent => 48;
  @override bool shouldRebuild(_TabDelegate o) => o.activeIndex != activeIndex;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      height: 48, color: surface,
      child: Column(children: [
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: tabs.length,
            itemBuilder: (context, i) {
              final active = i == activeIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(
                      color: active ? const Color(0xFF6B7C45) : Colors.transparent, width: 2.5))),
                  child: Center(child: Text(tabs[i], style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                    color: active ? const Color(0xFF6B7C45)
                        : Theme.of(context).textTheme.bodySmall!.color,
                  ))),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: Color(0xFFCCD9B0)),
      ]),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final RestaurantModel restaurant;
  const _BottomBar({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MakeReservationPage(
                restaurantId: restaurant.id, restaurantName: restaurant.name,
                restaurantAddress: restaurant.address, restaurantImageUrl: restaurant.imageUrl,
              ))),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B7C45), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
          ),
          child: const Text('Rezerviši', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ─── Small shared widgets ─────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  const _CircleBtn({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: Icon(icon, size: 18,
            color: iconColor ?? Theme.of(context).textTheme.bodyLarge!.color),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final RestaurantModel restaurant;
  const _OpenBadge({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final open = restaurant.isOpenNow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: open ? const Color(0xFF4CAF50).withOpacity(0.12)
            : const Color(0xFFD94F4F).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        open ? 'Otvoreno · ${restaurant.todayHoursLabel}'
            : restaurant.nextOpenDay.isNotEmpty
                ? 'Zatvoreno · Otvara ${restaurant.nextOpenDay}' : 'Zatvoreno',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: open ? const Color(0xFF4CAF50) : const Color(0xFFD94F4F)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: Theme.of(context).textTheme.bodySmall!.color),
      const SizedBox(width: 4),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13,
          color: Theme.of(context).textTheme.bodySmall!.color))),
    ]);
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);
  @override
  Widget build(BuildContext context) => Text(label, style: TextStyle(
      fontSize: 20, fontWeight: FontWeight.bold,
      color: Theme.of(context).textTheme.bodyLarge!.color));
}

class _Thumb extends StatelessWidget {
  final String url;
  const _Thumb({required this.url});
  @override
  Widget build(BuildContext context) => Image.network(url,
      fit: BoxFit.cover, width: double.infinity, height: double.infinity,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFFD8E6C0),
          child: const Icon(Icons.restaurant, size: 28, color: Color(0xFF6B7C45))));
}

class _Tile {
  final IconData icon;
  final String label;
  final String value;
  const _Tile(this.icon, this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final List<_Tile> tiles;
  const _InfoCard({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: tiles.asMap().entries.map((e) {
        final isLast = e.key == tiles.length - 1;
        final t = e.value;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(t.icon, size: 18, color: const Color(0xFF6B7C45)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.label, style: TextStyle(fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall!.color)),
                const SizedBox(height: 2),
                Text(t.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge!.color)),
              ])),
            ]),
          ),
          if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFECF2DF)),
        ]);
      }).toList()),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  final MenuItemModel item;
  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge!.color)),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.description, style: TextStyle(fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall!.color, height: 1.4)),
          ],
          const SizedBox(height: 6),
          Text('${item.price.toStringAsFixed(2)} KM',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7C45))),
        ])),
        if (item.imageUrl.isNotEmpty) ...[
          const SizedBox(width: 14),
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image.network(item.imageUrl, width: 64, height: 64, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 64, height: 64,
                    color: const Color(0xFFD8E6C0),
                    child: const Icon(Icons.restaurant, size: 24, color: Color(0xFF6B7C45)))),
          ),
        ],
      ]),
    );
  }
}

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

class _RatingSummary extends StatelessWidget {
  final List<ReviewModel> reviews;
  final double rating;
  final int? totalReviews;
  const _RatingSummary({required this.reviews, required this.rating, this.totalReviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 36,
              fontWeight: FontWeight.bold, color: Color(0xFF6B7C45))),
          Row(children: List.generate(5, (i) => Icon(
              i < rating.round() ? Icons.star : Icons.star_border,
              size: 14, color: const Color(0xFFE8B84B)))),
          const SizedBox(height: 4),
          Text('${totalReviews ?? reviews.length} recenzija',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall!.color)),
        ]),
        const SizedBox(width: 20),
        Expanded(child: Column(children: List.generate(5, (i) {
          final star = 5 - i;
          final count = reviews.where((r) => r.rating == star).length;
          final frac = reviews.isEmpty ? 0.0 : count / reviews.length;
          return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Text('$star', style: TextStyle(fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall!.color)),
              const SizedBox(width: 4),
              const Icon(Icons.star, size: 11, color: Color(0xFFE8B84B)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: frac, minHeight: 6,
                      backgroundColor: const Color(0xFFECF2DF),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFE8B84B))))),
              const SizedBox(width: 6),
              Text('$count', style: TextStyle(fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall!.color)),
            ]),
          );
        }))),
      ]),
    );
  }
}

class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const ReviewCard({super.key, required this.review});

  String get _initials {
    final p = review.userName.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return review.userName.isNotEmpty ? review.userName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18, backgroundColor: const Color(0xFFD8E6C0),
            backgroundImage: review.userAvatarUrl.isNotEmpty ? NetworkImage(review.userAvatarUrl) : null,
            child: review.userAvatarUrl.isEmpty ? Text(_initials,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7C45))) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(review.userName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge!.color)),
            Text(review.timeAgo, style: TextStyle(fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall!.color)),
          ])),
          Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star : Icons.star_border,
              size: 13, color: const Color(0xFFE8B84B)))),
        ]),
        const SizedBox(height: 10),
        Text(review.comment, style: TextStyle(fontSize: 13,
            color: Theme.of(context).textTheme.bodySmall!.color, height: 1.5)),
        if (review.managerReply != null && review.managerReply!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6B7C45).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF6B7C45).withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.storefront_outlined, size: 12, color: Color(0xFF6B7C45)),
                SizedBox(width: 4),
                Text('Odgovor restorana', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: Color(0xFF6B7C45))),
              ]),
              const SizedBox(height: 4),
              Text(review.managerReply!, style: TextStyle(fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall!.color, height: 1.4)),
            ]),
          ),
        ],
      ]),
    );
  }
}