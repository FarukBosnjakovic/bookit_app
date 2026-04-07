import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> _daysOfWeek = [
  'Ponedjeljak', 'Utorak', 'Srijeda', 'Četvrtak',
  'Petak', 'Subota', 'Nedjelja',
];

const List<String> _cuisineOptions = [
  'Azijska', 'Evropska', 'Tradicionalna', 'Brza hrana',
  'Mediteranska', 'Italijanska', 'Meksička', 'Ostalo',
];

const List<String> _sectionSuggestions = [
  'Sala', 'Terasa', 'Prizemlje', 'Sprat', 'Suteren',
  'Bašta', 'Privatna sala', 'Bar',
];

// ─── Section entry ────────────────────────────────────────────────────────────

class _SectionEntry {
  final TextEditingController nameController;
  int tables;

  _SectionEntry({String name = '', this.tables = 4})
      : nameController = TextEditingController(text: name);

  void dispose() => nameController.dispose();

  Map<String, dynamic> toMap(int index) => {
    'id': nameController.text.trim().toLowerCase().replaceAll(' ', '_').isEmpty
        ? 's$index'
        : nameController.text.trim().toLowerCase().replaceAll(' ', '_'),
    'name': nameController.text.trim(),
    'tables': tables,
  };
}

// ─── Manager Edit Restaurant Page ─────────────────────────────────────────────

class ManagerEditRestaurantPage extends StatefulWidget {
  const ManagerEditRestaurantPage({super.key});

  @override
  State<ManagerEditRestaurantPage> createState() =>
      _ManagerEditRestaurantPageState();
}

