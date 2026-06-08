import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgencyInfoScreen extends StatefulWidget {
  final String agencyName;
  final String email;
  final String phone;
  final String address;
  final String ownerName;
  final String regNumber;
  final Map<String, String> pickedFiles;
  final String userId;

  const AgencyInfoScreen({
    super.key,
    required this.agencyName,
    required this.email,
    required this.phone,
    required this.address,
    required this.ownerName,
    required this.regNumber,
    required this.pickedFiles,
    required this.userId,
  });

  @override
  State<AgencyInfoScreen> createState() => _AgencyInfoScreenState();
}

class _AgencyInfoScreenState extends State<AgencyInfoScreen> {
  final Color _mainColor = const Color(0xFF6A1B9A);

  bool _isEditing = false;
  File? _profileImage;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.agencyName);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
    _addressController = TextEditingController(text: widget.address);
  }

  Future<void> _pickProfileImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  void _logout() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _saveAgencyInfoToFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('agencies')
          .doc(widget.userId)
          .set({
            'agencyName': _nameController.text,
            'email': _emailController.text,
            'phone': _phoneController.text,
            'address': _addressController.text,
            'ownerName': widget.ownerName,
            'regNumber': widget.regNumber,
            // You can add image URL here if you upload the profile image to storage
          }, SetOptions(merge: true));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Agency info updated!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update agency info: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FA),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: _mainColor.withOpacity(0.10),
                    backgroundImage:
                        _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                    child:
                        _profileImage == null
                            ? Icon(
                              Icons.account_circle,
                              size: 110,
                              color: _mainColor.withOpacity(0.7),
                            )
                            : null,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      icon: Icon(Icons.camera_alt, color: _mainColor, size: 22),
                      onPressed: _pickProfileImage,
                      tooltip: "Change Profile Picture",
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                children: [
                  _modernTextField(
                    controller: _nameController,
                    label: 'Agency Name',
                    icon: Icons.business,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 18),
                  _modernTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 18),
                  _modernTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    icon: Icons.phone,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: 18),
                  _modernTextField(
                    controller: _addressController,
                    label: 'Location',
                    icon: Icons.location_on,
                    enabled: _isEditing,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(
                    _isEditing ? Icons.save : Icons.edit,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isEditing ? 'Save' : 'Edit',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _mainColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () async {
                    if (_isEditing) {
                      await _saveAgencyInfoToFirestore();
                    }
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Log Out', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  onPressed: _logout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(
        color: enabled ? _mainColor : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _mainColor),
        labelText: label,
        labelStyle: TextStyle(color: _mainColor, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mainColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _mainColor, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }
}