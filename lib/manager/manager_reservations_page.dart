import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:bookit/manager/manager_walkin_page.dart';
import 'package:bookit/points/bookit_points_page.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class ManagerReservationModel {
  final String id;
  final String guestName;
  final String guestPhone;
  final DateTime date;
  final String time;
  final int guestCount;
  final String status;
  final int? tableNumber;
  final String? sectionName;
  final String? sectionId;

  const ManagerReservationModel({
    required this.id,
    required this.guestName,
    required this.guestPhone,
    required this.date,
    required this.time,
    required this.guestCount,
    required this.status,
    this.tableNumber,
    this.sectionName,
    this.sectionId,
  });

  factory ManagerReservationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['date'] as Timestamp?;
    return ManagerReservationModel(
      id: doc.id,
      guestName: d['userName'] ?? 'Nepoznat gost',
      guestPhone: d['userPhone'] ?? '',
      date: ts?.toDate() ?? DateTime.now(),
      time: d['time'] ?? '',
      guestCount: d['guestCount'] ?? 1,
      status: d['status'] ?? 'pending',
      tableNumber: d['tableNumber'] as int?,
      sectionName: d['sectionName'] as String?,
      sectionId: d['sectionId'] as String?,
    );
  }

  String get formattedDate {
    const months = [
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni',
      'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];
    return '${date.day}. ${months[date.month - 1]} ${date.year}.';
  }
}

// ─── Section entry ────────────────────────────────────────────────────────────

class _SectionEntry {
  final String id;
  final String name;
  const _SectionEntry({required this.id, required this.name});
}

// ─── Manager Reservations Page ────────────────────────────────────────────────

class ManagerReservationsPage extends StatefulWidget {
  const ManagerReservationsPage({super.key});

  @override
  State<ManagerReservationsPage> createState() =>
      _ManagerReservationsPageState();
}

