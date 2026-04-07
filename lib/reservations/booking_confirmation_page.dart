import 'package:flutter/material.dart';
import 'package:bookit/home/home_page.dart';
import 'package:bookit/restaurants/restaurants_bookings_page.dart';
import 'package:add_2_calendar/add_2_calendar.dart';


class BookingConfirmationPage extends StatelessWidget {
  final String bookingId;
  final String restaurantName;
  final String restaurantAddress;
  final String date;
  final DateTime dateTime;
  final String time;
  final int guestCount;

  const BookingConfirmationPage({
    super.key,
    required this.bookingId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.date,
    required this.dateTime,
    required this.time,
    required this.guestCount,
  });

  // -- Build Calendar Event
  void _addToCalendar() {
    final timeParts = time.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 12;
    final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;

    final startDate = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      hour,
      minute,
    );
    final endDate = startDate.add(const Duration(hours: 2));

    final event = Event(
      title: 'Rezervacija - $restaurantName',
      description: 'Rezervacija za $guestCount ${guestCount == 1 ? 'gosta' : 'gostiju'} u $restaurantName',
      location: restaurantAddress,
      startDate: startDate,
      endDate: endDate,
    );

    Add2Calendar.addEvent2Cal(event);
  }

  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFF6B7C45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 52,
                ),
              ),

              const SizedBox(height: 42),

              // -- Title
              Text(
                'Rezervacija poslana!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                'Vaša rezervacija je na čekanju. Restoran će je potvrditi uskoro.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall!.color,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              // -- Bookings detail card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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

                    // -- Restaurant Information
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8E6C0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            size: 24,
                            color: Color(0xFF6B7C45)
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurantName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge!.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                restaurantAddress,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).textTheme.bodySmall!.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(
                      height: 1,
                      color: Color(0xFFCCD9B0)
                    ),
                    const SizedBox(height: 20),

                    // Detail Rows
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Datum',
                      value: date,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.access_time_outlined,
                      label: 'Vrijeme',
                      value: time,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.people_outline,
                      label: 'Broj gostiju',
                      value: '$guestCount ${guestCount == 1 ? 'gost' : 'gosta'}',
                    ),
                    const SizedBox(height: 14),

                    // -- Pending status badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8B84B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.hourglass_top_rounded,
                            size: 14,
                            color: Color(0xFFE8B84B)
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Na čekanju — čekamo potvrdu restorana',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE8B84B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // -- Add to Calendar Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _addToCalendar,
                  icon: const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: Color(0xFF6B7C45)
                  ),
                  label: const Text(
                    'Dodaj u kalendar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7C45),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF6B7C45),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // -- Back home button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage()
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B7C45),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(
                        color: Color(0xFF6B7C45),
                        width: 1.8,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Nazad na početnu',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),

              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RestaurantBookingsPage()
                    ),
                    (route) => route.isFirst,
                  );
                },
                child: const Text(
                  'Pogledajte sve rezervacije',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7C45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}


// -- Detail Row

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override 
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF6B7C45)
        ),
        const SizedBox(width: 12),
        Text(
          '$label',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodySmall!.color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}