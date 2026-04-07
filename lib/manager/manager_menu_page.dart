import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// ─── Menu item model ──────────────────────────────────────────────────────────

class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final bool isAvailable;
  final String imageUrl;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.isAvailable,
    this.imageUrl = '',
  });

  factory MenuItemModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MenuItemModel(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      price: (d['price'] ?? 0.0).toDouble(),
      category: d['category'] ?? '',
      isAvailable: d['available'] ?? true,
      imageUrl: d['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'available': isAvailable,
        'imageUrl': imageUrl,
      };
}

// ─── Default categories ───────────────────────────────────────────────────────

const List<String> _defaultCategories = [
  'Predjelo',
  'Glavno jelo',
  'Desert',
  'Piće',
];

// ─── Manager Menu Page ────────────────────────────────────────────────────────

class ManagerMenuPage extends StatefulWidget {
  const ManagerMenuPage({super.key});

  @override
  State<ManagerMenuPage> createState() => _ManagerMenuPageState();
}

class _ManagerMenuPageState extends State<ManagerMenuPage> {
  String? _restaurantId;
  bool _loadingRestaurant = true;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final restaurantId = userDoc.data()?['restaurantId'];
    if (restaurantId == null) {
      setState(() => _loadingRestaurant = false);
      return;
    }

    final restaurantDoc = await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .get();

    List<String> categories;
    final raw = restaurantDoc.data()?['menuCategories'];
    if (raw != null && raw is List && raw.isNotEmpty) {
      categories = raw.map((e) => e.toString()).toList();
    } else {
      categories = List.from(_defaultCategories);
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .update({'menuCategories': categories});
    }

    setState(() {
      _restaurantId = restaurantId;
      _categories = categories;
      _loadingRestaurant = false;
    });
  }

  Future<void> _saveCategories(List<String> updated) async {
    if (_restaurantId == null) return;
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(_restaurantId)
        .update({'menuCategories': updated});
    setState(() => _categories = updated);
  }

  CollectionReference get _menuRef => FirebaseFirestore.instance
      .collection('restaurants')
      .doc(_restaurantId)
      .collection('menuItems');

  Future<void> _toggleAvailability(MenuItemModel item) async {
    await _menuRef
        .doc(item.id)
        .update({'available': !item.isAvailable});
  }

  void _deleteItem(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Obrisati stavku?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        content: Text(
          'Da li ste sigurni da želite obrisati "${item.name}" iz jelovnika?',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium!.color,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Odustani',
                style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .color,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Delete image from Storage if exists
              if (item.imageUrl.isNotEmpty) {
                try {
                  await FirebaseStorage.instance
                      .refFromURL(item.imageUrl)
                      .delete();
                } catch (_) {}
              }
              await _menuRef.doc(item.id).delete();
            },
            child: const Text('Obriši',
                style: TextStyle(
                    color: Color(0xFFD94F4F),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openAddEditPage(
      {MenuItemModel? item, required String defaultCategory}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMenuItemPage(
          existingItem: item,
          defaultCategory: item == null ? defaultCategory : null,
          categories: _categories,
          restaurantId: _restaurantId!,
          onSave: (savedItem) async {
            if (savedItem.id.startsWith('new_')) {
              await _menuRef.add(savedItem.toFirestore());
            } else {
              await _menuRef
                  .doc(savedItem.id)
                  .update(savedItem.toFirestore());
            }
          },
        ),
      ),
    );
  }

  void _openManageCategories() {
    final working = List<String>.from(_categories);
    final newCatController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + 24,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Upravljanje kategorijama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dodajte ili uklonite kategorije jelovnika.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .color,
                ),
              ),
              const SizedBox(height: 16),
              ...working.asMap().entries.map((entry) {
                final index = entry.key;
                final cat = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFCCD9B0),
                        width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_handle,
                          size: 18, color: Color(0xFFCCD9B0)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(cat,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color)),
                      ),
                      GestureDetector(
                        onTap: working.length <= 1
                            ? null
                            : () => setSheetState(
                                () => working.removeAt(index)),
                        child: Icon(
                          Icons.remove_circle_outline,
                          size: 20,
                          color: working.length <= 1
                              ? const Color(0xFFCCD9B0)
                              : const Color(0xFFD94F4F),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newCatController,
                      style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color),
                      decoration: InputDecoration(
                        hintText: 'Nova kategorija...',
                        hintStyle: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .color,
                            fontSize: 14),
                        filled: true,
                        fillColor: Theme.of(context)
                            .scaffoldBackgroundColor,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFCCD9B0),
                              width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF6B7C45),
                              width: 1.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      final val = newCatController.text.trim();
                      if (val.isEmpty || working.contains(val))
                        return;
                      setSheetState(() {
                        working.add(val);
                        newCatController.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7C45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveCategories(working);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7C45),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Sačuvaj kategorije',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRestaurant || _categories.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF6B7C45), strokeWidth: 2.5),
        ),
      );
    }

    if (_restaurantId == null) {
      return Scaffold(
        body: Center(
          child: Text('Restoran nije pronađen.',
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .color)),
        ),
      );
    }

    return _MenuTabView(
      key: ValueKey(_categories.join(',')),
      categories: _categories,
      menuRef: _menuRef,
      restaurantId: _restaurantId!,
      onOpenAddEdit: _openAddEditPage,
      onDelete: _deleteItem,
      onToggleAvailability: _toggleAvailability,
      onManageCategories: _openManageCategories,
    );
  }
}