class _ManagerReservationsPageState extends State<ManagerReservationsPage> {
  String _selectedFilter = 'all';
  String? _selectedSectionId;
  String? _restaurantId;
  bool _loadingId = true;
  int _tableCount = 0;
  List<_SectionEntry> _sections = [];

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }

  Future<void> _loadRestaurantData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final restaurantId = userDoc.data()?['restaurantId'];

    int tableCount = 0;
    final sections = <_SectionEntry>[];

    if (restaurantId != null) {
      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants').doc(restaurantId).get();
      final d = restaurantDoc.data() ?? {};
      tableCount = ((d['tableCount'] ?? 0) as num).toInt();

      final sectionsData = d['sections'];
      if (sectionsData is List) {
        for (final s in sectionsData) {
          if (s is Map<String, dynamic>) {
            sections.add(_SectionEntry(
              id: s['id'] as String? ?? '',
              name: s['name'] as String? ?? '',
            ));
          }
        }
      }
    }

    setState(() {
      _restaurantId = restaurantId;
      _tableCount = tableCount;
      _sections = sections;
      _loadingId = false;
    });
  }

  Future<void> _acceptReservation(String bookingId) async {
    await FirebaseFirestore.instance
        .collection('bookings').doc(bookingId).update({'status': 'confirmed'});

    // Award points to the user
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings').doc(bookingId).get();
      final d = doc.data() as Map<String, dynamic>?;
      final userId = d?['userId'] as String? ?? '';
      final restaurantId = d?['restaurantId'] as String? ?? '';
      final restaurantName = d?['restaurantName'] as String? ?? '';
      if (userId.isNotEmpty && restaurantId.isNotEmpty) {
        await BookItPointsService.awardBookingPoints(
          userId: userId,
          restaurantId: restaurantId,
          restaurantName: restaurantName,
        );
      }
    } catch (_) {}
  }

  Future<void> _declineReservation(String bookingId) async {
    await FirebaseFirestore.instance
        .collection('bookings').doc(bookingId).update({'status': 'cancelled'});
  }

  Future<void> _assignTable(String bookingId, int tableNumber) async {
    await FirebaseFirestore.instance
        .collection('bookings').doc(bookingId).update({'tableNumber': tableNumber});
  }

  Future<void> _unassignTable(String bookingId) async {
    await FirebaseFirestore.instance
        .collection('bookings').doc(bookingId).update({'tableNumber': FieldValue.delete()});
  }

  bool _hasReservations(DateTime day, List<ManagerReservationModel> all) =>
      all.any((r) => isSameDay(r.date, day));

  List<ManagerReservationModel> _applyFilters(List<ManagerReservationModel> all) {
    var result = all.where((r) => isSameDay(r.date, _selectedDay)).toList();
    if (_selectedFilter != 'all') {
      result = result.where((r) => r.status == _selectedFilter).toList();
    }
    if (_selectedSectionId != null) {
      result = result.where((r) => r.sectionId == _selectedSectionId).toList();
    }
    return result;
  }

  String _formattedSelectedDay() {
    const months = [
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni',
      'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];
    final now = DateTime.now();
    if (isSameDay(_selectedDay, now)) return 'Danas';
    if (isSameDay(_selectedDay, now.add(const Duration(days: 1)))) return 'Sutra';
    return '${_selectedDay.day}. ${months[_selectedDay.month - 1]}';
  }

  // ── Table picker ─────────────────────────────────────────────────────────────

  void _showTablePicker(
    BuildContext context,
    ManagerReservationModel reservation,
    List<ManagerReservationModel> allForDay,
  ) {
    final takenTables = allForDay
        .where((r) =>
            r.time == reservation.time &&
            r.id != reservation.id &&
            r.tableNumber != null &&
            r.status == 'confirmed')
        .map((r) => r.tableNumber!)
        .toSet();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.85;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Fixed header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFCCD9B0),
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Dodijeli stol — ${reservation.guestName}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${reservation.time} · ${reservation.guestCount} osoba',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall!.color),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Scrollable body ───────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_tableCount == 0)
                        Text(
                          'Broj stolova nije podešen za ovaj restoran.',
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).textTheme.bodySmall!.color),
                        )
                      else ...[
                        // Unassign button
                        if (reservation.tableNumber != null) ...[
                          GestureDetector(
                            onTap: () async {
                              Navigator.pop(context);
                              await _unassignTable(reservation.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD94F4F).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFD94F4F).withOpacity(0.4),
                                    width: 1.2),
                              ),
                              child: const Row(children: [
                                Icon(Icons.link_off,
                                    size: 18, color: Color(0xFFD94F4F)),
                                SizedBox(width: 10),
                                Text('Ukloni dodjelu stola',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFD94F4F))),
                              ]),
                            ),
                          ),
                        ],

                        Text('Odaberite stol:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme.bodySmall!.color)),
                        const SizedBox(height: 10),

                        // Table grid — NeverScrollable since parent scrolls
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1),
                          itemCount: _tableCount,
                          itemBuilder: (context, index) {
                            final num = index + 1;
                            final isTaken = takenTables.contains(num);
                            final isCurrent = reservation.tableNumber == num;
                            Color color;
                            if (isCurrent) color = const Color(0xFF6B7C45);
                            else if (isTaken) color = const Color(0xFFD94F4F);
                            else color = const Color(0xFF4CAF50);

                            return GestureDetector(
                              onTap: isTaken && !isCurrent
                                  ? null
                                  : () async {
                                      Navigator.pop(context);
                                      await _assignTable(reservation.id, num);
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: color.withOpacity(
                                          isTaken && !isCurrent ? 0.3 : 0.6),
                                      width: 1.5),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isCurrent)
                                      const Icon(Icons.check,
                                          size: 14, color: Color(0xFF6B7C45)),
                                    Text('$num',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: color.withOpacity(
                                                isTaken && !isCurrent
                                                    ? 0.4 : 1.0))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Legend
                      Row(children: [
                        _dot(const Color(0xFF4CAF50)),
                        const SizedBox(width: 4),
                        Text('Slobodan',
                            style: TextStyle(fontSize: 11,
                                color: Theme.of(context).textTheme.bodySmall!.color)),
                        const SizedBox(width: 14),
                        _dot(const Color(0xFFD94F4F)),
                        const SizedBox(width: 4),
                        Text('Zauzet',
                            style: TextStyle(fontSize: 11,
                                color: Theme.of(context).textTheme.bodySmall!.color)),
                        const SizedBox(width: 14),
                        _dot(const Color(0xFF6B7C45)),
                        const SizedBox(width: 4),
                        Text('Trenutni',
                            style: TextStyle(fontSize: 11,
                                color: Theme.of(context).textTheme.bodySmall!.color)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot(Color color) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5)));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingId) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(
              color: Color(0xFF6B7C45), strokeWidth: 2.5)));
    }

    if (_restaurantId == null) {
      return Scaffold(
          body: Center(child: Text('Restoran nije pronađen.',
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall!.color))));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ManagerWalkInPage()
          )
        ),
        backgroundColor: const Color(0xFF6B7C45),
        icon: const Icon(
          Icons.add,
          color: Colors.white,
        ),
        label: const Text(
          'Walk-In',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('restaurantId', isEqualTo: _restaurantId)
              .orderBy('date', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            final allReservations = (snapshot.data?.docs ?? [])
                .map((doc) => ManagerReservationModel.fromFirestore(doc))
                .toList();

            final filtered = _applyFilters(allReservations);
            filtered.sort((a, b) {
              if (a.status == 'pending' && b.status != 'pending') return -1;
              if (a.status != 'pending' && b.status == 'pending') return 1;
              return a.time.compareTo(b.time);
            });

            final dayReservations = allReservations
                .where((r) => isSameDay(r.date, _selectedDay))
                .toList();
            final pendingCount =
                dayReservations.where((r) => r.status == 'pending').length;
            final confirmedCount =
                dayReservations.where((r) => r.status == 'confirmed').length;
            final cancelledCount =
                dayReservations.where((r) => r.status == 'cancelled').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Top bar ──────────────────────────────────────
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
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rezervacije',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme.bodyLarge!.color)),
                            Text(_formattedSelectedDay(),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7C45),
                                    fontWeight: FontWeight.w500)),
                          ]),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showCalendar = !_showCalendar),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _showCalendar
                              ? const Color(0xFF6B7C45)
                              : const Color(0xFF6B7C45).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_month_outlined,
                              size: 16,
                              color: _showCalendar
                                  ? Colors.white
                                  : const Color(0xFF6B7C45)),
                          const SizedBox(width: 5),
                          Text('Kalendar',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _showCalendar
                                      ? Colors.white
                                      : const Color(0xFF6B7C45))),
                        ]),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Calendar ─────────────────────────────────────
                if (_showCalendar) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: TableCalendar(
                        firstDay: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDay:
                            DateTime.now().add(const Duration(days: 365)),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                            _selectedFilter = 'all';
                          });
                        },
                        onPageChanged: (focusedDay) =>
                            setState(() => _focusedDay = focusedDay),
                        eventLoader: (day) =>
                            _hasReservations(day, allReservations)
                                ? [true]
                                : [],
                        calendarStyle: CalendarStyle(
                          selectedDecoration: const BoxDecoration(
                              color: Color(0xFF6B7C45),
                              shape: BoxShape.circle),
                          todayDecoration: BoxDecoration(
                              color: const Color(0xFF6B7C45).withOpacity(0.2),
                              shape: BoxShape.circle),
                          todayTextStyle: const TextStyle(
                              color: Color(0xFF6B7C45),
                              fontWeight: FontWeight.bold),
                          markerDecoration: const BoxDecoration(
                              color: Color(0xFFD94F4F),
                              shape: BoxShape.circle),
                          markerSize: 5,
                          markerMargin:
                              const EdgeInsets.symmetric(horizontal: 1),
                          defaultTextStyle: TextStyle(
                              color: Theme.of(context)
                                  .textTheme.bodyLarge!.color),
                          weekendTextStyle: TextStyle(
                              color: Theme.of(context)
                                  .textTheme.bodyLarge!.color),
                          outsideTextStyle: TextStyle(
                              color: Theme.of(context)
                                  .textTheme.bodySmall!.color),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme.bodyLarge!.color),
                          leftChevronIcon: Icon(Icons.chevron_left,
                              color: Theme.of(context)
                                  .textTheme.bodyLarge!.color),
                          rightChevronIcon: Icon(Icons.chevron_right,
                              color: Theme.of(context)
                                  .textTheme.bodyLarge!.color),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme.bodySmall!.color),
                          weekendStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme.bodySmall!.color),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Status filter chips ──────────────────────────
                SizedBox(
                  height: 38,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterTab(
                          label: 'Sve',
                          isSelected: _selectedFilter == 'all',
                          onTap: () =>
                              setState(() => _selectedFilter = 'all')),
                      const SizedBox(width: 8),
                      _FilterTab(
                          label: 'Na čekanju',
                          isSelected: _selectedFilter == 'pending',
                          color: const Color(0xFFE8B84B),
                          count: pendingCount,
                          onTap: () =>
                              setState(() => _selectedFilter = 'pending')),
                      const SizedBox(width: 8),
                      _FilterTab(
                          label: 'Potvrđeno',
                          isSelected: _selectedFilter == 'confirmed',
                          color: const Color(0xFF4CAF50),
                          count: confirmedCount,
                          onTap: () =>
                              setState(() => _selectedFilter = 'confirmed')),
                      const SizedBox(width: 8),
                      _FilterTab(
                          label: 'Otkazano',
                          isSelected: _selectedFilter == 'cancelled',
                          color: const Color(0xFFD94F4F),
                          count: cancelledCount,
                          onTap: () =>
                              setState(() => _selectedFilter = 'cancelled')),
                    ],
                  ),
                ),

                // ── Section filter chips ─────────────────────────
                if (_sections.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _SectionChip(
                          label: 'Sve sekcije',
                          isSelected: _selectedSectionId == null,
                          onTap: () =>
                              setState(() => _selectedSectionId = null),
                        ),
                        ..._sections.map((s) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _SectionChip(
                                label: s.name,
                                isSelected: _selectedSectionId == s.id,
                                onTap: () => setState(() =>
                                    _selectedSectionId =
                                        _selectedSectionId == s.id
                                            ? null
                                            : s.id),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Reservations list ────────────────────────────
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF6B7C45), strokeWidth: 2.5))
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.event_busy_outlined,
                                      size: 48, color: Color(0xFFCCD9B0)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedSectionId != null
                                        ? 'Nema rezervacija za odabranu sekciju.'
                                        : 'Nema rezervacija za ovaj dan.',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .textTheme.bodySmall!.color),
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
                              itemBuilder: (context, index) {
                                final r = filtered[index];
                                return _ReservationCard(
                                  reservation: r,
                                  restaurantId: _restaurantId!,
                                  onAccept: () => _acceptReservation(r.id),
                                  onDecline: () => _declineReservation(r.id),
                                  onAssignTable: r.status == 'confirmed'
                                      ? () => _showTablePicker(
                                          context, r, dayReservations)
                                      : null,
                                );
                              },
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

