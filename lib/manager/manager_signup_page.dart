import 'package:flutter/material.dart';
import 'package:bookit/manager/manager_pending_page.dart';
import 'package:bookit/auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─── BiH cities ───────────────────────────────────────────────────────────────

const List<String> _bihCities = [
  'Tuzla', 'Sarajevo', 'Mostar', 'Banja Luka', 'Zenica',
  'Bijeljina', 'Brčko', 'Travnik', 'Cazin', 'Bihać',
  'Živinice', 'Lukavac', 'Gradačac', 'Doboj', 'Zvornik',
  'Srebrenik', 'Tešanj', 'Visoko', 'Konjic', 'Ostalo',
];

// ─── Days of week ─────────────────────────────────────────────────────────────

const List<String> _daysOfWeek = [
  'Ponedjeljak', 'Utorak', 'Srijeda', 'Četvrtak',
  'Petak', 'Subota', 'Nedjelja',
];

// ─── Section entry ────────────────────────────────────────────────────────────

class _SectionEntry {
  final TextEditingController nameController;
  int tables;

  _SectionEntry({String name = '', int tables = 1})
      : nameController = TextEditingController(text: name),
        tables = tables;

  void dispose() => nameController.dispose();

  Map<String, dynamic> toMap(int index) => {
    'id': 's$index',
    'name': nameController.text.trim(),
    'tables': tables,
  };
}

// Preset section suggestions for quick-add
const List<String> _sectionSuggestions = [
  'Sala', 'Terasa', 'Prizemlje', 'Sprat', 'Suteren',
  'Bašta', 'Privatna sala', 'Bar',
];

// ─── Menu item entry ──────────────────────────────────────────────────────────

class _MenuItemEntry {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  String category;
  XFile? imageFile;

  _MenuItemEntry({
    String name = '',
    String description = '',
    String price = '',
    String category = 'Glavno jelo',
    XFile? imageFile,
  })  : category = category,
        imageFile = imageFile,
        nameController = TextEditingController(text: name),
        descriptionController = TextEditingController(text: description),
        priceController = TextEditingController(text: price);

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }
}

// ─── Manager Sign Up Page ─────────────────────────────────────────────────────

class ManagerSignUpPage extends StatefulWidget {
  const ManagerSignUpPage({super.key});

  @override
  State<ManagerSignUpPage> createState() => _ManagerSignUpPageState();
}

class _ManagerSignUpPageState extends State<ManagerSignUpPage> {
  int _currentStep = 0;
  final int _totalSteps = 6;

  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  // ── Step 0 — Registration code ─────────────────────────────────────
  final _registrationCodeController = TextEditingController();
  bool _codeError = false;
  String? _codeErrorText;

  // ── Step 1 — Account info ──────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // ── Step 2 — Restaurant info ───────────────────────────────────────
  final _restaurantNameController = TextEditingController();
  final _restaurantAddressController = TextEditingController();
  final _restaurantPhoneController = TextEditingController();
  String? _selectedCity;
  final List<String> _selectedCuisines = [];

  final List<String> _cuisines = [
    'Azijska', 'Evropska', 'Tradicionalna', 'Brza hrana',
    'Mediteranska', 'Italijanska', 'Meksička', 'Ostalo',
  ];

  // ── Step 3 — Restaurant setup ──────────────────────────────────────
  final _descriptionController = TextEditingController();

  // Sections (replaces single tableCount)
  final List<_SectionEntry> _sections = [];

  // Total table count derived from sections
  int get _totalTableCount =>
      _sections.fold(0, (sum, s) => sum + s.tables);

  // Per-day working hours
  final Map<String, Map<String, dynamic>> _workingHours = {
    for (int i = 0; i < _daysOfWeek.length; i++)
      _daysOfWeek[i]: {
        'isOpen': i < 6,
        'open': '08:00',
        'close': '23:00',
      },
  };

  // ── Step 4 — Menu items ────────────────────────────────────────────
  final List<_MenuItemEntry> _menuItems = [];
  final List<String> _menuCategories = [
    'Hladna predjela', 'Topla predjela', 'Supe i čorbe', 'Salate',
    'Gotova jela', 'Jela po narudžbi', 'Ribe', 'Desert', 'Piće',
  ];

  XFile? _profileImageFile;
  String _profileImageUrl = '';
  XFile? _coverImageFile;
  String _coverImageUrl = '';
  final _profileImageUrlController = TextEditingController();
  final _coverImageUrlController = TextEditingController();

