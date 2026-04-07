import 'package:bookit/personal/profile_settings_page.dart';
import 'package:bookit/restaurants/restaurants_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:bookit/restaurants/favourite_restaurants_page.dart';
import 'package:bookit/search/search_restaurants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookit/restaurants/restaurants_bookings_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bookit/restaurants/restaurants_category_page.dart';

// ─── BiH cities ───────────────────────────────────────────────────────────────

const String _allCities = 'Sve lokacije';

const List<String> _bihCities = [
  _allCities,
  'Tuzla',
  'Sarajevo',
  'Mostar',
  'Banja Luka',
  'Zenica',
  'Bijeljina',
  'Brčko',
  'Travnik',
  'Cazin',
  'Bihać',
  'Živinice',
  'Lukavac',
  'Gradačac',
  'Doboj',
  'Zvornik',
  'Srebrenik',
  'Tešanj',
  'Visoko',
  'Konjic',
];

// ─── Restaurant model ─────────────────────────────────────────────────────────

class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final List<String> cuisines;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final Map<String, dynamic> workingHours;
  final double? lat;
  final double? lng;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.cuisines,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
    required this.workingHours,
    this.lat,
    this.lng,
  });

  bool get isOpenNow {
    const dayNames = [
      'Ponedjeljak', 'Utorak', 'Srijeda', 'Četvrtak',
      'Petak', 'Subota', 'Nedjelja',
    ];
    final today = dayNames[DateTime.now().weekday - 1];
    if (workingHours.isEmpty) return false;
    final dayData = workingHours[today] as Map?;
    if (dayData == null || dayData['isOpen'] != true) return false;
    try {
      final open = _parseTime(dayData['open'] as String);
      final close = _parseTime(dayData['close'] as String);
      final now = TimeOfDay.now();
      final nowMins = now.hour * 60 + now.minute;
      final openMins = open.hour * 60 + open.minute;
      final closeMins = close.hour * 60 + close.minute;
      if (closeMins > openMins) {
        return nowMins >= openMins && nowMins < closeMins;
      } else {
        return nowMins >= openMins || nowMins < closeMins;
      }
    } catch (_) {
      return false;
    }
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.trim().split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1].substring(0, 2)),
    );
  }

  String get cuisineLabel => cuisines.join(', ');

  factory RestaurantModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    List<String> cuisines;
    final cuisinesData = d['cuisines'];
    final cuisineData = d['cuisine'];
    if (cuisinesData != null && cuisinesData is List) {
      cuisines = cuisinesData.map((e) => e.toString()).toList();
    } else if (cuisineData != null) {
      cuisines = [cuisineData.toString()];
    } else {
      cuisines = [];
    }
    return RestaurantModel(
      id: doc.id,
      name: d['name'] ?? '',
      address: d['address'] ?? '',
      city: d['city'] ?? '',
      cuisines: cuisines,
      rating: (d['rating'] ?? 0.0).toDouble(),
      reviewCount: (d['reviewCount'] ?? 0) as int,
      imageUrl: d['imageUrl'] ?? '',
      workingHours:
      Map<String, dynamic>.from(d['workingHours'] ?? {}),
      lat: d['lat'] != null ? (d['lat'] as num).toDouble() : null,
      lng: d['lng'] != null ? (d['lng'] as num).toDouble() : null,
    );
  }
}