// ─── Tab view ─────────────────────────────────────────────────────────────────

class _MenuTabView extends StatefulWidget {
  final List<String> categories;
  final CollectionReference menuRef;
  final String restaurantId;
  final void Function(
      {MenuItemModel? item,
      required String defaultCategory}) onOpenAddEdit;
  final void Function(MenuItemModel) onDelete;
  final void Function(MenuItemModel) onToggleAvailability;
  final VoidCallback onManageCategories;

  const _MenuTabView({
    super.key,
    required this.categories,
    required this.menuRef,
    required this.restaurantId,
    required this.onOpenAddEdit,
    required this.onDelete,
    required this.onToggleAvailability,
    required this.onManageCategories,
  });

  @override
  State<_MenuTabView> createState() => _MenuTabViewState();
}

class _MenuTabViewState extends State<_MenuTabView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final cat = widget.categories[_tabController.index];
          widget.onOpenAddEdit(defaultCategory: cat);
        },
        backgroundColor: const Color(0xFF6B7C45),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .color,
                        size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Jelovnik',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .color,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onManageCategories,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7C45)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.tune,
                              size: 15,
                              color: Color(0xFF6B7C45)),
                          SizedBox(width: 5),
                          Text('Kategorije',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7C45))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Tab bar ──────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: IntrinsicWidth(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFCCD9B0)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    padding: const EdgeInsets.all(4),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(
                      color: const Color(0xFF6B7C45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .color,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle:
                        const TextStyle(fontSize: 13),
                    tabs: widget.categories
                        .map((cat) => Tab(text: cat))
                        .toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Tab content ──────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: widget.categories.map((category) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: widget.menuRef
                        .where('category', isEqualTo: category)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF6B7C45),
                              strokeWidth: 2.5),
                        );
                      }

                      final items = (snapshot.data?.docs ?? [])
                          .map((doc) =>
                              MenuItemModel.fromFirestore(doc))
                          .toList();

                      if (items.isEmpty) {
                        return _EmptyCategory(
                          category: category,
                          onAdd: () => widget.onOpenAddEdit(
                              defaultCategory: category),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _MenuItemCard(
                          item: items[index],
                          onEdit: () => widget.onOpenAddEdit(
                              item: items[index],
                              defaultCategory: category),
                          onDelete: () =>
                              widget.onDelete(items[index]),
                          onToggleAvailability: () =>
                              widget.onToggleAvailability(
                                  items[index]),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Menu item card ───────────────────────────────────────────────────────────

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleAvailability;

  const _MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleAvailability,
  });

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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dish image ─────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _ImagePlaceholder(),
                    )
                  : _ImagePlaceholder(),
            ),

            const SizedBox(width: 12),

            // ── Name + description + price ─────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .color,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${item.price.toStringAsFixed(2)} KM',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7C45),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onToggleAvailability,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.isAvailable
                                ? const Color(0xFF4CAF50)
                                    .withOpacity(0.1)
                                : const Color(0xFFD94F4F)
                                    .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.isAvailable
                                ? 'Dostupno'
                                : 'Nedostupno',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: item.isAvailable
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFD94F4F),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Edit / delete ──────────────────────────────────
            Column(
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7C45)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        size: 16, color: Color(0xFF6B7C45)),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD94F4F)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 16, color: Color(0xFFD94F4F)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Image placeholder (64x64) ───────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFFD8E6C0),
      child: const Center(
        child: Icon(Icons.restaurant,
            size: 28, color: Color(0xFF6B7C45)),
      ),
    );
  }
}