// ─── Section chip ─────────────────────────────────────────────────────────────

class _SectionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6B7C45).withOpacity(0.12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6B7C45)
                : const Color(0xFFCCD9B0),
            width: isSelected ? 1.5 : 1.2,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isSelected) ...[
            const Icon(Icons.chair_outlined,
                size: 13, color: Color(0xFF6B7C45)),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF6B7C45)
                    : Theme.of(context).textTheme.bodySmall!.color,
              )),
        ]),
      ),
    );
  }
}

// ─── Filter tab ───────────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final int? count;

  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color = const Color(0xFF6B7C45),
    this.count,
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
              width: 1.2),
        ),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodySmall!.color)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : color)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── Reservation card ─────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  final ManagerReservationModel reservation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onAssignTable;
  final String restaurantId;

  const _ReservationCard({
    required this.reservation,
    required this.onAccept,
    required this.onDecline,
    required this.restaurantId,
    this.onAssignTable,
  });

  Color _statusColor() {
    switch (reservation.status) {
      case 'pending':   return const Color(0xFFE8B84B);
      case 'confirmed': return const Color(0xFF4CAF50);
      case 'cancelled': return const Color(0xFFD94F4F);
      default:          return const Color(0xFF8A9A7A);
    }
  }

  String _statusLabel() {
    switch (reservation.status) {
      case 'pending':   return 'Na čekanju';
      case 'confirmed': return 'Potvrđeno';
      case 'cancelled': return 'Otkazano';
      default:          return reservation.status;
    }
  }

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
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF6B7C45).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(reservation.time,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7C45)))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reservation.guestName,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .textTheme.bodyLarge!.color)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 10, runSpacing: 4, children: [
                      _InfoChip(
                          icon: Icons.people_outline,
                          label: '${reservation.guestCount} gosta'),
                      _InfoChip(
                          icon: Icons.calendar_today_outlined,
                          label: reservation.formattedDate),
                      if (reservation.sectionName != null &&
                          reservation.sectionName!.isNotEmpty)
                        _InfoChip(
                            icon: Icons.chair_outlined,
                            label: reservation.sectionName!),
                    ]),
                    if (reservation.guestPhone.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.phone_outlined,
                            size: 13, color: Color(0xFF8A9A7A)),
                        const SizedBox(width: 4),
                        Text(reservation.guestPhone,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme.bodySmall!.color)),
                      ]),
                    ],
                    if (reservation.tableNumber != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.table_restaurant_outlined,
                            size: 13, color: Color(0xFF6B7C45)),
                        const SizedBox(width: 4),
                        Text('Stol ${reservation.tableNumber}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7C45))),
                      ]),
                    ],
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor())),
              ),
              if (onAssignTable != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onAssignTable,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: reservation.tableNumber != null
                          ? const Color(0xFF6B7C45).withOpacity(0.1)
                          : const Color(0xFFE8B84B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        reservation.tableNumber != null
                            ? Icons.table_restaurant
                            : Icons.table_restaurant_outlined,
                        size: 12,
                        color: reservation.tableNumber != null
                            ? const Color(0xFF6B7C45)
                            : const Color(0xFFE8B84B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        reservation.tableNumber != null
                            ? 'Promijeni'
                            : 'Dodijeli',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: reservation.tableNumber != null
                                ? const Color(0xFF6B7C45)
                                : const Color(0xFFE8B84B)),
                      ),
                    ]),
                  ),
                ),
              ],
            ]),
          ]),
        ),

        // if (reservation.status == 'confirmed')
        //   _WaitlistBadge(
        //     restaurantId: reservation.sectionId ?? '',
        //     date: reservation.date,
        //     time: reservation.time,
        //     sectionId: reservation.sectionId ?? '',
        //   ),
        
        if (reservation.status == 'confirmed')
          _WaitlistRow(
            restaurantId: restaurantId,
            date: reservation.date,
            time: reservation.time,
            sectionId: reservation.sectionId ?? '',
            sectionName: reservation.sectionName ?? '',
          ),

        if (reservation.status == 'pending')
          Container(
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: const Color(0xFFCCD9B0).withOpacity(0.6),
                        width: 1))),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onDecline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(14))),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close,
                              size: 16, color: Color(0xFFD94F4F)),
                          SizedBox(width: 6),
                          Text('Odbij',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD94F4F))),
                        ]),
                  ),
                ),
              ),
              Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFFCCD9B0).withOpacity(0.6)),
              Expanded(
                child: GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(14))),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check,
                              size: 16, color: Color(0xFF4CAF50)),
                          SizedBox(width: 6),
                          Text('Prihvati',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4CAF50))),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: const Color(0xFF8A9A7A)),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall!.color)),
    ]);
  }
}


