import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class ManagerReviewModel {
  final String id;
  final String userName;
  final String userAvatarUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String? managerReply;

  const ManagerReviewModel({
    required this.id,
    required this.userName,
    required this.userAvatarUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.managerReply,
  });

  factory ManagerReviewModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['createdAt'] as Timestamp?;
    return ManagerReviewModel(
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
    if (diff.inDays < 30) return 'Prije ${(diff.inDays / 7).floor()} sedmica';
    if (diff.inDays < 365) return 'Prije ${(diff.inDays / 30).floor()} mjeseci';
    return 'Prije ${(diff.inDays / 365).floor()} godina';
  }
}

// ─── Manager Reviews Page ─────────────────────────────────────────────────────

class ManagerReviewsPage extends StatefulWidget {
  const ManagerReviewsPage({super.key});

  @override
  State<ManagerReviewsPage> createState() => _ManagerReviewsPageState();
}

class _ManagerReviewsPageState extends State<ManagerReviewsPage> {
  String _selectedFilter = 'all';
  String? _restaurantId;
  bool _loadingId = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurantId();
  }

  Future<void> _loadRestaurantId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() {
      _restaurantId = doc.data()?['restaurantId'];
      _loadingId = false;
    });
  }

  // ── Save or update manager reply ───────────────────────────────────
  Future<void> _saveReply(String reviewId, String reply) async {
    if (_restaurantId == null) return;
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(_restaurantId)
        .collection('reviews')
        .doc(reviewId)
        .update({
          'managerReply': reply,
          'replyTimestamp': FieldValue.serverTimestamp(),
          });
  }

  // ── Delete manager reply ───────────────────────────────────────────
  Future<void> _deleteReply(String reviewId) async {
    if (_restaurantId == null) return;
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(_restaurantId)
        .collection('reviews')
        .doc(reviewId)
        .update({
          'managerReply': FieldValue.delete(),
          'replyTimestamp': FieldValue.delete(),
          });
  }

  // ── Filter reviews ─────────────────────────────────────────────────
  List<ManagerReviewModel> _applyFilter(List<ManagerReviewModel> all) {
    switch (_selectedFilter) {
      case 'replied':
        return all
            .where((r) =>
                r.managerReply != null && r.managerReply!.isNotEmpty)
            .toList();
      case 'unreplied':
        return all
            .where((r) =>
                r.managerReply == null || r.managerReply!.isEmpty)
            .toList();
      default:
        return all;
    }
  }

  // ── Reply bottom sheet ─────────────────────────────────────────────
  void _openReplySheet(ManagerReviewModel review) {
    final replyController =
        TextEditingController(text: review.managerReply ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCD9B0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                review.managerReply != null &&
                        review.managerReply!.isNotEmpty
                    ? 'Uredi odgovor'
                    : 'Odgovori na recenziju',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '"${review.comment}"',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              TextField(
                controller: replyController,
                maxLines: 4,
                maxLength: 300,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                decoration: InputDecoration(
                  hintText: 'Napišite Vaš odgovor...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall!.color,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.all(14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFCCD9B0), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF6B7C45), width: 1.8),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  // Delete reply button
                  if (review.managerReply != null &&
                      review.managerReply!.isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);
                                await _deleteReply(review.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD94F4F),
                          side: const BorderSide(
                              color: Color(0xFFD94F4F), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Obriši',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Save reply button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final reply =
                                  replyController.text.trim();
                              if (reply.isEmpty) return;
                              setSheetState(() => isSaving = true);
                              await _saveReply(review.id, reply);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B7C45),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFCCD9B0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              review.managerReply != null &&
                                      review.managerReply!.isNotEmpty
                                  ? 'Sačuvaj izmjene'
                                  : 'Pošalji odgovor',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingId) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF6B7C45), strokeWidth: 2.5),
        ),
      );
    }

    if (_restaurantId == null) {
      return Scaffold(
        body: Center(
          child: Text('Restoran nije pronađen.',
              style: TextStyle(
                  color:
                      Theme.of(context).textTheme.bodySmall!.color)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('restaurants')
              .doc(_restaurantId)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF6B7C45), strokeWidth: 2.5),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(snapshot.error.toString(),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color)),
              );
            }

            final allReviews = (snapshot.data?.docs ?? [])
                .map((doc) => ManagerReviewModel.fromFirestore(doc))
                .toList();

            final filtered = _applyFilter(allReviews);

            final unrepliedCount = allReviews
                .where((r) =>
                    r.managerReply == null || r.managerReply!.isEmpty)
                .length;

            final averageRating = allReviews.isEmpty
                ? 0.0
                : allReviews
                        .map((r) => r.rating)
                        .reduce((a, b) => a + b) /
                    allReviews.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Top bar ──────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.arrow_back,
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color,
                            size: 24),
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
                      if (unrepliedCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8B84B)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE8B84B)
                                  .withOpacity(0.5),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            '$unrepliedCount bez odgovora',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE8B84B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Summary card ─────────────────────────────────
                if (allReviews.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B7C45),
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < averageRating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 16,
                                    color: const Color(0xFFE8B84B),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${allReviews.length} recenzija',
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
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: List.generate(5, (i) {
                                final star = 5 - i;
                                final count = allReviews
                                    .where((r) => r.rating == star)
                                    .length;
                                final fraction = allReviews.isEmpty
                                    ? 0.0
                                    : count / allReviews.length;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2),
                                  child: Row(
                                    children: [
                                      Text('$star',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall!
                                                  .color)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star,
                                          size: 11,
                                          color: Color(0xFFE8B84B)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: fraction,
                                            minHeight: 6,
                                            backgroundColor:
                                                const Color(0xFFECF2DF),
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                                    Color(0xFFE8B84B)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('$count',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall!
                                                  .color)),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Filter tabs ──────────────────────────────────
                SizedBox(
                  height: 38,
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterTab(
                        label: 'Sve',
                        count: allReviews.length,
                        isSelected: _selectedFilter == 'all',
                        onTap: () =>
                            setState(() => _selectedFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label: 'Bez odgovora',
                        count: allReviews
                            .where((r) =>
                                r.managerReply == null ||
                                r.managerReply!.isEmpty)
                            .length,
                        isSelected: _selectedFilter == 'unreplied',
                        color: const Color(0xFFE8B84B),
                        onTap: () => setState(
                            () => _selectedFilter = 'unreplied'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label: 'Odgovoreno',
                        count: allReviews
                            .where((r) =>
                                r.managerReply != null &&
                                r.managerReply!.isNotEmpty)
                            .length,
                        isSelected: _selectedFilter == 'replied',
                        color: const Color(0xFF4CAF50),
                        onTap: () => setState(
                            () => _selectedFilter = 'replied'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Reviews list ─────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons.rate_review_outlined,
                                  size: 48,
                                  color: Color(0xFFCCD9B0)),
                              const SizedBox(height: 12),
                              Text(
                                'Nema recenzija.',
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
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _ReviewCard(
                            review: filtered[index],
                            onReply: () =>
                                _openReplySheet(filtered[index]),
                          ),
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
  final ManagerReviewModel review;
  final VoidCallback onReply;

  const _ReviewCard({required this.review, required this.onReply});

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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Guest info + rating ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
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

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
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

                if (review.managerReply != null &&
                    review.managerReply!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Odgovoreno',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Comment ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              review.comment,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium!.color,
                height: 1.5,
              ),
            ),
          ),

          // ── Manager reply ──────────────────────────────────────
          if (review.managerReply != null &&
              review.managerReply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
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

          // ── Reply button ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: GestureDetector(
              onTap: onReply,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    review.managerReply != null &&
                            review.managerReply!.isNotEmpty
                        ? Icons.edit_outlined
                        : Icons.reply_outlined,
                    size: 15,
                    color: const Color(0xFF6B7C45),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    review.managerReply != null &&
                            review.managerReply!.isNotEmpty
                        ? 'Uredi odgovor'
                        : 'Odgovori',
                    style: const TextStyle(
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
    );
  }
}

// ─── Filter tab ───────────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color = const Color(0xFF6B7C45),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCCD9B0),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodySmall!.color,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}