// ─── Empty category ───────────────────────────────────────────────────────────

class _EmptyCategory extends StatelessWidget {
  final String category;
  final VoidCallback onAdd;

  const _EmptyCategory(
      {required this.category, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu_outlined,
              size: 48, color: Color(0xFFCCD9B0)),
          const SizedBox(height: 12),
          Text(
            'Nema stavki u kategoriji "$category".',
            style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .color),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF6B7C45).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF6B7C45)
                        .withOpacity(0.4),
                    width: 1.2),
              ),
              child: const Text(
                '+ Dodaj prvu stavku',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7C45),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add / Edit Menu Item Page ────────────────────────────────────────────────

class AddMenuItemPage extends StatefulWidget {
  final MenuItemModel? existingItem;
  final String? defaultCategory;
  final List<String> categories;
  final String restaurantId;
  final Function(MenuItemModel) onSave;

  const AddMenuItemPage({
    super.key,
    this.existingItem,
    this.defaultCategory,
    required this.categories,
    required this.restaurantId,
    required this.onSave,
  });

  @override
  State<AddMenuItemPage> createState() => _AddMenuItemPageState();
}

class _AddMenuItemPageState extends State<AddMenuItemPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory;
  bool _isAvailable = true;
  bool _isSaving = false;

  XFile? _pickedImage;
  String _currentImageUrl = '';
  final _imageUrlController = TextEditingController();

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _nameController.text = item.name;
      _descriptionController.text = item.description;
      _priceController.text = item.price.toStringAsFixed(2);
      _selectedCategory = widget.categories.contains(item.category)
          ? item.category
          : widget.categories.first;
      _isAvailable = item.isAvailable;
      _currentImageUrl = item.imageUrl;
    } else {
      _selectedCategory = widget.defaultCategory ??
          widget.categories.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  // ── Pick image from gallery ────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  // ── Upload image to Firebase Storage ──────────────────────────────
  Future<String> _uploadImage(String itemId) async {
    if (_pickedImage == null) return _currentImageUrl;
    try {
      final bytes = await _pickedImage!.readAsBytes();
      final ext =
          _pickedImage!.name.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance.ref().child(
          'menu_items/${widget.restaurantId}/$itemId.$ext');
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$ext'),
      );
      return await ref.getDownloadURL();
    } catch (_) {
      return _currentImageUrl;
    }
  }

  // ── Remove image ───────────────────────────────────────────────────
  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _currentImageUrl = '';
      _imageUrlController.clear();
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty ||
        _selectedCategory == null) return;

    setState(() => _isSaving = true);

    // Use a temp ID for new items to name the image file
    final tempId = _isEditing
        ? widget.existingItem!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final imageUrl = await _uploadImage(tempId);

    final item = MenuItemModel(
      id: _isEditing ? widget.existingItem!.id : 'new_',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price:
          double.tryParse(_priceController.text.trim()) ?? 0.0,
      category: _selectedCategory!,
      isAvailable: _isAvailable,
      imageUrl: imageUrl,
    );

    await widget.onSave(item);

    setState(() => _isSaving = false);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        _pickedImage != null || _currentImageUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B7C45),
              disabledBackgroundColor: const Color(0xFFCCD9B0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    _isEditing
                        ? 'Sačuvaj izmjene'
                        : 'Dodaj stavku',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
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

              // ── Top bar ────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .color,
                        size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _isEditing ? 'Uredi stavku' : 'Nova stavka',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .color,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Image picker ───────────────────────────────────
              _FieldLabel(label: 'Slika jela (opciono)'),
              const SizedBox(height: 10),

              Row(
                children: [
                  // ── Preview ──────────────────────────────────
                  GestureDetector(
                    onTap: _pickImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: _pickedImage != null
                            ? FutureBuilder<List<int>>(
                                future: _pickedImage!
                                    .readAsBytes()
                                    .then((v) => v.toList()),
                                builder: (context, snap) {
                                  if (snap.hasData) {
                                    return Image.memory(
                                      snap.data!
                                          as dynamic,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return _PickerPlaceholder();
                                },
                              )
                            : _currentImageUrl.isNotEmpty
                                ? Image.network(
                                    _currentImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            _PickerPlaceholder(),
                                  )
                                : _PickerPlaceholder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // ── Buttons ───────────────────────────────────
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 18),
                        label: Text(hasImage
                            ? 'Promijeni sliku'
                            : 'Dodaj sliku'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF6B7C45),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (hasImage) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _removeImage,
                          icon: const Icon(Icons.delete_outline,
                              size: 16,
                              color: Color(0xFFD94F4F)),
                          label: const Text('Ukloni sliku',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFD94F4F))),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // -- Or enter image URL
              _FieldLabel(label: 'Ili unesite link slike'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _imageUrlController,
                      keyboardType: TextInputType.url,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                      decoration: InputDecoration(  
                        hintText: 'https://...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall!.color,
                          fontSize: 13
                        ),
                        prefixIcon: const Icon(
                          Icons.link_outlined,
                          size: 18,
                          color: Color(0xFF6B7C45)
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFCCD9B0),
                            width: 1.2
                          )
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF6B7C45),
                              width: 1.8
                        )
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: ()  {
                    final url = _imageUrlController.text.trim();
                    if (url.isNotEmpty) {
                      setState(() {
                        _currentImageUrl = url;
                        _pickedImage = null;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7C45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(  
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      )
                    ),
                  ),
                ),
              ]
            ),

              const SizedBox(height: 24),

              _FieldLabel(label: 'Naziv stavke'),
              const SizedBox(height: 8),
              _InputField(
                controller: _nameController,
                hint: 'npr. Roštilj mješoviti',
                icon: Icons.restaurant_outlined,
              ),

              const SizedBox(height: 20),

              _FieldLabel(label: 'Opis (opciono)'),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                maxLength: 150,
                style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .color),
                decoration: InputDecoration(
                  hintText: 'Kratki opis jela ili pića...',
                  hintStyle: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .color,
                      fontSize: 14),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFCCD9B0), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF6B7C45), width: 1.8),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _FieldLabel(label: 'Cijena (KM)'),
              const SizedBox(height: 8),
              _InputField(
                controller: _priceController,
                hint: '0.00',
                icon: Icons.attach_money_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true),
              ),

              const SizedBox(height: 20),

              _FieldLabel(label: 'Kategorija'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFCCD9B0), width: 1.2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Color(0xFF8A9A7A)),
                    style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .color),
                    dropdownColor:
                        Theme.of(context).colorScheme.surface,
                    onChanged: (value) => setState(
                        () => _selectedCategory = value),
                    items: widget.categories
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            ))
                        .toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Availability toggle ────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFCCD9B0), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 20, color: Color(0xFF6B7C45)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dostupnost',
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
                            _isAvailable
                                ? 'Vidljivo na jelovniku'
                                : 'Skriveno sa jelovnika',
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
                    Switch(
                      value: _isAvailable,
                      onChanged: (val) =>
                          setState(() => _isAvailable = val),
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF4CAF50),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor:
                          const Color(0xFFCCD9B0),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Picker placeholder ───────────────────────────────────────────────────────

class _PickerPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFD8E6C0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFCCD9B0), width: 1.2),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 28, color: Color(0xFF6B7C45)),
          SizedBox(height: 4),
          Text('Dodaj sliku',
              style: TextStyle(
                  fontSize: 10, color: Color(0xFF6B7C45))),
        ],
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).textTheme.bodySmall!.color,
      ),
    );
  }
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
      style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).textTheme.bodyLarge!.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color:
                Theme.of(context).textTheme.bodySmall!.color,
            fontSize: 15),
        prefixIcon: Icon(icon,
            size: 20, color: const Color(0xFF6B7C45)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFFCCD9B0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF6B7C45), width: 1.8),
        ),
      ),
    );
  }
}