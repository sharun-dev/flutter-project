import 'package:flutter/material.dart';

class BookingConfirmationPage extends StatelessWidget {
  final String busName;
  final DateTime fromDate;
  final DateTime toDate;
  final String fromPlace;
  final String toPlace;
  final int totalPrice;
  final String paymentMethod;
  final String bookingToken;
  final DateTime cancelUntil;

  const BookingConfirmationPage({
    super.key,
    required this.busName,
    required this.fromDate,
    required this.toDate,
    required this.fromPlace,
    required this.toPlace,
    required this.totalPrice,
    required this.paymentMethod,
    required this.bookingToken,
    required this.cancelUntil,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmed'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bus: $busName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('From: $fromPlace'),
            Text('To: $toPlace'),
            Text(
              'Dates: ${fromDate.day}/${fromDate.month}/${fromDate.year} - ${toDate.day}/${toDate.month}/${toDate.year}',
            ),
            Text('Total Price: ₹$totalPrice'),
            const SizedBox(height: 12),
            Text(
              'Payment Method: $paymentMethod',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Booking Token:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(
              bookingToken,
              style: const TextStyle(fontSize: 16, color: Colors.deepPurple),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'You can cancel your booking until: ${cancelUntil.day}/${cancelUntil.month}/${cancelUntil.year}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Terms and Conditions:\n- Cancellation allowed until the above date.\n- Payment must be completed before travel.\n- Show this token in Home > Bookings for confirmation.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
