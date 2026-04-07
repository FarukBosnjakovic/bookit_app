import 'package:bookit/restaurants/restaurants_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Search result model ──────────────────────────────────────────────────────

class SearchRestaurantModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String imageUrl;
  final double rating;
  final List<String> cuisines;

  const SearchRestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.imageUrl,
    required this.rating,
    required this.cuisines,
  });

  String get cuisineLabel => cuisines.join(', ');

  factory SearchRestaurantModel.fromFirestore(DocumentSnapshot doc) {
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
    return SearchRestaurantModel(
      id: doc.id,
      name: d['name'] ?? '',
      address: d['address'] ?? '',
      city: d['city'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      rating: (d['rating'] ?? 0.0).toDouble(),
      cuisines: cuisines,
    );
  }
}

// ─── Quick filter suggestions ─────────────────────────────────────────────────

const List<Map<String, dynamic>> _quickFilters = [
  {'label': 'Najbolje ocijenjeni', 'icon': Icons.star_outline,       'type': 'rating'},
  {'label': 'Italijanska',         'icon': Icons.local_pizza_outlined,'type': 'cuisine'},
  {'label': 'Tradicionalna',       'icon': Icons.outdoor_grill_outlined,'type': 'cuisine'},
  {'label': 'Azijska',             'icon': Icons.rice_bowl_outlined,  'type': 'cuisine'},
  {'label': 'Evropska',            'icon': Icons.local_dining_outlined,'type': 'cuisine'},
  {'label': 'Mediteranska',        'icon': Icons.set_meal_outlined,   'type': 'cuisine'},
  {'label': 'Japanska',            'icon': Icons.ramen_dining_outlined,'type': 'cuisine'},
  {'label': 'Pizzeria',            'icon': Icons.local_pizza_outlined, 'type': 'cuisine'},
];

// ─── BiH cities ───────────────────────────────────────────────────────────────

const String _allCities = 'Sve lokacije';
const List<String> _bihCities = [
  _allCities, 'Tuzla', 'Sarajevo', 'Mostar', 'Banja Luka', 'Zenica',
  'Bijeljina', 'Brčko', 'Travnik', 'Cazin', 'Bihać', 'Živinice',
  'Lukavac', 'Gradačac', 'Doboj', 'Zvornik', 'Srebrenik', 'Tešanj',
  'Visoko', 'Konjic',
];

// ─── Search Restaurants Page ──────────────────────────────────────────────────

class SearchRestaurantsPage extends StatefulWidget {
  const SearchRestaurantsPage({super.key});

  @override
  State<SearchRestaurantsPage> createState() => _SearchRestaurantsPageState();
}

