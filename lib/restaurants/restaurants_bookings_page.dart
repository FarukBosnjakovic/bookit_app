import 'package:bookit/reservations/bookings_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookit/review/leave_review_page.dart';

// ─── Booking model ────────────────────────────────────────────────────────────

class BookingModel {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final int guestCount;
  final DateTime date;
  final String time;
  final String status;
  final String sectionName;
  final String cuisineLabel;

  const BookingModel({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.guestCount,
    required this.date,
    required this.time,
    required this.status,
    required this.sectionName,
    this.cuisineLabel = '',
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['date'] as Timestamp?;
    return BookingModel(
      id: doc.id,
      restaurantId: d['restaurantId'] ?? '',
      restaurantName: d['restaurantName'] ?? '',
      restaurantAddress: d['restaurantAddress'] ?? '',
      guestCount: d['guestCount'] ?? 1,
      date: ts?.toDate() ?? DateTime.now(),
      time: d['time'] ?? '',
      status: d['status'] ?? 'pending',
      sectionName: d['sectionName'] ?? '',
      cuisineLabel: d['cuisineLabel'] ?? '',
    );
  }

  String get formattedDate {
    const months = [
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni',
      'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];
    const days = [
      'Ponedjeljak', 'Utorak', 'Srijeda', 'Četvrtak',
      'Petak', 'Subota', 'Nedjelja',
    ];
    return '${days[date.weekday - 1]}, ${date.day}. ${months[date.month - 1]} ${date.year}.';
  }
}

// ─── Restaurant Bookings Page ─────────────────────────────────────────────────

class RestaurantBookingsPage extends StatefulWidget {
  const RestaurantBookingsPage({super.key});

  @override
  State<RestaurantBookingsPage> createState() =>
      _RestaurantBookingsPageState();
}

class _RestaurantBookingsPageState extends State<RestaurantBookingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Today's date at midnight (no time component) ───────────────────
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── Booking belongs to upcoming if its date >= today (midnight) ────
  bool _isUpcoming(BookingModel b) {
    final bookingDay = DateTime(b.date.year, b.date.month, b.date.day);
    return !bookingDay.isBefore(_today);
  }

  // ── Apply optional date filter ─────────────────────────────────────
  List<BookingModel> _applyDateFilter(List<BookingModel> bookings) {
    if (_selectedDate == null) return bookings;
    return bookings.where((b) {
      return b.date.year == _selectedDate!.year &&
          b.date.month == _selectedDate!.month &&
          b.date.day == _selectedDate!.day;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color(0xFF6B7C45),
            onPrimary: Colors.white,
            surface: Theme.of(context).colorScheme.surface,
            onSurface: Theme.of(context).textTheme.bodyLarge!.color!,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatFilterDate(DateTime d) =>
      '${d.day}.${d.month}.${d.year}.';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                        size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Rezervacije',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                ],
              ),
            ),

            // ── Date filter chip ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickDate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedDate != null
                            ? const Color(0xFF6B7C45)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedDate != null
                              ? const Color(0xFF6B7C45)
                              : const Color(0xFFCCD9B0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 14,
                              color: _selectedDate != null
                                  ? Colors.white
                                  : const Color(0xFF6B7C45)),
                          const SizedBox(width: 6),
                          Text(
                            _selectedDate != null
                                ? _formatFilterDate(_selectedDate!)
                                : 'Filtriraj po datumu',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _selectedDate != null
                                  ? Colors.white
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _selectedDate = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD94F4F).withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: Color(0xFFD94F4F)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tabs ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFCCD9B0), width: 1.2),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF6B7C45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      Theme.of(context).textTheme.bodySmall!.color,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Predstojeće'),
                    Tab(text: 'Historija'),
                    Tab(text: 'Lista čekanja')
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Content ────────────────────────────────────────────
            Expanded(
              child: uid == null
                  ? Center(
                      child: Text('Niste prijavljeni.',
                          style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .color)),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('bookings')
                          .where('userId', isEqualTo: uid)
                          .orderBy('date', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        // ── Loading ──────────────────────────────
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF6B7C45),
                                strokeWidth: 2.5),
                          );
                        }

                        // ── Error (shows instead of silent empty) ─
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 40,
                                      color: Color(0xFFD94F4F)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Greška pri učitavanju rezervacija.',
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  // Shows exact error — useful for spotting missing index
                                  Text(
                                    snapshot.error.toString(),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .color),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // ── Split into upcoming / history ─────────
                        final all = (snapshot.data?.docs ?? [])
                            .map((doc) =>
                                BookingModel.fromFirestore(doc))
                            .toList();

                        final upcoming = _applyDateFilter(
                            all.where(_isUpcoming).toList());
                        final history = _applyDateFilter(
                            all.where((b) => !_isUpcoming(b)).toList());

                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _BookingList(
                              bookings: upcoming,
                              emptyMessage: _selectedDate != null
                                  ? 'Nema rezervacija za odabrani datum.'
                                  : 'Nemate predstojeće rezervacije.',
                              uid: uid,
                            ),
                            _BookingList(
                              bookings: history,
                              emptyMessage: _selectedDate != null
                                  ? 'Nema rezervacija za odabrani datum.'
                                  : 'Nemate prošlih rezervacija.',
                              uid: uid,
                            ),
                            // -- _WaitlistTab(uid: uid ?? ''),
                            _WaitlistTab(uid: uid),
                          ],
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

