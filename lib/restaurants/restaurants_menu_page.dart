import 'package:flutter/material.dart';

// -- Menu Item
// TODO: This will be fetched from Firebase Firestore when database is set up

class MenuItemModel {
  final String name;
  final String category;
  final double price;
  final String imageUrl;

  const MenuItemModel({
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
  });
}


// ─── Mock menu items simulating a Firebase Firestore response ─────────────────
// TODO: Remove and replace with a real Firestore fetch when Firebase is set up.

const List<MenuItemModel> mockMenuItems = [
  MenuItemModel(
    name: 'Naziv jela 1',
    category: 'Predjela',
    price: 12.50,
    imageUrl: '',
  ),
  MenuItemModel(
    name: 'Naziv jela 2',
    category: 'Glavno jelo',
    price: 28.00,
    imageUrl: '',
  ),
  MenuItemModel(
    name: 'Naziv jela 3',
    category: 'Glavno jelo',
    price: 32.00,
    imageUrl: '',
  ),
  MenuItemModel(
    name: 'Naziv jela 4',
    category: 'Deserti',
    price: 8.50,
    imageUrl: '',
  ),
];


// -- Restaurant Menu Page

class RestaurantMenuPage extends StatelessWidget {
  // TODO: When Firebase is ready, pass the restaurant ID and fetch
  // menu items from Firestore collection 'restaurants/{id}/menu'.
  final List<MenuItemModel> menuItems;

  const RestaurantMenuPage({
    super.key,
    this.menuItems = mockMenuItems,
  });

  @override  
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFFF0F5E4),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // -- Top Bar with back arrow and title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1E2A1A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Jelovnik',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2A1A),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // -- Menu Items list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: menuItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _MenuItemCard(item: menuItems[index]);
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}


// -- Menu item card

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;

  const _MenuItemCard({required this.item});

  @override 
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0,3),
          ),
        ],
      ),

      child: Row(
        children: [
          // -- Item image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(14),
            ),
            child: SizedBox(
              width: 80,
              height: 80,
              // TODO: Replace with Image.network(item.imageUrl) when
              // Firebase Storage URLs are available.
              child: item.imageUrl.isNotEmpty
                ? Image.network(item.imageUrl, fit: BoxFit.cover)
                : Container(
                    color: const Color(0xFFD8E6C0),
                    child: const Icon(
                      Icons.fastfood_outlined,
                      size: 32,
                      color: Color(0xFF6B7C45),
                    ),
                ),

            ),
          ),

          const SizedBox(width: 14),

          // -- Item name and category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E2A1A),
                  ),
                ),

                const SizedBox(height: 4),
                Text(
                  item.category,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A9A7A),
                  ),
                ),
              ],
            ),
          ),

          // -- Price
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${item.price.toStringAsFixed(2)} KM',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E2A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}