class _SearchRestaurantsPageState extends State<SearchRestaurantsPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  String _selectedCity = _allCities;
  String _query = '';
  List<SearchRestaurantModel> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  // Recent searches stored in SharedPreferences
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q != _query) {
        setState(() => _query = q);
        if (q.length >= 2) {
          _search(q);
        } else {
          setState(() {
            _results = [];
            _hasSearched = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Load recent searches ───────────────────────────────────────────
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches =
          prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveSearch(String query) async {
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    list.remove(query);
    list.insert(0, query);
    final trimmed = list.take(8).toList();
    await prefs.setStringList('recent_searches', trimmed);
    setState(() => _recentSearches = trimmed);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() => _recentSearches = []);
  }

  Future<void> _removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    list.remove(query);
    await prefs.setStringList('recent_searches', list);
    setState(() => _recentSearches = list);
  }

  // ── Firestore search ───────────────────────────────────────────────
  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final q = query.toLowerCase();
      QuerySnapshot snapshot;

      if (_selectedCity != _allCities) {
        snapshot = await FirebaseFirestore.instance
            .collection('restaurants')
            .where('city', isEqualTo: _selectedCity)
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance
            .collection('restaurants')
            .get();
      }

      final all = snapshot.docs
          .map((doc) => SearchRestaurantModel.fromFirestore(doc))
          .toList();

      // Client-side filter by name or cuisine
      final filtered = all.where((r) {
        return r.name.toLowerCase().contains(q) ||
            r.cuisines.any((c) => c.toLowerCase().contains(q)) ||
            r.address.toLowerCase().contains(q) ||
            r.city.toLowerCase().contains(q);
      }).toList();

      // Sort by rating descending
      filtered.sort((a, b) => b.rating.compareTo(a.rating));

      setState(() {
        _results = filtered;
        _searching = false;
        _hasSearched = true;
      });
    } catch (_) {
      setState(() {
        _searching = false;
        _hasSearched = true;
      });
    }
  }

  // ── Apply quick filter ─────────────────────────────────────────────
  void _applyQuickFilter(Map<String, dynamic> filter) {
    final label = filter['label'] as String;
    _searchController.text = label;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: label.length),
    );
    _saveSearch(label);
    _search(label);
  }

  // ── Apply recent search ────────────────────────────────────────────
  void _applyRecentSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _search(query);
  }

  // ── City picker ────────────────────────────────────────────────────
  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  width: 40, height: 4,
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
                  const Icon(Icons.location_on, size: 20, color: Color(0xFFD94F4F)),
                  const SizedBox(width: 8),
                  Text('Odaberite grad',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFECF2DF)),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _bihCities.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFECF2DF)),
                itemBuilder: (context, index) {
                  final city = _bihCities[index];
                  final isSelected = city == _selectedCity;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCity = city);
                      Navigator.pop(context);
                      if (_query.length >= 2) _search(_query);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            city == _allCities ? Icons.public_outlined : Icons.location_city_outlined,
                            size: 20,
                            color: isSelected ? const Color(0xFF6B7C45) : Theme.of(context).textTheme.bodySmall!.color,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              city == _allCities ? city : '$city, BiH',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? const Color(0xFF6B7C45) : Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check, size: 18, color: Color(0xFF6B7C45)),
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

  void _navigateTo(SearchRestaurantModel r) {
    _saveSearch(r.name);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantProfilePage(restaurantId: r.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showResults = _query.length >= 2;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Location bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _openCityPicker,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFCCD9B0), width: 1.2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: Color(0xFFD94F4F)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedCity == _allCities
                              ? 'Bosna i Hercegovina'
                              : '$_selectedCity, BiH',
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
                      const Icon(Icons.keyboard_arrow_down,
                          size: 20, color: Color(0xFF8A9A7A)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Search bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    const Icon(Icons.search,
                        size: 20, color: Color(0xFF8A9A7A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tip hrane, naziv restorana...',
                          hintStyle: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _saveSearch(val.trim());
                            _search(val.trim());
                          }
                        },
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.close,
                              size: 18, color: Color(0xFF8A9A7A)),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'Odustani',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7C45),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Content ────────────────────────────────────────────
            Expanded(
              child: showResults
                  ? _buildResults()
                  : _buildDiscovery(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Discovery view (no query) ──────────────────────────────────────
  Widget _buildDiscovery() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // ── Use current location ─────────────────────────────────
        GestureDetector(
          onTap: _openCityPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFCCD9B0), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B7C45).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location,
                      size: 18, color: Color(0xFF6B7C45)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Koristi moju lokaciju',
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
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Color(0xFF8A9A7A)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Recent searches ──────────────────────────────────────
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nedavne pretrage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: const Text(
                  'Obriši sve',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7C45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentSearches.map((search) => _RecentSearchRow(
                query: search,
                onTap: () => _applyRecentSearch(search),
                onRemove: () => _removeRecentSearch(search),
              )),
          const SizedBox(height: 24),
        ],

        // ── Top searches ─────────────────────────────────────────
        Text(
          'Prijedlozi pretrage',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        const SizedBox(height: 12),
        ..._quickFilters.map((filter) => _QuickFilterRow(
              filter: filter,
              onTap: () => _applyQuickFilter(filter),
            )),
      ],
    );
  }

  // ── Search results view ────────────────────────────────────────────
  Widget _buildResults() {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF6B7C45), strokeWidth: 2.5),
      );
    }

    if (_hasSearched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off,
                size: 52, color: Color(0xFFCCD9B0)),
            const SizedBox(height: 14),
            Text(
              'Nema rezultata za "$_query"',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pokušajte sa drugim pojmom.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall!.color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rezultati pretrage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
              Text(
                '${_results.length} restorana',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _SearchResultCard(
              restaurant: _results[index],
              onTap: () => _navigateTo(_results[index]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Recent search row ────────────────────────────────────────────────────────

class _RecentSearchRow extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentSearchRow({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFCCD9B0), width: 1),
              ),
              child: const Icon(Icons.history,
                  size: 16, color: Color(0xFF8A9A7A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    query,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close,
                    size: 16, color: Color(0xFF8A9A7A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick filter row ─────────────────────────────────────────────────────────

class _QuickFilterRow extends StatelessWidget {
  final Map<String, dynamic> filter;
  final VoidCallback onTap;

  const _QuickFilterRow({
    required this.filter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF6B7C45).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                filter['icon'] as IconData,
                size: 16,
                color: const Color(0xFF6B7C45),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                    ),
                  ),
                  Text(
                    filter['type'] == 'rating'
                        ? 'Sortirano po ocjeni'
                        : 'Tip kuhinje',
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

// ─── Search result card ───────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final SearchRestaurantModel restaurant;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Restaurant image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: restaurant.imageUrl.isNotEmpty
                    ? Image.network(
                        restaurant.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),

            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: TextStyle(
                      fontSize: 15,
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
                    restaurant.cuisineLabel,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Color(0xFF8A9A7A)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          restaurant.city.isNotEmpty
                              ? restaurant.city
                              : restaurant.address,
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
                      if (restaurant.rating > 0) ...[
                        const Icon(Icons.star,
                            size: 12, color: Color(0xFFE8B84B)),
                        const SizedBox(width: 3),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color,
                          ),
                        ),
                      ],
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

  Widget _placeholder() => Container(
        color: const Color(0xFFD8E6C0),
        child: const Center(
          child: Icon(Icons.restaurant,
              size: 28, color: Color(0xFF6B7C45)),
        ),
      );
}