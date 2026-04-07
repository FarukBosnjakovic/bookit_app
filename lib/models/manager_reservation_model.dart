import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerReservationModel {
  final String id;
  final String guestName;
  final String guestPhone;
  final DateTime date;
  final String time;
  final int guestCount;
  final String status;

  const ManagerReservationModel({
    required this.id,
    required this.guestName,
    required this.guestPhone,
    required this.date,
    required this.time,
    required this.guestCount,
    required this.status,
  });

  factory ManagerReservationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['date'] as Timestamp?;
    return ManagerReservationModel(
      id: doc.id,
      guestName: d['userName'] ?? 'Nepoznat gost',
      guestPhone: d['userPhone'] ?? '',
      date: ts?.toDate() ?? DateTime.now(),
      time: d['time'] ?? '',
      guestCount: d['guestCount'] ?? 1,
      status: d['status'] ?? 'pending',
    );
  }

  String get formattedDate {
    const months = [
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Juni',
      'Juli', 'August', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];
    return '${date.day}. ${months[date.month - 1]} ${date.year}.';
  }
}