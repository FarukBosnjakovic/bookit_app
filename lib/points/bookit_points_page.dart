import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Tier helpers ─────────────────────────────────────────────────────────────

enum BookItTier { bronze, silver, gold }

BookItTier tierFromPoints(int points) {
  if (points >= 500) return BookItTier.gold;
  if (points >= 200) return BookItTier.silver;
  return BookItTier.bronze;
}

String tierName(BookItTier tier) {
  switch (tier) {
    case BookItTier.gold:   return 'Gold';
    case BookItTier.silver: return 'Silver';
    case BookItTier.bronze: return 'Bronze';
  }
}

Color tierColor(BookItTier tier) {
  switch (tier) {
    case BookItTier.gold:   return const Color(0xFFE8B84B);
    case BookItTier.silver: return const Color(0xFF8A9A7A);
    case BookItTier.bronze: return const Color(0xFFB5651D);
  }
}

IconData tierIcon(BookItTier tier) {
  switch (tier) {
    case BookItTier.gold:   return Icons.workspace_premium;
    case BookItTier.silver: return Icons.military_tech;
    case BookItTier.bronze: return Icons.emoji_events_outlined;
  }
}

int nextTierThreshold(BookItTier tier) {
  switch (tier) {
    case BookItTier.bronze: return 200;
    case BookItTier.silver: return 500;
    case BookItTier.gold:   return 500;
  }
}

// ─── Points history model ─────────────────────────────────────────────────────

class PointsEntry {
  final String id;
  final int points;
  final String reason;
  final String restaurantName;
  final DateTime createdAt;

  const PointsEntry({
    required this.id,
    required this.points,
    required this.reason,
    required this.restaurantName,
    required this.createdAt,
  });

  factory PointsEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['createdAt'] as Timestamp?;
    return PointsEntry(
      id: doc.id,
      points: (d['points'] as int?) ?? 0,
      reason: d['reason'] as String? ?? '',
      restaurantName: d['restaurantName'] as String? ?? '',
      createdAt: ts?.toDate() ?? DateTime.now(),
    );
  }

  String get reasonLabel {
    switch (reason) {
      case 'first_booking':   return 'Prva rezervacija';
      case 'booking':         return 'Potvrđena rezervacija';
      case 'review':          return 'Ostavljena recenzija';
      case 'repeat_visitor':  return 'Bonus — ponovni gost';
      default:                return reason;
    }
  }

  IconData get reasonIcon {
    switch (reason) {
      case 'first_booking':   return Icons.star_outline;
      case 'booking':         return Icons.calendar_today_outlined;
      case 'review':          return Icons.rate_review_outlined;
      case 'repeat_visitor':  return Icons.favorite_outline;
      default:                return Icons.add_circle_outline;
    }
  }
}

// ─── BookIt Points Page ───────────────────────────────────────────────────────

class BookItPointsPage extends StatelessWidget {
  const BookItPointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        body: Center(child: Text('Niste prijavljeni.',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall!.color))),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            final points = (userSnap.data?.data()
                as Map<String, dynamic>?)?['bookitPoints'] as int? ?? 0;
            final tier = tierFromPoints(points);
            // final tColor = tierColor(tier);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                          size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text('BookIt Poeni',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .textTheme.bodyLarge!.color)),
                  ]),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Tier card ──────────────────────────────
                        _TierCard(points: points, tier: tier),

                        const SizedBox(height: 24),

                        // ── How to earn ────────────────────────────
                        _SectionLabel('Kako zaraditi poene'),
                        const SizedBox(height: 12),
                        _EarnCard(),

                        const SizedBox(height: 24),

                        // ── History ────────────────────────────────
                        _SectionLabel('Historija poena'),
                        const SizedBox(height: 12),
                        _HistoryList(uid: uid),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Tier card ────────────────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  final int points;
  final BookItTier tier;

  const _TierCard({required this.points, required this.tier});

  @override
  Widget build(BuildContext context) {
    final tColor = tierColor(tier);
    final nextThreshold = nextTierThreshold(tier);
    final isMax = tier == BookItTier.gold;
    final progress = isMax ? 1.0 : (points / nextThreshold).clamp(0.0, 1.0);
    final remaining = isMax ? 0 : nextThreshold - points;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tColor.withOpacity(0.15), tColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(tierIcon(tier), size: 26, color: tColor),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tierName(tier),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: tColor)),
            Text('Vaš trenutni nivo',
                style: TextStyle(fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall!.color)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$points',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color)),
            Text('poena',
                style: TextStyle(fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall!.color)),
          ]),
        ]),

        const SizedBox(height: 20),

        // Progress bar
        if (!isMax) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Do sljedećeg nivoa',
                style: TextStyle(fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall!.color)),
            Text('$remaining poena',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: tColor)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: tColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(tColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('0',
                style: TextStyle(fontSize: 10,
                    color: Theme.of(context).textTheme.bodySmall!.color)),
            Text('$nextThreshold',
                style: TextStyle(fontSize: 10,
                    color: Theme.of(context).textTheme.bodySmall!.color)),
          ]),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: tColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text('Čestitamo! Dosegli ste najviši nivo! 🎉',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: tColor))),
          ),
        ],

        const SizedBox(height: 16),

        // Tier overview
        Row(children: [
          _TierBadge(label: 'Bronze', threshold: '0+',
              active: tier == BookItTier.bronze,
              color: tierColor(BookItTier.bronze)),
          const SizedBox(width: 8),
          _TierBadge(label: 'Silver', threshold: '200+',
              active: tier == BookItTier.silver,
              color: tierColor(BookItTier.silver)),
          const SizedBox(width: 8),
          _TierBadge(label: 'Gold', threshold: '500+',
              active: tier == BookItTier.gold,
              color: tierColor(BookItTier.gold)),
        ]),
      ]),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String label;
  final String threshold;
  final bool active;
  final Color color;

  const _TierBadge({
    required this.label,
    required this.threshold,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? color : color.withOpacity(0.3), width: 1.2),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? color
                      : Theme.of(context).textTheme.bodySmall!.color)),
          Text(threshold,
              style: TextStyle(fontSize: 10,
                  color: Theme.of(context).textTheme.bodySmall!.color)),
        ]),
      ),
    );
  }
}

