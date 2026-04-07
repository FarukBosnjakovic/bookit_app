import 'dart:io';
import 'package:bookit/restaurants/restaurants_bookings_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class BookingDetailsPage extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailsPage({
    super.key,
    required this.booking,
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  bool _isCancelling = false;
  bool _isSharing = false;

  final ScreenshotController _screenshotController = ScreenshotController();

  // ── Restaurant data ────────────────────────────────────────────────
  String _restaurantName = '';
  String _restaurantAddress = '';
  String _restaurantImageUrl = '';
  bool _loadingRestaurant = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    setState(() {
      _restaurantName = widget.booking.restaurantName;
      _restaurantAddress = widget.booking.restaurantAddress;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.booking.restaurantId)
          .get();

      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _restaurantName = (d['name'] as String?) ?? widget.booking.restaurantName;
          _restaurantAddress = (d['address'] as String?) ?? widget.booking.restaurantAddress;
          _restaurantImageUrl = (d['imageUrl'] as String?) ?? '';
          _loadingRestaurant = false;
        });
      } else {
        setState(() => _loadingRestaurant = false);
      }
    } catch (_) {
      setState(() => _loadingRestaurant = false);
    }
  }

  // ── Share booking as image ─────────────────────────────────────────
  Future<void> _shareBooking() async {
    setState(() => _isSharing = true);
    try {
      final image = await _screenshotController.capture(pixelRatio: 2.5);
      if (image == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bookit_rezervacija.png');
      await file.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Rezervacija u $_restaurantName — ${widget.booking.formattedDate} u ${widget.booking.time}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Greška pri dijeljenju rezervacije.'),
          backgroundColor: const Color(0xFFD94F4F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return const Color(0xFF4CAF50);
      case 'cancelled': return const Color(0xFFD94F4F);
      default:          return const Color(0xFFE8B84B);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Potvrđeno';
      case 'cancelled': return 'Otkazano';
      default:          return 'Na čekanju';
    }
  }

  Future<void> _cancelBooking() async {
    setState(() => _isCancelling = true);
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.booking.id)
          .update({'status': 'cancelled'});

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isCancelling = false);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Greška pri otkazivanju rezervacije.'),
          backgroundColor: const Color(0xFFD94F4F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Otkazati rezervaciju?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
        content: Text(
          'Da li ste sigurni da želite otkazati rezervaciju u restoranu $_restaurantName?',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium!.color,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nazad',
                style: TextStyle(color: Color(0xFF6B7C45), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: _cancelBooking,
            child: const Text('Otkaži rezervaciju',
                style: TextStyle(color: Color(0xFFD94F4F), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final canCancel = b.status == 'pending' || b.status == 'confirmed';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // ── Top bar ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(Icons.arrow_back,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                                size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Detalji rezervacije',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                            ),
                          ),
                          // ── Share button ─────────────────────────
                          GestureDetector(
                            onTap: _isSharing ? null : _shareBooking,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B7C45).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _isSharing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Color(0xFF6B7C45), strokeWidth: 2),
                                    )
                                  : const Icon(Icons.share_outlined,
                                      size: 20, color: Color(0xFF6B7C45)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Screenshottable card ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // ── Restaurant card ────────────────────
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: _loadingRestaurant
                                            ? Container(
                                                color: const Color(0xFFD8E6C0),
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 20, height: 20,
                                                    child: CircularProgressIndicator(
                                                        color: Color(0xFF6B7C45),
                                                        strokeWidth: 2),
                                                  ),
                                                ),
                                              )
                                            : _restaurantImageUrl.isNotEmpty
                                                ? Image.network(
                                                    _restaurantImageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                        _RestaurantPlaceholder(),
                                                  )
                                                : _RestaurantPlaceholder(),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _loadingRestaurant
                                              ? Container(
                                                  height: 16, width: 120,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFD8E6C0),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                )
                                              : Text(
                                                  _restaurantName.isNotEmpty
                                                      ? _restaurantName
                                                      : 'Nepoznat restoran',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                          const SizedBox(height: 6),
                                          _loadingRestaurant
                                              ? Container(
                                                  height: 12, width: 160,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFD8E6C0),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                )
                                              : Row(
                                                  children: [
                                                    const Icon(Icons.location_on_outlined,
                                                        size: 13, color: Color(0xFF8A9A7A)),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        _restaurantAddress,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Theme.of(context)
                                                              .textTheme
                                                              .bodySmall!
                                                              .color,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _statusColor(b.status).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _statusLabel(b.status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _statusColor(b.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Divider(height: 1, color: Color(0xFFCCD9B0)),

                              // ── Booking info ───────────────────────
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Informacije o rezervaciji',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _DetailRow(
                                      icon: Icons.confirmation_number_outlined,
                                      label: 'Broj rezervacije',
                                      value: '#${b.id.substring(0, 8).toUpperCase()}',
                                    ),
                                    const _RowDivider(),
                                    _DetailRow(
                                      icon: Icons.calendar_today_outlined,
                                      label: 'Datum',
                                      value: b.formattedDate,
                                    ),
                                    const _RowDivider(),
                                    _DetailRow(
                                      icon: Icons.access_time_outlined,
                                      label: 'Vrijeme',
                                      value: b.time,
                                    ),
                                    const _RowDivider(),
                                    _DetailRow(
                                      icon: Icons.people_outline,
                                      label: 'Broj gostiju',
                                      value: '${b.guestCount} ${b.guestCount == 1 ? 'gost' : 'gosta'}',
                                    ),
                                    if (b.sectionName.isNotEmpty) ...[
                                      const _RowDivider(),
                                      _DetailRow(
                                        icon: Icons.table_restaurant_outlined,
                                        label: 'Sekcija',
                                        value: b.sectionName,
                                      ),
                                    ],

                                    // ── BookIt branding on screenshot ──
                                    const SizedBox(height: 20),
                                    const Divider(height: 1, color: Color(0xFFCCD9B0)),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.restaurant_menu,
                                            size: 14, color: Color(0xFF6B7C45)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'BookIt rezervacija',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall!
                                                .color,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Info note ────────────────────────────────────
                    if (canCancel)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7C45).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF6B7C45).withOpacity(0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 18, color: Color(0xFF6B7C45)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Molimo Vas da otkažete rezervaciju najmanje 2 sata prije dogovorenog termina.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .color,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Cancel button ────────────────────────────────────────
            if (canCancel)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _isCancelling ? null : _showCancelDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD94F4F),
                      disabledForegroundColor:
                          const Color(0xFFD94F4F).withOpacity(0.4),
                      side: BorderSide(
                        color: _isCancelling
                            ? const Color(0xFFD94F4F).withOpacity(0.4)
                            : const Color(0xFFD94F4F),
                        width: 1.8,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Color(0xFFD94F4F), strokeWidth: 2.5),
                          )
                        : const Text(
                            'Otkaži rezervaciju',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
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

// ─── Restaurant image placeholder ────────────────────────────────────────────

class _RestaurantPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD8E6C0),
      child: const Center(
        child: Icon(Icons.restaurant, size: 30, color: Color(0xFF6B7C45)),
      ),
    );
  }
}

// ─── Detail row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7C45)),
          const SizedBox(width: 12),
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
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Row divider ──────────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFCCD9B0));
  }
}