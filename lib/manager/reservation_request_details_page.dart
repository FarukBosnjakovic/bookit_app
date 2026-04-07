import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:bookit/manager/manager_reservations_page.dart';
import 'package:bookit/models/manager_reservation_model.dart';

// ─── Reservation Request Details Page ────────────────────────────────────────

class ReservationRequestDetailsPage extends StatefulWidget {
  final ManagerReservationModel reservation;

  const ReservationRequestDetailsPage({
    super.key,
    required this.reservation,
  });

  @override
  State<ReservationRequestDetailsPage> createState() =>
      _ReservationRequestDetailsPageState();
}

class _ReservationRequestDetailsPageState
    extends State<ReservationRequestDetailsPage> {
  late String _currentStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.reservation.status;
  }

  // ── Write to Firestore then update local state ───────────────────────
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.reservation.id)
          .update({'status': newStatus});
      setState(() {
        _currentStatus = newStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Greška. Pokušajte ponovo.'),
          backgroundColor: const Color(0xFFD94F4F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleAccept() {
    showDialog(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Prihvatiti rezervaciju?',
        message:
            'Da li ste sigurni da želite prihvatiti rezervaciju za ${widget.reservation.guestName}?',
        confirmLabel: 'Prihvati',
        confirmColor: const Color(0xFF4CAF50),
        onConfirm: () {
          Navigator.pop(context);
          _updateStatus('confirmed');
        },
      ),
    );
  }

  void _handleDecline() {
    showDialog(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Odbiti rezervaciju?',
        message:
            'Da li ste sigurni da želite odbiti rezervaciju za ${widget.reservation.guestName}?',
        confirmLabel: 'Odbij',
        confirmColor: const Color(0xFFD94F4F),
        onConfirm: () {
          Navigator.pop(context);
          _updateStatus('cancelled');
        },
      ),
    );
  }

  Color _statusColor() {
    switch (_currentStatus) {
      case 'pending':   return const Color(0xFFE8B84B);
      case 'confirmed': return const Color(0xFF4CAF50);
      case 'cancelled': return const Color(0xFFD94F4F);
      default:          return const Color(0xFF8A9A7A);
    }
  }

  String _statusLabel() {
    switch (_currentStatus) {
      case 'pending':   return 'Na čekanju';
      case 'confirmed': return 'Potvrđeno';
      case 'cancelled': return 'Otkazano';
      default:          return _currentStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // ── Bottom action buttons (pending only) ─────────────────────────
      bottomNavigationBar: _currentStatus == 'pending'
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  // Decline
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _handleDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD94F4F),
                          side: const BorderSide(
                              color: Color(0xFFD94F4F), width: 1.8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Odbij',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Accept
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5),
                              )
                            : const Text(
                                'Prihvati rezervaciju',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Top bar ──────────────────────────────────────────────
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
                        'Detalji rezervacije',
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
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor().withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Guest info card ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SectionCard(
                  title: 'Informacije o gostu',
                  icon: Icons.person_outline,
                  children: [
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Ime i prezime',
                      value: r.guestName,
                    ),
                    const _RowDivider(),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Broj telefona',
                      value: r.guestPhone.isNotEmpty
                          ? r.guestPhone
                          : 'Nije dostupno',
                      valueColor: r.guestPhone.isNotEmpty
                          ? const Color(0xFF6B7C45)
                          : null,
                    ),
                    const _RowDivider(),
                    _DetailRow(
                      icon: Icons.people_outline,
                      label: 'Broj gostiju',
                      value:
                          '${r.guestCount} ${r.guestCount == 1 ? 'gost' : 'gosta'}',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Reservation info card ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SectionCard(
                  title: 'Detalji rezervacije',
                  icon: Icons.calendar_today_outlined,
                  children: [
                    _DetailRow(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Broj rezervacije',
                      value:
                          '#${r.id.substring(0, 8).toUpperCase()}',
                    ),
                    const _RowDivider(),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Datum',
                      value: r.formattedDate,
                    ),
                    const _RowDivider(),
                    _DetailRow(
                      icon: Icons.access_time_outlined,
                      label: 'Vrijeme',
                      value: r.time,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Status note ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StatusNote(status: _currentStatus),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status note ──────────────────────────────────────────────────────────────

class _StatusNote extends StatelessWidget {
  final String status;
  const _StatusNote({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late IconData icon;
    late String text;

    switch (status) {
      case 'confirmed':
        color = const Color(0xFF4CAF50);
        icon = Icons.check_circle_outline;
        text = 'Rezervacija je potvrđena. Gost je obaviješten.';
        break;
      case 'cancelled':
        color = const Color(0xFFD94F4F);
        icon = Icons.cancel_outlined;
        text = 'Rezervacija je odbijena. Gost je obaviješten.';
        break;
      default: // pending
        color = const Color(0xFFE8B84B);
        icon = Icons.info_outline;
        text =
            'Ova rezervacija čeka Vašu potvrdu. Gost će biti obaviješten čim prihvatite ili odbijete zahtjev.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium!.color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF6B7C45)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFECF2DF)),
          ...children,
        ],
      ),
    );
  }
}

// ─── Detail row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              color: valueColor ??
                  Theme.of(context).textTheme.bodyLarge!.color,
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
    return const Divider(
        height: 1, indent: 46, color: Color(0xFFECF2DF));
  }
}

// ─── Confirm dialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge!.color,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyMedium!.color,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Odustani',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall!.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          child: Text(
            confirmLabel,
            style: TextStyle(
                color: confirmColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}