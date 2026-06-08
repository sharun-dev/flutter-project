import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intl/intl.dart';
import 'chat_page.dart';
import 'booking_payment_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusDetailsPage extends StatefulWidget {
  final String agencyId;
  final String busDocId;
  const BusDetailsPage({
    super.key,
    required this.agencyId,
    required this.busDocId,
  });

  @override
  State<BusDetailsPage> createState() => _BusDetailsPageState();
}

class _BusDetailsPageState extends State<BusDetailsPage> {
  final _commentController = TextEditingController();

  int _currentImage = 0;
  DateTime? _fromDate, _toDate;
  int? _numDays;
  String? _fromPlace, _toPlace;
  Map<String, dynamic>? _bus;
  List<Map<String, dynamic>> _otherBuses = [];
  bool _loading = true;

  Map<String, dynamic>? _specialOffer;

  // Store booked dates as string for reliable comparison
  Set<String> _bookedDates = {};

  bool _bookingInProgress = false;
  @override
  void initState() {
    super.initState();

    _fetchBusDetails();
    _fetchSpecialOffer();
  }

  // --- Fetch booked dates and store as string ---
  Future<void> _fetchBookedDates() async {
    try {
      if (_bus == null) return;
      final snap =
          await FirebaseFirestore.instance
              .collection('agencies')
              .doc(widget.agencyId)
              .collection('buses')
              .doc(widget.busDocId)
              .collection('bookings')
              .get();

      final Set<String> booked = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        final bookingDate = (data['bookingDate'] as Timestamp).toDate();
        final daysDuration = data['daysDuration'] ?? 1;

        for (int i = 0; i < daysDuration; i++) {
          final d = bookingDate.add(Duration(days: i));
          final dateStr =
              "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
          booked.add(dateStr);
        }
      }
      setState(() {
        _bookedDates = booked;
      });
    } catch (e, st) {
      print('Error in _fetchBookedDates: $e\n$st');
    }
  }

  // --- Add Booking to Firestore ---
  Future<void> _addBookingToFirestore() async {
    if (_fromDate == null || _numDays == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('agencies')
          .doc(widget.agencyId)
          .collection('buses') // <-- Add this line
          .doc(widget.busDocId)
          .collection('bookings')
          .add({
            'busDocId': widget.busDocId,
            'bookingDate': Timestamp.fromDate(_fromDate!),
            'daysDuration': _numDays,
            'fromPlace': _fromPlace,
            'toPlace': _toPlace,
            'createdAt': FieldValue.serverTimestamp(),
            // add other fields as needed
          });
      await _fetchBookedDates(); // Refresh booked dates in calendar
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add booking. Please try again.'),
        ),
      );
    }
  }

  // Fetch special offer from Firestore
  Future<void> _fetchSpecialOffer() async {
    final offerSnap =
        await FirebaseFirestore.instance
            .collection('agencies')
            .doc(widget.agencyId)
            .collection('offers')
            .where('busDocId', isEqualTo: widget.busDocId)
            .limit(1)
            .get();

    if (offerSnap.docs.isNotEmpty) {
      setState(() {
        _specialOffer = offerSnap.docs.first.data();
      });
    }
  }

  Future<void> _fetchBusDetails() async {
    try {
      setState(() => _loading = true);
      final busDoc =
          await FirebaseFirestore.instance
              .collection('agencies')
              .doc(widget.agencyId)
              .collection('buses')
              .doc(widget.busDocId)
              .get();

      final agencyBusesSnap =
          await FirebaseFirestore.instance
              .collection('agencies')
              .doc(widget.agencyId)
              .collection('buses')
              .get();

      final busData = busDoc.data() ?? {};
      final otherBuses =
          agencyBusesSnap.docs
              .where((d) => d.id != widget.busDocId)
              .map((d) => {...d.data(), 'docId': d.id})
              .toList();
      final agencyDoc =
          await FirebaseFirestore.instance
              .collection('agencies')
              .doc(widget.agencyId)
              .get();
      final agencyEmail = agencyDoc.data()?['email'] ?? '';
      final agencyPhone = agencyDoc.data()?['phone'] ?? '';
      final agencyUpiId = agencyDoc.data()?['upiId'] ?? '';
      final agencyMobile = agencyDoc.data()?['agencyMobile'] ?? '';

      setState(() {
        _bus = {
          ...busData,
          'docId': widget.busDocId,
          'agencyEmail': agencyEmail,
          'agencyPhone': agencyPhone,
          'agencyName': agencyDoc.data()?['agencyName'] ?? '',
          'upiId': agencyUpiId,
          'agencyMobile': agencyMobile,
        };
        _otherBuses = otherBuses;

        _loading = false;
      });

      // Fetch booked dates AFTER _bus is loaded
      await _fetchBookedDates();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load bus details.')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // --- Modified: Show calendar with booked dates marked/disabled ---
  Future<void> _pickDaysDialog() async {
    DateTime now = DateTime.now();
    DateTime? pickedFrom = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (date) {
        // Convert to string for comparison
        final dateStr =
            "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        return !_bookedDates.contains(dateStr);
      },
      helpText: 'Select Start Date (Booked dates are disabled)',
    );

    if (pickedFrom == null) return;

    int tempNumDays = _numDays ?? 1;
    final daysController = TextEditingController(text: tempNumDays.toString());

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: const Text('Select Booking Days'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          'Start Date: ${DateFormat('dd MMM yyyy').format(pickedFrom)}',
                        ),
                      ),
                      Row(
                        children: [
                          const Text('How many days?'),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 50,
                            child: TextField(
                              controller: daysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null &&
                                    parsed > 0 &&
                                    parsed <= 30) {
                                  setStateDialog(() => tempNumDays = parsed);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'End Date: ${DateFormat('dd MMM yyyy').format(pickedFrom.add(Duration(days: tempNumDays - 1)))}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (!_isDateRangeAvailable(pickedFrom, tempNumDays))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Selected range includes booked dates!',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          _isDateRangeAvailable(pickedFrom, tempNumDays)
                              ? () {
                                setState(() {
                                  _fromDate = pickedFrom;
                                  _numDays = tempNumDays;
                                  _toDate = pickedFrom.add(
                                    Duration(days: tempNumDays - 1),
                                  );
                                });
                                Navigator.pop(context);
                                _showFromToDialog();
                              }
                              : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Helper to check if selected range is available
  bool _isDateRangeAvailable(DateTime start, int numDays) {
    for (int i = 0; i < numDays; i++) {
      final d = start.add(Duration(days: i));
      final dateStr =
          "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      if (_bookedDates.contains(dateStr)) return false;
    }
    return true;
  }

  // --- UPDATED: Enter Route Details with validation ---
  Future<void> _showFromToDialog() async {
    final fromController = TextEditingController(text: _fromPlace ?? "");
    final toController = TextEditingController(text: _toPlace ?? "");
    String? errorText;

    bool _isValid(String value) {
      // Only allow letters, numbers, spaces
      final validRegExp = RegExp(r'^[a-zA-Z0-9 ]+$');
      return validRegExp.hasMatch(value);
    }

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: const Text('Enter Route Details'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: fromController,
                        decoration: const InputDecoration(labelText: 'From'),
                      ),
                      TextField(
                        controller: toController,
                        decoration: const InputDecoration(labelText: 'To'),
                      ),
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final from = fromController.text.trim();
                        final to = toController.text.trim();
                        if (from.isEmpty || to.isEmpty) {
                          setStateDialog(() {
                            errorText = 'Both fields are required.';
                          });
                          return;
                        }
                        if (from.toLowerCase() == to.toLowerCase()) {
                          setStateDialog(() {
                            errorText = 'From and To cannot be the same.';
                          });
                          return;
                        }
                        if (!_isValid(from) || !_isValid(to)) {
                          setStateDialog(() {
                            errorText = 'No special characters allowed.';
                          });
                          return;
                        }
                        setState(() {
                          _fromPlace = from;
                          _toPlace = to;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Bus Details Modal ---
  void _showBusDetailsModal(BuildContext context) {
    final bus = _bus ?? {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.95,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Text(
                        'Details of Bus and Driver',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: const Color(0xFF6A1B9A),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (bus['imageUrl'] != null)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              bus['imageUrl'],
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (c, e, s) => Container(
                                    height: 160,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.directions_bus,
                                      size: 60,
                                    ),
                                  ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 18),
                      _busDetailRow('Bus Number', bus['badgeNumber']),

                      _busDetailRow('Driver ID', bus['driverId']),
                      if (bus['driverIdImageUrl'] != null)
                        _imageRow('Driver ID Image', bus['driverIdImageUrl']),

                      _busDetailRow(
                        'Emergency Contact',
                        bus['emergencyContact'],
                      ),

                      _busDetailRow('Bus Fitness', bus['fitness']),
                      if (bus['fitnessImageUrl'] != null)
                        _imageRow('Fitness Image', bus['fitnessImageUrl']),

                      _busDetailRow('Insurance', bus['insurance']),
                      if (bus['insuranceImageUrl'] != null)
                        _imageRow('Insurance Image', bus['insuranceImageUrl']),

                      _busDetailRow(
                        'Driver\'s licenseNumber',
                        bus['licenseNumber'],
                      ),

                      _busDetailRow(
                        'Permit Under Control (PUC) Certificate',
                        bus['permit'],
                      ),
                      if (bus['permitImageUrl'] != null)
                        _imageRow('Permit Image', bus['permitImageUrl']),

                      _busDetailRow('Pollution Certificate', bus['puc']),
                      if (bus['puImageUrl'] != null)
                        _imageRow('PUC Image', bus['pucImageUrl']),

                      _busDetailRow(
                        'Vehicle Registration Certificate',
                        bus['rc'],
                      ),
                      if (bus['rcImageUrl'] != null)
                        _imageRow('RC Image', bus['rcImageUrl']),

                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _busDetailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageRow(String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (_) => Dialog(
                        backgroundColor: Colors.black,
                        insetPadding: EdgeInsets.zero,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Stack(
                            children: [
                              Center(
                                child: InteractiveViewer(
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder:
                                        (c, e, s) => Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white,
                                            size: 80,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 24,
                                right: 24,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (c, e, s) => Container(
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = const Color(0xFF6A1B9A);
    final chatColor = Colors.green;
    final bus = _bus ?? {};
    final images =
        (bus['images'] as List<dynamic>?)?.cast<String>() ??
        (bus['image'] != null ? [bus['image']] : <String>[]);
    String? email = bus['agencyEmail'];
    String? phone = bus['agencyPhone'];
    if ((email == null || email.isEmpty || phone == null || phone.isEmpty) &&
        bus['contact'] != null) {
      for (var line in bus['contact'].toString().split('\n')) {
        if ((email == null || email.isEmpty) && line.contains('@')) {
          email = line.trim();
        }
        if ((phone == null || phone.isEmpty) && line.contains('+91')) {
          phone = line.trim();
        }
      }
    }
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: mainColor,
          title: Text(
            bus['name'] ?? '',
            style: const TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // --- ADVANCE PRICE CALCULATION ---
    num? advancePrice;
    if (_fromDate != null &&
        _toDate != null &&
        bus['ratePerDay'] != null &&
        bus['ratePerDay'] > 0 &&
        _numDays != null) {
      advancePrice = (bus['ratePerDay'] * _numDays! / 7);
    }
    // --- END ADVANCE PRICE CALCULATION ---

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        title: Text(
          bus['name'] ?? '',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // --- IMAGE CAROUSEL AT THE VERY TOP ---
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                if (images.isNotEmpty)
                  PageView.builder(
                    itemCount: images.length,
                    controller: PageController(
                      initialPage: _currentImage,
                      viewportFraction: 1,
                    ),
                    onPageChanged: (idx) => setState(() => _currentImage = idx),
                    itemBuilder:
                        (context, idx) => Image.network(
                          images[idx],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                width: double.infinity,
                                height: 220,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.directions_bus,
                                  size: 60,
                                ),
                              ),
                        ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 220,
                    color: Colors.grey[300],
                    child: const Icon(Icons.directions_bus, size: 60),
                  ),
                if (images.length > 1)
                  Positioned(
                    bottom: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (idx) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: _currentImage == idx ? 16 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                _currentImage == idx
                                    ? mainColor
                                    : Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SPECIAL OFFER SECTION ---
                if (_specialOffer != null)
                  Card(
                    color: Colors.yellow[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_specialOffer!['imageUrl'] != null &&
                            _specialOffer!['imageUrl'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: Image.network(
                              _specialOffer!['imageUrl'],
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => Container(
                                    width: 90,
                                    height: 90,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.local_offer,
                                      color: Colors.orange,
                                      size: 40,
                                    ),
                                  ),
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _specialOffer!['title'] ?? 'Special Offer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                    fontSize: 17,
                                  ),
                                ),
                                if (_specialOffer!['description'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _specialOffer!['description'],
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // --- END SPECIAL OFFER SECTION ---

                // --- BUS NAME & RATING ---
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bus['name'],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          Text(
                            bus['rating'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  bus['place'],
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // --- AGENCY DESCRIPTION & ABOUT ---
                if (bus['agencyDescription'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      bus['agencyDescription'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (bus['about'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      bus['about'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                // --- BUS DESCRIPTION ---
                if (bus['description'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      bus['description'],
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),

                // --- BUS FEATURES CARD ---
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  color: Colors.blueGrey[50],
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bus['seatCapacity'] != null &&
                            bus['seatCapacity'] > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.event_seat,
                                color: Colors.teal,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Seat Capacity: ${bus['seatCapacity']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        if (bus['features'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              children:
                                  (bus['features'] as List<dynamic>)
                                      .map(
                                        (f) => Chip(
                                          label: Text(
                                            f,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        if (bus['jblCount'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'JBL Speakers: ${bus['jblCount']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // --- PRICE CARD ---
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  color: Colors.deepPurple[50],
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${bus['price']}/km',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                            fontSize: 18,
                          ),
                        ),
                        if (bus['ratePerDay'] != null && bus['ratePerDay'] > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '₹${bus['ratePerDay']}/day',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // --- CONTACT CARD ---
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  color: Colors.teal[50],
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bus['agencyEmail'] != null &&
                            bus['agencyEmail'].toString().isNotEmpty)
                          _contactRow(
                            icon: Icons.email,
                            text: bus['agencyEmail'],
                            color: Colors.deepPurple,
                            onTap: () => _launchEmail(bus['agencyEmail']),
                          ),
                        if (bus['agencyPhone'] != null &&
                            bus['agencyPhone'].toString().isNotEmpty)
                          _contactRow(
                            icon: Icons.phone,
                            text: bus['agencyPhone'],
                            color: Colors.teal,
                            onTap: () => _launchPhone(bus['agencyPhone']),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.info_outline),
                              label: const Text("More details about Bus"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 1,
                              ),
                              onPressed: () => _showBusDetailsModal(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- OTHER BUSES ---
                if (_otherBuses.isNotEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    color: Colors.orange[50],
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Other Buses from this Agency:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ..._otherBuses.map(
                            (b) => Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading:
                                    (b['images'] != null &&
                                            b['images'] is List &&
                                            (b['images'] as List).isNotEmpty)
                                        ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            b['images'][0],
                                          ),
                                        )
                                        : const CircleAvatar(
                                          child: Icon(Icons.directions_bus),
                                        ),
                                title: Text(b['name']),
                                subtitle: Text('₹${b['price']}/km'),
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => BusDetailsPage(
                                            agencyId: widget.agencyId,
                                            busDocId: b['docId'],
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- SELECTED DATES & ROUTE ---
                if (_fromDate != null && _toDate != null)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    color: Colors.blue[50],
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.date_range,
                                color: mainColor,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${DateFormat('dd MMM yyyy').format(_fromDate!)} to ${DateFormat('dd MMM yyyy').format(_toDate!)}'
                                ' (${_numDays ?? 1} days)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_fromPlace != null && _toPlace != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$_fromPlace → $_toPlace'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // --- ADVANCE PRICE ---
                if (advancePrice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Advance Price: ₹${advancePrice.round()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),

                // --- SELECT DAYS BUTTON ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 28),
                      label: const Text(
                        'Select Days For Booking',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        try {
                          print('Fetching booked dates...');
                          await _fetchBookedDates();
                          print('Opening pick days dialog...');
                          await _pickDaysDialog();
                          print('Dialog closed.');
                        } catch (e, st) {
                          print('Error in booking flow: $e\n$st');
                        }
                      },
                    ),
                  ),
                ),

                // --- AGENCY REVIEWS SECTION ---
                const SizedBox(height: 18),
                const Text(
                  'Reviews:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.deepPurple,
                  ),
                ),

                StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('agencies')
                          .doc(widget.agencyId)
                          .collection('reviews')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final reviews = snapshot.data!.docs;
                    if (reviews.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text('No reviews for this agency yet.'),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      itemBuilder: (context, idx) {
                        final data =
                            reviews[idx].data() as Map<String, dynamic>;
                        final userEmail = data['userEmail'] ?? '';
                        // Try to get userId if available, else fallback to email
                        final userId = data['userId'];
                        return FutureBuilder<DocumentSnapshot>(
                          future:
                              userId != null
                                  ? FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .get()
                                  : FirebaseFirestore.instance
                                      .collection('users')
                                      .where('email', isEqualTo: userEmail)
                                      .limit(1)
                                      .get()
                                      .then(
                                        (snap) =>
                                            snap.docs.isNotEmpty
                                                ? snap.docs.first.reference
                                                        .get()
                                                    as Future<
                                                      DocumentSnapshot<Object?>
                                                    >
                                                : Future.value(null),
                                      ),
                          builder: (context, userSnapshot) {
                            String userName = 'User';
                            if (userSnapshot.hasData &&
                                userSnapshot.data != null) {
                              final userData =
                                  userSnapshot.data!.data()
                                      as Map<String, dynamic>?;
                              userName = userData?['name'] ?? userEmail;
                            } else {
                              userName = userEmail;
                            }
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : 'U',
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(userName),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    Text(
                                      (data['rating'] ?? 5.0).toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['review'] ?? ''),
                                    if (data['timestamp'] != null)
                                      Text(
                                        (data['timestamp'] as Timestamp)
                                            .toDate()
                                            .toString()
                                            .split('.')[0],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ChatPage(
                            busName: bus['name'],
                            isOnline: true,
                            agencyId: widget.agencyId,
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: chatColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    (_fromDate != null &&
                            _toDate != null &&
                            _fromPlace != null &&
                            _toPlace != null)
                        // After booking is confirmed, add booking to Firestore
                        ? () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => BookingPaymentScreen(
                                    busName: bus['name'],
                                    totalPrice:
                                        advancePrice != null
                                            ? advancePrice.round()
                                            : 0,
                                    agencyName: bus['agencyName'] ?? '',
                                    upiId: bus['upiId'] ?? '',
                                    mobileNumber: bus['agencyMobile'] ?? '',
                                    bookingDate: _fromDate ?? DateTime.now(),
                                    location:
                                        '${_fromPlace ?? ''} → ${_toPlace ?? ''}',
                                    daysDuration: _numDays ?? 1,
                                    agencyId: widget.agencyId,
                                  ),
                            ),
                          );
                          if (result == true) {
                            await _addBookingToFirestore();
                          }
                          setState(() => _bookingInProgress = false);
                        }
                        : null,
                icon:
                    _bookingInProgress
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.directions_bus),
                label: const Text('Book Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
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
