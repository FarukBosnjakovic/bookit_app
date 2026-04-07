import 'package:flutter/material.dart';

class MenuPage extends StatelessWidget {
  final String restaurantId;
  final String restaurantName;
  final List<dynamic> menuItems; // List<MenuItemModel>
  final List<String> categories;

  const MenuPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.menuItems,
    required this.categories,
  });

  List<String> _getCategories() {
    if (categories.isNotEmpty) return categories;
    final seen = <String>{};
    return menuItems
        .map((i) => i.category as String)
        .where((c) => c.isNotEmpty && seen.add(c))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cats = _getCategories();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, size: 24,
                      color: Theme.of(context).textTheme.bodyLarge!.color),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Jelovnik', style: TextStyle(fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color)),
                  Text(restaurantName, style: TextStyle(fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall!.color)),
                ]),
              ]),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFCCD9B0)),

            // ── Menu ─────────────────────────────────────────────
            Expanded(
              child: menuItems.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.restaurant_menu_outlined,
                          size: 52, color: Color(0xFFCCD9B0)),
                      const SizedBox(height: 14),
                      Text('Jelovnik nije dostupan.', style: TextStyle(fontSize: 15,
                          color: Theme.of(context).textTheme.bodySmall!.color)),
                    ]))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: cats.isEmpty
                          ? [_CategoryCard(category: null, items: menuItems, context: context)]
                          : cats.map((cat) {
                              final catItems = menuItems
                                  .where((i) => i.category == cat)
                                  .toList();
                              if (catItems.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _CategoryCard(
                                    category: cat, items: catItems, context: context),
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

class _CategoryCard extends StatelessWidget {
  final String? category;
  final List<dynamic> items;
  final BuildContext context;

  const _CategoryCard({
    required this.category,
    required this.items,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCD9B0), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (category != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(category!, style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).textTheme.bodyLarge!.color)),
          ),
          const Divider(height: 1, color: Color(0xFFCCD9B0)),
        ],
        ...items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ItemRow(item: item),
            ),
            if (!isLast)
              const Divider(height: 1, indent: 16, endIndent: 16,
                  color: Color(0xFFECF2DF)),
          ]);
        }),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final dynamic item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name as String, style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge!.color)),
            if ((item.description as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.description as String, style: TextStyle(fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall!.color, height: 1.4)),
            ],
            const SizedBox(height: 8),
            Text('${(item.price as double).toStringAsFixed(2)} KM',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7C45))),
          ]),
        ),
        if ((item.imageUrl as String).isNotEmpty) ...[
          const SizedBox(width: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(item.imageUrl as String,
                width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 80, height: 80, color: const Color(0xFFD8E6C0),
                    child: const Icon(Icons.restaurant, size: 28,
                        color: Color(0xFF6B7C45)))),
          ),
        ],
      ]),
    );
  }
}