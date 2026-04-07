import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookit/points/bookit_points_page.dart';

class LeaveReviewPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String restaurantCuisine;

  const LeaveReviewPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.restaurantCuisine,
  });

  @override
  State<LeaveReviewPage> createState() => _LeaveReviewPageState();
}

class _LeaveReviewPageState extends State<LeaveReviewPage> {
  final _commentController = TextEditingController();
  double _selectedRating = 0;
  bool _isSubmitting = false;

  // ── Gating state ───────────────────────────────────────────────────
  bool _checkingEligibility = true;
  bool _hasQualifyingBooking = false;
  bool _alreadyReviewed = false;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Check if user is allowed to review ────────────────────────────
  Future<void> _checkEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _checkingEligibility = false);
      return;
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    try {
      // Check 1: qualifying past booking
      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .where('status', whereIn: ['confirmed', 'cancelled'])
          .get();

      final hasQualifying = bookingsSnap.docs.any((doc) {
        final ts = doc.data()['date'] as Timestamp?;
        if (ts == null) return false;
        final bookingDay = DateTime(
          ts.toDate().year,
          ts.toDate().month,
          ts.toDate().day,
        );
        return bookingDay.isBefore(today);
      });

      // Check 2: already reviewed
      final reviewsSnap = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      final alreadyReviewed = reviewsSnap.docs.isNotEmpty;

      setState(() {
        _hasQualifyingBooking = hasQualifying;
        _alreadyReviewed = alreadyReviewed;
        _checkingEligibility = false;
      });
    } catch (_) {
      setState(() => _checkingEligibility = false);
    }
  }

  // ── Submit review ──────────────────────────────────────────────────
  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Molimo odaberite ocjenu.'),
          backgroundColor: const Color(0xFFE8B84B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Niste prijavljeni.');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 'Korisnik';
      final userAvatarUrl = userDoc.data()?['photoUrl'] ?? '';

      final restaurantRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final restaurantSnap = await transaction.get(restaurantRef);
        final data = restaurantSnap.data() ?? {};

        final currentRating = (data['rating'] ?? 0.0).toDouble();
        final currentCount = (data['reviewCount'] ?? 0) as int;
        final newCount = currentCount + 1;
        final newRating =
            ((currentRating * currentCount) + _selectedRating) / newCount;

        final reviewRef = restaurantRef.collection('reviews').doc();
        transaction.set(reviewRef, {
          'userId': user.uid,
          'restaurantId': widget.restaurantId,
          'restaurantName': widget.restaurantName,
          'restaurantCuisine': widget.restaurantCuisine,
          'userName': userName,
          'userAvatarUrl': userAvatarUrl,
          'rating': _selectedRating,
          'comment': _commentController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(restaurantRef, {
          'rating': double.parse(newRating.toStringAsFixed(1)),
          'reviewCount': newCount,
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recenzija je uspješno poslana!'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      await BookItPointsService.awardReviewPoints(
        userId: user.uid,
        restaurantName: widget.restaurantName,
        restaurantId: widget.restaurantId,
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška: ${e.toString()}'),
          backgroundColor: const Color(0xFFD94F4F),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _ratingLabel(double rating) {
    if (rating == 1) return 'Loše';
    if (rating == 2) return 'Ispod prosjeka';
    if (rating == 3) return 'Prosječno';
    if (rating == 4) return 'Dobro';
    if (rating == 5) return 'Odlično';
    return '';
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // ── Top bar ──────────────────────────────────────
                    Row(
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
                        Text(
                          'Ostavite recenziju',
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

                    const SizedBox(height: 32),

                    // ── Restaurant info card ─────────────────────────
                    Container(
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
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD8E6C0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant,
                                size: 28, color: Color(0xFF6B7C45)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.restaurantName,
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
                                  widget.restaurantAddress,
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Eligibility gate ─────────────────────────────
                    if (_checkingEligibility)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(
                              color: Color(0xFF6B7C45), strokeWidth: 2.5),
                        ),
                      )
                    else if (_alreadyReviewed)
                      _BlockedState(
                        icon: Icons.rate_review_outlined,
                        iconColor: const Color(0xFF6B7C45),
                        title: 'Već ste ostavili recenziju',
                        subtitle:
                            'Možete ostaviti samo jednu recenziju po restoranu.',
                      )
                    else if (!_hasQualifyingBooking)
                      _BlockedState(
                        icon: Icons.lock_outline,
                        iconColor: const Color(0xFFE8B84B),
                        title: 'Recenzija nije dostupna',
                        subtitle:
                            'Možete ostaviti recenziju nakon što posjetite ovaj restoran putem BookIt-a.',
                      )
                    else ...[
                      // ── Star rating ────────────────────────────────
                      Text(
                        'Vaša ocjena',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starValue = index + 1.0;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedRating = starValue),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                _selectedRating >= starValue
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 42,
                                color: _selectedRating >= starValue
                                    ? const Color(0xFFE8B84B)
                                    : const Color(0xFFCCD9B0),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_selectedRating > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Center(
                            child: Text(
                              _ratingLabel(_selectedRating),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7C45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // ── Comment field ──────────────────────────────
                      Text(
                        'Komentar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentController,
                        maxLines: 5,
                        maxLength: 300,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Podijelite Vaše iskustvo s ovim restoranom...',
                          hintStyle: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.all(16),
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

                      const SizedBox(height: 32),

                      // ── Submit button ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              _isSubmitting ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B7C45),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFFCCD9B0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Pošalji recenziju',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
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

// ─── Blocked state widget ─────────────────────────────────────────────────────

class _BlockedState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _BlockedState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall!.color,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}