  @override
  void dispose() {
    _registrationCodeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _restaurantNameController.dispose();
    _restaurantAddressController.dispose();
    _restaurantPhoneController.dispose();
    _descriptionController.dispose();
    for (final s in _sections) s.dispose();
    for (final item in _menuItems) item.dispose();
    _profileImageUrlController.dispose();
    _coverImageUrlController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) { _validateCode(); return; }
    if (_currentStep == 1) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _errorMessage = 'Lozinke se ne podudaraju.');
        return;
      }
      if (_passwordController.text.length < 6) {
        setState(() => _errorMessage = 'Lozinka mora imati najmanje 6 znakova.');
        return;
      }
    }
    if (_currentStep == 2) {
      if (_selectedCity == null) {
        setState(() => _errorMessage = 'Molimo odaberite grad.');
        return;
      }
      if (_selectedCuisines.isEmpty) {
        setState(() => _errorMessage = 'Molimo odaberite barem jedan tip kuhinje.');
        return;
      }
    }
    if (_currentStep == 3) {
      if (_sections.isEmpty) {
        setState(() => _errorMessage = 'Dodajte barem jednu sekciju (npr. Sala).');
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
    }
    setState(() {
      _errorMessage = null;
      if (_currentStep < _totalSteps - 1) _currentStep++;
    });
  }

  void _previousStep() {
    if (_currentStep > 0) setState(() { _currentStep--; _errorMessage = null; });
  }

  Future<void> _validateCode() async {
    final code = _registrationCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() { _codeError = true; _codeErrorText = 'Molimo unesite registracijski kod.'; });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('registration_codes').doc(code).get();
      setState(() => _isLoading = false);
      if (!doc.exists) {
        setState(() { _codeError = true; _codeErrorText = 'Nevažeći kod.'; });
        return;
      }
      if (doc['used'] == true) {
        setState(() { _codeError = true; _codeErrorText = 'Ovaj kod je već iskorišten.'; });
        return;
      }
      setState(() { _codeError = false; _codeErrorText = null; _currentStep++; });
    } catch (e) {
      setState(() { _isLoading = false; _codeError = true; _codeErrorText = 'Greška pri provjeri koda.'; });
    }
  }

  Future<Map<String, double>?> _geocodeAddress(String address) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'BookitApp/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lng': double.parse(data[0]['lon']),
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _uploadMenuItemImage(
      XFile imageFile, String restaurantId, int index) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final ext = imageFile.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance
          .ref()
          .child('menu_items/$restaurantId/item_$index.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      return await ref.getDownloadURL();
    } catch (_) { return null; }
  }

  Future<String?> _uploadRestaurantImage(
    XFile file,
    String restaurantId,
    String name
  ) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance 
          .ref()
          .child('restaurants/$restaurantId/$name.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      return await ref.getDownloadURL();
    } catch (_) {
        return null;
    }
  }

  // Future<void> _handleSubmit() async {
  //   setState(() { _isLoading = true; _errorMessage = null; });

  //   final coords = await _geocodeAddress(
  //       _restaurantAddressController.text.trim());

  //   // Build sections list for Firestore
  //   final sectionsData = _sections
  //       .asMap()
  //       .entries
  //       .map((e) => e.value.toMap(e.key + 1))
  //       .toList();

  //   final error = await _authService.signUpManager(
  //     name: _nameController.text.trim(),
  //     email: _emailController.text.trim(),
  //     password: _passwordController.text.trim(),
  //     restaurantName: _restaurantNameController.text.trim(),
  //     restaurantAddress: _restaurantAddressController.text.trim(),
  //     restaurantPhone: _restaurantPhoneController.text.trim(),
  //     city: _selectedCity ?? '',
  //     cuisines: _selectedCuisines,
  //     tableCount: _totalTableCount,
  //     sections: sectionsData,
  //     workingHours: _workingHours,
  //     description: _descriptionController.text.trim(),
  //     registrationCode:
  //         _registrationCodeController.text.trim().toUpperCase(),
  //     lat: coords?['lat'],
  //     lng: coords?['lng'],
  //   );

  //   if (error != null) {
  //     setState(() {
  //       _isLoading = false;
  //       _errorMessage = error;
  //     });
  //     return;
  //   }

  //   // Mark code as used
  //   final code = _registrationCodeController.text.trim().toUpperCase();
  //   try {
  //     await FirebaseFirestore.instance
  //         .collection('registration_codes')
  //         .doc(code)
  //         .update({'used': true});
  //   } catch (_) {}

  //   // Upload menu items
  //   if (_menuItems.isNotEmpty) {
  //     try {
  //       final uid = await _authService.getCurrentUserId();
  //       if (uid != null) {
  //         final userDoc = await FirebaseFirestore.instance
  //             .collection('users').doc(uid).get();
  //         final restaurantId = userDoc.data()?['restaurantId'];
  //         if (restaurantId != null) {
  //           final menuRef = FirebaseFirestore.instance
  //               .collection('restaurants')
  //               .doc(restaurantId)
  //               .collection('menuItems');
  //           for (int i = 0; i < _menuItems.length; i++) {
  //             final item = _menuItems[i];
  //             final name = item.nameController.text.trim();
  //             if (name.isEmpty) continue;
  //             String? imageUrl;
  //             if (item.imageFile != null) {
  //               imageUrl = await _uploadMenuItemImage(
  //                   item.imageFile!, restaurantId, i);
  //             }
  //             await menuRef.add({
  //               'name': name,
  //               'description': item.descriptionController.text.trim(),
  //               'price': double.tryParse(
  //                       item.priceController.text.trim()) ??
  //                   0.0,
  //               'category': item.category,
  //               'imageUrl': imageUrl ?? '',
  //               'available': true,
  //             });
  //           }
  //         }
  //       }
  //     } catch (_) {}
  //   }

  //   if (!mounted) return;
  //   Navigator.pushReplacement(context,
  //       MaterialPageRoute(builder: (_) => const ManagerPendingPage()));
  // }

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final coords = await _geocodeAddress(
      _restaurantAddressController.text.trim(),
    );

    // Build section list for Firestore
    final sectionsData = _sections
        .asMap()
        .entries
        .map((e) => e.value.toMap(e.key + 1))
        .toList();
    
    final error = await _authService.signUpManager(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      restaurantName: _restaurantNameController.text.trim(),
      restaurantAddress: _restaurantAddressController.text.trim(),
      restaurantPhone: _restaurantPhoneController.text.trim(),
      city: _selectedCity ?? '',
      cuisines: _selectedCuisines,
      tableCount: _totalTableCount,
      sections: sectionsData,
      workingHours: _workingHours,
      description: _descriptionController.text.trim(),
      registrationCode: _registrationCodeController.text.trim().toUpperCase(),
      lat: coords?['lat'],
      lng: coords?['lng'],
    );

    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
      return;
    }

    // Mark code as used
    final code = _registrationCodeController.text.trim().toUpperCase();
    try {
      await FirebaseFirestore.instance 
          .collection('registration_codes')
          .doc(code)
          .update({'used': true});
    } catch (_) {}

    // Upload menu items + save "menuCategories" to restaurant doc
    try {
      final uid = await _authService.getCurrentUserId();
      
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance 
            .collection('users')
            .doc(uid)
            .get();
        
        final restaurantId = userDoc.data()?['restaurantId'];

        if (restaurantId != null) {

          // -- Save registration categories so the menu page can find items under correct tabs
          await FirebaseFirestore.instance 
              .collection('restaurants')
              .doc(restaurantId)
              .update({'menuCategories': _menuCategories});
          
          // -- Upload cover and profile photos
          String finalCoverUrl = _coverImageUrl;
          if (_coverImageFile != null) {
            final url = await _uploadRestaurantImage(
              _coverImageFile!,
              restaurantId,
              'cover'
            );
            if (url != null) finalCoverUrl = url;
          }

          String finalProfileUrl = _profileImageUrl;
          if (_profileImageFile != null) {
            final url = await _uploadRestaurantImage(
              _profileImageFile!,
              restaurantId,
              'profile'
            );
            if (url != null) finalProfileUrl = url;
          }

          if (finalCoverUrl.isNotEmpty || finalProfileUrl.isNotEmpty) {
            final updates = <String, dynamic>{};
            if (finalCoverUrl.isNotEmpty) updates['coverUrl'] = finalCoverUrl;
            if (finalProfileUrl.isNotEmpty) updates['imageUrl'] = finalProfileUrl;
            await FirebaseFirestore.instance 
                .collection('restaurants')
                .doc(restaurantId)
                .update(updates);
          }
          
          // -- Upload each menu item
          if (_menuItems.isNotEmpty) {
            final menuRef = FirebaseFirestore.instance
                .collection('restaurants')
                .doc(restaurantId)
                .collection('menuItems');
            
            for (int i = 0; i < _menuItems.length; i++) {
              final item = _menuItems[i];
              final name = item.nameController.text.trim();
              
              if (name.isEmpty) continue;

              String? imageUrl;
              if (item.imageFile != null) {
                imageUrl = await _uploadMenuItemImage(
                  item.imageFile!,
                  restaurantId, 
                  i
                );
              }

              await menuRef.add({
                'name': name,
                'description': item.descriptionController.text.trim(),
                'price': double.tryParse(
                  item.priceController.text.trim()
                ) ?? 0.0,
                'category': item.category,
                'imageUrl': imageUrl ?? '',
                'available': true,
              });
            }
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ManagerPendingPage()
      )
    );
  }

  Future<void> _pickTime(String day, bool isOpening) async {
    final current =
        _workingHours[day]![isOpening ? 'open' : 'close'] as String;
    final parts = current.split(':');
    final initial = TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));

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
        _workingHours[day]![isOpening ? 'open' : 'close'] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: _currentStep == 0
                      ? () => Navigator.pop(context)
                      : _previousStep,
                  child: Icon(Icons.arrow_back,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                      size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(_stepTitle(),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color)),
                ),
                Text('${_currentStep + 1}/$_totalSteps',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _totalSteps,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFCCD9B0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6B7C45)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_stepSubtitle(),
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color)),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCurrentStep(),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
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
                    Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFD94F4F)))),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_currentStep < _totalSteps - 1
                          ? _nextStep
                          : _handleSubmit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7C45),
                    disabledBackgroundColor: const Color(0xFFCCD9B0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _currentStep < _totalSteps - 1
                              ? 'Nastavi'
                              : 'Pošaljite zahtjev',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_currentStep) {
      case 0: return 'Registracijski kod';
      case 1: return 'Vaš nalog';
      case 2: return 'Vaš restoran';
      case 3: return 'Postavljanje';
      case 4: return 'Fotografije';
      case 5: return 'Meni';
      default: return '';
    }
  }

  String _stepSubtitle() {
    switch (_currentStep) {
      case 0: return 'Unesite kod koji ste dobili od Bookit tima.';
      case 1: return 'Kreirajte nalog menadžera restorana.';
      case 2: return 'Unesite osnovne informacije o restoranu.';
      case 3: return 'Dodajte sekcije, stolove i radno vrijeme.';
      case 4: return 'Dodajte fotografije restorana (opcionalno).';
      case 5: return 'Dodajte stavke menija (opcionalno).';
      default: return '';
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep0();
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      case 4: return _buildStep4Photos();
      case 5: return _buildStep4();
      default: return const SizedBox();
    }
  }

  // ── Step 0 ─────────────────────────────────────────────────────────

  Widget _buildStep0() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: const Color(0xFF6B7C45).withOpacity(0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.vpn_key_outlined,
              size: 36, color: Color(0xFF6B7C45)),
        ),
      ),
      const SizedBox(height: 20),
      Center(
        child: Text('Registracija je samo za\novlaštene partnere.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge!.color,
                height: 1.4)),
      ),
      const SizedBox(height: 6),
      Center(
        child: Text(
            'Unesite Vaš registracijski kod kako biste nastavili.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall!.color,
                height: 1.5)),
      ),
      const SizedBox(height: 32),
      _FieldLabel(label: 'Registracijski kod'),
      const SizedBox(height: 8),
      TextField(
        controller: _registrationCodeController,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
            color: Theme.of(context).textTheme.bodyLarge!.color),
        onChanged: (_) {
          if (_codeError) setState(() => _codeError = false);
        },
        decoration: InputDecoration(
          hintText: 'XXXXXXXX',
          hintStyle: TextStyle(
              color: Theme.of(context).textTheme.bodySmall!.color,
              fontSize: 18,
              letterSpacing: 3),
          prefixIcon: const Icon(Icons.vpn_key_outlined,
              size: 20, color: Color(0xFF6B7C45)),
          errorText: _codeError ? _codeErrorText : null,
          filled: true,
          fillColor: _codeError
              ? const Color(0xFFD94F4F).withOpacity(0.05)
              : Theme.of(context).colorScheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: _codeError
                      ? const Color(0xFFD94F4F)
                      : const Color(0xFFCCD9B0),
                  width: 1.2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: _codeError
                      ? const Color(0xFFD94F4F)
                      : const Color(0xFF6B7C45),
                  width: 1.8)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFD94F4F), width: 1.2)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFD94F4F), width: 1.8)),
        ),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
        ),
        child: Row(children: [
          const Icon(Icons.help_outline, size: 18, color: Color(0xFF8A9A7A)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Nemate registracijski kod?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge!.color)),
                const SizedBox(height: 2),
                Text('Kontaktirajte nas na partneri@bookit.ba',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color)),
              ])),
        ]),
      ),
      const SizedBox(height: 24),
      Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: RichText(
              text: TextSpan(
            text: 'Već imate nalog? ',
            style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall!.color),
            children: const [
              TextSpan(
                  text: 'Prijavite se',
                  style: TextStyle(
                      color: Color(0xFF6B7C45),
                      fontWeight: FontWeight.w600))
            ],
          )),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  // ── Step 1 ─────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label: 'Ime i prezime'),
      const SizedBox(height: 8),
      _InputField(
          controller: _nameController,
          hint: 'Ime i prezime',
          icon: Icons.person_outline),
      const SizedBox(height: 20),
      _FieldLabel(label: 'Email adresa'),
      const SizedBox(height: 8),
      _InputField(
          controller: _emailController,
          hint: 'email@restoran.ba',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 20),
      _FieldLabel(label: 'Lozinka'),
      const SizedBox(height: 8),
      _InputField(
        controller: _passwordController,
        hint: 'Minimalno 6 znakova',
        icon: Icons.lock_outline,
        obscureText: !_passwordVisible,
        suffixIcon: IconButton(
          icon: Icon(
              _passwordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Theme.of(context).textTheme.bodySmall!.color),
          onPressed: () =>
              setState(() => _passwordVisible = !_passwordVisible),
        ),
      ),
      const SizedBox(height: 20),
      _FieldLabel(label: 'Potvrdite lozinku'),
      const SizedBox(height: 8),
      _InputField(
        controller: _confirmPasswordController,
        hint: 'Ponovite lozinku',
        icon: Icons.lock_outline,
        obscureText: !_confirmPasswordVisible,
        suffixIcon: IconButton(
          icon: Icon(
              _confirmPasswordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Theme.of(context).textTheme.bodySmall!.color),
          onPressed: () => setState(
              () => _confirmPasswordVisible = !_confirmPasswordVisible),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  // ── Step 2 ─────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label: 'Naziv restorana'),
      const SizedBox(height: 8),
      _InputField(
          controller: _restaurantNameController,
          hint: 'Naziv Vašeg restorana',
          icon: Icons.storefront_outlined),
      const SizedBox(height: 20),
      _FieldLabel(label: 'Grad'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCity,
            isExpanded: true,
            hint: Text('Odaberite grad',
                style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodySmall!.color)),
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Color(0xFF8A9A7A)),
            style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).textTheme.bodyLarge!.color),
            dropdownColor: Theme.of(context).colorScheme.surface,
            onChanged: (value) => setState(() => _selectedCity = value),
            items: _bihCities
                .map((city) => DropdownMenuItem(
                      value: city,
                      child: Row(children: [
                        Icon(
                            city == 'Ostalo'
                                ? Icons.more_horiz
                                : Icons.location_city_outlined,
                            size: 18,
                            color: const Color(0xFF6B7C45)),
                        const SizedBox(width: 10),
                        Text(city),
                      ]),
                    ))
                .toList(),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _FieldLabel(label: 'Adresa restorana'),
      const SizedBox(height: 4),
      const Text('Koordinate će biti automatski preuzete.',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B7C45))),
      const SizedBox(height: 8),
      _InputField(
          controller: _restaurantAddressController,
          hint: 'Ulica bb, Grad',
          icon: Icons.location_on_outlined),
      const SizedBox(height: 20),
      _FieldLabel(label: 'Broj telefona'),
      const SizedBox(height: 8),
      _InputField(
          controller: _restaurantPhoneController,
          hint: '+387 33 000 000',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone),
      const SizedBox(height: 20),
      _FieldLabel(label: 'Tip kuhinje'),
      const SizedBox(height: 4),
      Text('Možete odabrati više tipova.',
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall!.color)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _cuisines.map((cuisine) {
          final selected = _selectedCuisines.contains(cuisine);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected)
                _selectedCuisines.remove(cuisine);
              else
                _selectedCuisines.add(cuisine);
              _errorMessage = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (selected) ...[
                  const Icon(Icons.check, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(cuisine,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
    ]);
  }

  // ── Step 3 — Sections + Working hours + Description ────────────────

  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Sections ───────────────────────────────────────────────
      _FieldLabel(label: 'Sekcije restorana'),
      const SizedBox(height: 4),
      Text('Dodajte sve prostore Vašeg restorana (sala, terasa, sprat...)',
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall!.color)),
      const SizedBox(height: 12),

      // Quick-add suggestions
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _sectionSuggestions.map((name) {
          final alreadyAdded = _sections
              .any((s) => s.nameController.text.trim() == name);
          return GestureDetector(
            onTap: alreadyAdded
                ? null
                : () => setState(() {
                      _sections.add(_SectionEntry(name: name));
                      _errorMessage = null;
                    }),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: alreadyAdded
                    ? const Color(0xFF6B7C45).withOpacity(0.1)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: alreadyAdded
                        ? const Color(0xFF6B7C45).withOpacity(0.4)
                        : const Color(0xFFCCD9B0),
                    width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    alreadyAdded ? Icons.check : Icons.add,
                    size: 14,
                    color: alreadyAdded
                        ? const Color(0xFF6B7C45)
                        : Theme.of(context).textTheme.bodySmall!.color),
                const SizedBox(width: 4),
                Text(name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: alreadyAdded
                            ? const Color(0xFF6B7C45)
                            : Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color)),
              ]),
            ),
          );
        }).toList(),
      ),

      const SizedBox(height: 14),

      // Section cards
      if (_sections.isNotEmpty) ...[
        ..._sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          return _SectionCard(
            section: section,
            index: index,
            onDelete: () => setState(() {
              section.dispose();
              _sections.removeAt(index);
            }),
            onTablesChanged: (val) =>
                setState(() => section.tables = val),
            onNameChanged: () => setState(() {}),
          );
        }),
        // Total summary
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6B7C45).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF6B7C45).withOpacity(0.3),
                width: 1.2),
          ),
          child: Row(children: [
            const Icon(Icons.table_restaurant_outlined,
                size: 18, color: Color(0xFF6B7C45)),
            const SizedBox(width: 10),
            Text('Ukupno stolova:',
                style: TextStyle(
                    fontSize: 14,
                    color:
                        Theme.of(context).textTheme.bodySmall!.color)),
            const Spacer(),
            Text('$_totalTableCount',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7C45))),
          ]),
        ),
      ],

      // Custom section button
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => setState(() {
          _sections.add(_SectionEntry());
          _errorMessage = null;
        }),
        icon: const Icon(Icons.add, size: 18, color: Color(0xFF6B7C45)),
        label: const Text('Dodaj sekciju',
            style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7C45),
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: Color(0xFF6B7C45), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      const SizedBox(height: 28),

      // ── Working hours per day ──────────────────────────────────
      _FieldLabel(label: 'Radno vrijeme po danima'),
      const SizedBox(height: 4),
      Text('Uključite dane i postavite radno vrijeme.',
          style: TextStyle(
              fontSize: 11,
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
            final index = entry.key;
            final day = entry.value;
            final isOpen = _workingHours[day]!['isOpen'] as bool;
            final openTime = _workingHours[day]!['open'] as String;
            final closeTime = _workingHours[day]!['close'] as String;
            final isLast = index == _daysOfWeek.length - 1;

            return Column(children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(children: [
                  Row(children: [
                    SizedBox(
                      width: 110,
                      child: Text(day,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isOpen
                                  ? Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color
                                  : Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .color)),
                    ),
                    Text(
                      isOpen ? 'Otvoreno' : 'Zatvoreno',
                      style: TextStyle(
                          fontSize: 12,
                          color: isOpen
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFD94F4F),
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Switch(
                      value: isOpen,
                      onChanged: (val) => setState(
                          () => _workingHours[day]!['isOpen'] = val),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFCCD9B0),
                                  width: 1.2),
                            ),
                            child: Row(children: [
                              const Icon(Icons.access_time_outlined,
                                  size: 16, color: Color(0xFF6B7C45)),
                              const SizedBox(width: 6),
                              Text(openTime,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color)),
                            ]),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('–',
                            style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color)),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickTime(day, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFCCD9B0),
                                  width: 1.2),
                            ),
                            child: Row(children: [
                              const Icon(Icons.access_time_outlined,
                                  size: 16, color: Color(0xFF6B7C45)),
                              const SizedBox(width: 6),
                              Text(closeTime,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
              if (!isLast)
                const Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: Color(0xFFECF2DF)),
            ]);
          }).toList(),
        ),
      ),

      const SizedBox(height: 24),

      // ── Description ────────────────────────────────────────────
      _FieldLabel(label: 'Opis restorana'),
      const SizedBox(height: 8),
      TextField(
        controller: _descriptionController,
        maxLines: 4,
        maxLength: 300,
        style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyLarge!.color),
        decoration: InputDecoration(
          hintText: 'Kratki opis Vašeg restorana, specijaliteti...',
          hintStyle: TextStyle(
              color: Theme.of(context).textTheme.bodySmall!.color,
              fontSize: 14),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.all(16),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFCCD9B0), width: 1.2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF6B7C45), width: 1.8)),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF6B7C45).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF6B7C45).withOpacity(0.3), width: 1.2),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF6B7C45)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Sekcije i radno vrijeme možete promijeniti kasnije u postavkama restorana.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                      height: 1.5))),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }

  // ── Step 4 — Menu items ────────────────────────────────────────────

  Widget _buildStep4() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF6B7C45).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF6B7C45).withOpacity(0.3), width: 1.2),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF6B7C45)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Ovaj korak je opcionalan. Stavke menija možete dodati i kasnije u postavkama restorana.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                      height: 1.5))),
        ]),
      ),
      const SizedBox(height: 20),
      ..._menuItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _MenuItemCard(
          item: item,
          index: index,
          categories: _menuCategories,
          onDelete: () =>
              setState(() { item.dispose(); _menuItems.removeAt(index); }),
          onImagePick: () async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                imageQuality: 75);
            if (picked != null) setState(() => item.imageFile = picked);
          },
          onCategoryChanged: (cat) => setState(() => item.category = cat),
          onRebuild: () => setState(() {}),
        );
      }),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () =>
              setState(() => _menuItems.add(_MenuItemEntry())),
          icon: const Icon(Icons.add, size: 18, color: Color(0xFF6B7C45)),
          label: const Text('Dodaj stavku menija',
              style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7C45),
                  fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFF6B7C45), width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildStep4Photos() {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6B7C45).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6B7C45).withOpacity(0.3), width: 1.2),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 16, color: Color(0xFF6B7C45)),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Ovaj korak je opcionalan. Fotografije možete dodati i kasnije u postavkama restorana.',
          style: TextStyle(fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium!.color, height: 1.5),
        )),
      ]),
    ),
    const SizedBox(height: 24),

    // ── Cover photo ────────────────────────────────────────────
    _FieldLabel(label: 'Naslovna fotografija'),
    const SizedBox(height: 4),
    Text('Prikazuje se kao pozadinska slika profila restorana.',
        style: TextStyle(fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall!.color)),
    const SizedBox(height: 10),
    GestureDetector(
      onTap: () async {
        final picked = await ImagePicker().pickImage(
            source: ImageSource.gallery, maxWidth: 1400, imageQuality: 80);
        if (picked != null) setState(() {
          _coverImageFile = picked;
          _coverImageUrl = '';
          _coverImageUrlController.clear();
        });
      },
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFD8E6C0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
        ),
        child: _coverImageFile != null
            ? FutureBuilder<dynamic>(
                future: _coverImageFile!.readAsBytes(),
                builder: (context, snap) {
                  if (snap.hasData)
                    return ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.memory(snap.data!, fit: BoxFit.cover,
                            width: double.infinity));
                  return const Center(child: CircularProgressIndicator(
                      color: Color(0xFF6B7C45), strokeWidth: 2));
                })
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_outlined,
                    size: 36, color: Color(0xFF6B7C45)),
                const SizedBox(height: 8),
                Text('Dodaj naslovnu fotografiju',
                    style: TextStyle(fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall!.color)),
              ]),
      ),
    ),
    const SizedBox(height: 10),
    _FieldLabel(label: 'Ili unesite link fotografije'),
    const SizedBox(height: 6),
    Row(children: [
      Expanded(
        child: _InputField(
          controller: _coverImageUrlController,
          hint: 'https://...',
          icon: Icons.link_outlined,
          keyboardType: TextInputType.url,
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () {
          final url = _coverImageUrlController.text.trim();
          if (url.isNotEmpty) setState(() {
            _coverImageUrl = url;
            _coverImageFile = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF6B7C45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('OK', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
    if (_coverImageUrl.isNotEmpty && _coverImageFile == null) ...[
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(_coverImageUrl, height: 100, width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFD94F4F).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('Nevažeći link.',
                  style: TextStyle(color: Color(0xFFD94F4F), fontSize: 13))),
            )),
      ),
    ],

    const SizedBox(height: 28),

    // ── Profile image ──────────────────────────────────────────
    _FieldLabel(label: 'Profilna fotografija'),
    const SizedBox(height: 4),
    Text('Prikazuje se kao avatar restorana.',
        style: TextStyle(fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall!.color)),
    const SizedBox(height: 12),
    Row(children: [
      GestureDetector(
        onTap: () async {
          final picked = await ImagePicker().pickImage(
              source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
          if (picked != null) setState(() {
            _profileImageFile = picked;
            _profileImageUrl = '';
            _profileImageUrlController.clear();
          });
        },
        child: Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFFD8E6C0),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFCCD9B0), width: 1.5),
          ),
          child: _profileImageFile != null
              ? FutureBuilder<dynamic>(
                  future: _profileImageFile!.readAsBytes(),
                  builder: (context, snap) {
                    if (snap.hasData)
                      return ClipOval(child: Image.memory(snap.data!,
                          fit: BoxFit.cover, width: 90, height: 90));
                    return const Center(child: CircularProgressIndicator(
                        color: Color(0xFF6B7C45), strokeWidth: 2));
                  })
              : const Icon(Icons.add_a_photo_outlined,
                  size: 28, color: Color(0xFF6B7C45)),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label: 'Ili unesite link'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: _InputField(
              controller: _profileImageUrlController,
              hint: 'https://...',
              icon: Icons.link_outlined,
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final url = _profileImageUrlController.text.trim();
              if (url.isNotEmpty) setState(() {
                _profileImageUrl = url;
                _profileImageFile = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7C45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('OK', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ])),
    ]),
    if (_profileImageUrl.isNotEmpty && _profileImageFile == null) ...[
      const SizedBox(height: 8),
      Row(children: [
        ClipOval(child: Image.network(_profileImageUrl,
            width: 56, height: 56, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(
                  color: Color(0xFFD94F4F), shape: BoxShape.circle),
              child: const Icon(Icons.broken_image, color: Colors.white, size: 20),
            ))),
        const SizedBox(width: 10),
        Text('Pregled linka', style: TextStyle(fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall!.color)),
      ]),
    ],
    const SizedBox(height: 24),
  ]);
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
    required this.section,
    required this.index,
    required this.onDelete,
    required this.onTablesChanged,
    required this.onNameChanged,
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7C45))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: section.nameController,
              onChanged: (_) => onNameChanged(),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge!.color),
              decoration: InputDecoration(
                hintText: 'Naziv sekcije (npr. Sala)',
                hintStyle: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall!.color),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFCCD9B0), width: 1.2)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF6B7C45), width: 1.8)),
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
              child: const Icon(Icons.delete_outline,
                  size: 16, color: Color(0xFFD94F4F)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.table_restaurant_outlined,
              size: 16,
              color: Theme.of(context).textTheme.bodySmall!.color),
          const SizedBox(width: 8),
          Text('Broj stolova:',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall!.color)),
          const Spacer(),
          _CounterButton(
            icon: Icons.remove,
            enabled: section.tables > 1,
            onTap: () => onTablesChanged(section.tables - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('${section.tables}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color)),
          ),
          _CounterButton(
            icon: Icons.add,
            enabled: section.tables < 100,
            onTap: () => onTablesChanged(section.tables + 1),
          ),
        ]),
      ]),
    );
  }
}

