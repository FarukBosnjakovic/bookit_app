import 'package:bookit/manager/manager_menu_page.dart';
import 'package:bookit/manager/manager_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bookit/manager/manager_reservations_page.dart';
import 'package:bookit/manager/manager_restaurant_profile_page.dart';
import 'package:bookit/manager/manager_table_overview_page.dart';
import 'package:bookit/manager/manager_walkin_page.dart';

// ─── Breakpoint ───────────────────────────────────────────────────────────────

bool _isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 900;

// ─── Models ───────────────────────────────────────────────────────────────────

class SectionInfo {
  final String id;
  final String name;
  final int tables;
  const SectionInfo(
      {required this.id, required this.name, required this.tables});
}

class DashboardStatsModel {
  final int totalToday;
  final int pending;
  final int confirmed;
  final int cancelled;
  final int totalTables;

  const DashboardStatsModel({
    required this.totalToday,
    required this.pending,
    required this.confirmed,
    required this.cancelled,
    required this.totalTables,
  });
}

class RecentReservationModel {
  final String id;
  final String guestName;
  final String time;
  final int guestCount;
  final String status;
  final String? sectionName;

  const RecentReservationModel({
    required this.id,
    required this.guestName,
    required this.time,
    required this.guestCount,
    required this.status,
    this.sectionName,
  });

  factory RecentReservationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RecentReservationModel(
      id: doc.id,
      guestName: d['userName'] ?? 'Nepoznat gost',
      time: d['time'] ?? '',
      guestCount: d['guestCount'] ?? 1,
      status: d['status'] ?? 'pending',
      sectionName: d['sectionName'] as String?,
    );
  }
}

// ─── Nav items ────────────────────────────────────────────────────────────────

const _navLabels = [
  'Pregled', 'Rezervacije', 'Stolovi', 'Jelovnik', 'Restoran', 'Profil',
];
const _navIcons = [
  Icons.dashboard_outlined,
  Icons.book_online_outlined,
  Icons.table_restaurant_outlined,
  Icons.restaurant_menu_outlined,
  Icons.storefront_outlined,
  Icons.person_outline,
];
const _navIconsSelected = [
  Icons.dashboard,
  Icons.book_online,
  Icons.table_restaurant,
  Icons.restaurant_menu,
  Icons.storefront,
  Icons.person,
];

Widget _pageForIndex(int index) {
  switch (index) {
    case 1: return const ManagerReservationsPage();
    case 2: return const TableOverviewPage();
    case 3: return const ManagerMenuPage();
    case 4: return const ManagerRestaurantProfilePage();
    case 5: return const ManagerProfilePage();
    default: return const SizedBox.shrink();
  }
}

// ─── Manager Dashboard Page ───────────────────────────────────────────────────