// ─── Waitlist row (shown on confirmed reservation cards) ──────────────────────

class _WaitlistRow extends StatelessWidget {
  final String restaurantId;
  final DateTime date;
  final String time;
  final String sectionId;
  final String sectionName;

  const _WaitlistRow({
    required this.restaurantId,
    required this.date,
    required this.time,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('waitlist')
          .where('restaurantId', isEqualTo: restaurantId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .where('time', isEqualTo: time)
          .where('status', isEqualTo: 'waiting')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: const Color(0xFFCCD9B0).withOpacity(0.6),
                      width: 1))),
          child: InkWell(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => _WaitlistSheet(
                restaurantId: restaurantId,
                date: date,
                time: time,
                sectionId: sectionId,
                sectionName: sectionName,
                docs: snapshot.data?.docs ?? [],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.hourglass_empty_outlined,
                    size: 14, color: Color(0xFFE8B84B)),
                const SizedBox(width: 6),
                Text(
                  '$count ${count == 1 ? 'osoba čeka' : 'osoba čeka'} na listi',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE8B84B)),
                ),
                const Spacer(),
                const Text('Prikaži',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7C45),
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios,
                    size: 11, color: Color(0xFF6B7C45)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ─── Waitlist sheet ───────────────────────────────────────────────────────────

