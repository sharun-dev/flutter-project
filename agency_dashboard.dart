import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agency_info.dart';
import 'agency_chat_page.dart';
import "package:http/http.dart" as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;

// --- Terms and Conditions Page ---
class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        backgroundColor: Color(0xFF6A1B9A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: SingleChildScrollView(
          child: Text(
            '''Terms and conditions,
1. The required information about users and agencies must be given at the registration time. 
2. The information will be accessed and verified by the admin. 
3. The requests without proper information may be rejected by the admin.
4. The users and agencies are connected through the app after the admin verification. 
5. The agencies must give their proper details about their vehicle and their minimum charge for the trip according to per day. 
6. The compliant about the app like ( agencies dealings, additional payment,time delay, etc) can be directly reported to admin.''',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

// --- Report Page ---
class ReportPage extends StatefulWidget {
  final String reportType; // "app" or "user"
  const ReportPage({super.key, required this.reportType});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  Future<void> _submitReport() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('reports').add({
      'from': 'agency',
      'type': widget.reportType,
      'text': text,
      'agencyId': user?.uid,
      'agencyEmail': user?.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => _loading = false);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.reportType == 'app' ? 'Report about App' : 'Report about User',
        ),
        backgroundColor: Color(0xFF6A1B9A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Type your report here',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00BFAE),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const Text(
                          'Register',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

String getChatRoomId(String userId, String agencyId) {
  return userId.compareTo(agencyId) < 0
      ? '${userId}_$agencyId'
      : '${agencyId}_$userId';
}

class AgencyDashboardScreen extends StatefulWidget {
  final String agencyName;
  final String ownerName;
  final String email;
  final String phone;
  final String address;
  final String regNumber;
  final Map<String, String> pickedFiles;
  final String? userId;
  final String agencyId;

  const AgencyDashboardScreen({
    super.key,
    required this.agencyName,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.address,
    required this.regNumber,
    this.pickedFiles = const {},
    this.userId,
    required this.agencyId,
  });

  @override
  State<AgencyDashboardScreen> createState() => _AgencyDashboardScreenState();
}

class _AgencyDashboardScreenState extends State<AgencyDashboardScreen> {
  final Color _mainColor = const Color(0xFF6A1B9A);

  int _selectedIndex = 0;
  // Verification state
  bool _isVerified = false;
  bool _loadingVerification = true;

  // UPI ID and Mobile Number controllers
  final _upiIdController = TextEditingController();
  final _agencyMobileController = TextEditingController();

  // --- Added driver & vehicle fields controllers ---
  final _driverIdController = TextEditingController();
  final _licenseController = TextEditingController();
  final _badgeNumberController = TextEditingController();
  final _rcController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _permitController = TextEditingController();
  final _fitnessController = TextEditingController();
  final _pucController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  // --- Added image fields ---
  File? _driverIdImage;
  File? _rcImage;
  File? _insuranceImage;
  File? _permitImage;
  File? _pucImage;
  File? _fitnessImage;

  // Special Offer
  File? _offerImage;
  final _offerDescController = TextEditingController();
  final List<Map<String, dynamic>> _specialOffers = [];
  int? _editingOfferIndex;

  // Bus fields
  final _busNameController = TextEditingController();
  final _busDescController = TextEditingController();
  final _busEmailController = TextEditingController();
  final _busPhoneController = TextEditingController();
  final _busPlaceController = TextEditingController();
  final _busRateController = TextEditingController(); // Rate per km
  final _busRatePerDayController = TextEditingController(); // Rate per day
  final _busSeatCapacityController = TextEditingController();
  List<File> _busImages = [];
  final List<Map<String, dynamic>> _buses = [];
  int? _editingBusIndex;

  // --- Image pickers ---
  Future<void> _pickDriverIdImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _driverIdImage = File(result.files.single.path!));
    }
  }

  Future<void> _pickRCImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _rcImage = File(result.files.single.path!));
    }
  }

  Future<void> _pickInsuranceImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _insuranceImage = File(result.files.single.path!));
    }
  }

  Future<void> _pickPermitImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _permitImage = File(result.files.single.path!));
    }
  }

  Future<void> _pickPUCImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _pucImage = File(result.files.single.path!));
    }
  }

  Future<void> _pickFitnessImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() => _fitnessImage = File(result.files.single.path!));
    }
  }

  // Cloudinary upload function
  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'dkz5wmhge';
      final uploadPreset =
          dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'agency_uploads';

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request =
          http.MultipartRequest('POST', url)
            ..fields['upload_preset'] = uploadPreset
            ..files.add(
              await http.MultipartFile.fromPath('file', imageFile.path),
            );

      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = jsonDecode(resStr);
        return data['secure_url'];
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image upload failed: ${response.statusCode}'),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload error: $e')));
      }
      return null;
    }
  }

  void _deleteUserDetailsFromBooking(DocumentReference bookingRef) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete User Details'),
            content: const Text(
              'Are you sure you want to delete the user details from this booking?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (confirm == true) {
      try {
        // Get booking data before deleting
        final bookingSnap = await bookingRef.get();
        final bookingData = bookingSnap.data() as Map<String, dynamic>?;

        // Delete from agency's bookings
        await bookingRef.delete();

        // Also delete from user's bookings if possible
        if (bookingData != null && bookingData['userId'] != null) {
          final userId = bookingData['userId'];
          final busName = bookingData['busName'];
          final agencyId = bookingData['agencyId'] ?? widget.agencyId;

          // Find the user's booking document with matching busName and agencyId
          final userBookings =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('bookings')
                  .where('busName', isEqualTo: busName)
                  .where('agencyId', isEqualTo: agencyId)
                  .get();

          for (final doc in userBookings.docs) {
            await doc.reference.delete();
          }
        }

        // Also delete from bus's bookings subcollection
        if (bookingData != null &&
            bookingData['busDocId'] != null &&
            bookingData['bookingDate'] != null &&
            bookingData['createdAt'] != null) {
          final busDocId = bookingData['busDocId'];
          final bookingDate = bookingData['bookingDate'];
          final createdAt = bookingData['createdAt'];

          // Find the booking in the bus's bookings subcollection by bookingDate
          final busBookings =
              await FirebaseFirestore.instance
                  .collection('agencies')
                  .doc(widget.userId)
                  .collection('buses')
                  .doc(busDocId)
                  .collection('bookings')
                  .where('bookingDate', isEqualTo: bookingDate)
                  .where('createdAt', isEqualTo: createdAt)
                  .get();

          for (final doc in busBookings.docs) {
            await doc.reference.delete();
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user details: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkVerification();
    _loadOffersFromFirestore();
    _loadBusesFromFirestore();
    _loadAgencyPaymentDetails();
  }

  Future<void> _checkVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('agencies')
              .doc(user.uid)
              .get();
      setState(() {
        _isVerified = doc.exists && doc['status'] == 'verified';
        _loadingVerification = false;
      });
    } else {
      setState(() {
        _isVerified = false;
        _loadingVerification = false;
      });
    }
  }

  Future<void> _loadAgencyPaymentDetails() async {
    if (widget.userId == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('agencies')
              .doc(widget.userId)
              .get();
      if (doc.exists) {
        final data = doc.data();
        _upiIdController.text = data?['upiId'] ?? '';
        _agencyMobileController.text = data?['agencyMobile'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payment details: $e')),
        );
      }
    }
  }

  Future<void> _saveAgencyPaymentDetails() async {
    if (widget.userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('agencies')
          .doc(widget.userId)
          .set({
            'upiId': _upiIdController.text.trim(),
            'agencyMobile': _agencyMobileController.text.trim(),
          }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment details updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save payment details: $e')),
        );
      }
    }
  }

  // Function to pick multiple bus images
  Future<void> _pickBusImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _busImages.addAll(
          result.paths.whereType<String>().map((path) => File(path)),
        );
      });
    }
  }

  // Function to pick an offer image
  Future<void> _pickOfferImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _offerImage = File(result.files.single.path!);
      });
    }
  }

  Future<void> _addOrUpdateSpecialOffer() async {
    if (_offerDescController.text.isEmpty) return;

    String imageUrl = '';
    if (_offerImage != null) {
      final uploadedUrl = await _uploadImageToCloudinary(_offerImage!);
      if (uploadedUrl != null) {
        imageUrl = uploadedUrl;
      }
    }

    final offerData = {
      'agency': widget.agencyName,
      'description': _offerDescController.text,
      'isNetwork': false,
      'imageUrl': imageUrl,
    };

    try {
      if (_editingOfferIndex != null) {
        final docId = _specialOffers[_editingOfferIndex!]['docId'];
        await FirebaseFirestore.instance
            .collection('agencies')
            .doc(widget.userId)
            .collection('offers')
            .doc(docId)
            .update(offerData);

        setState(() {
          _specialOffers[_editingOfferIndex!] = {...offerData, 'docId': docId};
          _editingOfferIndex = null;
        });
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('agencies')
            .doc(widget.userId)
            .collection('offers')
            .add(offerData);

        setState(() {
          _specialOffers.add({...offerData, 'docId': docRef.id});
        });
      }
      setState(() {
        _offerImage = null;
        _offerDescController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save offer: $e')));
      }
    }
  }

  Future<void> _deleteSpecialOffer(int idx) async {
    final docId = _specialOffers[idx]['docId'];
    try {
      await FirebaseFirestore.instance
          .collection('agencies')
          .doc(widget.userId)
          .collection('offers')
          .doc(docId)
          .delete();
      setState(() {
        _specialOffers.removeAt(idx);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete offer: $e')));
      }
    }
  }

  void _editSpecialOffer(int idx) {
    setState(() {
      _editingOfferIndex = idx;
      _offerDescController.text = _specialOffers[idx]['description'];
    });
  }

  Future<void> _loadOffersFromFirestore() async {
    try {
      final query =
          await FirebaseFirestore.instance
              .collection('agencies')
              .doc(widget.userId)
              .collection('offers')
              .get();
      setState(() {
        _specialOffers.clear();
        for (var doc in query.docs) {
          _specialOffers.add({...doc.data(), 'docId': doc.id});
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load offers: $e')));
      }
    }
  }

  Future<void> _addOrUpdateBus() async {
    if (_busNameController.text.isEmpty || _busRateController.text.isEmpty) {
      return;
    }

    List<String> imageUrls = [];
    try {
      for (final img in _busImages) {
        final url = await _uploadImageToCloudinary(img);
        if (url != null) imageUrls.add(url);
      }

      String? driverIdImageUrl;
      String? rcImageUrl;
      String? insuranceImageUrl;
      String? permitImageUrl;
      String? pucImageUrl;
      String? fitnessImageUrl;

      if (_driverIdImage != null) {
        driverIdImageUrl = await _uploadImageToCloudinary(_driverIdImage!);
      }
      if (_rcImage != null) {
        rcImageUrl = await _uploadImageToCloudinary(_rcImage!);
      }
      if (_insuranceImage != null) {
        insuranceImageUrl = await _uploadImageToCloudinary(_insuranceImage!);
      }
      if (_permitImage != null) {
        permitImageUrl = await _uploadImageToCloudinary(_permitImage!);
      }
      if (_pucImage != null) {
        pucImageUrl = await _uploadImageToCloudinary(_pucImage!);
      }
      if (_fitnessImage != null) {
        fitnessImageUrl = await _uploadImageToCloudinary(_fitnessImage!);
      }
      final busData = {
        'agency': widget.agencyName,
        'name': _busNameController.text,
        'description': _busDescController.text,
        'email': _busEmailController.text,
        'phone': _busPhoneController.text,
        'place': _busPlaceController.text,
        'price': double.tryParse(_busRateController.text) ?? 0,
        'ratePerDay': double.tryParse(_busRatePerDayController.text) ?? 0,
        'seatCapacity': int.tryParse(_busSeatCapacityController.text) ?? 0,
        'images': imageUrls,
        'rating': 5.0,
        'isNetwork': false,
        // --- Added driver & vehicle fields ---
        'driverId': _driverIdController.text,
        'driverIdImageUrl': driverIdImageUrl,
        'licenseNumber': _licenseController.text,
        'Bus Number': _badgeNumberController.text,
        'rc': _rcController.text,
        'rcImageUrl': rcImageUrl,
        'insurance': _insuranceController.text,
        'insuranceImageUrl': insuranceImageUrl,
        'permit': _permitController.text,
        'permitImageUrl': permitImageUrl,
        'fitness': _fitnessController.text,
        'fitnessImageUrl': fitnessImageUrl,
        'puc': _pucController.text,
        'pucImageUrl': pucImageUrl,
        'emergencyContact': _emergencyContactController.text,
      };

      if (_editingBusIndex != null) {
        final docId = _buses[_editingBusIndex!]['docId'];
        await FirebaseFirestore.instance
            .collection('agencies')
            .doc(widget.userId)
            .collection('buses')
            .doc(docId)
            .update(busData);

        setState(() {
          _buses[_editingBusIndex!] = {...busData, 'docId': docId};
          _editingBusIndex = null;
        });
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('agencies')
            .doc(widget.userId)
            .collection('buses')
            .add(busData);

        setState(() {
          _buses.add({...busData, 'docId': docRef.id});
        });
      }
      setState(() {
        _busNameController.clear();
        _busDescController.clear();
        _busEmailController.clear();
        _busPhoneController.clear();
        _busPlaceController.clear();
        _busRateController.clear();
        _busRatePerDayController.clear();
        _busSeatCapacityController.clear();
        _busImages = [];
        // --- Clear driver & vehicle fields ---
        _driverIdController.clear();
        _licenseController.clear();
        _badgeNumberController.clear();
        _rcController.clear();
        _insuranceController.clear();
        _permitController.clear();
        _fitnessController.clear();
        _pucController.clear();
        _emergencyContactController.clear();
        _driverIdImage = null;
        _rcImage = null;
        _insuranceImage = null;
        _permitImage = null;
        _pucImage = null;
        _fitnessImage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save bus: $e')));
      }
    }
  }

  Future<void> _deleteBus(int idx) async {
    final docId = _buses[idx]['docId'];
    try {
      await FirebaseFirestore.instance
          .collection('agencies')
          .doc(widget.userId)
          .collection('buses')
          .doc(docId)
          .delete();
      setState(() {
        _buses.removeAt(idx);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete bus: $e')));
      }
    }
  }

  void _editBus(int idx) {
    setState(() {
      _editingBusIndex = idx;
      _busNameController.text = _buses[idx]['name'] ?? '';
      _busDescController.text = _buses[idx]['description'] ?? '';
      _busEmailController.text = _buses[idx]['email'] ?? '';
      _busPhoneController.text = _buses[idx]['phone'] ?? '';
      _busPlaceController.text = _buses[idx]['place'] ?? '';
      _busRateController.text = (_buses[idx]['price'] ?? '').toString();
      _busRatePerDayController.text =
          (_buses[idx]['ratePerDay'] ?? '').toString();
      _busSeatCapacityController.text =
          (_buses[idx]['seatCapacity'] ?? '').toString();
      // --- Populate driver & vehicle fields when editing ---
      _driverIdController.text = _buses[idx]['driverId'] ?? '';
      _licenseController.text = _buses[idx]['licenseNumber'] ?? ''; // Fixed key
      _badgeNumberController.text = _buses[idx]['Bus Number'] ?? '';
      _rcController.text = _buses[idx]['rc'] ?? '';
      _insuranceController.text = _buses[idx]['insurance'] ?? '';
      _permitController.text = _buses[idx]['permit'] ?? '';
      _fitnessController.text = _buses[idx]['fitness'] ?? '';
      _pucController.text = _buses[idx]['puc'] ?? '';
      _emergencyContactController.text = _buses[idx]['emergencyContact'] ?? '';

      _driverIdImage = null;
      _rcImage = null;
      _insuranceImage = null;
      _permitImage = null;
      _pucImage = null;
      _fitnessImage = null;
    });
  }

  Future<void> _loadBusesFromFirestore() async {
    final query =
        await FirebaseFirestore.instance
            .collection('agencies')
            .doc(widget.userId)
            .collection('buses')
            .get();
    setState(() {
      _buses.clear();
      for (var doc in query.docs) {
        _buses.add({...doc.data(), 'docId': doc.id});
      }
    });
  }

  Widget _buildAddTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Payment Details Section ---
        const Text(
          'AGENCY PAYMENT DETAILS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF6A1B9A),
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black26,
                offset: Offset(1, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _upiIdController,
          decoration: const InputDecoration(
            labelText: 'UPI ID',
            hintText: 'example@upi',
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _agencyMobileController,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            hintText: 'Enter agency mobile number',
            prefixIcon: Icon(Icons.phone_android),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save, color: Colors.white, size: 22),
            label: const Text(
              'Save Payment Details',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6A1B9A),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shadowColor: Colors.deepPurpleAccent,
            ),
            onPressed: _saveAgencyPaymentDetails,
          ),
        ),
        const Divider(),
        // Special Offer Section
        const Text(
          'UPLOAD SPECIAL OFFER',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF6A1B9A),
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black26,
                offset: Offset(1, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickOfferImage,
          child:
              _offerImage != null
                  ? Image.file(_offerImage!, height: 120, fit: BoxFit.cover)
                  : Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text('Tap to upload offer photo'),
                    ),
                  ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _offerDescController,
          decoration: const InputDecoration(
            hintText: 'Special offer description',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            icon: Icon(
              _editingOfferIndex != null ? Icons.save : Icons.upload,
              color: Colors.white,
              size: 22,
            ),
            label: Text(
              _editingOfferIndex != null
                  ? 'Save Offer'
                  : 'Upload Special Offer',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6A1B9A),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shadowColor: Colors.deepPurpleAccent,
            ),
            onPressed: _addOrUpdateSpecialOffer,
          ),
        ),
        const SizedBox(height: 16),
        ..._specialOffers.asMap().entries.map(
          (entry) => Card(
            child: ListTile(
              leading: const Icon(Icons.local_offer, color: Colors.deepPurple),
              title: Text(entry.value['description']),
              subtitle: Text(entry.value['agency'] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editSpecialOffer(entry.key),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSpecialOffer(entry.key),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(),
        // Bus Section
        const Text(
          'UPLOAD BUS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF6A1B9A),
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black26,
                offset: Offset(1, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _busNameController,
          decoration: const InputDecoration(labelText: 'Bus Name'),
        ),
        TextField(
          controller: _busDescController,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        TextField(
          controller: _busEmailController,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: _busPhoneController,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        TextField(
          controller: _busPlaceController,
          decoration: const InputDecoration(
            labelText: 'Place (Current District in Kerala)',
          ),
        ),
        TextField(
          controller: _busRateController,
          decoration: const InputDecoration(labelText: 'Rate per km (e.g. 12)'),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _busRatePerDayController,
          decoration: const InputDecoration(
            labelText: 'Rate per day (e.g. 2500)',
          ),
        ),
        TextField(
          controller: _busSeatCapacityController,
          decoration: const InputDecoration(
            labelText: 'Seat Capacity',
            hintText: 'Enter total seat capacity',
          ),
          keyboardType: TextInputType.number,
        ),

        // --- Added driver & vehicle fields ---
        TextField(
          controller: _driverIdController,
          decoration: const InputDecoration(
            labelText: "Driver’s ID",
            hintText: "Enter driver's ID",
            prefixIcon: Icon(Icons.person),
          ),
        ),
        GestureDetector(
          onTap: _pickDriverIdImage,
          child:
              _driverIdImage != null
                  ? Image.file(
                    _driverIdImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                  : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Center(child: Text('Upload Driver ID Image')),
                  ),
        ),
        TextField(
          controller: _licenseController,
          decoration: const InputDecoration(
            labelText: "Driver’s License Number",
            hintText: "Heavy vehicle license number",
            prefixIcon: Icon(Icons.badge),
          ),
        ),
        TextField(
          controller: _badgeNumberController,
          decoration: const InputDecoration(
            labelText: "Bus Number",
            hintText: "Enter bus registration number",
            prefixIcon: Icon(Icons.confirmation_number),
          ),
        ),
        TextField(
          controller: _rcController,
          decoration: const InputDecoration(
            labelText: "Vehicle Registration Certificate (RC)",
            hintText: "RC Number",
            prefixIcon: Icon(Icons.directions_bus),
          ),
        ),
        GestureDetector(
          onTap: _pickRCImage,
          child:
              _rcImage != null
                  ? Image.file(
                    _rcImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                  : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Center(child: Text('Upload RC Image')),
                  ),
        ),
        TextField(
          controller: _insuranceController,
          decoration: const InputDecoration(
            labelText: "Insurance Certificate",
            hintText: "Insurance details",
            prefixIcon: Icon(Icons.policy),
          ),
        ),

        GestureDetector(
          onTap: _pickInsuranceImage,
          child:
              _insuranceImage != null
                  ? Image.file(
                    _insuranceImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                  : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Center(child: Text('Upload Insurance Image')),
                  ),
        ),

        TextField(
          controller: _permitController,
          decoration: const InputDecoration(
            labelText: "Permit Details",
            hintText: "Tourist/interstate permit info",
            prefixIcon: Icon(Icons.assignment),
          ),
        ),
        GestureDetector(
          onTap: _pickPermitImage,
          child:
              _permitImage != null
                  ? Image.file(
                    _permitImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                  : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Center(child: Text('Upload Permit Image')),
                  ),
        ),

        TextField(
          controller: _fitnessController,
          decoration: const InputDecoration(
            labelText: "Fitness Certificate",
            hintText: "Fitness certificate number",
            prefixIcon: Icon(Icons.check_circle),
          ),
        ),

        GestureDetector(
          onTap: _pickFitnessImage,
          child:
              _fitnessImage != null
                  ? Image.file(
                    _fitnessImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                  : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text('Upload Fitness Certificate Image'),
                    ),
                  ),
        ),

        TextField(
          controller: _pucController,
          decoration: const InputDecoration(
            labelText: "Pollution Under Control (PUC) Certificate",
            hintText: "PUC certificate number",
            prefixIcon: Icon(Icons.eco),
          ),
        ),
        GestureDetector(
          onTap: _pickPUCImage,
          child:
              _pucImage != null
                  ? Image.file(
                    _pucImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                  : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Center(child: Text('Upload PUC Image')),
                  ),
        ),

        // ...existing code...
        TextField(
          controller: _emergencyContactController,
          decoration: const InputDecoration(
            labelText: "Emergency Contact Info",
            hintText: "Contact number for emergencies",
            prefixIcon: Icon(Icons.phone_in_talk),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            ..._busImages.asMap().entries.map(
              (entry) => Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.file(
                    entry.value,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _busImages.removeAt(entry.key)),
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _pickBusImages,
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.add_a_photo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            icon: Icon(
              _editingBusIndex != null ? Icons.save : Icons.upload,
              color: Colors.white,
              size: 22,
            ),
            label: Text(
              _editingBusIndex != null ? 'Save Bus' : 'Upload Bus',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6A1B9A),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shadowColor: Colors.deepPurpleAccent,
            ),
            onPressed: _addOrUpdateBus,
          ),
        ),
        const SizedBox(height: 16),
        ..._buses.asMap().entries.map(
          (entry) => Card(
            child: ListTile(
              leading: const Icon(Icons.directions_bus, color: Colors.indigo),
              title: Text(entry.value['name']),
              subtitle: Text(
                '${entry.value['agency'] ?? ''}'
                '${entry.value['price'] != null ? ' | ₹${entry.value['price']}/km' : ''}'
                '${entry.value['ratePerDay'] != null && entry.value['ratePerDay'] > 0 ? ' | ₹${entry.value['ratePerDay']}/day' : ''}'
                '${entry.value['seatCapacity'] != null && entry.value['seatCapacity'] > 0 ? ' | Seats: ${entry.value['seatCapacity']}' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editBus(entry.key),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteBus(entry.key),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatTab() {
    final String agencyId = widget.userId ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('chatRooms')
              .where('participants', arrayContains: agencyId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final chatRooms = snapshot.data!.docs;
        if (chatRooms.isEmpty) {
          return const Center(child: Text('No chats yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          itemCount: chatRooms.length,
          itemBuilder: (context, idx) {
            final chatRoom = chatRooms[idx];
            final chatRoomId = chatRoom.id;
            final participants = List<String>.from(
              chatRoom['participants'] ?? [],
            );
            String userId = participants.firstWhere(
              (id) => id != agencyId,
              orElse: () => '',
            );
            if (userId.isEmpty) {
              userId = chatRoomId.replaceAll(agencyId, '').replaceAll('_', '');
            }

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
              builder: (context, userSnapshot) {
                String userName = 'User';
                String? profileImageUrl;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data();
                  userName = userData?['name'] ?? 'User';
                  profileImageUrl = userData?['profileImageUrl'];
                }
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 18,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal[100],
                      backgroundImage:
                          (profileImageUrl != null &&
                                  profileImageUrl.isNotEmpty)
                              ? NetworkImage(profileImageUrl)
                              : null,
                      child:
                          (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? const Icon(
                                Icons.person,
                                size: 32,
                                color: Color(0xFF6A1B9A),
                              )
                              : null,
                    ),
                    title: Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                    subtitle: Row(
                      children: const [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: Colors.teal,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Tap to chat',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.deepPurple,
                      size: 20,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => AgencyChatPage(
                                chatRoomId: chatRoomId,
                                agencyId: agencyId,
                                userId: userId,
                                userName: userName,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBookingsTab() {
    // Show a list of bookings from Firestore
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('agencies')
              .doc(widget.userId)
              .collection('bookings')
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookings = snapshot.data!.docs;
        if (bookings.isEmpty) {
          return const Center(child: Text('No bookings yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, idx) {
            final booking = bookings[idx].data() as Map<String, dynamic>;
            final user = booking['user'] ?? {};
            final bookingDate = booking['bookingDate'];
            String bookingDateStr = '';
            if (bookingDate != null) {
              if (bookingDate is Timestamp) {
                bookingDateStr = bookingDate.toDate().toString().split(' ')[0];
              } else {
                bookingDateStr = bookingDate.toString().split(' ')[0];
              }
            }

            final status = (booking['status'] ?? 'pending').toString();
            final bool cancelled =
                status.toLowerCase() == 'cancelled' ||
                booking['cancelled'] == true;
            final bool refundRequired = booking['refundRequired'] == true;
            final bool refundConfirmed = booking['refundConfirmed'] == true;
            final String cancelledMessage = booking['cancelledMessage'] ?? '';

            // Highlight card if booking is cancelled
            final bool highlightCancelled = status.toLowerCase() == 'cancelled';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: highlightCancelled ? Colors.red[50] : null,
              elevation: highlightCancelled ? 6 : 2,
              shape: RoundedRectangleBorder(
                side:
                    highlightCancelled
                        ? BorderSide(color: Colors.red, width: 2)
                        : BorderSide.none,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0, top: 8.0),
                      child: Icon(
                        Icons.book_online,
                        color: Colors.deepPurple,
                        size: 32,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] != null
                                ? 'User: ${user['name']}'
                                : 'User',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(height: 2),
                          if (user['email'] != null)
                            Text(
                              'Email: ${user['email']}',
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          if (user['phone'] != null)
                            Text(
                              'Phone: ${user['phone']}',
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          Text(
                            'Booked Date: $bookingDateStr',
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          Text(
                            'Location: ${booking['location'] ?? ''}',
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          Text(
                            'Duration: ${booking['daysDuration'] ?? ''} days',
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          Text(
                            'Payment: ₹${booking['totalPrice'] ?? ''} (${booking['paymentMethod'] ?? ''})',
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          Text(
                            'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                            style:
                                highlightCancelled
                                    ? const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    )
                                    : null,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          if (highlightCancelled)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 6.0,
                                bottom: 2.0,
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'The booking has been cancelled and a refund is required.',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (cancelled && refundRequired)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cancelledMessage.isNotEmpty
                                        ? cancelledMessage
                                        : 'The booking has been cancelled and a refund is required.',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Refund Confirmed: ${refundConfirmed ? "Yes" : "No"}',
                                    style: TextStyle(
                                      color:
                                          refundConfirmed
                                              ? Colors.green
                                              : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: const Text('Yes'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          minimumSize: const Size(60, 36),
                                        ),
                                        onPressed:
                                            refundConfirmed
                                                ? null
                                                : () async {
                                                  await bookings[idx].reference
                                                      .update({
                                                        'refundConfirmed': true,
                                                      });
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Refund marked as confirmed.',
                                                      ),
                                                    ),
                                                  );
                                                },
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: const Text('No'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          minimumSize: const Size(60, 36),
                                        ),
                                        onPressed:
                                            !refundConfirmed
                                                ? null
                                                : () async {
                                                  await bookings[idx].reference
                                                      .update({
                                                        'refundConfirmed':
                                                            false,
                                                      });
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Refund marked as not confirmed.',
                                                      ),
                                                    ),
                                                  );
                                                },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (status == 'pending') ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Update status to accepted
                                  await bookings[idx].reference.update({
                                    'status': 'accepted',
                                  });

                                  // Get booking data
                                  final bookingData =
                                      bookings[idx].data()
                                          as Map<String, dynamic>;
                                  final userId = bookingData['userId'];
                                  if (userId != null) {
                                    // Prepare booking data for user
                                    final userBookingData = {
                                      'busName': bookingData['busName'],
                                      'agencyName': widget.agencyName,
                                      'agencyId': widget.agencyId,
                                      'bookingDate': bookingData['bookingDate'],
                                      'location': bookingData['location'],
                                      'daysDuration':
                                          bookingData['daysDuration'],
                                      'status': 'accepted',
                                      'timestamp': FieldValue.serverTimestamp(),
                                    };
                                    // Store in user's bookings collection
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(userId)
                                        .collection('bookings')
                                        .add(userBookingData);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size(60, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await bookings[idx].reference.update({
                                    'status': 'rejected',
                                  });
                                  // Do not add to user bookings if rejected
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  minimumSize: const Size(60, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete User Details',
                            onPressed:
                                () => _deleteUserDetailsFromBooking(
                                  bookings[idx].reference,
                                ),
                          ),
                        ],
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
  }

  // --- UNREAD CHAT BADGE LOGIC ---
  Stream<int> _unreadChatCountStream() {
    final agencyId = widget.userId ?? '';
    return FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participants', arrayContains: agencyId)
        .snapshots()
        .asyncMap((chatRoomsSnapshot) async {
          int totalUnread = 0;
          for (var chatRoom in chatRoomsSnapshot.docs) {
            try {
              // Only use whereNotIn if agencyId is not null and less than 10
              final messagesQuery = chatRoom.reference
                  .collection('messages')
                  .where('senderId', isNotEqualTo: agencyId);

              // Defensive: Firestore whereNotIn supports max 10 elements
              final readByList = [agencyId];
              if (readByList.length <= 10) {
                final messages =
                    await messagesQuery
                        .where('readBy', whereNotIn: readByList)
                        .get();
                totalUnread += messages.docs.length;
              } else {
                // Fallback: fetch all and filter in Dart
                final messages = await messagesQuery.get();
                totalUnread +=
                    messages.docs
                        .where(
                          (doc) =>
                              !(List<String>.from(
                                doc['readBy'] ?? [],
                              ).contains(agencyId)),
                        )
                        .length;
              }
            } catch (_) {
              // Ignore errors for this chatRoom
            }
          }
          return totalUnread;
        });
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _agencyMobileController.dispose();
    _offerDescController.dispose();
    _busNameController.dispose();
    _busDescController.dispose();
    _busEmailController.dispose();
    _busPhoneController.dispose();
    _busPlaceController.dispose();
    _busRateController.dispose();
    _busRatePerDayController.dispose();
    _busSeatCapacityController.dispose();
    // --- Dispose driver & vehicle fields ---
    _driverIdController.dispose();
    _licenseController.dispose();
    _badgeNumberController.dispose();
    _rcController.dispose();
    _insuranceController.dispose();
    _permitController.dispose();
    _fitnessController.dispose();
    _pucController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingVerification) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isVerified) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.block, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                'Your agency registration is not verified.\nPlease wait for admin approval.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    final pages = [
      _buildAddTab(),
      _buildChatTab(),
      _buildBookingsTab(),

      AgencyInfoScreen(
        agencyName: widget.agencyName,
        email: widget.email,
        phone: widget.phone,
        address: widget.address,
        ownerName: widget.ownerName,
        regNumber: widget.regNumber,
        pickedFiles: widget.pickedFiles,
        userId: widget.userId ?? '',
      ),
    ];

    PreferredSizeWidget? getAppBar() {
      if (_selectedIndex == 0) {
        return AppBar(
          backgroundColor: _mainColor,
          elevation: 0,
          title: Text(
            '${widget.agencyName} Dashboard',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 1.2,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 30),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  builder: (ctx) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.description),
                            title: const Text('Terms and conditions'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const TermsAndConditionsPage(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.report),
                            title: const Text('Report'),
                            onTap: () {
                              Navigator.pop(ctx);
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                ),
                                builder: (ctx2) {
                                  return SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.bug_report),
                                          title: const Text('Report about app'),
                                          onTap: () {
                                            Navigator.pop(ctx2);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => const ReportPage(
                                                      reportType: 'app',
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.person),
                                          title: const Text(
                                            'Report about user',
                                          ),
                                          onTap: () {
                                            Navigator.pop(ctx2);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => const ReportPage(
                                                      reportType: 'user',
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              tooltip: 'More',
            ),
          ],
        );
      } else if (_selectedIndex == 1) {
        return AppBar(
          backgroundColor: _mainColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Chat',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 1.1,
            ),
          ),
          centerTitle: true,
        );
      } else if (_selectedIndex == 2) {
        return AppBar(
          backgroundColor: _mainColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Bookings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 1.1,
            ),
          ),
          centerTitle: true,
        );
      } else if (_selectedIndex == 3) {
        return AppBar(
          backgroundColor: _mainColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Agency Info',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 1.1,
            ),
          ),
          centerTitle: true,
        );
      } else {
        return null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: getAppBar(),
      body: pages[_selectedIndex],
      bottomNavigationBar: StreamBuilder<int>(
        stream: _unreadChatCountStream(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          return CurvedNavigationBar(
            index: _selectedIndex,
            height: 60,
            backgroundColor: Colors.transparent,
            color: _mainColor,
            buttonBackgroundColor: const Color(0xFF00BFAE),
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 400),
            items: [
              const Icon(Icons.add_business, size: 30, color: Colors.white),
              badges.Badge(
                showBadge: unreadCount > 0,
                badgeContent: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                badgeStyle: const badges.BadgeStyle(
                  badgeColor: Colors.red,
                  padding: EdgeInsets.all(6),
                ),
                child: const Icon(Icons.chat, size: 30, color: Colors.white),
              ),
              const Icon(Icons.book_online, size: 30, color: Colors.white),
              const Icon(Icons.info, size: 30, color: Colors.white),

            ],
            onTap: _onTabTapped,
          );
        },
      ),
    );
  }
}