// ─── Booking list ─────────────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String emptyMessage;
  final String? uid;

  const _BookingList(
      {required this.bookings, required this.emptyMessage, this.uid});
  
  bool _needsReviewPrompt(BookingModel b) {
    if (b.status != 'confirmed') return false;
    final bookingDateTime = DateTime(
      b.date.year,
      b.date.month,
      b.date.day,
    );
    return bookingDateTime.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 48, color: Color(0xFFCCD9B0)),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodySmall!.color),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final showPrompt = uid != null && _needsReviewPrompt(booking);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingDetailsPage(booking: booking),
                  ),
                ),
                child: _BookingCard(booking: booking),
              ),
              if (showPrompt)
                _ReviewPromptCard(booking: booking, uid: uid!),
            ],
          ),
        );
      },
    );
  }
}

// ─── Booking card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  String _name = '';
  String _imageUrl = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _name = widget.booking.restaurantName;
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    if (widget.booking.restaurantId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.booking.restaurantId)
          .get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _name = (d['name'] as String?) ?? widget.booking.restaurantName;
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

  Color _statusColor() {
    switch (widget.booking.status) {
      case 'confirmed': return const Color(0xFF4CAF50);
      case 'cancelled': return const Color(0xFFD94F4F);
      default:          return const Color(0xFFE8B84B);
    }
  }

  String _statusLabel() {
    switch (widget.booking.status) {
      case 'confirmed': return 'Potvrđeno';
      case 'cancelled': return 'Otkazano';
      default:          return 'Na čekanju';
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Container(
      padding: const EdgeInsets.all(16),
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
          // ── Restaurant image ───────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: _loading
                  ? Container(
                      color: const Color(0xFFD8E6C0),
                      child: const Center(
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Color(0xFF6B7C45),
                              strokeWidth: 2),
                        ),
                      ),
                    )
                  : _imageUrl.isNotEmpty
                      ? Image.network(_imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
            ),
          ),

          const SizedBox(width: 14),

          // ── Booking info ───────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _loading
                          ? Container(
                              height: 14, width: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8E6C0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          : Text(
                              _name.isNotEmpty ? _name : 'Nepoznat restoran',
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
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor().withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: Color(0xFF6B7C45)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${b.formattedDate}  ·  ${b.time}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 14, color: Color(0xFF6B7C45)),
                    const SizedBox(width: 6),
                    Text(
                      '${b.guestCount} ${b.guestCount == 1 ? 'gost' : 'gosta'}',
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
              ],
            ),
          ),

          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios,
              size: 14, color: Color(0xFF8A9A7A)),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFD8E6C0),
        child: const Center(
          child:
              Icon(Icons.restaurant, size: 24, color: Color(0xFF6B7C45)),
        ),
      );
}