// ─── Earn card ────────────────────────────────────────────────────────────────

class _EarnCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.star_outline, label: 'Prva rezervacija u restoranu',
          points: '+50 poena', color: const Color(0xFF6B7C45)),
      (icon: Icons.calendar_today_outlined,
          label: 'Svaka potvrđena rezervacija', points: '+25 poena',
          color: const Color(0xFF6B7C45)),
      (icon: Icons.rate_review_outlined, label: 'Ostavite recenziju',
          points: '+10 poena', color: const Color(0xFF6B7C45)),
      (icon: Icons.favorite_outline,
          label: '3+ rezervacije u istom restoranu',
          points: '+100 bonus', color: const Color(0xFFE8B84B)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 18, color: item.color),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item.label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge!.color))),
                const SizedBox(width: 8),
                Text(item.points,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: item.color)),
              ]),
            ),
            if (!isLast)
              const Divider(height: 1, indent: 16, endIndent: 16,
                  color: Color(0xFFECF2DF)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─── History list ─────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final String uid;
  const _HistoryList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('pointsHistory')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
                color: Color(0xFF6B7C45), strokeWidth: 2),
          ));
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              const Icon(Icons.history, size: 36, color: Color(0xFFCCD9B0)),
              const SizedBox(height: 10),
              Text('Još nemate historiju poena.',
                  style: TextStyle(fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall!.color)),
            ]),
          );
        }

        final entries = docs
            .map((d) => PointsEntry.fromFirestore(d))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: entries.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final isLast = i == entries.length - 1;

              const months = [
                'Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Jun',
                'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dec',
              ];
              final dateStr =
                  '${e.createdAt.day}. ${months[e.createdAt.month - 1]}';

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7C45).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(e.reasonIcon, size: 16,
                          color: const Color(0xFF6B7C45)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(e.reasonLabel,
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme.bodyLarge!.color)),
                      if (e.restaurantName.isNotEmpty)
                        Text(e.restaurantName,
                            style: TextStyle(fontSize: 11,
                                color: Theme.of(context)
                                    .textTheme.bodySmall!.color)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text('+${e.points}',
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B7C45))),
                      Text(dateStr,
                          style: TextStyle(fontSize: 10,
                              color: Theme.of(context)
                                  .textTheme.bodySmall!.color)),
                    ]),
                  ]),
                ),
                if (!isLast)
                  const Divider(height: 1, indent: 16, endIndent: 16,
                      color: Color(0xFFECF2DF)),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge!.color));
}

// ─── Points service (static helpers) ─────────────────────────────────────────

class BookItPointsService {
  static Future<void> awardBookingPoints({
    required String userId,
    required String restaurantId,
    required String restaurantName,
  }) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final historyRef = userRef.collection('pointsHistory');

      // Count how many confirmed bookings this user has at this restaurant
      final existing = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('restaurantId', isEqualTo: restaurantId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      final isFirst = existing.docs.isEmpty;
      final bookingPoints = isFirst ? 50 : 25;
      final reason = isFirst ? 'first_booking' : 'booking';

      // Award booking points
      await historyRef.add({
        'points': bookingPoints,
        'reason': reason,
        'restaurantName': restaurantName,
        'restaurantId': restaurantId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await userRef.update({
        'bookitPoints': FieldValue.increment(bookingPoints),
      });

      // Check repeat visitor bonus (3rd confirmed booking at this restaurant)
      final totalAtRestaurant = existing.docs.length + 1;
      if (totalAtRestaurant == 3) {
        await historyRef.add({
          'points': 100,
          'reason': 'repeat_visitor',
          'restaurantName': restaurantName,
          'restaurantId': restaurantId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await userRef.update({
          'bookitPoints': FieldValue.increment(100),
        });
      }
    } catch (e) {
      debugPrint('BookItPointsService.awardBookingPoints error: $e');
    }
  }

  static Future<void> awardReviewPoints({
    required String userId,
    required String restaurantName,
    required String restaurantId,
  }) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userRef.collection('pointsHistory').add({
        'points': 10,
        'reason': 'review',
        'restaurantName': restaurantName,
        'restaurantId': restaurantId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await userRef.update({'bookitPoints': FieldValue.increment(10)});
    } catch (e) {
      debugPrint('BookItPointsService.awardReviewPoints error: $e');
    }
  }
}