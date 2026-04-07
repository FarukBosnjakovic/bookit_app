import 'package:bookit/reservations/booking_confirmation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Section model ────────────────────────────────────────────────────────────

class SectionModel {
  final String id;
  final String name;
  final int tables;

  const SectionModel({
    required this.id,
    required this.name,
    required this.tables,
  });

  factory SectionModel.fromMap(Map<String, dynamic> map) {
    return SectionModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      tables: (map['tables'] as int?) ?? 0,
    );
  }
}

// ─── Make Reservation Page ────────────────────────────────────────────────────

class MakeReservationPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final String restaurantImageUrl;

  const MakeReservationPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    this.restaurantImageUrl = '',
  });

  @override
  State<MakeReservationPage> createState() => _MakeReservationPageState();
}

class _MakeReservationPageState extends State<MakeReservationPage> {
  int _guestCount = 2;
  DateTime? _selectedDate;
  String? _selectedTime;
  SectionModel? _selectedSection;
  bool _isSaving = false;

  // ── Phone number ───────────────────────────────────────────────────
  final _phoneController = TextEditingController();
  bool _phoneError = false;

  // ── Restaurant data ────────────────────────────────────────────────
  List<SectionModel> _sections = [];
  int _totalTables = 0;
  int _bookingDurationMinutes = 90;
  bool _loadingRestaurant = true;

  // ── Availability data ──────────────────────────────────────────────
  Map<String, Map<String, int>> _bookingCounts = {};
  bool _loadingAvailability = false;
  Set<String> _fullyBookedDates = {};
  Map<String, int> _waitlistCounts = {};
  Set<String> _userWaitlist = {};