// ─── Home Page ────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showMap = false;

  final List<String> _cuisineCategories = [
    'Sve',
    'Evropska',
    'Francuska',
    'Azijska',
    'Italijanska',
    'Tradicionalna',
    'Japanska',
    'Pizzeria',
    'Internacionalna',
    'Mediteranska',
    'Meksička',
  ];

  int _selectedCuisineIndex = 0;

  // ── Location ───────────────────────────────────────────────────────
  String _selectedCity = _allCities;
  bool _locationLoading = true;

  // ── Recently viewed ────────────────────────────────────────────────
  List<RestaurantModel> _recentlyViewed = [];

  @override
  void initState() {
    super.initState();
    _detectLocation();
    _loadRecentlyViewed();
  }

  Future<void> _detectLocation() async {
    try {
      bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationLoading = false);
        return;
      }
      LocationPermission permission =
      await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationLoading = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final detected =
      _detectCityFromCoords(position.latitude, position.longitude);
      setState(() {
        _selectedCity = detected;
        _locationLoading = false;
      });
    } catch (_) {
      setState(() => _locationLoading = false);
    }
  }

  String _detectCityFromCoords(double lat, double lng) {
    const cityCoords = {
      'Tuzla':      [44.5384, 18.6762],
      'Sarajevo':   [43.8476, 18.3564],
      'Mostar':     [43.3438, 17.8078],
      'Banja Luka': [44.7751, 17.1941],
      'Zenica':     [44.2010, 17.9078],
      'Bijeljina':  [44.7558, 19.2147],
      'Brčko':      [44.8683, 18.8102],
      'Travnik':    [44.2265, 17.6617],
      'Bihać':      [44.8175, 15.8703],
      'Doboj':      [44.7311, 18.0867],
    };
    double minDist = double.infinity;
    String closest = _allCities;
    cityCoords.forEach((city, coords) {
      final dist = (coords[0] - lat).abs() + (coords[1] - lng).abs();
      if (dist < minDist) {
        minDist = dist;
        closest = city;
      }
    });
    return minDist < 0.45 ? closest : _allCities;
  }

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 8),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      size: 20, color: Color(0xFFD94F4F)),
                  const SizedBox(width: 8),
                  Text(
                    'Odaberite grad',
                    style: TextStyle(
                      fontSize: 18,
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
            const Divider(height: 1, color: Color(0xFFECF2DF)),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                itemCount: _bihCities.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, color: Color(0xFFECF2DF)),
                itemBuilder: (context, index) {
                  final city = _bihCities[index];
                  final isSelected = city == _selectedCity;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCity = city);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            city == _allCities
                                ? Icons.public_outlined
                                : Icons.location_city_outlined,
                            size: 20,
                            color: isSelected
                                ? const Color(0xFF6B7C45)
                                : Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              city == _allCities
                                  ? city
                                  : '$city, BiH',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF6B7C45)
                                    : Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check,
                                size: 18,
                                color: Color(0xFF6B7C45)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _locationDisplayLabel {
    if (_locationLoading) return '...';
    if (_selectedCity == _allCities) return 'Bosna i Hercegovina';
    return '$_selectedCity, BiH';
  }

  Future<void> _loadRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('recently_viewed') ?? [];
    if (ids.isEmpty) return;
    final restaurants = <RestaurantModel>[];
    for (final id in ids.take(6)) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(id)
            .get();
        if (doc.exists) {
          restaurants.add(RestaurantModel.fromFirestore(doc));
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _recentlyViewed = restaurants);
  }

  Future<void> _addToRecentlyViewed(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('recently_viewed') ?? [];
    ids.remove(restaurantId);
    ids.insert(0, restaurantId);
    await prefs.setStringList(
        'recently_viewed', ids.take(6).toList());
  }

  Future<void> _clearRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recently_viewed');
    setState(() => _recentlyViewed = []);
  }

  void _openRestaurant(BuildContext context, RestaurantModel r) {
    _addToRecentlyViewed(r.id);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              RestaurantProfilePage(restaurantId: r.id)),
    ).then((_) => _loadRecentlyViewed());
  }

  // ── Fetch with error logging ───────────────────────────────────────
  Future<List<RestaurantModel>> _fetchRestaurants() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .orderBy('rating', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => RestaurantModel.fromFirestore(doc))
          .toList();
    } catch (e, stack) {
      debugPrint('FETCH ERROR: $e');
      debugPrint('STACK: $stack');
      rethrow;
    }
  }

  Future<String> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data()?['name'] ?? '';
  }

  List<RestaurantModel> _applyFilters(List<RestaurantModel> all) {
    var result = all;
    if (_selectedCity != _allCities) {
      result = result
          .where((r) =>
      r.city.toLowerCase() ==
          _selectedCity.toLowerCase())
          .toList();
    }
    if (_selectedCuisineIndex != 0) {
      final selected =
      _cuisineCategories[_selectedCuisineIndex];
      result = result
          .where((r) => r.cuisines.contains(selected))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<RestaurantModel>>(
                future: _fetchRestaurants(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(
                        context, snapshot.error.toString());
                  }

                  final restaurants = snapshot.data ?? [];
                  final filtered = _applyFilters(restaurants);
                  final topRated = _selectedCity == _allCities
                      ? restaurants.take(5).toList()
                      : filtered.take(5).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _AppBarRow(fetchName: _fetchUserName),
                        const SizedBox(height: 16),
                        _LocationBar(
                          label: _locationDisplayLabel,
                          loading: _locationLoading,
                          onTap: _openCityPicker,
                        ),
                        const SizedBox(height: 14),
                        _SearchBarWidget(
                          showMap: _showMap,
                          onMapToggle: () => setState(
                                  () => _showMap = !_showMap),
                        ),
                        if (_showMap) ...[
                          const SizedBox(height: 14),
                          _MapSection(
                            restaurants: restaurants,
                            selectedCity: _selectedCity,
                            onTap: (r) =>
                                _openRestaurant(context, r),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _CuisineCategoryList(
                          categories: _cuisineCategories,
                          selectedIndex: _selectedCuisineIndex,
                          onSelect: (i) => setState(
                                  () => _selectedCuisineIndex = i),
                        ),
                        const SizedBox(height: 20),
                        _DiscoverSection(selectedCity: _selectedCity),

                        const SizedBox(height: 24),

                        // ── Best rated ────────────────────────
                        Text(
                          'Najbolje ocijenjeni restorani',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (snapshot.connectionState ==
                            ConnectionState.waiting)
                          const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF6B7C45),
                                  strokeWidth: 2.5),
                            ),
                          )
                        else if (topRated.isEmpty)
                          const _EmptyState(
                              message: 'Nema dostupnih restorana.')
                        else
                          SizedBox(
                            height: 210,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: topRated.length,
                              separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                              itemBuilder: (context, index) =>
                                  _TopRestaurantCard(
                                    restaurant: topRated[index],
                                    onTap: () => _openRestaurant(
                                        context, topRated[index]),
                                  ),
                            ),
                          ),

                        // ── Recently viewed ───────────────────
                        if (_recentlyViewed.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nedavno posjećeni',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color,
                                ),
                              ),
                              GestureDetector(
                                onTap: _clearRecentlyViewed,
                                child: const Text(
                                  'Obriši sve',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFD94F4F),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 210,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _recentlyViewed.length,
                              separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                              itemBuilder: (context, index) =>
                                  _TopRestaurantCard(
                                    restaurant:
                                    _recentlyViewed[index],
                                    onTap: () => _openRestaurant(
                                        context,
                                        _recentlyViewed[index]),
                                  ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // ── All / filtered restaurants ────────
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCuisineIndex == 0
                                  ? (_selectedCity == _allCities
                                  ? 'Svi restorani'
                                  : _selectedCity)
                                  : _cuisineCategories[
                              _selectedCuisineIndex],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color,
                              ),
                            ),
                            Text(
                              '${filtered.length} restorana',
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
                        const SizedBox(height: 14),
                        if (snapshot.connectionState ==
                            ConnectionState.waiting)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                  color: Color(0xFF6B7C45),
                                  strokeWidth: 2.5),
                            ),
                          )
                        else if (filtered.isEmpty)
                          const _EmptyState(
                              message:
                              'Nema restorana u ovoj kategoriji.')
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics:
                            const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _RestaurantCard(
                                  restaurant: filtered[index],
                                  onTap: () => _openRestaurant(
                                      context, filtered[index]),
                                ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
            _BottomNavBar(
              selectedIndex: 0,
              onTap: (i) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _AppBarRow(fetchName: _fetchUserName),
          const SizedBox(height: 16),
          _LocationBar(
            label: _locationDisplayLabel,
            loading: _locationLoading,
            onTap: _openCityPicker,
          ),
          const SizedBox(height: 14),
          _SearchBarWidget(
            showMap: _showMap,
            onMapToggle: () =>
                setState(() => _showMap = !_showMap),
          ),
          const SizedBox(height: 16),
          _CuisineCategoryList(
            categories: _cuisineCategories,
            selectedIndex: _selectedCuisineIndex,
            onSelect: (i) =>
                setState(() => _selectedCuisineIndex = i),
          ),
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                const Icon(Icons.wifi_off_outlined,
                    size: 52, color: Color(0xFFCCD9B0)),
                const SizedBox(height: 14),
                Text(
                  'Greška pri učitavanju restorana.',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color),
                ),
                const SizedBox(height: 8),
                // ── Error detail for debugging ─────────────
                Container(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD94F4F)
                        .withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFD94F4F)
                            .withOpacity(0.3)),
                  ),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFD94F4F)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Pokušaj ponovo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7C45),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Location bar ─────────────────────────────────────────────────────────────

