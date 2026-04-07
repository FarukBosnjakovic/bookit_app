import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerAnalyticsPage extends StatefulWidget {
  const ManagerAnalyticsPage({super.key});

  @override
  State<ManagerAnalyticsPage> createState() => _ManagerAnalyticsPageState();
}

class _ManagerAnalyticsPageState extends State<ManagerAnalyticsPage> {
  bool _loading = true;
  int _selectedDays = 30;

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _reviews = [];

  bool _isPremium = false;
  bool _hasPendingRequest = false;
  String? _restaurantId;
  String _restaurantName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }

    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final restaurantId = userDoc.data()?['restaurantId'];
    if (restaurantId == null) { setState(() => _loading = false); return; }

    final restaurantDoc = await FirebaseFirestore.instance
        .collection('restaurants').doc(restaurantId).get();
    final isPremium = restaurantDoc.data()?['isPremium'] == true;
    final restaurantName = restaurantDoc.data()?['name'] ?? '';

    // Check for pending premium request
    bool hasPendingRequest = false;
    if (!isPremium) {
      final requestSnap = await FirebaseFirestore.instance
          .collection('premiumRequests')
          .where('restaurantId', isEqualTo: restaurantId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      hasPendingRequest = requestSnap.docs.isNotEmpty;
    }

    if (!isPremium) {
      setState(() {
        _restaurantId = restaurantId;
        _restaurantName = restaurantName;
        _isPremium = false;
        _hasPendingRequest = hasPendingRequest;
        _loading = false;
      });
      return;
    }

    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('bookings')
          .where('restaurantId', isEqualTo: restaurantId)
          .get(),
      FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .collection('reviews')
          .get(),
    ]);

    setState(() {
      _restaurantId = restaurantId;
      _restaurantName = restaurantName;
      _isPremium = true;
      _bookings = results[0].docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      _reviews = results[1].docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      _loading = false;
    });
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) {
      try { return DateTime.parse(val); } catch (_) { return null; }
    }
    return null;
  }

  List<Map<String, dynamic>> get _filteredBookings {
    final cutoff = DateTime.now().subtract(Duration(days: _selectedDays));
    return _bookings.where((b) {
      final date = _parseDate(b['date']);
      return date != null && date.isAfter(cutoff);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredReviews {
    final cutoff = DateTime.now().subtract(Duration(days: _selectedDays));
    return _reviews.where((r) {
      final ts = r['createdAt'];
      if (ts is Timestamp) return ts.toDate().isAfter(cutoff);
      return false;
    }).toList();
  }

  int get _totalBookings => _filteredBookings.length;
  int get _confirmedCount =>
      _filteredBookings.where((b) => b['status'] == 'confirmed').length;
  int get _cancelledCount =>
      _filteredBookings.where((b) => b['status'] == 'cancelled').length;
  int get _pendingCount =>
      _filteredBookings.where((b) => b['status'] == 'pending').length;

  Map<String, int> get _dayOfWeekCounts {
    const days = ['Pon', 'Uto', 'Sri', 'Čtv', 'Pet', 'Sub', 'Ned'];
    final map = {for (var d in days) d: 0};
    for (final b in _filteredBookings) {
      if (b['status'] == 'cancelled') continue;
      final date = _parseDate(b['date']);
      if (date == null) continue;
      final day = days[date.weekday - 1];
      map[day] = (map[day] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get _timeSlotCounts {
    final map = <String, int>{};
    for (final b in _filteredBookings) {
      if (b['status'] == 'cancelled') continue;
      final time = b['time'] as String? ?? '';
      if (time.isEmpty) continue;
      map[time] = (map[time] ?? 0) + 1;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Map<String, int> get _sectionCounts {
    final map = <String, int>{};
    for (final b in _filteredBookings) {
      if (b['status'] == 'cancelled') continue;
      final section = b['sectionName'] as String? ?? 'Nepoznato';
      map[section] = (map[section] ?? 0) + 1;
    }
    return map;
  }

  double get _averageRating {
    if (_filteredReviews.isEmpty) return 0;
    final total = _filteredReviews.fold<double>(
        0, (sum, r) => sum + ((r['rating'] ?? 0) as num).toDouble());
    return total / _filteredReviews.length;
  }

  // ── Locked screen ─────────────────────────────────────────────────────────

  Widget _buildLockedScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero icon
          Center(
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF6B7C45).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_outlined,
                  size: 44, color: Color(0xFF6B7C45)),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text('Analitika',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Dostupno uz Premium paket',
                style: const TextStyle(fontSize: 14,
                    color: Color(0xFF6B7C45), fontWeight: FontWeight.w600)),
          ),

          const SizedBox(height: 32),

          // Feature list
          _FeatureRow(
            icon: Icons.calendar_month_outlined,
            title: 'Pregled rezervacija',
            subtitle:
                'Ukupno, potvrđeno, otkazano i na čekanju u odabranom periodu.',
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.bar_chart_outlined,
            title: 'Najprometniji dani i termini',
            subtitle:
                'Saznajte kada su gosti najaktivniji kako biste optimizirali osoblje.',
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.chair_outlined,
            title: 'Zauzetost po sekcijama',
            subtitle: 'Pratite koje sekcije su najpopularnije i zašto.',
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.star_outline,
            title: 'Analiza recenzija',
            subtitle:
                'Prosječna ocjena i distribucija zvjezdica u odabranom periodu.',
          ),

          const SizedBox(height: 36),

          // CTA or pending state
          if (_hasPendingRequest) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B84B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFE8B84B).withOpacity(0.4),
                    width: 1.2),
              ),
              child: Column(children: [
                const Icon(Icons.hourglass_empty_outlined,
                    size: 28, color: Color(0xFFE8B84B)),
                const SizedBox(height: 10),
                Text('Zahtjev je poslan',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color)),
                const SizedBox(height: 6),
                Text(
                  'Vaš zahtjev za Premium paket je na čekanju. Kontaktiraćemo vas uskoro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context).textTheme.bodySmall!.color),
                ),
              ]),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => _showRequestForm(),
                icon: const Icon(Icons.workspace_premium_outlined,
                    color: Colors.white, size: 20),
                label: const Text('Zatraži Premium',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7C45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Bez automatske naplate. Kontaktiraćemo vas sa detaljima.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall!.color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRequestForm() {
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final messageController = TextEditingController();
    bool submitting = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFCCD9B0),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                Text('Zatraži Premium paket',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color)),
                const SizedBox(height: 6),
                Text('Popunite formu i kontaktiraćemo vas sa detaljima.',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Theme.of(context).textTheme.bodySmall!.color)),

                const SizedBox(height: 24),

                // Restaurant (read-only)
                _FormLabel('Restoran'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFCCD9B0), width: 1.2),
                  ),
                  child: Row(children: [
                    const Icon(Icons.storefront_outlined,
                        size: 18, color: Color(0xFF6B7C45)),
                    const SizedBox(width: 10),
                    Text(_restaurantName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color)),
                  ]),
                ),

                const SizedBox(height: 16),

                _FormLabel('Kontakt osoba'),
                const SizedBox(height: 6),
                _SheetField(
                  controller: contactController,
                  hint: 'Ime i prezime',
                  icon: Icons.person_outline,
                ),

                const SizedBox(height: 16),

                _FormLabel('Broj telefona'),
                const SizedBox(height: 6),
                _SheetField(
                  controller: phoneController,
                  hint: '+387 xx xxx xxx',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 16),

                _FormLabel('Poruka (opcionalno)'),
                const SizedBox(height: 6),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  style: TextStyle(
                      fontSize: 14,
                      color:
                          Theme.of(context).textTheme.bodyLarge!.color),
                  decoration: InputDecoration(
                    hintText: 'Kratka napomena ili pitanje...',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFCCD9B0), width: 1.2)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF6B7C45), width: 1.8)),
                  ),
                ),

                if (error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94F4F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFFD94F4F).withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          size: 15, color: Color(0xFFD94F4F)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(error!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFD94F4F)))),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (contactController.text.trim().isEmpty) {
                              setSheetState(() =>
                                  error = 'Unesite kontakt osobu.');
                              return;
                            }
                            if (phoneController.text.trim().isEmpty) {
                              setSheetState(() =>
                                  error = 'Unesite broj telefona.');
                              return;
                            }

                            setSheetState(() {
                              submitting = true;
                              error = null;
                            });

                            try {
                              await FirebaseFirestore.instance
                                  .collection('premiumRequests')
                                  .add({
                                'restaurantId': _restaurantId,
                                'restaurantName': _restaurantName,
                                'contactName':
                                    contactController.text.trim(),
                                'phone': phoneController.text.trim(),
                                'message': messageController.text.trim(),
                                'status': 'pending',
                                'createdAt':
                                    FieldValue.serverTimestamp(),
                              });

                              if (!mounted) return;
                              Navigator.pop(context);
                              setState(() => _hasPendingRequest = true);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Zahtjev je uspješno poslan!'),
                                  backgroundColor: Color(0xFF4CAF50),
                                ),
                              );
                            } catch (_) {
                              setSheetState(() {
                                submitting = false;
                                error =
                                    'Greška pri slanju zahtjeva. Pokušajte ponovo.';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7C45),
                      disabledBackgroundColor: const Color(0xFFCCD9B0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: submitting
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Pošalji zahtjev',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF6B7C45), strokeWidth: 2.5))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.06),
                                  blurRadius: 4)
                            ],
                          ),
                          child: Icon(Icons.arrow_back,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color,
                              size: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text('Analitika',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color)),
                      ),
                      InkWell(
                        onTap: _loadData,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7C45)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.refresh,
                              size: 18, color: Color(0xFF6B7C45)),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Period selector (hidden on locked screen) ───
                  if (_isPremium)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        _PeriodChip(
                          label: '7 dana',
                          selected: _selectedDays == 7,
                          onTap: () =>
                              setState(() => _selectedDays = 7),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: '30 dana',
                          selected: _selectedDays == 30,
                          onTap: () =>
                              setState(() => _selectedDays = 30),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: '90 dana',
                          selected: _selectedDays == 90,
                          onTap: () =>
                              setState(() => _selectedDays = 90),
                        ),
                      ]),
                    ),

                  if (_isPremium) const SizedBox(height: 20),

                  // ── Content ────────────────────────────────────
                  Expanded(
                    child: !_isPremium
                        ? _buildLockedScreen()
                        : _filteredBookings.isEmpty &&
                                _filteredReviews.isEmpty
                            ? _EmptyState(days: _selectedDays)
                            : LayoutBuilder(
                                builder: (context, constraints) =>
                                    SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 0, 20, 32),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionLabel(
                                            'Pregled rezervacija'),
                                        const SizedBox(height: 10),
                                        _SummaryGrid(
                                          total: _totalBookings,
                                          confirmed: _confirmedCount,
                                          cancelled: _cancelledCount,
                                          pending: _pendingCount,
                                        ),
                                        if (_dayOfWeekCounts.values
                                            .any((v) => v > 0)) ...[
                                          const SizedBox(height: 24),
                                          _SectionLabel(
                                              'Najprometniji dani'),
                                          const SizedBox(height: 10),
                                          _BarChart(
                                              data: _dayOfWeekCounts,
                                              color: const Color(
                                                  0xFF6B7C45)),
                                        ],
                                        if (_timeSlotCounts
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 24),
                                          _SectionLabel(
                                              'Najprometniji termini'),
                                          const SizedBox(height: 10),
                                          _BarChart(
                                              data: _timeSlotCounts,
                                              color: const Color(
                                                  0xFF4A6FA5)),
                                        ],
                                        if (_sectionCounts
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 24),
                                          _SectionLabel(
                                              'Zauzetost po sekcijama'),
                                          const SizedBox(height: 10),
                                          _HorizontalBars(
                                              data: _sectionCounts),
                                        ],
                                        const SizedBox(height: 24),
                                        _SectionLabel(
                                            'Recenzije u periodu'),
                                        const SizedBox(height: 10),
                                        _RatingCard(
                                            reviews: _filteredReviews,
                                            average: _averageRating),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Period chip ──────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6B7C45)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? const Color(0xFF6B7C45)
                  : const Color(0xFFCCD9B0),
              width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .color)),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge!.color));
}

