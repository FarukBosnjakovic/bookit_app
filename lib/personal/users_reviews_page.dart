import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class UserReviewModel {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String restaurantCuisine;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const UserReviewModel({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantCuisine,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory UserReviewModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserReviewModel(
      id: doc.id,
      restaurantId: d['restaurantId'] ?? '',
      restaurantName: d['restaurantName'] ?? '',
      restaurantCuisine: d['restaurantCuisine'] ?? '',
      rating: (d['rating'] ?? 0.0).toDouble(),
      comment: d['comment'] ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get formattedDate {
    const months = [
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni',
      'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];
    return '${createdAt.day}. ${months[createdAt.month - 1]} ${createdAt.year}.';
  }
}

// ─── User Reviews Page ────────────────────────────────────────────────────────

class UserReviewsPage extends StatelessWidget {
  const UserReviewsPage({super.key});

  Future<void> _deleteReview(
      BuildContext context, UserReviewModel review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Obrisati recenziju?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        content: Text(
          'Da li ste sigurni da želite obrisati Vašu recenziju?',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall!.color,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Odustani',
                style: TextStyle(
                    color:
                        Theme.of(context).textTheme.bodySmall!.color,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Obriši',
                style: TextStyle(
                    color: Color(0xFFD94F4F),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final restaurantRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(review.restaurantId);
      final reviewRef =
          restaurantRef.collection('reviews').doc(review.id);

      await FirebaseFirestore.instance
          .runTransaction((transaction) async {
        final restaurantSnap = await transaction.get(restaurantRef);
        final data = restaurantSnap.data() ?? {};
        final currentRating = (data['rating'] ?? 0.0).toDouble();
        final currentCount = (data['reviewCount'] ?? 0) as int;

        transaction.delete(reviewRef);

        if (currentCount <= 1) {
          transaction.update(restaurantRef,
              {'rating': 0.0, 'reviewCount': 0});
        } else {
          final newCount = currentCount - 1;
          final newRating =
              ((currentRating * currentCount) - review.rating) /
                  newCount;
          transaction.update(restaurantRef, {
            'rating':
                double.parse(newRating.toStringAsFixed(1)),
            'reviewCount': newCount,
          });
        }
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recenzija je obrisana.'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Greška pri brisanju. Pokušajte ponovo.'),
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: uid == null
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collectionGroup('reviews')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
          builder: (context, snapshot) {
            final reviews = (snapshot.data?.docs ?? [])
                .map((doc) => UserReviewModel.fromFirestore(doc))
                .toList();

            final isDarkMode = Theme.of(context).brightness == Brightness.dark;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ──────────────────────────────────────
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
                        Expanded(
                          child: Text(
                            'Moje recenzije',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : const Color(0xFF212121),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7C45).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${reviews.length} recenzija',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7C45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6B7C45),
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Greška: ${(snapshot.error as dynamic)?.message ?? snapshot.error.runtimeType}',
                          style: const TextStyle(color: Color(0xFFD94F4F), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else if (reviews.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rate_review_outlined,
                              size: 56, color: Color(0xFFCCD9B0)),
                          const SizedBox(height: 14),
                          Text(
                            'Nemate recenzija.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Podijelite iskustvo nakon posjete restoranu.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // ── Summary strip ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20),
                    child: _SummaryStrip(reviews: reviews),
                  ),

                  const SizedBox(height: 16),

                  // ── Reviews list ───────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _UserReviewCard(
                        review: reviews[index],
                        onDelete: () =>
                            _deleteReview(context, reviews[index]),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Summary strip ────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final List<UserReviewModel> reviews;
  const _SummaryStrip({required this.reviews});

  double get _averageRating {
    if (reviews.isEmpty) return 0;
    return reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
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
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prosječna ocjena',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7C45)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < _averageRating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: const Color(0xFFE8B84B),
                          ),
                        ),
                      ),
                      Text('${reviews.length} recenzija',
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
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (i) {
              final star = 5 - i;
              final count =
                  reviews.where((r) => r.rating == star).length;
              return Row(
                children: [
                  Text('$star',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .color)),
                  const SizedBox(width: 3),
                  const Icon(Icons.star,
                      size: 11, color: Color(0xFFE8B84B)),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: reviews.isEmpty
                            ? 0
                            : count / reviews.length,
                        minHeight: 5,
                        backgroundColor:
                            const Color(0xFFECF2DF),
                        valueColor:
                            const AlwaysStoppedAnimation(
                                Color(0xFFE8B84B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('$count',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .color)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── User review card ─────────────────────────────────────────────────────────

class _UserReviewCard extends StatefulWidget {
  final UserReviewModel review;
  final VoidCallback onDelete;

  const _UserReviewCard({
    required this.review,
    required this.onDelete,
  });

  @override
  State<_UserReviewCard> createState() => _UserReviewCardState();
}

class _UserReviewCardState extends State<_UserReviewCard> {
  String _name = '';
  String _cuisine = '';
  String _imageUrl = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Use saved values as immediate fallback
    _name = widget.review.restaurantName;
    _cuisine = widget.review.restaurantCuisine;
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    if (widget.review.restaurantId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.review.restaurantId)
          .get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        // Cuisines — support both array and single string
        String cuisine = _cuisine;
        final cuisinesData = d['cuisines'];
        final cuisineData = d['cuisine'];
        if (cuisinesData != null && cuisinesData is List) {
          cuisine = (cuisinesData)
              .map((e) => e.toString())
              .join(', ');
        } else if (cuisineData != null) {
          cuisine = cuisineData.toString();
        }

        setState(() {
          _name = (d['name'] as String?)?.isNotEmpty == true
              ? d['name'] as String
              : widget.review.restaurantName;
          _cuisine = cuisine;
          _imageUrl = (d['imageUrl'] as String?) ?? '';
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Restaurant info header ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Restaurant image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: _loading
                        ? Container(
                            color: const Color(0xFFD8E6C0),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF6B7C45),
                                    strokeWidth: 2),
                              ),
                            ),
                          )
                        : _imageUrl.isNotEmpty
                            ? Image.network(
                                _imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholder(),
                              )
                            : _placeholder(),
                  ),
                ),

                const SizedBox(width: 10),

                // Name + cuisine
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _loading
                          ? Container(
                              height: 13,
                              width: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8E6C0),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                            )
                          : Text(
                              _name.isNotEmpty
                                  ? _name
                                  : 'Nepoznat restoran',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color,
                              ),
                            ),
                      const SizedBox(height: 3),
                      _loading
                          ? Container(
                              height: 10,
                              width: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8E6C0),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                            )
                          : Text(
                              _cuisine,
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

                // Delete button
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94F4F)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 16, color: Color(0xFFD94F4F)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: Color(0xFFECF2DF)),

          // ── Rating + date ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: const Color(0xFFE8B84B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  review.formattedDate,
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

          // ── Comment ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(
                left: 14, right: 14, bottom: 14),
            child: Text(
              review.comment,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFD8E6C0),
        child: const Center(
          child: Icon(Icons.restaurant,
              size: 20, color: Color(0xFF6B7C45)),
        ),
      );
}