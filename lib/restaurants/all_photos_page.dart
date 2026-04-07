import 'package:flutter/material.dart';

class AllPhotosPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String restaurantImageUrl;
  final List<dynamic> communityPhotos; // List<PhotoModel>

  const AllPhotosPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImageUrl,
    required this.communityPhotos,
  });

  @override
  State<AllPhotosPage> createState() => _AllPhotosPageState();
}

class _AllPhotosPageState extends State<AllPhotosPage> {
  int _filter = 0; // 0=Sve, 1=Restoran, 2=Gosti

  // Restaurant photo = the restaurant's own imageUrl
  List<String> get _restaurantPhotos =>
      widget.restaurantImageUrl.isNotEmpty ? [widget.restaurantImageUrl] : [];

  // Guest photos = community photos tagged source:'user'
  List<String> get _guestPhotos => widget.communityPhotos
      .where((p) => (p.source as String) == 'user')
      .map((p) => p.imageUrl as String)
      .toList();

  List<String> get _displayed {
    switch (_filter) {
      case 1: return _restaurantPhotos;
      case 2: return _guestPhotos;
      default: return [..._restaurantPhotos, ..._guestPhotos];
    }
  }

  void _openViewer(int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _Viewer(urls: _displayed, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final all = [..._restaurantPhotos, ..._guestPhotos];
    final displayed = _displayed;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, size: 24,
                      color: Theme.of(context).textTheme.bodyLarge!.color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(widget.restaurantName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge!.color)),
                ),
              ]),
            ),

            // ── Filter chips ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Wrap(spacing: 8, children: [
                _Chip(label: 'Sve (${all.length})',
                    selected: _filter == 0, onTap: () => setState(() => _filter = 0)),
                _Chip(label: 'Restoran (${_restaurantPhotos.length})',
                    selected: _filter == 1, onTap: () => setState(() => _filter = 1)),
                _Chip(label: 'Gosti (${_guestPhotos.length})',
                    selected: _filter == 2, onTap: () => setState(() => _filter = 2)),
              ]),
            ),

            const Divider(height: 1, color: Color(0xFFCCD9B0)),
            const SizedBox(height: 4),

            // ── Grid ─────────────────────────────────────────────
            Expanded(
              child: displayed.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.photo_library_outlined, size: 52, color: Color(0xFFCCD9B0)),
                      const SizedBox(height: 14),
                      Text('Nema slika.', style: TextStyle(fontSize: 15,
                          color: Theme.of(context).textTheme.bodySmall!.color)),
                    ]))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 4,
                        mainAxisSpacing: 4, childAspectRatio: 1,
                      ),
                      itemCount: displayed.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => _openViewer(i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(displayed[i], fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFD8E6C0),
                                  child: const Icon(Icons.broken_image,
                                      size: 28, color: Color(0xFF6B7C45)))),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6B7C45) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF6B7C45) : const Color(0xFFCCD9B0),
            width: 1.5,
          ),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Theme.of(context).textTheme.bodyLarge!.color)),
      ),
    );
  }
}

class _Viewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _Viewer({required this.urls, required this.initialIndex});

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late int _current;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.urls.length}',
            style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _ctrl, itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: Image.network(widget.urls[i], fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                  color: Colors.white54, size: 48))),
        ),
      ),
    );
  }
}