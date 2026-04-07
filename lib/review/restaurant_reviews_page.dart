import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class ReviewModel {
  final String id;
  final String userName;
  final String userAvatarUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String? managerReply;

  const ReviewModel({
    required this.id,
    required this.userName,
    required this.userAvatarUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.managerReply,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['createdAt'] as Timestamp?;
    return ReviewModel(
      id: doc.id,
      userName: d['userName'] ?? 'Anoniman',
      userAvatarUrl: d['userAvatarUrl'] ?? '',
      rating: (d['rating'] ?? 0.0).toDouble(),
      comment: d['comment'] ?? '',
      createdAt: ts?.toDate() ?? DateTime.now(),
      managerReply: d['managerReply'] as String?,
    );
  }

  String get initials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return userName.isNotEmpty ? userName[0].toUpperCase() : '?';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return 'Prije ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Prije ${diff.inHours} h';
    if (diff.inDays < 7) return 'Prije ${diff.inDays} dana';
    if (diff.inDays < 30)
      return 'Prije ${(diff.inDays / 7).floor()} sedmica';
    if (diff.inDays < 365)
      return 'Prije ${(diff.inDays / 30).floor()} mjeseci';
    return 'Prije ${(diff.inDays / 365).floor()} godina';
  }
}

// ─── Restaurant Reviews Page ──────────────────────────────────────────────────

class RestaurantReviewsPage extends StatelessWidget {
  final String restaurantId;

  const RestaurantReviewsPage({
    super.key,
    required this.restaurantId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('restaurants')
              .doc(restaurantId)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final reviews = (snapshot.data?.docs ?? [])
                .map((doc) => ReviewModel.fromFirestore(doc))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Top bar ────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
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
                        child: Text(
                          'Recenzije',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color,
                          ),
                        ),
                      ),
                      // Review count badge
                      if (reviews.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7C45)
                                .withOpacity(0.1),
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

                const SizedBox(height: 20),

                // ── Loading ────────────────────────────────────────
                if (snapshot.connectionState ==
                    ConnectionState.waiting)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6B7C45), strokeWidth: 2.5),
                    ),
                  )

                // ── Empty state ────────────────────────────────────
                else if (reviews.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rate_review_outlined,
                              size: 48, color: Color(0xFFCCD9B0)),
                          const SizedBox(height: 12),
                          Text(
                            'Još nema recenzija.',
                            style: TextStyle(
                              fontSize: 15,
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

                // ── Reviews list ───────────────────────────────────
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 32,
                        color: Color(0xFFCCD9B0),
                      ),
                      itemBuilder: (context, index) =>
                          _ReviewCard(review: reviews[index]),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Review card ──────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── User info row ────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFD8E6C0),
              backgroundImage: review.userAvatarUrl.isNotEmpty
                  ? NetworkImage(review.userAvatarUrl)
                  : null,
              child: review.userAvatarUrl.isEmpty
                  ? Text(
                      review.initials,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7C45),
                      ),
                    )
                  : null,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.userName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: const Color(0xFFE8B84B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        review.timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall!
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

        const SizedBox(height: 10),

        // ── Comment ───────────────────────────────────────────────
        Text(
          review.comment,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium!.color,
            height: 1.5,
          ),
        ),

        // ── Manager reply ──────────────────────────────────────────
        if (review.managerReply != null &&
            review.managerReply!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B7C45).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6B7C45).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 13, color: Color(0xFF6B7C45)),
                    SizedBox(width: 5),
                    Text(
                      'Odgovor restorana',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7C45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  review.managerReply!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .color,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}