// -- Review prompt card

class _ReviewPromptCard extends StatefulWidget {
  final BookingModel booking;
  final String uid;

  const _ReviewPromptCard({
    required this.booking,
    required this.uid,
  });

  @override 
  State<_ReviewPromptCard> createState() => _ReviewPromptCardState();
}

class _ReviewPromptCardState extends State<_ReviewPromptCard> {
  bool _hasReviewed = false;
  bool _dismissed = false;
  bool _loading = true;

  @override 
  void initState() {
    super.initState();
    _checkReview();
  }

  Future<void> _checkReview() async {
    try {
      final snap = await FirebaseFirestore.instance 
          .collection('restaurants')
          .doc(widget.booking.restaurantId)
          .collection('reviews')
          .where('userId', isEqualTo: widget.uid)
          .limit(1)
          .get();
      
      if (mounted) {
        setState(() {
          _hasReviewed = snap.docs.isNotEmpty;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override 
  Widget build(BuildContext context) {
    if (_loading || _hasReviewed || _dismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6B7C45).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6B7C45).withOpacity(0.25),
          width: 1.2
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 20,
            color: Color(0xFF6B7C45)
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kako vam je bilo?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge!.color
                  )
                ),
                const SizedBox(height: 2),
                Text(
                  'Ostavite recenziju za ${widget.booking.restaurantName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall!.color
                  )
                ),
              ]
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaveReviewPage(
                    restaurantId: widget.booking.restaurantId,
                    restaurantName: widget.booking.restaurantName,
                    restaurantAddress: widget.booking.restaurantAddress,
                    restaurantCuisine: widget.booking.cuisineLabel,
                  )
                )
              ).then((_) => _checkReview());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7C45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Ocijeni',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white
                )
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: const Icon(
              Icons.close,
              size: 16,
              color: Color(0xFF8A9A7A)
            ),
          ),
        ]
      ),
    );
  }
}


// -- Waitlist Tab

class _WaitlistTab extends StatelessWidget {
  final String uid;
  
  const _WaitlistTab({
    required this.uid,
  });

  @override 
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return Center(
        child: Text(
          'Niste prijavljeni.',
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).textTheme.bodySmall!.color
          )
        )
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('waitlist')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'waiting')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6B7C45),
              strokeWidth: 2.5
            )
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.hourglass_empty_outlined,
                  size: 48,
                  color: Color(0xFFCCD9B0)
                ),
                const SizedBox(height: 12),
                Text(
                  'Niste na nijednoj listi čekanja.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodySmall!.color
                  )
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final ts = d['date'] as Timestamp?;
            final date = ts?.toDate() ?? DateTime.now();

            const months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Jun',
              'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dec',
            ];
            
            final dateStr = '${date.day}. ${months[date.month - 1]} ${date.year}.';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE8B84B).withOpacity(0.3),
                  width: 1.2
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3)
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8B84B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_outlined,
                      size: 20,
                      color: Color(0xFFE8B84B)
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['restaurantName'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge!.color
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dateStr  ·  ${d['time'] ?? ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall!.color
                          )
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d['guesCount'] ?? 1} gosta'
                          '${(d['sectionName'] as String?)?.isNotEmpty == true ? '  ·  ${d['sectionName']}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall!.color
                          )
                        ),
                      ]
                    )
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _leaveWaitlist(context, docId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD94F4F).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Odustani',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD94F4F)
                        )
                      ),
                    ),
                  ),
                ]
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _leaveWaitlist(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance 
          .collection('waitlist').doc(docId)
          .update({'status': 'cancelled'});
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Greška pri otkazivanju.',
          ),
          backgroundColor: Color(0xFFD94F4F),
        )
      );
    }
  }
}