// ─── Summary grid ─────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final int total, confirmed, cancelled, pending;

  const _SummaryGrid({
    required this.total,
    required this.confirmed,
    required this.cancelled,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Ukupno',
        value: total,
        color: const Color(0xFF6B7C45),
        icon: Icons.calendar_month_outlined
      ),
      (
        label: 'Potvrđeno',
        value: confirmed,
        color: const Color(0xFF4CAF50),
        icon: Icons.check_circle_outline
      ),
      (
        label: 'Otkazano',
        value: cancelled,
        color: const Color(0xFFD94F4F),
        icon: Icons.cancel_outlined
      ),
      (
        label: 'Na čekanju',
        value: pending,
        color: const Color(0xFFE8B84B),
        icon: Icons.hourglass_empty_outlined
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      children: items
          .map((item) => _StatBox(
                label: item.label,
                value: '${item.value}',
                color: item.color,
                icon: item.icon,
              ))
          .toList(),
    );
  }
}

// ─── Stat box ─────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _StatBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Vertical bar chart ───────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final Map<String, int> data;
  final Color color;

  const _BarChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.entries.map((e) {
              final frac = maxVal == 0 ? 0.0 : e.value / maxVal;
              final isMax = e.value == maxVal && maxVal > 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (e.value > 0)
                        Text('${e.value}',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isMax
                                    ? color
                                    : Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .color)),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        height: frac * 90,
                        decoration: BoxDecoration(
                          color: isMax
                              ? color
                              : color.withOpacity(0.35),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFECF2DF)),
        const SizedBox(height: 6),
        Row(
          children: data.keys
              .map((label) => Expanded(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color)),
                  ))
              .toList(),
        ),
      ]),
    );
  }
}