class ManagerDashboardPage extends StatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  int _selectedIndex = 0;

  String? _restaurantId;
  String _restaurantName = '';
  int _totalTables = 0;
  List<SectionInfo> _sections = [];
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _loadManagerMeta();
  }

  Future<void> _loadManagerMeta() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final restaurantId = userDoc.data()?['restaurantId'] as String?;
    if (restaurantId == null) {
      setState(() => _loadingMeta = false);
      return;
    }

    final restaurantDoc = await FirebaseFirestore.instance
        .collection('restaurants').doc(restaurantId).get();
    final d = restaurantDoc.data() ?? {};

    final sectionsData = d['sections'];
    final sections = <SectionInfo>[];
    if (sectionsData is List) {
      for (final s in sectionsData) {
        if (s is Map<String, dynamic>) {
          sections.add(SectionInfo(
            id: s['id'] as String? ?? '',
            name: s['name'] as String? ?? '',
            tables: ((s['tables'] ?? 0) as num).toInt(),
          ));
        }
      }
    }

    setState(() {
      _restaurantId = restaurantId;
      _restaurantName = d['name'] ?? '';
      _totalTables = ((d['tableCount'] ?? 0) as num).toInt();
      _sections = sections;
      _loadingMeta = false;
    });
  }

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    setState(() => _selectedIndex = index);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _pageForIndex(index)),
    ).then((_) {
      setState(() => _selectedIndex = 0);
      _loadManagerMeta();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingMeta) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(
            color: Color(0xFF6B7C45), strokeWidth: 2.5)),
      );
    }

    if (_restaurantId == null) {
      return Scaffold(
        body: Center(child: Text('Nije pronađen restoran za vaš račun.',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall!.color))),
      );
    }

    return _isDesktop(context) ? _buildDesktop() : _buildMobile();
  }

  // ── Desktop layout ────────────────────────────────────────────────────────

  Widget _buildDesktop() {
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
            fontWeight: FontWeight.w600
          )
        ),
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo area
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8E6C0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_outlined,
                          color: Color(0xFF6B7C45), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('BookIt',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge!.color)),
                  ]),
                ),

                const Divider(height: 1),
                const SizedBox(height: 12),

                // Nav items
                ...List.generate(_navLabels.length, (i) {
                  final isSelected = i == _selectedIndex;
                  return _SidebarItem(
                    icon: isSelected ? _navIconsSelected[i] : _navIcons[i],
                    label: _navLabels[i],
                    isSelected: isSelected,
                    onTap: () => _onNavTap(i),
                  );
                }),

                const Spacer(),

                // Restaurant name at bottom
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFD8E6C0),
                      child: Icon(Icons.storefront_outlined,
                          color: Color(0xFF6B7C45), size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _restaurantName.isNotEmpty ? _restaurantName : 'Restoran',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge!.color),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // Right border
          const VerticalDivider(thickness: 1, width: 1),

          // Content
          Expanded(
            child: _buildDashboardContent(desktop: true),
          ),
        ],
      ),
    );
  }

  // ── Mobile layout — identical to original ─────────────────────────────────

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(child: _buildDashboardContent(desktop: false)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ManagerWalkInPage())),
        backgroundColor: const Color(0xFF6B7C45),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Walk-in',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: Color(0xFFCCD9B0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navLabels.length, (index) {
          final isSelected = index == _selectedIndex;
          return GestureDetector(
            onTap: () => _onNavTap(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(isSelected ? _navIconsSelected[index] : _navIcons[index],
                    size: 24,
                    color: isSelected
                        ? const Color(0xFF6B7C45)
                        : const Color(0xFF8A9A7A)),
                const SizedBox(height: 4),
                Text(_navLabels[index],
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF6B7C45)
                            : const Color(0xFF8A9A7A))),
              ]),
            ),
          );
        }),
      ),
    );
  }

  // ── Dashboard content (shared, adapts to desktop/mobile) ─────────────────

  Widget _buildDashboardContent({required bool desktop}) {
    final range = _todayRange;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('restaurantId', isEqualTo: _restaurantId)
          .where('date', isGreaterThanOrEqualTo: range.start)
          .where('date', isLessThanOrEqualTo: range.end)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final stats = _computeStats(docs);
        final confirmedPerSection = _confirmedPerSection(docs);

        final allReservations = docs
            .map((doc) => RecentReservationModel.fromFirestore(doc))
            .toList();
        final pending =
            allReservations.where((r) => r.status == 'pending').toList();
        final rest =
            allReservations.where((r) => r.status != 'pending').toList();
        final sorted = [...pending, ...rest];

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: desktop ? 32 : 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // ── Top bar ──────────────────────────────────────────
                  _buildTopBar(context, stats, desktop),
                  const SizedBox(height: 20),

                  // ── Section title ────────────────────────────────────
                  Text('Pregled za danas',
                      style: TextStyle(
                          fontSize: desktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color)),
                  const SizedBox(height: 12),

                  // ── Stats grid ───────────────────────────────────────
                  desktop
                      ? _buildStatsRow(context, stats)
                      : _buildStatsMobileGrid(context, stats),

                  const SizedBox(height: 20),

                  // ── Desktop: side-by-side occupancy + reservations ───
                  if (desktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_totalTables > 0)
                          Expanded(
                            flex: 5,
                            child: _buildOccupancyCard(
                                context, stats, confirmedPerSection),
                          ),
                        if (_totalTables > 0) const SizedBox(width: 20),
                        Expanded(
                          flex: 7,
                          child: _buildReservationsSection(
                              context, sorted, allReservations,
                              showAll: true),
                        ),
                      ],
                    )
                  else ...[
                    if (_totalTables > 0) ...[
                      _buildOccupancyCard(
                          context, stats, confirmedPerSection),
                      const SizedBox(height: 24),
                    ],
                    _buildReservationsSection(
                        context, sorted, allReservations,
                        showAll: false),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(
      BuildContext context, DashboardStatsModel stats, bool desktop) {
    return Row(children: [
      if (!desktop) ...[
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFD8E6C0),
          child: const Icon(Icons.storefront_outlined,
              color: Color(0xFF6B7C45), size: 20),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _restaurantName.isNotEmpty ? _restaurantName : 'Restoran',
            style: TextStyle(
                fontSize: desktop ? 22 : 17,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge!.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(_todayLabel(),
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall!.color)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6B7C45).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF6B7C45).withOpacity(0.4), width: 1.2),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storefront_outlined, size: 13, color: Color(0xFF6B7C45)),
          SizedBox(width: 6),
          Text('Menadžer restorana',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7C45))),
        ]),
      ),
      Stack(children: [
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.notifications_outlined,
              color: Theme.of(context).textTheme.bodyLarge!.color, size: 26),
        ),
        if (stats.pending > 0)
          Positioned(
            top: 8, right: 8,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(
                  color: Color(0xFFD94F4F), shape: BoxShape.circle),
              child: Center(
                child: Text('${stats.pending}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ),
      ]),
    ]);
  }

  // ── Stats — desktop: 4 cards in a Row ─────────────────────────────────────

  Widget _buildStatsRow(BuildContext context, DashboardStatsModel stats) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Ukupno danas', value: '${stats.totalToday}',
            icon: Icons.calendar_today_outlined, color: const Color(0xFF6B7C45))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Na čekanju', value: '${stats.pending}',
            icon: Icons.hourglass_top_rounded, color: const Color(0xFFE8B84B))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Potvrđeno', value: '${stats.confirmed}',
            icon: Icons.check_circle_outline, color: const Color(0xFF4CAF50))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Otkazano', value: '${stats.cancelled}',
            icon: Icons.cancel_outlined, color: const Color(0xFFD94F4F))),
      ],
    );
  }

  // ── Stats — mobile: 2×2 grid ──────────────────────────────────────────────

  Widget _buildStatsMobileGrid(
      BuildContext context, DashboardStatsModel stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _StatCard(label: 'Ukupno danas', value: '${stats.totalToday}',
            icon: Icons.calendar_today_outlined, color: const Color(0xFF6B7C45)),
        _StatCard(label: 'Na čekanju', value: '${stats.pending}',
            icon: Icons.hourglass_top_rounded, color: const Color(0xFFE8B84B)),
        _StatCard(label: 'Potvrđeno', value: '${stats.confirmed}',
            icon: Icons.check_circle_outline, color: const Color(0xFF4CAF50)),
        _StatCard(label: 'Otkazano', value: '${stats.cancelled}',
            icon: Icons.cancel_outlined, color: const Color(0xFFD94F4F)),
      ],
    );
  }

  // ── Occupancy card ────────────────────────────────────────────────────────

  Widget _buildOccupancyCard(
    BuildContext context,
    DashboardStatsModel stats,
    Map<String, int> confirmedPerSection,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Zauzetost stolova',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color)),
          const SizedBox(height: 14),
          if (_sections.isNotEmpty) ...[
            ..._sections.map((section) {
              final confirmed = confirmedPerSection[section.id] ?? 0;
              final fraction = section.tables > 0
                  ? (confirmed / section.tables).clamp(0.0, 1.0)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(section.name,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyLarge!.color)),
                      const Spacer(),
                      Text('$confirmed/${section.tables}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: Color(0xFF6B7C45))),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFECF2DF),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fraction > 0.8
                              ? const Color(0xFFD94F4F)
                              : fraction > 0.5
                                  ? const Color(0xFFE8B84B)
                                  : const Color(0xFF6B7C45),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Ukupno',
                  style: TextStyle(fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall!.color)),
              Text('${stats.confirmed}/$_totalTables',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.bold, color: Color(0xFF6B7C45))),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _totalTables > 0
                    ? (stats.confirmed / _totalTables).clamp(0.0, 1.0)
                    : 0,
                minHeight: 10,
                backgroundColor: const Color(0xFFECF2DF),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6B7C45)),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _LegendDot(color: const Color(0xFF6B7C45),
                  label: '${stats.confirmed} zauzeto'),
              const SizedBox(width: 16),
              _LegendDot(color: const Color(0xFFECF2DF),
                  label: '${_totalTables - stats.confirmed} slobodno',
                  textColor: Theme.of(context).textTheme.bodySmall!.color,
                  bordered: true),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Reservations section ──────────────────────────────────────────────────

  Widget _buildReservationsSection(
    BuildContext context,
    List<RecentReservationModel> sorted,
    List<RecentReservationModel> allReservations, {
    required bool showAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Na čekanju — pregled',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color)),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ManagerReservationsPage()))
                .then((_) {
              setState(() => _selectedIndex = 0);
              _loadManagerMeta();
            }),
            child: Text('Sve (${allReservations.length})',
                style: const TextStyle(fontSize: 13,
                    color: Color(0xFF6B7C45), fontWeight: FontWeight.w500)),
          ),
        ]),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Nema rezervacija za danas.',
                  style: TextStyle(fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall!.color)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: showAll ? sorted.length : sorted.length.clamp(0, 3),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _ReservationRow(reservation: sorted[index]),
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ({Timestamp start, Timestamp end}) get _todayRange {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return (start: Timestamp.fromDate(start), end: Timestamp.fromDate(end));
  }

  DashboardStatsModel _computeStats(List<QueryDocumentSnapshot> docs) {
    int pending = 0, confirmed = 0, cancelled = 0;
    for (final doc in docs) {
      final status = (doc.data() as Map<String, dynamic>)['status'] ?? '';
      if (status == 'pending') pending++;
      else if (status == 'confirmed') confirmed++;
      else if (status == 'cancelled') cancelled++;
    }
    return DashboardStatsModel(
      totalToday: docs.length,
      pending: pending,
      confirmed: confirmed,
      cancelled: cancelled,
      totalTables: _totalTables,
    );
  }

  Map<String, int> _confirmedPerSection(List<QueryDocumentSnapshot> docs) {
    final map = <String, int>{};
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['status'] == 'confirmed') {
        final sid = d['sectionId'] as String? ?? '__none__';
        map[sid] = (map[sid] ?? 0) + 1;
      }
    }
    return map;
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni',
      'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];
    return '${now.day}. ${months[now.month - 1]} ${now.year}.';
  }
}