  final List<String> _allTimes = [
    '12:00', '12:30', '13:00', '13:30',
    '14:00', '17:00', '17:30', '18:00',
    '18:30', '19:00', '19:30', '20:00',
    '20:30', '21:00', '21:30',
  ];

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
    _prefillPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Pre-fill phone if user already has one saved
  Future<void> _prefillPhone() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final phone = doc.data()?['phone'] as String?;
    if (phone != null && phone.isNotEmpty && mounted) {
      _phoneController.text = phone;
    }
  }

  Future<void> _loadRestaurant() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      final data = doc.data() ?? {};

      final sectionsData = data['sections'];
      final List<SectionModel> sections = [];
      if (sectionsData is List) {
        for (final s in sectionsData) {
          if (s is Map<String, dynamic>) {
            sections.add(SectionModel.fromMap(s));
          }
        }
      }

      final totalTables = (data['tableCount'] as int?) ?? 0;
      final duration = (data['bookingDurationMinutes'] as int?) ?? 90;

      if (mounted) {
        setState(() {
          _sections = sections;
          _totalTables = totalTables;
          _bookingDurationMinutes = duration;
          if (sections.length == 1) _selectedSection = sections.first;
          _loadingRestaurant = false;
        });
        await _loadAvailability();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRestaurant = false);
    }
  }

  Future<void> _loadAvailability() async {
    setState(() => _loadingAvailability = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 90));

      Query query = FirebaseFirestore.instance
          .collection('bookings')
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .where('status', whereIn: ['pending', 'confirmed'])
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to));

      if (_selectedSection != null) {
        query = query.where('sectionId', isEqualTo: _selectedSection!.id);
      }

      final snap = await query.get();

      final counts = <String, Map<String, int>>{};
      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final ts = d['date'] as Timestamp?;
        if (ts == null) continue;
        final dt = ts.toDate();
        final dateKey = _dateKey(dt);
        final time = d['time'] as String? ?? '';
        counts.putIfAbsent(dateKey, () => {});
        counts[dateKey]![time] = (counts[dateKey]![time] ?? 0) + 1;
      }

      final tableLimit = _selectedSection?.tables ?? _totalTables;
      final fullyBooked = <String>{};
      if (tableLimit > 0) {
        for (final dateKey in counts.keys) {
          final allSlotsFull = _allTimes.every((t) {
            final count = counts[dateKey]![t] ?? 0;
            return count >= tableLimit;
          });
          if (allSlotsFull) fullyBooked.add(dateKey);
        }
      }

      if (mounted) {
        setState(() {
          _bookingCounts = counts;
          _fullyBookedDates = fullyBooked;
          _loadingAvailability = false;
          if (_selectedDate != null && _selectedTime != null) {
            if (_isTimeFull(_selectedDate!, _selectedTime!)) {
              _selectedTime = null;
            }
          }
        });
        await _loadWaitlistCounts();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAvailability = false);
    }
  }

  Future<void> _loadWaitlistCounts() async {
    if (_selectedDate == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final date = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day
    );

    try {
      final snap = await FirebaseFirestore.instance 
          .collection('waitlists')
          .where('restaurantId', isEqualTo: widget.restaurantId)
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .where('status', isEqualTo: 'waiting')
          .get(); 
      
      final counts = <String, int>{};
      final userWaitList = <String>{};

      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final time = d['time'] as String? ?? '';

        if (time.isEmpty) continue;
        counts[time] = (counts[time] ?? 0) + 1;
        if (uid != null && d['userId'] == uid) userWaitList.add(time);
      }
      if (mounted) {
        setState(() {
          _waitlistCounts = counts;
          _userWaitlist = userWaitList;
        });
      } 
    } catch (_) {}
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  bool _isDateFull(DateTime date) =>
      _fullyBookedDates.contains(_dateKey(date));

  bool _isTimeFull(DateTime date, String time) {
    final tableLimit = _selectedSection?.tables ?? _totalTables;
    if (tableLimit <= 0) return false;

    final dateKey = _dateKey(date);
    final dayCounts = _bookingCounts[dateKey] ?? {};

    // Parse the requested time into minutes since midnight
    final reqMinutes = _timeToMinutes(time);
    if (reqMinutes == null) return false;

    // Count how many bookings overlap with this time slot
    int overlapping = 0;
    for (final entry in dayCounts.entries) {
      final slotMinutes = _timeToMinutes(entry.key);
      
      if (slotMinutes == null) continue;
      // A booking at slotMinutes occupies [slotMinutes, slotMinutes + duration]
      // It overlaps with reqMinutes if slotMinutes <= reqMinutes < slotMinutes + duration
      if (reqMinutes >= slotMinutes && reqMinutes < slotMinutes + _bookingDurationMinutes) {
        overlapping += entry.value;
      }
    }

    return overlapping >= tableLimit;
  }

  int? _timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      // return int.parse(parts[0] * 60 + int.parse(parts[1]))
      // return int.parse(parts[0] * 60 + (parts[1]));
      return int.parse(parts[0].trim()) * 60 + int.parse(parts[1].trim());
    } catch (_) {
      return null;
    }
  }

  int _remainingTables(DateTime date, String time) {
    final tableLimit = _selectedSection?.tables ?? _totalTables;
    if (tableLimit <= 0) return 0;

    final dateKey = _dateKey(date);
    final dayCounts = _bookingCounts[dateKey] ?? {};

    final reqMinutes = _timeToMinutes(time);
    if (reqMinutes == null) return tableLimit;

    int overlapping = 0;

    for (final entry in dayCounts.entries) {
      final slotMinutes = _timeToMinutes(entry.key);
      
      if (slotMinutes == null) continue;
      if (reqMinutes >= slotMinutes && reqMinutes < slotMinutes + _bookingDurationMinutes) {
        overlapping += entry.value;
      }
    }

    return (tableLimit - overlapping).clamp(0, tableLimit);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      selectableDayPredicate: (day) => !_isDateFull(day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF6B7C45),
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
      await _loadWaitlistCounts();
    }
  }

  String _formatDate(DateTime date) {
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

  bool get _phoneValid =>
      _phoneController.text.trim().length >= 6;

  bool get _canConfirm =>
      _selectedDate != null &&
      _selectedTime != null &&
      _guestCount > 0 &&
      (_sections.isEmpty || _selectedSection != null) &&
      _phoneValid;
  
  Future<void> _showWaitlistSheet(String time) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;
    if (_selectedDate == null) return;

    // Already on waitlist for this slot
    if (_userWaitlist.contains(time)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Već ste na listi čekanja za ovaj termin.'
          ),
          backgroundColor: Color(0xFFE8B84B),
        )
      );
      return;
    }

    final count = _waitlistCounts[time] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20)
        )
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCD9B0),
                  borderRadius: BorderRadius.circular(2)
                )
              )
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8B84B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: const Icon(
                    Icons.hourglass_empty_outlined,
                    size: 22,
                    color: Color(0xFFE8B84B)
                  )
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lista čekanja - $time',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color
                        )
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count > 0
                          ? '$count ${count == 1 ? 'osoba čeka' : 'osoba čeka'} ispred vas'
                          : 'Budite prvi na listi čekanja',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall!.color
                        )
                      ),
                    ]
                  )
                ),
              ]
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B84B).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE8B84B).withOpacity(0.3)
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 15,
                        color: Color(0xFFE8B84B)
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ako se mjesto oslobodi, menadžer restorana će vas kontaktirati.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Theme.of(context).textTheme.bodyMedium!.color
                          ),
                        )
                      ),
                    ]
                  ),
                ]
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _joinWaitlist(time);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7C45),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Pridruži se listi čekanja',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600
                  )
                ),
              ),
            ),
          ]
        ),
      ),
    );
  }

  Future<void> _joinWaitlist(String time) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _selectedDate == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userName = userDoc.data()?['name'] ?? 'Korisnik';
      final userPhone = _phoneController.text.trim().isNotEmpty
        ? _phoneController.text.trim()
        : (userDoc.data()?['phone'] ?? '');
      
      final date = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day
      );

      await FirebaseFirestore.instance.collection('waitlist').add({
        'restaurantId': widget.restaurantId,
        'restaurantName': widget.restaurantName,
        'restaurantAddress': widget.restaurantAddress,
        'userId': user.uid,
        'userName': userName,
        'userPhone': userPhone,
        'date': Timestamp.fromDate(date),
        'time': time,
        'sectionId': _selectedSection?.id ?? '',
        'sectionName': _selectedSection?.name ?? '',
        'guestCount': _guestCount,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() => _userWaitlist.add(time));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pridruži se listi čekanja'
          ),
          backgroundColor: Color(0xFF4CAF50),
        )
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Greška pri dodavanju na listu čekanja.'
          ),
          backgroundColor: Color(0xFFD94F4F),
        )
      );
    }
  }

  Future<void> _confirmReservation() async {
    // Validate phone before proceeding
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _phoneError = true);
      return;
    }
    if (!_canConfirm) return;

    setState(() {
      _isSaving = true;
      _phoneError = false;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Niste prijavljeni.');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 'Korisnik';
      final phone = _phoneController.text.trim();

      // Persist phone to user profile so it pre-fills next time
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'phone': phone});

      final date = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );

      final docRef =
          await FirebaseFirestore.instance.collection('bookings').add({
        'restaurantId': widget.restaurantId,
        'restaurantName': widget.restaurantName,
        'userId': user.uid,
        'userName': userName,
        'userPhone': phone,           // ← phone saved here
        'date': Timestamp.fromDate(date),
        'time': _selectedTime,
        'guestCount': _guestCount,
        'status': 'pending',
        'sectionId': _selectedSection?.id,
        'sectionName': _selectedSection?.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationPage(
            bookingId: docRef.id,
            restaurantName: widget.restaurantName,
            restaurantAddress: widget.restaurantAddress,
            date: _formatDate(_selectedDate!),
            dateTime: _selectedDate!,
            time: _selectedTime!,
            guestCount: _guestCount,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška: ${e.toString()}'),
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: (_canConfirm && !_isSaving) ? _confirmReservation : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B7C45),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCCD9B0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Potvrdi rezervaciju',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      size: 24),
                ),
                const SizedBox(width: 16),
                Text('Rezervacija',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color)),
              ]),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: _loadingRestaurant
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6B7C45), strokeWidth: 2.5))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Restaurant card ────────────────────────
                          _RestaurantCard(
                            name: widget.restaurantName,
                            address: widget.restaurantAddress,
                            imageUrl: widget.restaurantImageUrl,
                          ),

                          const SizedBox(height: 28),

                          // ── Section picker ─────────────────────────
                          if (_sections.isNotEmpty) ...[
                            _SectionLabel('Sekcija'),
                            const SizedBox(height: 4),
                            Text(
                              'Odaberite prostor u restoranu.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .color),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _sections.map((section) {
                                final selected =
                                    _selectedSection?.id == section.id;
                                return GestureDetector(
                                  onTap: () async {
                                    setState(() {
                                      _selectedSection = section;
                                      _selectedDate = null;
                                      _selectedTime = null;
                                    });
                                    await _loadAvailability();
                                  },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF6B7C45)
                                          : Theme.of(context)
                                              .colorScheme
                                              .surface,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? const Color(0xFF6B7C45)
                                            : const Color(0xFFCCD9B0),
                                        width: 1.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Icon(Icons.chair_outlined,
                                              size: 16,
                                              color: selected
                                                  ? Colors.white
                                                  : const Color(
                                                      0xFF6B7C45)),
                                          const SizedBox(width: 6),
                                          Text(section.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: selected
                                                    ? Colors.white
                                                    : Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color,
                                              )),
                                        ]),
                                        const SizedBox(height: 3),
                                        Text('${section.tables} stolova',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: selected
                                                  ? Colors.white
                                                      .withOpacity(0.8)
                                                  : Theme.of(context)
                                                      .textTheme
                                                      .bodySmall!
                                                      .color,
                                            )),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),
                          ],

                          // ── Guest count ────────────────────────────
                          _SectionLabel('Broj gostiju'),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$_guestCount ${_guestCount == 1 ? 'gost' : 'gosta'}',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color),
                                ),
                                Row(children: [
                                  _CounterBtn(
                                    icon: Icons.remove,
                                    enabled: _guestCount > 1,
                                    onTap: () =>
                                        setState(() => _guestCount--),
                                  ),
                                  const SizedBox(width: 16),
                                  _CounterBtn(
                                    icon: Icons.add,
                                    enabled: _guestCount < 20,
                                    onTap: () =>
                                        setState(() => _guestCount++),
                                  ),
                                ]),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Phone number ───────────────────────────
                          _SectionLabel('Kontakt telefon'),
                          const SizedBox(height: 4),
                          Text(
                            'Restoran će vas kontaktirati na ovaj broj.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-\s()]')),
                            ],
                            onChanged: (_) => setState(() {
                              _phoneError = false;
                            }),
                            style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color),
                            decoration: InputDecoration(
                              hintText: 'npr. +387 61 123 456',
                              hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .color),
                              prefixIcon: const Icon(
                                  Icons.phone_outlined,
                                  color: Color(0xFF6B7C45),
                                  size: 20),
                              errorText: _phoneError
                                  ? 'Unesite broj telefona'
                                  : null,
                              errorStyle: const TextStyle(
                                  color: Color(0xFFD94F4F), fontSize: 12),
                              filled: true,
                              fillColor:
                                  Theme.of(context).colorScheme.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: _phoneError
                                        ? const Color(0xFFD94F4F)
                                        : const Color(0xFFCCD9B0),
                                    width: 1.4),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFF6B7C45), width: 1.8),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD94F4F), width: 1.4),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD94F4F), width: 1.8),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Date ───────────────────────────────────
                          _SectionLabel('Datum'),
                          if (_sections.isNotEmpty &&
                              _selectedSection == null) ...[
                            const SizedBox(height: 8),
                            _InfoNote(
                                'Odaberite sekciju kako biste vidjeli dostupnost.'),
                          ] else ...[
                            const SizedBox(height: 14),
                            _loadingAvailability
                                ? const Center(
                                    child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF6B7C45),
                                        strokeWidth: 2),
                                  ))
                                : GestureDetector(
                                    onTap: _pickDate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: _selectedDate != null
                                              ? const Color(0xFF6B7C45)
                                              : const Color(0xFFCCD9B0),
                                          width: 1.4,
                                        ),
                                      ),
                                      child: Row(children: [
                                        const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 20,
                                            color: Color(0xFF6B7C45)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedDate != null
                                                ? _formatDate(
                                                    _selectedDate!)
                                                : 'Odaberite datum',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: _selectedDate != null
                                                  ? Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge!
                                                      .color
                                                  : Theme.of(context)
                                                      .textTheme
                                                      .bodySmall!
                                                      .color,
                                            ),
                                          ),
                                        ),
                                        if (_fullyBookedDates.isNotEmpty)
                                          Row(children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration:
                                                  const BoxDecoration(
                                                      color: Color(
                                                          0xFFD94F4F),
                                                      shape:
                                                          BoxShape.circle),
                                            ),
                                            const SizedBox(width: 4),
                                            Text('Neka su popunjena',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall!
                                                        .color)),
                                          ]),
                                      ]),
                                    ),
                                  ),
                          ],

                          const SizedBox(height: 28),

                          // ── Time slots ─────────────────────────────
                          _SectionLabel('Vrijeme'),
                          const SizedBox(height: 14),
                          if (_selectedDate == null)
                            _InfoNote(
                                'Odaberite datum kako biste vidjeli slobodna vremena.')
                          else
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _allTimes.map((time) {
                                final full =
                                    _isTimeFull(_selectedDate!, time);
                                final remaining =
                                    _remainingTables(_selectedDate!, time);
                                final selected = time == _selectedTime;

                                return GestureDetector(
                                  onTap: full
                                      ? () => _showWaitlistSheet(time)
                                      : () => setState(
                                          () => _selectedTime = time),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: full
                                          ? Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withOpacity(0.5)
                                          : selected
                                              ? const Color(0xFF6B7C45)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: full
                                            ? const Color(0xFFCCD9B0)
                                                .withOpacity(0.5)
                                            : selected
                                                ? const Color(0xFF6B7C45)
                                                : const Color(0xFFCCD9B0),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Column(children: [
                                      Text(
                                        time,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: full
                                              ? Theme.of(context)
                                                  .textTheme
                                                  .bodySmall!
                                                  .color!
                                                  .withOpacity(0.4)
                                              : selected
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge!
                                                      .color,
                                        ),
                                      ),
                                      if (full)
                                        Text(
                                          _userWaitlist.contains(time)
                                            ? 'Na čekanju'
                                            : 'Popunjeno',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: _userWaitlist.contains(time)
                                              ? const Color(0xFFE8B84B)
                                              : const Color(0xFFD94F4F).withOpacity(0.6)
                                          ),
                                        )
                                      else if (_totalTables > 0 &&
                                          remaining < _totalTables &&
                                          !selected)
                                        Text('$remaining slobodno',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: remaining <= 2
                                                    ? const Color(
                                                        0xFFE8B84B)
                                                    : const Color(
                                                        0xFF4CAF50))),
                                    ]),
                                  ),
                                );
                              }).toList(),
                            ),

                          const SizedBox(height: 100),
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

// ─── Small widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color));
  }
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 14, color: Color(0xFF8A9A7A)),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall!.color)),
      ]),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _CounterBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF6B7C45)
              : const Color(0xFFCCD9B0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final String name;
  final String address;
  final String imageUrl;
  const _RestaurantCard(
      {required this.name, required this.address, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFD8E6C0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.restaurant,
                          size: 28,
                          color: Color(0xFF6B7C45))),
                )
              : const Icon(Icons.restaurant,
                  size: 28, color: Color(0xFF6B7C45)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(address,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
        ),
      ]),
    );
  }
}