class _ManagerEditRestaurantPageState
    extends State<ManagerEditRestaurantPage> {
  // ── State ──────────────────────────────────────────────────────────
  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;
  String? _restaurantId;
  String? _errorMessage;

  // ── Controllers ────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ── Cuisines ───────────────────────────────────────────────────────
  final List<String> _selectedCuisines = [];

  // ── Sections ───────────────────────────────────────────────────────
  final List<_SectionEntry> _sections = [];

  // ── Working hours ──────────────────────────────────────────────────
  int _selectedDuration = 90;

  Map<String, Map<String, dynamic>> _workingHours = {
    for (int i = 0; i < _daysOfWeek.length; i++)
      _daysOfWeek[i]: {'isOpen': i < 6, 'open': '08:00', 'close': '23:00'},
  };

  int get _totalTableCount => _sections.fold(0, (s, e) => s + e.tables);

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
    // Track changes
    for (final c in [_nameController, _addressController, _phoneController,
        _emailController, _descriptionController]) {
      c.addListener(() => setState(() => _hasChanges = true));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    for (final s in _sections) s.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurant() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) { setState(() => _loading = false); return; }

      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final restaurantId = userDoc.data()?['restaurantId'] as String?;
      if (restaurantId == null) { setState(() => _loading = false); return; }

      final doc = await FirebaseFirestore.instance
          .collection('restaurants').doc(restaurantId).get();
      final d = doc.data() ?? {};

      // Basic info
      _nameController.text = d['name'] ?? '';
      _addressController.text = d['address'] ?? '';
      _phoneController.text = d['phone'] ?? '';
      _emailController.text = d['email'] ?? '';
      _descriptionController.text = d['description'] ?? '';

      // Cuisines
      final cuisinesData = d['cuisines'];
      if (cuisinesData is List) {
        _selectedCuisines.addAll(cuisinesData.map((e) => e.toString()));
      }

      // Sections
      final sectionsData = d['sections'];
      if (sectionsData is List) {
        for (final s in sectionsData) {
          if (s is Map<String, dynamic>) {
            _sections.add(_SectionEntry(
              name: s['name'] as String? ?? '',
              tables: (s['tables'] as int?) ?? 4,
            ));
          }
        }
      } else if (_sections.isEmpty) {
        // No sections yet — add one default based on tableCount
        final tc = (d['tableCount'] as int?) ?? 10;
        _sections.add(_SectionEntry(name: 'Sala', tables: tc));
      }

      // Booking duration
      _selectedDuration = (d['bookingDurationMinutes'] as int?) ?? 90;

      // Working hours
      final wh = d['workingHours'];
      if (wh is Map) {
        final map = <String, Map<String, dynamic>>{};
        for (final day in _daysOfWeek) {
          final dayData = wh[day];
          if (dayData is Map) {
            map[day] = {
              'isOpen': dayData['isOpen'] ?? false,
              'open': dayData['open'] ?? '08:00',
              'close': dayData['close'] ?? '23:00',
            };
          } else {
            map[day] = {'isOpen': false, 'open': '08:00', 'close': '23:00'};
          }
        }
        _workingHours = map;
      }

      setState(() {
        _restaurantId = restaurantId;
        _loading = false;
        _hasChanges = false; // reset — loading isn't a change
      });
    } catch (e) {
      setState(() { _loading = false; _errorMessage = e.toString(); });
    }
  }

  Future<void> _save() async {
    // Validate
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Naziv restorana je obavezan.');
      return;
    }
    if (_selectedCuisines.isEmpty) {
      setState(() => _errorMessage = 'Odaberite barem jedan tip kuhinje.');
      return;
    }
    if (_sections.isEmpty) {
      setState(() => _errorMessage = 'Dodajte barem jednu sekciju.');
      return;
    }
    for (final s in _sections) {
      if (s.nameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Sve sekcije moraju imati naziv.');
        return;
      }
    }
    final anyOpen = _workingHours.values.any((d) => d['isOpen'] == true);
    if (!anyOpen) {
      setState(() => _errorMessage = 'Odaberite barem jedan radni dan.');
      return;
    }

    setState(() { _saving = true; _errorMessage = null; });

    try {
      final sectionsData = _sections
          .asMap()
          .entries
          .map((e) => e.value.toMap(e.key + 1))
          .toList();

      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(_restaurantId)
          .update({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'description': _descriptionController.text.trim(),
        'cuisines': _selectedCuisines,
        'sections': sectionsData,
        'tableCount': _totalTableCount,
        'workingHours': _workingHours,
        'bookingDurationMinutes': _selectedDuration,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() { _saving = false; _hasChanges = false; });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Izmjene su sačuvane.'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true); // return true = data changed
    } catch (e) {
      setState(() { _saving = false; _errorMessage = 'Greška: ${e.toString()}'; });
    }
  }

  void _confirmDiscard() {
    if (!_hasChanges) { Navigator.pop(context); return; }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Odbaciti izmjene?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge!.color)),
        content: Text('Imate nesačuvane izmjene.',
            style: TextStyle(fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall!.color, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Ostani',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall!.color,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Odbaci',
                style: TextStyle(color: Color(0xFFD94F4F), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(String day, bool isOpen) async {
    final current = _workingHours[day]![isOpen ? 'open' : 'close'] as String;
    final parts = current.split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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
      setState(() {
        _workingHours[day]![isOpen ? 'open' : 'close'] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _hasChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(
              color: Color(0xFF6B7C45), strokeWidth: 2.5)));
    }

    if (_restaurantId == null) {
      return Scaffold(
        body: Center(child: Text('Restoran nije pronađen.',
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall!.color))),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD94F4F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD94F4F).withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 16, color: Color(0xFFD94F4F)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFD94F4F)))),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_hasChanges && !_saving) ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7C45),
                  disabledBackgroundColor: const Color(0xFFCCD9B0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Sačuvaj izmjene',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                            letterSpacing: 0.4)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(children: [
                GestureDetector(
                  onTap: _confirmDiscard,
                  child: Icon(Icons.arrow_back,
                      color: Theme.of(context).textTheme.bodyLarge!.color, size: 24),
                ),
                const SizedBox(width: 16),
                Text('Postavke restorana',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color)),
                if (_hasChanges) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8B84B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Nesačuvano',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: Color(0xFFE8B84B))),
                  ),
                ],
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Basic info ─────────────────────────────────
                    _SectionHeader(label: 'Osnovne informacije'),
                    const SizedBox(height: 12),

                    _FieldLabel(label: 'Naziv restorana'),
                    const SizedBox(height: 8),
                    _InputField(controller: _nameController,
                        hint: 'Naziv Vašeg restorana', icon: Icons.storefront_outlined),

                    const SizedBox(height: 16),
                    _FieldLabel(label: 'Opis restorana'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4, maxLength: 300,
                      style: TextStyle(fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge!.color),
                      decoration: InputDecoration(
                        hintText: 'Kratki opis restorana, specijaliteti...',
                        hintStyle: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall!.color, fontSize: 14),
                        filled: true, fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCCD9B0), width: 1.2)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6B7C45), width: 1.8)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Contact ────────────────────────────────────
                    _SectionHeader(label: 'Kontakt'),
                    const SizedBox(height: 12),

                    _FieldLabel(label: 'Adresa'),
                    const SizedBox(height: 8),
                    _InputField(controller: _addressController,
                        hint: 'Ulica bb, Grad', icon: Icons.location_on_outlined),

                    const SizedBox(height: 16),
                    _FieldLabel(label: 'Telefon'),
                    const SizedBox(height: 8),
                    _InputField(controller: _phoneController,
                        hint: '+387 33 000 000', icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone),

                    const SizedBox(height: 16),
                    _FieldLabel(label: 'Email'),
                    const SizedBox(height: 8),
                    _InputField(controller: _emailController,
                        hint: 'info@restoran.ba', icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),

                    const SizedBox(height: 24),

                    // ── Cuisines ───────────────────────────────────
                    _SectionHeader(label: 'Tip kuhinje'),
                    const SizedBox(height: 4),
                    Text('Možete odabrati više tipova.',
                        style: TextStyle(fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall!.color)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _cuisineOptions.map((cuisine) {
                        final selected = _selectedCuisines.contains(cuisine);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (selected) _selectedCuisines.remove(cuisine);
                            else _selectedCuisines.add(cuisine);
                            _hasChanges = true;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF6B7C45)
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: selected ? const Color(0xFF6B7C45)
                                      : const Color(0xFFCCD9B0), width: 1.2),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (selected) ...[
                                const Icon(Icons.check, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                              ],
                              Text(cuisine,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                      color: selected ? Colors.white
                                          : Theme.of(context).textTheme.bodyLarge!.color)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Sections ───────────────────────────────────
                    _SectionHeader(label: 'Sekcije restorana'),
                    const SizedBox(height: 4),
                    Text('Upravljajte prostorima i brojem stolova.',
                        style: TextStyle(fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall!.color)),
                    const SizedBox(height: 12),

                    // Quick-add suggestions
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _sectionSuggestions.map((name) {
                        final exists = _sections.any(
                            (s) => s.nameController.text.trim() == name);
                        return GestureDetector(
                          onTap: exists ? null : () => setState(() {
                            _sections.add(_SectionEntry(name: name));
                            _hasChanges = true;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: exists
                                  ? const Color(0xFF6B7C45).withOpacity(0.1)
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: exists
                                      ? const Color(0xFF6B7C45).withOpacity(0.4)
                                      : const Color(0xFFCCD9B0), width: 1.2),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(exists ? Icons.check : Icons.add, size: 14,
                                  color: exists ? const Color(0xFF6B7C45)
                                      : Theme.of(context).textTheme.bodySmall!.color),
                              const SizedBox(width: 4),
                              Text(name,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                      color: exists ? const Color(0xFF6B7C45)
                                          : Theme.of(context).textTheme.bodyLarge!.color)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // Section cards
                    ..._sections.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      return _SectionCard(
                        section: s,
                        index: i,
                        onDelete: () => setState(() {
                          s.dispose();
                          _sections.removeAt(i);
                          _hasChanges = true;
                        }),
                        onTablesChanged: (v) => setState(() {
                          s.tables = v;
                          _hasChanges = true;
                        }),
                        onNameChanged: () => setState(() => _hasChanges = true),
                      );
                    }),

                    // Total
                    if (_sections.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B7C45).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF6B7C45).withOpacity(0.3), width: 1.2),
                        ),
                        child: Row(children: [
                          const Icon(Icons.table_restaurant_outlined,
                              size: 18, color: Color(0xFF6B7C45)),
                          const SizedBox(width: 10),
                          Text('Ukupno stolova:',
                              style: TextStyle(fontSize: 14,
                                  color: Theme.of(context).textTheme.bodySmall!.color)),
                          const Spacer(),
                          Text('$_totalTableCount',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B7C45))),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],

                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _sections.add(_SectionEntry());
                        _hasChanges = true;
                      }),
                      icon: const Icon(Icons.add, size: 18, color: Color(0xFF6B7C45)),
                      label: const Text('Dodaj sekciju',
                          style: TextStyle(fontSize: 14, color: Color(0xFF6B7C45),
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        side: const BorderSide(color: Color(0xFF6B7C45), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Booking duration
                    _SectionHeader(label: 'Trajanje rezervacije'),
                    const SizedBox(height: 4),
                    Text(
                      'Koliko dugo stolovi ostaju zauzeti po rezervaciji.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall!.color,
                      )
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCCD9B0),
                          width: 1.2
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedDuration,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF8A9A7A)
                          ),
                          style: TextStyle(
                            fontSize: 1,
                            color: Theme.of(context).textTheme.bodyLarge!.color
                          ),
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedDuration = val;
                                _hasChanges = true;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 60, child: Text('60 minuta')),
                            DropdownMenuItem(value: 90, child: Text('90 minuta')),
                            DropdownMenuItem(value: 120, child: Text('120 minuta')),
                            DropdownMenuItem(value: 150, child: Text('150 minuta')),
                            DropdownMenuItem(value: 180, child: Text('180 minuta')),
                          ],
                        ),
                      ),
                    ),

                    // ── Working hours ──────────────────────────────
                    _SectionHeader(label: 'Radno vrijeme'),
                    const SizedBox(height: 4),
                    Text('Postavite radno vrijeme za svaki dan.',
                        style: TextStyle(fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall!.color)),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
                      ),
                      child: Column(
                        children: _daysOfWeek.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final day = entry.value;
                          final isOpen = _workingHours[day]!['isOpen'] as bool;
                          final openTime = _workingHours[day]!['open'] as String;
                          final closeTime = _workingHours[day]!['close'] as String;
                          final isLast = idx == _daysOfWeek.length - 1;

                          return Column(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Column(children: [
                                Row(children: [
                                  SizedBox(
                                    width: 110,
                                    child: Text(day,
                                        style: TextStyle(fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isOpen
                                                ? Theme.of(context).textTheme.bodyLarge!.color
                                                : Theme.of(context).textTheme.bodySmall!.color)),
                                  ),
                                  Text(isOpen ? 'Otvoreno' : 'Zatvoreno',
                                      style: TextStyle(fontSize: 12,
                                          color: isOpen ? const Color(0xFF4CAF50)
                                              : const Color(0xFFD94F4F),
                                          fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Switch(
                                    value: isOpen,
                                    onChanged: (val) => setState(() {
                                      _workingHours[day]!['isOpen'] = val;
                                      _hasChanges = true;
                                    }),
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: const Color(0xFF4CAF50),
                                    inactiveThumbColor: Colors.white,
                                    inactiveTrackColor: const Color(0xFFCCD9B0),
                                  ),
                                ]),
                                if (isOpen) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _pickTime(day, true),
                                        child: _TimeBox(time: openTime),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text('–',
                                          style: TextStyle(fontSize: 16,
                                              color: Theme.of(context).textTheme.bodySmall!.color)),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _pickTime(day, false),
                                        child: _TimeBox(time: closeTime),
                                      ),
                                    ),
                                  ]),
                                ],
                              ]),
                            ),
                            if (!isLast)
                              const Divider(height: 1, indent: 14, endIndent: 14,
                                  color: Color(0xFFECF2DF)),
                          ]);
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 32),
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

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final _SectionEntry section;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<int> onTablesChanged;
  final VoidCallback onNameChanged;

  const _SectionCard({
    required this.section, required this.index, required this.onDelete,
    required this.onTablesChanged, required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: const Color(0xFF6B7C45).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('${index + 1}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7C45)))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: section.nameController,
              onChanged: (_) => onNameChanged(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge!.color),
              decoration: InputDecoration(
                hintText: 'Naziv sekcije',
                hintStyle: TextStyle(fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall!.color),
                filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCCD9B0), width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6B7C45), width: 1.8)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: const Color(0xFFD94F4F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFD94F4F)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.table_restaurant_outlined, size: 16,
              color: Theme.of(context).textTheme.bodySmall!.color),
          const SizedBox(width: 8),
          Text('Broj stolova:',
              style: TextStyle(fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall!.color)),
          const Spacer(),
          _CounterBtn(icon: Icons.remove, enabled: section.tables > 1,
              onTap: () => onTablesChanged(section.tables - 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('${section.tables}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color)),
          ),
          _CounterBtn(icon: Icons.add, enabled: section.tables < 100,
              onTap: () => onTablesChanged(section.tables + 1)),
        ]),
      ]),
    );
  }
}

// ─── Small shared widgets ─────────────────────────────────────────────────────

class _TimeBox extends StatelessWidget {
  final String time;
  const _TimeBox({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
      ),
      child: Row(children: [
        const Icon(Icons.access_time_outlined, size: 16, color: Color(0xFF6B7C45)),
        const SizedBox(width: 6),
        Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge!.color)),
      ]),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: enabled ? const Color(0xFF6B7C45) : const Color(0xFFCCD9B0),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge!.color)),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: const Color(0xFFCCD9B0).withOpacity(0.8), thickness: 1)),
    ]);
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodySmall!.color));
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _InputField({required this.controller, required this.hint,
      required this.icon, this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyLarge!.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall!.color, fontSize: 15),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7C45)),
        filled: true, fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCD9B0), width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6B7C45), width: 1.8)),
      ),
    );
  }
}