// ─── Menu item card ───────────────────────────────────────────────────────────

class _MenuItemCard extends StatefulWidget {
  final _MenuItemEntry item;
  final int index;
  final List<String> categories;
  final VoidCallback onDelete;
  final VoidCallback onImagePick;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onRebuild;

  const _MenuItemCard({
    required this.item, required this.index, required this.categories,
    required this.onDelete, required this.onImagePick,
    required this.onCategoryChanged, required this.onRebuild,
  });

  @override
  State<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<_MenuItemCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Stavka ${widget.index + 1}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall!.color)),
          const Spacer(),
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: const Color(0xFFD94F4F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline,
                  size: 16, color: Color(0xFFD94F4F)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: widget.onImagePick,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: const Color(0xFFD8E6C0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCCD9B0), width: 1.2)),
              child: widget.item.imageFile != null
                  ? FutureBuilder<dynamic>(
                      future: widget.item.imageFile!.readAsBytes(),
                      builder: (context, snap) {
                        if (snap.hasData)
                          return ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.memory(snap.data!, fit: BoxFit.cover));
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF6B7C45), strokeWidth: 2));
                      },
                    )
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          size: 24, color: Color(0xFF6B7C45)),
                      const SizedBox(height: 4),
                      Text('Slika',
                          style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .color)),
                    ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(children: [
            TextField(
              controller: widget.item.nameController,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyLarge!.color),
              decoration: _inputDecoration(context, 'Naziv jela'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.item.priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyLarge!.color),
              decoration: _inputDecoration(context, 'Cijena (KM)'),
            ),
          ])),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: widget.item.descriptionController,
          maxLines: 2,
          style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyLarge!.color),
          decoration: _inputDecoration(context, 'Opis (opcionalno)'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.categories.map((cat) {
            final selected = widget.item.category == cat;
            return GestureDetector(
              onTap: () => widget.onCategoryChanged(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6B7C45)
                      : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: selected
                          ? const Color(0xFF6B7C45)
                          : const Color(0xFFCCD9B0),
                      width: 1.2),
                ),
                child: Text(cat,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color)),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context).textTheme.bodySmall!.color,
            fontSize: 13),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCCD9B0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6B7C45), width: 1.8)),
      );
}

// ─── Counter button ───────────────────────────────────────────────────────────

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CounterButton(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF6B7C45)
                : const Color(0xFFCCD9B0),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodySmall!.color));
}

// ─── Input field ──────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).textTheme.bodyLarge!.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context).textTheme.bodySmall!.color,
            fontSize: 15),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7C45)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFFCCD9B0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF6B7C45), width: 1.8)),
      ),
    );
  }
}