// ignore_for_file: unused_field

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingPaymentScreen extends StatefulWidget {
  final String busName;
  final int totalPrice;
  final String agencyName;
  final String agencyId;
  final String upiId;
  final String mobileNumber;
  final DateTime bookingDate;
  final String location;
  final int daysDuration;
  const BookingPaymentScreen({
    super.key,
    required this.busName,
    required this.totalPrice,
    required this.agencyName,
    required this.agencyId,
    required this.upiId,
    required this.mobileNumber,
    required this.bookingDate,
    required this.location,
    required this.daysDuration,
  });

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  String? _selectedPayment;
  Map<String, dynamic>? _userData;
  StreamSubscription<DocumentSnapshot>? _bookingStatusSub;
  String? _bookingDocId;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _bookingStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      setState(() {
        _userData = doc.data();
      });
    }
  }

  Future<void> _handleBooking() async {
    // Show loading dialog (no OK button)
    _isDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                "Your booking has been considered and you will be notified of confirmation soon.",
              ),
            ),
          ],
        ),
      ),
    );

    // Save booking info to Firestore with status 'pending'
    final bookingRef = await FirebaseFirestore.instance
        .collection('agencies')
        .doc(widget.agencyId)
        .collection('bookings')
        .add({
          'busName': widget.busName,
          'totalPrice': widget.totalPrice,
          'upiId': widget.upiId,
          'mobileNumber': widget.mobileNumber,
          'bookingDate': widget.bookingDate,
          'location': widget.location,
          'daysDuration': widget.daysDuration,
          'paymentMethod': _selectedPayment,
          // Only store necessary user fields
          'user': _userData == null
              ? null
              : {
                  'name': _userData!['name'],
                  'email': _userData!['email'],
                  'phone': _userData!['phone'],
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                },
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'userId': FirebaseAuth.instance.currentUser?.uid,
        });

    setState(() {
      _bookingDocId = bookingRef.id;
    });

    // Listen for status changes
    _bookingStatusSub = bookingRef.snapshots().listen((doc) {
      final status = doc['status'];
      if (!_isDialogOpen) return;
      if (status == 'accepted') {
        if (Navigator.canPop(context)) Navigator.pop(context); // Close dialog
        _isDialogOpen = false;
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Congratulations!'),
            content: const Text(
              'Your booking has been successfully completed',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                   
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        _bookingStatusSub?.cancel();
      } else if (status == 'rejected') {
        if (Navigator.canPop(context)) Navigator.pop(context); // Close dialog
        _isDialogOpen = false;
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sorry'),
            content: const Text('Sorry, your booking is not confirmed'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        _bookingStatusSub?.cancel();
      }
    });
  }

  // Add this method to handle cancellation
  Future<void> _cancelBooking() async {
    if (_bookingDocId == null) return;

    // Fetch the booking document to check status
    final bookingDoc = await FirebaseFirestore.instance
        .collection('agencies')
        .doc(widget.agencyId)
        .collection('bookings')
        .doc(_bookingDocId)
        .get();

    final status = bookingDoc.data()?['status'];
    if (status == 'accepted' || status == 'rejected' || status == 'cancelled') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cannot be cancelled at this stage.')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('agencies')
        .doc(widget.agencyId)
        .collection('bookings')
        .doc(_bookingDocId)
        .update({'status': 'cancelled'});

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      '/agencyDashboard', // Make sure this route exists in your app
      arguments: {'userData': _userData, 'bookingId': _bookingDocId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment & Confirmation',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6A1B9A),
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF3E5F5), Color(0xFFE1F5FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  size: 48,
                                  color: Color(0xFF6A1B9A),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.busName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: Color(0xFF6A1B9A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Divider(thickness: 1.2),
                          const SizedBox(height: 8),
                          _infoRow(
                            Icons.attach_money,
                            'Advance Price',
                            '₹${widget.totalPrice}',
                          ),
                          _infoRow(
                            Icons.account_balance_wallet,
                            'UPI ID',
                            widget.upiId,
                          ),
                          _infoRow(
                            Icons.phone,
                            'Mobile Number',
                            widget.mobileNumber,
                          ),
                          _infoRow(
                            Icons.calendar_today,
                            'Booking Date',
                            '${widget.bookingDate.toLocal().toString().split(' ')[0]}',
                          ),
                          _infoRow(
                            Icons.location_on,
                            'Location',
                            widget.location,
                          ),
                          _infoRow(
                            Icons.timelapse,
                            'Duration',
                            '${widget.daysDuration} days',
                          ),
                          const SizedBox(height: 18),
                          Divider(thickness: 1.2),
                          const SizedBox(height: 10),
                          const Text(
                            'Select Payment Method:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _customRadio('UPI', Icons.qr_code),
                          _customRadio('Credit/Debit Card', Icons.credit_card),
                          _customRadio('Wallet', Icons.account_balance_wallet),
                          _customRadio('Cash', Icons.money),
                          const SizedBox(height: 18),
                          Divider(thickness: 1.2),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.yellow[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange,
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: const Text(
                                    'Terms and Conditions:\n'
                                    '- Advance payment is required for the booking to be confirmed\n'
                                    '- Cancellation allowed until 24 hours before booking date.\n'
                                    '- Payment must be completed before travel.\n'
                                    '- After cancelling the booking, the refund will be processed\n'
                                    '- Show booking confirmation at boarding.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                              onPressed:
                                  _selectedPayment == null || _userData == null
                                      ? null
                                      : _handleBooking,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BFAE),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              label: const Text(
                                'Confirm Booking',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.white,
                              ),
                              onPressed:
                                  _bookingDocId == null ? null : _cancelBooking,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                              ),
                              label: const Text(
                                'Cancel Booking',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper for info rows with icons
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF6A1B9A), size: 22),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for custom radio tiles with icons
  Widget _customRadio(String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedPayment = value),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedPayment,
              onChanged: (val) => setState(() => _selectedPayment = val),
              activeColor: Color(0xFF00BFAE),
            ),
            Icon(icon, color: Color(0xFF6A1B9A)),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}