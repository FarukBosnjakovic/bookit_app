import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bookit/restaurants/restaurants_profile_page.dart';

// ─── Category enum ────────────────────────────────────────────────────────────

enum RestaurantCategory { bestRated, mostBooked, onTheRise }

extension RestaurantCategoryX on RestaurantCategory {
  String get title {
    switch (this) {
      case RestaurantCategory.bestRated:  return 'Najbolje ocijenjeni';
      case RestaurantCategory.mostBooked: return 'Najpopularniji';
      case RestaurantCategory.onTheRise:  return 'U usponu';
    }
  }

  String get subtitle {
    switch (this) {
      case RestaurantCategory.bestRated:  return 'Restorani s najboljim ocjenama';
      case RestaurantCategory.mostBooked: return 'Najčešće rezervisani restorani';
      case RestaurantCategory.onTheRise:  return 'Novi i sve popularni restorani';
    }
  }

  IconData get icon {
    switch (this) {
      case RestaurantCategory.bestRated:  return Icons.star_rounded;
      case RestaurantCategory.mostBooked: return Icons.local_fire_department_rounded;
      case RestaurantCategory.onTheRise:  return Icons.trending_up_rounded;
    }
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CategoryRestaurantsPage extends StatefulWidget {
  final RestaurantCategory category;
  final String selectedCity; // pass _selectedCity from HomePage

  const CategoryRestaurantsPage({
    super.key,
    required this.category,
    required this.selectedCity,
  });

  @override
  State<CategoryRestaurantsPage> createState() =>
      _CategoryRestaurantsPageState();
}

class _CategoryRestaurantsPageState
    extends State<CategoryRestaurantsPage> {
  // ── State ──────────────────────────────────────────────────────────
  List<RestaurantModel> _restaurants = [];
  bool _loading = true;
  String? _error;

  /// When true → map fills the screen, carousel shown at bottom.
  /// When false → map is background, draggable sheet is shown.
  bool _showFullMap = false;

  int _selectedCarouselIndex = 0;

  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final MapController _mapController = MapController();

  // ── Lifecycle ──────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  // ── Data fetching ──────────────────────────────────────────────────

  Future<void> _fetchRestaurants() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<RestaurantModel> result;
      switch (widget.category) {
        case RestaurantCategory.bestRated:
          result = await _fetchBestRated();
          break;
        case RestaurantCategory.mostBooked:
          result = await _fetchMostBooked();
          break;
        case RestaurantCategory.onTheRise:
          result = await _fetchOnTheRise();
          break;
      }

      // City filter
      const allCities = 'Sve lokacije';
      if (widget.selectedCity != allCities) {
        result = result
            .where((r) =>
                r.city.toLowerCase() ==
                widget.selectedCity.toLowerCase())
            .toList();
      }

      setState(() {
        _restaurants = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<RestaurantModel>> _fetchBestRated() async {
    final snap = await FirebaseFirestore.instance
        .collection('restaurants')
        .orderBy('rating', descending: true)
        .get();
    return snap.docs
        .map((d) => RestaurantModel.fromFirestore(d))
        .toList();
  }

  Future<List<RestaurantModel>> _fetchMostBooked() async {
    // Aggregate confirmed/completed bookings per restaurant.
    // NOTE: once you add a `bookingCount` field (via Cloud Functions),
    // replace this with a simple orderBy('bookingCount') query.
    final bookingsSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('status', whereIn: ['confirmed', 'completed'])
        .get();

    final counts = <String, int>{};
    for (final doc in bookingsSnap.docs) {
      final rid = doc.data()['restaurantId'] as String?;
      if (rid != null) counts[rid] = (counts[rid] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      // Fallback: sort by reviewCount as a proxy
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .orderBy('reviewCount', descending: true)
          .get();
      return snap.docs
          .map((d) => RestaurantModel.fromFirestore(d))
          .toList();
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final restaurants = <RestaurantModel>[];
    for (final entry in sorted.take(50)) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(entry.key)
            .get();
        if (doc.exists) {
          restaurants.add(RestaurantModel.fromFirestore(doc));
        }
      } catch (_) {}
    }
    return restaurants;
  }

  Future<List<RestaurantModel>> _fetchOnTheRise() async {
    // Newest restaurants first. Once you track weekly growth,
    // swap this for a `weeklyBookings` or `trendScore` field.
    final snap = await FirebaseFirestore.instance
        .collection('restaurants')
        .orderBy('createdAt', descending: true)
        .limit(60)
        .get();
    return snap.docs
        .map((d) => RestaurantModel.fromFirestore(d))
        .toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  List<RestaurantModel> get _withCoords =>
      _restaurants
          .where((r) => r.lat != null && r.lng != null)
          .toList();

  LatLng get _mapCenter {
    if (_withCoords.isEmpty) return const LatLng(44.0, 17.5);
    final r = _withCoords[
        _selectedCarouselIndex.clamp(0, _withCoords.length - 1)];
    return LatLng(r.lat!, r.lng!);
  }

  void _openRestaurant(RestaurantModel r) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              RestaurantProfilePage(restaurantId: r.id)),
    );
  }

  void _selectCarouselItem(int index, RestaurantModel r) {
    setState(() => _selectedCarouselIndex = index);
    if (r.lat != null && r.lng != null) {
      _mapController.move(LatLng(r.lat!, r.lng!), 14.5);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildTopBar(),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF6B7C45), strokeWidth: 2.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) return _buildErrorScreen();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Full-screen map ─────────────────────────────────────
          _buildMap(),

          // ── Top bar (always visible) ────────────────────────────
          SafeArea(child: _buildTopBar()),

          // ── List mode: draggable sheet ──────────────────────────
          if (!_showFullMap) _buildDraggableSheet(),

          // ── Map mode: show-list button + carousel ───────────────
          if (_showFullMap) ...[
            _buildShowListButton(),
            _buildCarousel(),
          ],
        ],
      ),
    );
  }

  // ── Map widget ─────────────────────────────────────────────────────

  Widget _buildMap() {
    return SizedBox.expand(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _mapCenter,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.bookit.app',
          ),
          MarkerLayer(
            markers: _withCoords.map((r) {
              final idx = _restaurants.indexOf(r);
              final isSelected =
                  _showFullMap && idx == _selectedCarouselIndex;
              return Marker(
                point: LatLng(r.lat!, r.lng!),
                width: isSelected ? 64 : 52,
                height: isSelected ? 34 : 28,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCarouselIndex = idx;
                      _showFullMap = true;
                    });
                    _mapController.move(
                        LatLng(r.lat!, r.lng!), 14.5);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6B7C45)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      r.rating > 0
                          ? r.rating.toStringAsFixed(1)
                          : '–',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF6B7C45),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8)
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 17, color: Color(0xFF6B7C45)),
            ),
          ),
          const SizedBox(width: 10),
          // Title pill
          Expanded(
            child: Container(
              height: 42,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8)
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.category.icon,
                      size: 18, color: const Color(0xFF6B7C45)),
                  const SizedBox(width: 8),
                  Text(
                    widget.category.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Draggable sheet (list mode) ────────────────────────────────────

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.42,
      minChildSize: 0.14,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.14, 0.42, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCD9B0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_restaurants.length} restorana',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.category.subtitle,
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
                    // "View Map" button
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showFullMap = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined,
                                size: 15, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Pregledaj mapu',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFECF2DF)),
              // Restaurant list
              Expanded(
                child: _restaurants.isEmpty
                    ? const Center(
                        child: Text('Nema dostupnih restorana.'))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 24),
                        itemCount: _restaurants.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _CategoryRestaurantCard(
                          restaurant: _restaurants[index],
                          onTap: () => _openRestaurant(
                              _restaurants[index]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Show-list button (map mode) ────────────────────────────────────

  Widget _buildShowListButton() {
    return Positioned(
      bottom: 172,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _showFullMap = false),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.format_list_bulleted,
                    size: 18, color: Color(0xFF6B7C45)),
                const SizedBox(width: 8),
                Text(
                  'Lista · ${_restaurants.length} restorana',
                  style: const TextStyle(
                    color: Color(0xFF6B7C45),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom carousel (map mode) ─────────────────────────────────────

  Widget _buildCarousel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.fromLTRB(16, 10, 16, 16),
          itemCount: _restaurants.length,
          itemBuilder: (context, index) {
            final r = _restaurants[index];
            final isSelected = index == _selectedCarouselIndex;
            return GestureDetector(
              onTap: () {
                _selectCarouselItem(index, r);
                _openRestaurant(r);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 240,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(
                          color: const Color(0xFF6B7C45),
                          width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(14)),
                      child: r.imageUrl.isNotEmpty
                          ? Image.network(
                              r.imageUrl,
                              width: 80,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _CarouselPlaceholder(),
                            )
                          : _CarouselPlaceholder(),
                    ),
                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              r.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              r.cuisineLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.city,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 13,
                                    color: Color(0xFFE8B84B)),
                                const SizedBox(width: 3),
                                Text(
                                  r.rating > 0
                                      ? r.rating
                                          .toStringAsFixed(1)
                                      : 'Bez ocjene',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE8B84B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Error screen ───────────────────────────────────────────────────

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_outlined,
                        size: 52, color: Color(0xFFCCD9B0)),
                    const SizedBox(height: 14),
                    Text(
                      'Greška pri učitavanju',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _fetchRestaurants,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Pokušaj ponovo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B7C45),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category restaurant card (list view) ─────────────────────────────────────

class _CategoryRestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;

  const _CategoryRestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                  child: r.imageUrl.isNotEmpty
                      ? Image.network(
                          r.imageUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _CardImagePlaceholder(),
                        )
                      : _CardImagePlaceholder(),
                ),
                // Open/closed badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: r.isOpenNow
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFD94F4F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.isOpenNow ? 'Otvoreno' : 'Zatvoreno',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Rating badge
                if (r.rating > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              size: 12,
                              color: Color(0xFFE8B84B)),
                          const SizedBox(width: 3),
                          Text(
                            r.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.cuisineLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                r.city.isNotEmpty
                                    ? r.city
                                    : r.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Color(0xFF8A9A7A)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholders ─────────────────────────────────────────────────────────────

class _CardImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 160,
        width: double.infinity,
        color: const Color(0xFFD8E6C0),
        child: const Center(
          child: Icon(Icons.restaurant,
              size: 40, color: Color(0xFF6B7C45)),
        ),
      );
}

class _CarouselPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 80,
        color: const Color(0xFFD8E6C0),
        child: const Center(
          child: Icon(Icons.restaurant,
              size: 28, color: Color(0xFF6B7C45)),
        ),
      );
}