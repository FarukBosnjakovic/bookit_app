import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookit/restaurants/restaurants_profile_page.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class FavouriteRestaurantModel {
  final String id;
  final String docId;
  final String name;
  final String cuisine;
  final String address;
  final double rating;
  final String imageUrl;

  const FavouriteRestaurantModel({
    required this.id,
    required this.docId,
    required this.name,
    required this.cuisine,
    required this.address,
    required this.rating,
    required this.imageUrl,
  });

  factory FavouriteRestaurantModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FavouriteRestaurantModel(
      id: d['restaurantId'] ?? d['id'] ?? doc.id,
      docId: doc.id,
      name: d['name'] ?? '',
      cuisine: d['cuisine'] ?? '',
      address: d['address'] ?? '',
      rating: (d['rating'] ?? 0.0).toDouble(),
      imageUrl: d['imageUrl'] ?? '',
    );
  }
}

// ─── Favourite Restaurants Page ───────────────────────────────────────────────

class FavouriteRestaurantsPage extends StatelessWidget {
  const FavouriteRestaurantsPage({super.key});

  // ── Remove from favourites ─────────────────────────────────────────
  Future<void> _removeFavourite(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favourites')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────────
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.fromLTRB(0, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                // decoration: BoxDecoration(
                //   color: Theme.of(context).scaffoldBackgroundColor,
                //   borderRadius: BorderRadius.circular(20),
                //   border: Border.all(
                //     color: isDarkMode 
                //         ? Colors.white.withOpacity(0.5) 
                //         : const Color(0xFFECF2DF),
                //     width: 2,
                //   ),
                //   boxShadow: [
                //     BoxShadow(
                //       color: Colors.black.withOpacity(0.08),
                //       blurRadius: 15,
                //       offset: const Offset(0, 4),
                //     ),
                //   ],
                // ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back,
                        color: isDarkMode ? Colors.white : const Color(0xFF212121),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Favoriti',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF212121),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Favourites list ──────────────────────────────────────
            Expanded(
              child: uid == null
                  ? Center(
                      child: Text(
                        'Niste prijavljeni.',
                        style: TextStyle(
                          fontSize: 15,
                          color:
                              Theme.of(context).textTheme.bodySmall!.color,
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('favourites')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6B7C45),
                              strokeWidth: 2.5,
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        final favourites = docs
                            .map((doc) =>
                                FavouriteRestaurantModel.fromFirestore(doc))
                            .toList();

                        // if (favourites.isEmpty) {
                        //   return Center(
                        //     child: Column(
                        //       mainAxisAlignment: MainAxisAlignment.center,
                        //       children: [
                        //         const Icon(
                        //           Icons.favorite_border,
                        //           size: 48,
                        //           color: Color(0xFFCCD9B0),
                        //         ),
                        //         const SizedBox(height: 12),
                        //         Text(
                        //           'Nemate omiljenih restorana.',
                        //           style: TextStyle(
                        //             fontSize: 15,
                        //             color: Theme.of(context)
                        //                 .textTheme
                        //                 .bodySmall!
                        //                 .color,
                        //           ),
                        //         ),
                        //       ],
                        //     ),
                        //   );
                        // }

                        if (favourites.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD94F4F).withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.favorite_border,
                                      size: 36,
                                      color: Color(0xFFD94F4F),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Nemate omiljenih restorana',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).textTheme.bodyLarge!.color,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Dodajte restorane u favorite kako biste ih lako pronašli.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).textTheme.bodySmall!.color,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 28),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      // onPressed: () => Navigator.pop(context),
                                      onPressed: () => Navigator.popUntil(
                                        context,
                                        (route) => route.isFirst
                                      ),
                                      icon: const Icon(
                                        Icons.explore_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Istraži restorane',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6B7C45),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: favourites.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            return _FavouriteCard(
                              restaurant: favourites[index],
                              onFavouriteTap: () =>
                                  _removeFavourite(favourites[index].docId),
                              onTap: () {
                                // Check your debug console to see if this ID matches your 'restaurants' collection
                                debugPrint('Navigating to restaurant ID: ${favourites[index].id}');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RestaurantProfilePage(
                                      restaurantId: favourites[index].id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Favourite card ───────────────────────────────────────────────────────────

class _FavouriteCard extends StatelessWidget {
  final FavouriteRestaurantModel restaurant;
  final VoidCallback onFavouriteTap;
  final VoidCallback onTap;

  const _FavouriteCard({
    required this.restaurant,
    required this.onFavouriteTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Colors.blueGrey.shade200,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
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
            // ── Image + heart ────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 140,
                    child: restaurant.imageUrl.isNotEmpty
                        ? Image.network(
                            restaurant.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ImagePlaceholder(),
                          )
                        : _ImagePlaceholder(),
                  ),
                ),

                // Heart button
                Positioned(
                  top: 10,
                  right: 12,
                  child: GestureDetector(
                    onTap: onFavouriteTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFFD94F4F),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Details ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.cuisine,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Theme.of(context).textTheme.bodySmall!.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: Color(0xFF8A9A7A)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          style: TextStyle(
                            fontSize: 13,
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 14, color: Color(0xFFE8B84B)),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.rating > 0
                            ? '${restaurant.rating.toStringAsFixed(1)} od 5'
                            : 'Bez ocjene',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color,
                        ),
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

// ─── Image placeholder ────────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECF2DF),
      child: const Center(
        child: Icon(Icons.restaurant, size: 48, color: Color(0xFF6B7C45)),
      ),
    );
  }
}