class _WaitlistSheet extends StatelessWidget {
  final String restaurantId;
  final DateTime date;
  final String time;
  final String sectionId;
  final String sectionName;
  final List<QueryDocumentSnapshot> docs;

  const _WaitlistSheet({
    required this.restaurantId,
    required this.date,
    required this.time,
    required this.sectionId,
    required this.sectionName,
    required this.docs,
  });

  Future<void> _promote(
      BuildContext context, QueryDocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    try {
      // Create confirmed booking
      await FirebaseFirestore.instance.collection('bookings').add({
        'restaurantId': restaurantId,
        'restaurantName': d['restaurantName'] ?? '',
        'userId': d['userId'] ?? '',
        'userName': d['userName'] ?? '',
        'userPhone': d['userPhone'] ?? '',
        'guestCount': d['guestCount'] ?? 1,
        'date': d['date'],
        'time': time,
        'sectionId': sectionId,
        'sectionName': sectionName,
        'status': 'confirmed',
        'source': 'waitlist',
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Mark waitlist entry as promoted
      await FirebaseFirestore.instance
          .collection('waitlist')
          .doc(doc.id)
          .update({'status': 'promoted'});

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gost je promoviran i rezervacija je potvrđena.'),
        backgroundColor: Color(0xFF4CAF50),
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Greška pri promociji gosta.'),
        backgroundColor: Color(0xFFD94F4F),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Maj', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dec',
    ];
    final dateStr = '${date.day}. ${months[date.month - 1]} ${date.year}.';

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCCD9B0),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Lista čekanja',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color)),
                Text('$dateStr  ·  $time${sectionName.isNotEmpty ? '  ·  $sectionName' : ''}',
                    style: TextStyle(fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall!.color)),
              ])),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B84B).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFE8B84B).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Color(0xFFE8B84B)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Tapsni "Potvrdi" da kreirate rezervaciju za gosta i uklonite ga s liste čekanja.',
                  style: TextStyle(fontSize: 12, height: 1.4,
                      color: Theme.of(context).textTheme.bodyMedium!.color),
                )),
              ]),
            ),
            const SizedBox(height: 16),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final d = docs[index].data() as Map<String, dynamic>;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCCD9B0)),
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8B84B).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('${index + 1}',
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE8B84B)))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(d['userName'] ?? 'Nepoznat',
                        style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme.bodyLarge!.color)),
                    if ((d['userPhone'] as String?)?.isNotEmpty == true)
                      Text(d['userPhone'],
                          style: TextStyle(fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme.bodySmall!.color)),
                    Text('${d['guestCount'] ?? 1} gosta',
                        style: TextStyle(fontSize: 12,
                            color: Theme.of(context)
                                .textTheme.bodySmall!.color)),
                  ])),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _promote(context, docs[index]),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7C45),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Potvrdi',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}