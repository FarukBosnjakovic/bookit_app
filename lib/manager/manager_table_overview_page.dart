import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Table status ─────────────────────────────────────────────────────────────

enum TableStatus { vacant, reserved }

// ─── Table model ──────────────────────────────────────────────────────────────

class RestaurantTable {
  final int number;
  TableStatus status;
  String? guestName;
  String? bookingId;
  int? guestCount;

  RestaurantTable({
    required this.number,
    required this.status,
    this.guestName,
    this.bookingId,
    this.guestCount,
  });
}

// ─── Table Overview Page ──────────────────────────────────────────────────────

class TableOverviewPage extends StatefulWidget {
  const TableOverviewPage({super.key});

  @override
  State<TableOverviewPage> createState() => _TableOverviewPageState();
}

class _TableOverviewPageState extends State<TableOverviewPage> {
  final List<String> _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00',
    '15:00', '16:00', '17:00', '18:00', '19:00', '20:00', '21:00', '22:00',
  ];

  Set<String> _selectedTimes = {};
  DateTime _selectedDate = DateTime.now();
  int _tableCount = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _bookingsForDate = [];
  List<Map<String, dynamic>> _sections = [];
  String? _selectedSectionId;
  String? _debugError;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    final currentSlot = '${now.hour.toString().padLeft(2, '0')}:00';
    _selectedTimes = {
      _timeSlots.contains(currentSlot) ? currentSlot : _timeSlots.first
    };
    _loadData();
  }

  // ── Load tableCount + bookings for selected date ───────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final restaurantId = userDoc.data()?['restaurantId'];
      if (restaurantId == null) {
        setState(() => _loading = false);
        return;
      }

      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();
      final tableCount =
          ((restaurantDoc.data()?['tableCount'] ?? 0) as num).toInt();

      final sectionsData = restaurantDoc.data()?['sections'];
      if (sectionsData is List) {
        _sections = sectionsData.map((e) {
          final data = Map<String, dynamic>.from(e as Map);
          data['id'] = data['id']?.toString();
          return data;
        }).toList();
      }

      setState(() => _tableCount = tableCount);

      final startOfDay = DateTime(
          _selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      var query = FirebaseFirestore.instance
          .collection('bookings')
          .where('restaurantId', isEqualTo: restaurantId)
          .where('status', isEqualTo: 'confirmed')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay));

      if (_selectedSectionId != null) {
        query = query.where('sectionId', isEqualTo: _selectedSectionId);
      }

      final bookingsSnap = await query.get();

      setState(() {
        _bookingsForDate = bookingsSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _debugError = e.toString();
        _loading = false;
      });
    }
  }

  // ── Resolve table numbers for the selected section ─────────────────
  //
  // Supports two storage formats:
  //   1. section['tables'] = [1, 2, 3, ...]  – explicit list
  //   2. section['tableCount'] = 10          – just a count; ranges are
  //      computed by walking the ordered section list cumulatively.
  //
  // If no section is selected, all tables (1 … _tableCount) are shown.
  List<int> get _tableNumbersForSection {
    if (_selectedSectionId == null) {
      return List.generate(_tableCount, (i) => i + 1);
    }

    final section = _sections.firstWhere(
      (s) => s['id'] == _selectedSectionId,
      orElse: () => {},
    );

    if (section.isEmpty) {
      return List.generate(_tableCount, (i) => i + 1);
    }

    // ── Format 1: explicit table-number list ──────────────────────────
    final rawTables = section['tables'];
    if (rawTables is List && rawTables.isNotEmpty) {
      return rawTables
          .map((e) {
            if (e is num) return e.toInt();
            if (e is String) return int.tryParse(e) ?? 0;
            return 0;
          })
          .where((n) => n > 0)
          .toList()
        ..sort();
    }

    // ── Format 2: tables (number) per section → compute range ────────
    // Walk sections in order to find the starting table number for each.
    int offset = 1;
    for (final s in _sections) {
      final count = ((s['tables'] ?? 0) as num).toInt();
      if (s['id'] == _selectedSectionId) {
        if (count <= 0) break;
        return List.generate(count, (i) => offset + i);
      }
      offset += count;
    }

    // ── Fallback: show all tables ─────────────────────────────────────
    return List.generate(_tableCount, (i) => i + 1);
  }

  // ── Build table list for selected time slot ────────────────────────
  List<RestaurantTable> get _tables {
    final slotBookings = _bookingsForDate.where((b) {
      final tableNum = b['tableNumber'];
      final time = b['time'] ?? '';
      return tableNum != null && _selectedTimes.contains(time);
    }).toList();

    final tableNumbers = _tableNumbersForSection;

    return tableNumbers.map((number) {
      final booking =
          slotBookings.cast<Map<String, dynamic>?>().firstWhere(
                (b) => b!['tableNumber'] == number,
                orElse: () => null,
              );
      return RestaurantTable(
        number: number,
        status:
            booking != null ? TableStatus.reserved : TableStatus.vacant,
        guestName: booking?['userName'],
        bookingId: booking?['id'],
        guestCount: booking?['guestCount'],
      );
    }).toList();
  }

  List<Map<String, dynamic>> get _unassignedBookings {
    return _bookingsForDate.where((b) {
      final time = b['time'] ?? '';
      final tableNum = b['tableNumber'];
      return _selectedTimes.contains(time) && tableNum == null;
    }).toList();
  }

  Future<void> _assignTable(String bookingId, int tableNumber) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'tableNumber': tableNumber});
    await _loadData();
  }

  Future<void> _unassignTable(String bookingId) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'tableNumber': FieldValue.delete()});
    await _loadData();
  }

  int get _vacantCount =>
      _tables.where((t) => t.status == TableStatus.vacant).length;
  int get _reservedCount =>
      _tables.where((t) => t.status == TableStatus.reserved).length;

  // ── Date label ─────────────────────────────────────────────────────
  String get _dateLabel {
    const months = [
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni',
      'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    if (_isSameDay(_selectedDate, now)) return 'Danas';
    if (_isSameDay(_selectedDate, tomorrow)) return 'Sutra';
    return '${_selectedDate.day}. ${months[_selectedDate.month - 1]} ${_selectedDate.year}.';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Open date picker ───────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      await _loadData();
    }
  }

  // ── Quick date chips ───────────────────────────────────────────────
  Widget _buildDateChips() {
    final now = DateTime.now();
    final dates = [
      now,
      now.add(const Duration(days: 1)),
      now.add(const Duration(days: 2)),
      now.add(const Duration(days: 3)),
    ];
    const labels = ['Danas', 'Sutra', '+2', '+3'];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: dates.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == dates.length) {
            return GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFCCD9B0), width: 1.2),
                ),
                child: const Icon(Icons.calendar_month_outlined,
                    size: 18, color: Color(0xFF6B7C45)),
              ),
            );
          }

          final date = dates[index];
          final isSelected = _isSameDay(_selectedDate, date);
          final hasBookings =
              _bookingsForDate.isNotEmpty && _isSameDay(_selectedDate, date);

          return GestureDetector(
            onTap: () async {
              if (!_isSameDay(_selectedDate, date)) {
                setState(() => _selectedDate = date);
                await _loadData();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6B7C45)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6B7C45)
                      : const Color(0xFFCCD9B0),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).textTheme.bodySmall!.color,
                    ),
                  ),
                  if (isSelected && hasBookings) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF6B7C45), strokeWidth: 2.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        color:
                            Theme.of(context).textTheme.bodyLarge!.color,
                        size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pregled stolova',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color,
                          ),
                        ),
                        Text(
                          _dateLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7C45),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadData,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7C45).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh,
                          size: 20, color: Color(0xFF6B7C45)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Date selector ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Text(
                'Odaberite datum',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                ),
              ),
            ),

            _buildDateChips(),

            if (_sections.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 10),
                child: Text(
                  'Odaberite sekciju',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFCCD9B0), width: 1.2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedSectionId,
                    isExpanded: true,
                    hint: const Text('Sve sekcije'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Sve sekcije')),
                      ..._sections.map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'] as String? ?? ''),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedSectionId = val);
                      _loadData();
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Time slot selector ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Text(
                'Odaberite termin',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                ),
              ),
            ),

            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _timeSlots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final time = _timeSlots[index];
                  final isSelected = _selectedTimes.contains(time);
                  final hasBookings =
                      _bookingsForDate.any((b) => b['time'] == time);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedTimes.contains(time)) {
                          // Ensure at least one time slot remains selected
                          if (_selectedTimes.length > 1) {
                            _selectedTimes.remove(time);
                          }
                        } else {
                          _selectedTimes.add(time);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6B7C45)
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6B7C45)
                              : const Color(0xFFCCD9B0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .color,
                            ),
                          ),
                          if (hasBookings) ...[
                            const SizedBox(width: 5),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFD94F4F),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Summary row ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _SummaryChip(
                    color: const Color(0xFF4CAF50),
                    label: '$_vacantCount slobodna',
                  ),
                  const SizedBox(width: 10),
                  _SummaryChip(
                    color: const Color(0xFFE8B84B),
                    label: '$_reservedCount rezervisana',
                  ),
                  const Spacer(),
                  if (_unassignedBookings.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8B84B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE8B84B).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_outlined,
                              size: 13, color: Color(0xFFE8B84B)),
                          const SizedBox(width: 4),
                          Text(
                            '${_unassignedBookings.length} nedodijeljeno',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE8B84B),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Legend ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _LegendItem(
                      color: const Color(0xFF4CAF50), label: 'Slobodan'),
                  const SizedBox(width: 16),
                  _LegendItem(
                      color: const Color(0xFFE8B84B),
                      label: 'Rezervisan'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── No tables configured ─────────────────────────────────
            if (_tableCount == 0)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.table_restaurant_outlined,
                          size: 48, color: Color(0xFFCCD9B0)),
                      const SizedBox(height: 12),
                      Text(
                        _debugError ?? 'Broj stolova nije podešen.',
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
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _tables.length,
                  itemBuilder: (context, index) {
                    return _TableCell(
                      table: _tables[index],
                      onTap: () => _showTableDetails(_tables[index]),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Table details bottom sheet ─────────────────────────────────────
  void _showTableDetails(RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final color = table.status == TableStatus.vacant
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE8B84B);
        final label =
            table.status == TableStatus.vacant ? 'Slobodan' : 'Rezervisan';

        return Padding(
          padding: const EdgeInsets.all(24),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Text(
                    'Stol ${table.number}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color:
                          Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (table.status == TableStatus.reserved) ...[
                _SheetRow(
                  icon: Icons.person_outline,
                  label: 'Gost',
                  value: table.guestName ?? 'Nepoznat',
                ),
                if (table.guestCount != null) ...[
                  const SizedBox(height: 10),
                  _SheetRow(
                    icon: Icons.people_outline,
                    label: 'Broj gostiju',
                    value: '${table.guestCount} osoba',
                  ),
                ],
                const SizedBox(height: 10),
                _SheetRow(
                  icon: Icons.access_time_outlined,
                  label: 'Termin',
                  value: _selectedTimes.join(', '),
                ),
                const SizedBox(height: 10),
                _SheetRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Datum',
                  value: _dateLabel,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (table.bookingId != null) {
                        await _unassignTable(table.bookingId!);
                      }
                    },
                    icon: const Icon(Icons.link_off,
                        size: 18, color: Color(0xFFD94F4F)),
                    label: const Text(
                      'Ukloni dodjelu stola',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFD94F4F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                          color: Color(0xFFD94F4F), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],

              if (table.status == TableStatus.vacant) ...[
                _SheetRow(
                  icon: Icons.check_circle_outline,
                  label: 'Status',
                  value: 'Slobodan za ${_selectedTimes.join(', ')}',
                  valueColor: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 16),

                if (_unassignedBookings.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7C45).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Color(0xFF6B7C45)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Nema nedodijeljenih rezervacija za ${_selectedTimes.join(', ')}, $_dateLabel.',
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
                  )
                else ...[
                  Text(
                    'Dodijeli rezervaciju ovom stolu:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          Theme.of(context).textTheme.bodySmall!.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._unassignedBookings.map((booking) {
                    final name =
                        booking['userName'] ?? 'Nepoznat gost';
                    final guests = booking['guestCount'] ?? 1;
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _assignTable(
                            booking['id'], table.number);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFCCD9B0), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 18, color: Color(0xFF6B7C45)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color,
                                    ),
                                  ),
                                  Text(
                                    '$guests osoba',
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
                  }),
                ],
              ],

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ─── Table cell ───────────────────────────────────────────────────────────────

class _TableCell extends StatelessWidget {
  final RestaurantTable table;
  final VoidCallback onTap;

  const _TableCell({required this.table, required this.onTap});

  Color get _color {
    switch (table.status) {
      case TableStatus.vacant:
        return const Color(0xFF4CAF50);
      case TableStatus.reserved:
        return const Color(0xFFE8B84B);
    }
  }

  IconData get _icon {
    switch (table.status) {
      case TableStatus.vacant:
        return Icons.table_restaurant_outlined;
      case TableStatus.reserved:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 20, color: _color),
            const SizedBox(height: 4),
            Text(
              '${table.number}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            ),
            if (table.guestName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  table.guestName!.split(' ').first,
                  style:
                      TextStyle(fontSize: 9, color: _color.withOpacity(0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary chip ─────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final Color color;
  final String label;

  const _SummaryChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Legend item ──────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall!.color,
          ),
        ),
      ],
    );
  }
}

// ─── Bottom sheet row ─────────────────────────────────────────────────────────

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SheetRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7C45)),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall!.color,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color:
                valueColor ?? Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
      ],
    );
  }
}