// ─── Horizontal bars ─────────────────────────────────────────────────────────

class _HorizontalBars extends StatelessWidget {
  final Map<String, int> data;
  const _HorizontalBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final frac = maxVal == 0 ? 0.0 : e.value / maxVal;
          final isLast = i == sorted.length - 1;
          return Column(children: [
            Row(children: [
              SizedBox(
                  width: 90,
                  child: Text(e.key,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color),
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFECF2DF),
                    valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF6B7C45)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${e.value}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7C45))),
            ]),
            if (!isLast) const SizedBox(height: 12),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─── Rating card ──────────────────────────────────────────────────────────────

class _RatingCard extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final double average;
  const _RatingCard({required this.reviews, required this.average});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Text('Nema recenzija u odabranom periodu.',
            style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).textTheme.bodySmall!.color)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(average.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7C45))),
          Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                      i < average.round()
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: const Color(0xFFE8B84B)))),
          const SizedBox(height: 4),
          Text('${reviews.length} recenzija',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .color)),
        ]),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
              children: List.generate(5, (i) {
            final star = 5 - i;
            final count = reviews
                .where((r) =>
                    ((r['rating'] ?? 0) as num).round() == star)
                .length;
            final frac =
                reviews.isEmpty ? 0.0 : count / reviews.length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Text('$star',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color)),
                const SizedBox(width: 4),
                const Icon(Icons.star,
                    size: 11, color: Color(0xFFE8B84B)),
                const SizedBox(width: 6),
                Expanded(
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFECF2DF),
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFE8B84B))))),
                const SizedBox(width: 6),
                Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color)),
              ]),
            );
          })),
        ),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final int days;
  const _EmptyState({required this.days});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF6B7C45).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bar_chart_outlined,
              size: 48, color: Color(0xFF6B7C45)),
        ),
        const SizedBox(height: 16),
        Text('Nema podataka za posljednjih $days dana.',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color:
                    Theme.of(context).textTheme.bodyLarge!.color)),
        const SizedBox(height: 6),
        Text('Podaci će se pojaviti čim se rezervacije kreiraju.',
            style: TextStyle(
                fontSize: 12,
                color:
                    Theme.of(context).textTheme.bodySmall!.color)),
      ]),
    );
  }
}

// ─── Feature row (locked screen) ─────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF6B7C45).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF6B7C45)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color)),
            ]),
      ),
    ]);
  }
}

// ─── Form label ───────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String label;
  const _FormLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodySmall!.color));
}

// ─── Sheet input field ────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _SheetField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyLarge!.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodySmall!.color),
        prefixIcon:
            Icon(icon, size: 18, color: const Color(0xFF6B7C45)),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFFCCD9B0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF6B7C45), width: 1.8)),
      ),
    );
  }
}