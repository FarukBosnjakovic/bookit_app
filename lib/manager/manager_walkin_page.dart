import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerWalkInPage extends StatefulWidget {
  const ManagerWalkInPage({super.key});

  @override
  State<ManagerWalkInPage> createState() => _ManagerWalkInPageState();
}

class _ManagerWalkInPageState extends State<ManagerWalkInPage> {
  // ── Meta ──────────────────────────────────────────────────────────
  String? _restaurantId;
  String _restaurantName = '';
  List<Map<String, dynamic>> _sections = [];
  bool _loadingMeta = true;

  // ── Customer ──────────────────────────────────────────────────────
  bool _useExistingUser = false;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Map<String, dynamic>? _selectedUser;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // ── Booking details ───────────────────────────────────────────────
  int _guestCount = 2;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Map<String, dynamic>? _selectedSection;
  int? _selectedTable;

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final restaurantId = userDoc.data()?['restaurantId'];
    if (restaurantId == null) {
      setState(() => _loadingMeta = false);
      return;
    }
    final restaurantDoc = await FirebaseFirestore.instance
        .collection('restaurants').doc(restaurantId).get();
    final d = restaurantDoc.data() ?? {};
    final sectionsRaw = d['sections'];
    final sections = <Map<String, dynamic>>[];
    if (sectionsRaw is List) {
      for (final s in sectionsRaw) {
        if (s is Map<String, dynamic>) sections.add(Map<String, dynamic>.from(s));
      }
    }
    setState(() {
      _restaurantId = restaurantId;
      _restaurantName = d['name'] ?? '';
      _sections = sections;
      _loadingMeta = false;
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .startAt([query.trim()])
          .endAt(['${query.trim()}\uf8ff'])
          .limit(8)
          .get();
      setState(() {
        _searchResults = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String get _formattedDate {
    const months = [
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni',
      'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];
    return '${_selectedDate.day}. ${months[_selectedDate.month - 1]} ${_selectedDate.year}.';
  }

  String get _formattedTime =>
      '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() { _errorMessage = null; });

    // Validate customer
    if (_useExistingUser && _selectedUser == null) {
      setState(() => _errorMessage = 'Odaberite korisnika iz rezultata pretrage.');
      return;
    }
    if (!_useExistingUser) {
      if (_firstNameController.text.trim().isEmpty ||
          _lastNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Unesite ime i prezime gosta.');
        return;
      }
    }
    if (_selectedSection == null) {
      setState(() => _errorMessage = 'Odaberite sekciju.');
      return;
    }
    if (_selectedTable == null) {
      setState(() => _errorMessage = 'Odaberite stol.');
      return;
    }
    if (_restaurantId == null) return;

    setState(() => _saving = true);

    final userName = _useExistingUser
        ? (_selectedUser!['name'] ?? 'Nepoznat')
        : '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
    final userPhone = _useExistingUser
        ? (_selectedUser!['phone'] ?? '')
        : _phoneController.text.trim();
    final userId = _useExistingUser ? (_selectedUser!['id'] ?? '') : '';

    final bookingDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'restaurantId': _restaurantId,
        'restaurantName': _restaurantName,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'guestCount': _guestCount,
        'date': Timestamp.fromDate(bookingDate),
        'time': _formattedTime,
        'sectionId': _selectedSection!['id'],
        'sectionName': _selectedSection!['name'],
        'tableNumber': _selectedTable,
        'status': 'confirmed',
        'source': 'walkin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rezervacija kreirana uspješno.'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = 'Greška pri kreiranju rezervacije.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMeta) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(
            color: Color(0xFF6B7C45), strokeWidth: 2.5)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B7C45),
              disabledBackgroundColor: const Color(0xFFCCD9B0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Kreiraj rezervaciju',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Header ──────────────────────────────────────────
              Row(children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                    ),
                    child: Icon(Icons.arrow_back,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                        size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Nova walk-in rezervacija',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color)),
              ]),

              const SizedBox(height: 28),

              // ── Customer section ────────────────────────────────
              _SectionLabel('Gost'),
              const SizedBox(height: 10),

              // Toggle
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
                ),
                child: Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _useExistingUser = false;
                        _selectedUser = null;
                        _searchResults = [];
                        _searchController.clear();
                      }),
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_useExistingUser
                              ? const Color(0xFF6B7C45)
                              : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(12)),
                        ),
                        child: Center(child: Text('Ručni unos',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !_useExistingUser
                                    ? Colors.white
                                    : Theme.of(context).textTheme.bodySmall!.color))),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _useExistingUser = true;
                        _firstNameController.clear();
                        _lastNameController.clear();
                        _phoneController.clear();
                      }),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _useExistingUser
                              ? const Color(0xFF6B7C45)
                              : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(12)),
                        ),
                        child: Center(child: Text('Pretraži korisnike',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _useExistingUser
                                    ? Colors.white
                                    : Theme.of(context).textTheme.bodySmall!.color))),
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 14),

              if (_useExistingUser) ...[
                // Search field
                TextField(
                  controller: _searchController,
                  onChanged: _searchUsers,
                  style: TextStyle(fontSize: 15,
                      color: Theme.of(context).textTheme.bodyLarge!.color),
                  decoration: InputDecoration(
                    hintText: 'Pretraži po imenu...',
                    hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall!.color,
                        fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: Color(0xFF6B7C45)),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF6B7C45), strokeWidth: 2)))
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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

                // Selected user badge
                if (_selectedUser != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7C45).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF6B7C45).withOpacity(0.4),
                          width: 1.2),
                    ),
                    child: Row(children: [
                      const Icon(Icons.person_outline,
                          size: 18, color: Color(0xFF6B7C45)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedUser!['name'] ?? '',
                                style: TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .textTheme.bodyLarge!.color)),
                            if ((_selectedUser!['phone'] ?? '').isNotEmpty)
                              Text(_selectedUser!['phone'],
                                  style: TextStyle(fontSize: 12,
                                      color: Theme.of(context)
                                          .textTheme.bodySmall!.color)),
                          ])),
                      InkWell(
                        onTap: () => setState(() {
                          _selectedUser = null;
                          _searchController.clear();
                          _searchResults = [];
                        }),
                        child: const Icon(Icons.close,
                            size: 18, color: Color(0xFF8A9A7A)),
                      ),
                    ]),
                  ),
                ],

                // Search results
                if (_searchResults.isNotEmpty && _selectedUser == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFCCD9B0), width: 1.2),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      children: _searchResults.asMap().entries.map((entry) {
                        final i = entry.key;
                        final user = entry.value;
                        final isLast = i == _searchResults.length - 1;
                        return InkWell(
                          onTap: () => setState(() {
                            _selectedUser = user;
                            _searchResults = [];
                          }),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      const Color(0xFFD8E6C0),
                                  child: Text(
                                    (user['name'] as String? ?? '?')
                                        .isNotEmpty
                                        ? (user['name'] as String)[0]
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6B7C45)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(user['name'] ?? '',
                                          style: TextStyle(fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context)
                                                  .textTheme.bodyLarge!.color)),
                                      if ((user['phone'] ?? '').isNotEmpty)
                                        Text(user['phone'],
                                            style: TextStyle(fontSize: 12,
                                                color: Theme.of(context)
                                                    .textTheme.bodySmall!.color)),
                                    ])),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 12, color: Color(0xFF8A9A7A)),
                              ]),
                            ),
                            if (!isLast)
                              const Divider(height: 1,
                                  indent: 14, endIndent: 14,
                                  color: Color(0xFFECF2DF)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ] else ...[
                // Manual entry
                Row(children: [
                  Expanded(child: _InputField(
                      controller: _firstNameController,
                      hint: 'Ime',
                      icon: Icons.person_outline)),
                  const SizedBox(width: 10),
                  Expanded(child: _InputField(
                      controller: _lastNameController,
                      hint: 'Prezime',
                      icon: Icons.person_outline)),
                ]),
                const SizedBox(height: 12),
                _InputField(
                    controller: _phoneController,
                    hint: 'Broj telefona (opcionalno)',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
              ],

              const SizedBox(height: 24),

              // ── Guest count ─────────────────────────────────────
              _SectionLabel('Broj gostiju'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFCCD9B0), width: 1.2),
                ),
                child: Row(children: [
                  const Icon(Icons.people_outline,
                      size: 18, color: Color(0xFF6B7C45)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('$_guestCount osoba',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyLarge!.color))),
                  _CounterBtn(
                    icon: Icons.remove,
                    enabled: _guestCount > 1,
                    onTap: () => setState(() => _guestCount--),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('$_guestCount',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge!.color)),
                  ),
                  _CounterBtn(
                    icon: Icons.add,
                    enabled: _guestCount < 50,
                    onTap: () => setState(() => _guestCount++),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Date & time ─────────────────────────────────────
              _SectionLabel('Datum i vrijeme'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFCCD9B0), width: 1.2),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: Color(0xFF6B7C45)),
                        const SizedBox(width: 8),
                        Flexible(child: Text(_formattedDate,
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme.bodyLarge!.color))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFCCD9B0), width: 1.2),
                      ),
                      child: Row(children: [
                        const Icon(Icons.access_time_outlined,
                            size: 16, color: Color(0xFF6B7C45)),
                        const SizedBox(width: 8),
                        Text(_formattedTime,
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme.bodyLarge!.color)),
                      ]),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Section selection ───────────────────────────────
              _SectionLabel('Sekcija'),
              const SizedBox(height: 10),
              if (_sections.isEmpty)
                Text('Nema sekcija u restoranu.',
                    style: TextStyle(fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall!.color))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sections.map((section) {
                    final isSelected =
                        _selectedSection?['id'] == section['id'];
                    return InkWell(
                      onTap: () => setState(() {
                        _selectedSection = section;
                        _selectedTable = null;
                      }),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6B7C45)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6B7C45)
                                  : const Color(0xFFCCD9B0),
                              width: 1.2),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (isSelected) ...[
                            const Icon(Icons.check,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                          ],
                          Text(section['name'] ?? '',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context)
                                          .textTheme.bodyLarge!.color)),
                          const SizedBox(width: 6),
                          Text('(${section['tables']} stolova)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.8)
                                      : Theme.of(context)
                                          .textTheme.bodySmall!.color)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),

              // ── Table selection ─────────────────────────────────
              if (_selectedSection != null) ...[
                const SizedBox(height: 24),
                _SectionLabel('Stol — ${_selectedSection!['name']}'),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1),
                  itemCount: (_selectedSection!['tables'] as num).toInt(),
                  itemBuilder: (context, index) {
                    final num = index + 1;
                    final isSelected = _selectedTable == num;
                    return InkWell(
                      onTap: () => setState(() => _selectedTable = num),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6B7C45)
                              : const Color(0xFF6B7C45).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6B7C45)
                                  : const Color(0xFFCCD9B0),
                              width: 1.5),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSelected)
                                const Icon(Icons.check,
                                    size: 12, color: Colors.white),
                              Text('$num',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF6B7C45))),
                            ]),
                      ),
                    );
                  },
                ),
              ],

              // ── Error ───────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD94F4F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFD94F4F).withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Color(0xFFD94F4F)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFFD94F4F)))),
                  ]),
                ),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Counter button ───────────────────────────────────────────────────────────

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CounterBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF6B7C45)
                : const Color(0xFFCCD9B0),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 18),
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
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge!.color));
}

// ─── Input field ──────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _InputField({
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
      style: TextStyle(fontSize: 15,
          color: Theme.of(context).textTheme.bodyLarge!.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context).textTheme.bodySmall!.color,
            fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7C45)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
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