// ─── Sidebar item ─────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6B7C45).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF6B7C45)
                  : const Color(0xFF8A9A7A)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? const Color(0xFF6B7C45)
                      : const Color(0xFF8A9A7A))),
        ]),
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall!.color)),
        ],
      ),
    );
  }
}

// ─── Legend dot ───────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color? textColor;
  final bool bordered;

  const _LegendDot(
      {required this.color,
      required this.label,
      this.textColor,
      this.bordered = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: bordered
              ? Border.all(color: const Color(0xFFCCD9B0), width: 1)
              : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: textColor ??
                  Theme.of(context).textTheme.bodySmall!.color)),
    ]);
  }
}

// ─── Reservation row ──────────────────────────────────────────────────────────

class _ReservationRow extends StatelessWidget {
  final RecentReservationModel reservation;
  const _ReservationRow({required this.reservation});

  Color _statusColor() {
    switch (reservation.status) {
      case 'pending': return const Color(0xFFE8B84B);
      case 'confirmed': return const Color(0xFF4CAF50);
      case 'cancelled': return const Color(0xFFD94F4F);
      default: return const Color(0xFF8A9A7A);
    }
  }

  String _statusLabel() {
    switch (reservation.status) {
      case 'pending': return 'Na čekanju';
      case 'confirmed': return 'Potvrđeno';
      case 'cancelled': return 'Otkazano';
      default: return reservation.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFF6B7C45).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(reservation.time,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7C45)))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reservation.guestName,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge!.color)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.people_outline, size: 13,
                  color: Theme.of(context).textTheme.bodySmall!.color),
              const SizedBox(width: 4),
              Text('${reservation.guestCount} gosta',
                  style: TextStyle(fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall!.color)),
              if (reservation.sectionName != null) ...[
                const SizedBox(width: 8),
                const Text('·', style: TextStyle(color: Color(0xFF8A9A7A))),
                const SizedBox(width: 8),
                Icon(Icons.chair_outlined, size: 12,
                    color: Theme.of(context).textTheme.bodySmall!.color),
                const SizedBox(width: 3),
                Text(reservation.sectionName!,
                    style: TextStyle(fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall!.color)),
              ],
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: _statusColor().withOpacity(0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(_statusLabel(),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _statusColor())),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF8A9A7A)),
      ]),
    );
  }
}