class _LocationBar extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _LocationBar({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on,
              size: 16, color: Color(0xFFD94F4F)),
          const SizedBox(width: 4),
          loading
              ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                color: Color(0xFF6B7C45), strokeWidth: 2),
          )
              : Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .color,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down,
              size: 16, color: Color(0xFF8A9A7A)),
        ],
      ),
    );
  }
}

// ─── App bar row ──────────────────────────────────────────────────────────────

class _AppBarRow extends StatelessWidget {
  final Future<String> Function() fetchName;
  const _AppBarRow({required this.fetchName});

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: fetchName(),
      builder: (context, snapshot) {
        final name = snapshot.data ?? '';
        return Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFD8E6C0),
              child: Text(
                _getInitials(name),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7C45),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? 'Dobrodošli,' : 'Dobrodošli!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .color,
                  ),
                ),
                if (name.isNotEmpty)
                  Text(
                    name.split(' ').first,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBarWidget extends StatelessWidget {
  final bool showMap;
  final VoidCallback onMapToggle;

  const _SearchBarWidget({
    required this.showMap,
    required this.onMapToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SearchRestaurantsPage()),
            ),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFCCD9B0), width: 1.2),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                      size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pretraži restorane...',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onMapToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: showMap
                  ? const Color(0xFF6B7C45)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: showMap
                      ? const Color(0xFF6B7C45)
                      : const Color(0xFFCCD9B0),
                  width: 1.2),
            ),
            child: Icon(
              Icons.map_outlined,
              size: 22,
              color: showMap
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Cuisine category list ────────────────────────────────────────────────────

class _CuisineCategoryList extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _CuisineCategoryList({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  IconData _iconForCuisine(String cuisine) {
    switch (cuisine) {
      case 'Azijska':         return Icons.rice_bowl_outlined;
      case 'Evropska':        return Icons.local_dining_outlined;
      case 'Tradicionalna':   return Icons.outdoor_grill_outlined;
      case 'Mediteranska':    return Icons.set_meal_outlined;
      case 'Italijanska':     return Icons.local_pizza_outlined;
      case 'Meksička':        return Icons.lunch_dining_outlined;
      case 'Francuska':       return Icons.dining_outlined;
      case 'Japanska':        return Icons.ramen_dining_outlined;
      case 'Pizzeria':        return Icons.local_pizza_outlined;
      case 'Internacionalna': return Icons.public_outlined;
      default:                return Icons.restaurant_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final bool isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6B7C45)
                    : const Color(0xFFCCD9B0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    index == 0
                        ? Icons.apps_outlined
                        : _iconForCuisine(categories[index]),
                    size: 22,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF6B7C45),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    categories[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF6B7C45),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// -- Discover section

class _DiscoverSection extends StatelessWidget {
  final String selectedCity;
 
  const _DiscoverSection({required this.selectedCity});
 
  @override
  Widget build(BuildContext context) {
    final items = [
      _DiscoverItem(
        category: RestaurantCategory.bestRated,
        label: 'Najbolje\nocijenjeni',
        icon: Icons.star_rounded,
        color: const Color(0xFFE8B84B),
        bgColor: const Color(0xFFFFF8E7),
      ),
      _DiscoverItem(
        category: RestaurantCategory.mostBooked,
        label: 'Najpopularniji',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFD94F4F),
        bgColor: const Color(0xFFFFF0F0),
      ),
      _DiscoverItem(
        category: RestaurantCategory.onTheRise,
        label: 'U usponu',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF6B7C45),
        bgColor: const Color(0xFFECF2DF),
      ),
    ];
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Istražite',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: items
              .map(
                (item) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: item != items.last ? 10.0 : 0.0),
                    child: _DiscoverCard(
                      item: item,
                      selectedCity: selectedCity,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _DiscoverItem {
  final RestaurantCategory category;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
 
  const _DiscoverItem({
    required this.category,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
 
class _DiscoverCard extends StatelessWidget {
  final _DiscoverItem item;
  final String selectedCity;
 
  const _DiscoverCard({
    required this.item,
    required this.selectedCity,
  });
 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryRestaurantsPage(
            category: item.category,
            selectedCity: selectedCity,
          ),
        ),
      ),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: item.bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 20, color: item.color),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: item.color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map section ──────────────────────────────────────────────────────────────

// ─── City coordinates ────────────────────────────────────────────────────────

const Map<String, LatLng> _cityCoords = {
  'Tuzla':      LatLng(44.5384, 18.6762),
  'Sarajevo':   LatLng(43.8476, 18.3564),
  'Mostar':     LatLng(43.3438, 17.8078),
  'Banja Luka': LatLng(44.7751, 17.1941),
  'Zenica':     LatLng(44.2010, 17.9078),
  'Bijeljina':  LatLng(44.7558, 19.2147),
  'Brčko':      LatLng(44.8683, 18.8102),
  'Travnik':    LatLng(44.2265, 17.6617),
  'Cazin':      LatLng(44.9488, 15.9436),
  'Bihać':      LatLng(44.8175, 15.8703),
  'Živinice':   LatLng(44.4483, 18.6511),
  'Lukavac':    LatLng(44.5355, 18.5260),
  'Gradačac':   LatLng(44.8783, 18.4264),
  'Doboj':      LatLng(44.7311, 18.0867),
  'Zvornik':    LatLng(44.3864, 19.1022),
  'Srebrenik':  LatLng(44.7083, 18.4883),
  'Tešanj':     LatLng(44.6119, 17.9836),
  'Visoko':     LatLng(43.9886, 18.1781),
  'Konjic':     LatLng(43.6575, 17.9608),
};

class _MapSection extends StatefulWidget {
  final List<RestaurantModel> restaurants;
  final String selectedCity;
  final void Function(RestaurantModel) onTap;

  const _MapSection({
    required this.restaurants,
    required this.selectedCity,
    required this.onTap,
  });

  @override
  State<_MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<_MapSection> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(_MapSection old) {
    super.didUpdateWidget(old);
    // When city changes, animate the map to the new city
    if (old.selectedCity != widget.selectedCity) {
      final target = _targetCenter;
      final zoom = _targetZoom;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(target, zoom);
      });
    }
  }

  LatLng get _targetCenter {
    // If a specific city is selected, use its coords
    if (widget.selectedCity != _allCities &&
        _cityCoords.containsKey(widget.selectedCity)) {
      return _cityCoords[widget.selectedCity]!;
    }
    // Otherwise center on first restaurant with coords
    final withCoords = widget.restaurants
        .where((r) => r.lat != null && r.lng != null)
        .toList();
    return withCoords.isNotEmpty
        ? LatLng(withCoords.first.lat!, withCoords.first.lng!)
        : const LatLng(44.0, 17.5); // BiH center
  }

  double get _targetZoom {
    if (widget.selectedCity != _allCities) return 13.0;
    final withCoords = widget.restaurants
        .where((r) => r.lat != null && r.lng != null)
        .toList();
    return withCoords.length == 1 ? 14.0 : 7.5;
  }

  @override
  Widget build(BuildContext context) {
    final withCoords = widget.restaurants
        .where((r) => r.lat != null && r.lng != null)
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _targetCenter,
            initialZoom: _targetZoom,
          ),
          children: [
            TileLayer(
              urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bookit.app',
            ),
            MarkerLayer(
              markers: withCoords.map((r) {
                return Marker(
                  point: LatLng(r.lat!, r.lng!),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => widget.onTap(r),
                    child: Tooltip(
                      message: r.name,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF6B7C45),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.restaurant,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top restaurant card ──────────────────────────────────────────────────────

class _TopRestaurantCard extends StatefulWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;

  const _TopRestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  @override
  State<_TopRestaurantCard> createState() =>
      _TopRestaurantCardState();
}

class _TopRestaurantCardState extends State<_TopRestaurantCard> {
  bool _isFavourite = false;

  @override
  void initState() {
    super.initState();
    _checkFavourite();
  }

  Future<void> _checkFavourite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favourites')
        .doc(widget.restaurant.id)
        .get();
    if (mounted) setState(() => _isFavourite = doc.exists);
  }

  Future<void> _toggleFavourite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favourites')
        .doc(widget.restaurant.id);
    setState(() => _isFavourite = !_isFavourite);
    if (_isFavourite) {
      await ref.set({
        'name': widget.restaurant.name,
        'cuisine': widget.restaurant.cuisineLabel,
        'address': widget.restaurant.address,
        'rating': widget.restaurant.rating,
        'imageUrl': widget.restaurant.imageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 170,
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
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                  child: r.imageUrl.isNotEmpty
                      ? Image.network(r.imageUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _ImagePlaceholder())
                      : _ImagePlaceholder(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: r.isOpenNow
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFD94F4F),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.isOpenNow ? 'Otvoreno' : 'Zatvoreno',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: _toggleFavourite,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                            Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isFavourite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                        color: const Color(0xFFD94F4F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.cuisineLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .color,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(r.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(r.city.isNotEmpty ? r.city : r.address,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 13, color: Color(0xFFE8B84B)),
                      const SizedBox(width: 3),
                      Text(
                        r.rating > 0
                            ? '${r.rating.toStringAsFixed(1)} od 5'
                            : 'Bez ocjene',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Restaurant card (vertical list) ─────────────────────────────────────────

class _RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: r.imageUrl.isNotEmpty
                  ? Image.network(r.imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _SmallPlaceholder())
                  : _SmallPlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(r.name,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: r.isOpenNow
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFD94F4F),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.cuisineLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    r.city.isNotEmpty ? r.city : r.address,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 12, color: Color(0xFFE8B84B)),
                      const SizedBox(width: 3),
                      Text(
                        r.rating > 0
                            ? r.rating.toStringAsFixed(1)
                            : 'Bez ocjene',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color),
                      ),
                      if (r.reviewCount > 0)
                        Text(' (${r.reviewCount})',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFF8A9A7A)),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholders ─────────────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 110,
    width: double.infinity,
    color: const Color(0xFFD8E6C0),
    child: const Center(
      child: Icon(Icons.restaurant,
          size: 36, color: Color(0xFF6B7C45)),
    ),
  );
}

class _SmallPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    color: const Color(0xFFD8E6C0),
    child: const Center(
      child: Icon(Icons.restaurant,
          size: 28, color: Color(0xFF6B7C45)),
    ),
  );
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.storefront_outlined,
                size: 48, color: Color(0xFFCCD9B0)),
            const SizedBox(height: 12),
            Text(message,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .color)),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom navigation bar ────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
 
  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
  });
 
  static const _items = [
    _NavItem(icon: Icons.home_outlined,         activeIcon: Icons.home_rounded,              label: 'Početna'),
    _NavItem(icon: Icons.search_outlined,       activeIcon: Icons.search_rounded,            label: 'Pretraga'),
    _NavItem(icon: Icons.book_online_outlined,  activeIcon: Icons.book_online_rounded,       label: 'Rezervacije'),
    _NavItem(icon: Icons.favorite_outline,      activeIcon: Icons.favorite_rounded,          label: 'Favoriti'),
    _NavItem(icon: Icons.person_outline,        activeIcon: Icons.person_rounded,            label: 'Profil'),
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
          color: isDark
              ? const Color(0xFF2A2A2A)
              : Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                            : const Color(0xFF9E9E9E),
                      ),
                      child: Text(item.label),
                    ),
                  ],
                ),
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
        break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const SearchRestaurantsPage()));
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
        Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const ProfileSettingsPage()));
        break;
    }
  }
}
 
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
 
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}